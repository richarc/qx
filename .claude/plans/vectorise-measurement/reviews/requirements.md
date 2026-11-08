## Requirements Coverage (from plan file .claude/plans/vectorise-measurement/plan.md)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| G1 | Mid-circuit measurement: {p0,p1} with Nx, one sync; static-slice collapse | MET | `lib/qx/simulation.ex:717-726`; `calc_fast.ex:216-226,306-331`; no `Nx.to_number(state[` left (static guard test `simulation_measurement_test.exs:180`) |
| G2 | run/2 sampling O(2^n + shots·n): one cumsum, one sync, binary search | MET | `sampler.ex:28-33,40-47,62-71`; `simulation.ex:625` |
| S1 | CalcFast `qubit_probabilities/3` (f64, one sync) and `collapse/5` (in_axes/halves); Calc delegators | MET | `calc_fast.ex:214-250,306-331`; `calc.ex:162-175` |
| S2 | New `Qx.Simulation.Sampler` (@moduledoc false), cumulative tuple, binary search with process :rand | MET | `sampler.ex:2,26-33,40-47` |
| S3 | Simulation routes to new code; old `calculate_measurement_probability/4`, `collapse_to_measurement/4`, `generate_samples/2` deleted | MET | `simulation.ex:160,617-625,717-726`; grep finds none of the old names |
| S4 | Bench: sample n=8/12/16 x 1024/100k; c_if n=4/8/12 x 256; steps n=12/14; alias entry | MET | `bench/measurement_bench.exs:29-63`; `mix.exs` `@bench_suites` adds `measurement` |
| D1 | Host binary search over cumulative tuple, process :rand | MET | `sampler.ex:40-47` (`:rand.uniform()`) |
| D2 | First i with draw <= cum[i]; f64 Nx cumsum; test vs old linear algorithm on fixed seed | MET | `sampler.ex:62-71`, `:56-58`; `simulation_sampler_test.exs:48-67` |
| D3 | Fallback is last p>0 index; crafted test; CHANGELOG Fixed | MET (deviation OK) | Clamp `min(draw,total)` at `sampler.ex:44`; test `simulation_sampler_test.exs:82-103`; CHANGELOG "Fixed" entry. Clamp maps an overflow draw to the first index reaching total, which is the last p>0 index. Intent is satisfied. Residual: draw exactly 0.0 with p[0]=0 returns 0 (pre-existing, ~2^-53, documented in scratchpad) |
| D4 | {p0,p1} accumulate in f64 via sum(axes) | MET | `calc_fast.ex:307-312` |
| D5 | Collapse via static slices, zero + scaled; host norm factor; c64; p>0 guard | MET (minor deviation) | `calc_fast.ex:317-330`; `simulation.ex:723`. Uses `Nx.broadcast` zeros instead of `zeros_like(off_slice)`; same result. Norm factor is passed as an f64 tensor; scaling is done in c128 and cast back to c64 |
| D6 | No public API change | MET | The diff touches only `CalcFast`/`Calc` (tier 3), `Sampler`, and private Simulation functions. `Qx.Calc` gained two delegators, as the plan allows |
| R1 | One :rand call per shot / per measurement | MET | `sampler.ex:44`; `simulation.ex:721`; seeded-trajectory tests |
| P0-T1 | Add measurement scenarios, wire into `mix bench` | MET | `bench/measurement_bench.exs`; `mix.exs` |
| P0-T2 | Baseline run -> `research/baseline/measurement.txt` with commit hash | MET | `research/baseline/measurement.txt:1` ("commit: 2bf4b78"); the commit exists in the git log |
| P1-T1 | CalcFast measurement tests (oracle, n=1,3,5, errors) | MET | `calc_fast_measurement_test.exs:41-125` |
| P1-T2 | Sampler equals old linear algorithm; 1 draw/shot; D3 fallback | MET | `simulation_sampler_test.exs:48-111` |
| P1-T3 | Seeded steps/2 trajectory vs reference (teleportation + GHZ-5) | MET | `simulation_measurement_test.exs:109-126` |
| P1-T4 | run/2 statistical checks (Bell, GHZ-4, RY) + c_if teleportation | MET | `simulation_measurement_test.exs:128-178` |
| P1-T5 | Static guard on simulation.ex | MET | `simulation_measurement_test.exs:180` |
| P1-T6 | Confirm red before Phase 2 | UNCLEAR | Process step, not verifiable from the diff; scratchpad/plan claim it was done |
| P2-T1 | `qubit_probabilities/3` with validation, defn, f64, one sync | MET | `calc_fast.ex:216-226,255-258,306-313` |
| P2-T2 | `collapse/5` defn on in_axes/halves, c64 | MET | `calc_fast.ex:237-250,260-263,317-331` |
| P2-T3 | Calc delegators; existing tests untouched | MET | `calc.ex:162-175`; test diff is 3 new files only (+429 lines, no modifications) |
| P3-T1 | Sampler `cumulative/1` and `sample/2` | MET | `sampler.ex:26-33,40-47` |
| P3-T2 | perform_measurements -> Sampler; delete generate_samples | MET | `simulation.ex:617-625` |
| P3-T3 | perform_single_measurement -> Calc; delete old helpers; norm guard kept | MET | `simulation.ex:717-726` |
| P3-T4 | Full mix test/credo/docs green | UNCLEAR | Run results not verifiable from the diff; I did not re-run them. The plan reports 1479 passed |
| P4-T1 | Re-run benches -> research/after/, bench-comparison.md | MET | `research/after/{measurement,ghz,kernels,single-measurement-isolated}.txt`; `research/bench-comparison.md` |
| P4-T2 | CHANGELOG Performance + Fixed entries | MET | CHANGELOG `[Unreleased]` diff (Performance x3 bullets, Fixed bullet) |
| P4-T3 | ROADMAP both items ticked | MET | ROADMAP.md diff shows both `[ ]` -> `[x]` |
| P4-T4 | /phx:review | Open (expected) | n/a |

Out-of-scope check: no `seed:` option on run/2 and no run_with_conditionals changes were found in the diff.

**Summary**: 29 MET · 0 PARTIAL · 0 UNMET · 2 UNCLEAR (P1-T6, P3-T4: process claims) · 1 open as expected (P4-T4)
