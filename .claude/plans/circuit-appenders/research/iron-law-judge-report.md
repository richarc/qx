# Iron Law Judge Report — feat/circuit-appenders

## Summary
- Files scanned: `lib/qx/patterns.ex`, `lib/qx.ex`, `CHANGELOG.md`, `test/qx/patterns_test.exs`, `lib/qx/errors.ex`
- Iron Laws checked: #6 (public API surface), #7 (typed errors), #9 (dispatch completeness), TDD discipline
- Violations found: 0

## Verdict: PASS

## Per-law status

### #6 Public API surface — PASS
- Change is purely additive: `Qx.Patterns.bell_pair/4` + `Qx.bell_pair/4` facade
  delegate, `Qx.Patterns.ghz/2` + `Qx.ghz/2` facade delegate. No existing
  public function's arity, `@spec`, or `@doc` contract changed.
- `bell_state_circuit/1` and `ghz_state_circuit/1` (both `@doc false`, called
  only through the `Qx.bell_state/1` / `Qx.ghz_state/1` facade, per the
  module's own documented convention) were reframed to thin wrappers:
  - `bell_state_circuit/1`: `QuantumCircuit.new(2) |> bell_pair(0, 1, which)`
    — `bell_pair/4`'s own `which`-dispatch clauses (`:phi_plus/:phi_minus/
    :psi_plus/:psi_minus` + fallback `raise Qx.OptionError` with the
    byte-identical message string) now own the dispatch. Gate sequences
    verified identical to the pre-reframe explicit clauses (see plan target
    signatures, matches implementation at `lib/qx/patterns.ex:396-427`).
  - `ghz_state_circuit/1`: happy path now `QuantumCircuit.new(num_qubits) |>
    ghz(0..(num_qubits - 1))`; the `n >= 2` guard and the two
    `Qx.QubitCountError` fallback clauses for `is_integer < 2` and
    non-integer input are **unchanged** (`lib/qx/patterns.ex:443-457`) — the
    appender's own `QubitCountError` path (`ghz/2`, lines 332-345) is
    unreachable for valid creator calls since the creator's guard already
    filters `< 2`.
  - Reframe safety is verified by invariant tests in
    `test/qx/patterns_test.exs:617-627` (`bell_state_circuit(w) == new(2) |>
    bell_pair(0,1,w)` for all 4 `w`; `ghz_state_circuit(n) == new(n) |>
    ghz(0..(n-1))` for n ∈ {2,3,5}), plus the plan's Phase-3 instruction to
    run the full existing (unmodified) `bell_state`/`ghz_state` suite as a
    tripwire.
- CHANGELOG `[Unreleased]` → `### Added` entry present (`CHANGELOG.md:10-21`),
  correctly describes both new functions, the reframe, and states
  "no behaviour change... Purely additive, non-breaking." No version bump —
  correct, since releases in this repo are tag-gated, not bump-on-merge.

### #7 Typed errors — PASS
- `bell_pair/4` bad `which` → falls through to the catch-all clause at
  `lib/qx/patterns.ex:424-427`: `raise Qx.OptionError, {:which, which, ...}`.
  Confirmed `Qx.OptionError` is a real `defexception` (`lib/qx/errors.ex:158-165`).
  Test: `patterns_test.exs:546` (`Patterns.bell_pair(qc, 0, 1, :bogus)`).
- `ghz/2` short list (`[]` or single element) → `raise Qx.QubitCountError,
  {0, 2, 20}` / `{1, 2, 20}` (`lib/qx/patterns.ex:334-338`). Confirmed
  `Qx.QubitCountError` is a real `defexception` (`lib/qx/errors.ex:453-457`).
  Tests: `patterns_test.exs:589`, `:597`.
- Qubit-index misuse (out-of-range, `q0 == q1`) is not independently
  validated by `bell_pair/4`/`ghz/2` — by design, it's surfaced by the
  composed `Operations.h/2`, `Operations.x/2`, `Operations.cx/3` calls, which
  already raise `Qx.QubitIndexError` (confirmed `defexception` at
  `lib/qx/errors.ex:181-185`). Tests: `patterns_test.exs:530` (`q0==q1`),
  `:538` (out-of-range), `:605` (ghz out-of-range).
- No raw `Nx`/`Complex`/`ArgumentError` can escape either new function — both
  bottom out in either a typed raise or a delegated `Operations.*` call.

### #9 Dispatch completeness — PASS
- `bell_pair/4` and `ghz/2` emit only `:h`, `:x`, `:cx` instructions via
  `Operations.h/2`, `Operations.x/2`, `Operations.cx/3`, and `cx_chain/2`
  (itself built from `Operations.cx/3`). These instruction shapes are
  pre-existing and already handled by every consumer (simulation dispatch,
  drawing, OpenQASM export). No new instruction kind introduced, no dead
  special-case arm added.

### TDD — PASS
- Plan phases 1–2 mark `[P1-T1]`/`[P2-T1]` "tests first... Run — MUST FAIL"
  before the corresponding `[P1-T2]`/`[P2-T2]` implementation steps, and all
  are checked off in `.claude/plans/circuit-appenders/plan.md`.
- Phase 3 (`[P3-T1]`) adds invariant-equality tests *before* the reframe
  refactor, present at `test/qx/patterns_test.exs:617-627`, matching the
  plan's requirement.
- Existing `bell_state`/`ghz_state` tests/doctests were not modified (only
  new `describe` blocks and new invariant tests were added) — consistent
  with the "confirm EXISTING tests are NOT modified" plan instruction.

## Notes / non-findings
- No LiveView, Ecto, Oban, or OTP-process code in this diff (qx is a pure
  Elixir library) — those categories from the generic Iron Law checklist are
  N/A here and were not evaluated.
- No `String.to_atom`, `raw/1`, or SQL/query code touched by this diff.
