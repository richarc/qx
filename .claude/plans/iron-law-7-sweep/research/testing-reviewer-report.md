# Test Review: Iron Law #7 Sweep — typed_errors_sweep_test.exs + retyped assertions

Reviewed files:
- `test/qx/typed_errors_sweep_test.exs` (new, untracked)
- `test/qx/register_test.exs` (retyped assertions)
- `test/qx/export/openqasm_test.exs` (retyped assertions)
- `test/qx/u_gate_test.exs` (retyped assertions)

---

## Summary

The sweep is largely sound. The new test file covers the two new exception
structs (`Qx.RegisterError`, `Qx.BasisError`) plus all the call sites that
previously leaked raw errors. Payloads are asserted on all newly-tested sites.
There are two genuinely missing coverage gaps (both SHOULD-FIX), one message
mismatch that is a silent test pass waiting to become a broken assertion
(SHOULD-FIX), one async omission (SHOULD-FIX), and a handful of NICE-TO-HAVE
issues.

---

## Iron Law Violations

None. No mocks, no database, no Mox, no `Process.sleep`. Pure unit tests.

---

## Issues Found

### Critical

None.

---

### SHOULD-FIX

#### S-1 — `u_gate_test.exs` missing `async: true`
`test/qx/u_gate_test.exs:2`

```elixir
use ExUnit.Case   # ← no async: true
```

This is a pure-logic test with no shared state. Iron Law #1 (ASYNC BY DEFAULT)
applies. All other files in this sweep use `async: true`; this one was missed.

Fix:
```elixir
use ExUnit.Case, async: true
```

---

#### S-2 — `openqasm_test.exs` message regex may silently mis-match
`test/qx/export/openqasm_test.exs:21`

```elixir
assert_raise Qx.OptionError, ~r/option :version/, fn ->
  OpenQASM.to_qasm(circuit, version: 1)
end
```

`Qx.OptionError.exception/1` (in `lib/qx/errors.ex:135`) formats the message
as:

```
"Invalid value for option :version: 1. Must be 2 or 3."
```

The text "option :version" does appear in the rendered string, so the regex
passes today. However, the colon-after-atom pattern (`option :version:`) is
fragile — if the message template changes to `"option #{inspect(option)} is
invalid"` the regex will break silently because the type check still passes.

Preferred pattern: capture the exception and assert `:option` / `:value`
fields, as is done consistently in `typed_errors_sweep_test.exs`:

```elixir
e = assert_raise Qx.OptionError, fn ->
  OpenQASM.to_qasm(circuit, version: 1)
end
assert e.option == :version
assert e.value == 1
```

---

#### S-3 — `Qx.Draw.bloch_sphere/2` and `Qx.Draw.histogram/2` format errors untested
`lib/qx/draw.ex:182` and `lib/qx/draw.ex:231`

The sweep test covers `Qx.Draw.plot/2` and `Qx.Draw.plot_counts/2` for the
`:format` option guard (`typed_errors_sweep_test.exs:86-96`). The identical
guard in `bloch_sphere/2` and `histogram/2` raises `Qx.OptionError` but has no
corresponding test.

The sweep's declared scope is "the public sites that previously leaked a raw
error" — these two functions share exactly that pattern. The omission is not a
regression (there were no prior assertions) but it is an inconsistency in what
the sweep set out to achieve.

Fix: add two tests to the existing `"Qx.Draw format options"` describe block.

---

#### S-4 — `from_basis_states/1` non-list input path untested
`lib/qx/register.ex:161`

```elixir
def from_basis_states(states) when is_list(states) do
```

A non-list input (e.g. `Qx.Register.from_basis_states(:not_a_list)`) falls
through to a `FunctionClauseError` — the old raw-error leak that the sweep was
meant to eliminate. The sweep only tests the empty-list and bad-element paths,
leaving this clause unguarded and untested. Whether the sweep intentionally
skipped a guard clause here or the guard was simply missed is not clear from the
code, but the raw error still leaks at this call site.

Either:
- add a `def from_basis_states(other)` fallback that raises `Qx.RegisterError,
  {:invalid_input, other}` and test it, or
- add a test documenting that a `FunctionClauseError` (not a `Qx.*Error`) is
  the expected outcome for non-list inputs, to make the gap explicit.

---

### NICE-TO-HAVE

#### N-1 — `Qx.RegisterError` "invalid_qubit" reason left unasserted in `register_test.exs`
`test/qx/register_test.exs:73`

