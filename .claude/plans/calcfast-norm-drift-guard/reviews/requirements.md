## Requirements Coverage (from Plan calcfast-norm-drift-guard (qx-53v))

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| AC1 | Configurable `renormalize: true` option in `run/2` opts | MET | `simulation.ex:82` reads opt; `resolve_renormalize/1` at `:104–110` maps `true → :measurement`; `maybe_measurement_renorm/2` at `:277–278` applies it; test `simulation_renormalization_test.exs:73–76` asserts 80-gate circuit with `renormalize: true` stays ≤1e-6 |
| AC2 | Norm assertion available in test/dev mode | MET | `@assert_norm` module attr at `simulation.ex:21`; `assert_norm/1` at `:293–296` calls `Validation.validate_normalized!/2`; `config/test.exs:10` sets `assert_norm: true`; `config/config.exs:30` defaults to `false` |
| AC3 (amended) | 100-gate circuit with `renormalize: 10` stays ≤1e-6 AND strictly lower than `renormalize: false` (relative guarantee) | MET | `simulation_renormalization_test.exs:38–53`: first test asserts `dev(result.state) <= 1.0e-6` with `renormalize: 10`; second test proves `renormalize: false` trips the active guard (`assert_raise Qx.StateNormalizationError`). Together: renorm keeps drift ≤1e-6 while the same circuit without renorm exceeds 1e-6 — relative guarantee discharged. |
| AC4 | No perf regression on short circuits (default `:off` path within benchmark noise) | MET | `bench/renormalization_bench.exs` exists in diff; recorded results in `scratchpad.md` "Perf evidence" section: baseline 293.79 µs vs explicit `false` 293.69 µs (+0.03%, within ±7.6% noise). `:off` path indistinguishable from pre-feature baseline. |
| DC1 | `Qx.CalcFast` NOT modified | MET | `lib/qx/calc_fast.ex` absent from diff; `lib/qx/calc.ex` absent from diff; `simulation.ex` aliases only `Calc` (not `CalcFast`). |
| DC2 | Reuses `Math.normalize/1` + `Validation.validate_normalized!/2`; no new hex dep | MET | `simulation.ex:278` calls `Math.normalize/1`; `simulation.ex:294` calls `Validation.validate_normalized!/2`; `mix.exs` version 0.7.1, deps block unchanged (no new entries in diff). |
| DC3 | `:renormalize` resolves to `:off \| :measurement \| {:every, n}`; default `false`/`:off` zero-cost | MET | `resolve_renormalize/1` at `simulation.ex:104–110`; `maybe_gate_renorm/3` catch-all at `:287` returns state unchanged for `:off`/`:measurement`. |
| DC4 | Invalid `:renormalize` raises typed `Qx.OptionError` | MET | `validation.ex:333–336` raises `Qx.OptionError`; `errors.ex:8–29` defines the exception; `simulation_renormalization_test.exs:84–98` tests negative int, zero, float, atom all raise `Qx.OptionError`. |
| DC5 | Guard compile-time gated via `Application.compile_env(:qx, :assert_norm, false)` — on in `:test`, off elsewhere | MET | `simulation.ex:21` reads compile_env; `config/config.exs:30` sets `false`; `config/test.exs:10` sets `true`; `assert_norm/1` at `:293–294` is a no-op `if @assert_norm` — host sync dead code in prod. |
| DC6 | Both `execute_circuit/2` AND `execute_single_shot/2` honour `:renormalize` | MET | `execute_circuit/2` at `simulation.ex:267–272` calls `maybe_gate_renorm/3` + `assert_norm/1` per gate; `execute_single_shot/2` at `:484` calls `maybe_gate_renorm(renorm, idx) \|> assert_norm()`; conditional-path test at `simulation_renormalization_test.exs:101–117` exercises this. |
| DC7 | Additive/non-breaking: CHANGELOG `[Unreleased]`, no `mix.exs` version bump | MET | `CHANGELOG.md:8–24` has entry under `[Unreleased]` with correct description; `mix.exs:6` version remains `"0.7.1"` (unchanged from prior tag). |

**Summary**: 11 MET · 0 PARTIAL · 0 UNMET · 0 UNCLEAR

**Verdict**: All requirements and design constraints MET.
