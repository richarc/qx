# Qx — Test Health Audit

Date: 2026-06-14
Scope: `test/**/*.exs`, `test/support/`, `spec/`, `coveralls.json`, `cover/`.

## Headline numbers

| Metric | Value |
|---|---|
| Overall line coverage (excoveralls, fresh `mix coveralls`) | **81.4 %** (target 80 %) |
| Test files | 46 (`.exs`) |
| Tests / doctests | **851 tests + 243 doctests** |
| Failures | 0 |
| Suite runtime | **0.9 s** (0.6 s async, 0.3 s sync) — well under the 30 s flag |
| Compile warning | 1 (`Qx.Math.basis_state/2` deprecation, see L1 below) |
| `excoveralls` `minimum_coverage` gate | 80 % (passes) |
| `coveralls.json` `_comment` | Out of date — says "66.4 %", actual is 81.4 % |
| `spec/` directory | 25 markdown design docs — **NOT** wired into `mix test`; no `.ex`/`.exs` inside. No `test_paths` override in `mix.exs`. |
| ExUnit `async: true` files / total | 28 / 46 (~61 %) |

### Bottom 5 modules by coverage

| % | File |
|---:|---|
| 0.0 % | `lib/qx/draw/svg/charts.ex` (72/72 lines uncovered) |
| 0.0 % | `lib/qx/simulation_result.ex` (9/9) |
| 0.0 % | `lib/qx/export/openqasm/ast.ex` (0 relevant lines — header only) |
| 0.0 % | `lib/qx/behaviours/quantum_state.ex` (0 relevant — behaviour) |
| 61.5 % | `lib/qx/draw/svg/circuit.ex` (115/299 uncovered) |
| 63.3 % | `lib/qx/export/openqasm/codegen.ex` (22/60 uncovered) |
| 65.2 % | `lib/qx/errors.ex` (24/69 uncovered) |

(`ast.ex` and `quantum_state.ex` have 0 relevant lines so they are not real
coverage holes — they are listed only because excoveralls prints them at 0 %.)

---

## Findings

### Numerical tolerances (Iron Law — `:c64` ≈ float32, ε ≈ 1.2e-7)

| Sev | File:line | Problem | Fix |
|---|---|---|---|
| **CRIT** | `test/qx/cswap_iswap_matrix_test.exs:33` | `@delta 1.0e-12` is asserted entrywise against `:c64` matrices returned by `Qx.Gates.cswap/4` and `Qx.Gates.iswap/3` (Iron Law forbids sub-`1.0e-6` tolerance on `:c64`). Currently passes only because every entry is an exact 0/1/±i representable in float32 — but the *stated* tolerance is unreachable and a future non-integer matrix will silently fail. | Raise `@delta` to `1.0e-6`, or assert via `Qx.Validation` / `Nx.all_close` with a `:c64`-realistic atol. Add a doc comment that exact-integer matrices are why a tighter check would *coincidentally* pass. |
| **CRIT** | `test/qx/export/openqasm/round_trip_test.exs:8` | `@tolerance 1.0e-10` used to compare two simulated `:c64` statevectors (`Nx.subtract → Nx.abs → Nx.reduce_max`). Sub-epsilon on `:c64` — Iron Law violation. Passes today because the fixture circuits (Bell, GHZ3, QFT3, Grover2) happen to round to floats representable exactly *after* normalisation; a richer fixture would flake. | Set `@tolerance` to `1.0e-6` (or `5.0e-7`) consistent with the `Qx.Math.normalize/1` guard. |
| HIGH | `test/qx/u_gate_convention_test.exs:24` | `@delta 1.0e-6` used to compare `:c64` unitary entries up-to-phase. At the **floor** of `:c64` ε≈1.2e-7; one accumulated FMA could trip it. | Loosen to `5.0e-6` or `1.0e-5`. Document the chosen value. |
| LOW | `test/qx/math_test.exs:110-120` | Loose tolerance `0.01` used for an inner-product check that should be `1.0e-5` (single-gate, single-shot — no statistical noise). Two tests: `< 0.01` against `0.9998` and `< 0.01` against `0.0`. Hides regressions of ≥ 1 % per amplitude. | Tighten to `1.0e-5` (or `1.0e-6`) — matches the rest of `math_test.exs`. |
| LOW | `test/qx_test.exs:60-165` | Eleven `< 0.01` checks for single-circuit deterministic amplitudes (no shot sampling). Same hiding-power as above. | Tighten to `1.0e-5`. |

