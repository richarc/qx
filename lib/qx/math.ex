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
        s64[4][4]
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
        f32
        0.0
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
        f32[2][2]
        [
          [0.0, 1.0],
          [0.0, 0.0]
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
        [0.49999842047691345, 0.49999842047691345]
      >
  """
  defn probabilities(state) do
    Nx.abs(state) ** 2
  end

  @doc """
  Creates a complex number from real and imaginary parts.

  ## Examples

      iex> Qx.Math.complex(1.0, 2.0)
      #Complex<1.0+2.0i>
  """
  def complex(real, imag \\ 0.0) do
    C.new(real, imag)
  end

  @doc """
  Converts a complex number to an Nx tensor with [real, imag] representation.

  ## Examples

      iex> c = Complex.new(1.0, 2.0)
      iex> Qx.Math.complex_to_tensor(c)
      #Nx.Tensor<
        f32[2]
        [1.0, 2.0]
      >
  """
  def complex_to_tensor(%C{} = c) do
    Nx.tensor([c.re, c.im])
  end

  @doc """
  Converts an Nx tensor with [real, imag] representation to a complex number.

  ## Examples

      iex> tensor = Nx.tensor([1.0, 2.0])
      iex> Qx.Math.tensor_to_complex(tensor)
      #Complex<1.0+2.0i>
  """
  def tensor_to_complex(tensor) do
    [re, im] = Nx.to_flat_list(tensor)
    C.new(re, im)
  end

  @doc """
  Creates a complex matrix for quantum gates.

  ## Examples

      iex> # Pauli-Y gate matrix
      iex> Qx.Math.complex_matrix([[0, -1i], [1i, 0]])
  """
  def complex_matrix(matrix) when is_list(matrix) do
    matrix
    |> Enum.map(fn row ->
      Enum.map(row, fn
        %C{} = c -> [c.re, c.im]
        val when is_number(val) -> [val, 0.0]
      end)
    end)
    |> Nx.tensor()
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

  ## Examples

      iex> Qx.Math.identity(2)
      #Nx.Tensor<
        f32[2][2]
        [
          [1.0, 0.0],
          [0.0, 1.0]
        ]
      >
  """
  def identity(n) do
    Nx.eye(n)
  end

  @doc """
  Creates a computational basis state |n⟩ in a Hilbert space of given dimension.

  ## Examples

      iex> Qx.Math.basis_state(0, 2)  # |0⟩ state
      #Nx.Tensor<
        f32[2]
        [1.0, 0.0]
      >

      iex> Qx.Math.basis_state(1, 2)  # |1⟩ state
      #Nx.Tensor<
        f32[2]
        [0.0, 1.0]
      >
  """
  def basis_state(index, dimension) do
    state = Nx.broadcast(0.0, {dimension})
    Nx.put_slice(state, [index], Nx.tensor([1.0]))
  end

  @doc """
  Checks if a matrix is unitary (U† U = I).

  ## Examples

      iex> pauli_x = Nx.tensor([[0.0, 1.0], [1.0, 0.0]])
      iex> Qx.Math.is_unitary?(pauli_x)
      true
  """
  def is_unitary?(matrix) do
    {n, m} = Nx.shape(matrix)

    if n != m do
      false
    else
      conjugate_transpose = Nx.transpose(Nx.conjugate(matrix))
      product = Nx.dot(conjugate_transpose, matrix)
      identity_matrix = identity(n)

      # Check if the product is close to identity within tolerance
      diff = Nx.abs(product - identity_matrix)
      max_diff = Nx.reduce_max(diff) |> Nx.to_number()
      max_diff < 1.0e-10
    end
  end

  @doc """
  Applies complex matrix multiplication to a complex state vector.

  Both matrix and state are represented as Nx tensors with the last dimension
  being [real, imag] pairs.
  """
  def apply_complex_gate(gate_matrix, state) do
    # gate_matrix: shape [n, n, 2] where last dim is [real, imag]
    # state: shape [n, 2] where last dim is [real, imag]

    # Extract real and imaginary parts
    gate_real = Nx.slice_along_axis(gate_matrix, 0, 1, axis: -1) |> Nx.squeeze(axes: [-1])
    gate_imag = Nx.slice_along_axis(gate_matrix, 1, 1, axis: -1) |> Nx.squeeze(axes: [-1])
    state_real = Nx.slice_along_axis(state, 0, 1, axis: -1) |> Nx.squeeze(axes: [-1])
    state_imag = Nx.slice_along_axis(state, 1, 1, axis: -1) |> Nx.squeeze(axes: [-1])

    # Complex multiplication: (a + bi) * (c + di) = (ac - bd) + (ad + bc)i
    result_real = Nx.subtract(Nx.dot(gate_real, state_real), Nx.dot(gate_imag, state_imag))
    result_imag = Nx.add(Nx.dot(gate_real, state_imag), Nx.dot(gate_imag, state_real))

    Nx.stack([result_real, result_imag], axis: -1)
  end

  @doc """
  Computes probabilities from complex state vector.

  State is represented as Nx tensor with last dimension being [real, imag] pairs.
  """
  def complex_probabilities(complex_state) do
    # |ψ|² = real² + imag²
    real_part = Nx.slice_along_axis(complex_state, 0, 1, axis: -1) |> Nx.squeeze(axes: [-1])
    imag_part = Nx.slice_along_axis(complex_state, 1, 1, axis: -1) |> Nx.squeeze(axes: [-1])
    Nx.add(Nx.pow(real_part, 2), Nx.pow(imag_part, 2))
  end

  @doc """
  Normalizes a complex state vector.
  """
  def normalize_complex(complex_state) do
    probs = complex_probabilities(complex_state)
    norm = Nx.sqrt(Nx.sum(probs))
    Nx.divide(complex_state, norm)
  end
end
