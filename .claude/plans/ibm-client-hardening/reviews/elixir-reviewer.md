# Code Review: ibm-client-hardening (Group B)

## Summary

- **Status**: ⚠️ Changes Requested
- **Issues Found**: 4 (1 BLOCKER, 1 WARNING, 2 SUGGESTION)

---

## Critical Issues

### 1. `Application.compile_env/2` without default — compile failure in dev/prod

**Location**: `lib/qx/hardware/ibm.ex:11`

```elixir
# Current
@ibm_retry_delay Application.compile_env(:qx, :ibm_retry_delay)
```

`Application.compile_env/2` (two-arity, no default) raises `ArgumentError` at
compile time when the key is absent. `:ibm_retry_delay` is only set in
`config/test.exs`, which `config.exs` imports only when `config_env() == :test`.
Compiling in `:dev` or `:prod` never sets this key, so the module fails to
compile outside the test environment.

The comment in the file correctly states "nil in prod" — but the 2-arity form
cannot produce nil for a missing key; it raises. The required fix is the
3-arity form with an explicit default:

```elixir
# Suggested
@ibm_retry_delay Application.compile_env(:qx, :ibm_retry_delay, nil)
```

---

## Warnings

### 2. `retry_after_seconds/1` duplicated across `ibm.ex` and `portal.ex`

**Location**: `lib/qx/hardware/ibm.ex:458–469`, `lib/qx/hardware/portal.ex:165–176`

The two implementations are byte-for-byte identical. The `Http` module was
introduced in this very change to centralise shared HTTP logic; this function
is an obvious candidate to move there (or expose from there). Leaving it
duplicated means any future change (e.g. supporting `Retry-After` as an
HTTP-date) needs to be applied in two places.

```elixir
# Suggested addition to Qx.Hardware.Http:
@doc false
@spec retry_after_seconds(Req.Response.t()) :: non_neg_integer() | nil
def retry_after_seconds(%Req.Response{} = resp) do
  case Req.Response.get_header(resp, "retry-after") do
    [value | _] ->
      case Integer.parse(value) do
        {n, _} -> n
        :error -> nil
      end
    _ -> nil
  end
end
```

---

## Suggestions

### 3. `truncate/1` guards on `byte_size` but slices by character position

**Location**: `lib/qx/hardware/http.ex:45–46`

```elixir
defp truncate(str) when byte_size(str) <= @max_body_preview, do: str
defp truncate(str), do: String.slice(str, 0, @max_body_preview) <> "… (truncated)"
```

The guard uses `byte_size/1` (bytes), but `String.slice/3` counts grapheme
clusters (characters). For a string containing multi-byte UTF-8 sequences the
truncated segment can exceed `@max_body_preview` bytes — up to 4× for 4-byte
codepoints. IBM/Portal responses are ASCII JSON in practice, so this is
unlikely to matter now, but the inconsistency is a latent surprise.

Strict byte-level cap:

```elixir
defp truncate(str) when byte_size(str) <= @max_body_preview, do: str
defp truncate(str), do: binary_part(str, 0, @max_body_preview) <> "… (truncated)"
```

Note: `binary_part/3` can split a multi-byte codepoint — if that matters,
validate UTF-8 safety with `String.valid?/1` after slicing, or use
`String.slice(str, 0, @max_body_preview)` and accept the slight byte overrun.
Either consistent choice is preferable to the current mismatch.

### 4. `maybe_put_retry_delay/1` wraps integer unnecessarily

**Location**: `lib/qx/hardware/ibm.ex:425–429`

```elixir
# Current
delay when is_integer(delay) -> Keyword.put(options, :retry_delay, fn _ -> delay end)
```

Req's `:retry_delay` option accepts a plain non-negative integer directly
(verified in `deps/req/lib/req/steps.ex`, line 2338: `delay when is_integer(delay)`).
The function-wrapping is harmless but the accompanying comment ("Req expects a
function of the retry count, so wrap the configured millis") is inaccurate.
Either pass the integer directly or remove the comment:

```elixir
# Suggested — simpler, accurate
delay when is_integer(delay) -> Keyword.put(options, :retry_delay, delay)
```

---

## One-line notes on unchanged / lightly-touched code

- `lib/qx/hardware/portal.ex:66–83` — `get/2` correctly uses `:safe_transient`
  without a custom `retry_delay`; Portal has no equivalent test knob, which is
  intentional given the lean scope.
- `test/qx/hardware/portal_test.exs` — no GET retry test (503 → success) exists
  for Portal. The transient-retry path is exercised in `ibm_test.exs`; a
  parallel Portal test would close the gap but is out of the stated scope.
- `test/qx/hardware/ibm_test.exs:466–480` — the transient-retry test uses
  `:counters` for a lock-free hit count inside Bypass; clean approach.
