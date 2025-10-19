defmodule Qx.Qubit do
  @moduledoc """
  Functions for creating and manipulating quantum qubits in calculation mode.

  This module provides the fundamental building blocks for quantum computing
  simulations by handling individual qubit states and ensuring they meet
  the normalization requirements of quantum mechanics.

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
      # Returns superposition state: [0.707+0.0i, 0.707+0.0i]

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

  ## State Inspection

  Two main functions for examining qubit states:

  - `state_vector/1` - Returns the complex probability amplitudes [α, β]
  - `measure_probabilities/1` - Returns the measurement probabilities [|α|², |β|²]

  Use `state_vector/1` when you need to see phase information (important for
  interference effects). Use `measure_probabilities/1` when you want to know
  what you'd measure if you observed the qubit.

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

  ## Comparison: Calculation Mode vs Circuit Mode

      # Circuit Mode (Qx.QuantumCircuit)
      qc = Qx.create_circuit(1)
        |> Qx.h(0)
        |> Qx.x(0)
      # Can't inspect state here - gates not applied yet!

      result = Qx.run(qc)  # Execute the circuit
      result.probabilities  # See results only after running

      # Calculation Mode (Qx.Qubit)
      q = Qx.Qubit.new()
        |> Qx.Qubit.h()
      Qx.Qubit.state_vector(q)  # Can inspect immediately!

      q = Qx.Qubit.x(q)
      Qx.Qubit.state_vector(q)  # Inspect at any step!

  ## See Also

  - `Qx.Register` - Multi-qubit calculation mode
  - `Qx.QuantumCircuit` - Circuit mode for building quantum circuits
  - `Qx.Draw.bloch_sphere/2` - Visualize single qubit states
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
      iex> probs = Qx.Qubit.measure_probabilities(qubit)
      iex> Nx.shape(probs)
      {2}
      iex> [p0, p1] = Nx.to_flat_list(probs)
      iex> abs(p0 - 0.5) < 0.01 and abs(p1 - 0.5) < 0.01
      true
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
      iex> alpha = Qx.Qubit.alpha(qubit)
      iex> abs(Complex.abs(alpha) - 0.6) < 0.01
      true
  """
  def alpha(qubit) do
    # Extract the first complex number from c64 tensor
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

  # ============================================================================
  # Calculation Mode - Gate Operations
  # ============================================================================

  @doc """
  Applies a Hadamard gate to a qubit in calculation mode.

  The Hadamard gate creates superposition, transforming |0⟩ to (|0⟩ + |1⟩)/√2
  and |1⟩ to (|0⟩ - |1⟩)/√2. The gate is applied immediately and returns the
  updated state.

  ## Examples

      # Create superposition from |0⟩
      iex> q = Qx.Qubit.new() |> Qx.Qubit.h()
      iex> probs = Qx.Qubit.measure_probabilities(q)
      iex> [p0, p1] = Nx.to_flat_list(probs)
      iex> abs(p0 - 0.5) < 0.01 and abs(p1 - 0.5) < 0.01
      true

      # Apply to |1⟩
      iex> q = Qx.Qubit.one() |> Qx.Qubit.h()
      iex> probs = Qx.Qubit.measure_probabilities(q)
      iex> [p0, p1] = Nx.to_flat_list(probs)
      iex> abs(p0 - 0.5) < 0.01 and abs(p1 - 0.5) < 0.01
      true
  """
  def h(qubit) do
    gate_matrix = Qx.Gates.hadamard()
    Nx.dot(gate_matrix, qubit)
  end

  @doc """
  Applies a Pauli-X gate (bit flip) to a qubit in calculation mode.

  The X gate flips |0⟩ to |1⟩ and |1⟩ to |0⟩. The gate is applied immediately
  and returns the updated state.

  ## Examples

      # Flip |0⟩ to |1⟩
      iex> q = Qx.Qubit.new() |> Qx.Qubit.x()
      iex> Qx.Qubit.measure_probabilities(q)
      #Nx.Tensor<
        f32[2]
        [0.0, 1.0]
      >

      # Chain with other gates
      iex> q = Qx.Qubit.new() |> Qx.Qubit.x() |> Qx.Qubit.h()
      iex> Qx.Qubit.valid?(q)
      true
  """
  def x(qubit) do
    gate_matrix = Qx.Gates.pauli_x()
    Nx.dot(gate_matrix, qubit)
  end

  @doc """
  Applies a Pauli-Y gate to a qubit in calculation mode.

  The Y gate applies both bit flip and phase flip transformations.
  The gate is applied immediately and returns the updated state.

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.y()
      iex> Qx.Qubit.valid?(q)
      true
  """
  def y(qubit) do
    gate_matrix = Qx.Gates.pauli_y()
    Nx.dot(gate_matrix, qubit)
  end

  @doc """
  Applies a Pauli-Z gate (phase flip) to a qubit in calculation mode.

  The Z gate leaves |0⟩ unchanged and applies a phase of -1 to |1⟩.
  The gate is applied immediately and returns the updated state.

  ## Examples

      # Z has no effect on |0⟩
      iex> q = Qx.Qubit.new() |> Qx.Qubit.z()
      iex> Qx.Qubit.measure_probabilities(q)
      #Nx.Tensor<
        f32[2]
        [1.0, 0.0]
      >

      # Creates phase difference in superposition
      iex> q = Qx.Qubit.new() |> Qx.Qubit.h() |> Qx.Qubit.z()
      iex> Qx.Qubit.valid?(q)
      true
  """
  def z(qubit) do
    gate_matrix = Qx.Gates.pauli_z()
    Nx.dot(gate_matrix, qubit)
  end

  @doc """
  Applies an S gate (phase gate with π/2 phase) to a qubit in calculation mode.

  The S gate applies a phase of i to the |1⟩ component.
  The gate is applied immediately and returns the updated state.

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.s()
      iex> Qx.Qubit.valid?(q)
      true
  """
  def s(qubit) do
    gate_matrix = Qx.Gates.s_gate()
    Nx.dot(gate_matrix, qubit)
  end

  @doc """
  Applies a T gate (phase gate with π/4 phase) to a qubit in calculation mode.

  The T gate applies a phase of e^(iπ/4) to the |1⟩ component.
  The gate is applied immediately and returns the updated state.

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.t()
      iex> Qx.Qubit.valid?(q)
      true
  """
  def t(qubit) do
    gate_matrix = Qx.Gates.t_gate()
    Nx.dot(gate_matrix, qubit)
  end

  @doc """
  Applies a rotation around the X-axis to a qubit in calculation mode.

  ## Parameters
    * `qubit` - The qubit state tensor
    * `theta` - Rotation angle in radians

  ## Examples

      # π/2 rotation
      iex> q = Qx.Qubit.new() |> Qx.Qubit.rx(:math.pi() / 2)
      iex> Qx.Qubit.valid?(q)
      true

      # Full rotation (2π) returns to original state
      iex> q = Qx.Qubit.new() |> Qx.Qubit.rx(2 * :math.pi())
      iex> probs = Qx.Qubit.measure_probabilities(q)
      iex> [p0, _p1] = Nx.to_flat_list(probs)
      iex> abs(p0 - 1.0) < 0.01
      true
  """
  def rx(qubit, theta) do
    gate_matrix = Qx.Gates.rx(theta)
    Nx.dot(gate_matrix, qubit)
  end

  @doc """
  Applies a rotation around the Y-axis to a qubit in calculation mode.

  ## Parameters
    * `qubit` - The qubit state tensor
    * `theta` - Rotation angle in radians

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.ry(:math.pi() / 2)
      iex> Qx.Qubit.valid?(q)
      true
  """
  def ry(qubit, theta) do
    gate_matrix = Qx.Gates.ry(theta)
    Nx.dot(gate_matrix, qubit)
  end

  @doc """
  Applies a rotation around the Z-axis to a qubit in calculation mode.

  ## Parameters
    * `qubit` - The qubit state tensor
    * `theta` - Rotation angle in radians

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.rz(:math.pi() / 4)
      iex> Qx.Qubit.valid?(q)
      true
  """
  def rz(qubit, theta) do
    gate_matrix = Qx.Gates.rz(theta)
    Nx.dot(gate_matrix, qubit)
  end

  @doc """
  Applies a phase gate with specified phase to a qubit in calculation mode.

  ## Parameters
    * `qubit` - The qubit state tensor
    * `phi` - Phase angle in radians

  ## Examples

      iex> q = Qx.Qubit.new() |> Qx.Qubit.phase(:math.pi() / 4)
      iex> Qx.Qubit.valid?(q)
      true
  """
  def phase(qubit, phi) do
    gate_matrix = Qx.Gates.phase(phi)
    Nx.dot(gate_matrix, qubit)
  end

  @doc """
  Returns the state vector of a qubit.

  This function provides explicit access to the qubit's state vector, showing
  the complex probability amplitudes for the |0⟩ and |1⟩ basis states.

  The state vector is the tensor itself, but this function makes it explicit
  for inspection in calculation mode workflows.

  ## Returns
  An Nx.Tensor of shape {2} containing the complex amplitudes [α, β] where
  the qubit state is α|0⟩ + β|1⟩.

  ## Examples

      # Inspect state after applying gates
      iex> q = Qx.Qubit.new() |> Qx.Qubit.h()
      iex> state = Qx.Qubit.state_vector(q)
      iex> Nx.shape(state)
      {2}

      # See the amplitudes
      iex> q = Qx.Qubit.new() |> Qx.Qubit.x()
      iex> state = Qx.Qubit.state_vector(q)
      iex> alpha = Qx.Qubit.alpha(state)
      iex> beta = Qx.Qubit.beta(state)
      iex> abs(Complex.abs(alpha) - 0.0) < 0.01 and abs(Complex.abs(beta) - 1.0) < 0.01
      true

  ## See Also
    * `measure_probabilities/1` - Get measurement probabilities instead of amplitudes
    * `alpha/1` - Extract the |0⟩ amplitude
    * `beta/1` - Extract the |1⟩ amplitude
  """
  def state_vector(qubit) do
    qubit
  end
end
