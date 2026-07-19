## Requirements Coverage (from plan file `.claude/plans/stateinit-vector-deprecation/plan.md`)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Phase 1: `test/qx/state_init_vector_test.exs` created with `describe` block | MET | `test/qx/state_init_vector_test.exs:1` — file exists, `Qx.StateInitVectorTest` module with four `describe` blocks |
| 2 | Phase 1: Bell vector tests for all four variants (`:phi_plus` default, `:phi_minus`, `:psi_plus`, `:psi_minus`) | MET | `state_init_vector_test.exs:11-48` — four tests, probability assertions for each variant |
| 3 | Phase 1: GHZ vector tests for 2/3/4/5 qubits | MET | `state_init_vector_test.exs:51-78` — tests for 2, 3, 4, 5 qubits with prob assertions |
| 4 | Phase 1: Delegation equivalence asserted (`bell_state == bell_state_vector`, `ghz_state == ghz_state_vector`) with `Nx.equal/2` + `Nx.all/1` | MET | `state_init_vector_test.exs:80-96` — both delegation tests use `Nx.to_number(Nx.all(Nx.equal(a, b))) == 1` |
| 5 | Phase 1: `:c128` type param honoured on both `_vector` functions (`Nx.type/1` check) | MET | `state_init_vector_test.exs:98-106` — checks `{:c, 128}` for both `bell_state_vector` and `ghz_state_vector` (plan said `:c32`; corrected to `:c128` — see deviation note) |
| 6 | Phase 2: `bell_state_vector/2` canonical with full `@doc`, `@spec`, `@type bell_state_which`, doctests using `_vector` name | MET | `state_init.ex:229` (`@type`), `state_init.ex:231-272` (`@doc`), `state_init.ex:273` (`@spec`), doctests at lines 246-264 all call `bell_state_vector` |
| 7 | Phase 2: `ghz_state_vector/2` canonical with full `@doc`, `@spec`, doctests using `_vector` name, `num_qubits >= 2` guard preserved | MET | `state_init.ex:321-369` (`@doc`), `state_init.ex:353` (`@spec`), guard at `state_init.ex:355` (`num_qubits >= 2`), doctests at lines 330-345 call `ghz_state_vector` |
| 8 | Phase 2: Old `bell_state/2` → `@deprecated` + `@doc false` + `# Deprecated:` comment, delegates to `bell_state_vector` | MET | `state_init.ex:312-319` — comment at 312, `@deprecated` at 315, `@doc false` at 316, single-line delegator at 317-319 |
| 9 | Phase 2: Old `ghz_state/2` → `@deprecated` + `@doc false` + `# Deprecated:` comment, delegates to `ghz_state_vector`, guard preserved | MET | `state_init.ex:371-378` — comment at 371, `@deprecated` at 374, `@doc false` at 375, guard at 376, delegates at 377 |
| 10 | Phase 3: `lib/qx.ex` `bell_state/1` `## See Also` → `bell_state_vector/2` | MET | `qx.ex:1165` — `Qx.StateInit.bell_state_vector/2` |
| 11 | Phase 3: `lib/qx.ex` `ghz_state/0` `## See Also` → `ghz_state_vector/2` | MET | `qx.ex:1189` — `Qx.StateInit.ghz_state_vector/2` |
| 12 | Phase 3: `lib/qx/patterns.ex` `bell_state_circuit/1` `## See Also` → `bell_state_vector/2` | MET | `patterns.ex:319` — `Qx.StateInit.bell_state_vector/2` |
| 13 | Phase 3: `lib/qx/patterns.ex` `ghz_state_circuit/1` `## See Also` → `ghz_state_vector/2` | MET | `patterns.ex:370` — `Qx.StateInit.ghz_state_vector/2` |
| 14 | Phase 4: CHANGELOG `### Added` entry for `bell_state_vector/2` and `ghz_state_vector/2` | MET | `CHANGELOG.md:16-19` — both functions named with rationale |
| 15 | Phase 4: CHANGELOG `### Deprecated` section for `bell_state/2` and `ghz_state/2` with v0.9 removal note | MET | `CHANGELOG.md:21-26` — dedicated `### Deprecated` section, v0.9 removal stated |
| 16 | Verification: `mix compile --warnings-as-errors` clean | UNCLEAR | Reported green by the implementer; cannot verify from diff alone (gate is open/unchecked in plan) |
| 17 | Verification: `mix format --check-formatted` clean | UNCLEAR | Reported green; cannot verify from diff |
| 18 | Verification: `mix credo --strict` 0 issues | UNCLEAR | Reported green; cannot verify from diff |
| 19 | Verification: `mix test` full suite green (245 doctests, 916 tests, 0 failures) | UNCLEAR | Reported green; cannot verify from diff |

### Deviation note — `:c32` → `:c128`

The plan's Phase 1 checkpoint and Phase 2 doc-correction item both acknowledge that the type-param test was changed from `:c32` (plan text) to `:c128` (implementation), because Nx has no `:c32` type. The test (`state_init_vector_test.exs:100,104`) and the docstring (`state_init.ex:235` prose) both use `:c128` consistently. The deviation is self-consistent, technically correct, and explicitly called out in the plan's own `[x]` annotation — it is acceptable.

**Summary**: 15 MET · 0 PARTIAL · 0 UNMET · 4 UNCLEAR
