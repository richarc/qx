defmodule Qx.HardwareTest do
  @moduledoc """
  Verifies the `Qx.Hardware` orchestrator's stage sequencing, error
  routing, and poll-loop behaviour with stub IBM + Portal clients.

  Adapted from `kino_qx/test/kino/qx/transpile_pipeline_test.exs`; the
  new lazy-connect + measurement-check tests are unique to this plan.
  """
  use ExUnit.Case, async: true

  alias Qx.Hardware
  alias Qx.Hardware.Config
  alias Qx.Hardware.ConfigError
  alias Qx.Hardware.NoMeasurementsError
  alias Qx.Hardware.StubIbm
  alias Qx.Hardware.StubIbm.Recorder
  alias Qx.QuantumCircuit

  setup do
    {:ok, recorder} = Recorder.start_link()

    config = %Config{
      portal_url: "http://localhost",
      portal_token: "ptok",
      ibm_api_key: "ibm_key",
      ibm_crn: "crn",
      ibm_region: "us-south",
      backend: "ibm_brisbane",
      # Pre-populate identity + backends_list so lazy-connect is a no-op
      # in most tests. Lazy-connect itself is exercised in its own
      # describe block.
      identity: "test@example.com",
      backends_list: ["ibm_brisbane"]
    }

    config = Map.put(config, :__recorder__, recorder)

    %{recorder: recorder, config: config}
  end

  defp bell_circuit do
    QuantumCircuit.new(2, 2)
    |> Qx.h(0)
    |> Qx.cx(0, 1)
    |> Qx.measure(0, 0)
    |> Qx.measure(1, 1)
  end

  defp script_happy_path(recorder, opts \\ []) do
    poll_sequence =
      Keyword.get(opts, :polls, [
        {:ok, %{status: "Queued", reason: nil}},
        {:ok, %{status: "Running", reason: nil}},
        {:ok, %{status: "Completed", reason: nil}}
      ])

    # Lazy-connect tests script :iam_exchange themselves (the returned
    # config needs different field state); they pass `skip_iam_exchange: true`
    # so this helper leaves the recorder entry alone.
    unless Keyword.get(opts, :skip_iam_exchange, false) do
      Recorder.set(
        recorder,
        :iam_exchange,
        {:ok,
         %Config{
           portal_url: "http://localhost",
           portal_token: "ptok",
           ibm_api_key: "ibm_key",
           ibm_crn: "crn",
           ibm_region: "us-south",
           backend: "ibm_brisbane",
           access_token: "t",
           identity: "test@example.com",
           backends_list: ["ibm_brisbane"]
         }
         |> Map.put(:__recorder__, recorder)}
      )
    end

    Recorder.set(
      recorder,
      :fetch_backend_configuration,
      {:ok, %{coupling_map: [[0, 1]], basis_gates: ["cx"], num_qubits: 2}}
    )

    Recorder.set(
      recorder,
      :transpile,
      {:ok,
       %{qasm: "OPENQASM 3.0;\n// TRANSPILED;", metadata: %{depth: 1, size: 1, num_qubits: 2}}}
    )

    Recorder.set(recorder, :submit_sampler, {:ok, "job_1"})
    Recorder.set(recorder, :poll_job, poll_sequence)

    Recorder.set(
      recorder,
      :fetch_results,
      {:ok, %{counts: %{"00" => 500, "11" => 524}, metadata: %{execution_time_ms: 42}}}
    )
  end

  defp base_opts do
    [
      ibm: StubIbm.Ibm,
      portal: StubIbm.Portal,
      sleep: fn _ -> :ok end
    ]
  end

  describe "run/3 happy path" do
    test "sequences all stages and returns SimulationResult", ctx do
      script_happy_path(ctx.recorder)

      test_pid = self()
      opts = Keyword.put(base_opts(), :on_status, &send(test_pid, {:status, &1}))

      assert {:ok, result} = Hardware.run(bell_circuit(), ctx.config, opts)
      assert result.counts == %{"00" => 500, "11" => 524}
      assert result.shots == 4096

      events = drain_statuses()
      assert {:ibm, :authenticating} in events
      assert {:ibm, :fetching_backend} in events
      assert {:portal, :transpiling} in events
      assert {:ibm, :submitting} in events
      assert {:ibm, :job_started, "job_1"} in events
      assert {:ibm, :polling, "Queued"} in events
      assert {:ibm, :polling, "Completed"} in events
      assert {:ibm, :fetching_results} in events

      call_keys = ctx.recorder |> Recorder.calls() |> Enum.map(&elem(&1, 0))

      assert call_keys == [
               :iam_exchange,
               :fetch_backend_configuration,
               :transpile,
               :submit_sampler,
               :poll_job,
               :poll_job,
               :poll_job,
               :fetch_results
             ]
    end

    test "transpile payload uses backend properties + optimization_level", ctx do
      script_happy_path(ctx.recorder)

      config = %{ctx.config | optimization_level: 3}
      assert {:ok, _} = Hardware.run(bell_circuit(), config, base_opts())

      [{:transpile, [_cfg, qasm, transpile_opts]} | _] =
        ctx.recorder
        |> Recorder.calls()
        |> Enum.filter(fn {k, _} -> k == :transpile end)

      assert transpile_opts[:coupling_map] == [[0, 1]]
      assert transpile_opts[:basis_gates] == ["cx"]
      assert transpile_opts[:optimization_level] == 3
      assert qasm =~ "OPENQASM"
    end

    test "submit receives the transpiled qasm + default shots", ctx do
      script_happy_path(ctx.recorder)
      assert {:ok, _} = Hardware.run(bell_circuit(), ctx.config, base_opts())

      [{:submit_sampler, [_, qasm, backend, shots]}] =
        ctx.recorder |> Recorder.calls() |> Enum.filter(fn {k, _} -> k == :submit_sampler end)

      assert qasm =~ "TRANSPILED"
      assert backend == "ibm_brisbane"
      assert shots == 4096
    end

    test "shots opt threads through to submit_sampler", ctx do
      script_happy_path(ctx.recorder)

      opts = Keyword.put(base_opts(), :shots, 1024)
      assert {:ok, _} = Hardware.run(bell_circuit(), ctx.config, opts)

      [{:submit_sampler, [_, _, _, shots]}] =
        ctx.recorder |> Recorder.calls() |> Enum.filter(fn {k, _} -> k == :submit_sampler end)

      assert shots == 1024
    end
  end

  describe "error routing" do
    test "iam_exchange failure → {:error, {:ibm_auth, reason}}", ctx do
      Recorder.set(ctx.recorder, :iam_exchange, {:error, :unauthorized})

      assert {:error, {:ibm_auth, :unauthorized}} =
               Hardware.run(bell_circuit(), ctx.config, base_opts())
    end

    test "fetch_backend_configuration failure → {:error, {:ibm_auth, _}}", ctx do
      Recorder.set(
        ctx.recorder,
        :iam_exchange,
        {:ok, Map.put(ctx.config, :access_token, "t")}
      )

      Recorder.set(ctx.recorder, :fetch_backend_configuration, {:error, :not_found})

      assert {:error, {:ibm_auth, :not_found}} =
               Hardware.run(bell_circuit(), ctx.config, base_opts())
    end

    test "portal transpile failure → {:error, {:portal, reason}}", ctx do
      script_happy_path(ctx.recorder)
      Recorder.set(ctx.recorder, :transpile, {:error, :transpile_failed})

      assert {:error, {:portal, :transpile_failed}} =
               Hardware.run(bell_circuit(), ctx.config, base_opts())
    end

    test "submit_sampler failure → {:error, {:ibm_submit, reason}}", ctx do
      script_happy_path(ctx.recorder)
      Recorder.set(ctx.recorder, :submit_sampler, {:error, {:http, 500, %{}}})

      assert {:error, {:ibm_submit, {:http, 500, %{}}}} =
               Hardware.run(bell_circuit(), ctx.config, base_opts())
    end

    test "poll deadline exceeded → :ibm_poll_timeout", ctx do
      script_happy_path(ctx.recorder,
        polls: List.duplicate({:ok, %{status: "Queued", reason: nil}}, 100)
      )

      # Negative timeout puts the deadline in the past *before* the
      # first `>` check in do_poll/1; `timeout_ms: 0` would race against
      # monotonic_time on fast machines.
      opts = Keyword.put(base_opts(), :timeout_ms, -1)

      assert {:error, {:ibm_poll_timeout, :deadline_exceeded}} =
               Hardware.run(bell_circuit(), ctx.config, opts)
    end

    test "job ends with Failed → :ibm_job_failed", ctx do
      script_happy_path(ctx.recorder,
        polls: [
          {:ok, %{status: "Queued", reason: nil}},
          {:ok, %{status: "Failed", reason: "circuit too large"}}
        ]
      )

      assert {:error, {:ibm_job_failed, %{status: "Failed", reason: "circuit too large"}}} =
               Hardware.run(bell_circuit(), ctx.config, base_opts())
    end

    test "job ends with Cancelled → :ibm_job_failed", ctx do
      script_happy_path(ctx.recorder,
        polls: [{:ok, %{status: "Cancelled", reason: "user"}}]
      )

      assert {:error, {:ibm_job_failed, %{status: "Cancelled"}}} =
               Hardware.run(bell_circuit(), ctx.config, base_opts())
    end

    test "job ends with Cancelled - Ran too long → :ibm_job_failed", ctx do
      script_happy_path(ctx.recorder,
        polls: [{:ok, %{status: "Cancelled - Ran too long", reason: nil}}]
      )

      assert {:error, {:ibm_job_failed, %{status: "Cancelled - Ran too long"}}} =
               Hardware.run(bell_circuit(), ctx.config, base_opts())
    end

    test "poll request itself fails → :ibm_poll", ctx do
      script_happy_path(ctx.recorder, polls: [{:error, {:network, :timeout}}])

      assert {:error, {:ibm_poll, {:network, :timeout}}} =
               Hardware.run(bell_circuit(), ctx.config, base_opts())
    end

    test "fetch_results failure → :ibm_results", ctx do
      script_happy_path(ctx.recorder)
      Recorder.set(ctx.recorder, :fetch_results, {:error, :unsupported_result})

      assert {:error, {:ibm_results, :unsupported_result}} =
               Hardware.run(bell_circuit(), ctx.config, base_opts())
    end
  end

  describe "on_status callback" do
    test "is optional", ctx do
      script_happy_path(ctx.recorder)
      assert {:ok, _} = Hardware.run(bell_circuit(), ctx.config, base_opts())
    end

    test "polling emits status on each iteration", ctx do
      script_happy_path(ctx.recorder)

      test_pid = self()
      opts = Keyword.put(base_opts(), :on_status, &send(test_pid, {:status, &1}))

      assert {:ok, _} = Hardware.run(bell_circuit(), ctx.config, opts)

      poll_events =
        drain_statuses()
        |> Enum.filter(&match?({:ibm, :polling, _}, &1))

      assert length(poll_events) == 3
      assert {:ibm, :polling, "Queued"} in poll_events
      assert {:ibm, :polling, "Running"} in poll_events
      assert {:ibm, :polling, "Completed"} in poll_events
    end

    test "events fire in documented order", ctx do
      script_happy_path(ctx.recorder)

      test_pid = self()
      opts = Keyword.put(base_opts(), :on_status, &send(test_pid, {:status, &1}))

      assert {:ok, _} = Hardware.run(bell_circuit(), ctx.config, opts)

      events = drain_statuses()
      auth_idx = Enum.find_index(events, &(&1 == {:ibm, :authenticating}))
      fetch_idx = Enum.find_index(events, &(&1 == {:ibm, :fetching_backend}))
      trans_idx = Enum.find_index(events, &(&1 == {:portal, :transpiling}))
      submit_idx = Enum.find_index(events, &(&1 == {:ibm, :submitting}))
      results_idx = Enum.find_index(events, &(&1 == {:ibm, :fetching_results}))

      assert auth_idx < fetch_idx
      assert fetch_idx < trans_idx
      assert trans_idx < submit_idx
      assert submit_idx < results_idx
    end
  end

  describe "measurement pre-flight" do
    test "circuit without measurements raises NoMeasurementsError", ctx do
      circuit = QuantumCircuit.new(2, 2) |> Qx.h(0) |> Qx.cx(0, 1)

      assert {:error, %NoMeasurementsError{} = err} =
               Hardware.run(circuit, ctx.config, base_opts())

      assert err.message =~ "no measurement"
    end

    test "run!/3 raises the typed exception on unmeasured circuit", ctx do
      circuit = QuantumCircuit.new(2, 2) |> Qx.h(0)

      assert_raise NoMeasurementsError, fn ->
        Hardware.run!(circuit, ctx.config, base_opts())
      end
    end
  end

  describe "lazy connect" do
    test "succeeds when identity + backends_list absent", ctx do
      config = %{ctx.config | identity: nil, backends_list: []}

      Recorder.set(ctx.recorder, :portal_me, {:ok, %{email: "lazy@example.com"}})

      Recorder.set(
        ctx.recorder,
        :iam_exchange,
        {:ok, Map.put(config, :access_token, "t")}
      )

      Recorder.set(
        ctx.recorder,
        :list_backends,
        {:ok, [%{name: "ibm_brisbane", status: "active", num_qubits: 127}]}
      )

      script_happy_path(ctx.recorder, skip_iam_exchange: true)

      assert {:ok, _} = Hardware.run(bell_circuit(), config, base_opts())

      keys = ctx.recorder |> Recorder.calls() |> Enum.map(&elem(&1, 0))
      assert :portal_me in keys
      assert :list_backends in keys
    end

    test "fails with ConfigError when backend not in backends_list", ctx do
      config = %{ctx.config | identity: nil, backends_list: [], backend: "ibm_unknown"}

      Recorder.set(ctx.recorder, :portal_me, {:ok, %{email: "x@example.com"}})

      Recorder.set(
        ctx.recorder,
        :iam_exchange,
        {:ok, Map.put(config, :access_token, "t") |> Map.put(:__recorder__, ctx.recorder)}
      )

      Recorder.set(
        ctx.recorder,
        :list_backends,
        {:ok, [%{name: "ibm_brisbane", status: "active", num_qubits: 127}]}
      )

      assert {:error, {:config, %ConfigError{field: :backend}}} =
               Hardware.run(bell_circuit(), config, base_opts())
    end

    test "skipped when identity + backends_list already populated", ctx do
      script_happy_path(ctx.recorder)

      assert {:ok, _} = Hardware.run(bell_circuit(), ctx.config, base_opts())

      keys = ctx.recorder |> Recorder.calls() |> Enum.map(&elem(&1, 0))
      refute :portal_me in keys
      refute :list_backends in keys
    end
  end

  describe "cancel/3" do
    test "happy path → :ok", ctx do
      Recorder.set(
        ctx.recorder,
        :iam_exchange,
        {:ok, Map.put(ctx.config, :access_token, "t")}
      )

      Recorder.set(ctx.recorder, :cancel_job, :ok)

      assert :ok = Hardware.cancel("job_xyz", ctx.config, ibm: StubIbm.Ibm)
    end

    test "ibm failure routes through :ibm_poll stage", ctx do
      Recorder.set(
        ctx.recorder,
        :iam_exchange,
        {:ok, Map.put(ctx.config, :access_token, "t")}
      )

      Recorder.set(ctx.recorder, :cancel_job, {:error, :network_down})

      assert {:error, {:ibm_poll, :network_down}} =
               Hardware.cancel("job_xyz", ctx.config, ibm: StubIbm.Ibm)
    end
  end

  describe "transpile/3" do
    test "circuit + config returns transpiled qasm", ctx do
      script_happy_path(ctx.recorder)

      assert {:ok, qasm} = Hardware.transpile(bell_circuit(), ctx.config, base_opts())
      assert qasm =~ "TRANSPILED"
    end

    test "string qasm bypasses circuit conversion", ctx do
      script_happy_path(ctx.recorder)

      assert {:ok, _qasm} =
               Hardware.transpile("OPENQASM 3.0;", ctx.config, base_opts())
    end
  end

  ## ---- helpers ----------------------------------------------------

  defp drain_statuses(acc \\ []) do
    receive do
      {:status, event} -> drain_statuses([event | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
