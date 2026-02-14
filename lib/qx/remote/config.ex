defmodule Qx.Remote.Config do
  @moduledoc """
  Configuration for connecting to a QxServer instance.

  ## Fields

    * `:url` - Base URL of the qx_server (required), e.g. `"http://localhost:4040"`
    * `:api_key` - API key for authentication (optional, depends on server config)
    * `:timeout` - HTTP request timeout in milliseconds (default: 300_000 = 5 min)

  ## Examples

      config = Qx.Remote.Config.new!(url: "http://localhost:4040", api_key: "my-key")

      {:ok, config} = Qx.Remote.Config.new(url: "http://localhost:4040")

  """

  @type t :: %__MODULE__{
          url: String.t(),
          api_key: String.t() | nil,
          timeout: pos_integer()
        }

  @enforce_keys [:url]
  defstruct [:url, :api_key, timeout: 300_000]

  @doc """
  Creates a new remote config.

  ## Returns

    * `{:ok, %Config{}}` on success
    * `{:error, reason}` on validation failure

  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts) when is_list(opts) do
    url = Keyword.get(opts, :url)
    api_key = Keyword.get(opts, :api_key)
    timeout = Keyword.get(opts, :timeout, 300_000)

    cond do
      is_nil(url) or url == "" ->
        {:error, "url is required"}

      not is_binary(url) ->
        {:error, "url must be a string"}

      not is_integer(timeout) or timeout < 1 ->
        {:error, "timeout must be a positive integer"}

      true ->
        # Normalize: strip trailing slash
        url = String.trim_trailing(url, "/")
        {:ok, %__MODULE__{url: url, api_key: api_key, timeout: timeout}}
    end
  end

  @doc """
  Creates a new remote config, raising on invalid input.
  """
  @spec new!(keyword()) :: t()
  def new!(opts) do
    case new(opts) do
      {:ok, config} -> config
      {:error, reason} -> raise ArgumentError, reason
    end
  end
end
