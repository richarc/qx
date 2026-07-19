# API cleanup — Phase B: additive parity + gate completion

**Branch:** `feat/api-cleanup-phase-b`
**Source:** Elevation of Phase B from
`.claude/plans/public-api-audit/plan.md`. Covers 5 audit findings:
B3 (n-qubit `Qx.superposition`), B4 (move state-shaped helpers out
of inline `lib/qx.ex`), B5 (full `Qx.Register` gate parity), B6
(`Qx.Qubit` basis-explicit measurement), D2 option-(a) (implement
the `Qx.Behaviours.QuantumState` behaviour on `Qx.Qubit` and
`Qx.Register`).
**Target version:** Ships in `0.8.x` (likely `0.8.1` or a dedicated
patch). **Non-breaking** — every change is either a new function,
a new default-arg, or a refactor preserving the existing call sites
via `defdelegate`. The `Qx.Behaviours.QuantumState` callback list
grows, but no existing implementor is broken (no one implements it
today — see audit finding D2).

## Context

Phase A made ExDoc honest. Phase B closes the **gate-parity gap**
between Qx's three paradigm-specific gate-application surfaces:
`Qx.Operations` (circuit mode), `Qx.Register` (calc-mode multi-qubit),
and `Qx.Qubit` (calc-mode single-qubit). The audit found that
`Qx.Register` is missing 8 gates that `Qx.Operations` has, and
`Qx.Qubit` is missing the basis-explicit measurements that shipped
in QAAL-parity. The `Qx.Behaviours.QuantumState` behaviour exists
but no module implements it — Phase B does both: completes the
parity *and* implements the behaviour to lock in future parity.

## Decisions (locked from the audit)

1. **D2 option (a) — implement the behaviour**, not remove it.
   Reasoning: the behaviour is the *enforcement mechanism* for the
   parity Phase B establishes. Going forward, adding a gate to
   `Qx.Operations` will force the same gate onto `Qx.Register` and
   `Qx.Qubit` via the `@behaviour` `@callback` check. That's a
   feature, not a cost — it's exactly the gate-parity bug Phase B
   exists to fix.
2. **Behaviour callbacks must grow to match the post-Phase-B
   surface.** The current 13-callback list reflects only the
   pre-QAAL gate set. Expand to include `iswap`, `cp`, `cy`, `crx`,
   `cry`, `crz`, `cswap`, `u`, `sdg`, and `measure_x`/`measure_y`/
   `measure_z`. Optional callbacks (using `@optional_callbacks`)
   for those that don't apply to single-qubit `Qx.Qubit`
   (`cx`/`cz`/`cy`/`crx`/`cry`/`crz`/`cswap`/`ccx` — all need ≥2
   qubits).
3. **B5/B6 implementations mirror existing patterns**, not
   re-derive matrices. `Qx.Register.cx/3` already exists and uses
   `Qx.Calc.apply_cnot/4`; the new `Qx.Register.cy/3` will use
   `Qx.Gates.controlled_gate/4` with `Qx.Gates.pauli_y/0` — same
   shape as the new `Qx.Simulation` dispatch from QAAL-parity.
4. **B4 placement: extend `Qx.Patterns`** to host
   `bell_state_circuit/1`, `ghz_state_circuit/1`,
   `superposition_circuit/1`. The top-level `Qx.bell_state`,
   `Qx.ghz_state`, `Qx.superposition` become `defdelegate`s.
   *Names use the `_circuit` suffix to mirror the
   `_state_vector` proposal in Phase C — but both old names
   remain via the top-level delegate, so no break.* Alternative:
   new module `Qx.Circuits`. Decision: `Qx.Patterns` — it
   already exists, the helpers are tiny, and "named circuit
   recipes" *is* a composite pattern.

## Scope summary

| Finding | File | Change | Lines |
|---|---|---|---|
| B3 | `lib/qx.ex` `superposition/0` → `superposition/1` | Add optional `num_qubits \\ 1` arg. Move body to `Qx.Patterns`; top-level becomes `defdelegate`. | ~5 |
| B4 | `lib/qx.ex` `bell_state/1`, `ghz_state/0`, `superposition` | Move bodies to `Qx.Patterns` as `bell_state_circuit/1`, `ghz_state_circuit/1` (n-qubit), `superposition_circuit/1`. Top-level keeps existing names as `defdelegate`s. **No break** — every existing caller of `Qx.bell_state/1` etc. continues to work. | ~50 |
| B5 | `lib/qx/register.ex` | Add `iswap/3`, `cp/4`, `cy/3`, `crx/4`, `cry/4`, `crz/4`, `cswap/4`, `u/5`. Each ~5–10 lines, following the existing `cx/3` / `cz/3` pattern (state-vector evolution via `Qx.Calc` or `Qx.Gates.controlled_gate/4` + `Nx.dot/2`). | ~70 |
| B6 | `lib/qx/qubit.ex` | Add `measure_x/1`, `measure_y/1`, `measure_z/1`. Each is a wrapper over the existing `measure_probabilities/1` with a basis-change pre-step (`H` for X-basis, `Sdg \|> H` for Y-basis, identity for Z-basis). | ~30 |
| D2-a | `lib/qx/behaviours/quantum_state.ex` | Expand callback list to cover the full post-B5/B6 surface. Use `@optional_callbacks` for the multi-qubit gates that don't apply to single-qubit `Qx.Qubit`. | ~30 |
| D2-a | `lib/qx/qubit.ex` | Add `@behaviour Qx.Behaviours.QuantumState` at the top. Add `@impl true` annotations on every implementing function. | ~15 |
| D2-a | `lib/qx/register.ex` | Same — add `@behaviour Qx.Behaviours.QuantumState` and `@impl true` annotations. | ~20 |

