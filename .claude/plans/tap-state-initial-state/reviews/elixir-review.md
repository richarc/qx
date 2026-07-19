# Elixir Review: fix/tap-state-initial-state (68e7ffd)

## Summary
- **Status**: ✅ Approved
- **Issues Found**: 0 blockers, 0 warnings, 2 suggestions

## Critical Issues
None.

## Warnings
None.

## Suggestions

1. **lib/qx/operations.ex:871-875, 925-930**: `tap_state/2` and
   `tap_probabilities/2` now call `Simulation.get_state/1` /
   `get_probabilities/1` (default `options \\ []`), correctly replacing
   the old `QuantumCircuit.get_state/1` call that only read the struct's
   stored `circuit.state` field (confirmed at
   `lib/qx/quantum_circuit.ex:198-200`, `circuit.state` — no execution).
   The delegation is correct: `Qx.Simulation.get_state/2` /
   `get_probabilities/2` execute the circuit via `execute_circuit/2` and
   raise `Qx.MeasurementError` on measurements/conditionals, matching
   the new `## Raises` doc sections and the test file's assertions
   (`test/qx/operations_tap_test.exs:32-41`, `:70-79`). No functional
   issue — this is a correctness confirmation, not a finding.

2. **lib/qx/operations.ex:842-858, 890-913**: The `## Examples` blocks
   predate this fix and were not updated with a "before instructions
   ran, this used to be wrong" callout — acceptable since they were
   already showing the *intended* post-fix behavior (e.g. `Probabilities:
   [0.5, 0.5, 0.0, 0.0]` after an H gate), and the module isn't
   doctested (`grep` found no `doctest Qx.Operations` in `test/`), so
   the placeholder `#Nx.Tensor<...>` / `%Qx.QuantumCircuit{...}` outputs
   are never executed and can't drift. No action needed, noting only
   for completeness.

3. **Pre-existing, out of scope**: `Qx.Qubit.tap_state/2`
   (`lib/qx/qubit.ex:765`) has a different signature (`opts` keyword,
   not a `fun`) and calls `show_state/1` internally — it does not share
   the `QuantumCircuit.get_state/1` bug pattern this PR fixes, and
   `Qx.Register` has no `tap_state`/`tap_probabilities` at all. One-line
   mention only, no action required in this PR.

## Test Coverage

`test/qx/operations_tap_test.exs` is new and covers: correct
post-instruction state (not initial state) for `tap_state/2`,
pass-through of the circuit unchanged for both taps, and
`Qx.MeasurementError` raised when a measurement precedes the tap — all
three claims made in the new `## Raises` docs. Tolerance
(`1.0e-6`) is correctly justified against `:c64` float32 epsilon per
Iron Law #8. Good coverage; no gaps found.
