defmodule Qx.Hardware.Http do
  @moduledoc false

  # Shared HTTP helpers for the hardware clients (Ibm, Portal).
  #
  # `http_error/2` bounds/redacts the response body so a downstream that logs
  # the error tuple cannot leak the full response (which may echo request
  # context or headers). It keeps a short, debuggable preview: a recognised
  # error message when present, otherwise a generic marker rather than the raw
  # body. `retry_after_seconds/1` parses the `retry-after` header for rate-limit
  # handling.

  @max_body_preview 256
  @known_error_keys ~w(errorMessage error errors message detail title reason)

  @doc """
  Builds a redacted `{:error, {:http, status, preview}}` tuple.
  """
  @spec http_error(non_neg_integer(), term()) :: {:error, {:http, non_neg_integer(), term()}}
  def http_error(status, body), do: {:error, {:http, status, redact_body(body)}}

  @doc """
  Reduces a response body to a bounded, safe preview.

  A map keeps only a recognised error field; any other map becomes a generic
  marker (its content is dropped). A binary is truncated. Nothing echoes the
  full multi-field/multi-KB body.
  """
  @spec redact_body(term()) :: term()
  def redact_body(body) when is_map(body) do
    case Enum.find_value(@known_error_keys, fn key -> present(body[key]) end) do
      nil -> "(response body redacted: #{map_size(body)} field(s))"
      value -> truncate(to_preview(value))
    end
  end

  def redact_body(body) when is_binary(body), do: truncate(body)
  def redact_body(nil), do: nil
  def redact_body(body), do: truncate(inspect(body))

  @doc """
  Reads a non-negative integer `retry-after` header from a response, or `nil`.
  """
  @spec retry_after_seconds(Req.Response.t()) :: non_neg_integer() | nil
  def retry_after_seconds(%Req.Response{} = resp) do
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

  defp present(nil), do: nil
  defp present(""), do: nil
  defp present(value), do: value

  defp to_preview(value) when is_binary(value), do: value
  defp to_preview(value), do: inspect(value)

  # Byte-bounded to match the byte_size/1 guard. A multibyte codepoint split at
  # the 256-byte boundary is harmless in a log preview.
  defp truncate(str) when byte_size(str) <= @max_body_preview, do: str
  defp truncate(str), do: binary_part(str, 0, @max_body_preview) <> " … (truncated)"
end
