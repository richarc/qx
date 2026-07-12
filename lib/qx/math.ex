defmodule Qx.Math do
  @moduledoc """
  Utility module: a documented tier-2 escape hatch below the circuit API
  (normal use never reaches it — `normalize/1` and `probabilities/1` are
  the supported surface).

  Core mathematical functions for quantum mechanics calculations.

  The public surface of this module is `normalize/1` and `probabilities/1`
  — the two state utilities used throughout Qx and taught in the tutorials.

  The remaining linear-algebra helpers (`kron/2`, `inner_product/2`,
  `outer_product/2`, `trace/1`, `unitary?/1`, `apply_gate/2`, `identity/1`,
  `complex/2`) are deprecated and will be removed in Qx 1.0. Each carries a
  drop-in `Nx`/`Complex` replacement in its deprecation notice.
  """

  import Nx.Defn
  alias Complex, as: C

  @doc """
  Computes the Kronecker (tensor) product of two matrices.

  The Kronecker product is fundamental in quantum mechanics for combining
  quantum states and operators across multiple qubits.

  ## Examples

      iex> a = Nx.tensor([[1, 2], [3, 4]])
      iex> b = Nx.tensor([[0, 5], [6, 7]])
      iex> Qx.Math.kron(a, b)
      #Nx.Tensor<
        s32[4][4]
        [
          [0, 5, 0, 10],
          [6, 7, 12, 14],
          [0, 15, 0, 20],
          [18, 21, 24, 28]
        ]
      >
  """
  @deprecated "Inline the Nx pipeline: `a |> Nx.reshape({m, 1, n, 1}) |> Nx.multiply(Nx.reshape(b, {1, p, 1, q})) |> Nx.reshape({m * p, n * q})`. Will be removed in Qx 1.0"
  defn kron(a, b) do
    {m, n} = Nx.shape(a)
    {p, q} = Nx.shape(b)

    # Reshape tensors for broadcasting
    a_reshaped = Nx.reshape(a, {m, 1, n, 1})
    b_reshaped = Nx.reshape(b, {1, p, 1, q})

    # Compute Kronecker product via broadcasting
    result = a_reshaped * b_reshaped

    # Reshape to final dimensions
    Nx.reshape(result, {m * p, n * q})
  end

  @doc """
  Normalizes a quantum state vector to unit magnitude.

  This is a host function: it performs a single `Nx.to_number/1` sync to
  check the norm, then delegates to a pure `defn` kernel. Composing it inside
  your own `defn` is therefore not supported — inline the kernel
  (`state / Nx.sqrt(Nx.sum(Nx.abs(state) ** 2))`) in that case.

  ## Examples

      iex> state = Nx.tensor([1.0, 1.0])
      iex> Qx.Math.normalize(state)
      #Nx.Tensor<
        f32[2]
        [0.70710677, 0.70710677]
      >

  ## Raises

    * `Qx.StateNormalizationError` - If the input has zero norm (an all-zero
      vector has no defined normalization; this previously returned a silent
      `NaN` tensor)
  """
  @spec normalize(Nx.Tensor.t()) :: Nx.Tensor.t()
  def normalize(state) do
    norm = Nx.abs(state) |> Nx.pow(2) |> Nx.sum() |> Nx.sqrt() |> Nx.to_number()

    if norm == 0.0 do
      raise Qx.StateNormalizationError,
            "Cannot normalize a zero-norm state vector (all amplitudes are zero)"
    end

    normalize_unchecked(state)
  end

  # Pure-defn normalization kernel: the byte-identical body of the former
  # `defn normalize/1`. Used by the public `normalize/1` (after its host-side
  # zero-norm check) and by the `Qx.Simulation` renorm hot path, which never
  # sees a zero-norm state (post-gate states are unit-norm by construction) and
  # so must avoid the public wrapper's per-call host sync (Iron Laws #5/#8).
  @doc false
  defn normalize_unchecked(state) do
    norm = Nx.sqrt(Nx.sum(Nx.abs(state) ** 2))
    state / norm
  end

  @doc """
  Computes the inner product (dot product) of two quantum states.

  ## Examples

      iex> state1 = Nx.tensor([1.0, 0.0])
      iex> state2 = Nx.tensor([0.0, 1.0])
      iex> Qx.Math.inner_product(state1, state2)
      #Nx.Tensor<
        c64
        0.0+0.0i
      >
  """
  @deprecated "Use `Nx.sum(Nx.multiply(Nx.conjugate(state1), state2))`. Will be removed in Qx 1.0"
  defn inner_product(state1, state2) do
    Nx.sum(Nx.conjugate(state1) * state2)
  end

  @doc """
  Computes the outer product of two quantum states.

  ## Examples

      iex> state1 = Nx.tensor([1.0, 0.0])
      iex> state2 = Nx.tensor([0.0, 1.0])
      iex> Qx.Math.outer_product(state1, state2)
      #Nx.Tensor<
        c64[2][2]
        [
          [0.0+0.0i, 1.0+0.0i],
          [0.0+0.0i, 0.0+0.0i]
        ]
      >
  """
  @deprecated "Use `Nx.outer(state1, Nx.conjugate(state2))`. Will be removed in Qx 1.0"
  defn outer_product(state1, state2) do
    Nx.outer(state1, Nx.conjugate(state2))
  end

  @doc """
  Applies a quantum gate (unitary matrix) to a quantum state.

  ## Examples

      iex> state = Nx.tensor([1.0, 0.0])
      iex> x_gate = Nx.tensor([[0.0, 1.0], [1.0, 0.0]])
      iex> Qx.Math.apply_gate(x_gate, state)
      #Nx.Tensor<
        f32[2]
        [0.0, 1.0]
      >
  """
  @deprecated "Use `Nx.dot/2`. Will be removed in Qx 1.0"
  defn apply_gate(gate, state) do
    Nx.dot(gate, state)
  end

  @doc """
  Computes the probability amplitudes from a quantum state vector.

  ## Examples

      iex> state = Nx.tensor([0.7071, 0.7071])
      iex> Qx.Math.probabilities(state)
      #Nx.Tensor<
        f32[2]
        [0.49999037, 0.49999037]
      >
  """
  @spec probabilities(Nx.Tensor.t()) :: Nx.Tensor.t()
  defn probabilities(state) do
    Nx.abs(state) ** 2
  end

  @doc """
  Creates a complex number from real and imaginary parts.

  ## Examples

      iex> c = Qx.Math.complex(1.0, 2.0)
      iex> Complex.real(c)
      1.0
      iex> Complex.imag(c)
      2.0
  """
  @deprecated "Use `Complex.new/2`. Will be removed in Qx 1.0"
  def complex(real, imag \\ 0.0) do
    C.new(real, imag)
  end

  # Builds a c64 complex matrix tensor from a list-of-lists. Accepts plain
  # numbers (treated as real) or `Complex.t()` cells. Used internally by
  # `Qx.Gates` matrix factories.
  @doc false
  def complex_matrix(matrix) when is_list(matrix) do
    matrix
    |> Enum.map(fn row ->
      Enum.map(row, fn
        %C{} = c -> c
        val when is_number(val) -> C.new(val, 0.0)
      end)
    end)
    |> Nx.tensor(type: :c64)
  end

  @doc """
  Computes the trace of a matrix.

  ## Examples

      iex> matrix = Nx.tensor([[1.0, 2.0], [3.0, 4.0]])
      iex> Qx.Math.trace(matrix)
      #Nx.Tensor<
        f32
        5.0
      >
  """
  @deprecated "Use `Nx.sum(Nx.take_diagonal(matrix))`. Will be removed in Qx 1.0"
  defn trace(matrix) do
    Nx.sum(Nx.take_diagonal(matrix))
  end

  @doc """
  Creates the identity matrix of given size.

  Returns a generic `n × n` real-valued identity tensor (delegates to
  `Nx.eye/1`). Not gate-shaped: the 2×2 c64 single-qubit identity
  matrix used by gate factories is internal and is not exposed at the
  public surface.

  ## Examples

      iex> Qx.Math.identity(2)
      #Nx.Tensor<
        s32[2][2]
        [
          [1, 0],
          [0, 1]
        ]
      >
  """
  @deprecated "Use `Nx.eye/1`. Will be removed in Qx 1.0"
  def identity(n) do
    Nx.eye(n)
  end

  @doc """
  Checks if a matrix is unitary (U† U = I).

  ## Examples

      iex> pauli_x = Nx.tensor([[0.0, 1.0], [1.0, 0.0]])
      iex> Qx.Math.unitary?(pauli_x)
      true

      iex> not_unitary = Nx.tensor([[2.0, 0.0], [0.0, 2.0]])
      iex> Qx.Math.unitary?(not_unitary)
      false

  ## Replacement recipe

  Check U†U ≈ I directly with Nx:

      {n, m} = Nx.shape(matrix)

      unitary? =
        n == m and
          matrix
          |> Nx.conjugate()
          |> Nx.transpose()
          |> Nx.dot(matrix)
          |> Nx.subtract(Nx.as_type(Nx.eye(n), Nx.type(matrix)))
          |> Nx.abs()
          |> Nx.reduce_max()
          |> Nx.to_number()
          |> Kernel.<(1.0e-6)
  """
  @deprecated "Check U†U ≈ I directly with Nx (recipe in the docs). Will be removed in Qx 1.0"
  @spec unitary?(Nx.Tensor.t()) :: boolean()
  def unitary?(matrix) do
    {n, m} = Nx.shape(matrix)

    if n != m do
      false
    else
      conjugate_transpose = Nx.transpose(Nx.conjugate(matrix))
      product = Nx.dot(conjugate_transpose, matrix)

      # Convert identity to same type as product (inline Nx.eye — not the
      # deprecated identity/1 — so lib/ emits no deprecation warnings)
      identity_matrix = Nx.eye(n) |> Nx.as_type(Nx.type(product))

      # Check if the product is close to identity within tolerance
      # Use Nx.subtract instead of - operator for tensor subtraction
      diff_matrix = Nx.subtract(product, identity_matrix)

      # Abs gives magnitude (real number) for each complex element
      abs_diff = Nx.abs(diff_matrix)

      # If still complex type (c64), extract real part
      real_diff =
        case Nx.type(abs_diff) do
          {:c, _} -> Nx.real(abs_diff)
          _ -> abs_diff
        end

      max_diff = Nx.reduce_max(real_diff) |> Nx.to_number()

      # Use slightly relaxed tolerance for floating point comparisons
      max_diff < 1.0e-6
    end
  end
end
