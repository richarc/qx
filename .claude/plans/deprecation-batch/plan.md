# Deprecation batch — open the v0.11 window (T1-04/06/08/14, R-02, B-01/05/06/07)

**Branch:** `feat/deprecation-batch`
**ROADMAP:** v0.11 "API Review Follow-Through" — the "Deprecation batch" item.
Ticks that checkbox on merge.
**Depth:** comprehensive · **Complexity:** 8 (5 distinct deprecations across
`Qx`/`Operations`/`Patterns`/`QuantumCircuit`/`Draw` +3, changes declared-public
surface +3, 2 new fns + 1 range-overload +2, follows the `@deprecated` pattern
−2). No new dep.

## Decision (user-confirmed 2026-07-12) — all 5 in ONE branch

Deprecations are **non-breaking** (functions keep working; removals at 1.0). No
version bump. Established pattern: `@deprecated "Use … . Will be removed in Qx
1.0"` on whole functions.

| # | Deprecate | Replacement | Mechanism |
|---|---|---|---|
| 1 | `Patterns.barrier_all/2` (+ `Qx.barrier_all/2`) | `Qx.barrier/2` — now accepts list OR range | `@deprecated` + ADD range support to `barrier/2` |
| 2 | `Qx.superposition/1` (+ `Patterns.superposition_circuit/1`) | `Qx.create_circuit(n) \|> Qx.h_all()` | `@deprecated` |
| 3 | `QuantumCircuit.get_state/1` | `QuantumCircuit.initial_state/1` (NEW; `Qx.get_state/1` runs the circuit; `reset/1`/`depth/1` exist) | `@deprecated` + ADD `initial_state/1` |
| 4 | `run/2` integer-shots overload (`run(qc, 1000)`) | `run(qc, shots: 1000)` | **soft** — `@doc` note only, NO warning (heavily used in README + qxportal tutorials; can't `@deprecated` one clause) |
| 5 | `draw_state`/`state_table` **Register** input | circuit mode (`run`/`get_state`/`steps`) | **runtime `IO.warn`** on Register input + tighten `@spec` |

**Deprecation-mechanics risk (verify each phase):** `@deprecated` warns at CALL
sites during compile. A `defdelegate`/internal call to a freshly-deprecated fn
can break `mix compile --warnings-as-errors`. Mitigate: deprecate at the level
users call, and make any internal caller (facade `defdelegate`, or a creator that
composes the deprecated fn) NOT hit the deprecated arity — e.g. keep the impl
un-deprecated and deprecate only the facade, OR point the facade at a fresh
private helper. Empirically confirm `--warnings-as-errors` stays green after each.

---

## Phase 1 — `barrier/2` range support + deprecate `barrier_all/2`

- [x] [P1-T1] **Tests first**: `barrier(new(4), 0..2)` → `[{:barrier,[0,1,2],[]}]`
      (range accepted, byte-identical to the list form); existing `barrier/2`
      list tests unchanged. Run — range case FAILS (list-only guard).
- [x] [P1-T2] Add a `Range` clause to `Operations.barrier/2` (normalise via
      `Enum.to_list/1`, then the existing validate + `add_barrier`). Keep the
      list clause. Compile clean; tests pass.
- [x] [P1-T3] `@deprecated "Use `Qx.barrier/2`, which now accepts a list or
      range. Will be removed in Qx 1.0"` on `Patterns.barrier_all/2` and the
      `Qx.barrier_all/2` facade. Verify `--warnings-as-errors` (no internal
      caller hits `barrier_all/2`). Keep `barrier_all/1`. CHANGELOG Deprecated.

## Phase 2 — deprecate `superposition/1`

- [x] [P2-T1] `@deprecated "Use `Qx.create_circuit(n) |> Qx.h_all()`. Will be
      removed in Qx 1.0"` on `Qx.superposition/1` (facade) and
      `Patterns.superposition_circuit/1`. Structure so the facade doesn't
      self-warn at compile (deprecate the facade `def`, keep impl reachable
      without a deprecated call — verify `--warnings-as-errors`).
- [x] [P2-T2] Confirm the EXISTING `qx_test.exs` superposition test still passes
      (deprecated fn still works; a deprecation warning at test-compile is
      acceptable — do NOT modify the test). CHANGELOG Deprecated.

## Phase 3 — `QuantumCircuit.initial_state/1` + deprecate `get_state/1`

- [x] [P3-T1] **Tests first** (`quantum_circuit_*` test or new): `initial_state(
      new(1)) == get_state(new(1))` (both return `circuit.state`), shape `{2}`.
      Run — FAILS (`initial_state/1` undefined).
- [x] [P3-T2] Add `QuantumCircuit.initial_state/1` (returns `circuit.state`,
      well-named) with `@spec` + `@doc` + doctest. `@deprecated "Use
      `initial_state/1` (this returns the circuit's INITIAL state, not a run
      result; `Qx.get_state/1` runs the circuit). Will be removed in Qx 1.0"` on
      `QuantumCircuit.get_state/1`. Verify no lib/ caller of
      `QuantumCircuit.get_state/1` (grep) breaks `--warnings-as-errors`.
      CHANGELOG Deprecated + Added.

## Phase 4 — `run/2` integer-shots soft-deprecate (doc-only)

- [x] [P4-T1] Update `Qx.run/2` `@doc`: mark the integer-shots form as
      discouraged, steer to `run(circuit, shots: n)`; keep BOTH clauses working.
      NO `@deprecated`, NO `IO.warn` — zero churn. Note in CHANGELOG under
      Deprecated as a *soft* (documentation-only) deprecation, explicitly "still
      supported; no warning."

## Phase 5 — `draw_state` Register input runtime-warn

- [x] [P5-T1] **Tests first**: passing a tensor to `Qx.draw_state/1` still works
      silently; passing a `Qx.Register` emits a deprecation `IO.warn` (assert via
      `ExUnit.CaptureIO.capture_io(:stderr, fn -> … end) =~ "deprecated"`) and
      still returns the table. Run — Register-warn case FAILS.
- [x] [P5-T2] In `Qx.Draw.Tables.render/2` (or `state_table/2`), add an
      `is_struct(register_or_state, Qx.Register)` branch that `IO.warn`s
      (pointing to circuit mode) then proceeds. Tighten the `state_table/2`
      `@spec`/`@doc` to the tensor path (note Register deprecated). CHANGELOG
      Deprecated.

## Phase 6 — verify

- [x] [P6-T1] Full gate: `mix compile --warnings-as-errors && mix format
      --check-formatted && mix credo --strict && mix test`. Pay special
      attention to `--warnings-as-errors` (the deprecation-self-warn risk).
- [x] [P6-T2] `mix docs` warning count ≤ baseline (36); the new `@deprecated`
      tags render a "deprecated" badge (not a warning) — confirm count holds.
- [x] [P6-T3] CHANGELOG `[Unreleased]` → append all 5 to the existing
      **Deprecated** section (window opens this minor, removals at 1.0). No
      version bump.

## Iron Laws check

- **#6 (public API):** deprecations are NON-breaking (fns still work); each has a
  CHANGELOG Deprecated entry; no version bump. New `initial_state/1` +
  `barrier/2` range are additive. `get_state/1` etc. keep working until 1.0.
- **#7 (typed errors):** unchanged. `barrier/2` range still routes through
  `validate_qubit_indices!`; the Register `IO.warn` is a warning, not an error.
- **#9:** no new instruction shape.

## Risks

1. **`--warnings-as-errors` from deprecation self-warns** (facade `defdelegate`
   or a creator composing a deprecated fn). Mitigation: grep every deprecated
   fn's callers in `lib/` before deprecating; deprecate at the user-facing level;
   re-run the gate per phase. This is the #1 thing to watch.
2. **Existing tests calling deprecated fns** (`qx_test.exs` superposition,
   any get_state test) emit deprecation warnings at test-compile — acceptable,
   do NOT modify the tests (TDD rule 2). Only `lib/` compiles under
   `--warnings-as-errors`; test-compile warnings don't fail `mix test`.
3. **Register detection** — `Qx.Register` is `is_struct`-detectable; ensure the
   tensor path is completely unaffected (silent).

## Self-check

- *What could break?* Only `--warnings-as-errors` via self-warns (Risk 1) —
  caught per-phase.
- *Public surface?* All changes non-breaking (deprecate + add). No removals.
- *Deferred?* Nothing — this closes the "Deprecation batch" item. (run/2 removal
  and draw_state Register removal are 1.0 decisions.)
