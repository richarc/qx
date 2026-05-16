defmodule Qx.Hardware.Config do
  @moduledoc """
  Configuration for `Qx.Hardware` execution against IBM Quantum via the
  qxportal transpilation service.

  Two independent credential sets live side-by-side in this struct, and
  the two HTTP clients (`Qx.Hardware.Portal` and `Qx.Hardware.Ibm`)
  consume only their own credentials — the portal token never reaches
  IBM, and the IBM API key never reaches the portal.

  ## Fields

  Required (enforced at struct construction time):

    * `:portal_url` — base URL for the qxportal transpilation service
      (e.g. `"https://api.qxquantum.com"`).
    * `:portal_token` — bearer token for the qxportal API.
    * `:ibm_api_key` — IBM Quantum API key (used for the IAM exchange).
    * `:ibm_crn` — IBM Cloud Resource Name for the Quantum service instance.
    * `:ibm_region` — IBM Cloud region (e.g. `"us-east"`).
    * `:backend` — IBM backend name (e.g. `"ibm_brisbane"`).

  Defaulted:

    * `:optimization_level` — transpiler optimization level, integer in
      `0..3`. Defaults to `1`.
    * `:shots` — number of shots for sampler jobs, integer in `1..100_000`.
      Defaults to `4096`.

  Transient (populated by `Qx.Hardware` during lazy-connect):

    * `:identity` — qxportal identity returned by `/api/v1/me`.
    * `:backends_list` — list of backend names available to this account.

  Internal (managed by `Qx.Hardware.Ibm`; callers should not set these
  directly except when injecting test/override hooks):

    * `:access_token` — IBM IAM bearer token. Populated by
      `Qx.Hardware.Ibm.iam_exchange/1`.
    * `:token_expires_at` — `DateTime` for the IAM token's expiry.
    * `:iam_url` — overrides the IBM IAM endpoint (test hook).
    * `:base_url` — overrides the IBM Quantum API base URL (test hook).

  ## Construction

      iex> {:ok, _config} =
      ...>   Qx.Hardware.Config.new(
      ...>     portal_url: "https://api.qxquantum.com",
      ...>     portal_token: "ptok",
      ...>     ibm_api_key: "ibm",
      ...>     ibm_crn: "crn:v1:bluemix:public:quantum-computing:us-east:a/x:y::",
      ...>     ibm_region: "us-east",
      ...>     backend: "ibm_brisbane"
      ...>   )

  Invalid input returns an error tuple:

      iex> {:error, %Qx.Hardware.ConfigError{field: :optimization_level}} =
      ...>   Qx.Hardware.Config.new(
      ...>     portal_url: "https://api.qxquantum.com",
      ...>     portal_token: "ptok",
      ...>     ibm_api_key: "ibm",
      ...>     ibm_crn: "crn",
      ...>     ibm_region: "us-east",
      ...>     backend: "ibm_brisbane",
      ...>     optimization_level: 7
      ...>   )

  The bang variant raises:

      iex> Qx.Hardware.Config.new!(
      ...>   portal_url: "ftp://nope",
      ...>   portal_token: "ptok",
      ...>   ibm_api_key: "ibm",
      ...>   ibm_crn: "crn",
      ...>   ibm_region: "us-east",
      ...>   backend: "ibm_brisbane"
      ...> )
      ** (Qx.Hardware.ConfigError) Invalid `portal_url`: scheme must be \"http\" or \"https\"
  """

  alias Qx.Hardware.ConfigError

  @enforce_keys [
    :portal_url,
    :portal_token,
    :ibm_api_key,
    :ibm_crn,
    :ibm_region,
    :backend
  ]

  # Redact the four credential fields from ANY inspect/1 — Logger
  # output, BEAM crash reports dumping a closure env, error tuples that
  # embed the struct, ad-hoc debugging. Without this they appear in
  # plaintext (qx-o9h). Non-secret fields stay visible so the struct is
  # still useful to inspect.
  @derive {Inspect, except: [:portal_token, :ibm_api_key, :ibm_crn, :access_token]}
  defstruct [
    :portal_url,
    :portal_token,
    :ibm_api_key,
    :ibm_crn,
    :ibm_region,
    :backend,
    optimization_level: 1,
    shots: 4096,
    identity: nil,
    backends_list: [],
    access_token: nil,
    token_expires_at: nil,
    iam_url: nil,
    base_url: nil
  ]

  @type t :: %__MODULE__{
          portal_url: String.t(),
          portal_token: String.t(),
          ibm_api_key: String.t(),
          ibm_crn: String.t(),
          ibm_region: String.t(),
          backend: String.t(),
          optimization_level: 0..3,
          shots: pos_integer(),
          identity: String.t() | nil,
          backends_list: [String.t()],
          access_token: String.t() | nil,
          token_expires_at: DateTime.t() | nil,
          iam_url: String.t() | nil,
          base_url: String.t() | nil
        }

  @required_string_fields [
    :portal_url,
    :portal_token,
    :ibm_api_key,
    :ibm_crn,
    :ibm_region,
    :backend
  ]

  @ibm_region_allowlist ~w(us-east us-south eu-de eu-es jp-tok au-syd)

  @doc """
  Builds a `t:t/0` from a keyword list or map.

  Returns `{:ok, %Qx.Hardware.Config{}}` on success or
  `{:error, %Qx.Hardware.ConfigError{}}` on validation failure.
  """
  @spec new(keyword() | map()) :: {:ok, t()} | {:error, ConfigError.t()}
  def new(attrs) when is_list(attrs) or is_map(attrs) do
    attrs = normalize_attrs(attrs)

    with :ok <- check_required(attrs),
         :ok <- validate_portal_url(attrs[:portal_url]),
         :ok <- validate_optimization_level(Map.get(attrs, :optimization_level, 1)),
         :ok <- validate_shots(Map.get(attrs, :shots, 4096)),
         :ok <- validate_region(attrs[:ibm_region]) do
      {:ok, struct!(__MODULE__, attrs)}
    end
  end

  @doc """
  Same as `new/1` but raises `Qx.Hardware.ConfigError` on failure.
  """
  @spec new!(keyword() | map()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, config} -> config
      {:error, error} -> raise error
    end
  end

  @doc """
  Builds a `t:t/0` from environment variables.

  Reads:

    * `QX_PORTAL_URL`
    * `QX_PORTAL_TOKEN`
    * `QX_IBM_API_KEY`
    * `QX_IBM_CRN`
    * `QX_IBM_REGION`
    * `QX_IBM_BACKEND`

  Optional overrides may be passed via `opts` (e.g. `optimization_level:`,
  `shots:`).
  """
  @spec from_env(keyword()) :: {:ok, t()} | {:error, ConfigError.t()}
  def from_env(opts \\ []) when is_list(opts) do
    env_attrs = [
      portal_url: System.get_env("QX_PORTAL_URL"),
      portal_token: System.get_env("QX_PORTAL_TOKEN"),
      ibm_api_key: System.get_env("QX_IBM_API_KEY"),
      ibm_crn: System.get_env("QX_IBM_CRN"),
      ibm_region: System.get_env("QX_IBM_REGION"),
      backend: System.get_env("QX_IBM_BACKEND")
    ]

    new(Keyword.merge(env_attrs, opts))
  end

  @doc """
  Same as `from_env/1` but raises on failure.
  """
  @spec from_env!(keyword()) :: t()
  def from_env!(opts \\ []) do
    case from_env(opts) do
      {:ok, config} -> config
      {:error, error} -> raise error
    end
  end

  defp normalize_attrs(attrs) when is_list(attrs), do: Map.new(attrs)
  defp normalize_attrs(%_{} = attrs), do: Map.from_struct(attrs)
  defp normalize_attrs(attrs) when is_map(attrs), do: attrs

  defp check_required(attrs) do
    Enum.reduce_while(@required_string_fields, :ok, fn field, :ok ->
      case Map.get(attrs, field) do
        value when is_binary(value) and byte_size(value) > 0 ->
          {:cont, :ok}

        _ ->
          {:halt,
           {:error,
            ConfigError.exception(
              field: field,
              reason: "is required and must be a non-empty string"
            )}}
      end
    end)
  end

  defp validate_portal_url(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme}} when scheme in ["http", "https"] ->
        :ok

      {:ok, %URI{}} ->
        {:error,
         ConfigError.exception(
           field: :portal_url,
           reason: "scheme must be \"http\" or \"https\""
         )}

      {:error, _} ->
        {:error,
         ConfigError.exception(
           field: :portal_url,
           reason: "is not a valid URI"
         )}
    end
  end

  defp validate_optimization_level(level) when level in 0..3, do: :ok

  defp validate_optimization_level(level) do
    {:error,
     ConfigError.exception(
       field: :optimization_level,
       reason: "must be an integer in 0..3, got: #{inspect(level)}"
     )}
  end

  defp validate_shots(shots) when is_integer(shots) and shots in 1..100_000, do: :ok

  defp validate_shots(shots) do
    {:error,
     ConfigError.exception(
       field: :shots,
       reason: "must be an integer in 1..100_000, got: #{inspect(shots)}"
     )}
  end

  defp validate_region(region) when region in @ibm_region_allowlist, do: :ok

  defp validate_region(region) do
    {:error,
     ConfigError.exception(
       field: :ibm_region,
       reason: "must be one of #{inspect(@ibm_region_allowlist)}, got: #{inspect(region)}"
     )}
  end
end
