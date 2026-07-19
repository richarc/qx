# Code Review: qx-hardware — Qx.Hardware pipeline

## Summary

- **Status**: ⚠️ Changes Requested
- **Issues Found**: 5 (1 blocker, 2 warnings, 2 suggestions)

---

## BLOCKER

### 1. `run!/3` loses structured error info for plain-tuple errors (`hardware.ex:145`)

```elixir
# Current
{:error, %{__exception__: true} = exception} -> raise exception
{:error, reason} -> raise "Qx.Hardware.run! failed: #{inspect(reason)}"
```

The second clause fires for the dominant error shape `{:error, {stage, reason}}` — e.g.
`{:error, {:ibm_poll, :deadline_exceeded}}`. `inspect/1` of the tuple goes into a generic
`RuntimeError` string. Callers catching `Qx.Error` or `Qx.Hardware.ConfigError` will
instead see a bare `RuntimeError`, which breaks Iron Law #7 (typed errors at the API
boundary).

The first clause also uses a duck-typed `%{__exception__: true}` match rather than an
Exception struct check; prefer `is_exception/1`.

```elixir
# Suggested
def run!(circuit, config, opts \\ []) do
  case run(circuit, config, opts) do
    {:ok, result} ->
      result

    {:error, exception} when is_exception(exception) ->
      raise exception

    {:error, {stage, reason}} ->
      raise Qx.Hardware.ConfigError.exception(
        field: stage,
        reason: inspect(reason)
      )
  end
end
```

Alternatively, define a dedicated `Qx.Hardware.RunError` struct (preferred for Iron Law #7
compliance) so `rescue Qx.Hardware.RunError` works predictably.

---

## WARNINGS

### 2. `ensure_connected/4` uses `if` where pattern matching suffices (`hardware.ex:273-286`)

```elixir
# Current — third clause
defp ensure_connected(%Config{} = config, _portal, _ibm, _on_status) do
  if config.backend in config.backends_list do
    {:ok, config}
  else
    {:error, {:config, ConfigError.exception(...)}}
  end
end
```

This is a textbook case for a guard or a separate function head. The `if` is unnecessary
because the match on `%Config{}` with non-nil `identity` and non-empty `backends_list` is
already established by the two preceding heads. Two additional heads would be cleaner:

```elixir
defp ensure_connected(
       %Config{backends_list: backends, backend: backend} = config,
       _portal,
       _ibm,
       _on_status
     )
     when backend in backends,
     do: {:ok, config}

defp ensure_connected(%Config{backend: backend, backends_list: backends} = _config, _, _, _),
  do:
    {:error,
     {:config,
      ConfigError.exception(
        field: :backend,
        reason: "backend #{inspect(backend)} not in account's backends_list #{inspect(backends)}"
      )}}
```

Note: `in` is a valid guard operator for lists in Elixir.

### 3. `submit_sampler/3` arity-3 head lacks `@spec` and silently drops `shots` override (`ibm.ex:218-220`)

```elixir
# Current — no @spec, not listed in module doc
def submit_sampler(%Config{shots: shots} = config, qasm, backend) do
  submit_sampler(config, qasm, backend, shots)
end
```

This convenience overload is unspecced and undocumented. If `Qx.Hardware` always passes the
explicit `shots` arg (it does — `ibm_submit/6` passes `shots`), this clause is dead code.
If it is intentionally kept as a convenience, it needs a `@spec` and should appear in the
`@moduledoc`. Leaving it unspecced will trigger Dialyzer `invalid_contract` warnings and
confuses callers about the public surface.

---

## SUGGESTIONS

### 4. `do_poll/1` / `handle_poll_status/3` uses `cond` with boolean checks (`hardware.ex:405-418`)

```elixir
# Current
cond do
  state.ibm.terminal_success?(status) -> {:ok, info}
  state.ibm.terminal_failure?(status) -> {:error, ...}
  true -> ...
end
```

`cond` with a `true` fallback is fine in Elixir — this is not wrong. However, the two
`terminal_*?` functions are called via dynamic dispatch on `state.ibm` (which defaults to
`Qx.Hardware.Ibm`). A minor cleanliness improvement is to bind the results before the
`cond`:

```elixir
success? = state.ibm.terminal_success?(status)
failure? = state.ibm.terminal_failure?(status)

cond do
  success? -> {:ok, info}
  failure? -> {:error, {:ibm_job_failed, %{status: status, reason: info[:reason]}}}
  true -> ...
end
```

More idiomatic still: pattern-match on the two terminal lists directly in `handle_poll_status`
function heads, avoiding the indirection entirely. But this would require exposing the lists
or inlining — a judgment call given the test-injection design.

### 5. `atomize/1` in `portal.ex` — `@known_keys` linear scan on every map key (`portal.ex:194`)

```elixir
defp to_known_atom(key) when is_binary(key) do
  Enum.find(@known_keys, key, fn atom -> Atom.to_string(atom) == key end)
end
```

`@known_keys` is a list of atoms; `Enum.find` is O(n) per key. With 20 keys this is
acceptable, but the pattern is fragile: if the portal ever expands its response shape,
unknown fields silently remain string-keyed (which is the documented intent) but the code
doesn't make that obvious. Consider a `MapSet` or a compile-time `Map` of
`%{"string" => :atom}` built with `@known_keys_map` for O(1) lookup and explicit documentation
of the allow-list design:

```elixir
@known_keys_map Map.new(@known_keys, fn a -> {Atom.to_string(a), a} end)

defp to_known_atom(key) when is_binary(key) do
  Map.get(@known_keys_map, key, key)
end
```

This also removes the `Enum.find/3` default-value semantic which is subtle to read.

---

## Privacy Invariant — VERIFIED

- `lib/qx/hardware/ibm.ex`: zero references to `portal_token` or `portal_url`. ✓
- `lib/qx/hardware/portal.ex`: zero references to `ibm_api_key`, `ibm_crn`, `ibm_region`, or
  `access_token`. ✓

## Iron Law #1 — VERIFIED

IBM status strings are matched against `@known_statuses` and returned as binaries throughout.
No `String.to_atom/1` call found in any new file. ✓

## Test Coverage

Test files present for all four modules:
- `test/qx/hardware_test.exs`
- `test/qx/hardware/ibm_test.exs`
- `test/qx/hardware/portal_test.exs`
- `test/qx/hardware/config_test.exs`

## `transpile/3` default-arg head — VERIFIED

`def transpile(input, config, opts \\ [])` with two implementation heads is the correct
pattern for default args in multi-clause functions. `@spec` covers both input shapes via
the union type `QuantumCircuit.t() | String.t()`. No issue.

## `connect/2` default arg — VERIFIED

Single-clause public function with `opts \\ []` delegating immediately to `do_connect/4`.
No risk of default-arg + multi-clause foot-gun. ✓