Notes on tight tolerances that are **fine**:
- `cp_gate_test.exs:11`, `u_gate_test.exs:11-13`, `operations_controlled_rotations_test.exs:61`, `export/openqasm/parser_test.exs`, `export/openqasm/lowering_test.exs`, `export/openqasm/expr_test.exs` — all use `1.0e-10` / `1.0e-12` on raw Elixir float64 instruction-list parameters (e.g. `theta` stored in `{:cp, _, [theta]}`). These are *not* `:c64` values; the Iron Law does not apply.

### Determinism / HTTP mocking

| Sev | File:line | Problem | Fix |
|---|---|---|---|
| OK | `test/qx/hardware/ibm_test.exs`, `test/qx/hardware/portal_test.exs` | All IBM Quantum and qxportal HTTP traffic is stubbed with `Bypass`. `Bypass.down(bypass)` is used for network-failure paths. No test reads `IBM_QUANTUM_TOKEN`, `IBM_API_KEY`, or any other secret env var. | — |
| OK | `test/support/stub_ibm.ex` | Lightweight in-memory recorder (no Mox) used by `hardware_test.exs` to drive the pipeline against scripted responses. Calls/responses are per-test via an `Agent` started in `setup`. | — |
| LOW | `test/qx/hardware/ibm_test.exs:7` | `use ExUnit.Case, async: true` while two Bypass instances bind ephemeral ports per test — this is fine in practice (each `Bypass.open()` gets its own port), but the file mixes IAM + API bypasses; if a future test forgets to start `iam`, an unrelated async test holding the same port number is a theoretical (very unlikely) flake source. | Note only. |

### Async hygiene

| Sev | File:line | Problem | Fix |
|---|---|---|---|
| OK | `test/qx/hardware/config_from_env_test.exs:7` | Uses `async: false` because it mutates `System.put_env`/`delete_env` — correct. Restores state in `after`. | — |
| MED | 16 files use `use ExUnit.Case` (default sync) with no shared state | Files: `qx_test.exs`, `complex_support_test.exs`, `cp_gate_test.exs`, `qubit_test.exs`, `math_test.exs`, `format_test.exs`, `controlled_gates_test.exs`, `cswap_gate_test.exs`, `validation_test.exs`, `gates_test.exs`, `calc_test.exs`, `swap_gate_test.exs`, `iswap_gate_test.exs`, `u_gate_test.exs`, `state_init_test.exs`, `export/openqasm_test.exs`. All are pure computational — no env vars, no `:ets`, no `:persistent_term`, no Application config writes. Leaving them sync wastes wall-clock and inflates the 0.3 s sync bucket. | Flip to `async: true` (one-line change per file). Expected runtime drop: small in absolute terms (suite already 0.9 s) but cuts the sync bucket roughly in half. |

### Test naming

| Sev | File:line | Problem | Fix |
|---|---|---|---|
| LOW | `test/qx/simulation_renormalization_test.exs:135-143` | Tests named `"zero"`, `"float"`, `"atom"`. Inside a `describe`, this is interpretable, but the failure message will only say `test float`. | Rename to `"zero tolerance disables renormalization"`, etc. |
| LOW | `test/qx/hardware_test.exs:286` | `test "is optional"` — context-dependent but the failure log loses context. | Rename to `"opts[:portal_token] is optional"` (or similar). |
| LOW | `test/qx/state_init_test.exs:44,103,121,164,320,374` | Six tests literally named `"is normalized"` across different describes. Same outer issue. | Rename per state being tested. |
| LOW | `test/qx_test.exs:24-38` | `"apply x gate"`, `"apply cnot gate"`, `"add measurement"` — terse but acceptable; flagged for completeness. | Optional. |

No tests named `"test 1"`, `"test"`, or `"works"`. No catch-all `test "..."` placeholders.

### `setup_all` / `on_exit` / fixture mutation

| Sev | File:line | Problem | Fix |
|---|---|---|---|
| OK | `test/qx/export/openqasm/codegen_test.exs:73` | `on_exit/1` purges and deletes a dynamically `Code.compile_string`-built module. Correct — prevents module-table growth across tests. | — |
| OK | No `setup_all` mutating state anywhere in the suite. | — | — |
| OK | No tests modify other tests' fixtures (`test/fixtures/qasm/` is read-only — `bell.qasm`, `ghz3.qasm`, `grover2.qasm`, `ibm_example.qasm`, `qft3.qasm`). | — | — |

