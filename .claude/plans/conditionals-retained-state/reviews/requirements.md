## Requirements Coverage (from Plan .claude/plans/conditionals-retained-state/plan.md)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| G1 | `run/2` with `c_if` holds one 2^n state at a time, not one per shot | MET | `lib/qx/simulation.ex:174-185` reduce replaces the carried state each shot; memory test `test/qx/simulation_conditionals_retention_test.exs:77-95` passes (3 reruns) |
| G2 | Results unchanged (classical_bits order, counts, last-shot state after renorm, probabilities, shots) | MET | `simulation.ex:181,185-195` (reverse once, frequencies_by, `maybe_measurement_renorm(last_state)`); characterisation tests `test:29-74` pass |
| S-In1 | Only `run_with_conditionals/3` changed in simulation.ex | MET | `git diff main` shows a single hunk at `simulation.ex:172-195` |
| S-In2 | One new test file (memory regression + characterisation) | MET | `test/qx/simulation_conditionals_retention_test.exs`, untracked; no existing test modified (`git status`) |
| S-In3 | CHANGELOG Unreleased entry | MET | `CHANGELOG.md:53-58` under Fixed |
| S-Out | Out of scope untouched (per-shot rerun, timeline/real_state hoist, seed_rand/seed option, descending range) | MET | diff has no change to `execute_single_shot/2`, RNG seeding, the `run/2` signature or any other public API; `1..shots//1` is the only range change (D1) |
| D1 | Reduce carrying `{reversed_cbits, last_state}`, one `Enum.reverse`, `1..shots//1` | MET | `simulation.ex:177-181` |
| D2 | Memory metric is `Process.info(pid, :binary)`, polled, peak kept | MET | `test:110-129` (polls every 1 ms via `receive ... after 1`; plan's "separate poller/Task" is replaced by a spawn_link runner polled from the test process, which is functionally equivalent) |
| D3+amend | n=12, shots=200, threshold `shots*2^n*8/2` | MET | `test:78-79,86,92` (`div(all_states_bytes, 2)` = 3,276,800 B) |
| D4 | No new dependency | MET | no mix.exs or deps change in diff |
| 1.1 | Characterisation tests: deterministic (shots=5, exact fields), probabilistic, pass on old code | PARTIAL | tests at `test:30-73` cover all stated fields and pass on current code; "pass on old code" not verifiable without changing the tree (scratchpad claims it). Deterministic test checks `abs(state)` not full complex state (minor) |
| 1.2 | Memory test: n per D3 amendment, 200 shots, poll `:binary` per 1 ms, assert peak < threshold, private helper | MET | `test:77-95,110-129` |
| 1.3 | Red on old code (peak near 1.6 MiB; recorded in scratchpad) | UNCLEAR | cannot verify without reverting the tree; scratchpad "Implementation notes" records 1,650,808 B at n=10/200 and 6,636,528 B at n=12/200 |
| 2.1 | Shot loop rewritten per D1; counts/renorm/struct kept; comments updated | MET | `simulation.ex:175-195` |
| 2.2 | Re-measure real post-fix peak, margin >= ~1.5x, 5 runs for flakiness | PARTIAL | scratchpad records 0.30-0.75 MB (4.4x under at n=12); I ran the file 3 times, 5/5 tests passed each time. The 5x run count and the margin numbers come from the scratchpad |
| 2.3 | Full `mix test` passes | MET | I ran it: 1490 passed (328 doctests, 1162 tests) |
| 2.3b | compile --warnings-as-errors, format --check, credo --strict clean | UNCLEAR | not re-run by me; claimed in the plan only |
| 3.1 | CHANGELOG Unreleased -> Fixed entry: no per-shot statevector retention, peak independent of shots | MET | `CHANGELOG.md:53-58` |
| 3.2 | Review gate | N/A | expected unchecked |
| R | ROADMAP tick deferred to merge | N/A | expected unchecked |

**Summary**: 14 MET · 2 PARTIAL · 0 UNMET · 2 UNCLEAR (2 N/A excluded)
