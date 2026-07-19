---
module: "Qx.Validation"
date: "2026-06-24"
problem_type: iron_law_violation
component: architecture
symptoms:
  - "Public gates (`Qx.rx/ry/rz/u/cp/crx/cry/crz`) raised raw `ArgumentError` on a non-numeric angle, leaking an untyped exception across the API boundary"
  - "`Qx.Validation.validate_parameter!/1`, `validate_qubits_different!/1`, and `validate_state_shape!/2` raised `ArgumentError` with in-source `# Iron Law #7 follow-on` TODO markers (`lib/qx/validation.ex:127,152,165`)"
  - "`## Raises` doc sections advertised `ArgumentError`, so callers could not `rescue` a typed `Qx.*Error` and pattern-match the cause"
root_cause: "These three validators were the last sites left un-converted when the predecessor `iron-law-7-critical` plan (shipped 0.8.0) closed the CRITICAL leaks. They violated Iron Law #7: public functions must raise typed `Qx.*Error`, never raw `ArgumentError`/`Nx`/`Complex`, routed through `Qx.Validation`."
severity: medium
iron_law_number: 7
tags: [iron-law-7, typed-errors, defexception, validation, argumenterror, public-api, tdd-hook, semver-pre-1.0]
related_solutions: ["sweep-typed-errors-public-surface-iron-law-7-20260624"]
---

# Route the last `Qx.Validation` raises through typed `Qx.*Error`

## Symptoms

`Qx.Validation` still raised raw `ArgumentError` in three spots after the
0.8.0 Iron Law #7 pass (`iron-law-7-critical`) converted the critical ones:

| Function | Old raise | New raise |
|---|---|---|
| `validate_parameter!/1` | `ArgumentError "Parameter must be a number…"` | **`Qx.ParameterError`** (new) |
| `validate_qubits_different!/1` | `ArgumentError "All qubit indices must be different…"` | `Qx.QubitIndexError {:duplicate, qubits}` |
| `validate_state_shape!/2` | `ArgumentError "Invalid state shape…"` | `Qx.StateShapeError {actual, expected}` |

Only `validate_parameter!/1` had `lib/` callers (the rotation/phase gates), so
it was the user-visible leak; the other two were dead in `lib/` but converted
for consistency and forward-proofing.

## Investigation

1. **Did a typed error already exist for each?** Two of three: `errors.ex`
   already had `Qx.QubitIndexError.exception({:duplicate, qubits})` (built by
   the predecessor plan) and `Qx.StateShapeError.exception({actual, expected})`.
   Those were one-line raise swaps. A non-numeric *parameter* had no matching
   type — that was the only design decision.
2. **Reuse `Qx.GateError {:invalid_parameter, gate, param}`, or add a new
   type?** `GateError` already models it but `validate_parameter!/1` doesn't
   receive the gate name (would need to thread an atom through 5 call sites).
   Chose a dedicated **`Qx.ParameterError`** carrying `:value` — one-error-per-
   concept, matching the family, no call-site churn.
3. **Where are the `## Raises` docs?** Grep found them in BOTH `lib/qx/operations.ex`
   (the impl) AND `lib/qx.ex` (the public `Qx.*` delegators) — 5 sites each.
   The delegators carry their own copy of the doc, so updating only the impl
   would have left the primary public surface stale.

## Root Cause

Iron Law #7 (Qx `CLAUDE.md`): *public functions raise typed `Qx.*Error` on
misuse; do not let raw `Nx`/`Complex`/`ArgumentError` leak across the API
boundary — route through `Qx.Validation`.* These three validators predated the
typed-error family and were deferred (as "H1") when the 0.8.0 plan scoped only
the CRITICAL leaks. They were the remaining debt, not a new regression.

## Solution

### The non-obvious gotcha: omit the `is_binary` message fallback

Every other exception in `errors.ex` (e.g. `Qx.OptionError`, `Qx.GateError`)
has a `exception(message) when is_binary(message)` clause so you can
`raise SomeError, "preformatted message"`. **`Qx.ParameterError` must NOT have
that clause** — a non-numeric parameter can itself be a binary string
(`Qx.rx(qc, 0, "bad")`). A binary fallback would misclassify `"bad"` as a
pre-formatted message and lose it from `:value`. So a single catch-all clause:

```elixir
defmodule Qx.ParameterError do
  @moduledoc """
  Raised when a gate parameter (rotation angle or phase) is not a number.

  Carries the offending `:value` so callers can pattern-match on the cause
  rather than parsing the message.

  Unlike the other exceptions in this file, `Qx.ParameterError` intentionally
  omits the `exception(message) when is_binary` fallback: a plain string is
  itself a valid non-numeric parameter (e.g. `Qx.rx(qc, 0, "bad")`), so every
  value — binaries included — is captured in `:value`, never treated as a
  pre-formatted message.
  """
  defexception [:value, :message]

  @impl true
  def exception(value) do
    %__MODULE__{value: value, message: "Parameter must be a number, got: #{inspect(value)}"}
  end
end
```

