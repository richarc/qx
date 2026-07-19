# Fix Iron Law #7 Critical Violations

**Branch:** `fix/iron-law-7-critical`
**Source:** `.claude/audit/reports/arch-review.md` (C1, C2, C3 + tightly-coupled M2)
**Target version:** `0.7.1 → 0.8.0` (SemVer minor — observable public-API error type change, pre-1.0)

## Iron Law #7 (qx CLAUDE.md)
> Public functions raise typed `Qx.*Error` on misuse. Do not let raw `Nx` / `Complex` / `ArgumentError` leak across the API boundary — route through `Qx.Validation`.

## Scope (CRITICAL only)
- C1 — `Qx.QuantumCircuit` leaks `FunctionClauseError` / `ArgumentError`
- C2 — `Qx.Operations` raises raw `ArgumentError` from `barrier/2`, `c_if/4`, nested-conditional check
- C3 — `Qx.Simulation` raises bare strings (→ `RuntimeError`)
- M2 — `lib/qx.ex` docstrings advertise `FunctionClauseError` (must update in lockstep with C1)

## Out of scope (deferred)
- H1 (`Qx.Validation` self-leak), H2 (`@spec` coverage), H3 (CalcFast gather pattern)
- M1, M3–M6, L1–L5

## Phases

### Phase 1 — C1: QuantumCircuit + lib/qx.ex docstrings (M2)
- [x] `add_gate/4` — drop bounds from guard; call `Qx.Validation.validate_qubit_index!/2` in body
- [x] `add_two_qubit_gate/5` — drop bounds + distinctness from guard; call `validate_qubit_index!` ×2 + new check via raised `Qx.QubitIndexError` for `c == t` (added `{:duplicate, qubits}` constructor to `Qx.QubitIndexError`)
- [x] `add_measurement/3` — drop bounds from guard; call `validate_qubit_index!` + `validate_classical_bit!`
- [x] `add_three_qubit_gate/6` — replace `validate_indices_*` helper bodies (`raise ArgumentError`) with typed errors via `Qx.Validation`
- [x] `lib/qx.ex` docstrings — replaced `FunctionClauseError` → typed errors in 10 `## Raises` sections (the 2 sites at `create_circuit/1,2` annotated `(guard-only; struct construction predates Qx.Validation)`)
- [x] Add focused test: `test/qx/quantum_circuit_typed_errors_test.exs` (10 tests, all green)
- [x] `mix compile --warnings-as-errors && mix format && mix test test/qx/quantum_circuit_typed_errors_test.exs` ✓

### Phase 2 — C2: Operations typed errors
- [x] `barrier/2` — route through `Qx.Validation.validate_qubit_indices!/2`
- [x] `c_if/4` (3 raises) — `Qx.ClassicalBitError` for index OOR, `Qx.ConditionalError` (binary form) for invalid value and non-fn gate_fn
- [x] `validate_conditional_block/1` nested check — `raise Qx.ConditionalError, :nested_conditionals`
- [x] Add focused test: `test/qx/operations_typed_errors_test.exs` (6 tests, all green)
- [x] Verify ✓

### Phase 3 — C3: Simulation typed errors
- [x] 5 bare-string raises in `lib/qx/simulation.ex` → `Qx.GateError, {:unsupported_gate, gate_name}`
- [x] Add focused test: `test/qx/simulation_typed_errors_test.exs` (5 tests, all green)
- [x] Verify ✓

### Phase 3.5 — Existing-test cleanup (per user "Replace + delete" decision)
- [x] Remove 11 obsolete assertions in 5 test files (swap, iswap, cp, cswap, qx_test) — replaced by new `*_typed_errors_test.exs` coverage. Each deletion site carries a 1-line breadcrumb pointing at the new home.

### Phase 4 — Release prep
- [x] Bump `version: "0.7.1"` → `"0.8.0"` in `mix.exs`
- [x] `CHANGELOG.md` — `[0.8.0] - 2026-05-21` with `### BREAKING` section (matches existing `[0.7.0]` style) documenting the error-type migration; cross-refs C1/C2/C3; explicit "Known deferred" subsection naming H1/M3/M4/M5
- [x] Full gate: `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test` — all clean; 234 doctests + 731 tests, 0 failures
- [x] Self-review against Iron Laws (see Notes below)

### Phase 5 — Post-review triage (from `/phx:review` findings)
- [x] **Finding A** — `Qx.QuantumCircuit.set_state/2` no longer raises bare `ArgumentError`; new typed `Qx.StateShapeError` (with `{actual, expected}` constructor + binary form for non-1-D states) added to `lib/qx/errors.ex` and registered in `mix.exs` `groups_for_modules`. Two new tests in `quantum_circuit_typed_errors_test.exs`.
- [x] **Finding B** — 5 stale `## Raises` docstrings updated to typed errors (`lib/qx.ex:346`, `lib/qx/operations.ex:163, 392, 417, 445`). The 3 remaining `ArgumentError`/`FunctionClauseError` references (`operations.ex:284, 285, 446`) are accurate today via deferred H1/M3 paths and were left alone.
- [x] **Finding C** — Plan-level 0.7.1 → 0.8.0 minor bump confirmed by user; Iron Law #6 text not amended (single dev, plan decision is the audit trail).

## Verification gate (qx CLAUDE.md mandatory)
```
mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict
mix test
```

## Notes
- `Qx.Validation.validate_qubit_index!/2` and `validate_classical_bit!/2` already raise typed errors (`lib/qx/validation.ex:134`, `:190`).
- `Qx.GateError.exception({:unsupported_gate, gate})` constructor exists at `lib/qx/errors.ex:153`.
- `Qx.ConditionalError.exception(:nested_conditionals)` constructor exists at `lib/qx/errors.ex:109`.
- PreToolUse hook on `*_test.exs`: in this branch the hook only warns; 11 obsolete assertions were deleted in 5 existing test files (per user "Replace + delete" decision) and replaced by 21 new typed-error tests across 3 new files.

## Self-review against Iron Laws (`qx/CLAUDE.md`)
- **#1 String.to_atom** — clean, none introduced.
- **#2 No processes** — clean, none added.
- **#3 Reshape vs gather** — Nx kernels untouched.
- **#4 defn / BinaryBackend** — no defn changes.
- **#5 No host-side 2^n loops** — none introduced.
- **#6 Breaking + version bump** — CHANGELOG present; 0.7.1→0.8.0 is a SemVer 0.x minor (treated as effective major per pre-1.0 convention). User confirmed plan decision; Iron Law #6 text was not amended.
- **#7 Typed errors at API boundary** — the entire point of this branch. All sites named in arch-review C1/C2/C3 now route through typed errors; `set_state/2` (Finding A) also fixed. Deferred (per plan + reviewer): H1 (`Qx.Validation` self-leak), M3 (`u/5` guard), M4–M5 (`Qx.Qubit`, `Qx.Register`).
- **#8 Tolerance feasibility** — no tolerance constants touched.

## Stop conditions
- Skill stops at merge gate after self-review. Does NOT merge to `main` — human authorization required.

## Outcome
- All 4 plan phases + post-review triage complete. Branch is at green merge gate (PASS verdict; new findings A/B resolved, C confirmed). Awaiting human authorization for `git merge --squash` to `main`, ROADMAP tick, and the deliberate 0.8.0 release tag (release-manager agent).
