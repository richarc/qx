defmodule Qx.Qubit do
  @moduledoc """
  Functions for creating and manipulating quantum qubits.

  This module provides the fundamental building blocks for quantum computing
  simulations by handling individual qubit states and ensuring they meet
  the normalization requirements of quantum mechanics.
  """

  import Nx.Defn
  alias Qx.Math

  @doc """
  Creates a new qubit in the default |0⟩ state.

  ## Examples

      iex> Qx.Qubit.new()
      #Nx.Tensor<
        f32[2]
        [1.0, 0.0]
      >
  """
  def new do
    Nx.tensor([1.0, 0.0])
  end

  @doc """
  Creates a new qubit with specified alpha and beta coefficients.

  The qubit state is represented as α|0⟩ + β|1⟩, where |α|² + |β|² = 1.
  This function automatically normalizes the coefficients to ensure the
  qubit meets quantum mechanics normalization requirements.

  ## Parameters
    * `alpha` - Coefficient for the |0⟩ state
    * `beta` - Coefficient for the |1⟩ state

  ## Examples

      iex> Qx.Qubit.new(1.0, 1.0)
      #Nx.Tensor<
        f32[2]
        [0.7071067690849304, 0.7071067690849304]
      >

      iex> Qx.Qubit.new(1.0, 0.0)
      #Nx.Tensor<
        f32[2]
        [1.0, 0.0]
      >
  """
  def new(alpha, beta) do
    state = Nx.tensor([alpha, beta])
    Math.normalize(state)
  end

  @doc """
  Creates a qubit in the |1⟩ state.

  ## Examples

      iex> Qx.Qubit.one()
      #Nx.Tensor<
        f32[2]
        [0.0, 1.0]
      >
  """
  def one do
    Nx.tensor([0.0, 1.0])
  end

  @doc """
  Creates a qubit in the |+⟩ state (equal superposition).

  The |+⟩ state is (|0⟩ + |1⟩)/√2.

  ## Examples

      iex> Qx.Qubit.plus()
      #Nx.Tensor<
        f32[2]
        [0.7071067690849304, 0.7071067690849304]
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
        f32[2]
        [0.7071067690849304, -0.7071067690849304]
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
  1. Have exactly 2 components
  2. Be normalized (|α|² + |β|² = 1)

  ## Examples

      iex> valid_qubit = Nx.tensor([0.6, 0.8])
      iex> Qx.Qubit.valid?(valid_qubit)
      true

      iex> invalid_qubit = Nx.tensor([1.0, 1.0])
      iex> Qx.Qubit.valid?(invalid_qubit)
      false
  """
  def valid?(state) do
    case Nx.shape(state) do
      {2} ->
        norm_squared = Nx.sum(Nx.abs(state) ** 2) |> Nx.to_number()
        abs(norm_squared - 1.0) < 1.0e-10

      _ ->
        false
    end
  end

  @doc """
  Gets the amplitude for the |0⟩ state.

  ## Examples

      iex> qubit = Qx.Qubit.new(0.6, 0.8)
      iex> Qx.Qubit.alpha(qubit)
      #Nx.Tensor<
        f32
        0.6000000238418579
      >
  """
  defn alpha(qubit) do
    qubit[0]
  end

  @doc """
  Gets the amplitude for the |1⟩ state.

  ## Examples

      iex> qubit = Qx.Qubit.new(0.6, 0.8)
      iex> Qx.Qubit.beta(qubit)
      #Nx.Tensor<
        f32
        0.7999999523162842
      >
  """
  defn beta(qubit) do
    qubit[1]
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
    # Random between -1 and 1
    alpha = :rand.uniform() * 2 - 1
    # Random between -1 and 1
    beta = :rand.uniform() * 2 - 1
    new(alpha, beta)
  end
end
