defmodule Qx.Math do
  @moduledoc """
  Core mathematical and linear algebra functions for quantum mechanics calculations.

  This module provides the fundamental mathematical operations needed for quantum
  computing simulations, including tensor products, matrix operations, and
  quantum state manipulations.
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
  Normalizes a quantum state vector to ensure unit magnitude.

  ## Examples

      iex> state = Nx.tensor([1.0, 1.0])
      iex> Qx.Math.normalize(state)
      #Nx.Tensor<
        f32[2]
        [0.7071067690849304, 0.7071067690849304]
      >
  """
  defn normalize(state) do
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
        [0.4999903738498688, 0.4999903738498688]
      >
  """
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
  def complex(real, imag \\ 0.0) do
    C.new(real, imag)
  end

  # Converts a `Complex.t()` to an Nx tensor [re, im]. Internal converter
  # used by gate-matrix builders.
  @doc false
  def complex_to_tensor(%C{} = c) do
    Nx.tensor([c.re, c.im])
  end

  # Inverse of complex_to_tensor/1: extracts [re, im] from a 2-element Nx
  # tensor into a `Complex.t()`. Internal.
  @doc false
  def tensor_to_complex(tensor) do
    [re, im] = Nx.to_flat_list(tensor)
    C.new(re, im)
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
  def identity(n) do
    Nx.eye(n)
  end

  # Deprecated: use `Qx.StateInit.basis_state/3` — it returns c64 (complex)
  # matching the rest of the quantum-state surface; this f32 (real) version
  # is kept callable for the 0.8.x deprecation window only.
  @deprecated "Use Qx.StateInit.basis_state/3"
  @doc false
  def basis_state(index, dimension) do
    state = Nx.broadcast(0.0, {dimension})
    Nx.put_slice(state, [index], Nx.tensor([1.0]))
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
  """
  @spec unitary?(Nx.Tensor.t()) :: boolean()
  def unitary?(matrix) do
    {n, m} = Nx.shape(matrix)

    if n != m do
      false
    else
      conjugate_transpose = Nx.transpose(Nx.conjugate(matrix))
      product = Nx.dot(conjugate_transpose, matrix)

      # Convert identity to same type as product
      identity_matrix = identity(n) |> Nx.as_type(Nx.type(product))

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
