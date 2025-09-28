defmodule Qx.QuantumCircuit do
  @moduledoc """
  Functions for creating and managing quantum circuits.

  This module provides the core structure for quantum circuits, maintaining
  circuit state and instruction lists that can be passed to the simulator
  for execution.
  """

  @type instruction :: {atom(), list(), list()}
  @type measurement :: {integer(), integer()}

  @type t :: %__MODULE__{
          num_qubits: integer(),
          num_classical_bits: integer(),
          state: Nx.Tensor.t(),
          instructions: list(instruction()),
          measurements: list(measurement()),
          measured_qubits: MapSet.t()
        }

  defstruct [
    :num_qubits,
    :num_classical_bits,
    :state,
    instructions: [],
    measurements: [],
    measured_qubits: MapSet.new()
  ]

  @doc """
  Creates a new quantum circuit with specified number of qubits and classical bits.

  All qubits are initialized in the |0⟩ state, and all classical bits are
  initialized to 0.

  ## Parameters
    * `num_qubits` - Number of qubits in the circuit
    * `num_classical_bits` - Number of classical bits for measurement storage

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 2)
      iex> qc.num_qubits
      2
      iex> qc.num_classical_bits
      2
  """
  def new(num_qubits, num_classical_bits) when num_qubits > 0 and num_classical_bits >= 0 do
    # Initialize all qubits in |0⟩ state with complex representation
    # For n qubits, we need a 2^n dimensional state vector with complex components
    state_size = trunc(:math.pow(2, num_qubits))
    initial_state = complex_basis_state(0, state_size)

    %__MODULE__{
      num_qubits: num_qubits,
      num_classical_bits: num_classical_bits,
      state: initial_state,
      instructions: [],
      measurements: [],
      measured_qubits: MapSet.new()
    }
  end

  @doc """
  Creates a new quantum circuit with only qubits (no classical bits).

  ## Parameters
    * `num_qubits` - Number of qubits in the circuit

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(3)
      iex> qc.num_qubits
      3
      iex> qc.num_classical_bits
      0
  """
  def new(num_qubits) when num_qubits > 0 do
    new(num_qubits, 0)
  end

  @doc """
  Adds a single-qubit gate instruction to the circuit.

  ## Parameters
    * `circuit` - The quantum circuit
    * `gate_name` - Name of the gate (e.g., :h, :x, :y, :z)
    * `qubit` - Target qubit index
    * `params` - Optional gate parameters (default: [])

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 0)
      iex> qc = Qx.QuantumCircuit.add_gate(qc, :h, 0)
      iex> length(qc.instructions)
      1
  """
  def add_gate(%__MODULE__{} = circuit, gate_name, qubit, params \\ [])
      when is_atom(gate_name) and is_integer(qubit) and qubit >= 0 and qubit < circuit.num_qubits do
    instruction = {gate_name, [qubit], params}

    %{circuit | instructions: circuit.instructions ++ [instruction]}
  end

  @doc """
  Adds a two-qubit gate instruction to the circuit.

  ## Parameters
    * `circuit` - The quantum circuit
    * `gate_name` - Name of the gate (e.g., :cx, :cz)
    * `control_qubit` - Control qubit index
    * `target_qubit` - Target qubit index
    * `params` - Optional gate parameters (default: [])

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 0)
      iex> qc = Qx.QuantumCircuit.add_two_qubit_gate(qc, :cx, 0, 1)
      iex> length(qc.instructions)
      1
  """
  def add_two_qubit_gate(
        %__MODULE__{} = circuit,
        gate_name,
        control_qubit,
        target_qubit,
        params \\ []
      )
      when is_atom(gate_name) and is_integer(control_qubit) and is_integer(target_qubit) and
             control_qubit >= 0 and control_qubit < circuit.num_qubits and
             target_qubit >= 0 and target_qubit < circuit.num_qubits and
             control_qubit != target_qubit do
    instruction = {gate_name, [control_qubit, target_qubit], params}

    %{circuit | instructions: circuit.instructions ++ [instruction]}
  end

  @doc """
  Adds a three-qubit gate instruction to the circuit.

  ## Parameters
    * `circuit` - The quantum circuit
    * `gate_name` - Name of the gate (e.g., :ccx)
    * `control1` - First control qubit index
    * `control2` - Second control qubit index
    * `target` - Target qubit index
    * `params` - Optional gate parameters (default: [])

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(3, 0)
      iex> qc = Qx.QuantumCircuit.add_three_qubit_gate(qc, :ccx, 0, 1, 2)
      iex> length(qc.instructions)
      1
  """
  def add_three_qubit_gate(
        %__MODULE__{} = circuit,
        gate_name,
        control1,
        control2,
        target,
        params \\ []
      )
      when is_atom(gate_name) and is_integer(control1) and is_integer(control2) and
             is_integer(target) and
             control1 >= 0 and control1 < circuit.num_qubits and
             control2 >= 0 and control2 < circuit.num_qubits and
             target >= 0 and target < circuit.num_qubits and
             control1 != control2 and control1 != target and control2 != target do
    instruction = {gate_name, [control1, control2, target], params}

    %{circuit | instructions: circuit.instructions ++ [instruction]}
  end

  @doc """
  Adds a measurement instruction to the circuit.

  ## Parameters
    * `circuit` - The quantum circuit
    * `qubit` - Qubit index to measure
    * `classical_bit` - Classical bit index to store the result

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 2)
      iex> qc = Qx.QuantumCircuit.add_measurement(qc, 0, 0)
      iex> length(qc.measurements)
      1
  """
  def add_measurement(%__MODULE__{} = circuit, qubit, classical_bit)
      when is_integer(qubit) and is_integer(classical_bit) and
             qubit >= 0 and qubit < circuit.num_qubits and
             classical_bit >= 0 and classical_bit < circuit.num_classical_bits do
    measurement = {qubit, classical_bit}
    measured_qubits = MapSet.put(circuit.measured_qubits, qubit)

    %{
      circuit
      | measurements: circuit.measurements ++ [measurement],
        measured_qubits: measured_qubits
    }
  end

  @doc """
  Gets the current quantum state of the circuit.

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(1, 0)
      iex> state = Qx.QuantumCircuit.get_state(qc)
      iex> Nx.shape(state)
      {2}
  """
  def get_state(%__MODULE__{} = circuit) do
    circuit.state
  end

  @doc """
  Sets the quantum state of the circuit.

  The state must be a valid quantum state vector with dimension 2^n
  where n is the number of qubits.

  ## Parameters
    * `circuit` - The quantum circuit
    * `state` - New quantum state vector

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(1, 0)
      iex> new_state = Nx.tensor([Complex.new(0.0, 0.0), Complex.new(1.0, 0.0)], type: :c64)
      iex> qc = Qx.QuantumCircuit.set_state(qc, new_state)
      iex> Nx.shape(qc.state)
      {2}
  """
  def set_state(%__MODULE__{} = circuit, state) do
    expected_size = trunc(:math.pow(2, circuit.num_qubits))

    case Nx.shape(state) do
      {^expected_size} ->
        %{circuit | state: state}

      _ ->
        raise ArgumentError,
              "State vector size must be #{expected_size} for #{circuit.num_qubits} qubits"
    end
  end

  @doc """
  Gets the list of instructions in the circuit.

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 0)
      iex> qc = Qx.QuantumCircuit.add_gate(qc, :h, 0)
      iex> [{gate_name, qubits, params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> gate_name
      :h
      iex> qubits
      [0]
  """
  def get_instructions(%__MODULE__{} = circuit) do
    circuit.instructions
  end

  @doc """
  Gets the list of measurements in the circuit.

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 2)
      iex> qc = Qx.QuantumCircuit.add_measurement(qc, 0, 0)
      iex> [{qubit, classical_bit}] = Qx.QuantumCircuit.get_measurements(qc)
      iex> qubit
      0
      iex> classical_bit
      0
  """
  def get_measurements(%__MODULE__{} = circuit) do
    circuit.measurements
  end

  @doc """
  Checks if a qubit has been measured.

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 2)
      iex> qc = Qx.QuantumCircuit.add_measurement(qc, 0, 0)
      iex> Qx.QuantumCircuit.is_measured?(qc, 0)
      true
      iex> Qx.QuantumCircuit.is_measured?(qc, 1)
      false
  """
  def is_measured?(%__MODULE__{} = circuit, qubit) do
    MapSet.member?(circuit.measured_qubits, qubit)
  end

  @doc """
  Gets the depth (number of instruction layers) of the circuit.

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 0)
      iex> qc = qc |> Qx.QuantumCircuit.add_gate(:h, 0) |> Qx.QuantumCircuit.add_gate(:x, 1)
      iex> Qx.QuantumCircuit.depth(qc)
      2
  """
  def depth(%__MODULE__{} = circuit) do
    length(circuit.instructions)
  end

  @doc """
  Resets the circuit to its initial state, clearing all instructions and measurements.

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 2)
      iex> qc = qc |> Qx.QuantumCircuit.add_gate(:h, 0) |> Qx.QuantumCircuit.add_measurement(0, 0)
      iex> qc_reset = Qx.QuantumCircuit.reset(qc)
      iex> length(qc_reset.instructions)
      0
      iex> length(qc_reset.measurements)
      0
  """
  def reset(%__MODULE__{} = circuit) do
    state_size = trunc(:math.pow(2, circuit.num_qubits))
    initial_state = complex_basis_state(0, state_size)

    %{
      circuit
      | state: initial_state,
        instructions: [],
        measurements: [],
        measured_qubits: MapSet.new()
    }
  end

  # Private helper function to create complex basis states
  defp complex_basis_state(index, dimension) do
    # Create state vector with c64 complex representation
    alias Complex, as: C

    state_data =
      for i <- 0..(dimension - 1) do
        if i == index do
          # |i⟩ state has amplitude 1+0i
          C.new(1.0, 0.0)
        else
          # other states have amplitude 0+0i
          C.new(0.0, 0.0)
        end
      end

    Nx.tensor(state_data, type: :c64)
  end
end
