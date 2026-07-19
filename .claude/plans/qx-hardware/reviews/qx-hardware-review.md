# Code Review: qx-hardware

**Verdict**: REQUIRES CHANGES
**Findings**: 2 BLOCKERs · 4 WARNINGs · 2 SUGGESTIONs
**Verification gates**: ALL PASS (compile, format, credo strict, 689 tests + 229 doctests, docs)
**Coverage**: 78.8% total; hardware modules 75.4% – 90.9% (bd issue filed)

## Requirements Coverage (from `.claude/plans/qx-hardware/plan.md`)

**31 MET · 0 PARTIAL · 0 UNMET · 0 UNCLEAR**

All 31 plan acceptance criteria are implemented. Two precision notes (not failures):
- `list_backends/1` and `cancel/2` are implemented as `list_backends/2` / `cancel/3` with defaulted `opts`. API-compatible with the planned arities.
- The new hardware files are untracked in git — they'll need `git add` before the diff is complete (PR step).

## BLOCKERs

### B1 — `run!/3` raises raw `RuntimeError` for `{stage, reason}` tuples
`lib/qx/hardware.ex:145`

```elixir
{:error, reason} -> raise "Qx.Hardware.run! failed: #{inspect(reason)}"
```

This arm fires for the **dominant** error shape `{:error, {:ibm_poll, :deadline_exceeded}}` etc. The result is an untyped `RuntimeError` with the tuple `inspect`-ed into the message. Callers cannot `rescue Qx.Hardware.SomeError` predictably — Iron Law #7 (typed errors at the public boundary) is violated for the bang variant.

Both `elixir-reviewer` and `iron-law-judge` flagged this. The plan's own Iron Law compliance table claims "no raw `RuntimeError` leaks", so this is also a plan ↔ implementation drift.

**Suggested fix** — add a `Qx.Hardware.ExecutionError` in `lib/qx/errors.ex` and raise it from the fallback arm:

```elixir
defmodule Qx.Hardware.ExecutionError do
  defexception [:stage, :reason, :message]

  @impl true
  def exception({stage, reason}),
    do: %__MODULE__{
      stage: stage,
      reason: reason,
      message: "Hardware execution failed at #{stage}: #{inspect(reason)}"
    }

  def exception(other),
    do: %__MODULE__{message: "Hardware execution failed: #{inspect(other)}"}
end

# In hardware.ex run!/3
{:error, reason} -> raise Qx.Hardware.ExecutionError.exception(reason)
```

Also: the existing first arm `{:error, %{__exception__: true} = exception}` should use `is_exception/1` instead of duck-typing.

### B2 — `timeout_ms: 0` does not deterministically exercise the deadline branch
`test/qx/hardware_test.exs:220–228`

```elixir
opts = Keyword.put(base_opts(), :timeout_ms, 0)
```

`do_poll/1` uses strict `>`: `System.monotonic_time(:millisecond) > state.deadline`. With `timeout_ms: 0`, the deadline equals `now`, and on a fast enough machine the check fires while `monotonic_now == state.deadline` — guard is false, loop enters `poll_once` and the test accidentally passes via a `Queued` script entry.

**Suggested fix**: use `timeout_ms: -1` (or `-1000`) so the deadline is unambiguously in the past on the first check.

## WARNINGs

### W1 — `ensure_connected/4` third clause uses `if` where guards suffice
`lib/qx/hardware.ex:273-286`

Idiomatic Elixir prefers function-head pattern matching with guards over `if` for the final clause. Suggested form:

```elixir
defp ensure_connected(%Config{backend: b, backends_list: bs} = config, _, _, _)
     when b in bs,
     do: {:ok, config}

defp ensure_connected(%Config{backend: b, backends_list: bs}, _, _, _),
  do: {:error, {:config, ConfigError.exception(field: :backend, reason: "...")}}
```

`in` is a valid guard operator for lists.

### W2 — `submit_sampler/3` convenience overload missing `@spec` / `@doc`
`lib/qx/hardware/ibm.ex:218-220`

The arity-3 head delegates to arity-4 with `config.shots` as default but has no `@spec` and is not mentioned in the module doc. Either spec + document it, or delete (the orchestrator always passes `shots` explicitly via `ibm_submit/6`, so it's dead code today).

### W3 — `config_test.exs` `from_env` tests share `async: true` with env mutation
`test/qx/hardware/config_test.exs:107-180`

`with_env/2` correctly restores state, but during `fun.()` execution, any other async test that reads `QX_*` env vars would see poisoned values. Today no other test reads `QX_*`, so this is latent — but the next time someone adds an env-driven test we get a flaky race.

**Suggested fix**: move the three `from_env*` tests into their own module with `async: false`, or guard the helper with a per-test ExUnit serial tag.

### W4 — Lazy-connect test silently overrides `iam_exchange` script
`test/qx/hardware_test.exs:343-367`

The test sets `iam_exchange`, `portal_me`, `list_backends`, then calls `script_happy_path/1` which **also** sets `iam_exchange`. `Recorder.set/3` replaces the response list, so the second wins. This works today but the order-dependent overwrite is invisible to a reader.

**Suggested fix**: add a one-line comment explaining the intentional override, or factor `script_happy_path` to accept `:skip_iam_exchange` so lazy-connect tests don't rely on this.

## SUGGESTIONs

### S1 — `Qx.Hardware.Portal.atomize/1` uses O(n) linear scan per map key
`lib/qx/hardware/portal.ex:191-195`

```elixir
Enum.find(@known_keys, key, fn atom -> Atom.to_string(atom) == key end)
```

With ~20 keys the cost is fine, but a compile-time `Map.new(@known_keys, &{Atom.to_string(&1), &1})` would be O(1) lookup AND make the allowlist intent self-documenting. The default-value semantic of `Enum.find/3` is also subtle.

### S2 — `handle_poll_status/3` `cond` could bind helpers first
`lib/qx/hardware.ex:399-413`

Bind `success?`/`failure?` before the `cond` for readability, or split into pattern-matched function heads. Not wrong as-is.

## Verified clean

- **Privacy invariant** — `ibm.ex` has zero `portal_*` references; `portal.ex` has zero `ibm_*` / `access_token` references.
- **Iron Law #1** — no `String.to_atom` anywhere in new files; IBM statuses use `@known_statuses` allowlist, Portal keys use `@known_keys` with string fallback.
- **Iron Law #2** — no `GenServer`/`Agent`/`Task` in shipped code; the test `Recorder` Agent is in `test/support/` only.
- **Iron Law #6** — `mix.exs` is 0.7.0; CHANGELOG `[0.7.0]` BREAKING block with migration code example.
- **Iron Law #7 (non-bang paths)** — `Req` transport errors and `Jason.DecodeError` all caught at `handle_response/1` boundary; surface as `{:network, _}` / `{:http, _, _}` tuples.
- **`transpile/3`** default-arg + multi-clause pattern is correct.
- **`connect/2`** single-clause with `opts \\ []` delegates immediately to `do_connect/4`. No foot-gun.
- **Verification gates**: warnings-as-errors clean, format clean, credo strict 719 mods no issues, 689 tests + 229 doctests 0 failures, docs render all `Qx.Hardware.*` modules.
