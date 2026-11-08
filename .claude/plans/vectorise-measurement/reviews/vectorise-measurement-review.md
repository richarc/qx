# Review: vectorise-measurement

**Branch:** feat/vectorise-measurement (564b3a0, fd4f560) vs main
**Agents:** elixir-reviewer, testing-reviewer, iron-law-judge, requirements-verifier
(+ context-supervisor → `summaries/review-consolidated.md`)

## Verdict: REQUIRES CHANGES (2 findings to fix; both small)

## Requirements Coverage

Source: plan `.claude/plans/vectorise-measurement/plan.md`.
**29 MET · 0 PARTIAL · 0 UNMET · 2 UNCLEAR → resolved.**
- P1-T6 (red before Phase 2) and P3-T4 (1479 tests, credo, `mix docs` diff
  empty) were verified in-session.
- P4-T4 (this review) is open, as expected.
- Deviations accepted as meeting the intent:
  - D3 is implemented as a `min(draw, total)` clamp.
  - D5 zeroes via `Nx.broadcast` and rescales in c128.

## Must fix

### W1 — `:shots` unvalidated: raw `FunctionClauseError` now leaks from `Qx.run/2` (Iron Law #7)
`lib/qx/simulation/sampler.ex:38-40`; `lib/qx/simulation.ex` `run/2`.

Verified by the orchestrator:

| | `shots: 0` | `shots: -1` |
|---|---|---|
| main | silently 2 samples | silently 3 samples (descending `1..shots`) |
| branch | raw `FunctionClauseError` | raw `FunctionClauseError` |

- The missing validation is pre-existing (`run_with_conditionals` has the same
  `1..shots` bug); this diff changed how it fails.
- Fix: add `Qx.Validation.validate_shots!/1`, which raises a typed `Qx.*Error`
  for a non-positive or non-integer value, and call it in `Simulation.run/2`
  so both paths are covered.
- Add an execution test for it.
- CHANGELOG "Fixed" line: `shots < 1` now raises instead of returning wrong
  counts.

### W3 — unseeded statistical tests can flake (~4e-4 per run)
`test/qx/simulation_measurement_test.exs:128-177` has 7 independent 4σ
assertions.
- The sampling path uses the process `:rand`, so seed it with
  `:rand.seed(:exsss, …)` in the 3 sampling-path tests.
- The `c_if` path draws fresh entropy per shot and can't be seeded. Widen it to
  5σ (about 6e-7 per assertion).

## Pre-existing (track, do not fix here)
- **W7 / plan R2** (`lib/qx/simulation.ex:722-726`): if `uniform >= p0` while
  `p1 == 0`, the state collapses to all zeros. The old code had the same logic.
  The fix is one line (`uniform < p0 or p1 <= 0`) but changes RNG→outcome only
  in that degenerate case, so it belongs in a separate fix.

## Demoted to suggestions (anti-noise filter)
- **W2** `ArgumentError` from CalcFast is unreachable via `Qx.run` / `Qx.steps`.
  Qubits are builder-validated and the value is a literal 0/1 (iron-law-judge:
  LOW).
- **W4 / W5** Trajectory test independence. Using the implementation's
  pre-states is by design (the test pins measurement, not gates). The GHZ-5
  case exercises the decision branch twice; teleportation's q0/q1 are random.
- **W6** Sampler equality test vs the D3 fallback. It is deterministic with
  fixed seeds; add a one-line comment explaining why the seeds avoid draws
  above the total.
- Edge-case tests: `shots: 1`, guard raises, message regexes.
- `-0.0` exact-zero comparisons. The current kernel emits +0.0 via broadcast.
- Static guard path via `__DIR__`; module-global `@shots` attribute.
- `is_number(norm_factor)` guard; host tuple memory at very large n.

## Clean
Iron Laws #1–#6, #8 and #9: no violations. Iron Law #5 is satisfied: a single
Nx cumulative sum and sync, then O(n) per shot. Tier-1/2 public API is
unchanged.

## Resolution (2026-11-08, user chose "fix both directly")

- **W1 fixed.** Added `Qx.Validation.validate_shots!/1`, which raises
  `Qx.OptionError` with `option: :shots`. It is called in `Simulation.run/2`,
  so it covers both run paths and the integer facade form. `:shots` docs were
  updated in `Qx.run/2` and `Simulation.run/2`, and a CHANGELOG "Fixed" entry
  was added. Tests cover 0, -1, 1.5 and `:many` on both paths, the facade form,
  and `shots: 1`.
- **W3 fixed.** The sampling-path tests are seeded via `setup`
  (`:rand.seed(:exsss, 20_261_108)`), so they are deterministic. The `c_if`
  path uses 5σ.
- **Suggestions taken:** the static-guard path now uses `__DIR__`, and
  `@shots` was renamed to the module-level `@sampling_shots`.
- **Verification:** compile clean; format clean; credo clean; 1485 tests pass
  (328 doctests); `mix docs` warning list identical to the baseline; seed
  probes 1, 2 and 3 on the new files are green.

**Updated verdict: PASS.** Both must-fix findings are resolved. W7 is
pre-existing (plan R2) and tracked in the scratchpad.
