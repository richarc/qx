---
module: "Qx.Register / Qx.Draw / Qx.Operations"
date: "2026-06-24"
problem_type: iron_law_violation
component: architecture
symptoms:
  - "`Qx.Register.new/1`, `from_basis_states/1`, the distinctness gates (`cx`/`cz`/`cy`/`ccx`/`swap`/`iswap`/`cswap`), `Qx.Qubit.from_basis/1`, `Qx.Draw.*`, `Qx.Draw.Tables.render/2`, `Qx.Draw.SVG.Circuit.render/1`, and `Qx.Export.OpenQASM.to_qasm/2` raised raw `ArgumentError` across the API boundary (~24 sites)"
  - "`Qx.u/5`/`Qx.Operations.u/5` raised `FunctionClauseError` for an out-of-range qubit because the guard `when qubit >= 0 and qubit < circuit.num_qubits` failed with no fallback clause"
  - "`Qx.create_circuit/1,2` `## Raises` docs still advertised `FunctionClauseError` for a bad `num_qubits`, but the function actually raises `Qx.QubitCountError` (validation wired in by an earlier plan) — surfaced by review, not grep"
root_cause: "Last cluster of Iron Law #7 debt: public functions across `Qx.Register`, `Qx.Qubit`, `Qx.Draw*`, and `Qx.Export.OpenQASM` predated the typed-error family and still leaked raw `ArgumentError`; `u/5` enforced bounds in its guard instead of routing through `Qx.QuantumCircuit.add_gate/4`'s existing `Qx.QubitIndexError`."
severity: medium
iron_law_number: 7
tags: [iron-law-7, typed-errors, defexception, public-api, argumenterror, functionclauseerror, guard-relaxation, defensive-validation]
related_solutions: ["route-validation-raises-to-typed-errors-iron-law-7-20260624"]
---

# Sweep raw `ArgumentError`/`FunctionClauseError` off the rest of the public surface

## Symptoms

The follow-on to [[route-validation-raises-to-typed-errors-iron-law-7-20260624]]:
that plan closed the `Qx.Validation` raises; this one cleared everything else
that still leaked a raw error across the public boundary, plus the `u/5` stray.

| Site cluster | Old raise | New raise |
|---|---|---|
| `register.ex` construction (`new/1` empty/bad qubit, `from_basis_states/1` empty) | `ArgumentError` | **`Qx.RegisterError`** (new, `:reason`) |
| `register.ex` / `qubit.ex` basis "must be 0 or 1" | `ArgumentError` | **`Qx.BasisError`** (new, `:value`) |
| `register.ex` distinctness (`cx`/`cz`/`cy`/`ccx`/`swap`/`iswap`/`cswap`) | `ArgumentError` | `Qx.QubitIndexError {:duplicate, …}` |
| `draw.ex` (4 sites) + `draw/tables.ex` bad `:format` | `ArgumentError` | `Qx.OptionError {:format, …}` |
| `export/openqasm.ex` bad `:version` | `ArgumentError` | `Qx.OptionError {:version, …}` |
| `draw/svg/circuit.ex` (5 sites) | `ArgumentError` | `QubitCountError` / `GateError` / `QubitIndexError` / `ClassicalBitError` |
| `operations.ex` `u/5` OOR qubit | `FunctionClauseError` | `Qx.QubitIndexError` |

## Investigation

1. **Grep `lib/` wholesale, not the plan's site list.** `grep -rn "raise ArgumentError" lib/`
   is the source of truth — line numbers in the plan drift. The same grep at the
   end (returning **zero**) is the completion proof.
2. **Two new types, or reuse?** Most sites mapped onto existing types
   (`QubitIndexError`, `OptionError`, `GateError`, `QubitCountError`,
   `ClassicalBitError`). Only register construction and the basis check had no
   fitting type → `Qx.RegisterError` (a `:reason` tuple: `:empty` /
   `{:invalid_qubit, q}` / `{:invalid_input, v}`) and `Qx.BasisError`.
3. **Distinctness gates reuse the predecessor's helper.** Where a list of qubits
   was already in hand (`ccx`, `cswap`), `Qx.Validation.validate_qubits_different!/1`
   replaced the hand-rolled `if a == b or … raise` — one call, `QubitIndexError {:duplicate}`.

## Root Cause

Iron Law #7 (Qx `CLAUDE.md`): *public functions raise typed `Qx.*Error`; do not
let raw `Nx`/`Complex`/`ArgumentError` leak across the API boundary.* These were
the remaining sites the 0.8.0 CRITICAL pass and the validation follow-on didn't
reach — debt, not regression.

## Solution — the non-obvious parts

### 1. Relax an over-strict guard to reach an *existing* typed error

`u/5` was the only gate enforcing bounds in its **guard**:

```elixir
# before — OOR qubit fails the clause => FunctionClauseError
def u(%QuantumCircuit{} = circuit, qubit, theta, phi, lambda)
    when qubit >= 0 and qubit < circuit.num_qubits do
```

Its siblings (`rx`/`ry`/`rz`/`cp`) carry no bounds guard — they fall through to
`Qx.QuantumCircuit.add_gate/4`, which already calls `validate_qubit_index!/2`
and raises `Qx.QubitIndexError`. The fix is to **delete the bounds and keep only
the type guard**, letting the body reach `add_gate`:

```elixir
def u(%QuantumCircuit{} = circuit, qubit, theta, phi, lambda)
    when is_integer(qubit) do
```

Lesson: when one clause in a family enforces a constraint via its guard and the
rest delegate to a validator, the guard is the bug — relax it to match siblings,
don't add a new validation call. Verify the delegate (`add_gate/4`) keeps the
`is_integer` guard so non-integers still fail cleanly.

