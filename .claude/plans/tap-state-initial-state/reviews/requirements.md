## Requirements Coverage (from ROADMAP.md v0.10 tap-fix item)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Compute the prefix state properly: `tap_state/2` must reflect the circuit-so-far, not the stored initial state | MET | `lib/qx/operations.ex:865` swaps `QuantumCircuit.get_state(circuit)` → `Simulation.get_state(circuit)`; test asserts post-`h(0)` amplitudes at `test/qx/operations_tap_test.exs:10-22` |
| 2 | Same fix for `tap_probabilities/2` | MET | `lib/qx/operations.ex:926-927` swaps to `Simulation.get_probabilities(circuit)` (was `get_state` + `Qx.Math.probabilities`); test at `test/qx/operations_tap_test.exs:45-60` verifies post-`h(0)`+`cx(0,1)` Bell probabilities |
| 3 | Docs no longer contradict actual (fixed) behaviour | MET | `## Raises` sections added documenting `Qx.MeasurementError` contract at `lib/qx/operations.ex:860-865` and `lib/qx/operations.ex:915-920`; perf caveat added at `lib/qx/operations.ex:883`; existing doc examples (`h(0) |> tap_state(...)`) are now truthful given the code change |
| 4 | CHANGELOG entry for the fix | MET | `CHANGELOG.md:10-19`, `### Fixed` under `[Unreleased]`, describes prior bug, new behaviour, and the new `Qx.MeasurementError` raise contract |
| 5 | Ship ahead of stepper as small interim fix (scope boundary — stepper item untouched) | MET | Diff touches only `lib/qx/operations.ex`, its test, `CHANGELOG.md`, `ROADMAP.md`; the stepper item (`ROADMAP.md` second bullet) is unmodified in content, still `- [ ]` |

**Summary**: 5 MET · 0 PARTIAL · 0 UNMET · 0 UNCLEAR

Note: the ROADMAP checkbox for this item itself is still `- [ ]` in the diff (`ROADMAP.md` line 88) — per this repo's workflow (`qx/CLAUDE.md`), the tick happens in the squash-merge commit to `main`, not on the feature branch, so this is expected and not a coverage gap.
