# Consolidated Summary

**Strategy**: Index by token count (~5k input tokens); caller priorities applied in full
**Input**: 4 files (elixir.md, testing.md, iron-laws.md, requirements.md), ~5k tokens (`.requirements-input.md` ignored per instructions)
**Output**: ~2k tokens

## Key Findings

### BLOCKER
None (reported by elixir-reviewer, testing-reviewer, iron-law-judge).

### WARNING

1. **Memory test flake risk (test/qx/simulation_conditionals_retention_test.exs:76-95)**
   - Raised by: iron-law-judge (primary for this code), also related to testing-reviewer's vacuity finding below.
   - Scenario: the test polls `Process.info(pid, :binary)` about once per ms. Its margin depends on GC timing. Measured fixed-code slack is 0.3-0.75 MB against a 3.28 MB bound (4.4x). On a very slow or loaded CI box, delayed GC could push the peak over the bound. Not a law violation; the test is `async: false`, so risk is low.

2. **No vacuity guard on memory test (test/qx/simulation_conditionals_retention_test.exs:88-95)**
   - Raised by: testing-reviewer.
   - Scenario: if the poller never samples, `Process.info` returns nil (runner dead, counted as 0), or a future change moves shots into other processes (e.g. `Task.async_stream`), `peak_bytes` stays 0 and the test passes on code that retains every state. Fix suggested: assert `peak_bytes > Integer.pow(2, num_qubits) * 8` (one state, 32 KB; fixed peaks are 300-745 KB), and/or a minimum sample count.

3. **Shot order not pinned (test/qx/simulation_conditionals_retention_test.exs:51-73; guards simulation.ex:181 `Enum.reverse`)**
   - Raised by: testing-reviewer.
   - Scenario: if `Enum.reverse` were dropped, only the "state and probabilities are those of the last shot" assertions (lines 62-73) could fail, and only about 50% of runs, because the reversed `List.last` is the first shot. The deterministic test has identical rows, and probabilistic rows are only `[0,0]`/`[1,1]`. Suggested fix: repeat the test body ~20-30 times in one test. Per-shot `seed_rand(nil)` makes shot order non-reproducible, so repetition is the practical route.

### SUGGESTION (grouped)

- **Test coverage and tolerance**
  - testing-reviewer: add a `renormalize: true` test with `shots: 5` asserting `Nx.sum(probabilities)` ~ 1 (test covers `maybe_measurement_renorm` on `last_state`, simulation.ex:193).
  - testing-reviewer: `@tolerance 1.0e-6` (test:18) is at the float32 floor; `1.0e-5` is safer and equally strict here.
  - testing-reviewer: add `@tag timeout:` (e.g. 120_000) to the memory test. Default 60 s applies; low priority.
  - testing-reviewer: memory-test residual risk depends on OTP vheap defaults (`min_bin_vheap_size`); a comment would help. No action.
  - testing-reviewer: test at line 62 `case` has no fallback (CaseClauseError instead of a clean assertion). Acceptable.
- **Comment hygiene (project convention: no plan-path or measurement provenance in code comments)**
  - elixir-reviewer (test:16) and testing-reviewer (lines 14-16, 82-85): drop the `.claude/plans/.../research/` path (will rot when the plan is archived); keep the intrinsic fact that refc binaries are invisible to heap metrics. Drop "measured 0.3-0.75 MB" (line 84).
  - elixir-reviewer (CHANGELOG.md:53-58): "independent of `shots`" overclaims; suggest "no longer grows with shots (per-shot classical bits are still kept)".
- **Style and idiom**
  - elixir-reviewer: `1..shots//1` (simulation.ex:179) step is redundant given validation but harmless; taste only.
  - elixir-reviewer: line 173 (simulation.ex) and test line 126 may exceed 98 columns; run `mix format --check-formatted`.

## Coverage-related notes (from requirements-verifier)

- Requirements verifier flags 2 PARTIAL (1.1, 2.2) and 2 UNCLEAR (1.3, 2.3b) items. Red-on-old-code and compile/format/credo checks were not re-run by the reviewer.

## Requirements Coverage

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

## Coverage

| File | Represented | Key Items |
|---|---|---|
| elixir.md | Yes | 0 BLOCKER, 0 WARNING, 3 SUGGESTION groups (see above) |
| testing.md | Yes | 0 BLOCKER, 2 WARNING, 5 SUGGESTION items |
| iron-laws.md | Yes | 0 BLOCKER, 1 WARNING |
| requirements.md | Yes | Requirements Coverage block kept verbatim |

## Multi-agent findings

- Flagged by more than one agent: memory-test timing (test:76-95) raised by iron-law-judge (flake) and testing-reviewer (vacuity, 88-95); the iron-law-judge finding is kept as primary.
- Elixir-reviewer and iron-law-judge agree that `1..shots//1` and the `shots >= 1` invariant are safe; no conflict.
- No findings were severity-changed.

## Coverage Gaps

None.