```elixir
assert_raise Qx.RegisterError, ~r/Invalid qubit/, fn ->
  Register.new([invalid_qubit])
end
```

The exception struct carries `reason: {:invalid_qubit, qubit}` but the
assertion only checks the message string. Capturing the exception and asserting
`e.reason` (as done in `typed_errors_sweep_test.exs:21-22`) would be
consistent and less brittle.

---

#### N-2 — `Qx.GateError` `:gate` field unasserted for SVG circuit test
`test/qx/typed_errors_sweep_test.exs:104-112`

```elixir
e = assert_raise Qx.GateError, fn -> SvgCircuit.render(circuit) end
assert e.gate == :bogus
```

`Qx.GateError` is raised with `{:unsupported_gate, gate}` which sets
`e.gate = :bogus` — this is correctly asserted. Good. No action needed here.

---

#### N-3 — `Qx.QubitIndexError` payload fields unasserted in SVG circuit tests
`test/qx/typed_errors_sweep_test.exs:115-128`

The two `Qx.QubitIndexError` SVG circuit tests (`out-of-range gate qubit`,
`out-of-range measurement qubit`) only call `assert_raise` without capturing
the exception. The struct carries `:qubit` and `:max`; asserting them would
improve regression detection.

```elixir
e = assert_raise Qx.QubitIndexError, fn -> SvgCircuit.render(circuit) end
assert e.qubit == 5
assert e.max == 1
```

This is NICE-TO-HAVE, not blocking.

---

#### N-4 — `Qx.ClassicalBitError` payload unasserted in SVG circuit test
`test/qx/typed_errors_sweep_test.exs:130-133`

Same as N-3 for `Qx.ClassicalBitError` — `:bit` and `:max` are set by the
exception constructor but not asserted.

---

#### N-5 — `Qx.QubitCountError` payload unasserted in SVG circuit test
`test/qx/typed_errors_sweep_test.exs:99-101`

`Qx.QubitCountError` carries `:count`, `:min`, `:max`. The test only checks
that the exception type is raised; asserting `e.count == 21` would be
appropriate given that count is directly observable.

---

## Coverage Assessment by Mapped Site

| Site | Tested | Payload asserted |
|------|--------|-----------------|
| `Qx.RegisterError` struct unit | Yes | Yes (all clauses) |
| `Qx.BasisError` struct unit | Yes | Yes |
| `Qx.Register.from_basis_states/1` — empty list | Yes | Yes (`:reason == :empty`) |
| `Qx.Register.from_basis_states/1` — bad element | Yes | Yes (`:value == 2`) |
| `Qx.Register.from_basis_states/1` — non-list input | **No** | — (S-4) |
| `Qx.Qubit.from_basis/1` | Yes | Yes (`:value == 2`) |
| `Qx.Draw.Tables.render/2` — invalid input | Yes | Yes |
| `Qx.Draw.Tables.render/2` — bad format | Yes | Yes (`:option`, `:value`) |
| `Qx.Draw.plot/2` — bad format | Yes | Partial (`:option` only, no `:value`) |
| `Qx.Draw.plot_counts/2` — bad format | Yes | Partial (`:option` only) |
| `Qx.Draw.bloch_sphere/2` — bad format | **No** | — (S-3) |
| `Qx.Draw.histogram/2` — bad format | **No** | — (S-3) |
| `Qx.Draw.SVG.Circuit` — qubit limit | Yes | No (N-5) |
| `Qx.Draw.SVG.Circuit` — unsupported gate | Yes | Yes (`:gate`) |
| `Qx.Draw.SVG.Circuit` — out-of-range gate qubit | Yes | No (N-3) |
| `Qx.Draw.SVG.Circuit` — out-of-range measure qubit | Yes | No (N-3) |
| `Qx.Draw.SVG.Circuit` — out-of-range classical bit | Yes | No (N-4) |

---

## Retyped Assertions Correctness

All three retyped files assert the correct new exception modules:

- `register_test.exs` — `Qx.RegisterError`, `Qx.QubitCountError`, `Qx.QubitIndexError`: correct.
- `openqasm_test.exs` — `Qx.OptionError` (version), `Qx.ConditionalError` (v2 conditional): correct.
- `u_gate_test.exs` — `Qx.ParameterError`, `Qx.QubitIndexError`: correct.

No retyped assertion names the wrong exception type.
