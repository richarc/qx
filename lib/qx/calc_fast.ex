defmodule Qx.CalcFast do
  @moduledoc """
  Optimized quantum gate operations using direct statevector manipulation.

  This module provides high-performance implementations that apply gates
  directly to statevectors without building full 2^n x 2^n gate matrices.
  All functions are compiled with Nx.Defn for GPU/CPU acceleration.

  ## Performance

  Compared to the original matrix-based approach:
  - Memory: O(2^n) instead of O(2^(2n))
  - Speed: 10-1000x faster depending on circuit size
  - GPU-friendly: All operations use Nx primitives that compile to XLA

  ## Implementation Notes

  These implementations follow the approach used by production quantum
  simulators like Qiskit-Aer and Cirq, manipulating statevector amplitudes
  directly rather than constructing and multiplying large matrices.
  """

  import Nx.Defn

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
  def apply_single_qubit_gate(state, gate_matrix, _target_qubit, 1) do
    # Special case: single qubit system (simple matrix-vector multiply)
    Nx.dot(gate_matrix, state)
  end

  def apply_single_qubit_gate(state, gate_matrix, target_qubit, num_qubits) do
    # Multi-qubit: apply gate using direct statevector manipulation
    apply_single_qubit_gate_compiled(state, gate_matrix, target_qubit, num_qubits)
  end

  defn apply_single_qubit_gate_compiled(state, gate_matrix, target_qubit, num_qubits) do
    apply_single_qubit_gate_direct(state, gate_matrix, target_qubit, num_qubits)
  end

  # Direct statevector manipulation for single-qubit gates
  defnp apply_single_qubit_gate_direct(state, gate, target_qubit, num_qubits) do
    state_size = Nx.axis_size(state, 0)

    # For each basis state, we need to determine if its target qubit is |0⟩ or |1⟩
    # and pair it with the state that has the target qubit flipped
    #
    # Qubit indexing: qubit 0 is MSB (leftmost)
    # For state index i, qubit q is: bit (num_qubits - 1 - q) of i

    # Create index tensor: [0, 1, 2, ..., state_size-1]
    indices = Nx.iota({state_size}, type: :s64)

    # Calculate which qubit bit to check (MSB convention)
    qubit_bit_position = num_qubits - 1 - target_qubit

    # Mask to isolate the target qubit bit
    qubit_mask = Nx.left_shift(1, qubit_bit_position)

    # Determine which states have target qubit = 0 vs 1
    # target_bit = (indices >>> qubit_bit_position) & 1
    target_bits = Nx.bitwise_and(
      Nx.right_shift(indices, qubit_bit_position),
      1
    )

    # For each index, compute its pair (index with target qubit flipped)
    paired_indices = Nx.bitwise_xor(indices, qubit_mask)

    # Extract amplitudes for |0⟩ and |1⟩ states of target qubit
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
  defn apply_cnot(state, control_qubit, target_qubit, num_qubits) do
    state_size = Nx.axis_size(state, 0)

    # Create index tensor
    indices = Nx.iota({state_size}, type: :s64)

    # Calculate bit positions (MSB convention)
    control_bit_pos = num_qubits - 1 - control_qubit
    target_bit_pos = num_qubits - 1 - target_qubit

    # Extract control bit value for each basis state
    control_bits = Nx.bitwise_and(
      Nx.right_shift(indices, control_bit_pos),
      1
    )

    # For states with control=1, we need to flip the target bit
    # Mask to flip target bit
    target_mask = Nx.left_shift(1, target_bit_pos)

    # Compute swapped indices (target bit flipped)
    swapped_indices = Nx.bitwise_xor(indices, target_mask)

    # Get amplitudes from potentially swapped positions
    swapped_amps = Nx.take(state, swapped_indices)

    # Apply CNOT: if control=1, use swapped amplitude; else use original
    Nx.select(Nx.equal(control_bits, 1), swapped_amps, state)
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
  defn apply_toffoli(state, control1, control2, target, num_qubits) do
    state_size = Nx.axis_size(state, 0)

    # Create index tensor
    indices = Nx.iota({state_size}, type: :s64)

    # Calculate bit positions (MSB convention)
    control1_bit_pos = num_qubits - 1 - control1
    control2_bit_pos = num_qubits - 1 - control2
    target_bit_pos = num_qubits - 1 - target

    # Extract control bit values
    control1_bits = Nx.bitwise_and(
      Nx.right_shift(indices, control1_bit_pos),
      1
    )
    control2_bits = Nx.bitwise_and(
      Nx.right_shift(indices, control2_bit_pos),
      1
    )

    # Check if both controls are 1
    both_controls_set = Nx.logical_and(
      Nx.equal(control1_bits, 1),
      Nx.equal(control2_bits, 1)
    )

    # Mask to flip target bit
    target_mask = Nx.left_shift(1, target_bit_pos)

    # Compute swapped indices (target bit flipped)
    swapped_indices = Nx.bitwise_xor(indices, target_mask)

    # Get amplitudes from potentially swapped positions
    swapped_amps = Nx.take(state, swapped_indices)

    # Apply Toffoli: if both controls=1, use swapped amplitude; else original
    Nx.select(both_controls_set, swapped_amps, state)
  end
end