### 2. `Qx.BasisError` omits the `is_binary` fallback (same trap as `ParameterError`)

A basis value can be any term, including a binary, so — exactly like
`Qx.ParameterError` in the predecessor — `Qx.BasisError` must **not** copy the
family's `exception(message) when is_binary` clause, or `"x"` gets misread as a
pre-formatted message instead of captured in `:value`. The `@moduledoc` says why,
and a struct-field test guards it.

### 3. Defensive-validation paths are only reachable via hand-built structs

`Qx.Draw.SVG.Circuit.render/1`'s `validate_circuit!` checks for >20 qubits, bad
gate names, and OOR qubit/classical-bit indices — but the **public constructors
reject all of those earlier**, so these branches are unreachable through the
normal API. To test them (and to get coverage on the retyped raises), construct
a malformed struct directly:

```elixir
circuit = %Qx.QuantumCircuit{num_qubits: 1, num_classical_bits: 0,
                             instructions: [{:bogus, [0], []}]}
assert_raise Qx.GateError, fn -> Qx.Draw.SVG.Circuit.render(circuit) end
```

The error path runs before `state` is touched, so the struct can omit `state`.

### 4. Retyping can expose *adjacent* docs an earlier plan made stale

Review (not grep) caught that `Qx.create_circuit/1,2` docs still claimed
`FunctionClauseError` for a bad `num_qubits` — but a prior plan wired
`validate_num_qubits!` into `QuantumCircuit.new`, so it now raises
`Qx.QubitCountError`. **Verify empirically** before editing the doc:

```
mix run -e 'try do Qx.create_circuit(0) rescue e -> IO.puts(inspect(e.__struct__)) end'
# => Qx.QubitCountError
```

The accurate doc lists both: `QubitCountError` for an integer out of range,
`FunctionClauseError` only for a non-integer / negative classical-bit count
(the guard's genuine job).

### Files Changed

- `lib/qx/errors.ex` — new `Qx.RegisterError` + `Qx.BasisError`; added to the `Qx.Error` moduledoc list.
- `lib/qx/register.ex`, `qubit.ex`, `draw.ex`, `draw/tables.ex`, `draw/svg/circuit.ex`, `export/openqasm.ex`, `operations.ex` — ~24 raises retyped; `u/5` guard relaxed; unused `gate_name` param dropped from a private validator.
- `lib/qx.ex`, `operations.ex`, `export/openqasm.ex`, `draw/svg/circuit.ex` — `## Raises`/`## Validation` docs corrected.
- `CHANGELOG.md` — `[Unreleased]` Changed entry.
- `test/qx/{register,export/openqasm,u_gate}_test.exs` retyped; new `test/qx/typed_errors_sweep_test.exs` (18→20 tests covering the two new exceptions + the defensive `SVG.Circuit` paths + `Draw`/`Tables` format errors).
- `ROADMAP.md` — ticked both v0.8.1 lines (the `u/5` stray + the `ArgumentError` sweep).
- Shipped on `main` in squash commit `9003dca` after `/phx:review` PASS (3 reviewers). 245 doctests + 872 tests, 0 failures.

## Prevention

- [x] **Already an Iron Law** — #7; `iron-law-judge` flags raw `ArgumentError`/`FunctionClauseError` across the public boundary.
- **Grep is the spec, not the plan.** `grep -rn "raise ArgumentError" lib/` before AND after; zero at the end is the proof. Plan line numbers drift across edits.
- **Process gate (TDD + hook):** retyping breaks every existing `assert_raise ArgumentError`/`FunctionClauseError` for that path. The `PreToolUse` hook hard-blocks all `*_test.exs` writes (existing edits AND new files) and TDD rule #2 needs explicit human approval — get approval for the *whole* test set up front, then land lib changes and watch the suite go RED before retyping the assertions.
- **Test blast radius is the full suite.** Gate-call-site tests in unrelated files assert the old type; only `mix test` (not the unit file) finds them all.
- **Guard vs. validator:** if one clause in a gate family enforces a bound in its guard and the rest delegate to a validator, relax the guard to match — don't bolt on a redundant check.
- **Defensive paths need hand-built structs** to test; without them the retyped raise has zero coverage.
- **Re-verify adjacent docs after a behavior change lands elsewhere.** A doc can be wrong because an *earlier* plan changed runtime behavior, not because this change touched it — empirically check what a function raises before trusting (or rewriting) its `## Raises`.
- **SemVer pre-1.0:** observable error-type change → CHANGELOG `Changed` entry, minor/patch, no major bump (mirrors both predecessors). Release is tag-gated, not merge-gated.

## Related

- Predecessor [[route-validation-raises-to-typed-errors-iron-law-7-20260624]] (`iron-law-7-followon`, 0.8.1) — closed the `Qx.Validation` raises and built the `Qx.ParameterError` / `QubitIndexError {:duplicate}` constructors this sweep reused. Its "open follow-ups" (the `u/5` stray and the `register.ex` sweep) are exactly what this doc closes.
- Predecessor `iron-law-7-critical` (0.8.0) — converted the CRITICAL leaks in `Qx.QuantumCircuit`/`Operations`/`Simulation`; built `add_gate/4`'s `QubitIndexError` that the `u/5` fix now falls through to.
- Deferred (still open after this sweep): guard-only `FunctionClauseError` on `Qx.Register.from_basis_states/1` non-list input and `Qx.Gates.swap/3`/`iswap/3` docs — a future guard-routing pass; `export/openqasm/parser.ex:568` `String.to_float/1` deferred to v0.8.3 (grammar-validated input, does not leak across the boundary).
- Iron Law #7 (Qx `AGENTS.md`/`CLAUDE.md` plugin block).