The `@moduledoc` note is load-bearing: without it a future maintainer
"fixes the inconsistency" by re-adding the binary clause and silently breaks
string-valued parameters. A test asserting the struct field guards it:

```elixir
test "exception carries the offending value in :value" do
  error = assert_raise Qx.ParameterError, fn -> Validation.validate_parameter!("not a number") end
  assert error.value == "not a number"   # assert_raise/2 returns the exception
end
```

### Reuse existing constructor shapes verbatim

```elixir
# lib/qx/validation.ex
def validate_parameter!(param) when is_number(param), do: :ok
def validate_parameter!(param), do: raise Qx.ParameterError, param

def validate_qubits_different!(qubits) when is_list(qubits) do
  if length(Enum.uniq(qubits)) != length(qubits),
    do: raise(Qx.QubitIndexError, {:duplicate, qubits})
  :ok
end

def validate_state_shape!(state, expected_size) do
  actual = Nx.axis_size(state, 0)
  if actual != expected_size, do: raise(Qx.StateShapeError, {actual, expected_size})
  :ok
end
```

### Update `## Raises` in BOTH `qx.ex` and `operations.ex`

`ArgumentError` → `Qx.ParameterError` in 5 sites each (`u/cp/crx/cry/crz`,
plus the rotation delegators in `qx.ex`). The `qx.ex` delegators carry their
own doc copy — don't forget them.

### Files Changed

- `lib/qx/errors.ex` — new `Qx.ParameterError`; added to the `Qx.Error` moduledoc list.
- `lib/qx/validation.ex` — three raises retyped; TODO markers removed.
- `lib/qx.ex` + `lib/qx/operations.ex` — 10 `## Raises` doc lines retyped.
- `CHANGELOG.md` — `[Unreleased]` Changed entry (observable error-type change).
- `test/qx/{validation,u_gate,cp_gate,operations_controlled_rotations}_test.exs` — assertions retyped + 1 new struct-field test.
- `ROADMAP.md` — ticked both v0.8.1 "Iron Law #7 follow-on" lines.
- Shipped on `main` in squash commit `bedc604` after `/phx:review` PASS from all three reviewers. 245 doctests + 852 tests, 0 failures.

## Prevention

- [x] **Already an Iron Law** — Iron Law #7 names this exactly; `iron-law-judge`
  flags raw `ArgumentError` across the public boundary.
- **Process gate (TDD + hook):** retyping a raised error breaks every existing
  `assert_raise ArgumentError` for that path. A `PreToolUse` hook hard-blocks
  all `*_test.exs` edits and TDD rule #2 forbids modifying existing tests
  without explicit human approval — so **plan for an approval stop** and land
  the new typed-error assertions RED before changing `lib/`. The blast radius
  is wider than the unit test: gate-call-site tests in other files
  (`u_gate_test`, `cp_gate_test`, …) also assert the old type and surface only
  when the full suite runs. Run `mix test` (not just the unit file) to find them all.
- **Doc surface is duplicated:** `## Raises` for a public gate lives in both the
  impl module AND the `Qx.*` delegator in `lib/qx.ex`. Grep both:
  `grep -rn "ArgumentError" lib/qx.ex lib/qx/operations.ex`.
- **New typed error?** If the offending value can be a binary string, do NOT
  copy the family's `exception(message) when is_binary` fallback — capture
  every value in a struct field and document why the fallback is absent.
- **SemVer pre-1.0:** an error-type change is observable (callers rescuing
  `ArgumentError` miss the new type). Pre-1.0, ship it as a minor/patch with a
  CHANGELOG `Changed` entry (mirrors the predecessor `iron-law-7-critical`,
  0.7.1→0.8.0). The `mix.exs` bump is a deliberate release step when the whole
  ROADMAP version section is checked — not per-item.

## Related

- Predecessor plan `iron-law-7-critical` (shipped 0.8.0) — converted the CRITICAL
  `FunctionClauseError`/`ArgumentError`/bare-string leaks in `Qx.QuantumCircuit`,
  `Qx.Operations`, `Qx.Simulation`; built the `Qx.QubitIndexError {:duplicate}`
  constructor this work reused.
- Successor [[sweep-typed-errors-public-surface-iron-law-7-20260624]]
  (`iron-law-7-sweep`, shipped `main` `9003dca`) — **closed** the two follow-ups
  discovered here: the `Qx.Operations.u/5` `FunctionClauseError` stray (guard
  relaxed to fall through to `add_gate/4`) and the broader `register.ex`
  `ArgumentError` sweep (reusing the now-typed `validate_qubits_different!/1`),
  plus the `draw*`/`qubit`/`openqasm` sites and two new exceptions
  (`Qx.RegisterError`, `Qx.BasisError`).
- Iron Law #7 (Qx `AGENTS.md`/`CLAUDE.md` plugin block).
