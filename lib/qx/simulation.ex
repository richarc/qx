defmodule Qx.Simulation do
  @moduledoc """
  Simulation engine for executing quantum circuits with full complex number support.

  This module runs circuit instructions and applies quantum gates to evolve the
  quantum state, then provides measurement probabilities and classical bit results.
  All quantum states and operations properly support complex number arithmetic.
  """

  alias Qx.{Math, QuantumCircuit, Gates}

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

    # Calculate probabilities from complex state
    probabilities = Math.complex_probabilities(final_state)

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
      {2, 2}
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
    Math.complex_probabilities(final_state)
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

  defp real_state_to_complex(real_state) do
    # Convert [a, b, c, d] to [[a,0], [b,0], [c,0], [d,0]]
    real_list = Nx.to_flat_list(real_state)

    complex_list =
      real_list
      |> Enum.map(fn real_val -> [real_val, 0.0] end)

    Nx.tensor(complex_list)
  end

  defp apply_instruction({gate_name, qubits, params}, state, num_qubits) do
    case {gate_name, length(qubits)} do
      {:h, 1} ->
        apply_single_qubit_gate(Gates.hadamard(), Enum.at(qubits, 0), state, num_qubits)

      {:x, 1} ->
        apply_single_qubit_gate(Gates.pauli_x(), Enum.at(qubits, 0), state, num_qubits)

      {:y, 1} ->
        apply_single_qubit_gate(Gates.pauli_y(), Enum.at(qubits, 0), state, num_qubits)

      {:z, 1} ->
        apply_single_qubit_gate(Gates.pauli_z(), Enum.at(qubits, 0), state, num_qubits)

      {:s, 1} ->
        apply_single_qubit_gate(Gates.s_gate(), Enum.at(qubits, 0), state, num_qubits)

      {:t, 1} ->
        apply_single_qubit_gate(Gates.t_gate(), Enum.at(qubits, 0), state, num_qubits)

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
        apply_single_qubit_gate(
          Gates.rx(Enum.at(params, 0)),
          Enum.at(qubits, 0),
          state,
          num_qubits
        )

      {:ry, 1} ->
        apply_single_qubit_gate(
          Gates.ry(Enum.at(params, 0)),
          Enum.at(qubits, 0),
          state,
          num_qubits
        )

      {:rz, 1} ->
        apply_single_qubit_gate(
          Gates.rz(Enum.at(params, 0)),
          Enum.at(qubits, 0),
          state,
          num_qubits
        )

      {:phase, 1} ->
        apply_single_qubit_gate(
          Gates.phase(Enum.at(params, 0)),
          Enum.at(qubits, 0),
          state,
          num_qubits
        )

      _ ->
        raise "Unsupported gate: #{gate_name} with #{length(qubits)} qubits"
    end
  end

  defp apply_single_qubit_gate(gate_matrix, target_qubit, state, num_qubits) do
    state_size = trunc(:math.pow(2, num_qubits))
    new_state = Nx.broadcast(0.0, {state_size, 2})

    # Apply gate to each computational basis state
    for i <- 0..(state_size - 1), reduce: new_state do
      acc_state ->
        target_bit = Bitwise.band(Bitwise.bsr(i, target_qubit), 1)

        # Get current amplitude as complex number
        amplitude_real = Nx.to_number(state[i][0])
        amplitude_imag = Nx.to_number(state[i][1])

        cond do
          target_bit == 0 ->
            # |0⟩ component - apply first row of gate matrix
            gate_00_real = Nx.to_number(gate_matrix[0][0][0])
            gate_00_imag = Nx.to_number(gate_matrix[0][0][1])
            gate_10_real = Nx.to_number(gate_matrix[1][0][0])
            gate_10_imag = Nx.to_number(gate_matrix[1][0][1])

            # Complex multiplication: (gate_element) * (amplitude)
            # For |0⟩ -> |0⟩
            new_amp_0_real = gate_00_real * amplitude_real - gate_00_imag * amplitude_imag
            new_amp_0_imag = gate_00_real * amplitude_imag + gate_00_imag * amplitude_real

            # For |0⟩ -> |1⟩
            new_amp_1_real = gate_10_real * amplitude_real - gate_10_imag * amplitude_imag
            new_amp_1_imag = gate_10_real * amplitude_imag + gate_10_imag * amplitude_real

            # Add to |0⟩ state (same index)
            acc_state =
              acc_state
              |> Nx.put_slice(
                [i, 0],
                Nx.tensor([[Nx.to_number(acc_state[i][0]) + new_amp_0_real]])
              )
              |> Nx.put_slice(
                [i, 1],
                Nx.tensor([[Nx.to_number(acc_state[i][1]) + new_amp_0_imag]])
              )

            # Add to |1⟩ state (flip target bit)
            new_index = Bitwise.bxor(i, Bitwise.bsl(1, target_qubit))

            acc_state
            |> Nx.put_slice(
              [new_index, 0],
              Nx.tensor([[Nx.to_number(acc_state[new_index][0]) + new_amp_1_real]])
            )
            |> Nx.put_slice(
              [new_index, 1],
              Nx.tensor([[Nx.to_number(acc_state[new_index][1]) + new_amp_1_imag]])
            )

          target_bit == 1 ->
            # |1⟩ component - apply second row of gate matrix
            gate_01_real = Nx.to_number(gate_matrix[0][1][0])
            gate_01_imag = Nx.to_number(gate_matrix[0][1][1])
            gate_11_real = Nx.to_number(gate_matrix[1][1][0])
            gate_11_imag = Nx.to_number(gate_matrix[1][1][1])

            # For |1⟩ -> |0⟩
            new_amp_0_real = gate_01_real * amplitude_real - gate_01_imag * amplitude_imag
            new_amp_0_imag = gate_01_real * amplitude_imag + gate_01_imag * amplitude_real

            # For |1⟩ -> |1⟩
            new_amp_1_real = gate_11_real * amplitude_real - gate_11_imag * amplitude_imag
            new_amp_1_imag = gate_11_real * amplitude_imag + gate_11_imag * amplitude_real

            # Add to |0⟩ state (flip target bit)
            new_index = Bitwise.bxor(i, Bitwise.bsl(1, target_qubit))

            acc_state =
              acc_state
              |> Nx.put_slice(
                [new_index, 0],
                Nx.tensor([[Nx.to_number(acc_state[new_index][0]) + new_amp_0_real]])
              )
              |> Nx.put_slice(
                [new_index, 1],
                Nx.tensor([[Nx.to_number(acc_state[new_index][1]) + new_amp_0_imag]])
              )

            # Add to |1⟩ state (same index)
            acc_state
            |> Nx.put_slice([i, 0], Nx.tensor([[Nx.to_number(acc_state[i][0]) + new_amp_1_real]]))
            |> Nx.put_slice([i, 1], Nx.tensor([[Nx.to_number(acc_state[i][1]) + new_amp_1_imag]]))
        end
    end
  end

  defp apply_cx_gate(control_qubit, target_qubit, state, num_qubits) do
    state_size = trunc(:math.pow(2, num_qubits))
    new_state = Nx.broadcast(0.0, {state_size, 2})

    # Iterate through all basis states
    for i <- 0..(state_size - 1), reduce: new_state do
      acc_state ->
        control_bit = Bitwise.band(Bitwise.bsr(i, control_qubit), 1)
        amplitude_real = Nx.to_number(state[i][0])
        amplitude_imag = Nx.to_number(state[i][1])

        if control_bit == 1 do
          # Flip target bit
          new_index = Bitwise.bxor(i, Bitwise.bsl(1, target_qubit))

          acc_state
          |> Nx.put_slice(
            [new_index, 0],
            Nx.tensor([[Nx.to_number(acc_state[new_index][0]) + amplitude_real]])
          )
          |> Nx.put_slice(
            [new_index, 1],
            Nx.tensor([[Nx.to_number(acc_state[new_index][1]) + amplitude_imag]])
          )
        else
          # Keep state unchanged
          acc_state
          |> Nx.put_slice([i, 0], Nx.tensor([[Nx.to_number(acc_state[i][0]) + amplitude_real]]))
          |> Nx.put_slice([i, 1], Nx.tensor([[Nx.to_number(acc_state[i][1]) + amplitude_imag]]))
        end
    end
  end

  defp apply_ccx_gate(control1_qubit, control2_qubit, target_qubit, state, num_qubits) do
    state_size = trunc(:math.pow(2, num_qubits))
    new_state = Nx.broadcast(0.0, {state_size, 2})

    for i <- 0..(state_size - 1), reduce: new_state do
      acc_state ->
        control1_bit = Bitwise.band(Bitwise.bsr(i, control1_qubit), 1)
        control2_bit = Bitwise.band(Bitwise.bsr(i, control2_qubit), 1)
        amplitude_real = Nx.to_number(state[i][0])
        amplitude_imag = Nx.to_number(state[i][1])

        if control1_bit == 1 and control2_bit == 1 do
          # Flip target bit
          new_index = Bitwise.bxor(i, Bitwise.bsl(1, target_qubit))

          acc_state
          |> Nx.put_slice(
            [new_index, 0],
            Nx.tensor([[Nx.to_number(acc_state[new_index][0]) + amplitude_real]])
          )
          |> Nx.put_slice(
            [new_index, 1],
            Nx.tensor([[Nx.to_number(acc_state[new_index][1]) + amplitude_imag]])
          )
        else
          # Keep state unchanged
          acc_state
          |> Nx.put_slice([i, 0], Nx.tensor([[Nx.to_number(acc_state[i][0]) + amplitude_real]]))
          |> Nx.put_slice([i, 1], Nx.tensor([[Nx.to_number(acc_state[i][1]) + amplitude_imag]]))
        end
    end
  end

  defp perform_measurements(%QuantumCircuit{} = circuit, final_state, shots) do
    measurements = QuantumCircuit.get_measurements(circuit)

    if measurements == [] do
      {[], %{}}
    else
      # Get probabilities for all computational basis states
      probabilities = Math.complex_probabilities(final_state) |> Nx.to_flat_list()

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
