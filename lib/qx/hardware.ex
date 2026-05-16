defmodule Qx.Hardware do
  @moduledoc """
  Execute Qx circuits on real IBM Quantum hardware.

  Orchestrates the full pipeline:

  ```
  circuit  →  QASM  →  qxportal transpile  →  IBM submit  →  poll
                                                   ↓
                                              IBM results
                                                   ↓
                                         Qx.SimulationResult
  ```

  ## Configuration

  All entry points require a `Qx.Hardware.Config`, which carries portal
  + IBM credentials and execution preferences (backend, shots,
  optimization level). See `Qx.Hardware.Config` for details and
  `Qx.Hardware.Config.from_env/1` for the environment-driven setup
  used in `examples/hardware/run_on_ibm.exs`.

  ## Privacy invariant

  The portal token never reaches `Qx.Hardware.Ibm`, and the IBM API key
  / CRN never reach `Qx.Hardware.Portal`. The two clients read only
  their own fields from the shared `Qx.Hardware.Config` struct.

  ## Status callback

  Pass `:on_status` in `opts` to receive pipeline events:

      run(circuit, config, on_status: fn event -> Logger.debug(inspect(event)) end)

  Events (all atoms, allowlisted — Iron Law #1):

    * `{:portal, :connecting}` — emitted by `connect/1`
    * `{:portal, :listing_backends}`
    * `{:portal, :transpiling}`
    * `{:ibm, :authenticating}`
    * `{:ibm, :fetching_backend}`
    * `{:ibm, :submitting}`
    * `{:ibm, :job_started, job_id}` — `job_id` is a binary
    * `{:ibm, :polling, status}` — `status` is a binary in
      `["Queued", "Running", "Completed", "Cancelled", ...]`
    * `{:ibm, :fetching_results}`

  ## Error returns

  Every failure mode normalises to `{:error, {stage, reason}}`, where
  `stage` is one of:

    * `:config` — config validation or measurement check failed
    * `:portal` — `/api/v1/me` or `/api/v1/transpile` failed
    * `:ibm_auth` — IAM exchange or backend lookup failed
    * `:ibm_submit` — `POST /jobs` failed
    * `:ibm_poll` — poll request failed (not the same as terminal
      `Failed`/`Cancelled`)
    * `:ibm_poll_timeout` — overall poll deadline exceeded
    * `:ibm_job_failed` — IBM returned terminal `Failed` /
      `Cancelled` / `Cancelled - Ran too long`
    * `:ibm_results` — results fetch / parse failed

  ## Synchronous, blocking

  `run/3` and `submit_qasm/3` block until the IBM job reaches a terminal
  status. Hardware queues can take hours; callers that need to surface
  progress should wire `:on_status` and/or run the call in a supervised
  Task. The Livebook integration in `kino_qx` wraps this in a monitored
  Task with a cancel button — non-Livebook callers must arrange their
  own supervision if they need async cancel.
  """

  alias Qx.Export.OpenQASM
  alias Qx.Hardware.Config
  alias Qx.Hardware.ConfigError
  alias Qx.Hardware.ExecutionError
  alias Qx.Hardware.Ibm
  alias Qx.Hardware.NoMeasurementsError
  alias Qx.Hardware.Portal
  alias Qx.QuantumCircuit
  alias Qx.ResultBuilder
  alias Qx.SimulationResult

  @poll_first_interval_ms 1_000
  @poll_max_interval_ms 30_000
  # 24 hours — IBM queues can be very long. Callers can override.
  @default_timeout_ms 24 * 60 * 60 * 1000

  @type stage ::
          :config
          | :portal
          | :ibm_auth
          | :ibm_submit
          | :ibm_poll
          | :ibm_poll_timeout
          | :ibm_job_failed
          | :ibm_results

  @type error :: {:error, {stage(), term()} | ConfigError.t() | NoMeasurementsError.t()}

  @typedoc """
  Pipeline options accepted by `run/3`, `submit_qasm/3`, etc.

    * `:on_status` — `(event -> any)` callback; defaults to no-op.
    * `:shots` — override `config.shots`.
    * `:timeout_ms` — overall poll deadline; default 24h.
    * `:seed_transpiler` — optional integer seed passed to the portal.
    * `:ibm` / `:portal` — module overrides for test/stub injection.
    * `:sleep` — `(non_neg_integer -> any)` override for the poll sleep
      (test hook).
  """
  @type opts :: keyword()

  ## ------------------------------------------------------------------
  ## Public API
  ## ------------------------------------------------------------------

  @doc """
  Runs a quantum circuit on IBM hardware.

  Exports the circuit to OpenQASM 3.0, hands it to the qxportal
  transpiler, submits to IBM, polls until done, and reconstructs a
  `%Qx.SimulationResult{}` from the returned counts.

  The circuit MUST contain at least one measurement instruction; an
  unmeasured circuit raises `Qx.Hardware.NoMeasurementsError`.
  """
  @spec run(QuantumCircuit.t(), Config.t(), opts()) ::
          {:ok, SimulationResult.t()} | error()
  def run(%QuantumCircuit{} = circuit, %Config{} = config, opts \\ []) do
    with :ok <- check_measurements(circuit),
         {:ok, qasm} <- circuit_to_qasm(circuit) do
      submit_qasm(qasm, config, Keyword.put(opts, :num_bits, num_classical_bits(circuit)))
    end
  end

  @doc """
  Same as `run/3` but raises on failure.
  """
  @spec run!(QuantumCircuit.t(), Config.t(), opts()) :: SimulationResult.t()
  def run!(circuit, config, opts \\ []) do
    case run(circuit, config, opts) do
      {:ok, result} -> result
      {:error, exception} when is_exception(exception) -> raise exception
      {:error, reason} -> raise ExecutionError.exception(reason)
    end
  end

  @doc """
  Submits a hand-authored OpenQASM 3.0 program directly. Skips circuit
  → QASM conversion and the measurement pre-flight check (the caller
  owns the QASM).

  `opts[:num_bits]` should be the number of classical bits in the
  program; defaults to inferring from `length(first sample)` returned
  by IBM.
  """
  @spec submit_qasm(String.t(), Config.t(), opts()) ::
          {:ok, SimulationResult.t()} | error()
  def submit_qasm(qasm, %Config{} = config, opts \\ []) when is_binary(qasm) do
    on_status = Keyword.get(opts, :on_status, fn _ -> :ok end)
    ibm = Keyword.get(opts, :ibm, Ibm)
    portal = Keyword.get(opts, :portal, Portal)
    sleep_fn = Keyword.get(opts, :sleep, &Process.sleep/1)
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_timeout_ms)
    shots = Keyword.get(opts, :shots, config.shots)
    seed = Keyword.get(opts, :seed_transpiler)
    num_bits = Keyword.get(opts, :num_bits)

    with :ok <- require_backend(config),
         {:ok, config} <- ensure_connected(config, portal, ibm, on_status),
         {:ok, ibm_cfg} <- ibm_authenticate(config, ibm, on_status),
         {:ok, props} <- ibm_fetch_backend(ibm_cfg, ibm, on_status),
         {:ok, transpiled} <-
           portal_transpile(config, portal, qasm, props, seed, on_status),
         {:ok, job_id} <-
           ibm_submit(ibm_cfg, ibm, transpiled.qasm, config.backend, shots, on_status),
         _ = on_status.({:ibm, :job_started, job_id}),
         {:ok, _info} <-
           poll_until_done(ibm, ibm_cfg, job_id, on_status, sleep_fn, timeout_ms),
         {:ok, results} <- ibm_fetch_results(ibm_cfg, ibm, job_id, on_status) do
      num_bits = num_bits || infer_num_bits(results.counts)
      {:ok, ResultBuilder.from_counts(results.counts, shots, num_bits)}
    end
  end

  @doc """
  Transpiles QASM or a circuit via qxportal, without submitting.

  Useful for inspecting the transpiled program before submission.
  """
  @spec transpile(QuantumCircuit.t() | String.t(), Config.t(), opts()) ::
          {:ok, String.t()} | error()
  def transpile(input, config, opts \\ [])

  def transpile(%QuantumCircuit{} = circuit, %Config{} = config, opts) do
    with {:ok, qasm} <- circuit_to_qasm(circuit) do
      transpile(qasm, config, opts)
    end
  end

  def transpile(qasm, %Config{} = config, opts) when is_binary(qasm) do
    portal = Keyword.get(opts, :portal, Portal)
    ibm = Keyword.get(opts, :ibm, Ibm)
    on_status = Keyword.get(opts, :on_status, fn _ -> :ok end)
    seed = Keyword.get(opts, :seed_transpiler)

    with {:ok, config} <- ensure_connected(config, portal, ibm, on_status),
         {:ok, ibm_cfg} <- ibm_authenticate(config, ibm, on_status),
         {:ok, props} <- ibm_fetch_backend(ibm_cfg, ibm, on_status),
         {:ok, transpiled} <-
           portal_transpile(config, portal, qasm, props, seed, on_status) do
      {:ok, transpiled.qasm}
    end
  end

  @doc """
  Lists IBM backends available to the configured account, populating
  `config.backends_list` as a side product on the returned config.
  """
  @spec list_backends(Config.t(), opts()) :: {:ok, [String.t()], Config.t()} | error()
  def list_backends(%Config{} = config, opts \\ []) do
    ibm = Keyword.get(opts, :ibm, Ibm)

    with {:ok, ibm_cfg} <- ibm_authenticate(config, ibm, fn _ -> :ok end),
         {:ok, summaries} <-
           stage(:ibm_auth, fn -> ibm.list_backends(ibm_cfg) end) do
      names = Enum.map(summaries, & &1.name)
      {:ok, names, %{config | backends_list: names}}
    end
  end

  @doc """
  Cancels a running IBM job. Best-effort, synchronous.
  """
  @spec cancel(String.t(), Config.t(), opts()) :: :ok | error()
  def cancel(job_id, %Config{} = config, opts \\ []) when is_binary(job_id) do
    ibm = Keyword.get(opts, :ibm, Ibm)

    with {:ok, ibm_cfg} <- ibm_authenticate(config, ibm, fn _ -> :ok end) do
      case ibm.cancel_job(ibm_cfg, job_id) do
        :ok -> :ok
        {:error, reason} -> {:error, {:ibm_poll, reason}}
      end
    end
  end

  @doc """
  Establishes a session with qxportal: fetches `/api/v1/me`, performs
  the IBM IAM exchange, and lists the account's backends.

  Returns the same config with `identity` and `backends_list`
  populated.

  This is a *discovery* call — it is meant to be usable **before** a
  backend has been chosen (the caller typically picks from the returned
  `backends_list`). Therefore:

    * if `config.backend` is blank (`nil` or `""`), the backend
      membership check is skipped and the populated config is returned;
    * if `config.backend` is set, it is validated against the fetched
      `backends_list` and a `Qx.Hardware.ConfigError` is returned when
      it is not available to the account (catches typos early).

  Running a circuit still requires a chosen backend — `run/3`,
  `run!/3`, and `submit_qasm/3` reject a blank backend up front.
  """
  @spec connect(Config.t(), opts()) :: {:ok, Config.t()} | error()
  def connect(%Config{} = config, opts \\ []) do
    portal = Keyword.get(opts, :portal, Portal)
    ibm = Keyword.get(opts, :ibm, Ibm)
    on_status = Keyword.get(opts, :on_status, fn _ -> :ok end)
    do_connect(config, portal, ibm, on_status)
  end

  ## ------------------------------------------------------------------
  ## Internals
  ## ------------------------------------------------------------------

  defp ensure_connected(%Config{identity: nil} = config, portal, ibm, on_status),
    do: do_connect(config, portal, ibm, on_status)

  defp ensure_connected(%Config{backends_list: []} = config, portal, ibm, on_status),
    do: do_connect(config, portal, ibm, on_status)

  defp ensure_connected(%Config{} = config, _portal, _ibm, _on_status) do
    # `in` doesn't compile in guards against a runtime list, so the
    # backend ∈ backends_list check stays in the body.
    if config.backend in config.backends_list do
      {:ok, config}
    else
      {:error,
       {:config,
        ConfigError.exception(
          field: :backend,
          reason:
            "backend #{inspect(config.backend)} not in account's backends_list " <>
              inspect(config.backends_list)
        )}}
    end
  end

  defp do_connect(%Config{} = config, portal, ibm, on_status) do
    on_status.({:portal, :connecting})

    with {:ok, identity} <- stage(:portal, fn -> portal.me(config) end),
         _ = on_status.({:portal, :listing_backends}),
         {:ok, ibm_cfg} <- ibm_authenticate(config, ibm, on_status),
         {:ok, summaries} <- stage(:ibm_auth, fn -> ibm.list_backends(ibm_cfg) end) do
      backends = Enum.map(summaries, & &1.name)

      config =
        %{
          config
          | identity: identity_label(identity),
            backends_list: backends,
            access_token: ibm_cfg.access_token,
            token_expires_at: ibm_cfg.token_expires_at
        }

      cond do
        # Discovery call: no backend chosen yet — return the populated
        # config so the caller can pick from backends_list.
        blank_backend?(config) ->
          {:ok, config}

        config.backend in backends ->
          {:ok, config}

        true ->
          {:error,
           {:config,
            ConfigError.exception(
              field: :backend,
              reason:
                "backend #{inspect(config.backend)} not in account's backends " <>
                  inspect(backends)
            )}}
      end
    end
  end

  # A backend must be chosen before a circuit can run/submit. `connect/2`
  # (discovery) is exempt — it populates backends_list precisely so the
  # caller can choose.
  defp require_backend(%Config{} = config) do
    if blank_backend?(config) do
      {:error,
       {:config,
        ConfigError.exception(
          field: :backend,
          reason: "is required to run a circuit (none selected)"
        )}}
    else
      :ok
    end
  end

  defp blank_backend?(%Config{backend: nil}), do: true
  defp blank_backend?(%Config{backend: ""}), do: true
  defp blank_backend?(%Config{backend: b}) when is_binary(b), do: String.trim(b) == ""
  defp blank_backend?(%Config{}), do: false

  defp identity_label(%{email: email}) when is_binary(email), do: email
  defp identity_label(%{"email" => email}) when is_binary(email), do: email
  defp identity_label(other), do: inspect(other)

  defp ibm_authenticate(%Config{access_token: token} = config, _ibm, _on_status)
       when is_binary(token) do
    {:ok, config}
  end

  defp ibm_authenticate(%Config{} = config, ibm, on_status) do
    on_status.({:ibm, :authenticating})
    stage(:ibm_auth, fn -> ibm.iam_exchange(config) end)
  end

  defp ibm_fetch_backend(%Config{} = ibm_cfg, ibm, on_status) do
    on_status.({:ibm, :fetching_backend})
    stage(:ibm_auth, fn -> ibm.fetch_backend_configuration(ibm_cfg, ibm_cfg.backend) end)
  end

  defp portal_transpile(%Config{} = config, portal, qasm, props, seed, on_status) do
    on_status.({:portal, :transpiling})

    transpile_opts = [
      backend: config.backend,
      coupling_map: props.coupling_map,
      basis_gates: props.basis_gates,
      optimization_level: config.optimization_level,
      seed_transpiler: seed
    ]

    stage(:portal, fn -> portal.transpile(config, qasm, transpile_opts) end)
  end

  defp ibm_submit(%Config{} = ibm_cfg, ibm, qasm, backend, shots, on_status) do
    on_status.({:ibm, :submitting})
    stage(:ibm_submit, fn -> ibm.submit_sampler(ibm_cfg, qasm, backend, shots) end)
  end

  defp ibm_fetch_results(%Config{} = ibm_cfg, ibm, job_id, on_status) do
    on_status.({:ibm, :fetching_results})
    stage(:ibm_results, fn -> ibm.fetch_results(ibm_cfg, job_id) end)
  end

  defp stage(stage_atom, fun) when is_atom(stage_atom) and is_function(fun, 0) do
    case fun.() do
      {:ok, value} -> {:ok, value}
      :ok -> :ok
      {:error, reason} -> {:error, {stage_atom, reason}}
    end
  end

  defp poll_until_done(ibm, cfg, job_id, on_status, sleep_fn, timeout_ms) do
    state = %{
      ibm: ibm,
      cfg: cfg,
      job_id: job_id,
      on_status: on_status,
      sleep_fn: sleep_fn,
      deadline: System.monotonic_time(:millisecond) + timeout_ms,
      interval: @poll_first_interval_ms
    }

    do_poll(state)
  end

  defp do_poll(state) do
    if System.monotonic_time(:millisecond) > state.deadline do
      {:error, {:ibm_poll_timeout, :deadline_exceeded}}
    else
      poll_once(state)
    end
  end

  defp poll_once(state) do
    case state.ibm.poll_job(state.cfg, state.job_id) do
      {:ok, %{status: status} = info} ->
        state.on_status.({:ibm, :polling, status})
        handle_poll_status(state, info, status)

      {:error, reason} ->
        {:error, {:ibm_poll, reason}}
    end
  end

  defp handle_poll_status(state, info, status) do
    success? = state.ibm.terminal_success?(status)
    failure? = state.ibm.terminal_failure?(status)

    cond do
      success? ->
        {:ok, info}

      failure? ->
        {:error, {:ibm_job_failed, %{status: status, reason: info[:reason]}}}

      true ->
        state.sleep_fn.(state.interval)
        next_interval = min(state.interval * 2, @poll_max_interval_ms)
        do_poll(%{state | interval: next_interval})
    end
  end

  defp check_measurements(%QuantumCircuit{measurements: []} = circuit),
    do: {:error, NoMeasurementsError.exception(circuit)}

  defp check_measurements(%QuantumCircuit{measurements: [_ | _]}), do: :ok

  defp circuit_to_qasm(%QuantumCircuit{} = circuit) do
    {:ok, OpenQASM.to_qasm(circuit)}
  rescue
    exception -> {:error, {:config, exception}}
  end

  defp num_classical_bits(%QuantumCircuit{num_classical_bits: n}), do: n

  defp infer_num_bits(counts) when is_map(counts) and map_size(counts) > 0 do
    counts |> Map.keys() |> List.first() |> String.length()
  end

  defp infer_num_bits(_), do: 0
end
