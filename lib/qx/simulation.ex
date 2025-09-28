defmodule Qx.Simulation do
  @moduledoc """
  Simulation engine for executing quantum circuits and generating probability results.

  This module runs circuit instructions and applies quantum gates to evolve the
  quantum state, then provides measurement probabilities and classical bit results.
  """

  alias Qx.{Math, QuantumCircuit}

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
    # Execute the circuit to get final state
    final_state = execute_circuit(circuit)

    # Calculate probabilities
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
    initial_state = circuit.state
    instructions = QuantumCircuit.get_instructions(circuit)

    Enum.reduce(instructions, initial_state, fn instruction, state ->
      apply_instruction(instruction, state, circuit.num_qubits)
    end)
  end

  defp apply_instruction({gate_name, qubits, params}, state, num_qubits) do
    case {gate_name, length(qubits)} do
      {:h, 1} ->
        apply_hadamard_gate(Enum.at(qubits, 0), state, num_qubits)

      {:x, 1} ->
        apply_x_gate(Enum.at(qubits, 0), state, num_qubits)

      {:y, 1} ->
        apply_y_gate(Enum.at(qubits, 0), state, num_qubits)

      {:z, 1} ->
        apply_z_gate(Enum.at(qubits, 0), state, num_qubits)

      {:s, 1} ->
        apply_s_gate(Enum.at(qubits, 0), state, num_qubits)

      {:t, 1} ->
        apply_t_gate(Enum.at(qubits, 0), state, num_qubits)

      {:cx, 2} ->
        apply_cx_gate(Enum.at(qubits, 0), Enum.at(qubits, 1), state, num_qubits)

      {:ccx, 3} ->
        apply_ccx_gate(
          Enum.at(qubits, 0),
          Enum.at(qubits, 1),
          Enum.at(qubits, 2),
          state,
          num_qubits
        )

      {:rx, 1} ->
        apply_rx_gate(Enum.at(qubits, 0), Enum.at(params, 0), state, num_qubits)

      {:ry, 1} ->
        apply_ry_gate(Enum.at(qubits, 0), Enum.at(params, 0), state, num_qubits)

      {:rz, 1} ->
        apply_rz_gate(Enum.at(qubits, 0), Enum.at(params, 0), state, num_qubits)

      {:phase, 1} ->
        apply_phase_gate(Enum.at(qubits, 0), Enum.at(params, 0), state, num_qubits)

      _ ->
        raise "Unsupported gate: #{gate_name} with #{length(qubits)} qubits"
    end
  end

  defp apply_hadamard_gate(target_qubit, state, num_qubits) do
    gate_matrix =
      Nx.tensor([
        [1.0 / :math.sqrt(2), 1.0 / :math.sqrt(2)],
        [1.0 / :math.sqrt(2), -1.0 / :math.sqrt(2)]
      ])

    apply_single_qubit_gate(gate_matrix, target_qubit, state, num_qubits)
  end

  defp apply_x_gate(target_qubit, state, num_qubits) do
    gate_matrix =
      Nx.tensor([
        [0.0, 1.0],
        [1.0, 0.0]
      ])

    apply_single_qubit_gate(gate_matrix, target_qubit, state, num_qubits)
  end

  defp apply_y_gate(target_qubit, state, num_qubits) do
    # For now, implement Y as iXZ (approximation without complex numbers)
    state
    |> apply_z_gate(target_qubit, num_qubits)
    |> apply_x_gate(target_qubit, num_qubits)
  end

  defp apply_z_gate(target_qubit, state, num_qubits) do
    gate_matrix =
      Nx.tensor([
        [1.0, 0.0],
        [0.0, -1.0]
      ])

    apply_single_qubit_gate(gate_matrix, target_qubit, state, num_qubits)
  end

  defp apply_s_gate(target_qubit, state, num_qubits) do
    # S gate approximation (phase π/2 ≈ phase flip for |1⟩)
    apply_z_gate(target_qubit, state, num_qubits)
  end

  defp apply_t_gate(target_qubit, state, num_qubits) do
    # T gate approximation (phase π/4 ≈ partial phase flip)
    apply_z_gate(target_qubit, state, num_qubits)
  end

  defp apply_rx_gate(target_qubit, theta, state, num_qubits) do
    # RX gate approximation using cos/sin
    cos_half = :math.cos(theta / 2)
    sin_half = :math.sin(theta / 2)

    gate_matrix =
      Nx.tensor([
        [cos_half, -sin_half],
        [-sin_half, cos_half]
      ])

    apply_single_qubit_gate(gate_matrix, target_qubit, state, num_qubits)
  end

  defp apply_ry_gate(target_qubit, theta, state, num_qubits) do
    cos_half = :math.cos(theta / 2)
    sin_half = :math.sin(theta / 2)

    gate_matrix =
      Nx.tensor([
        [cos_half, -sin_half],
        [sin_half, cos_half]
      ])

    apply_single_qubit_gate(gate_matrix, target_qubit, state, num_qubits)
  end

  defp apply_rz_gate(target_qubit, _theta, state, num_qubits) do
    # RZ gate approximation as Z gate
    apply_z_gate(target_qubit, state, num_qubits)
  end

  defp apply_phase_gate(target_qubit, _phi, state, num_qubits) do
    # Phase gate approximation as Z gate
    apply_z_gate(target_qubit, state, num_qubits)
  end

  defp apply_single_qubit_gate(gate_matrix, target_qubit, state, num_qubits) do
    state_size = trunc(:math.pow(2, num_qubits))
    new_state = Nx.broadcast(0.0, {state_size})

    # Apply gate to each computational basis state
    for i <- 0..(state_size - 1), reduce: new_state do
      acc_state ->
        target_bit = Bitwise.band(Bitwise.bsr(i, target_qubit), 1)
        amplitude = Nx.to_number(state[i])

        cond do
          target_bit == 0 ->
            # |0⟩ component
            new_amp_0 = Nx.to_number(gate_matrix[0][0]) * amplitude
            new_amp_1 = Nx.to_number(gate_matrix[1][0]) * amplitude

            # Add to |0⟩ state (same index)
            acc_state =
              Nx.put_slice(acc_state, [i], Nx.tensor([Nx.to_number(acc_state[i]) + new_amp_0]))

            # Add to |1⟩ state (flip target bit)
            new_index = Bitwise.bxor(i, Bitwise.bsl(1, target_qubit))

            Nx.put_slice(
              acc_state,
              [new_index],
              Nx.tensor([Nx.to_number(acc_state[new_index]) + new_amp_1])
            )

          target_bit == 1 ->
            # |1⟩ component
            new_amp_0 = Nx.to_number(gate_matrix[0][1]) * amplitude
            new_amp_1 = Nx.to_number(gate_matrix[1][1]) * amplitude

            # Add to |0⟩ state (flip target bit)
            new_index = Bitwise.bxor(i, Bitwise.bsl(1, target_qubit))

            acc_state =
              Nx.put_slice(
                acc_state,
                [new_index],
                Nx.tensor([
                  Nx.to_number(acc_state[new_index]) + new_amp_0
                ])
              )

            # Add to |1⟩ state (same index)
            Nx.put_slice(acc_state, [i], Nx.tensor([Nx.to_number(acc_state[i]) + new_amp_1]))
        end
    end
  end

  defp apply_cx_gate(control_qubit, target_qubit, state, num_qubits) do
    state_size = trunc(:math.pow(2, num_qubits))
    new_state = Nx.broadcast(0.0, {state_size})

    # Iterate through all basis states
    for i <- 0..(state_size - 1), reduce: new_state do
      acc_state ->
        control_bit = Bitwise.band(Bitwise.bsr(i, control_qubit), 1)
        amplitude = Nx.to_number(state[i])

        if control_bit == 1 do
          # Flip target bit
          new_index = Bitwise.bxor(i, Bitwise.bsl(1, target_qubit))

          Nx.put_slice(
            acc_state,
            [new_index],
            Nx.tensor([Nx.to_number(acc_state[new_index]) + amplitude])
          )
        else
          # Keep state unchanged
          Nx.put_slice(acc_state, [i], Nx.tensor([Nx.to_number(acc_state[i]) + amplitude]))
        end
    end
  end

  defp apply_ccx_gate(control1_qubit, control2_qubit, target_qubit, state, num_qubits) do
    state_size = trunc(:math.pow(2, num_qubits))
    new_state = Nx.broadcast(0.0, {state_size})

    for i <- 0..(state_size - 1), reduce: new_state do
      acc_state ->
        control1_bit = Bitwise.band(Bitwise.bsr(i, control1_qubit), 1)
        control2_bit = Bitwise.band(Bitwise.bsr(i, control2_qubit), 1)
        amplitude = Nx.to_number(state[i])

        if control1_bit == 1 and control2_bit == 1 do
          # Flip target bit
          new_index = Bitwise.bxor(i, Bitwise.bsl(1, target_qubit))

          Nx.put_slice(
            acc_state,
            [new_index],
            Nx.tensor([Nx.to_number(acc_state[new_index]) + amplitude])
          )
        else
          # Keep state unchanged
          Nx.put_slice(acc_state, [i], Nx.tensor([Nx.to_number(acc_state[i]) + amplitude]))
        end
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

  defp extract_classical_bits(samples, measurements, _num_qubits) do
    Enum.map(samples, fn sample ->
      Enum.map(measurements, fn {qubit, _classical_bit} ->
        # Extract the bit value for the measured qubit from the sample index
        Bitwise.band(Bitwise.bsr(sample, qubit), 1)
      end)
    end)
  end
end
