defmodule Qx.Simulation do
  @moduledoc """
  Simulation engine for executing quantum circuits with full complex number support.

  This module runs circuit instructions and applies quantum gates to evolve the
  quantum state, then provides measurement probabilities and classical bit results.
  All quantum states and operations properly support complex number arithmetic.
  """

  alias Qx.{Math, QuantumCircuit, Gates, Calc}

  @type simulation_result :: %{
          probabilities: Nx.Tensor.t(),
          classical_bits: list(list(integer())),
          state: Nx.Tensor.t(),
          shots: integer(),
          counts: map()
        }

  @doc """
  Executes a quantum circuit and returns the simulation results.

  ## Parameters
    * `circuit` - The quantum circuit to execute
    * `shots` - Number of measurement shots (default: 1024)

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 2)
      iex> qc = qc |> Qx.Operations.h(0) |> Qx.Operations.cx(0, 1)
      iex> result = Qx.Simulation.run(qc)
      iex> is_map(result)
      true
  """
  def run(%QuantumCircuit{} = circuit, shots \\ 1024) do
    # Check if circuit has conditionals - if so, use shot-by-shot execution
    if has_conditionals?(circuit) do
      run_with_conditionals(circuit, shots)
    else
      # Use optimized path for non-conditional circuits
      run_without_conditionals(circuit, shots)
    end
  end

  # Original implementation for circuits without conditionals
  defp run_without_conditionals(%QuantumCircuit{} = circuit, shots) do
    # Execute the circuit to get final state
    final_state = execute_circuit(circuit)

    # Calculate probabilities from complex state
    probabilities = Math.probabilities(final_state)

    # Perform measurements if any
    {classical_bits, counts} = perform_measurements(circuit, final_state, shots)

    %{
      probabilities: probabilities,
      classical_bits: classical_bits,
      state: final_state,
      shots: shots,
      counts: counts
    }
  end

  # New implementation for circuits with conditionals
  defp run_with_conditionals(%QuantumCircuit{} = circuit, shots) do
    # Execute each shot independently
    results =
      for _shot <- 1..shots do
        execute_single_shot(circuit)
      end

    # Extract classical bits from all shots
    classical_bits = Enum.map(results, fn {_state, cbits} -> cbits end)

    # Count occurrences
    counts = Enum.frequencies(classical_bits)

    # Calculate average probabilities (from final states)
    # Note: For conditional circuits, we can't provide a single final state
    # We'll use the last shot's state as representative
    {final_state, _} = List.last(results)
    probabilities = Math.probabilities(final_state)

    %{
      probabilities: probabilities,
      classical_bits: classical_bits,
      state: final_state,
      shots: shots,
      counts: counts
    }
  end

  @doc """
  Executes a quantum circuit without measurements, returning only the final state.

  ## Parameters
    * `circuit` - The quantum circuit to execute

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(1, 0) |> Qx.Operations.h(0)
      iex> state = Qx.Simulation.get_state(qc)
      iex> Nx.shape(state)
      {2}
  """
  def get_state(%QuantumCircuit{} = circuit) do
    execute_circuit(circuit)
  end

  @doc """
  Gets the probability distribution for all computational basis states.

  ## Parameters
    * `circuit` - The quantum circuit

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(1, 0) |> Qx.Operations.h(0)
      iex> probs = Qx.Simulation.get_probabilities(qc)
      iex> Nx.shape(probs)
      {2}
  """
  def get_probabilities(%QuantumCircuit{} = circuit) do
    final_state = execute_circuit(circuit)
    Math.probabilities(final_state)
  end

  # Private functions

  defp execute_circuit(%QuantumCircuit{} = circuit) do
    # Convert initial real state to complex representation
    initial_complex_state = real_state_to_complex(circuit.state)
    instructions = QuantumCircuit.get_instructions(circuit)

    Enum.reduce(instructions, initial_complex_state, fn instruction, state ->
      apply_instruction(instruction, state, circuit.num_qubits)
    end)
  end

  defp real_state_to_complex(state) do
    # If already c64, return as-is; otherwise convert real to complex
    case Nx.type(state) do
      {:c, 64} -> state
      _ ->
        # Convert real tensor to c64
        real_list = Nx.to_flat_list(state)
        complex_list = Enum.map(real_list, fn val -> Complex.new(val, 0.0) end)
        Nx.tensor(complex_list, type: :c64)
    end
  end

  defp apply_instruction({gate_name, qubits, params}, state, num_qubits) do
    case {gate_name, length(qubits)} do
      {:h, 1} ->
        Calc.apply_single_qubit_gate(state, Gates.hadamard(), Enum.at(qubits, 0), num_qubits)

      {:x, 1} ->
        Calc.apply_single_qubit_gate(state, Gates.pauli_x(), Enum.at(qubits, 0), num_qubits)

      {:y, 1} ->
        Calc.apply_single_qubit_gate(state, Gates.pauli_y(), Enum.at(qubits, 0), num_qubits)

      {:z, 1} ->
        Calc.apply_single_qubit_gate(state, Gates.pauli_z(), Enum.at(qubits, 0), num_qubits)

      {:s, 1} ->
        Calc.apply_single_qubit_gate(state, Gates.s_gate(), Enum.at(qubits, 0), num_qubits)

      {:t, 1} ->
        Calc.apply_single_qubit_gate(state, Gates.t_gate(), Enum.at(qubits, 0), num_qubits)

      {:cx, 2} ->
        Calc.apply_cnot(state, Enum.at(qubits, 0), Enum.at(qubits, 1), num_qubits)

      {:ccx, 3} ->
        Calc.apply_toffoli(
          state,
          Enum.at(qubits, 0),
          Enum.at(qubits, 1),
          Enum.at(qubits, 2),
          num_qubits
        )

      {:cz, 2} ->
        # CZ = H on target, CNOT, H on target
        state
        |> Calc.apply_single_qubit_gate(Gates.hadamard(), Enum.at(qubits, 1), num_qubits)
        |> Calc.apply_cnot(Enum.at(qubits, 0), Enum.at(qubits, 1), num_qubits)
        |> Calc.apply_single_qubit_gate(Gates.hadamard(), Enum.at(qubits, 1), num_qubits)

      {:rx, 1} ->
        Calc.apply_single_qubit_gate(
          state,
          Gates.rx(Enum.at(params, 0)),
          Enum.at(qubits, 0),
          num_qubits
        )

      {:ry, 1} ->
        Calc.apply_single_qubit_gate(
          state,
          Gates.ry(Enum.at(params, 0)),
          Enum.at(qubits, 0),
          num_qubits
        )

      {:rz, 1} ->
        Calc.apply_single_qubit_gate(
          state,
          Gates.rz(Enum.at(params, 0)),
          Enum.at(qubits, 0),
          num_qubits
        )

      {:phase, 1} ->
        Calc.apply_single_qubit_gate(
          state,
          Gates.phase(Enum.at(params, 0)),
          Enum.at(qubits, 0),
          num_qubits
        )

      {:barrier, _} ->
        # Barriers don't affect quantum state
        state

      {:measure, _} ->
        # Measurements are handled separately in the timeline
        state

      _ ->
        raise "Unsupported gate: #{gate_name} with #{length(qubits)} qubits"
    end
  end

  defp perform_measurements(%QuantumCircuit{} = circuit, final_state, shots) do
    measurements = QuantumCircuit.get_measurements(circuit)

    if measurements == [] do
      {[], %{}}
    else
      # Get probabilities for all computational basis states
      probabilities = Math.probabilities(final_state) |> Nx.to_flat_list()

      # Generate measurement samples
      samples = generate_samples(probabilities, shots)

      # Extract classical bit values from samples based on measurements
      classical_bits = extract_classical_bits(samples, measurements, circuit.num_qubits)

      # Count occurrences of classical bit strings
      counts = Enum.frequencies(classical_bits)

      {classical_bits, counts}
    end
  end

  defp generate_samples(probabilities, shots) do
    # Create cumulative distribution
    cumulative = Enum.scan(probabilities, &(&1 + &2))

    # Generate random samples
    for _ <- 1..shots do
      rand = :rand.uniform()
      Enum.find_index(cumulative, fn cum_prob -> rand <= cum_prob end) || 0
    end
  end

  defp extract_classical_bits(samples, measurements, num_qubits) do
    Enum.map(samples, fn sample ->
      Enum.map(measurements, fn {qubit, _classical_bit} ->
        # Extract the bit value for the measured qubit from the sample index
        # Standard convention: qubit 0 is leftmost (MSB), so qubit q is at bit position (num_qubits - 1 - q)
        Bitwise.band(Bitwise.bsr(sample, num_qubits - 1 - qubit), 1)
      end)
    end)
  end

  # Check if circuit has conditional instructions
  defp has_conditionals?(%QuantumCircuit{} = circuit) do
    Enum.any?(circuit.instructions, fn
      {:c_if, _, _} -> true
      _ -> false
    end)
  end

  # Execute a single shot of a circuit with conditionals
  defp execute_single_shot(%QuantumCircuit{} = circuit) do
    initial_state = real_state_to_complex(circuit.state)
    classical_bits = List.duplicate(0, circuit.num_classical_bits)

    # Create instruction timeline (merges instructions and measurements)
    timeline = create_instruction_timeline(circuit)

    # Execute timeline sequentially
    {final_state, final_classical_bits} =
      Enum.reduce(timeline, {initial_state, classical_bits}, fn item, {state, cbits} ->
        case item do
          {:instruction, instruction} ->
            {apply_instruction(instruction, state, circuit.num_qubits), cbits}

          {:measurement, {qubit, cbit}} ->
            {new_state, measured_value} =
              perform_single_measurement(state, qubit, circuit.num_qubits)

            {new_state, List.replace_at(cbits, cbit, measured_value)}

          {:conditional, {cbit, value, instructions}} ->
            if Enum.at(cbits, cbit) == value do
              new_state =
                Enum.reduce(instructions, state, fn instr, s ->
                  apply_instruction(instr, s, circuit.num_qubits)
                end)

              {new_state, cbits}
            else
              {state, cbits}
            end
        end
      end)

    {final_state, final_classical_bits}
  end

  # Create unified timeline of operations (instructions and measurements)
  defp create_instruction_timeline(%QuantumCircuit{} = circuit) do
    instructions = circuit.instructions

    # Convert instructions to timeline format
    # Measurements are now in the instruction list for proper ordering
    Enum.map(instructions, fn instruction ->
      case instruction do
        {:c_if, [cbit, value], sub_instructions} ->
          {:conditional, {cbit, value, sub_instructions}}

        {:measure, [qubit, cbit], []} ->
          {:measurement, {qubit, cbit}}

        other ->
          {:instruction, other}
      end
    end)
  end

  # Perform a single measurement and collapse the state
  defp perform_single_measurement(state, qubit, num_qubits) do
    # Calculate probability of measuring |0⟩
    prob_0 = calculate_measurement_probability(state, qubit, 0, num_qubits)

    # Random measurement outcome
    measured_value = if :rand.uniform() < prob_0, do: 0, else: 1

    # Collapse state to measured outcome
    collapsed_state = collapse_to_measurement(state, qubit, measured_value, num_qubits)

    {collapsed_state, measured_value}
  end

  # Calculate probability of measuring a specific value for a qubit
  defp calculate_measurement_probability(state, qubit, value, num_qubits) do
    state_size = trunc(:math.pow(2, num_qubits))

    # Sum probabilities for all basis states where qubit has the specified value
    total_prob =
      for i <- 0..(state_size - 1), reduce: 0.0 do
        acc ->
          # Standard convention: qubit 0 is leftmost (MSB), so qubit q is at bit position (num_qubits - 1 - q)
          qubit_value = Bitwise.band(Bitwise.bsr(i, num_qubits - 1 - qubit), 1)

          if qubit_value == value do
            amplitude = Nx.to_number(state[i])
            prob = Complex.abs(amplitude) |> :math.pow(2)
            acc + prob
          else
            acc
          end
      end

    total_prob
  end

  # Collapse state to a measurement outcome
  defp collapse_to_measurement(state, qubit, measured_value, num_qubits) do
    state_size = trunc(:math.pow(2, num_qubits))

    # Calculate normalization factor
    prob = calculate_measurement_probability(state, qubit, measured_value, num_qubits)
    norm_factor = if prob > 0, do: 1.0 / :math.sqrt(prob), else: 1.0

    # Create new state with collapsed amplitudes
    collapsed_data =
      for i <- 0..(state_size - 1) do
        # Standard convention: qubit 0 is leftmost (MSB), so qubit q is at bit position (num_qubits - 1 - q)
        qubit_value = Bitwise.band(Bitwise.bsr(i, num_qubits - 1 - qubit), 1)

        if qubit_value == measured_value do
          # Keep amplitude and renormalize
          amplitude = Nx.to_number(state[i])
          Complex.multiply(amplitude, Complex.new(norm_factor, 0.0))
        else
          # Zero out inconsistent amplitudes
          Complex.new(0.0, 0.0)
        end
      end

    Nx.tensor(collapsed_data, type: :c64)
  end
end
