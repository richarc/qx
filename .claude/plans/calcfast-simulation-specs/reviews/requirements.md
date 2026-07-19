## Requirements Coverage (from plan file `.claude/plans/calcfast-simulation-specs/plan.md`)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | P1-T1: 10 `@typep` aliases in `simulation.ex`, all named per plan, all used | MET | `simulation.ex:15-24` — all 10 present (state, renorm, gate_name, qubit, bit, instruction, measurement, cbits, counts, timeline_item); all consumed by Phase 3/4 specs in same file |
| 2 | P1-T2: `calc_fast.ex` needs no type aliases (tensors only) — skip | MET | Not in diff; plan marks as skip/done |
| 3 | P2-T1: `apply_single_qubit_gate/4` — ONE `@spec` for 2-clause group | MET | `calc_fast.ex:32-33` — single spec precedes first clause |
| 4 | P2-T2: `apply_single_qubit_gate_compiled/4` (`defn`) — `@spec` added | MET | `calc_fast.ex:44-53` |
| 5 | P2-T3: `apply_single_qubit_gate_direct/4` (`defnp`) — `@spec` added | MET | `calc_fast.ex:55-64` |
| 6 | P2-T4: `apply_cnot/4` — `@spec` added | MET | `calc_fast.ex:128-129` |
| 7 | P2-T5: `apply_cswap/5` and `apply_toffoli/5` — `@spec` each | MET | `calc_fast.ex:173-180`, `calc_fast.ex:210-217` |
| 8 | P3-T1: `run/2` — `@spec run(QuantumCircuit.t(), keyword()) :: simulation_result()` | MET | `simulation.ex:94` |
| 9 | P3-T2: `get_state/2` — `@spec get_state(QuantumCircuit.t(), keyword()) :: Nx.Tensor.t()` | MET | `simulation.ex:214` |
| 10 | P3-T3: `get_probabilities/2` — `@spec get_probabilities(QuantumCircuit.t(), keyword()) :: Nx.Tensor.t()` | MET | `simulation.ex:263` |
| 11 | P4-T1: `resolve_renormalize/1` + `to_renorm/1` (3 clauses, ONE spec) | MET | `simulation.ex:120` (resolve), `simulation.ex:128` (to_renorm, one spec for clauses at 129-131) |
| 12 | P4-T2: `run_without_conditionals/3`, `run_with_conditionals/3`, `has_measurements?/1`, `has_conditionals?/1` | MET | `simulation.ex:134`, `160`, `234`, `546` |
| 13 | P4-T3: `execute_circuit/2`, `apply_gate_step/5`, `maybe_measurement_renorm/2` (ONE spec), `maybe_gate_renorm/3` (ONE spec), `assert_norm/1`, `real_state_to_complex/1` | MET | `simulation.ex:287`, `305`, `321` (one spec for clauses 322-323), `328` (one spec for clauses 329/333), `339`, `345` |
| 14 | P4-T4: `apply_instruction/3`, `apply_single_qubit_op/5`, `apply_parameterized_single_qubit_op/5`, `apply_two_qubit_op/5`, `apply_controlled_target_op/6`, `apply_three_qubit_op/5` (3 clauses, ONE spec) | MET | `simulation.ex:360`, `384`, `399`, `432`, `462`, `484` (one spec for clauses 486/490/494) |
| 15 | P4-T5: `perform_measurements/3`, `generate_samples/2`, `extract_classical_bits/3`, `perform_single_measurement/3`, `calculate_measurement_probability/4`, `collapse_to_measurement/4` | MET | `simulation.ex:498`, `521`, `533`, `598`, `613`, `637` — note: plan allowed `[[bit()]]` over `[[bit()]] \| []`; impl uses the simpler form, which covers the empty case |
| 16 | P4-T6: `execute_single_shot/2`, `create_instruction_timeline/1`, `process_timeline_item/6`, `process_conditional/8` | MET | `simulation.ex:555`, `577`, `664`, `689` |
| 17 | @spec count matches distinct function count (31 specs for 28 defp + 3 def) | MET | `grep @spec simulation.ex` yields exactly 31 entries; `grep def simulation.ex` yields 31 distinct function heads (counting multi-clause groups once) |
| 18 | Multi-clause groups each have exactly ONE `@spec` (to_renorm, maybe_measurement_renorm, maybe_gate_renorm, apply_three_qubit_op) | MET | Confirmed: one spec per group at simulation.ex:128, 321, 328, 484; no duplicate spec for subsequent clauses |
| 19 | Scope discipline: ONLY `@spec`/`@typep` added — no logic changes | MET | Diff contains only `+  @spec ...` and `+  @typep ...` lines (plus blank structural lines); zero function-body lines modified |
| 20 | No CHANGELOG entry (additive typing, non-breaking) | MET | `CHANGELOG.md` absent from `DIFF_FILES`; not touched |
| 21 | `lib/qx/calc.ex` untouched (already fully spec'd, out of scope) | MET | `calc.ex` absent from `DIFF_FILES` |
| 22 | Verification gate: `mix compile --warnings-as-errors`, `mix format --check-formatted`, `mix credo --strict`, `mix test` (242 doctests + 916 tests, 0 failures) | UNCLEAR | Self-reported by implementer in plan checkboxes; cannot verify test execution from diff inspection alone |

**Summary**: 21 MET · 0 PARTIAL · 0 UNMET · 1 UNCLEAR