### Coverage gaps (bottom-up)

| Sev | Module | % | Suggested fix |
|---|---|---:|---|
| HIGH | `lib/qx/draw/svg/charts.ex` | 0.0 % (72 lines) | No tests at all. Add at least snapshot/golden tests for the chart SVG output; mirror the pattern in `test/qx/draw/*_svg_test.exs`. |
| HIGH | `lib/qx/simulation_result.ex` | 0.0 % (9 lines) | Small module — add one constructor / one accessor test. |
| MED | `lib/qx/draw/svg/circuit.ex` | 61.5 % (115 lines uncovered) | Already has `circuit_test.exs`; the uncovered lines are likely error/fallback branches. Identify with `mix coveralls.detail --filter draw/svg/circuit`. |
| MED | `lib/qx/export/openqasm/codegen.ex` | 63.3 % (22 lines uncovered) | Add a failure-path test (unsupported modifier already covered — check else-branches around custom gate emission). |
| MED | `lib/qx/errors.ex` | 65.2 % (24 lines uncovered) | Add one test per untested `Qx.*Error` `message/1` clause. Cheap. |
| LOW | `coveralls.json:16` `_comment` | Stale — says coverage is 66.4 %, actually 81.4 %. | Update comment or remove. |

### Spec / executable specs

| Sev | File:line | Problem | Fix |
|---|---|---|---|
| INFO | `spec/` | 25 `.md` design / summary docs, **no executable code**. Not part of `mix test` and `mix.exs` does not override `test_paths`. Calling these "executable specs" in the audit brief is a misnomer — they are design notes. | If executable specs are desired, add an `mix.exs` `test_paths: ["test", "spec"]` override and put `.exs` files there. Otherwise note in `spec/README` that the directory is design-docs-only. |
| LOW | `spec/` | Many docs (e.g. `BACKEND_DETECTION_FIX.md`, `EMLX_MIGRATION_SUMMARY.md`, `*_SUMMARY.md`) read like commit-message archaeology. | Consider trimming once captured by `/phx:compound`. Out of scope for this audit. |

### Other

| Sev | File:line | Problem | Fix |
|---|---|---|---|
| L1 | `test/qx/math_test.exs:303,311,319` | Three tests call deprecated `Qx.Math.basis_state/2` (use `Qx.StateInit.basis_state/3`). Produces compile warning on every `mix test`. Will become an error if `--warnings-as-errors` is added to the test alias. | Migrate the three tests to `Qx.StateInit.basis_state/3` and delete the deprecation paths or @doc-tag them as deprecation-only tests. |
| OK | `mix test --max-failures 1 --warnings-as-errors` | Not run (the deprecation warning above would fail it). The plain `mix coveralls` run reports 0 failures. | After fixing L1, the `--warnings-as-errors` gate should be added to the verify pipeline. |

---

## Test health score: **84 / 100**

| Dimension | Weight | Earned | Reasoning |
|---|---:|---:|---|
| Coverage breadth | 30 | 26 | 81.4 % is over the 80 % gate; two whole modules at 0 % (`charts.ex`, `simulation_result.ex`) and three more under 70 % (`circuit.ex`, `codegen.ex`, `errors.ex`) cost 4 points. |
| No Iron-Law-violating tolerances | 20 | 12 | Two CRIT and one HIGH `:c64` sub-epsilon tolerance (`cswap_iswap_matrix_test.exs`, `round_trip_test.exs`, `u_gate_convention_test.exs`) — currently passing by luck of integer/exact-representable amplitudes. Worth a -8. |
| Determinism / no live network | 15 | 15 | Bypass + StubIbm cover the whole HTTP surface. No `IBM_QUANTUM_TOKEN` reads. `System.put_env` is isolated to one correctly-`async: false` test. |
| Async hygiene | 10 | 7 | 16 pure-computational files left at default sync without justification (-3). The async/sync split is otherwise correct. |
| Test naming quality | 5 | 4 | No `"test 1"` / `"works"`. A handful of low-context names (`"zero"`, `"is normalized"`) inside good describes. |
| Suite runtime | 10 | 10 | 0.9 s for 851 tests + 243 doctests — excellent. |
| `spec/` integration | 10 | 10 | `spec/` is design-docs only, not orphaned executable specs. `mix.exs` doesn't try to wire it in, and `mix test` doesn't choke on it. No issue. |
| **Total** | **100** | **84** | |
