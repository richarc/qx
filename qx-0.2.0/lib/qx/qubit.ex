defmodule Qx.Qubit do
  @moduledoc """
  Simplified API for single-qubit quantum operations.

  This module provides a beginner-friendly interface for working with individual
  qubits. Under the hood, it uses `Qx.Register` with `num_qubits=1`, providing
  a clean abstraction for single-qubit operations without exposing multi-qubit
  complexity.

  ## Calculation Mode

  Calculation mode allows you to work with qubits directly, applying gates
  in real-time and seeing results immediately. This is different from circuit
  mode (using `Qx.QuantumCircuit`) where you build a circuit first and then
  execute it.

  In calculation mode:
  - Gates are applied immediately to the quantum state
  - You can inspect the state at any point using `state_vector/1` or `measure_probabilities/1`
  - Results are available instantly without needing to run a simulation
  - Perfect for learning, exploration, and debugging

  ## Example Workflows

      # Basic gate application
      q = Qx.Qubit.new()
        |> Qx.Qubit.h()
        |> Qx.Qubit.state_vector()
      # Returns superposition state

      # Check probabilities at each step
      q = Qx.Qubit.new()
      Qx.Qubit.measure_probabilities(q)  # [1.0, 0.0] - definitely |0⟩

      q = Qx.Qubit.x(q)
      Qx.Qubit.measure_probabilities(q)  # [0.0, 1.0] - definitely |1⟩

      q = Qx.Qubit.h(q)
      Qx.Qubit.measure_probabilities(q)  # [0.5, 0.5] - equal superposition

      # Create and manipulate custom states
      q = Qx.Qubit.new(0.6, 0.8)  # Custom amplitudes (auto-normalized)
        |> Qx.Qubit.rz(:math.pi() / 4)
        |> Qx.Qubit.rx(:math.pi() / 2)

  ## Available Gates

  **Single-Qubit Gates** (no parameters):
  - `h/1` - Hadamard gate (creates superposition)
  - `x/1` - Pauli-X gate (bit flip)
  - `y/1` - Pauli-Y gate (bit and phase flip)
  - `z/1` - Pauli-Z gate (phase flip)
  - `s/1` - S gate (π/2 phase)
  - `t/1` - T gate (π/4 phase)

  **Parameterized Gates**:
  - `rx/2` - Rotation around X-axis
  - `ry/2` - Rotation around Y-axis
  - `rz/2` - Rotation around Z-axis
  - `phase/2` - Arbitrary phase gate

  ## Architecture Note

  This module is implemented as a thin wrapper around `Qx.Register`. All gate
  operations delegate to the Register module, ensuring consistency and reducing
  code duplication. This design provides:
  - Single source of truth for gate implementations
  - Better performance (Register is highly optimized)
  - Easier maintenance
  - Seamless transition when scaling to multi-qubit operations

  ## See Also

  - `Qx.Register` - Multi-qubit calculation mode
  - `Qx.QuantumCircuit` - Circuit mode for building quantum circuits
  - `Qx.Draw.bloch_sphere/2` - Visualize single qubit states
  """

  import Nx.Defn

  alias Qx.Register
  alias Complex, as: C

  @type t :: Nx.Tensor.t()

  # ============================================================================
  # STATE CREATION
  # ============================================================================

  @doc """
  Creates a qubit in the |0⟩ state.

  The |0⟩ state is represented as the state vector [1, 0].

  ## Examples

      iex> Qx.Qubit.new()
      #Nx.Tensor<
        c64[2]
        [1.0+0.0i, 0.0+0.0i]
      >
  """
  def new do
    Register.new(1) |> extract_state()
  end

  @doc """
  Creates a qubit with custom amplitudes.

  The qubit state is automatically normalized to ensure |α|² + |β|² = 1.

  ## Parameters
  - `alpha` - Amplitude for |0⟩ state (real number or Complex)
  - `beta` - Amplitude for |1⟩ state (real number or Complex)

  ## Examples

      iex> q = Qx.Qubit.new(0.6, 0.8)
      iex> Qx.Qubit.valid?(q)
      true

      iex> q = Qx.Qubit.new(1, 1)  # Auto-normalized to (|0⟩ + |1⟩)/√2
      iex> probs = Qx.Qubit.measure_probabilities(q) |> Nx.to_flat_list()
      iex> abs(Enum.at(probs, 0) - 0.5) < 0.01
      true
  """
  def new(alpha, beta) when is_number(alpha) and is_number(beta) do
    state = Nx.tensor([C.new(alpha, 0.0), C.new(beta, 0.0)], type: :c64)
    Qx.Math.normalize(state)
  end

  def new(%C{} = alpha, %C{} = beta) do
    state = Nx.tensor([alpha, beta], type: :c64)
    Qx.Math.normalize(state)
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
    Qx.StateInit.one_state()
  end

  @doc """
  Creates a qubit in the |+⟩ state (equal superposition).

  The |+⟩ state is (|0⟩ + |1⟩)/√2.

  ## Examples

      iex> q = Qx.Qubit.plus()
      iex> probs = Qx.Qubit.measure_probabilities(q) |> Nx.to_flat_list()
      iex> abs(Enum.at(probs, 0) - 0.5) < 0.01
      true
  """
  def plus do
    Qx.StateInit.plus_state()
  end

  @doc """
  Creates a qubit in the |-⟩ state.

  The |-⟩ state is (|0⟩ - |1⟩)/√2.

  ## Examples

      iex> q = Qx.Qubit.minus()
      iex> probs = Qx.Qubit.measure_probabilities(q) |> Nx.to_flat_list()
      iex> abs(Enum.at(probs, 0) - 0.5) < 0.01
      true
  """
  def minus do
    Qx.StateInit.minus_state()
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
    Qx.StateInit.random_state(1)
  end

  @doc """
  Creates a qubit from a computational basis state.

  ## Parameters
    * `basis` - 0 for |0⟩ or 1 for |1⟩

  ## Examples

      iex> q = Qx.Qubit.from_basis(0)
      iex> Qx.Qubit.alpha(q) |> Complex.abs()
      1.0

      iex> q = Qx.Qubit.from_basis(1)
      iex> Qx.Qubit.beta(q) |> Complex.abs()
      1.0
  """
  @spec from_basis(0 | 1) :: t()
  def from_basis(0), do: new()
  def from_basis(1), do: one()

  def from_basis(basis) do
    raise ArgumentError, "Basis must be 0 or 1, got: #{inspect(basis)}"
  end

  @doc """
  Creates a qubit from Bloch sphere coordinates.

  The Bloch sphere is a geometrical representation of a qubit's quantum state.
  Any pure qubit state can be written as:
  |ψ⟩ = cos(θ/2)|0⟩ + e^(iφ)sin(θ/2)|1⟩

  ## Parameters
    * `theta` - Polar angle in radians (0 to π)
    * `phi` - Azimuthal angle in radians (0 to 2π)

  ## Examples

      # Create |0⟩ state (north pole)
      iex> q = Qx.Qubit.from_bloch(0, 0)
      iex> Qx.Qubit.alpha(q) |> Complex.abs() |> Float.round(3)
      1.0

      # Create |1⟩ state (south pole)
      iex> q = Qx.Qubit.from_bloch(:math.pi(), 0)
      iex> Qx.Qubit.beta(q) |> Complex.abs() |> Float.round(3)
      1.0

      # Create |+⟩ state (equator, x-axis)
      iex> q = Qx.Qubit.from_bloch(:math.pi() / 2, 0)
      iex> probs = Qx.Qubit.measure_probabilities(q) |> Nx.to_flat_list()
      iex> abs(Enum.at(probs, 0) - 0.5) < 0.01
      true
  """
  @spec from_bloch(number(), number()) :: t()
  def from_bloch(theta, phi) when is_number(theta) and is_number(phi) do
    alpha = :math.cos(theta / 2)

    beta_magnitude = :math.sin(theta / 2)
    beta = C.multiply(C.new(beta_magnitude, 0.0), C.from_polar(1.0, phi))

    new(C.new(alpha, 0.0), beta)
  end

  @doc """
  Creates a qubit from angle (simplified Bloch sphere).

  This is a simplified version of `from_bloch/2` where phi=0.
  Useful for creating states along the X-Z plane of the Bloch sphere.

  ## Parameters
    * `theta` - Polar angle in radians (0 to π)

  ## Examples

      # Create superposition |+⟩
      iex> q = Qx.Qubit.from_angle(:math.pi() / 2)
      iex> probs = Qx.Qubit.measure_probabilities(q) |> Nx.to_flat_list()
      iex> abs(Enum.at(probs, 0) - 0.5) < 0.01
      true
  """
  @spec from_angle(number()) :: t()
  def from_angle(theta) when is_number(theta) do
    from_bloch(theta, 0.0)
  end

  # ============================================================================
  # GATE OPERATIONS (delegate to Register)
  # ============================================================================

  @doc """
  Applies a Hadamard gate to a qubit in calculation mode.

  The Hadamard gate creates superposition by transforming:
  - |0⟩ → (|0⟩ + |1⟩)/√2
  - |1⟩ → (|0⟩ - |1⟩)/√2

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.h()
      iex> probs = Qx.Qubit.measure_probabilities(q) |> Nx.to_flat_list()
      iex> abs(Enum.at(probs, 0) - 0.5) < 0.01
      true
  """
  def h(qubit) do
    qubit |> wrap() |> Register.h(0) |> extract_state()
  end

  @doc """
  Applies a Pauli-X gate (bit flip) to a qubit.

  Transforms |0⟩ ↔ |1⟩.

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.x()
      iex> probs = Qx.Qubit.measure_probabilities(q) |> Nx.to_flat_list()
      iex> Enum.at(probs, 1)
      1.0
  """
  def x(qubit) do
    qubit |> wrap() |> Register.x(0) |> extract_state()
  end

  @doc """
  Applies a Pauli-Y gate to a qubit.

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.y()
      iex> Qx.Qubit.valid?(q)
      true
  """
  def y(qubit) do
    qubit |> wrap() |> Register.y(0) |> extract_state()
  end

  @doc """
  Applies a Pauli-Z gate (phase flip) to a qubit.

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.z()
      iex> Qx.Qubit.valid?(q)
      true
  """
  def z(qubit) do
    qubit |> wrap() |> Register.z(0) |> extract_state()
  end

  @doc """
  Applies an S gate (π/2 phase) to a qubit.

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.s()
      iex> Qx.Qubit.valid?(q)
      true
  """
  def s(qubit) do
    qubit |> wrap() |> Register.s(0) |> extract_state()
  end

  @doc """
  Applies a T gate (π/4 phase) to a qubit.

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.t()
      iex> Qx.Qubit.valid?(q)
      true
  """
  def t(qubit) do
    qubit |> wrap() |> Register.t(0) |> extract_state()
  end

  @doc """
  Applies a rotation around the X-axis.

  ## Parameters
  - `qubit` - The qubit state
  - `theta` - Rotation angle in radians

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.rx(:math.pi())
      iex> probs = Qx.Qubit.measure_probabilities(q) |> Nx.to_flat_list()
      iex> abs(Enum.at(probs, 1) - 1.0) < 0.01
      true
  """
  def rx(qubit, theta) do
    qubit |> wrap() |> Register.rx(0, theta) |> extract_state()
  end

  @doc """
  Applies a rotation around the Y-axis.

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.ry(:math.pi() / 2)
      iex> probs = Qx.Qubit.measure_probabilities(q) |> Nx.to_flat_list()
      iex> abs(Enum.at(probs, 0) - 0.5) < 0.01
      true
  """
  def ry(qubit, theta) do
    qubit |> wrap() |> Register.ry(0, theta) |> extract_state()
  end

  @doc """
  Applies a rotation around the Z-axis.

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.h() |> Qx.Qubit.rz(:math.pi() / 4)
      iex> Qx.Qubit.valid?(q)
      true
  """
  def rz(qubit, theta) do
    qubit |> wrap() |> Register.rz(0, theta) |> extract_state()
  end

  @doc """
  Applies an arbitrary phase gate.

  ## Parameters
  - `qubit` - The qubit state
  - `phi` - Phase angle in radians

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.phase(:math.pi() / 4)
      iex> Qx.Qubit.valid?(q)
      true
  """
  def phase(qubit, phi) do
    qubit |> wrap() |> Register.phase(0, phi) |> extract_state()
  end

  # ============================================================================
  # CONVENIENCE ACCESSORS (unique to Qubit)
  # ============================================================================

  @doc """
  Gets the amplitude for the |0⟩ state.

  ## Examples

      iex> qubit = Qx.Qubit.new(0.6, 0.8)
      iex> alpha = Qx.Qubit.alpha(qubit)
      iex> abs(Complex.abs(alpha) - 0.6) < 0.01
      true
  """
  def alpha(qubit) do
    Nx.to_number(qubit[0])
  end

  @doc """
  Gets the amplitude for the |1⟩ state.

  ## Examples

      iex> qubit = Qx.Qubit.new(0.6, 0.8)
      iex> beta = Qx.Qubit.beta(qubit)
      iex> abs(Complex.abs(beta) - 0.8) < 0.01
      true
  """
  def beta(qubit) do
    Nx.to_number(qubit[1])
  end

  # ============================================================================
  # STATE INSPECTION
  # ============================================================================

  @doc """
  Returns the state vector of the qubit.

  ## Examples

      iex> q = Qx.Qubit.new()
      iex> Qx.Qubit.state_vector(q)
      #Nx.Tensor<
        c64[2]
        [1.0+0.0i, 0.0+0.0i]
      >
  """
  def state_vector(qubit) do
    qubit
  end

  @doc """
  Measures a qubit and returns the probability of measuring |0⟩ and |1⟩.

  ## Examples

      iex> qubit = Qx.Qubit.plus()
      iex> probs = Qx.Qubit.measure_probabilities(qubit)
      iex> Nx.shape(probs)
      {2}
  """
  defn measure_probabilities(qubit) do
    Qx.Math.probabilities(qubit)
  end

  @doc """
  Returns a human-readable representation of the qubit state.

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.h()
      iex> info = Qx.Qubit.show_state(q)
      iex> is_map(info)
      true
  """
  def show_state(qubit) do
    qubit |> wrap() |> Register.show_state()
  end

  @doc """
  Inspects and prints the qubit state, then returns the qubit unchanged.

  This is useful for debugging in pipelines without breaking the chain.

  ## Options
  - `:label` - Custom label for the output (default: "Qubit State")
  - `:verbose` - Show detailed probabilities (default: false)

  ## Examples

      iex> q = Qx.Qubit.new()
      ...>   |> Qx.Qubit.h()
      ...>   |> Qx.Qubit.tap_state(label: "After Hadamard")
      ...>   |> Qx.Qubit.x()
      iex> Qx.Qubit.valid?(q)
      true
  """
  def tap_state(qubit, opts \\ []) do
    state_info = show_state(qubit)
    label = Keyword.get(opts, :label, "Qubit State")

    IO.puts("\n#{label}: #{state_info.state}")

    if Keyword.get(opts, :verbose, false) do
      IO.puts("  Probabilities:")

      Enum.each(state_info.probabilities, fn {basis, prob} ->
        if prob > 1.0e-6 do
          IO.puts("    #{basis}: #{Float.round(prob, 6)}")
        end
      end)
    end

    qubit
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
    Qx.Validation.valid_qubit?(state)
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  # Wraps a state vector in a Register struct
  defp wrap(state) when is_struct(state, Nx.Tensor) do
    %Register{num_qubits: 1, state: state}
  end

  # Extracts state vector from Register
  defp extract_state(%Register{state: state}), do: state
end
