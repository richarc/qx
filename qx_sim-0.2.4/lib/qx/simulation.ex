defmodule Qx.Simulation do
  @moduledoc """
  Simulation engine for executing quantum circuits with full complex number support.

  This module runs circuit instructions and applies quantum gates to evolve the
  quantum state, then provides measurement probabilities and classical bit results.
  All quantum states and operations properly support complex number arithmetic.
  """

  alias Qx.{Calc, Gates, Math, QuantumCircuit, SimulationResult}

  @type simulation_result :: SimulationResult.t()

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

    %SimulationResult{
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

    %SimulationResult{
      probabilities: probabilities,
      classical_bits: classical_bits,
      state: final_state,
      shots: shots,
      counts: counts
    }
  end

  @doc """
  Executes a quantum circuit without measurements, returning only the final state.

  **Note:** This function only works for circuits without measurements or conditionals.
  For circuits with measurements, use `run/2` instead to get the simulation result.

  ## Parameters
    * `circuit` - The quantum circuit to execute

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(1, 0) |> Qx.Operations.h(0)
      iex> state = Qx.Simulation.get_state(qc)
      iex> Nx.shape(state)
      {2}

  ## Raises

    * `Qx.MeasurementError` - If circuit contains measurements or conditionals
  """
  def get_state(%QuantumCircuit{} = circuit) do
    # Check if circuit has measurements or conditionals
    if has_measurements?(circuit) or has_conditionals?(circuit) do
      raise Qx.MeasurementError,
            "Cannot get pure state from circuit with measurements or conditionals. Use run/2 instead."
    end

    execute_circuit(circuit)
  end

  # Helper to check if circuit has measurements
  defp has_measurements?(%QuantumCircuit{measurements: measurements}) do
    measurements != []
  end

  @doc """
  Gets the probability distribution for all computational basis states.

  **Note:** This function only works for circuits without measurements or conditionals.
  For circuits with measurements, use `run/2` and access the probabilities from the result.

  ## Parameters
    * `circuit` - The quantum circuit

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(1, 0) |> Qx.Operations.h(0)
      iex> probs = Qx.Simulation.get_probabilities(qc)
      iex> Nx.shape(probs)
      {2}

  ## Raises

    * `Qx.MeasurementError` - If circuit contains measurements or conditionals
  """
  def get_probabilities(%QuantumCircuit{} = circuit) do
    # Check if circuit has measurements or conditionals
    if has_measurements?(circuit) or has_conditionals?(circuit) do
      raise Qx.MeasurementError,
            "Cannot get probabilities from circuit with measurements or conditionals. Use run/2 instead."
    end

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
      {:c, 64} ->
        state

      _ ->
        # Convert real tensor to c64
        real_list = Nx.to_flat_list(state)
        complex_list = Enum.map(real_list, fn val -> Complex.new(val, 0.0) end)
        Nx.tensor(complex_list, type: :c64)
    end
  end

  defp apply_instruction({gate_name, qubits, params}, state, num_qubits) do
    case length(qubits) do
      0 ->
        # Handle 0-qubit gates like :barrier
        case gate_name do
          :barrier -> state
          _ -> raise "Unsupported 0-qubit gate: #{gate_name}"
        end

      1 ->
        apply_single_qubit_op(gate_name, qubits, params, state, num_qubits)

      2 ->
        apply_two_qubit_op(gate_name, qubits, params, state, num_qubits)

      3 ->
        apply_three_qubit_op(gate_name, qubits, params, state, num_qubits)

      _ ->
        raise "Unsupported gate: #{gate_name} with #{length(qubits)} qubits"
    end
  end

  defp apply_single_qubit_op(gate_name, [qubit], params, state, num_qubits) do
    case gate_name do
      :h -> Calc.apply_single_qubit_gate(state, Gates.hadamard(), qubit, num_qubits)
      :x -> Calc.apply_single_qubit_gate(state, Gates.pauli_x(), qubit, num_qubits)
      :y -> Calc.apply_single_qubit_gate(state, Gates.pauli_y(), qubit, num_qubits)
      :z -> Calc.apply_single_qubit_gate(state, Gates.pauli_z(), qubit, num_qubits)
      :s -> Calc.apply_single_qubit_gate(state, Gates.s_gate(), qubit, num_qubits)
      :t -> Calc.apply_single_qubit_gate(state, Gates.t_gate(), qubit, num_qubits)
      _ -> apply_parameterized_single_qubit_op(gate_name, qubit, params, state, num_qubits)
    end
  end

  defp apply_parameterized_single_qubit_op(gate_name, qubit, params, state, num_qubits) do
    case gate_name do
      :rx -> Calc.apply_single_qubit_gate(state, Gates.rx(hd(params)), qubit, num_qubits)
      :ry -> Calc.apply_single_qubit_gate(state, Gates.ry(hd(params)), qubit, num_qubits)
      :rz -> Calc.apply_single_qubit_gate(state, Gates.rz(hd(params)), qubit, num_qubits)
      :phase -> Calc.apply_single_qubit_gate(state, Gates.phase(hd(params)), qubit, num_qubits)
      :measure -> state
      _ -> raise "Unsupported single-qubit gate: #{gate_name}"
    end
  end

  defp apply_two_qubit_op(gate_name, [c, t], _params, state, num_qubits) do
    case gate_name do
      :cx ->
        Calc.apply_cnot(state, c, t, num_qubits)

      :cz ->
        state
        |> Calc.apply_single_qubit_gate(Gates.hadamard(), t, num_qubits)
        |> Calc.apply_cnot(c, t, num_qubits)
        |> Calc.apply_single_qubit_gate(Gates.hadamard(), t, num_qubits)

      :measure ->
        state

      _ ->
        raise "Unsupported two-qubit gate: #{gate_name}"
    end
  end

  defp apply_three_qubit_op(:ccx, [c1, c2, t], _params, state, num_qubits) do
    Calc.apply_toffoli(state, c1, c2, t, num_qubits)
  end

  defp apply_three_qubit_op(gate_name, qubits, _params, _state, _num_qubits) do
    raise "Unsupported three-qubit gate: #{gate_name} with qubits #{inspect(qubits)}"
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
        process_timeline_item(item, state, cbits, circuit.num_qubits)
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

  defp process_timeline_item(item, state, cbits, num_qubits) do
    case item do
      {:instruction, instruction} ->
        {apply_instruction(instruction, state, num_qubits), cbits}

      {:measurement, {qubit, cbit}} ->
        {new_state, measured_value} =
          perform_single_measurement(state, qubit, num_qubits)

        {new_state, List.replace_at(cbits, cbit, measured_value)}

      {:conditional, {cbit, value, instructions}} ->
        process_conditional(cbits, cbit, value, instructions, state, num_qubits)
    end
  end

  defp process_conditional(cbits, cbit, value, instructions, state, num_qubits) do
    if Enum.at(cbits, cbit) == value do
      new_state =
        Enum.reduce(instructions, state, fn instr, s ->
          apply_instruction(instr, s, num_qubits)
        end)

      {new_state, cbits}
    else
      {state, cbits}
    end
  end
end