**Net change budget:** ~220 lines of new lib code + ~200 lines of
tests + doctests. No public function is removed or renamed.

## Phases

### Phase 1 — Move state-shaped helpers into `Qx.Patterns` (B4 + B3)

- [x] `lib/qx/patterns.ex` — add `bell_state_circuit/1` accepting
      `:phi_plus | :phi_minus | :psi_plus | :psi_minus` (default
      `:phi_plus`). Bodies copied from `lib/qx.ex:1139-1165`.
- [x] `lib/qx/patterns.ex` — add `ghz_state_circuit/1` accepting
      `num_qubits` (default 3). For `n = 3`, body identical to
      existing `Qx.ghz_state/0`. For `n > 3`, extend via `cx_chain`.
- [x] `lib/qx/patterns.ex` — add `superposition_circuit/1` accepting
      `num_qubits` (default 1).
- [x] `@spec` + `@doc` + at least one doctest per new helper.
- [x] `lib/qx.ex` — replace the three inline `def`s
      (`bell_state/1`, `ghz_state/0`, `superposition/0`) with
      `defdelegate bell_state(which \\ :phi_plus), to: Patterns,
      as: :bell_state_circuit` etc. Top-level keeps its existing
      arities for backward compat.
- [x] **New top-level `Qx.superposition/1`** — extends arity to
      accept `num_qubits` (default 1). The old 0-arity call
      `Qx.superposition()` still works because of the default arg.
- [x] **New top-level `Qx.ghz_state/1`** — extends arity to accept
      `num_qubits` (default 3). Old 0-arity call still works.
- [x] Tests: `test/qx/patterns_test.exs` — add `describe` blocks
      for each new helper covering golden path + the new arity
      cases.
- [x] Verify: compile clean, format clean, all existing tests
      still pass.

### Phase 2 — Full `Qx.Register` gate parity (B5)

- [x] `lib/qx/register.ex` — add `iswap/3`, `cp/4`, `cy/3`,
      `crx/4`, `cry/4`, `crz/4`, `cswap/4`, `u/5`. Pattern: each
      function applies the gate matrix to `register.state` via
      `Qx.Gates.controlled_gate/4` (for controlled gates) or
      `Qx.Gates.<gate>/n` + `Qx.Calc.apply_single_qubit_gate/4` (for
      single-qubit-after-control gates).
- [x] `@spec` + `@doc` + at least one doctest per new function,
      following the existing `Qx.Register.cx/3` style.
- [x] Tests: extend `test/qx/register_test.exs` with golden-path +
      validation tests for each new gate. Borrow the
      probability-distribution checks from
      `test/qx/operations_controlled_rotations_test.exs` but adapted
      to the `Qx.Register` API.
- [x] Verify.

### Phase 3 — `Qx.Qubit` basis-explicit measurement (B6)

- [x] `lib/qx/qubit.ex` — add `measure_z/1` as an alias of the
      existing `measure_probabilities/1` (symmetry).
- [x] `lib/qx/qubit.ex` — add `measure_x/1` as
      `qubit |> h() |> measure_probabilities()`.
- [x] `lib/qx/qubit.ex` — add `measure_y/1` as
      `qubit |> sdg() |> h() |> measure_probabilities()`.
- [x] `@spec` + `@doc` + doctest per function.
- [x] Tests: `test/qx/qubit_test.exs` — assert deterministic
      probabilities on `|+⟩`/`|−⟩`/`|+i⟩`/`|−i⟩` matching the
      same pattern from the circuit-mode test
      (`test/qx/operations_basis_measurement_test.exs`).
- [x] Verify.

### Phase 4 — Expand `Qx.Behaviours.QuantumState` callbacks (D2-a)

- [x] `lib/qx/behaviours/quantum_state.ex` — extend `@callback`
      list to cover all gates that *both* `Qx.Register` and
      `Qx.Qubit` now expose. Mark multi-qubit gates as
      `@optional_callbacks` since `Qx.Qubit` (single-qubit) cannot
      implement them.
- [x] Add `@callback measure_x(state) :: state` (and `_y`/`_z`).
- [x] Update `@moduledoc` to reflect the expanded surface.
- [x] No tests for the behaviour itself — its enforcement is
      compile-time.

