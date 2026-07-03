defmodule Qx.Simulation do
  @moduledoc """
  Simulation engine for executing quantum circuits with full complex number support.

  This module runs circuit instructions and applies quantum gates to evolve the
  quantum state, then provides measurement probabilities and classical bit results.
  All quantum states and operations properly support complex number arithmetic.
  """

  alias Qx.{Calc, Gates, Math, QuantumCircuit, SimulationResult, Step, Validation}

  @type simulation_result :: SimulationResult.t()

  # Internal type aliases shared across the engine's private functions.
  @typep state :: Nx.Tensor.t()
  @typep renorm :: :off | :measurement | {:every, pos_integer()}
  @typep gate_name :: atom()
  @typep qubit :: non_neg_integer()
  @typep bit :: 0 | 1
  @typep instruction :: {gate_name(), [qubit()], [number()]}
  @typep measurement :: {qubit(), non_neg_integer()}
  @typep cbits :: [bit()]
  @typep counts :: %{optional([bit()]) => pos_integer()}
  @typep timeline_item ::
           {:instruction, instruction()}
           | {:measurement, measurement()}
           # conditional payload: {classical-bit index, expected bit value, body}
           | {:conditional, {non_neg_integer(), bit(), [instruction()]}}
  @typep rand_state :: :rand.state()
  # One step to be emitted by steps/2: {kind, operation, condition,
  # state-after, cbits-after}. The per-shot run path ignores these.
  @typep emission ::
           {Step.kind(), Step.operation() | nil, Step.condition() | nil, state(), cbits()}

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

      # Use EXLA for GPU/CPU acceleration. EXLA is not a Qx dependency; add it
      # to your own project first (see the README's "Performance &
      # Acceleration" section), then pass its backend here.
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
  @spec run(QuantumCircuit.t(), keyword()) :: simulation_result()
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
  @spec resolve_renormalize(keyword()) :: renorm()
  defp resolve_renormalize(options) do
    options
    |> Keyword.get(:renormalize, false)
    |> Validation.validate_renormalize!()
    |> to_renorm()
  end

  @spec to_renorm(boolean() | pos_integer()) :: renorm()
  defp to_renorm(false), do: :off
  defp to_renorm(true), do: :measurement
  defp to_renorm(n), do: {:every, n}

  # Original implementation for circuits without conditionals
  @spec run_without_conditionals(QuantumCircuit.t(), pos_integer(), renorm()) ::
          simulation_result()
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
  @spec run_with_conditionals(QuantumCircuit.t(), pos_integer(), renorm()) :: simulation_result()
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
  @spec get_state(QuantumCircuit.t(), keyword()) :: Nx.Tensor.t()
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
  @spec has_measurements?(QuantumCircuit.t()) :: boolean()
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
  @spec get_probabilities(QuantumCircuit.t(), keyword()) :: Nx.Tensor.t()
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

  @doc """
  Returns a lazy stream of `%Qx.Step{}` structs, one per executed
  operation.

  Unlike `get_state/2`, this works on circuits with mid-circuit
  measurement and `c_if`: measurements collapse the state and record
  their outcome in `classical_bits`, and each gate inside a taken
  `c_if` block yields its own step. A block that doesn't run yields a
  single step flagged `:not_taken`.

  A circuit with measurements is stochastic, so each materialisation of
  the stream samples one fresh trajectory. Pass `seed:` to reproduce a
  trajectory. Seeding never touches the caller's process `:rand` state.

  ## Options

    * `:seed` - integer seed for the trajectory's random measurement
      outcomes (default: fresh entropy per materialisation)
    * `:backend` - Nx backend to use for computation, same pass-through
      as `run/2` (default: current Nx default)
    * `:renormalize` - same contract as `run/2`; the every-`n` cadence
      counts gates inside `c_if` blocks exactly like `run/2` does
      (default: `false`)

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
      iex> steps = Qx.Simulation.steps(qc) |> Enum.to_list()
      iex> length(steps)
      2
      iex> Enum.map(steps, & &1.operation)
      [{:h, [0], []}, {:cx, [0, 1], []}]

  ## Raises

  Materialising the stream raises the same typed errors `run/2` raises:
  `Qx.GateError` on an unsupported instruction, `Qx.OptionError` on a
  bad `:renormalize` value.
  """
  @spec steps(QuantumCircuit.t(), keyword()) :: Enumerable.t()
  def steps(%QuantumCircuit{} = circuit, options \\ []) do
    backend = Keyword.get(options, :backend)
    renorm = resolve_renormalize(options)
    seed = Keyword.get(options, :seed)
    num_qubits = circuit.num_qubits
    initial_cbits = List.duplicate(0, circuit.num_classical_bits)
    timeline = create_instruction_timeline(circuit)

    Stream.transform(
      timeline,
      fn ->
        state = with_backend(backend, fn -> real_state_to_complex(circuit.state) end)
        {state, initial_cbits, 0, 0, seed_rand(seed)}
      end,
      fn item, {state, cbits, count, step_index, rand} ->
        {emissions, new_state, new_cbits, new_count, new_rand} =
          with_backend(backend, fn ->
            step_timeline_item(item, state, cbits, count, rand, num_qubits, renorm)
          end)

        steps =
          emissions
          |> Enum.with_index(step_index)
          |> Enum.map(&to_step(&1, backend))

        {steps, {new_state, new_cbits, new_count, step_index + length(emissions), new_rand}}
      end,
      fn _acc -> :ok end
    )
  end

  # Private functions

  @spec with_backend(module() | nil, (-> result)) :: result when result: var
  defp with_backend(nil, fun), do: fun.()
  defp with_backend(backend, fun), do: Nx.with_default_backend(backend, fun)

  # Explicit :rand state for measurement sampling; never the process
  # dict, so seeding a stream can't clobber the caller's RNG.
  @spec seed_rand(integer() | nil) :: rand_state()
  defp seed_rand(nil), do: :rand.seed_s(:exsss)
  defp seed_rand(seed), do: :rand.seed_s(:exsss, seed)

  @spec to_step({emission(), non_neg_integer()}, module() | nil) :: Step.t()
  defp to_step({{kind, operation, condition, state, cbits}, index}, backend) do
    probabilities = with_backend(backend, fn -> Math.probabilities(state) end)

    %Step{
      kind: kind,
      operation: operation,
      index: index,
      state: state,
      probabilities: probabilities,
      classical_bits: cbits,
      condition: condition
    }
  end

  @spec execute_circuit(QuantumCircuit.t(), renorm()) :: state()
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
  #
  # A barrier is a visual separator, not a unitary op: state unchanged
  # and the counter does NOT advance, so the renormalize: n cadence
  # ignores it. {:barrier, qubits, []} always carries the spanned
  # qubit list (Operations.barrier/2, Patterns.barrier_all, OpenQASM
  # import), so this head must match every arity.
  @spec apply_gate_step(state(), instruction(), non_neg_integer(), non_neg_integer(), renorm()) ::
          {state(), non_neg_integer()}
  defp apply_gate_step(state, {:barrier, _qubits, _params}, count, _num_qubits, _renorm) do
    {state, count}
  end

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
  @spec maybe_measurement_renorm(state(), renorm()) :: state()
  defp maybe_measurement_renorm(state, :off), do: state
  defp maybe_measurement_renorm(state, _renorm), do: Math.normalize(state)

  # Per-gate renorm for {:every, n}: renorm after the `ordinal`-th gate
  # (1-based) when `ordinal` is a multiple of n. :off / :measurement
  # add no per-gate work (catch-all clause just returns state).
  @spec maybe_gate_renorm(state(), renorm(), non_neg_integer()) :: state()
  defp maybe_gate_renorm(state, {:every, n}, ordinal) do
    if rem(ordinal, n) == 0, do: Math.normalize(state), else: state
  end

  defp maybe_gate_renorm(state, _renorm, _ordinal), do: state

  # Dev/test norm-drift guard. `validate_normalized!/2` does a host
  # sync (`Nx.to_number`); acceptable ONLY because @assert_norm is
  # compiled false in :prod (config/config.exs) so this is dead code
  # there (Iron Law Nx #5). Active in :test (config/test.exs).
  @spec assert_norm(state()) :: state()
  defp assert_norm(state) do
    if @assert_norm, do: :ok = Validation.validate_normalized!(state, @norm_tolerance)
    state
  end

  @spec real_state_to_complex(Nx.Tensor.t()) :: state()
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

  @spec apply_instruction(instruction(), state(), non_neg_integer()) :: state()
  defp apply_instruction({gate_name, qubits, params}, state, num_qubits) do
    case length(qubits) do
      0 ->
        # Barriers never reach here (intercepted in apply_gate_step);
        # no other 0-qubit instruction exists.
        raise Qx.GateError, {:unsupported_gate, gate_name}

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

  @spec apply_single_qubit_op(gate_name(), [qubit()], [number()], state(), non_neg_integer()) ::
          state()
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

  @spec apply_parameterized_single_qubit_op(
          gate_name(),
          qubit(),
          [number()],
          state(),
          non_neg_integer()
        ) :: state()
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

  @spec apply_two_qubit_op(gate_name(), [qubit()], [number()], state(), non_neg_integer()) ::
          state()
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

      :measure ->
        state

      _ ->
        apply_controlled_target_op(gate_name, c, t, params, state, num_qubits)
    end
  end

  # Lifts a single-qubit gate matrix (parameterised by `gate_name` and
  # `params`) into the controlled two-qubit gate `|0⟩⟨0|⊗I + |1⟩⟨1|⊗U`,
  # then applies it to `state`. Covers `cp`, `cy`, `crx`, `cry`, `crz`.
  @spec apply_controlled_target_op(
          gate_name(),
          qubit(),
          qubit(),
          [number()],
          state(),
          non_neg_integer()
        ) :: state()
  defp apply_controlled_target_op(gate_name, c, t, params, state, num_qubits) do
    target_gate =
      case gate_name do
        :cp -> Gates.phase(hd(params))
        :cy -> Gates.pauli_y()
        :crx -> Gates.rx(hd(params))
        :cry -> Gates.ry(hd(params))
        :crz -> Gates.rz(hd(params))
        _ -> raise Qx.GateError, {:unsupported_gate, gate_name}
      end

    Nx.dot(Gates.controlled_gate(target_gate, c, t, num_qubits), state)
  end

  @spec apply_three_qubit_op(gate_name(), [qubit()], [number()], state(), non_neg_integer()) ::
          state()
  defp apply_three_qubit_op(:ccx, [c1, c2, t], _params, state, num_qubits) do
    Calc.apply_toffoli(state, c1, c2, t, num_qubits)
  end

  defp apply_three_qubit_op(:cswap, [c, ta, tb], _params, state, num_qubits) do
    Calc.apply_cswap(state, c, ta, tb, num_qubits)
  end

  defp apply_three_qubit_op(gate_name, _qubits, _params, _state, _num_qubits) do
    raise Qx.GateError, {:unsupported_gate, gate_name}
  end

  @spec perform_measurements(QuantumCircuit.t(), state(), pos_integer()) :: {[[bit()]], counts()}
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

  @spec generate_samples([float()], pos_integer()) :: [non_neg_integer()]
  defp generate_samples(probabilities, shots) do
    # Create cumulative distribution
    cumulative = Enum.scan(probabilities, &(&1 + &2))

    # Generate random samples
    for _ <- 1..shots do
      rand = :rand.uniform()
      Enum.find_index(cumulative, fn cum_prob -> rand <= cum_prob end) || 0
    end
  end

  @spec extract_classical_bits([non_neg_integer()], [measurement()], non_neg_integer()) ::
          [[bit()]]
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
  @spec has_conditionals?(QuantumCircuit.t()) :: boolean()
  defp has_conditionals?(%QuantumCircuit{} = circuit) do
    Enum.any?(circuit.instructions, fn
      {:c_if, _, _} -> true
      _ -> false
    end)
  end

  # Execute a single shot of a circuit with conditionals
  @spec execute_single_shot(QuantumCircuit.t(), renorm()) :: {state(), cbits()}
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
    # RNG state is threaded explicitly (fresh entropy per shot) and the
    # per-item emissions are discarded — steps/2 is the consumer.
    {final_state, final_classical_bits, _count, _rand} =
      Enum.reduce(
        timeline,
        {initial_state, classical_bits, 0, seed_rand(nil)},
        fn item, {state, cbits, count, rand} ->
          {_emissions, new_state, new_cbits, new_count, new_rand} =
            step_timeline_item(item, state, cbits, count, rand, circuit.num_qubits, renorm)

          {new_state, new_cbits, new_count, new_rand}
        end
      )

    {final_state, final_classical_bits}
  end

  # Create unified timeline of operations (instructions and measurements)
  @spec create_instruction_timeline(QuantumCircuit.t()) :: [timeline_item()]
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

  # Perform a single measurement and collapse the state. Takes and
  # returns explicit :rand state (:rand.uniform_s/1) so measurement
  # sampling never reads or writes the process dict.
  @spec perform_single_measurement(state(), qubit(), non_neg_integer(), rand_state()) ::
          {state(), bit(), rand_state()}
  defp perform_single_measurement(state, qubit, num_qubits, rand) do
    # Calculate probability of measuring |0⟩
    prob_0 = calculate_measurement_probability(state, qubit, 0, num_qubits)

    # Random measurement outcome
    {uniform, new_rand} = :rand.uniform_s(rand)
    measured_value = if uniform < prob_0, do: 0, else: 1

    # Collapse state to measured outcome
    collapsed_state = collapse_to_measurement(state, qubit, measured_value, num_qubits)

    {collapsed_state, measured_value, new_rand}
  end

  # Calculate probability of measuring a specific value for a qubit
  @spec calculate_measurement_probability(state(), qubit(), bit(), non_neg_integer()) :: float()
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
  @spec collapse_to_measurement(state(), qubit(), bit(), non_neg_integer()) :: state()
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

  # Process one timeline item and return the steps it emits alongside
  # the threaded accumulator. Single execution path shared by run/2's
  # per-shot reduce (emissions discarded) and steps/2 (emissions become
  # %Qx.Step{} structs).
  @spec step_timeline_item(
          timeline_item(),
          state(),
          cbits(),
          non_neg_integer(),
          rand_state(),
          non_neg_integer(),
          renorm()
        ) :: {[emission()], state(), cbits(), non_neg_integer(), rand_state()}
  defp step_timeline_item(item, state, cbits, count, rand, num_qubits, renorm) do
    case item do
      {:instruction, instruction} ->
        {new_state, next} = apply_gate_step(state, instruction, count, num_qubits, renorm)
        {[{:gate, instruction, nil, new_state, cbits}], new_state, cbits, next, rand}

      {:measurement, {qubit, cbit}} ->
        {new_state, measured_value, new_rand} =
          perform_single_measurement(state, qubit, num_qubits, rand)

        new_cbits = List.replace_at(cbits, cbit, measured_value)
        emission = {:measurement, {:measure, [qubit, cbit], []}, nil, new_state, new_cbits}
        {[emission], new_state, new_cbits, count, new_rand}

      {:conditional, condition} ->
        step_conditional(condition, state, cbits, count, rand, num_qubits, renorm)
    end
  end

  @spec step_conditional(
          {non_neg_integer(), bit(), [instruction()]},
          state(),
          cbits(),
          non_neg_integer(),
          rand_state(),
          non_neg_integer(),
          renorm()
        ) :: {[emission()], state(), cbits(), non_neg_integer(), rand_state()}
  defp step_conditional(
         {cbit, value, instructions},
         state,
         cbits,
         count,
         rand,
         num_qubits,
         renorm
       ) do
    if Enum.at(cbits, cbit) == value do
      # c_if sub-gates advance the SAME gate counter, so renormalize: N
      # spans the conditional block consistently (W1 fix). One emission
      # per inner gate, each flagged :taken.
      {emissions, new_state, new_count} =
        Enum.reduce(instructions, {[], state, count}, fn instr, {acc, s, c} ->
          {stepped, next} = apply_gate_step(s, instr, c, num_qubits, renorm)
          {[{:conditional, instr, {cbit, value, :taken}, stepped, cbits} | acc], stepped, next}
        end)

      {Enum.reverse(emissions), new_state, cbits, new_count, rand}
    else
      # A block that doesn't run still emits one flagged step, so the
      # step count matches what a reader sees in the drawing.
      emission = {:conditional, nil, {cbit, value, :not_taken}, state, cbits}
      {[emission], state, cbits, count, rand}
    end
  end
end
