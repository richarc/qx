defmodule Qx.Hardware.Portal do
  @moduledoc false

  alias Qx.Hardware.Config
  alias Qx.Hardware.Http

  @typedoc "The shape returned by `/api/v1/me`."
  @type identity :: %{
          required(:email) => String.t(),
          required(:role) => String.t(),
          required(:api_key_name) => String.t()
        }

  @typedoc "Successful transpile response payload."
  @type transpile_result :: %{
          required(:qasm) => String.t(),
          required(:metadata) => %{
            depth: non_neg_integer(),
            size: non_neg_integer(),
            num_qubits: non_neg_integer()
          }
        }

  @doc """
  Confirms the portal token is valid and returns the authenticated
  identity.
  """
  @spec me(Config.t()) :: {:ok, identity()} | {:error, term()}
  def me(%Config{} = config), do: get(config, "/api/v1/me")

  @doc """
  Transpiles an OpenQASM 3.0 program for a target IBM backend.

  `qasm` is the source program; `opts` may include:

    * `:coupling_map` — list of qubit-pair connections.
    * `:basis_gates` — list of basis gates supported by the backend.
    * `:optimization_level` — integer 0..3. Defaults to
      `config.optimization_level`.
    * `:seed_transpiler` — optional integer seed.
    * `:backend` — backend name (string). Defaults to `config.backend`.

  Returns `{:ok, %{qasm: ..., metadata: %{depth: _, size: _, num_qubits: _}}}`
  on success.
  """
  @spec transpile(Config.t(), String.t(), keyword()) ::
          {:ok, transpile_result()} | {:error, term()}
  def transpile(%Config{} = config, qasm, opts \\ []) when is_binary(qasm) do
    payload = build_transpile_payload(config, qasm, opts)
    post(config, "/api/v1/transpile", payload)
  end

  defp build_transpile_payload(%Config{} = config, qasm, opts) do
    %{
      qasm: qasm,
      backend: Keyword.get(opts, :backend, config.backend),
      coupling_map: Keyword.get(opts, :coupling_map),
      basis_gates: Keyword.get(opts, :basis_gates),
      optimization_level: Keyword.get(opts, :optimization_level, config.optimization_level),
      seed_transpiler: Keyword.get(opts, :seed_transpiler)
    }
  end

  ## Internals

  defp get(%Config{portal_token: token, portal_url: base_url}, path) do
    url = String.trim_trailing(base_url, "/") <> path

    request =
      Req.new(
        url: url,
        headers: [
          {"authorization", "Bearer " <> token},
          {"accept", "application/json"}
        ],
        receive_timeout: 10_000,
        # GET is idempotent; retry transient failures. (The transpile POST
        # below stays retry: false — it is not safe to auto-replay.)
        retry: :safe_transient
      )

    handle_response(Req.get(request), :get)
  end

  defp post(%Config{portal_token: token, portal_url: base_url}, path, payload) do
    url = String.trim_trailing(base_url, "/") <> path

    request =
      Req.new(
        url: url,
        json: payload,
        headers: [
          {"authorization", "Bearer " <> token},
          {"accept", "application/json"}
        ],
        receive_timeout: 30_000,
        retry: false
      )

    handle_response(Req.post(request), :post)
  end

  defp handle_response({:ok, %Req.Response{status: 200, body: %{"data" => data}}}, _verb),
    do: {:ok, atomize(data)}

  defp handle_response({:ok, %Req.Response{status: 401}}, _verb),
    do: {:error, :unauthorized}

  defp handle_response({:ok, %Req.Response{status: 404}}, _verb),
    do: {:error, :not_found}

  defp handle_response({:ok, %Req.Response{status: 422, body: body}}, :post),
    do: {:error, {:invalid_qasm, error_detail(body)}}

  defp handle_response({:ok, %Req.Response{status: 429} = resp}, _verb),
    do: {:error, {:rate_limited, Http.retry_after_seconds(resp)}}

  defp handle_response({:ok, %Req.Response{status: 502}}, :post),
    do: {:error, :transpile_failed}

  defp handle_response({:ok, %Req.Response{status: 503}}, :post),
    do: {:error, :transpile_unavailable}

  defp handle_response({:ok, %Req.Response{status: 504}}, :post),
    do: {:error, :transpile_timeout}

  defp handle_response({:ok, %Req.Response{status: status, body: body}}, _verb),
    do: Http.http_error(status, body)

  defp handle_response({:error, %{reason: reason}}, _verb),
    do: {:error, {:network, reason}}

  defp handle_response({:error, exception}, _verb),
    do: {:error, {:network, Exception.message(exception)}}

  # Allow-list of atoms we know belong to the API contract. Anything
  # outside this set stays a string key — protects against atom
  # exhaustion if the portal ever adds an unexpected field.
  @known_keys ~w(
    id name email role api_key_name visibility share_url
    inserted_at updated_at error detail
    qasm metadata depth size num_qubits
  )a
  @known_keys_map Map.new(@known_keys, fn atom -> {Atom.to_string(atom), atom} end)

  defp atomize(data) when is_list(data), do: Enum.map(data, &atomize/1)

  defp atomize(data) when is_map(data) do
    for {k, v} <- data, into: %{} do
      {to_known_atom(k), atomize(v)}
    end
  end

  defp atomize(other), do: other

  defp to_known_atom(key) when is_atom(key), do: key

  defp to_known_atom(key) when is_binary(key),
    do: Map.get(@known_keys_map, key, key)

  defp error_detail(%{"detail" => detail}) when is_binary(detail), do: detail
  defp error_detail(%{"error" => err}) when is_binary(err), do: err
  defp error_detail(_), do: nil
end
