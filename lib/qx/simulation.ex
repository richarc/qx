defmodule Qx.Simulation do
  @moduledoc """
  Simulation engine for executing quantum circuits with full complex number support.

  This module runs circuit instructions and applies quantum gates to evolve the
  quantum state, then provides measurement probabilities and classical bit results.
  All quantum states and operations properly support complex number arithmetic.
  """

  alias Qx.{Calc, Gates, Math, QuantumCircuit, SimulationResult, Validation}

  @type simulation_result :: SimulationResult.t()

  # Dev/test-only norm-drift guard, compile-time gated. In :prod
  # `@assert_norm` is false (config/config.exs) so `assert_norm/1`'s
  # body — including the host sync inside `validate_normalized!/2`
  # (`Nx.to_number`) — is dead code there (Iron Law Nx #5).
  # config/test.exs flips it true. `@norm_tolerance` is float32-real:
  # `:c64` states drift ~1.2e-7 even right after `Math.normalize/1`,
  # so 1.0e-10 is unreachable — 1.0e-6 still traps gross drift.
  @assert_norm Application.compile_env(:qx, :assert_norm, false)
  @norm_tolerance 1.0e-6

  @doc """
  Executes a quantum circuit and returns the simulation results.

  ## Parameters
    * `circuit` - The quantum circuit to execute
    * `options` - Optional keyword list (default: [])

  ## Options
    * `:shots` - Number of measurement shots (default: 1024)
    * `:backend` - Nx backend to use for computation (default: current Nx default)
    * `:renormalize` - Counter unitary float drift by renormalizing the
      statevector (default: `false`). Accepts:
        * `false` — no renormalization (current behaviour, zero cost)
        * `true` — renormalize once at measurement-time (before
          probabilities are computed)
        * positive integer `N` — renormalize every `N` gates **and** at
          measurement-time
      Any other value raises `Qx.OptionError`.

      Note: states are `:c64` (complex float32, ε≈1.2e-7). Even
      immediately after renormalization the total probability deviates
      from 1.0 by ~1e-7, so renormalization bounds drift but does not
      eliminate it; do not expect sub-1e-7 accuracy in this backend.

  ## Backend Selection

  You can specify which Nx backend to use for this simulation:

      # Use EXLA for GPU/CPU acceleration
      Qx.Simulation.run(circuit, backend: EXLA.Backend)

      # Force binary backend (no acceleration)
      Qx.Simulation.run(circuit, backend: Nx.BinaryBackend)

      # Use default backend
      Qx.Simulation.run(circuit)

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 2)
      iex> qc = qc |> Qx.Operations.h(0) |> Qx.Operations.cx(0, 1)
      iex> result = Qx.Simulation.run(qc)
      iex> is_map(result)
      true

      # With custom shots
      iex> result = Qx.Simulation.run(qc, shots: 2048)
      iex> result.shots
      2048

      # Renormalize every 8 gates to counter long-circuit float drift
      iex> result = Qx.Simulation.run(qc, renormalize: 8)
      iex> is_map(result)
      true
  """
  def run(%QuantumCircuit{} = circuit, options \\ []) do
    shots = Keyword.get(options, :shots, 1024)
    backend = Keyword.get(options, :backend)
    renorm = resolve_renormalize(options)

    run_fn = fn ->
      # Check if circuit has conditionals - if so, use shot-by-shot execution
      if has_conditionals?(circuit) do
        run_with_conditionals(circuit, shots, renorm)
      else
        # Use optimized path for non-conditional circuits
        run_without_conditionals(circuit, shots, renorm)
      end
    end

    # Use specified backend if provided, otherwise use current default
    if backend do
      Nx.with_default_backend(backend, run_fn)
    else
      run_fn.()
    end
  end

  # Resolve the `:renormalize` opt to the internal form threaded
  # through the engine: :off | :measurement | {:every, n}.
  defp resolve_renormalize(options) do
    options
    |> Keyword.get(:renormalize, false)
    |> Validation.validate_renormalize!()
    |> to_renorm()
  end

  defp to_renorm(false), do: :off
  defp to_renorm(true), do: :measurement
  defp to_renorm(n), do: {:every, n}

  # Original implementation for circuits without conditionals
  defp run_without_conditionals(%QuantumCircuit{} = circuit, shots, renorm) do
    # Execute the circuit; renorm per-gate for {:every, n}, then once
    # more at measurement-time for :measurement / {:every, n}.
    final_state =
      circuit
      |> execute_circuit(renorm)
      |> maybe_measurement_renorm(renorm)

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
  defp run_with_conditionals(%QuantumCircuit{} = circuit, shots, renorm) do
    # Execute each shot independently
    results =
      for _shot <- 1..shots do
        execute_single_shot(circuit, renorm)
      end

    # Extract classical bits from all shots
    classical_bits = Enum.map(results, fn {_state, cbits} -> cbits end)

    # Count occurrences
    counts = Enum.frequencies(classical_bits)

    # Calculate average probabilities (from final states)
    # Note: For conditional circuits, we can't provide a single final state
    # We'll use the last shot's state as representative
    {last_state, _} = List.last(results)
    final_state = maybe_measurement_renorm(last_state, renorm)
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
    * `options` - Optional keyword list (default: [])

  ## Options
    * `:backend` - Nx backend to use for computation (default: current Nx default)

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(1, 0) |> Qx.Operations.h(0)
      iex> state = Qx.Simulation.get_state(qc)
      iex> Nx.shape(state)
      {2}

  ## Raises

    * `Qx.MeasurementError` - If circuit contains measurements or conditionals
  """
  def get_state(%QuantumCircuit{} = circuit, options \\ []) do
    # Check if circuit has measurements or conditionals
    if has_measurements?(circuit) or has_conditionals?(circuit) do
      raise Qx.MeasurementError,
            "Cannot get pure state from circuit with measurements or conditionals. Use run/2 instead."
    end

    backend = Keyword.get(options, :backend)

    exec_fn = fn -> execute_circuit(circuit, :off) end

    if backend do
      Nx.with_default_backend(backend, exec_fn)
    else
      exec_fn.()
    end
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
    * `options` - Optional keyword list (default: [])

  ## Options
    * `:backend` - Nx backend to use for computation (default: current Nx default)

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(1, 0) |> Qx.Operations.h(0)
      iex> probs = Qx.Simulation.get_probabilities(qc)
      iex> Nx.shape(probs)
      {2}

  ## Raises

    * `Qx.MeasurementError` - If circuit contains measurements or conditionals
  """
  def get_probabilities(%QuantumCircuit{} = circuit, options \\ []) do
    # Check if circuit has measurements or conditionals
    if has_measurements?(circuit) or has_conditionals?(circuit) do
      raise Qx.MeasurementError,
            "Cannot get probabilities from circuit with measurements or conditionals. Use run/2 instead."
    end

    backend = Keyword.get(options, :backend)

    prob_fn = fn ->
      final_state = execute_circuit(circuit, :off)
      Math.probabilities(final_state)
    end

    if backend do
      Nx.with_default_backend(backend, prob_fn)
    else
      prob_fn.()
    end
  end

  # Private functions

  defp execute_circuit(%QuantumCircuit{} = circuit, renorm) do
    # Convert initial real state to complex representation
    initial_complex_state = real_state_to_complex(circuit.state)
    instructions = QuantumCircuit.get_instructions(circuit)

    {final_state, _count} =
      Enum.reduce(instructions, {initial_complex_state, 0}, fn instruction, {state, count} ->
        apply_gate_step(state, instruction, count, circuit.num_qubits, renorm)
      end)

    final_state
  end

  # Apply one gate, advance the 1-based gate counter, and run the
  # per-gate renorm + dev/test norm guard. Single source of the
  # every-n cadence so the non-conditional path, the conditional
  # timeline, and gates *inside* a `c_if` block all count identically.
  defp apply_gate_step(state, instruction, count, num_qubits, renorm) do
    next = count + 1

    new_state =
      instruction
      |> apply_instruction(state, num_qubits)
      |> maybe_gate_renorm(renorm, next)
      |> assert_norm()

    {new_state, next}
  end

  # Measurement-time renorm: applied for :measurement and {:every, n}.
  # :off preserves the exact prior behaviour at zero cost.
  defp maybe_measurement_renorm(state, :off), do: state
  defp maybe_measurement_renorm(state, _renorm), do: Math.normalize(state)

  # Per-gate renorm for {:every, n}: renorm after the `ordinal`-th gate
  # (1-based) when `ordinal` is a multiple of n. :off / :measurement
  # add no per-gate work (catch-all clause just returns state).
  defp maybe_gate_renorm(state, {:every, n}, ordinal) do
    if rem(ordinal, n) == 0, do: Math.normalize(state), else: state
  end

  defp maybe_gate_renorm(state, _renorm, _ordinal), do: state

  # Dev/test norm-drift guard. `validate_normalized!/2` does a host
  # sync (`Nx.to_number`); acceptable ONLY because @assert_norm is
  # compiled false in :prod (config/config.exs) so this is dead code
  # there (Iron Law Nx #5). Active in :test (config/test.exs).
  defp assert_norm(state) do
    if @assert_norm, do: :ok = Validation.validate_normalized!(state, @norm_tolerance)
    state
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
          _ -> raise Qx.GateError, {:unsupported_gate, gate_name}
        end

      1 ->
        apply_single_qubit_op(gate_name, qubits, params, state, num_qubits)

      2 ->
        apply_two_qubit_op(gate_name, qubits, params, state, num_qubits)

      3 ->
        apply_three_qubit_op(gate_name, qubits, params, state, num_qubits)

      _ ->
        raise Qx.GateError, {:unsupported_gate, gate_name}
    end
  end

  defp apply_single_qubit_op(gate_name, [qubit], params, state, num_qubits) do
    case gate_name do
      :h -> Calc.apply_single_qubit_gate(state, Gates.hadamard(), qubit, num_qubits)
      :x -> Calc.apply_single_qubit_gate(state, Gates.pauli_x(), qubit, num_qubits)
      :y -> Calc.apply_single_qubit_gate(state, Gates.pauli_y(), qubit, num_qubits)
      :z -> Calc.apply_single_qubit_gate(state, Gates.pauli_z(), qubit, num_qubits)
      :s -> Calc.apply_single_qubit_gate(state, Gates.s_gate(), qubit, num_qubits)
      :sdg -> Calc.apply_single_qubit_gate(state, Gates.s_dagger(), qubit, num_qubits)
      :t -> Calc.apply_single_qubit_gate(state, Gates.t_gate(), qubit, num_qubits)
      _ -> apply_parameterized_single_qubit_op(gate_name, qubit, params, state, num_qubits)
    end
  end

  defp apply_parameterized_single_qubit_op(gate_name, qubit, params, state, num_qubits) do
    case gate_name do
      :rx ->
        Calc.apply_single_qubit_gate(state, Gates.rx(hd(params)), qubit, num_qubits)

      :ry ->
        Calc.apply_single_qubit_gate(state, Gates.ry(hd(params)), qubit, num_qubits)

      :rz ->
        Calc.apply_single_qubit_gate(state, Gates.rz(hd(params)), qubit, num_qubits)

      :phase ->
        Calc.apply_single_qubit_gate(state, Gates.phase(hd(params)), qubit, num_qubits)

      :u ->
        [theta, phi, lambda] = params
        Calc.apply_single_qubit_gate(state, Gates.u(theta, phi, lambda), qubit, num_qubits)

      :measure ->
        state

      _ ->
        raise Qx.GateError, {:unsupported_gate, gate_name}
    end
  end

  defp apply_two_qubit_op(gate_name, [c, t], params, state, num_qubits) do
    case gate_name do
      :cx ->
        Calc.apply_cnot(state, c, t, num_qubits)

      :cz ->
        state
        |> Calc.apply_single_qubit_gate(Gates.hadamard(), t, num_qubits)
        |> Calc.apply_cnot(c, t, num_qubits)
        |> Calc.apply_single_qubit_gate(Gates.hadamard(), t, num_qubits)

      :swap ->
        Nx.dot(Gates.swap(c, t, num_qubits), state)

      :iswap ->
        Nx.dot(Gates.iswap(c, t, num_qubits), state)

      :cp ->
        Nx.dot(Gates.controlled_gate(Gates.phase(hd(params)), c, t, num_qubits), state)

      :measure ->
        state

      _ ->
        raise Qx.GateError, {:unsupported_gate, gate_name}
    end
  end

  defp apply_three_qubit_op(:ccx, [c1, c2, t], _params, state, num_qubits) do
    Calc.apply_toffoli(state, c1, c2, t, num_qubits)
  end

  defp apply_three_qubit_op(:cswap, [c, ta, tb], _params, state, num_qubits) do
    Calc.apply_cswap(state, c, ta, tb, num_qubits)
  end

  defp apply_three_qubit_op(gate_name, _qubits, _params, _state, _num_qubits) do
    raise Qx.GateError, {:unsupported_gate, gate_name}
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
  defp execute_single_shot(%QuantumCircuit{} = circuit, renorm) do
    initial_state = real_state_to_complex(circuit.state)
    classical_bits = List.duplicate(0, circuit.num_classical_bits)

    # Create instruction timeline (merges instructions and measurements)
    timeline = create_instruction_timeline(circuit)

    # Execute timeline sequentially, threading a 1-based gate counter
    # (NOT a timeline index) so the {:every, n} cadence counts actual
    # gate applications — including gates *inside* a c_if block
    # (W1 fix). Measurements do not advance the counter (a measurement
    # is not a unitary gate; collapse already renormalizes).
    {final_state, final_classical_bits, _count} =
      Enum.reduce(timeline, {initial_state, classical_bits, 0}, fn item, {state, cbits, count} ->
        process_timeline_item(item, state, cbits, count, circuit.num_qubits, renorm)
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

  defp process_timeline_item(item, state, cbits, count, num_qubits, renorm) do
    case item do
      {:instruction, instruction} ->
        {new_state, next} = apply_gate_step(state, instruction, count, num_qubits, renorm)
        {new_state, cbits, next}

      {:measurement, {qubit, cbit}} ->
        {new_state, measured_value} =
          perform_single_measurement(state, qubit, num_qubits)

        {new_state, List.replace_at(cbits, cbit, measured_value), count}

      {:conditional, {cbit, value, instructions}} ->
        process_conditional(cbits, cbit, value, instructions, state, count, num_qubits, renorm)
    end
  end

  defp process_conditional(cbits, cbit, value, instructions, state, count, num_qubits, renorm) do
    if Enum.at(cbits, cbit) == value do
      # c_if sub-gates advance the SAME gate counter, so renormalize: N
      # spans the conditional block consistently (W1 fix).
      {new_state, new_count} =
        Enum.reduce(instructions, {state, count}, fn instr, {s, c} ->
          apply_gate_step(s, instr, c, num_qubits, renorm)
        end)

      {new_state, cbits, new_count}
    else
      {state, cbits, count}
    end
  end
end
