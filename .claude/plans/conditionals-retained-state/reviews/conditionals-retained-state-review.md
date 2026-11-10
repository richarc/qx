# Review: Cap retained state in `run_with_conditionals`

**Branch:** `fix/conditionals-retained-state` (uncommitted, base `main`)
**Date:** 2026-11-10
**Agents:** elixir-reviewer, testing-reviewer, iron-law-judge, requirements-verifier
(verification-runner skipped: `/phx:work` ran the full gates this session)
**Verdict: PASS WITH WARNINGS** — 0 blockers, 2 warnings (both in the new test file), 5 suggestions.

## Requirements Coverage

Source: plan `.claude/plans/conditionals-retained-state/plan.md`.
**14 MET · 2 PARTIAL · 0 UNMET · 2 UNCLEAR.** Nothing out of scope was changed.

The PARTIAL and UNCLEAR items are limits of what the verifier could check
without altering the tree, not gaps in the work:

| Item | Verifier | Evidence from the `/phx:work` session |
|---|---|---|
| 1.1 result tests pass on old code | PARTIAL | Run on old code before the fix: 4 passed, 1 (memory) failed |
| 1.3 memory test red on old code | UNCLEAR | Re-run at n=12 with the fix stashed: 6,636,528 B, failed |
| 2.2 five runs, margin | PARTIAL | 5 of 5 passed; verifier's own 3 reruns passed |
| 2.3 compile / format / credo | UNCLEAR | All three run clean after the fix; format re-checked during review |

Verifier also noted: the deterministic test compares `abs(state)`, not the full
complex state.

## Warnings

**W1 — Shot order is not pinned** (testing-reviewer)
`test/qx/simulation_conditionals_retention_test.exs:51-73`, guarding
`lib/qx/simulation.ex:184` (`Enum.reverse`).
The deterministic test's rows are all `[1, 1]`, and the probabilistic outcomes
are symmetric. If `Enum.reverse` were dropped, only the "last shot" test could
notice, and only when the first and last shots differ: about half the runs.
Suggested fix: repeat the last-shot check 20–30 times in one test (cheap at n=2).
Root cause is pre-existing: `seed_rand(nil)` per shot means order cannot be
pinned deterministically.

**W2 — No guard against a vacuous memory pass** (testing-reviewer)
`test/qx/simulation_conditionals_retention_test.exs:88-95`.
If the poller never samples, or `Process.info/2` returns `nil` (mapped to 0),
or a later refactor moves shots into other processes, `peak_bytes` is 0 and the
test passes on code that retains everything. Not vacuous today (old code
measured red). Suggested fix: add a floor, e.g. `assert peak_bytes > 2^n * 8`
(32 KB; recorded fixed peaks are 300–745 KB).

## Demoted

- **Memory-test flake risk** (iron-law-judge, WARNING → note). The testing
  reviewer analysed it and found the peak depends on bytes allocated between
  GCs, not wall-clock time; threshold is 4.4× above the worst recorded fixed
  peak (745 KB, identical in 6 cold VMs) and 2× below the old code.

## Suggestions

1. Test comment at line 16 cites `.claude/plans/.../research/`, which will rot
   (elixir-reviewer and testing-reviewer). Keep the fact, drop the path.
2. CHANGELOG: "independent of `shots`" slightly overclaims, since the classical
   bits list still grows with shots. "No longer grows with the statevector per
   shot" or similar (elixir-reviewer).
3. Cover `renormalize: true` on the conditional path (`simulation.ex:193`)
   (testing-reviewer).
4. Compare the full complex state, not `abs(state)`, in the deterministic test
   (requirements-verifier).
5. Optional: `@tag timeout:` on the memory test (testing-reviewer).

Not adopted as findings: `//1` on the range is redundant after
`validate_shots!` (harmless, kept as defence); loosening `1.0e-6` to `1.0e-5`
(the values compared are exact 0 and 1; iron-law-judge rated #8 compliant).

## What passed

- **Equivalence** (elixir-reviewer): new loop matches the old code for shot
  order, counts, last-shot state, single renorm, and `shots = 1`. The `nil`
  initial accumulator cannot reach `maybe_measurement_renorm/2` because
  `run/2` validates `shots >= 1` and is the only caller.
- **Non-retention** (elixir-reviewer): no other path keeps per-shot states.
- **Iron Laws** (iron-law-judge): #2, #5, #6, #7, #8 compliant; #1, #3, #4, #9
  not applicable. Private function only; no version bump needed. TDD sequence
  plausible; no existing test modified.
- **Verification:** 1490 passed (328 doctests, 1162 tests), run by `/phx:work`
  and again by the requirements-verifier; compile, format, credo clean.

## Pre-existing

- `lib/qx/simulation.ex:679` — per-shot `seed_rand(nil)`; conditional runs are
  not reproducible (already in the scratchpad as out of scope).
