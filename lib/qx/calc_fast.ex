defmodule Qx.CalcFast do
  @moduledoc false

  # Internal: high-performance gate operations using direct statevector
  # manipulation (no 2^n × 2^n matrices). Compiled via Nx.Defn for CPU/GPU
  # acceleration. Same algorithmic role as `Qx.Calc` but optimised.
  # Not part of the public API.

  import Nx.Defn

  # Bit-manipulation convention shared by every kernel below.
  #
  # These kernels evolve the statevector over its 2^n amplitudes without ever
  # building a 2^n x 2^n gate matrix and without a host-side loop over
  # amplitudes (Iron Law #5) — all indexing is vectorised Nx.
  #
  # Qubit 0 is the MOST significant bit, so in a basis-state index `i`
  # (0..2^n-1), qubit `q` is bit `(num_qubits - 1 - q)` of `i`. Every kernel
  # therefore computes `bit_pos = num_qubits - 1 - q`. Two recurring tricks:
  #   * value of qubit q in index i      ->  (i >>> bit_pos) &&& 1
  #   * partner index with qubit q flipped ->  i XOR (1 <<< bit_pos)
  # A single-bit XOR toggles exactly one qubit — that is how a gate locates the
  # amplitude(s) it must mix with each basis state.

  @doc """
  Applies a single-qubit gate directly to a statevector.

  This function applies a 2x2 gate matrix to a specific qubit in an n-qubit
  system by manipulating the statevector amplitudes directly.

  ## Parameters
    * `state` - State vector (2^n dimensional complex tensor)
    * `gate_matrix` - 2x2 gate matrix (from Qx.Gates)
    * `target_qubit` - Index of qubit to apply gate to (0-based)
    * `num_qubits` - Total number of qubits in the system

  ## Algorithm

  For a gate applied to qubit k in an n-qubit system:
  1. Iterate through statevector indices in pairs that differ only in qubit k
  2. Apply 2x2 gate matrix to each pair of amplitudes
  3. Update statevector in-place

  This avoids building a 2^n x 2^n matrix, using only O(2^n) memory.
  """
  @spec apply_single_qubit_gate(Nx.Tensor.t(), Nx.Tensor.t(), non_neg_integer(), pos_integer()) ::
          Nx.Tensor.t()
  def apply_single_qubit_gate(state, gate_matrix, _target_qubit, 1) do
    # Special case: single qubit system (simple matrix-vector multiply)
    Nx.dot(gate_matrix, state)
  end

  def apply_single_qubit_gate(state, gate_matrix, target_qubit, num_qubits) do
    # Multi-qubit: apply gate using direct statevector manipulation
    apply_single_qubit_gate_compiled(state, gate_matrix, target_qubit, num_qubits)
  end

  @spec apply_single_qubit_gate_compiled(
          Nx.Tensor.t(),
          Nx.Tensor.t(),
          non_neg_integer(),
          pos_integer()
        ) :: Nx.Tensor.t()
  defn apply_single_qubit_gate_compiled(state, gate_matrix, target_qubit, num_qubits) do
    apply_single_qubit_gate_direct(state, gate_matrix, target_qubit, num_qubits)
  end

  # Direct statevector manipulation for single-qubit gates
  @spec apply_single_qubit_gate_direct(
          Nx.Tensor.t(),
          Nx.Tensor.t(),
          non_neg_integer(),
          pos_integer()
        ) :: Nx.Tensor.t()
  defnp apply_single_qubit_gate_direct(state, gate, target_qubit, num_qubits) do
    state_size = Nx.axis_size(state, 0)

    # A single-qubit gate acts independently on each pair of amplitudes that
    # differ only in the target qubit, (|...0...⟩, |...1...⟩). We build both
    # halves of every pair at once and apply the 2x2 matrix to all pairs.
    indices = Nx.iota({state_size}, type: :s64)
    qubit_bit_position = num_qubits - 1 - target_qubit

    # Single 1-bit at the target slot: XOR-ing an index by it toggles only the
    # target, giving that index's partner in its pair.
    qubit_mask = Nx.left_shift(1, qubit_bit_position)

    # The target qubit's value (0/1) for every basis state.
    target_bits =
      Nx.bitwise_and(
        Nx.right_shift(indices, qubit_bit_position),
        1
      )

    paired_indices = Nx.bitwise_xor(indices, qubit_mask)

    # Line up (|0⟩-amp, |1⟩-amp) for the pair each index belongs to: if this
    # index's target bit is 0 it IS the |0⟩ half (partner is |1⟩); if 1, the
    # reverse. select/take build both views with no host-side loop.
    amp_0 = Nx.select(Nx.equal(target_bits, 0), state, Nx.take(state, paired_indices))
    amp_1 = Nx.select(Nx.equal(target_bits, 1), state, Nx.take(state, paired_indices))

    # Apply gate matrix: [new_0, new_1] = gate * [amp_0, amp_1]
    # gate = [[g00, g01], [g10, g11]]
    g00 = gate[0][0]
    g01 = gate[0][1]
    g10 = gate[1][0]
    g11 = gate[1][1]

    new_amp_0 = g00 * amp_0 + g01 * amp_1
    new_amp_1 = g10 * amp_0 + g11 * amp_1

    # Reconstruct state: use new amplitude based on target qubit value
    Nx.select(Nx.equal(target_bits, 0), new_amp_0, new_amp_1)
  end

  @doc """
  Applies a CNOT gate directly to a statevector.

  CNOT flips the target qubit if and only if the control qubit is |1⟩.

  ## Parameters
    * `state` - State vector (2^n dimensional complex tensor)
    * `control_qubit` - Index of control qubit
    * `target_qubit` - Index of target qubit
    * `num_qubits` - Total number of qubits in the system

  ## Algorithm

  For each basis state in the statevector:
  1. Check if control qubit is |1⟩
  2. If yes, swap amplitude with state that has target qubit flipped
  3. If no, leave amplitude unchanged

  This is much faster than building a 2^n x 2^n CNOT matrix.
  """
  @spec apply_cnot(Nx.Tensor.t(), non_neg_integer(), non_neg_integer(), pos_integer()) ::
          Nx.Tensor.t()
  defn apply_cnot(state, control_qubit, target_qubit, num_qubits) do
    state_size = Nx.axis_size(state, 0)

    # Create index tensor
    indices = Nx.iota({state_size}, type: :s64)

    # Calculate bit positions (MSB convention)
    control_bit_pos = num_qubits - 1 - control_qubit
    target_bit_pos = num_qubits - 1 - target_qubit

    # Extract control bit value for each basis state
    control_bits =
      Nx.bitwise_and(
        Nx.right_shift(indices, control_bit_pos),
        1
      )

    # Partner index with the target flipped (XOR-partner trick): flipping the
    # target qubit swaps each index's amplitude with this partner's.
    target_mask = Nx.left_shift(1, target_bit_pos)
    swapped_indices = Nx.bitwise_xor(indices, target_mask)
    swapped_amps = Nx.take(state, swapped_indices)

    # CNOT flips the target only where control=1: there, take the partner's
    # amplitude; elsewhere keep the original. One vectorised select, no branch.
    Nx.select(Nx.equal(control_bits, 1), swapped_amps, state)
  end

  @doc """
  Applies a CSWAP (Fredkin) gate directly to a statevector.

  CSWAP swaps the two target qubits if and only if the control qubit is |1⟩.

  ## Parameters
    * `state` - State vector (2^n dimensional complex tensor)
    * `control` - Index of the control qubit
    * `target_a` - Index of the first target qubit
    * `target_b` - Index of the second target qubit
    * `num_qubits` - Total number of qubits in the system
  """
  @spec apply_cswap(
          Nx.Tensor.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          pos_integer()
        ) :: Nx.Tensor.t()
  defn apply_cswap(state, control, target_a, target_b, num_qubits) do
    state_size = Nx.axis_size(state, 0)
    indices = Nx.iota({state_size}, type: :s64)

    control_bit_pos = num_qubits - 1 - control
    ta_bit_pos = num_qubits - 1 - target_a
    tb_bit_pos = num_qubits - 1 - target_b

    control_bits = Nx.bitwise_and(Nx.right_shift(indices, control_bit_pos), 1)
    ta_bits = Nx.bitwise_and(Nx.right_shift(indices, ta_bit_pos), 1)
    tb_bits = Nx.bitwise_and(Nx.right_shift(indices, tb_bit_pos), 1)

    # A swap only moves amplitude where the two targets DIFFER (|01⟩<->|10⟩);
    # when they're equal (|00⟩, |11⟩) it's a no-op fixed point. So act only
    # where control=1 AND ta != tb.
    control_set = Nx.equal(control_bits, 1)
    targets_differ = Nx.not_equal(ta_bits, tb_bits)
    should_swap = Nx.logical_and(control_set, targets_differ)

    # Flipping BOTH target bits at once maps 01<->10 — the partner to swap in.
    swap_mask =
      Nx.bitwise_or(
        Nx.left_shift(Nx.tensor(1, type: :s64), ta_bit_pos),
        Nx.left_shift(Nx.tensor(1, type: :s64), tb_bit_pos)
      )

    swapped_indices = Nx.bitwise_xor(indices, swap_mask)
    swapped_amps = Nx.take(state, swapped_indices)

    Nx.select(should_swap, swapped_amps, state)
  end

  @doc """
  Applies a Toffoli (CCX) gate directly to a statevector.

  Toffoli flips the target qubit if and only if both control qubits are |1⟩.

  ## Parameters
    * `state` - State vector (2^n dimensional complex tensor)
    * `control1` - Index of first control qubit
    * `control2` - Index of second control qubit
    * `target` - Index of target qubit
    * `num_qubits` - Total number of qubits in the system
  """
  @spec apply_toffoli(
          Nx.Tensor.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          pos_integer()
        ) :: Nx.Tensor.t()
  defn apply_toffoli(state, control1, control2, target, num_qubits) do
    state_size = Nx.axis_size(state, 0)

    # Create index tensor
    indices = Nx.iota({state_size}, type: :s64)

    # Calculate bit positions (MSB convention)
    control1_bit_pos = num_qubits - 1 - control1
    control2_bit_pos = num_qubits - 1 - control2
    target_bit_pos = num_qubits - 1 - target

    # Extract control bit values
    control1_bits =
      Nx.bitwise_and(
        Nx.right_shift(indices, control1_bit_pos),
        1
      )

    control2_bits =
      Nx.bitwise_and(
        Nx.right_shift(indices, control2_bit_pos),
        1
      )

    # Toffoli = CNOT gated on two controls: flip the target only where BOTH
    # control bits are 1.
    both_controls_set =
      Nx.logical_and(
        Nx.equal(control1_bits, 1),
        Nx.equal(control2_bits, 1)
      )

    # Partner index with the target flipped (XOR-partner trick).
    target_mask = Nx.left_shift(1, target_bit_pos)
    swapped_indices = Nx.bitwise_xor(indices, target_mask)

    # Get amplitudes from potentially swapped positions
    swapped_amps = Nx.take(state, swapped_indices)

    # Apply Toffoli: if both controls=1, use swapped amplitude; else original
    Nx.select(both_controls_set, swapped_amps, state)
  end
end
