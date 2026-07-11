defmodule Qx.QuantumCircuit do
  @moduledoc """
  Tier 1: a core Qx type. Circuits are created and threaded by the `Qx.*`
  facade (`Qx.create_circuit/2`, the gate builders, `Qx.run/2`); direct use
  of this module is rarely needed.

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
  @spec new(pos_integer(), non_neg_integer()) :: t()
  def new(num_qubits, num_classical_bits) do
    # Validate up front (Iron Law #7). A single unguarded clause raises the
    # typed error directly — `Qx.QubitCountError` (non-integer or outside 1..20)
    # or `Qx.ClassicalBitError` (non-integer or negative) — rather than relying
    # on a guard/fallback split whose exhaustiveness is only emergent.
    Qx.Validation.validate_num_qubits!(num_qubits)
    Qx.Validation.validate_num_classical_bits!(num_classical_bits)

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
  @spec new(pos_integer()) :: t()
  def new(num_qubits) do
    # `new/2` validates `num_qubits`; a non-integer or out-of-range value raises
    # `Qx.QubitCountError` there.
    new(num_qubits, 0)
  end

  # --- Instruction producer surface (internal) ---
  #
  # `add_gate/4`, `add_two_qubit_gate/5`, `add_three_qubit_gate/5`,
  # `add_measurement/3`, `add_barrier/2`, and `add_conditional/4` are the SINGLE
  # place every instruction tuple is built and appended. All are `@doc false`
  # with no external callers (only `Qx.Operations`/`Qx.Patterns` reach them), so
  # every instruction SHAPE a producer can emit is greppable here — the
  # Iron Law #9 (dispatch completeness) audit point. `gate_name`/kind atoms are
  # always hardcoded by `Operations` (never user input), so no per-name allowlist
  # is validated here; Iron Law #9 coverage is the execution-test-per-shape rule,
  # and qubit/bit indices are validated by the callers or the helpers below.

  # Adds a single-qubit gate instruction to the circuit. Internal helper used
  # by `Qx.Operations` and `Qx.Patterns`; users should call `Qx.h(qc, 0)` etc.
  # gate_name: atom (e.g. :h, :x). qubit: target index. params: optional list.
  @doc false
  def add_gate(%__MODULE__{} = circuit, gate_name, qubit, params \\ [])
      when is_atom(gate_name) do
    # `is_integer(qubit)` dropped from the guard (sweep #3) so a non-integer
    # qubit reaches `validate_qubit_index!`, which raises Qx.QubitIndexError
    # instead of a raw FunctionClauseError.
    Qx.Validation.validate_qubit_index!(qubit, circuit.num_qubits)
    instruction = {gate_name, [qubit], params}

    %{circuit | instructions: circuit.instructions ++ [instruction]}
  end

  # Adds a two-qubit gate instruction to the circuit. Internal helper used
  # by `Qx.Operations`; users should call `Qx.cx(qc, 0, 1)` etc.
  # gate_name: atom (e.g. :cx, :cz). Distinct qubits enforced.
  @doc false
  def add_two_qubit_gate(
        %__MODULE__{} = circuit,
        gate_name,
        control_qubit,
        target_qubit,
        params \\ []
      )
      when is_atom(gate_name) do
    # Integer guards on the qubits dropped (sweep #3) so non-integer indices
    # reach `validate_qubit_index!` → Qx.QubitIndexError, not FunctionClauseError.
    Qx.Validation.validate_qubit_index!(control_qubit, circuit.num_qubits)
    Qx.Validation.validate_qubit_index!(target_qubit, circuit.num_qubits)

    if control_qubit == target_qubit do
      raise Qx.QubitIndexError, {:duplicate, [control_qubit, target_qubit]}
    end

    instruction = {gate_name, [control_qubit, target_qubit], params}

    %{circuit | instructions: circuit.instructions ++ [instruction]}
  end

  # Adds a three-qubit gate instruction. Internal helper used by `Qx.Operations`;
  # users should call `Qx.ccx(qc, 0, 1, 2)` etc. gate_name: atom (e.g. :ccx).
  # Indices must be distinct.
  @doc false
  def add_three_qubit_gate(
        %__MODULE__{} = circuit,
        gate_name,
        control1,
        control2,
        target,
        params \\ []
      )
      when is_atom(gate_name) do
    validate_three_qubit_args!(circuit, control1, control2, target)

    instruction = {gate_name, [control1, control2, target], params}

    %{circuit | instructions: circuit.instructions ++ [instruction]}
  end

  defp validate_three_qubit_args!(circuit, c1, c2, t) do
    validate_indices_integers!(c1, c2, t)
    Qx.Validation.validate_qubit_indices!([c1, c2, t], circuit.num_qubits)
    validate_indices_distinct!(c1, c2, t)
  end

  defp validate_indices_integers!(c1, c2, t) do
    unless is_integer(c1) and is_integer(c2) and is_integer(t) do
      raise Qx.QubitIndexError,
            "Qubit indices must be integers, got: #{inspect([c1, c2, t])}"
    end
  end

  defp validate_indices_distinct!(c1, c2, t) do
    if c1 == c2 or c1 == t or c2 == t do
      raise Qx.QubitIndexError, {:duplicate, [c1, c2, t]}
    end
  end

  # Adds a measurement instruction. Internal helper used by `Qx.Operations` and
  # `Qx.Patterns`; users should call `Qx.measure(qc, 0, 0)`. Records the
  # measurement both as an instruction (for timeline ordering) and in the
  # `measurements` list (for end-of-circuit sampling).
  @doc false
  def add_measurement(%__MODULE__{} = circuit, qubit, classical_bit)
      when is_integer(qubit) and is_integer(classical_bit) do
    Qx.Validation.validate_qubit_index!(qubit, circuit.num_qubits)
    Qx.Validation.validate_classical_bit!(classical_bit, circuit.num_classical_bits)

    measurement = {qubit, classical_bit}
    measured_qubits = MapSet.put(circuit.measured_qubits, qubit)

    # Also add measurement as an instruction for proper timeline ordering
    measurement_instruction = {:measure, [qubit, classical_bit], []}

    %{
      circuit
      | measurements: circuit.measurements ++ [measurement],
        measured_qubits: measured_qubits,
        instructions: circuit.instructions ++ [measurement_instruction]
    }
  end

  # Adds a barrier instruction spanning `qubits`. Internal producer used by
  # `Qx.Operations.barrier/2` (which owns qubit-index validation); users call
  # `Qx.barrier(qc, [0, 1])`. Builds+appends the `{:barrier, qubits, []}` tuple
  # so barrier production lives on this single `add_*` surface, not inline in
  # Operations.
  @doc false
  def add_barrier(%__MODULE__{} = circuit, qubits) when is_list(qubits) do
    %{circuit | instructions: circuit.instructions ++ [{:barrier, qubits, []}]}
  end

  # Adds a conditional (`c_if`) instruction. Internal producer used by
  # `Qx.Operations.c_if/4` (which owns running the gate function, block
  # validation, and the value/bit guards); users call `Qx.c_if/4`. Builds +
  # appends the `{:c_if, [classical_bit, value], conditional_instructions}`
  # tuple — the already-collected `conditional_instructions` come from
  # Operations running the caller's `gate_fn` on a temp circuit.
  @doc false
  def add_conditional(%__MODULE__{} = circuit, classical_bit, value, conditional_instructions)
      when is_list(conditional_instructions) do
    instruction = {:c_if, [classical_bit, value], conditional_instructions}
    %{circuit | instructions: circuit.instructions ++ [instruction]}
  end

  @doc """
  Gets the current quantum state of the circuit.

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(1, 0)
      iex> state = Qx.QuantumCircuit.get_state(qc)
      iex> Nx.shape(state)
      {2}
  """
  @spec get_state(t()) :: Nx.Tensor.t()
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
  @spec set_state(t(), Nx.Tensor.t()) :: t()
  def set_state(%__MODULE__{} = circuit, state) do
    expected_size = trunc(:math.pow(2, circuit.num_qubits))

    case Nx.shape(state) do
      {^expected_size} ->
        %{circuit | state: state}

      {actual_size} ->
        raise Qx.StateShapeError, {actual_size, expected_size}

      shape ->
        raise Qx.StateShapeError,
              "State vector must be 1-D with length #{expected_size}, got shape #{inspect(shape)}"
    end
  end

  @doc """
  Gets the list of instructions in the circuit.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.h(0)
      iex> [{gate_name, qubits, _params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate_name, qubits}
      {:h, [0]}
  """
  @spec get_instructions(t()) :: [instruction()]
  def get_instructions(%__MODULE__{} = circuit) do
    circuit.instructions
  end

  @doc """
  Gets the list of measurements in the circuit.

  ## Examples

      iex> qc = Qx.create_circuit(2, 2) |> Qx.measure(0, 0)
      iex> [{qubit, classical_bit}] = Qx.QuantumCircuit.get_measurements(qc)
      iex> {qubit, classical_bit}
      {0, 0}
  """
  @spec get_measurements(t()) :: [measurement()]
  def get_measurements(%__MODULE__{} = circuit) do
    circuit.measurements
  end

  @doc """
  Checks if a qubit has been measured.

  ## Examples

      iex> qc = Qx.create_circuit(2, 2) |> Qx.measure(0, 0)
      iex> Qx.QuantumCircuit.measured?(qc, 0)
      true
      iex> Qx.QuantumCircuit.measured?(qc, 1)
      false
  """
  @spec measured?(t(), non_neg_integer()) :: boolean()
  def measured?(%__MODULE__{} = circuit, qubit) do
    MapSet.member?(circuit.measured_qubits, qubit)
  end

  @doc """
  Gets the depth (number of instruction layers) of the circuit.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.x(1)
      iex> Qx.QuantumCircuit.depth(qc)
      2
  """
  @spec depth(t()) :: non_neg_integer()
  def depth(%__MODULE__{} = circuit) do
    length(circuit.instructions)
  end

  @doc """
  Resets the circuit to its initial state, clearing all instructions and measurements.

  Note: this clears the entire circuit (instructions + measurements + state),
  *not* a single qubit. A future mid-circuit qubit reset (ROADMAP v0.9) will
  add a distinct operation; this function may be renamed to `clear/1` at
  that point to disambiguate.

  ## Examples

      iex> qc = Qx.create_circuit(2, 2) |> Qx.h(0) |> Qx.measure(0, 0)
      iex> qc_reset = Qx.QuantumCircuit.reset(qc)
      iex> length(qc_reset.instructions)
      0
      iex> length(qc_reset.measurements)
      0
  """
  @spec reset(t()) :: t()
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
    Qx.StateInit.basis_state(index, dimension)
  end
end
