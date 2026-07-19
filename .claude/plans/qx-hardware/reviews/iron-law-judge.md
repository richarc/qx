# Iron Law Violations Report — `qx-hardware`

## Summary

- Files scanned: 5 (`hardware.ex`, `hardware/config.ex`, `hardware/ibm.ex`, `hardware/portal.ex`, `errors.ex`)
- Iron Laws checked: 7 of 7 (project-specific subset)
- Violations found: 1 (0 critical, 0 high, 1 medium)

---

## Medium Violations (SUGGESTION)

### [#7] `run!/3` raises raw `RuntimeError` for non-exception error terms

- **File**: `lib/qx/hardware.ex:145`
- **Code**: `{:error, reason} -> raise "Qx.Hardware.run! failed: #{inspect(reason)}"`
- **Confidence**: LIKELY
- **Fix**: Law #7 requires typed `Qx.*Error` at the public boundary. The fallback arm of `run!/3` fires for any `{:error, {stage_atom, reason}}` tuple not wrapped in an exception struct — e.g. `{:error, {:ibm_poll, :deadline_exceeded}}`. Replace with a dedicated typed error:

  ```elixir
  # Add to lib/qx/errors.ex
  defmodule Qx.Hardware.ExecutionError do
    defexception [:stage, :reason, :message]
    def exception({stage, reason}),
      do: %__MODULE__{stage: stage, reason: reason,
                      message: "Hardware execution failed at #{stage}: #{inspect(reason)}"}
    def exception(other),
      do: %__MODULE__{message: "Hardware execution failed: #{inspect(other)}"}
  end

  # In hardware.ex run!/3
  {:error, reason} -> raise Qx.Hardware.ExecutionError.exception(reason)
  ```

---

## Passing checks (one-liner summary)

- **Law #1 (no `String.to_atom`)**: CLEAN. `Qx.Hardware.Ibm` uses `@known_statuses` binary allowlist; `Qx.Hardware.Portal.atomize/1` uses `@known_keys` + `Enum.find` with string fallback — zero `String.to_atom` calls in any new file.
- **Law #2 (no unjustified processes)**: CLEAN. No `GenServer`, `Agent`, `Task.async`, or `Task.Supervisor` in any shipped file. `Qx.Hardware.StubIbm.Recorder` uses `Agent` but is in `test/support/` — not shipped.
- **Law #6 (breaking API change)**: CLEAN. `mix.exs` version is `0.7.0`. `CHANGELOG.md` has a `[0.7.0]` section with a `BREAKING` block listing `Qx.Remote`, `Qx.Remote.Config`, `Qx.RemoteError` removals and a migration code example. Pre-1.0 minor bump documented as appropriate per SemVer §4.
- **Law #7 — all other paths**: CLEAN. `Config.new/1` returns `{:error, %Qx.Hardware.ConfigError{}}`. `Qx.Hardware.Ibm.handle_response/1` converts all `Req` transport errors to `{:network, reason}` tuples. `Qx.Hardware.Portal.handle_response/2` does the same. `stage/2` wrapper normalises all sub-errors to `{:error, {stage_atom, reason}}`. No raw `Req.TransportError`, `Jason.DecodeError`, or bare `ArgumentError` reaches callers.

---

## Plan Iron Law compliance table cross-check

The plan's compliance table (`.claude/plans/qx-hardware/plan.md` § "Iron Law compliance") is accurate for Laws #1, #2, and #6. Law #7's claim that "no raw `Req.TransportError` / `RuntimeError` leaks" is **partially inaccurate**: the `run!/3` fallback arm does emit a raw `RuntimeError` string for `{stage, reason}` tuples, contradicting the plan's claim. The other table entries are accurate.

---

## Pre-existing violation (out of scope, noted per instructions)

- `Qx.Validation` raises bare `ArgumentError` in unchanged files — noted in scratchpad; not in scope for this review.
