# Iron Law Review: fix/conditionals-retained-state

Verdict: 0 BLOCKER, 1 WARNING (flakiness risk, not a law violation).

## The nine laws

1. Atoms: NOT APPLICABLE. No atom creation in the diff.
2. Processes: APPLIES narrowly, COMPLIANT. The law covers library runtime processes (GenServer/Agent/Task under a supervisor), which force callers to supervise. The test's `spawn_link` (test file:112) is a test-only, link-bound, short-lived measurement harness. It is not shipped in `lib/` and nothing is left for callers to supervise. The runtime change adds no process.
3. Nx kernels (reshape/contract): NOT APPLICABLE. No `lib/qx/calc*.ex` or `defn` change.
4. `defn` correct on BinaryBackend: NOT APPLICABLE for kernels. The new test runs on the default BinaryBackend, which is the backend the plan measured.
5. No host loops over 2^n amplitudes: APPLIES, COMPLIANT. `simulation.ex:178-182` iterates `1..shots//1`, which is over shots and not amplitudes. It lowers the resident amplitude count from shots x 2^n to 2^n. `execute_single_shot/2` is unchanged. `Enum.frequencies_by` at :188 runs over shots and is unchanged. The test's `Nx.to_flat_list` is on 4-element tensors only.
6. Public API surface and tiering: APPLIES, COMPLIANT. `Qx.Simulation` is tier 2. The diff changes only a private function (`defp run_with_conditionals/3`). The signature, the `@spec`, the `SimulationResult` fields and their ordering, and the `counts` keying are unchanged. `state` and `probabilities` still come from the last shot, with `maybe_measurement_renorm` applied as before. The only observable difference is lower peak memory, so this is not breaking. The CHANGELOG entry (CHANGELOG.md:53-58) sits under `[Unreleased]` / `### Fixed` and is labelled "Internal, non-breaking". No version bump is required: it is a non-breaking fix, and the law only requires a minor bump for breaking changes. Its figures match the scratchpad measurements (6.6 MB before, under 0.8 MB after).
7. Typed errors at the public boundary: APPLIES, COMPLIANT. The call chain is `Qx.run/2` -> `Simulation.run/2` -> `validate_shots!` (simulation.ex:109), which accepts only an integer greater than 0 and otherwise raises `Qx.OptionError` (validation.ex:204-208). The validated `shots` is then passed to `run_with_conditionals`. `1..shots//1` therefore always has shots >= 1, so the empty-range / `nil` accumulator case is unreachable. If `shots` were ever 0, `last_state` would be `nil` and `maybe_measurement_renorm(nil, ...)` would raise a raw error. Validation closes that path. The old `for` comprehension also assumed at least one shot (`List.last`), so behaviour is unchanged. `Qx.run(circuit, shots)` with an integer routes through the same validation (qx.ex:1270). No leak.
8. Feasible float32 tolerances: APPLIES, COMPLIANT. The only numeric tolerance is `@tolerance 1.0e-6` (test:18), which is at the stated feasibility floor. It is used on exact 0.0/1.0 outcomes (deterministic or collapsed states), so it is comfortably reachable. The memory assertion is a byte comparison, not a float tolerance. There is no sub-epsilon target and no hand-rolled norm check.
9. Dispatch completeness: NOT APPLICABLE. No instruction shape or dispatch arm is touched. The tests do execute `c_if` through `Qx.run/2`.

## TDD rules

- Tests before implementation and red before green: plausible. The scratchpad records a red run on the old code (1,650,808 B at n=10/200 and 6,636,528 B at n=12/200, close to the all-states totals). It also records post-fix peaks. The memory test's threshold (all_states/2 = 3.28 MB) separates the two (old 6.6 MB, new under 0.8 MB). The result-field tests are characterisation tests and would pass on old code, which is acceptable for a refactor.
- Existing tests unmodified: the only test change is the new untracked `test/qx/simulation_conditionals_retention_test.exs`. `git status` lists no modified test files.
- Doctest directive: NOT APPLICABLE. No `iex>` examples were added or changed.
- Observation: the scratchpad says the test-file guard hook was inactive because of a stale path, so the new file was not hook-blocked. It is new, not an edit of an existing one, so this is fine.

## WARNING

- test/qx/simulation_conditionals_retention_test.exs:76-95 — the memory test samples `Process.info(pid, :binary)` about once per millisecond, and its margin depends on GC timing. The measured margin is large (slack 0.3-0.75 MB against a 3.28 MB bound, 4.4x), and the test is `async: false`, so the flake risk is low. It could still fail on a very slow or loaded CI box if GC is delayed. Not a law violation, just worth watching.

## PRE-EXISTING

None found in the touched region.
