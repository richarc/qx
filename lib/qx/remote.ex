defmodule Qx.Remote do
  @moduledoc """
  HTTP client for submitting quantum circuits to a QxServer instance.

  Converts circuits to OpenQASM, submits them to the server, and
  returns results as `Qx.SimulationResult` structs.

  ## Examples

      config = Qx.Remote.Config.new!(
        url: "http://localhost:4040",
        api_key: "my-key"
      )

      circuit = Qx.create_circuit(2, 2)
        |> Qx.h(0)
        |> Qx.cx(0, 1)
        |> Qx.measure(0, 0)
        |> Qx.measure(1, 1)

      # All-in-one: submit, wait, return result
      {:ok, result} = Qx.Remote.run(circuit, config,
        backend: "ibm_fez",
        shots: 4096
      )

      # Or step-by-step
      {:ok, job} = Qx.Remote.submit(circuit, config, backend: "ibm_fez")
      {:ok, result} = Qx.Remote.await(job["job_id"], config)

  """

  alias Qx.Remote.Config

  @default_poll_interval 2_000

  @doc """
  Submits a circuit, polls until complete, and returns the result.

  ## Options

    * `:backend` - Backend name (required)
    * `:shots` - Number of shots (default: 4096)
    * `:provider` - Provider name (default: "ibm")
    * `:options` - Provider-specific options map
    * `:on_status` - Callback function `(status_map -> any)` called on each poll
    * `:poll_interval` - Polling interval in ms (default: 2000)
    * `:req_options` - Additional Req options (for testing)

  """
  @spec run(Qx.QuantumCircuit.t(), Config.t(), keyword()) ::
          {:ok, Qx.SimulationResult.t()} | {:error, term()}
  def run(%Qx.QuantumCircuit{} = circuit, %Config{} = config, opts \\ []) do
    with {:ok, job} <- submit(circuit, config, opts) do
      await(job["job_id"], config, opts)
    end
  end

  @doc """
  Submits a circuit to the server (non-blocking).

  Returns `{:ok, map}` where the map includes `"job_id"` and `"status"` fields.

  ## Options

    * `:backend` - Backend name (required), e.g. `"ibm_fez"`
    * `:shots` - Number of shots (default: 4096)
    * `:provider` - Provider name (default: "ibm")
    * `:options` - Provider-specific options map
    * `:req_options` - Additional Req options (for testing)

  """
  @spec submit(Qx.QuantumCircuit.t(), Config.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def submit(%Qx.QuantumCircuit{} = circuit, %Config{} = config, opts \\ []) do
    qasm = Qx.Export.OpenQASM.to_qasm(circuit, version: 3)
    backend = Keyword.get(opts, :backend) || raise ArgumentError, "backend is required"
    shots = Keyword.get(opts, :shots, 4096)
    provider = Keyword.get(opts, :provider, "ibm")
    options = Keyword.get(opts, :options, %{})

    body = %{
      "qasm" => qasm,
      "provider" => provider,
      "backend" => backend,
      "shots" => shots,
      "options" => options
    }

    case post(config, "/api/v1/jobs", body, opts) do
      {:ok, %Req.Response{status: status, body: resp_body}} when status in [200, 201, 202] ->
        {:ok, resp_body}

      {:ok, %Req.Response{body: resp_body}} ->
        {:error, resp_body["message"] || resp_body}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Waits for a job to complete and returns the result as `Qx.SimulationResult`.

  ## Options

    * `:on_status` - Callback `(status_map -> any)` called on each poll
    * `:poll_interval` - Polling interval in ms (default: 2000)
    * `:timeout` - Max wait time in ms (default: config.timeout)
    * `:req_options` - Additional Req options

  """
  @spec await(String.t(), Config.t(), keyword()) ::
          {:ok, Qx.SimulationResult.t()} | {:error, term()}
  def await(job_id, %Config{} = config, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, config.timeout)
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
    on_status = Keyword.get(opts, :on_status)
    deadline = System.monotonic_time(:millisecond) + timeout

    do_poll(job_id, config, deadline, poll_interval, on_status, opts)
  end

  @doc """
  Gets the current status of a job.
  """
  @spec status(String.t(), Config.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def status(job_id, %Config{} = config, opts \\ []) do
    case get(config, "/api/v1/jobs/#{job_id}", opts) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: 404}} -> {:error, :not_found}
      {:ok, %Req.Response{body: body}} -> {:error, body["message"] || body}
      {:error, _} = error -> error
    end
  end

  @doc """
  Cancels a running job.

  Returns `{:ok, map}` with the cancellation response, or `{:error, :not_found}`
  if the job does not exist.

  ## Examples

      {:ok, _} = Qx.Remote.cancel(job_id, config)

  """
  @spec cancel(String.t(), Config.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def cancel(job_id, %Config{} = config, opts \\ []) do
    case request(config, :delete, "/api/v1/jobs/#{job_id}", nil, opts) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: 404}} -> {:error, :not_found}
      {:ok, %Req.Response{body: body}} -> {:error, body["message"] || body}
      {:error, _} = error -> error
    end
  end

  @doc """
  Lists available backends.

  ## Options

    * `:provider` - Filter by provider name
    * `:req_options` - Additional Req options

  """
  @spec list_backends(Config.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def list_backends(%Config{} = config, opts \\ []) do
    provider = Keyword.get(opts, :provider)
    path = if provider, do: "/api/v1/backends?provider=#{provider}", else: "/api/v1/backends"

    case get(config, path, opts) do
      {:ok, %Req.Response{status: 200, body: %{"backends" => backends}}} -> {:ok, backends}
      {:ok, %Req.Response{body: body}} -> {:error, body["message"] || body}
      {:error, _} = error -> error
    end
  end

  # Private helpers

  defp do_poll(job_id, config, deadline, poll_interval, on_status, opts) do
    if System.monotonic_time(:millisecond) > deadline do
      {:error, :timeout}
    else
      job_id
      |> status(config, opts)
      |> handle_poll_result(job_id, config, deadline, poll_interval, on_status, opts)
    end
  end

  defp handle_poll_result({:ok, %{"status" => "completed"} = status_map}, job_id, config, _deadline, _interval, on_status, opts) do
    if on_status, do: on_status.(status_map)
    fetch_results(job_id, config, opts)
  end

  defp handle_poll_result({:ok, %{"status" => status} = status_map}, _job_id, _config, _deadline, _interval, on_status, _opts)
       when status in ["failed", "cancelled"] do
    if on_status, do: on_status.(status_map)
    {:error, %{status: status, error: status_map["error"]}}
  end

  defp handle_poll_result({:ok, status_map}, job_id, config, deadline, poll_interval, on_status, opts) do
    if on_status, do: on_status.(status_map)
    Process.sleep(poll_interval)
    do_poll(job_id, config, deadline, poll_interval, on_status, opts)
  end

  defp handle_poll_result({:error, _} = error, _job_id, _config, _deadline, _interval, _on_status, _opts) do
    error
  end

  defp fetch_results(job_id, config, opts) do
    case get(config, "/api/v1/jobs/#{job_id}/results", opts) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        counts = body["counts"]
        shots = body["shots"]
        num_bits = body["num_classical_bits"]
        {:ok, Qx.ResultBuilder.from_counts(counts, shots, num_bits)}

      {:ok, %Req.Response{body: body}} ->
        {:error, body["message"] || body}

      {:error, _} = error ->
        error
    end
  end

  defp get(config, path, opts) do
    request(config, :get, path, nil, opts)
  end

  defp post(config, path, body, opts) do
    request(config, :post, path, body, opts)
  end

  defp request(config, method, path, body, opts) do
    req_options = Keyword.get(opts, :req_options, [])

    headers =
      [{"content-type", "application/json"}] ++
        if config.api_key, do: [{"x-api-key", config.api_key}], else: []

    req =
      Req.new(
        url: config.url <> path,
        method: method,
        headers: headers,
        json: body,
        receive_timeout: config.timeout
      )
      |> Req.merge(req_options)

    Req.request(req)
  end
end
