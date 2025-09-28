defmodule Qx.Qubit do
  @moduledoc """
  Functions for creating and manipulating quantum qubits.

  This module provides the fundamental building blocks for quantum computing
  simulations by handling individual qubit states and ensuring they meet
  the normalization requirements of quantum mechanics.
  """

  import Nx.Defn
  alias Qx.Math
  alias Complex, as: C

  @doc """
  Creates a new qubit in the default |0⟩ state.

  ## Examples

      iex> Qx.Qubit.new()
      #Nx.Tensor<
        c64[2]
        [1.0+0.0i, 0.0+0.0i]
      >
  """
  def new do
    # |0⟩ state with c64 complex representation
    Nx.tensor([C.new(1.0, 0.0), C.new(0.0, 0.0)], type: :c64)
  end

  @doc """
  Creates a new qubit with specified alpha and beta coefficients.

  The qubit state is represented as α|0⟩ + β|1⟩, where |α|² + |β|² = 1.
  This function automatically normalizes the coefficients to ensure the
  qubit meets quantum mechanics normalization requirements.

  ## Parameters
    * `alpha` - Coefficient for the |0⟩ state (number or Complex)
    * `beta` - Coefficient for the |1⟩ state (number or Complex)

  ## Examples

      iex> Qx.Qubit.new(1.0, 1.0)
      #Nx.Tensor<
        c64[2]
        [0.7071067690849304+0.0i, 0.7071067690849304+0.0i]
      >

      iex> Qx.Qubit.new(1.0, 0.0)
      #Nx.Tensor<
        c64[2]
        [1.0+0.0i, 0.0+0.0i]
      >
  """
  def new(alpha, beta) when is_number(alpha) and is_number(beta) do
    # Create c64 tensor from real numbers
    alpha_complex = C.new(alpha, 0.0)
    beta_complex = C.new(beta, 0.0)
    state = Nx.tensor([alpha_complex, beta_complex], type: :c64)
    Math.normalize(state)
  end

  def new(%C{} = alpha, %C{} = beta) do
    # Create c64 tensor from Complex numbers
    state = Nx.tensor([alpha, beta], type: :c64)
    Math.normalize(state)
  end

  @doc """
  Creates a qubit in the |1⟩ state.

  ## Examples

      iex> Qx.Qubit.one()
      #Nx.Tensor<
        c64[2]
        [0.0+0.0i, 1.0+0.0i]
      >
  """
  def one do
    # |1⟩ state with c64 complex representation
    Nx.tensor([C.new(0.0, 0.0), C.new(1.0, 0.0)], type: :c64)
  end

  @doc """
  Creates a qubit in the |+⟩ state (equal superposition).

  The |+⟩ state is (|0⟩ + |1⟩)/√2.

  ## Examples

      iex> Qx.Qubit.plus()
      #Nx.Tensor<
        c64[2]
        [0.7071067690849304+0.0i, 0.7071067690849304+0.0i]
      >
  """
  def plus do
    new(1.0, 1.0)
  end

  @doc """
  Creates a qubit in the |-⟩ state.

  The |-⟩ state is (|0⟩ - |1⟩)/√2.

  ## Examples

      iex> Qx.Qubit.minus()
      #Nx.Tensor<
        c64[2]
        [0.7071067690849304+0.0i, -0.7071067690849304+0.0i]
      >
  """
  def minus do
    new(1.0, -1.0)
  end

  @doc """
  Measures a qubit and returns the probability of measuring |0⟩ and |1⟩.

  ## Examples

      iex> qubit = Qx.Qubit.plus()
      iex> Qx.Qubit.measure_probabilities(qubit)
      #Nx.Tensor<
        f32[2]
        [0.49999842047691345, 0.49999842047691345]
      >
  """
  defn measure_probabilities(qubit) do
    Math.probabilities(qubit)
  end

  @doc """
  Checks if a given state vector represents a valid qubit.

  A valid qubit must:
  1. Have exactly 2 complex components (shape {2})
  2. Be normalized (|α|² + |β|² = 1)

  ## Examples

      iex> valid_qubit = Qx.Qubit.new(0.6, 0.8)
      iex> Qx.Qubit.valid?(valid_qubit)
      true

      iex> invalid_qubit = Nx.tensor([Complex.new(1.0, 0.0), Complex.new(1.0, 0.0)], type: :c64)
      iex> Qx.Qubit.valid?(invalid_qubit)
      false
  """
  def valid?(state) do
    case Nx.shape(state) do
      {2} ->
        probs = Math.probabilities(state)
        norm_squared = Nx.sum(probs) |> Nx.to_number()
        abs(norm_squared - 1.0) < 1.0e-6

      _ ->
        false
    end
  end

  @doc """
  Gets the amplitude for the |0⟩ state.

  ## Examples

      iex> qubit = Qx.Qubit.new(0.6, 0.8)
      iex> Qx.Qubit.alpha(qubit)
      #Complex<0.6000000238418579+0.0i>
  """
  def alpha(qubit) do
    # Extract the first complex number from c64 tensor
    Nx.to_number(qubit[0])
  end

  @doc """
  Gets the amplitude for the |1⟩ state.

  ## Examples

      iex> qubit = Qx.Qubit.new(0.6, 0.8)
      iex> Qx.Qubit.beta(qubit)
      #Complex<0.7999999523162842+0.0i>
  """
  def beta(qubit) do
    # Extract the second complex number from c64 tensor
    Nx.to_number(qubit[1])
  end

  @doc """
  Creates a random qubit state with uniformly distributed amplitudes.

  The state is automatically normalized to ensure it represents a valid qubit.

  ## Examples

      iex> random_qubit = Qx.Qubit.random()
      iex> Qx.Qubit.valid?(random_qubit)
      true
  """
  def random do
    # Generate random complex amplitudes
    alpha_re = :rand.uniform() * 2 - 1
    alpha_im = :rand.uniform() * 2 - 1
    beta_re = :rand.uniform() * 2 - 1
    beta_im = :rand.uniform() * 2 - 1

    alpha = C.new(alpha_re, alpha_im)
    beta = C.new(beta_re, beta_im)
    new(alpha, beta)
  end
end
