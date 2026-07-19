# Plan: fix multi-qubit barrier dispatch (`fix/barrier-dispatch`)

**Slug:** barrier-dispatch
**Branch:** `fix/barrier-dispatch` (from `main` at 403db05)
**Status:** DONE (merged to main as 400391f, 2026-07-03)
**Complexity:** 2 (bug fix, single lib file + new test file, follows existing pattern)
**ROADMAP:** v0.10 barrier item (tick in the squash-merge commit)
**Discovered:** circuit-stepper review (testing-reviewer), 2026-07-03

## Summary

`{:barrier, qubits, []}` always carries the full qubit list
(`Operations.barrier/2`; `Patterns.barrier_all/1,2` and OpenQASM import
funnel into the same shape), but `Simulation.apply_instruction/3` only
special-cases `:barrier` in its 0-qubit arm — a shape no API produces.
Any barrier-carrying circuit raises `Qx.GateError: Unsupported gate:
:barrier` from `run/2`, `get_state/2`, and `steps/2`.

Fix per ROADMAP: match `:barrier` as a no-op regardless of arity in
`apply_gate_step/5` (state unchanged, gate counter NOT advanced — a
barrier is not a unitary op, so the `renormalize: n` cadence must not
count it). The stepper still emits a step for it (barriers are visible
in drawings; the step shows the unchanged state).

## Tasks

- [x] Failing tests `test/qx/barrier_dispatch_test.exs`: `run/2` on a
      Bell circuit with a mid-circuit `Qx.barrier([0, 1])` (no raise,
      correct probabilities); `barrier_all/1` circuit runs; `get_state/2`
      unaffected by a barrier; `steps/2` emits a `:gate` step whose state
      equals the previous step's; `renormalize: 1` with a barrier stays
      normalized; tolerances 1.0e-6
- [x] `lib/qx/simulation.ex`: `apply_gate_step/5` head for
      `{:barrier, _, _}` returning `{state, count}` (no renorm, no
      counter advance)
- [x] CHANGELOG `### Fixed` under `[Unreleased]`
- [x] Verify gate: compile -Werror, format, credo --strict, full test
- [x] Merge gate: `/phx:review` PASS (or triaged); squash-merge ticks
      the ROADMAP barrier item (PASS x3; merged as 400391f with the tick)