### Phase 5 — Implement the behaviour on `Qx.Qubit` and `Qx.Register` (D2-a)

- [x] `lib/qx/qubit.ex` — add `@behaviour Qx.Behaviours.QuantumState`
      at the top of the module. Tag every implementing function
      with `@impl true`. Compile must pass (any callback the module
      claims to implement must have the matching signature; any
      mandatory callback the module doesn't implement is a compile
      warning under `--warnings-as-errors`).
- [x] `lib/qx/register.ex` — same.
- [x] **Iron Law #6 check:** the `@behaviour` annotation is
      additive (no existing function signature changes); no public
      API breaks.

### Phase 6 — Final verification + CHANGELOG + ROADMAP

- [x] Full gate: `mix compile --warnings-as-errors && mix format
      --check-formatted && mix credo --strict && mix test`.
- [x] CHANGELOG `## [0.8.0]` `### Added` — extend the existing
      QAAL-parity entry with a new bullet group:
      *"Calc-mode gate parity (`Qx.Register`):* iswap, cp, cy, crx,
      cry, crz, cswap, u; basis-explicit measurement on `Qx.Qubit`
      (`measure_x`, `measure_y`, `measure_z`); state-shaped circuit
      recipes (`Qx.bell_state/1`, `Qx.ghz_state/1`,
      `Qx.superposition/1`) now consolidated under `Qx.Patterns`
      and the latter two accept an optional `num_qubits` argument."*
- [x] CHANGELOG `### Changed` — note that
      `Qx.Behaviours.QuantumState` now has additional callbacks and
      is **implemented** by `Qx.Qubit` and `Qx.Register` (was
      previously a dead behaviour with no implementor — see
      audit D2).
- [x] ROADMAP v0.8.1 — tick the relevant follow-on items if
      applicable, or close the audit item if all of Phase B
      landed.

## Verification gate (qx CLAUDE.md mandatory)

```
mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict
mix test
```

## Notes / Iron Law compliance

- **Iron Law #1, #2** (atom interning, processes) — N/A.
- **Iron Law #3, #4, #5, #8** (Nx kernels) — Phase 2's `iswap`,
  `cp`, `cy`, `crx`, `cry`, `crz`, `cswap`, `u` on `Qx.Register`
  reuse the existing two-qubit and single-qubit kernels in
  `Qx.Calc` / `Qx.Gates`. **No new `defn`.** No new gather/mask
  patterns. Backend-agnostic. Confirmed by mirroring the existing
  `Qx.Register.cx/3` implementation shape.
- **Iron Law #6** (public API surface) — every change is additive.
  CHANGELOG entries reflect the new functions; no `### BREAKING`
  section.
- **Iron Law #7** (typed errors) — new functions inherit typed
  errors from the underlying `Qx.Validation.validate_*!` calls
  (which Phase A made internal but still raise the same typed
  exceptions). No new exception types.

## Risks

1. **`@behaviour` enforcement may surface missing parity at
   compile time as a *warning*, not an error.** Phase 4's expanded
   callback list must be matched exactly by Phase 5's `@impl true`
   annotations. If any callback is declared but no module
   implements it, compile under `--warnings-as-errors` will fail —
   which is the *desired* failure mode (it forces parity). Risk:
   the failure cascade may surface mid-Phase-5 and require
   reordering some Phase 2/3 work.
2. **`Qx.Qubit` is single-qubit; multi-qubit callbacks must be
   `@optional_callbacks`.** Getting that list wrong means
   `Qx.Qubit` fails to compile claiming it doesn't implement
   `cx/3`. Mitigation: explicitly enumerate the optional callbacks
   in Phase 4 before touching the implementor modules in Phase 5.
3. **`Qx.Register` doctests must use deterministic states.** The
   new gate functions return registers — doctest assertions should
   compare structural shape (`Nx.shape(reg.state)`) and a few
   probability values, not stochastic counts. Pattern: mirror
   `test/qx/operations_controlled_rotations_test.exs` style.
4. **`Qx.Patterns` is starting to host both "apply to every qubit"
   patterns and "build a named circuit recipe" patterns** (B4).
   These are conceptually different (`h_all/1` extends an existing
   circuit; `bell_state_circuit/1` creates a new one). Risk: the
   module's identity blurs over time. Mitigation: explicit
   `@moduledoc` partitioning *("Composite operations on an existing
   circuit" vs "Named circuit recipes")*. Defer renaming/splitting
   to v1.0 if it gets unwieldy.

## Stop conditions

Per qx CLAUDE.md: skill stops at the merge gate after `/phx:review`
PASS. Implementation phase is ~220 lines of lib code + ~200 lines
of tests; **parallel merge-gate review with two agents
(elixir-reviewer + testing-reviewer)** is appropriate. No
security-analyzer or iron-law-judge needed (no auth surface, no
defn, no atom interning).
