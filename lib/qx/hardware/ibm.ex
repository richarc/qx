defmodule Qx.Hardware.Ibm do
  @moduledoc """
  HTTP client for IBM Quantum (Qiskit Runtime REST API).

  Wraps [Req](https://hexdocs.pm/req); callers never touch HTTP details
  directly.

  ## Auth

  IBM Cloud splits identity into:

    * **API key** — exchanged at `iam.cloud.ibm.com/identity/token` for a
      1-hour bearer token (`access_token`).
    * **Service-CRN** — sent on every API request to identify which
      Quantum *instance* the request is for. Cannot be derived from the
      API key.
    * **Region** — encoded into the CRN; the API base URL must match.

  Tokens are 1-hour TTL; long queue waits routinely outlive them. Every
  authed call is wrapped in `with_iam_refresh/2`, which catches 401, runs
  a fresh IAM exchange once, and retries.

  ## Sessions are optional — we don't use them

  IBM's current spec (2026-05) treats sessions as optional and supports
  direct `POST /jobs`. Empirically verified against a production-proven
  reference (`qx_server`, last working 2026-02 and no relevant IBM API
  changes since per the changelog). Dropping sessions removes a request,
  an error path, and a leakage class.

  ## Iron Law #1

  IBM job-status values arrive as binaries from the wire (Pascal-Case per
  the documented enum: `"Queued"`, `"Running"`, `"Completed"`,
  `"Cancelled"`, `"Cancelled - Ran too long"`, `"Failed"`). They are
  matched against `@known_statuses` and returned as binaries — never
  `String.to_atom/1`-ed.

  ## Privacy invariant

  This module never sees the qxportal token, and `Qx.Hardware.Portal`
  never sees the IBM API key or CRN. Two independent clients, two
  independent auth flows; the shared `Qx.Hardware.Config` struct is the
  only point of contact and each side reads only its own fields.
  """

  alias Qx.Hardware.Config

  @iam_url_default "https://iam.cloud.ibm.com/identity/token"
  @api_version "2026-03-15"
  @known_statuses [
    "Queued",
    "Running",
    "Completed",
    "Cancelled",
    "Cancelled - Ran too long",
    "Failed"
  ]
  @terminal_success ["Completed"]
  @terminal_failure ["Failed", "Cancelled", "Cancelled - Ran too long"]

  ## --------------------------------------------------------------
  ## IAM
  ## --------------------------------------------------------------

  @doc """
  Exchanges the user's API key for a 1-hour IAM bearer token.

  Returns the input config with `:access_token` and `:token_expires_at`
  populated.
  """
  @spec iam_exchange(Config.t()) :: {:ok, Config.t()} | {:error, term()}
  def iam_exchange(%Config{ibm_api_key: api_key} = config) do
    url = config.iam_url || @iam_url_default

    body =
      URI.encode_query(%{
        "grant_type" => "urn:ibm:params:oauth:grant-type:apikey",
        "apikey" => api_key,
        "response_type" => "cloud_iam"
      })

    request =
      Req.new(
        url: url,
        headers: [
          {"content-type", "application/x-www-form-urlencoded"},
          {"accept", "application/json"}
        ],
        body: body,
        receive_timeout: 10_000,
        retry: false
      )

    case Req.post(request) do
      {:ok, %Req.Response{status: 200, body: %{"access_token" => token} = resp_body}} ->
        secs = resp_body["expires_in"] || 3600
        expires_at = DateTime.add(DateTime.utc_now(), secs, :second)
        {:ok, %{config | access_token: token, token_expires_at: expires_at}}

      {:ok, %Req.Response{status: status}} when status in [400, 401] ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http, status, body}}

      {:error, %{reason: reason}} ->
        {:error, {:network, reason}}

      {:error, exception} ->
        {:error, {:network, Exception.message(exception)}}
    end
  end

  ## --------------------------------------------------------------
  ## Backends
  ## --------------------------------------------------------------

  @doc """
  Lists backends available on the user's instance.

  Decodes only `:name`, `:status`, `:num_qubits` from each entry.
  """
  @spec list_backends(Config.t()) ::
          {:ok, [%{name: String.t(), status: String.t() | nil, num_qubits: integer() | nil}]}
          | {:error, term()}
  def list_backends(%Config{} = config) do
    with_iam_refresh(config, fn cfg ->
      case authed_request(:get, cfg, "/backends", nil) do
        {:ok, %{"devices" => list}} when is_list(list) ->
          {:ok, Enum.map(list, &take_backend_summary/1)}

        {:ok, %{"backends" => list}} when is_list(list) ->
          {:ok, Enum.map(list, &take_backend_summary/1)}

        {:ok, list} when is_list(list) ->
          {:ok, Enum.map(list, &take_backend_summary/1)}

        {:ok, _other} ->
          {:error, :unexpected_response}

        error ->
          error
      end
    end)
  end

  @doc """
  Returns the `coupling_map`, `basis_gates`, and `num_qubits` for a
  backend. These are the fields qxportal's `/api/v1/transpile` payload
  requires.

  IBM serves this static device shape from
  `GET /v1/backends/{name}/configuration` (NOT `/properties`, which
  returns time-varying per-gate / per-qubit calibration data). IBM names
  the qubit count `n_qubits` on the wire; we expose it as `:num_qubits`.
  """
  @spec fetch_backend_configuration(Config.t(), String.t()) ::
          {:ok,
           %{
             coupling_map: list(list(non_neg_integer())),
             basis_gates: list(String.t()),
             num_qubits: non_neg_integer()
           }}
          | {:error, term()}
  def fetch_backend_configuration(%Config{} = config, name) when is_binary(name) do
    with_iam_refresh(config, fn cfg ->
      case authed_request(:get, cfg, "/backends/#{name}/configuration", nil) do
        {:ok, %{} = body} ->
          {:ok,
           %{
             coupling_map: body["coupling_map"],
             basis_gates: body["basis_gates"],
             num_qubits: body["n_qubits"] || body["num_qubits"]
           }}

        error ->
          error
      end
    end)
  end

  ## --------------------------------------------------------------
  ## Jobs
  ## --------------------------------------------------------------

  @doc """
  Submits a Sampler job. The PUB-format wrapping
  (`pubs: [[qasm, nil, shots]]`) is done here so callers never build the
  raw shape — forgetting the outer list is a 400. The 3-element PUB
  carries qasm + null observable + shot count (matches the
  production-proven `qx_server` wire format).

  No session is opened.
  """
  @spec submit_sampler(Config.t(), String.t(), String.t(), pos_integer()) ::
          {:ok, String.t()} | {:error, term()}
  def submit_sampler(%Config{} = config, qasm, backend, shots)
      when is_binary(qasm) and is_binary(backend) and is_integer(shots) and shots > 0 do
    body = %{
      "program_id" => "sampler",
      "backend" => backend,
      "params" => %{
        "version" => 2,
        "pubs" => [[qasm, nil, shots]]
      }
    }

    with_iam_refresh(config, fn cfg ->
      case authed_request(:post, cfg, "/jobs", body) do
        {:ok, %{"id" => id}} when is_binary(id) -> {:ok, id}
        {:ok, _} -> {:error, :unexpected_response}
        error -> error
      end
    end)
  end

  @doc """
  Returns the current job status as a binary.

  IBM's `GET /jobs/{id}` returns BOTH a top-level `status` and a nested
  `state.status` (the schema-required path). We read `state.status` and
  fall back to top-level.

  Status is matched against `@known_statuses`; an unknown value becomes
  `{:error, {:unknown_status, raw}}` so an API drift surfaces loudly
  rather than silently being misclassified.
  """
  @spec poll_job(Config.t(), String.t()) ::
          {:ok, %{status: String.t(), reason: String.t() | nil}}
          | {:error, term()}
  def poll_job(%Config{} = config, job_id) when is_binary(job_id) do
    with_iam_refresh(config, fn cfg ->
      case authed_request(:get, cfg, "/jobs/#{job_id}", nil) do
        {:ok, body} when is_map(body) ->
          parse_job_response(body)

        error ->
          error
      end
    end)
  end

  defp parse_job_response(body) do
    status = get_in(body, ["state", "status"]) || body["status"]
    reason = get_in(body, ["state", "reason"]) || body["reason"]

    cond do
      not is_binary(status) ->
        {:error, :unexpected_response}

      status in @known_statuses ->
        {:ok, %{status: status, reason: reason}}

      true ->
        {:error, {:unknown_status, status}}
    end
  end

  @doc """
  Cancels a running job. Returns `:ok` on 200/204 (including the
  "already terminal" idempotent path) and on 404 (job already gone).

  Uses `POST /jobs/{id}/cancel` per IBM's current spec.
  """
  @spec cancel_job(Config.t(), String.t()) :: :ok | {:error, term()}
  def cancel_job(%Config{} = config, job_id) when is_binary(job_id) do
    case with_iam_refresh(config, fn cfg ->
           authed_request(:post, cfg, "/jobs/#{job_id}/cancel", %{})
         end) do
      :ok -> :ok
      {:ok, _body} -> :ok
      {:error, :not_found} -> :ok
      error -> error
    end
  end

  @doc false
  def terminal_success?(status), do: status in @terminal_success

  @doc false
  def terminal_failure?(status), do: status in @terminal_failure

  @doc """
  Fetches the result of a finished Sampler job and aggregates the
  individual shot samples into a counts map.

  IBM's Sampler V2 response shape (verified live 2026-05):

      {
        "results": [{
          "data": {
            "<classical_register_name>": {
              "samples": ["0x0", "0x3", "0x3", ...],
              "num_bits": 2
            }
          },
          "metadata": {...}
        }],
        "metadata": {...}
      }

  IBM does NOT pre-aggregate counts — each shot is returned as a hex
  bitstring under `data.<reg>.samples`. We aggregate ourselves: hex →
  integer → fixed-width binary → frequency map.

  Returns the IBM-side merged metadata for downstream display.

  Errors:
    * `:unexpected_response` — body doesn't have `results: [_ | _]`
    * `:unsupported_result` — first result has no recognizable data
      shape (e.g. Estimator tensor format)
  """
  @spec fetch_results(Config.t(), String.t()) ::
          {:ok, %{counts: map(), metadata: map()}} | {:error, term()}
  def fetch_results(%Config{} = config, job_id) when is_binary(job_id) do
    with_iam_refresh(config, fn cfg ->
      case authed_request(:get, cfg, "/jobs/#{job_id}/results", nil) do
        {:ok, body} when is_map(body) -> parse_sampler_results(body)
        {:error, _} = error -> error
        _ -> {:error, :unexpected_response}
      end
    end)
  end

  defp parse_sampler_results(%{"results" => [first | _]} = body) when is_map(first) do
    data = first["data"] || %{}
    metadata = merge_result_metadata(body, first)

    case find_register_samples(data) do
      {:ok, samples, num_bits} ->
        {:ok, %{counts: samples_to_counts(samples, num_bits), metadata: metadata}}

      :error ->
        {:error, :unsupported_result}
    end
  end

  defp parse_sampler_results(_), do: {:error, :unexpected_response}

  defp find_register_samples(data) when is_map(data) and map_size(data) > 0 do
    Enum.find_value(data, :error, fn
      {_name, %{"samples" => samples, "num_bits" => num_bits}}
      when is_list(samples) and is_integer(num_bits) ->
        {:ok, samples, num_bits}

      _ ->
        false
    end)
  end

  defp find_register_samples(_), do: :error

  defp samples_to_counts(samples, num_bits) do
    Enum.frequencies_by(samples, &hex_sample_to_bitstring(&1, num_bits))
  end

  defp hex_sample_to_bitstring("0x" <> hex, num_bits) when is_integer(num_bits) do
    case Integer.parse(hex, 16) do
      {n, ""} when n >= 0 ->
        n |> Integer.to_string(2) |> String.pad_leading(num_bits, "0")

      _ ->
        "0x" <> hex
    end
  end

  defp hex_sample_to_bitstring(other, _num_bits), do: inspect(other)

  defp merge_result_metadata(body, first_result) do
    job_meta = Map.get(body, "metadata", %{}) || %{}
    pub_meta = Map.get(first_result, "metadata", %{}) || %{}
    Map.merge(job_meta, pub_meta)
  end

  ## --------------------------------------------------------------
  ## Internals
  ## --------------------------------------------------------------

  @doc """
  Returns the IBM Quantum API base URL for a region.

  Known regions resolve to documented hosts; other allowlisted regions
  follow the standard `<region>.quantum.cloud.ibm.com/api/v1` pattern.
  """
  @spec base_url_for(String.t()) :: String.t()
  def base_url_for("us-south"), do: "https://quantum.cloud.ibm.com/api/v1"
  def base_url_for("eu-de"), do: "https://eu-de.quantum.cloud.ibm.com/api/v1"

  def base_url_for(region) when is_binary(region),
    do: "https://#{region}.quantum.cloud.ibm.com/api/v1"

  defp api_base_url(%Config{base_url: url}) when is_binary(url),
    do: String.trim_trailing(url, "/")

  defp api_base_url(%Config{ibm_region: region}), do: base_url_for(region)

  defp take_backend_summary(d) when is_map(d) do
    %{
      name: d["name"] || d["backend_name"],
      status: d["status"],
      num_qubits: d["num_qubits"]
    }
  end

  defp with_iam_refresh(config, fun) when is_function(fun, 1) do
    case fun.(config) do
      {:error, :unauthorized} ->
        case iam_exchange(config) do
          {:ok, refreshed} -> fun.(refreshed)
          error -> error
        end

      other ->
        other
    end
  end

  defp authed_request(method, %Config{} = config, path, body) do
    url = api_base_url(config) <> path

    headers = [
      {"authorization", "Bearer " <> (config.access_token || "")},
      {"service-crn", config.ibm_crn},
      {"ibm-api-version", @api_version},
      {"accept", "application/json"}
    ]

    base_options = [
      url: url,
      headers: headers,
      receive_timeout: 30_000,
      retry: false
    ]

    options =
      if body != nil do
        Keyword.put(base_options, :json, body)
      else
        base_options
      end

    request = Req.new(options)

    result =
      case method do
        :get -> Req.get(request)
        :post -> Req.post(request)
        :delete -> Req.delete(request)
      end

    handle_response(result)
  end

  defp handle_response({:ok, %Req.Response{status: 200, body: body}}), do: {:ok, decode(body)}
  defp handle_response({:ok, %Req.Response{status: 201, body: body}}), do: {:ok, decode(body)}
  defp handle_response({:ok, %Req.Response{status: 204}}), do: :ok
  defp handle_response({:ok, %Req.Response{status: 401}}), do: {:error, :unauthorized}
  defp handle_response({:ok, %Req.Response{status: 404}}), do: {:error, :not_found}

  defp handle_response({:ok, %Req.Response{status: 429} = resp}),
    do: {:error, {:rate_limited, retry_after_seconds(resp)}}

  defp handle_response({:ok, %Req.Response{status: status, body: body}}),
    do: {:error, {:http, status, body}}

  defp handle_response({:error, %{reason: reason}}), do: {:error, {:network, reason}}

  defp handle_response({:error, exception}),
    do: {:error, {:network, Exception.message(exception)}}

  defp decode(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> body
    end
  end

  defp decode(body), do: body

  defp retry_after_seconds(%Req.Response{} = resp) do
    case Req.Response.get_header(resp, "retry-after") do
      [value | _] ->
        case Integer.parse(value) do
          {n, _} -> n
          :error -> nil
        end

      _ ->
        nil
    end
  end
end
