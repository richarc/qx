defmodule Qx.CalcFast do
  @moduledoc false

  # Internal: high-performance gate operations using direct statevector
  # manipulation (no 2^n × 2^n matrices). Compiled via Nx.Defn for CPU/GPU
  # acceleration. Same algorithmic role as `Qx.Calc` but optimised.
  # Not part of the public API.

  import Nx.Defn

  # Axis-slicing convention shared by every kernel below.
  #
  # The {2^n} statevector is reshaped to a rank-n tensor of shape {2, …, 2}.
  # Qubit 0 is the MOST significant bit of a basis index, so after the
  # reshape **axis q is qubit q**: slicing axis q at index 0 / 1 selects the
  # amplitudes with that qubit in |0⟩ / |1⟩. Every gate is then expressed
  # with static slices of those axes — no gather, no mask, no 2^n × 2^n
  # matrix and no host-side loop over amplitudes (Iron Laws #3 / #5):
  #
  #   * single-qubit U on t   -> split axis t into halves (a0, a1) and
  #                              recombine: [u00·a0 + u01·a1, u10·a0 + u11·a1]
  #   * control on c          -> apply the sub-operation only to the c = 1
  #                              slice; concatenate it back after the c = 0
  #                              slice. Several controls nest (Toffoli).
  #   * X on t (CNOT / CCX)   -> reverse axis t of the control slice
  #   * SWAP a, b (CSWAP)     -> transpose axes a and b (of the control slice)
  #   * iSWAP a, b            -> exchange the |01⟩ / |10⟩ blocks, phase i
  #
  # Sliced axes keep size 1 (they are never squeezed), so axis numbers stay
  # valid through nested slicing. Qubit indices and `num_qubits` must be
  # STATIC (they drive shapes), so the `defnp` kernels take them as `opts`;
  # the public `def` wrappers validate them on the host first. Under EXLA
  # each distinct (qubits, num_qubits) combination compiles one executable;
  # the gate matrix is a tensor argument, so parameter changes never
  # recompile.
  #
  # Rank-n slicing was measured against a dense 2^k × 2^k `Nx.dot`
  # contraction: it is faster for every gate on BinaryBackend (the dense form
  # multiplies through mostly-zero controlled/permutation blocks) — see
  # `bench/kernels_bench.exs`.

  # ===========================================================================
  # Public entry points
  # ===========================================================================

  @doc """
  Applies a single-qubit gate directly to a statevector.

  Only the top-left 2×2 block of `gate_matrix` is read.

  ## Parameters
    * `state` - State vector (2^n dimensional complex tensor)
    * `gate_matrix` - 2x2 gate matrix (from Qx.Gates)
    * `target_qubit` - Index of qubit to apply gate to (0-based)
    * `num_qubits` - Total number of qubits in the system

  Raises `ArgumentError` for an out-of-range target or a state whose length
  is not `2^num_qubits` — except when `num_qubits == 1`, where the target is
  ignored and the gate is applied by a plain `Nx.dot` (no validation).
  """
  @spec apply_single_qubit_gate(Nx.Tensor.t(), Nx.Tensor.t(), non_neg_integer(), pos_integer()) ::
          Nx.Tensor.t()
  def apply_single_qubit_gate(state, gate_matrix, _target_qubit, 1) do
    # Special case: single qubit system (simple matrix-vector multiply)
    Nx.dot(gate_matrix, state)
  end

  def apply_single_qubit_gate(state, gate_matrix, target_qubit, num_qubits) do
    validate_qubits!([target_qubit], num_qubits)

    unitary_kernel(state, gate_matrix,
      controls: [],
      target: target_qubit,
      num_qubits: num_qubits
    )
  end

  @doc """
  Applies a controlled single-qubit gate `|0⟩⟨0|⊗I + |1⟩⟨1|⊗U` directly to a
  statevector: `gate_matrix` (2×2) acts on `target` wherever `control` is |1⟩.

  Covers CP / CY / CZ / CRx / CRy / CRz (and CX, though `apply_cnot/4` is the
  cheaper permutation-only path).

  Raises `ArgumentError` for out-of-range or equal qubits, a gate that is not
  2×2, or a state whose length is not `2^num_qubits`.
  """
  @spec apply_controlled_gate(
          Nx.Tensor.t(),
          Nx.Tensor.t(),
          non_neg_integer(),
          non_neg_integer(),
          pos_integer()
        ) :: Nx.Tensor.t()
  def apply_controlled_gate(state, gate_matrix, control, target, num_qubits) do
    validate_qubits!([control, target], num_qubits)
    validate_2x2!(gate_matrix)

    unitary_kernel(state, gate_matrix,
      controls: [control],
      target: target,
      num_qubits: num_qubits
    )
  end

  @doc """
  Applies a CNOT gate directly to a statevector.

  CNOT flips the target qubit if and only if the control qubit is |1⟩.

  ## Parameters
    * `state` - State vector (2^n dimensional complex tensor)
    * `control_qubit` - Index of control qubit
    * `target_qubit` - Index of target qubit
    * `num_qubits` - Total number of qubits in the system

  Raises `ArgumentError` for out-of-range or equal qubits.
  """
  @spec apply_cnot(Nx.Tensor.t(), non_neg_integer(), non_neg_integer(), pos_integer()) ::
          Nx.Tensor.t()
  def apply_cnot(state, control_qubit, target_qubit, num_qubits) do
    validate_qubits!([control_qubit, target_qubit], num_qubits)
    flip_kernel(state, controls: [control_qubit], target: target_qubit, num_qubits: num_qubits)
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

  Raises `ArgumentError` for out-of-range or repeated qubits.
  """
  @spec apply_toffoli(
          Nx.Tensor.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          pos_integer()
        ) :: Nx.Tensor.t()
  def apply_toffoli(state, control1, control2, target, num_qubits) do
    validate_qubits!([control1, control2, target], num_qubits)
    flip_kernel(state, controls: [control1, control2], target: target, num_qubits: num_qubits)
  end

  @doc """
  Applies a SWAP gate directly to a statevector (exchanges `qubit_a` and
  `qubit_b`).

  Raises `ArgumentError` for out-of-range or equal qubits.
  """
  @spec apply_swap(Nx.Tensor.t(), non_neg_integer(), non_neg_integer(), pos_integer()) ::
          Nx.Tensor.t()
  def apply_swap(state, qubit_a, qubit_b, num_qubits) do
    validate_qubits!([qubit_a, qubit_b], num_qubits)
    swap_kernel(state, controls: [], pair: [qubit_a, qubit_b], num_qubits: num_qubits)
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

  Raises `ArgumentError` for out-of-range or repeated qubits.
  """
  @spec apply_cswap(
          Nx.Tensor.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          pos_integer()
        ) :: Nx.Tensor.t()
  def apply_cswap(state, control, target_a, target_b, num_qubits) do
    validate_qubits!([control, target_a, target_b], num_qubits)
    swap_kernel(state, controls: [control], pair: [target_a, target_b], num_qubits: num_qubits)
  end

  @doc """
  Applies an iSWAP gate directly to a statevector:
  `|01⟩ → i|10⟩`, `|10⟩ → i|01⟩`, `|00⟩` and `|11⟩` unchanged (symmetric in
  the two qubits).

  Raises `ArgumentError` for out-of-range or equal qubits.
  """
  @spec apply_iswap(Nx.Tensor.t(), non_neg_integer(), non_neg_integer(), pos_integer()) ::
          Nx.Tensor.t()
  def apply_iswap(state, qubit_a, qubit_b, num_qubits) do
    validate_qubits!([qubit_a, qubit_b], num_qubits)
    iswap_kernel(state, pair: [qubit_a, qubit_b], num_qubits: num_qubits)
  end

  @doc """
  Returns `{p0, p1}`: the probabilities of measuring `qubit` as |0⟩ / |1⟩.

  |amplitude|² is accumulated in f64 (matching a host-side float sum of the
  `:c64` amplitudes), and the two sums reach the host in a single sync.

  Raises `ArgumentError` for an out-of-range qubit or a state whose length is
  not `2^num_qubits`.
  """
  @spec qubit_probabilities(Nx.Tensor.t(), non_neg_integer(), pos_integer()) ::
          {float(), float()}
  def qubit_probabilities(state, qubit, num_qubits) do
    validate_qubits!([qubit], num_qubits)

    [p0, p1] =
      state
      |> qubit_probabilities_kernel(qubit: qubit, num_qubits: num_qubits)
      |> Nx.to_flat_list()

    {p0, p1}
  end

  @doc """
  Collapses `state` onto `qubit = value`: amplitudes with the qubit in the
  other basis state become exactly 0, and the kept ones are multiplied by
  `norm_factor` (normally `1 / sqrt(p_value)`). The result stays `:c64`.

  Raises `ArgumentError` for an out-of-range qubit, a `value` other than 0 or
  1, or a state whose length is not `2^num_qubits`.
  """
  @spec collapse(Nx.Tensor.t(), non_neg_integer(), 0 | 1, float(), pos_integer()) ::
          Nx.Tensor.t()
  def collapse(state, qubit, value, norm_factor, num_qubits) when value in [0, 1] do
    validate_qubits!([qubit], num_qubits)

    collapse_kernel(state, Nx.tensor(norm_factor, type: :f64),
      qubit: qubit,
      value: value,
      num_qubits: num_qubits
    )
  end

  def collapse(_state, _qubit, value, _norm_factor, _num_qubits) do
    raise ArgumentError, "measured value must be 0 or 1, got: #{inspect(value)}"
  end

  # ===========================================================================
  # Compiled kernels (static qubits / num_qubits via opts)
  # ===========================================================================

  defnp qubit_probabilities_kernel(state, opts \\ []) do
    opts = keyword!(opts, [:qubit, :num_qubits])
    probabilities_expr(state, opts[:qubit], opts[:num_qubits])
  end

  defnp collapse_kernel(state, norm_factor, opts \\ []) do
    opts = keyword!(opts, [:qubit, :value, :num_qubits])
    collapse_expr(state, norm_factor, opts[:qubit], opts[:value], opts[:num_qubits])
  end

  defnp unitary_kernel(state, gate, opts \\ []) do
    opts = keyword!(opts, [:controls, :target, :num_qubits])
    unitary_expr(state, gate, opts[:controls], opts[:target], opts[:num_qubits])
  end

  defnp flip_kernel(state, opts \\ []) do
    opts = keyword!(opts, [:controls, :target, :num_qubits])
    flip_expr(state, opts[:controls], opts[:target], opts[:num_qubits])
  end

  defnp swap_kernel(state, opts \\ []) do
    opts = keyword!(opts, [:controls, :pair, :num_qubits])
    swap_expr(state, opts[:controls], opts[:pair], opts[:num_qubits])
  end

  defnp iswap_kernel(state, opts \\ []) do
    opts = keyword!(opts, [:pair, :num_qubits])
    iswap_expr(state, opts[:pair], opts[:num_qubits])
  end

  # Trace-time builders: plain Elixir over static ints, emitting Nx ops on the
  # traced tensors.

  deftransformp unitary_expr(state, gate, controls, target, num_qubits) do
    in_axes(state, num_qubits, controls, &mix_axis(&1, gate, target))
  end

  deftransformp flip_expr(state, controls, target, num_qubits) do
    in_axes(state, num_qubits, controls, &Nx.reverse(&1, axes: [target]))
  end

  deftransformp swap_expr(state, controls, [a, b], num_qubits) do
    in_axes(state, num_qubits, controls, &Nx.transpose(&1, axes: swap_axes(num_qubits, a, b)))
  end

  deftransformp iswap_expr(state, [a, b], num_qubits) do
    in_axes(state, num_qubits, [], &iswap_axes(&1, a, b))
  end

  # {pre, 2, post}: the middle axis is `qubit`, so summing the outer two
  # leaves [p0, p1].
  deftransformp probabilities_expr(state, qubit, num_qubits) do
    magnitude = state |> Nx.abs() |> Nx.as_type(:f64)

    magnitude
    |> Nx.multiply(magnitude)
    |> Nx.reshape({Integer.pow(2, qubit), 2, Integer.pow(2, num_qubits - qubit - 1)})
    |> Nx.sum(axes: [0, 2])
  end

  # Kept half rescaled in c128 (one rounding back to c64, as a host-side f64
  # multiply would give); the other half replaced by exact zeros.
  deftransformp collapse_expr(state, norm_factor, qubit, value, num_qubits) do
    in_axes(state, num_qubits, [], fn tensor ->
      {amp0, amp1} = halves(tensor, qubit)
      kept = if value == 0, do: amp0, else: amp1

      scaled =
        kept
        |> Nx.as_type({:c, 128})
        |> Nx.multiply(norm_factor)
        |> Nx.as_type(Nx.type(state))

      zeros = Nx.broadcast(Nx.tensor(0, type: Nx.type(state)), Nx.shape(kept))
      Nx.concatenate(if(value == 0, do: [scaled, zeros], else: [zeros, scaled]), axis: qubit)
    end)
  end

  # ===========================================================================
  # Slicing primitives (called at trace time from the deftransforms above)
  # ===========================================================================

  # Reshape {2^n} -> {2, …, 2}, apply `op` to the all-controls-|1⟩ slice,
  # reshape back.
  defp in_axes(state, num_qubits, controls, op) do
    state
    |> Nx.reshape(Tuple.duplicate(2, num_qubits))
    |> on_controls(controls, op)
    |> Nx.reshape({Integer.pow(2, num_qubits)})
  end

  defp on_controls(tensor, [], op), do: op.(tensor)

  defp on_controls(tensor, [control | rest], op) do
    {off, on} = halves(tensor, control)
    Nx.concatenate([off, on_controls(on, rest, op)], axis: control)
  end

  # The qubit = |0⟩ and qubit = |1⟩ slices along `axis` (size-1 axis kept).
  defp halves(tensor, axis) do
    {Nx.slice_along_axis(tensor, 0, 1, axis: axis), Nx.slice_along_axis(tensor, 1, 1, axis: axis)}
  end

  # [new_0, new_1] = gate · [amp_0, amp_1] for every pair along `axis`.
  defp mix_axis(tensor, gate, axis) do
    {amp0, amp1} = halves(tensor, axis)
    new0 = Nx.add(Nx.multiply(gate[0][0], amp0), Nx.multiply(gate[0][1], amp1))
    new1 = Nx.add(Nx.multiply(gate[1][0], amp0), Nx.multiply(gate[1][1], amp1))
    Nx.concatenate([new0, new1], axis: axis)
  end

  defp swap_axes(rank, a, b) do
    Enum.map(0..(rank - 1), fn
      ^a -> b
      ^b -> a
      axis -> axis
    end)
  end

  # Blocks indexed (qubit_a, qubit_b): |01⟩ ← i·|10⟩, |10⟩ ← i·|01⟩.
  defp iswap_axes(tensor, a, b) do
    {a0, a1} = halves(tensor, a)
    {a0b0, a0b1} = halves(a0, b)
    {a1b0, a1b1} = halves(a1, b)
    i = Complex.new(0.0, 1.0)

    Nx.concatenate(
      [
        Nx.concatenate([a0b0, Nx.multiply(i, a1b0)], axis: b),
        Nx.concatenate([Nx.multiply(i, a0b1), a1b1], axis: b)
      ],
      axis: a
    )
  end

  # ===========================================================================
  # Host-side validation of the static arguments
  # ===========================================================================

  defp validate_qubits!(qubits, num_qubits) when is_integer(num_qubits) and num_qubits >= 1 do
    case Enum.find(qubits, &(not (is_integer(&1) and &1 >= 0 and &1 < num_qubits))) do
      nil ->
        :ok

      bad ->
        raise ArgumentError,
              "qubit index #{inspect(bad)} is out of range for a #{num_qubits}-qubit state"
    end

    if Enum.uniq(qubits) != qubits do
      raise ArgumentError, "qubit indices must be distinct, got: #{inspect(qubits)}"
    end

    :ok
  end

  defp validate_qubits!(_qubits, num_qubits) do
    raise ArgumentError, "num_qubits must be a positive integer, got: #{inspect(num_qubits)}"
  end

  defp validate_2x2!(gate) do
    case Nx.shape(gate) do
      {2, 2} -> :ok
      shape -> raise ArgumentError, "expected a 2x2 gate matrix, got shape #{inspect(shape)}"
    end
  end
end
