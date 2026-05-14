defmodule Qx.Hardware.StubIbm do
  @moduledoc """
  In-memory stub matching the `Qx.Hardware.Ibm` surface used by
  `Qx.Hardware`.

  Looks up scripted return values in an Agent keyed by call name.
  Tests configure responses up-front, run the pipeline, then assert on
  call order via the recorded log.

  This is the lightweight alternative to Mox (not in deps).
  """

  defmodule Recorder do
    @moduledoc false
    use Agent

    def start_link(initial \\ %{}) do
      Agent.start_link(fn -> %{responses: initial, calls: []} end)
    end

    def set(pid, key, response_or_list) do
      Agent.update(pid, fn state ->
        put_in(state.responses[key], List.wrap(response_or_list))
      end)
    end

    def call(pid, key, args) do
      Agent.get_and_update(pid, fn state ->
        state = update_in(state.calls, &(&1 ++ [{key, args}]))

        case state.responses[key] do
          [response] ->
            {response, state}

          [response | rest] ->
            state = put_in(state.responses[key], rest)
            {response, state}

          nil ->
            raise "Qx.Hardware.StubIbm.Recorder: no response scripted for #{inspect(key)}"

          [] ->
            raise "Qx.Hardware.StubIbm.Recorder: responses exhausted for #{inspect(key)}"
        end
      end)
    end

    def calls(pid), do: Agent.get(pid, & &1.calls)
  end

  defmodule Ibm do
    @moduledoc false
    alias Qx.Hardware.StubIbm.Recorder

    def iam_exchange(%{__recorder__: pid} = config),
      do: Recorder.call(pid, :iam_exchange, [config])

    def list_backends(%{__recorder__: pid} = config),
      do: Recorder.call(pid, :list_backends, [config])

    def fetch_backend_configuration(%{__recorder__: pid} = config, name),
      do: Recorder.call(pid, :fetch_backend_configuration, [config, name])

    def submit_sampler(%{__recorder__: pid} = config, qasm, backend, shots \\ 4096),
      do: Recorder.call(pid, :submit_sampler, [config, qasm, backend, shots])

    def poll_job(%{__recorder__: pid} = config, job_id),
      do: Recorder.call(pid, :poll_job, [config, job_id])

    def fetch_results(%{__recorder__: pid} = config, job_id),
      do: Recorder.call(pid, :fetch_results, [config, job_id])

    def cancel_job(%{__recorder__: pid} = config, job_id),
      do: Recorder.call(pid, :cancel_job, [config, job_id])

    def terminal_success?(status), do: status == "Completed"

    def terminal_failure?(status),
      do: status in ["Failed", "Cancelled", "Cancelled - Ran too long"]
  end

  defmodule Portal do
    @moduledoc false
    alias Qx.Hardware.StubIbm.Recorder

    def me(%{__recorder__: pid} = config),
      do: Recorder.call(pid, :portal_me, [config])

    def transpile(%{__recorder__: pid} = config, qasm, opts \\ []),
      do: Recorder.call(pid, :transpile, [config, qasm, opts])
  end
end
