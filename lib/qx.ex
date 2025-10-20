defmodule Qx do
  @moduledoc """
  Qx - A Quantum Computing Simulator for Elixir

  Qx provides a simple and intuitive API for quantum computing simulations.
  It supports up to 20 qubits with statevector simulation using Nx as the
  computational backend for efficient processing.

  ## Example Usage

      # Create a Bell state circuit
      qc = Qx.create_circuit(2, 2)
      |> Qx.h(0)
      |> Qx.cx(0, 1)
      |> Qx.measure(0, 0)
      |> Qx.measure(1, 1)

      result = Qx.run(qc)
      Qx.draw(result)

  ## Modules

  The Qx library consists of several modules:

  - `Qx` - Main API (this module)
  - `Qx.Qubit` - Functions for qubit creation and manipulation
  - `Qx.QuantumCircuit` - Quantum circuit creation and management
  - `Qx.Operations` - Quantum gate operations
  - `Qx.Simulation` - Circuit execution and simulation
  - `Qx.Draw` - Visualization of results
  - `Qx.Math` - Core mathematical functions for quantum mechanics
  """

  alias Qx.{QuantumCircuit, Operations, Simulation, Draw}

  @type circuit :: QuantumCircuit.t()
  @type simulation_result :: Simulation.simulation_result()

  @doc """
  Creates a new quantum circuit with specified qubits and classical bits.

  ## Parameters
    * `num_qubits` - Number of qubits (1-20)
    * `num_classical_bits` - Number of classical bits for measurements

  ## Examples

      iex> qc = Qx.create_circuit(2, 2)
      iex> qc.num_qubits
      2
      iex> qc.num_classical_bits
      2
  """
  @spec create_circuit(pos_integer(), non_neg_integer()) :: circuit()
  defdelegate create_circuit(num_qubits, num_classical_bits), to: QuantumCircuit, as: :new

  @doc """
  Creates a new quantum circuit with only qubits (no classical bits).

  ## Parameters
    * `num_qubits` - Number of qubits (1-20)

  ## Examples

      iex> qc = Qx.create_circuit(3)
      iex> qc.num_qubits
      3
      iex> qc.num_classical_bits
      0
  """
  @spec create_circuit(pos_integer()) :: circuit()
  defdelegate create_circuit(num_qubits), to: QuantumCircuit, as: :new

  @doc """
  Applies a Hadamard gate to the specified qubit.

  Creates superposition: |0⟩ → (|0⟩ + |1⟩)/√2, |1⟩ → (|0⟩ - |1⟩)/√2

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.h(0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1
  """
  @spec h(circuit(), non_neg_integer()) :: circuit()
  defdelegate h(circuit, qubit), to: Operations

  @doc """
  Applies a Pauli-X gate (bit flip) to the specified qubit.

  Flips |0⟩ ↔ |1⟩

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.x(0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1
  """
  @spec x(circuit(), non_neg_integer()) :: circuit()
  defdelegate x(circuit, qubit), to: Operations

  @doc """
  Applies a Pauli-Y gate to the specified qubit.

  Combines bit flip and phase flip transformations.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.y(0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1
  """
  @spec y(circuit(), non_neg_integer()) :: circuit()
  defdelegate y(circuit, qubit), to: Operations

  @doc """
  Applies a Pauli-Z gate (phase flip) to the specified qubit.

  Leaves |0⟩ unchanged, applies -1 phase to |1⟩

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.z(0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1
  """
  @spec z(circuit(), non_neg_integer()) :: circuit()
  defdelegate z(circuit, qubit), to: Operations

  @doc """
  Applies a controlled-X (CNOT) gate.

  Flips target qubit if and only if control qubit is |1⟩

  ## Parameters
    * `circuit` - Quantum circuit
    * `control_qubit` - Control qubit index
    * `target_qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.cx(0, 1)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1
  """
  @spec cx(circuit(), non_neg_integer(), non_neg_integer()) :: circuit()
  defdelegate cx(circuit, control_qubit, target_qubit), to: Operations

  @doc """
  Applies a controlled-controlled-X (CCNOT/Toffoli) gate.

  Flips target qubit if and only if both control qubits are |1⟩

  ## Parameters
    * `circuit` - Quantum circuit
    * `control1` - First control qubit index
    * `control2` - Second control qubit index
    * `target` - Target qubit index

  ## Examples

      iex> qc = Qx.create_circuit(3) |> Qx.ccx(0, 1, 2)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1
  """
  @spec ccx(circuit(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: circuit()
  defdelegate ccx(circuit, control1, control2, target), to: Operations

  @doc """
  Applies an S gate (phase gate with π/2 phase).

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.s(0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1
  """
  @spec s(circuit(), non_neg_integer()) :: circuit()
  defdelegate s(circuit, qubit), to: Operations

  @doc """
  Applies a T gate (phase gate with π/4 phase).

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.t(0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1
  """
  @spec t(circuit(), non_neg_integer()) :: circuit()
  defdelegate t(circuit, qubit), to: Operations

  @doc """
  Applies a rotation around the X-axis.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index
    * `theta` - Rotation angle in radians

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.rx(0, :math.pi/2)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1
  """
  @spec rx(circuit(), non_neg_integer(), float()) :: circuit()
  defdelegate rx(circuit, qubit, theta), to: Operations

  @doc """
  Applies a rotation around the Y-axis.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index
    * `theta` - Rotation angle in radians

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.ry(0, :math.pi/2)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1
  """
  @spec ry(circuit(), non_neg_integer(), float()) :: circuit()
  defdelegate ry(circuit, qubit, theta), to: Operations

  @doc """
  Applies a rotation around the Z-axis.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index
    * `theta` - Rotation angle in radians

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.rz(0, :math.pi/2)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1
  """
  @spec rz(circuit(), non_neg_integer(), float()) :: circuit()
  defdelegate rz(circuit, qubit, theta), to: Operations

  @doc """
  Applies a phase gate with specified phase.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index
    * `phi` - Phase angle in radians

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.phase(0, :math.pi/4)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1
  """
  @spec phase(circuit(), non_neg_integer(), float()) :: circuit()
  defdelegate phase(circuit, qubit, phi), to: Operations

  @doc """
  Adds a measurement operation to the circuit.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Qubit index to measure
    * `classical_bit` - Classical bit index to store result

  ## Examples

      iex> qc = Qx.create_circuit(2, 2) |> Qx.measure(0, 0)
      iex> length(Qx.QuantumCircuit.get_measurements(qc))
      1
  """
  @spec measure(circuit(), non_neg_integer(), non_neg_integer()) :: circuit()
  defdelegate measure(circuit, qubit, classical_bit), to: Operations

  @doc """
  Applies gates conditionally based on a classical bit value.

  Enables mid-circuit measurement with classical feedback - a key capability
  for quantum error correction, quantum teleportation, and adaptive algorithms.

  ## Parameters
    * `circuit` - Quantum circuit
    * `classical_bit` - Classical bit index to check (must have been measured)
    * `value` - Value to compare (0 or 1)
    * `gate_fn` - Function that applies gates when condition is true

  ## Examples

      # Apply X gate to qubit 1 if classical bit 0 equals 1
      iex> qc = Qx.create_circuit(2, 2)
      ...> |> Qx.h(0)
      ...> |> Qx.measure(0, 0)
      ...> |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      3

      # Multiple gates in conditional block
      iex> qc = Qx.create_circuit(3, 2)
      ...> |> Qx.measure(0, 0)
      ...> |> Qx.c_if(0, 1, fn c ->
      ...>      c |> Qx.x(1) |> Qx.h(2)
      ...>    end)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      2

  ## See Also
    * OpenQASM 3.0 if-statements for hardware compatibility
    * Quantum teleportation example in documentation
  """
  @spec c_if(circuit(), non_neg_integer(), 0 | 1, (circuit() -> circuit())) :: circuit()
  defdelegate c_if(circuit, classical_bit, value, gate_fn), to: Operations

  @doc """
  Executes the quantum circuit and returns simulation results.

  ## Parameters
    * `circuit` - Quantum circuit to execute
    * `shots` - Number of measurement shots (default: 1024)

  ## Returns
  A map containing:
    * `:probabilities` - Probability amplitudes for all states
    * `:classical_bits` - List of measurement results
    * `:state` - Final quantum state vector
    * `:shots` - Number of shots performed
    * `:counts` - Frequency count of measurement outcomes

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.h(0)
      iex> result = Qx.run(qc)
      iex> is_map(result)
      true
      iex> Map.has_key?(result, :probabilities)
      true
  """
  @spec run(circuit(), pos_integer()) :: simulation_result()
  defdelegate run(circuit, shots \\ 1024), to: Simulation

  @doc """
  Executes a circuit and returns only the final quantum state.

  ## Parameters
    * `circuit` - Quantum circuit to execute

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.h(0)
      iex> state = Qx.get_state(qc)
      iex> Nx.shape(state)
      {2}
  """
  @spec get_state(circuit()) :: Nx.Tensor.t()
  defdelegate get_state(circuit), to: Simulation

  @doc """
  Gets probability distribution for computational basis states.

  ## Parameters
    * `circuit` - Quantum circuit

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.h(0)
      iex> probs = Qx.get_probabilities(qc)
      iex> Nx.shape(probs)
      {2}
  """
  @spec get_probabilities(circuit()) :: Nx.Tensor.t()
  defdelegate get_probabilities(circuit), to: Simulation, as: :get_probabilities

  @doc """
  Visualizes probability distribution from simulation results.

  Convenience function for quickly plotting the probability distribution
  from a simulation result. The probabilities are automatically extracted
  from the result map.

  For plotting raw probability tensors (e.g., from `get_probabilities/1`),
  use `histogram/2` instead.

  ## Parameters
    * `result` - Simulation result from `run/1` or `run/2`
    * `options` - Optional plotting parameters

  ## Options
    * `:format` - `:vega_lite` (default) or `:svg`
    * `:title` - Plot title
    * `:width` - Plot width (default: 400)
    * `:height` - Plot height (default: 300)

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
      iex> result = Qx.run(qc)
      iex> plot = Qx.draw(result)
      iex> is_map(plot) or is_binary(plot)
      true

  ## See Also
    * `histogram/2` - For plotting raw probability tensors
    * `draw_counts/2` - For plotting measurement counts
  """
  @spec draw(simulation_result(), keyword()) :: VegaLite.t() | String.t()
  defdelegate draw(result, options \\ []), to: Draw, as: :plot

  @doc """
  Visualizes measurement counts as a bar chart.

  ## Parameters
    * `result` - Simulation result containing measurement data
    * `options` - Optional plotting parameters

  ## Examples

      iex> qc = Qx.create_circuit(2, 2) |> Qx.h(0) |> Qx.measure(0, 0)
      iex> result = Qx.run(qc)
      iex> plot = Qx.draw_counts(result)
      iex> is_map(plot) or is_binary(plot)
      true
  """
  @spec draw_counts(simulation_result(), keyword()) :: VegaLite.t() | String.t()
  defdelegate draw_counts(result, options \\ []), to: Draw, as: :plot_counts

  @doc """
  Creates a histogram from a raw probability tensor.

  Use this function when you have a probability tensor and want to visualize it.
  This is useful for:
  - Plotting probabilities from `get_probabilities/1` without running simulation
  - Visualizing custom or theoretical probability distributions
  - Comparing different probability distributions

  For quick visualization of simulation results, use `draw/2` instead.

  ## Parameters
    * `probabilities` - Nx tensor of probabilities (should sum to 1.0)
    * `options` - Optional plotting parameters

  ## Examples

      # Visualize probabilities without full simulation
      iex> qc = Qx.create_circuit(2) |> Qx.h(0)
      iex> probs = Qx.get_probabilities(qc)
      iex> hist = Qx.histogram(probs)
      iex> is_map(hist) or is_binary(hist)
      true

  ## See Also
    * `draw/2` - For plotting from simulation results
    * `get_probabilities/1` - To obtain probability tensors
  """
  @spec histogram(Nx.Tensor.t(), keyword()) :: VegaLite.t() | String.t()
  defdelegate histogram(probabilities, options \\ []), to: Draw

  @doc """
  Visualizes a single qubit state on the Bloch sphere.

  The Bloch sphere provides a geometric representation of a pure qubit state.
  This visualization is particularly useful for understanding single-qubit gates
  and state transformations in calculation mode.

  ## Parameters
    * `qubit` - Single qubit state tensor (from `Qx.Qubit`)
    * `options` - Optional plotting parameters

  ## Options
    * `:format` - `:vega_lite` (default) or `:svg`
    * `:title` - Plot title (default: "Bloch Sphere")
    * `:size` - Sphere size (default: 400)

  ## Examples

      # Visualize |0⟩ state
      iex> q = Qx.Qubit.new()
      iex> plot = Qx.draw_bloch(q)
      iex> is_map(plot) or is_binary(plot)
      true

      # Visualize superposition state
      iex> q = Qx.Qubit.new() |> Qx.Qubit.h()
      iex> plot = Qx.draw_bloch(q, title: "Superposition State")
      iex> is_map(plot) or is_binary(plot)
      true

  ## See Also
    * `Qx.Qubit` - Calculation mode for single qubits
    * `draw_state/2` - Display multi-qubit state as table
  """
  @spec draw_bloch(Nx.Tensor.t(), keyword()) :: VegaLite.t() | String.t()
  defdelegate draw_bloch(qubit, options \\ []), to: Draw, as: :bloch_sphere

  @doc """
  Displays a quantum state as a formatted table.

  Shows basis states with their amplitudes and probabilities. Useful for
  inspecting multi-qubit states in calculation mode.

  ## Parameters
    * `register_or_state` - `Qx.Register.t()` or state tensor
    * `options` - Optional display parameters

  ## Options
    * `:format` - `:text` (default) or `:html`
    * `:precision` - Decimal places (default: 3)
    * `:hide_zeros` - Hide zero-amplitude states (default: false)

  ## Examples

      # Display Bell state
      iex> reg = Qx.Register.new(2) |> Qx.Register.h(0) |> Qx.Register.cx(0, 1)
      iex> table = Qx.draw_state(reg)
      iex> is_binary(table)
      true

      # Hide zero states
      iex> reg = Qx.Register.new(3) |> Qx.Register.h(0)
      iex> table = Qx.draw_state(reg, hide_zeros: true)
      iex> is_binary(table)
      true

  ## See Also
    * `Qx.Register` - Calculation mode for multi-qubit systems
    * `draw_bloch/2` - Bloch sphere visualization for single qubits
  """
  @spec draw_state(Qx.Register.t() | Nx.Tensor.t(), keyword()) :: String.t()
  defdelegate draw_state(register_or_state, options \\ []), to: Draw, as: :state_table

  # Convenience functions for creating common quantum states and circuits

  @doc """
  Creates a Bell state circuit (maximally entangled two-qubit state).

  Returns a circuit that prepares the |Φ+⟩ = (|00⟩ + |11⟩)/√2 Bell state.

  ## Examples

      iex> bell_circuit = Qx.bell_state()
      iex> bell_circuit.num_qubits
      2
  """
  @spec bell_state() :: circuit()
  def bell_state do
    create_circuit(2)
    |> h(0)
    |> cx(0, 1)
  end

  @doc """
  Creates a GHZ state circuit (three-qubit entangled state).

  Returns a circuit that prepares |GHZ⟩ = (|000⟩ + |111⟩)/√2.

  ## Examples

      iex> ghz_circuit = Qx.ghz_state()
      iex> ghz_circuit.num_qubits
      3
  """
  @spec ghz_state() :: circuit()
  def ghz_state do
    create_circuit(3)
    |> h(0)
    |> cx(0, 1)
    |> cx(1, 2)
  end

  @doc """
  Creates a superposition state on a single qubit.

  Returns a circuit with a Hadamard gate applied to qubit 0.

  ## Examples

      iex> sup_circuit = Qx.superposition()
      iex> sup_circuit.num_qubits
      1
  """
  @spec superposition() :: circuit()
  def superposition do
    create_circuit(1) |> h(0)
  end

  @doc """
  Returns version information for the Qx library.

  ## Examples

      iex> version = Qx.version()
      iex> is_binary(version)
      true
  """
  @spec version() :: String.t()
  def version do
    case Application.spec(:qx, :vsn) do
      nil -> "unknown"
      vsn -> List.to_string(vsn)
    end
  end
end
