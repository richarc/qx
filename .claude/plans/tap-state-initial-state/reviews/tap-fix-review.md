# Review: fix/tap-state-initial-state (68e7ffd)

**Verdict: PASS WITH WARNINGS**
**Date:** 2026-07-03
**Agents:** elixir-reviewer, testing-reviewer, iron-law-judge, requirements-verifier (parallel)

## Requirements Coverage

Source: ROADMAP.md v0.10 tap-fix item. **All 5 elements MET.**

- Taps execute the circuit-so-far (`lib/qx/operations.ex:872`, `:927` via
  `Simulation.get_state/1` / `get_probabilities/1`) — MET
- Docs now truthful; `## Raises` sections added for the
  `Qx.MeasurementError` contract — MET
- CHANGELOG `### Fixed` entry under `[Unreleased]` — MET
- Tests cover evolved-state tap, pass-through, and raise path — MET
- Scope stayed narrow (no stepper content touched) — MET

ROADMAP checkbox intentionally unticked on the branch; it flips in the
squash-merge commit per CLAUDE.md.

## Warnings (2)

1. **[testing] `c_if`-only raise branch untested.**
   `Simulation.get_state/2` raises on `has_measurements?/1` OR
   `has_conditionals?/1` (`simulation.ex:220`); both raise tests use
   `measure/3` only. A circuit with `c_if` and no `measure` exercises the
   second predicate. Cheap test to add.
2. **[iron-law #6] Version not yet bumped.** Behaviour change + new raise
   path on a declared-public module; `mix.exs` still 0.9.0. Judged
   non-blocking: pre-1.0, the prior behaviour was an undisputed bug
   contradicting its own docs, and the CHANGELOG documents the change.
   Satisfy at release prep (0.9.1 patch or roll into 0.10.0).

## Suggestions (3, non-gating)

- Multi-gate prefix test (prove full prefix executes, not just the first
  instruction).
- Pin the raise-message contract with
  `assert_raise Qx.MeasurementError, msg, fn` (docs claim parity with
  `Simulation.get_state/2`).
- Pass-through assertions (`tapped == circuit`) are trivially true; keep as
  contract pins or drop. (Demoted from testing-reviewer WARNING: harmless.)

## Pre-existing (out of scope)

- `tap_circuit/2` untested (unaffected by this bug).
- `Qx.Qubit.tap_state/2` (`qubit.ex:765`) is a differently-shaped calc-mode
  function; does not share the bug pattern. No action.

## Per-agent verdicts

- elixir-reviewer: Approved, 0 findings. Delegation confirmed correct
  against `quantum_circuit.ex:198-200`.
- testing-reviewer: clean on Iron Laws; 2 warnings (1 kept, 1 demoted).
- iron-law-judge: #5 PASS, #7 PASS, #8 PASS, #6 WARNING (above).
- requirements-verifier: all MET.
