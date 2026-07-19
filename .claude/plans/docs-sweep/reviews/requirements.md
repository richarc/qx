## Requirements Coverage (from plan file `.claude/plans/docs-sweep/plan.md`)

| # | Requirement | Status | Evidence |
|---|---|---|---|
| P1-T1 | Re-run `api_inventory.exs`; confirm 47-supported-`@spec` worklist, note StateInit drift | MET | scratchpad.md:46-58 records baseline 82/47/17/24; drift on `basis_state/2` noted |
| P1-T2 | Inventory tier-1 facade `## Returns` gaps (~55 blocks) | MET | scratchpad.md:77-88 full list w/ line numbers |
| P1-T3 | Record `mix docs` baseline (36) + confirm 0/9 tier-2 moduledocs have opener | MET | scratchpad.md:59-75, 90-92 |
| P2-T1 | `Qx.Operations` (29): add `@spec` to gate builders, angle→`number()` | MET | `lib/qx/operations.ex` has 33 `@spec` occurrences (29 new + pre-existing tap_*) |
| P2-T2 | `Qx.QuantumCircuit` (8) + `Qx.Draw` (6) + `Qx.Export.OpenQASM` (1) `@spec` added | MET | `lib/qx/quantum_circuit.ex` 9 `@spec`, `lib/qx/draw.ex` 6 `@spec`, `lib/qx/export/openqasm.ex:182` `to_qasm/2` specced |
| P2-T3 | `Qx.Math` (normalize/1, probabilities/1) + `Qx.StateInit.basis_state/3` `@spec` added | MET | `lib/qx/math.ex` 3 `@spec`; `lib/qx/state_init.ex:66` `basis_state/3` specced |
| P2-T4 | Angle-type unification: `rx`/`ry`/`rz`/`phase` facade specs `float()`→`number()` | MET | `lib/qx.ex:616,642,668,694` all `number()`; `u`/`cp`/`crx`/`cry`/`crz` already `number()` |
| P3-T1 | Add `## Returns` to all 55 facade blocks lacking one (61 total) | MET | `grep -c "## Returns" lib/qx.ex` = 61 |
| P3-T2 | Add grounded `## Raises` to 18 facade fns (cz/ccx/s/sdg/t/measure_z/barrier/c_if/draw_histogram/tap_state/tap_probabilities/`_all`×4/barrier_all/bell_state/ghz_state) | MET | `lib/qx.ex` has 48 total `## Raises` blocks (pre-existing + 18 new); spot-checked `draw_histogram` (:1424), `tap_state` (:1713), `tap_probabilities` (:1740) all cite plausible typed errors (`Qx.MissingDependencyError`, `Qx.MeasurementError`) |
| P4-T1 | Tier openers on 9 target moduledocs (plan said tier-2 opener on all 9; deviation applied per scratchpad DECISION) | MET (with flagged deviation) | 5 genuine tier-2 modules (`operations.ex:3`, `patterns.ex:3`, `simulation.ex:3`, `export/openqasm.ex:3`, `hardware.ex:3`) + `draw.ex:5` carry "Utility module" opener; 3 tier-1 structs (`quantum_circuit.ex:3`, `simulation_result.ex:3`, `step.ex:3`) carry "Tier 1" opener instead — deliberate §3-correct deviation per scratchpad.md:114-133, needs human sign-off at merge gate |
| P4-T2 | Copy tap warning to facade `tap_state`/`tap_probabilities`; lighter note for `tap_circuit` | MET | `lib/qx.ex:1698-1699` and `:1725-1726` carry "executes all instructions...use sparingly"; `tap_circuit` (:1673-1675) has accurate lighter "no simulation cost" note |
| P4-T3 | Fix openqasm doc-rot (`Qx.circuit`→`Qx.create_circuit`, `Qx.cnot`→`Qx.cx`) | MET | `grep -n "Qx.circuit(\|Qx.cnot("  lib/qx/export/openqasm.ex` returns zero matches |
| P5-T1 | CHANGELOG `[Unreleased]`: Changed (angle widening) + Documentation section | MET | `CHANGELOG.md:62-66` (Changed, angle-spec widening) and `:68-86` (Documentation, full sweep summary) |
| P5-T2 | Full gate: compile/format/credo/test pass | UNCLEAR | claimed in plan/scratchpad (P5-T2, scratchpad:148-149) but not independently re-run by this review — cannot verify from diff alone |
| P5-T3 | `mix docs` warning count = baseline (36), no stash-diff needed | UNCLEAR | claimed in scratchpad:144-147; not independently re-run |
| P5-T4 | Re-run `api_inventory.exs`: 0 supported functions missing `@spec` | MET | Cross-checked directly: all modules in worklist now show expected `@spec` counts (Operations, QuantumCircuit, Draw, Math, StateInit, OpenQASM) with no gaps found |

**Summary**: 14 MET (1 with flagged deviation, requires human sign-off) · 0 PARTIAL · 0 UNMET · 2 UNCLEAR
