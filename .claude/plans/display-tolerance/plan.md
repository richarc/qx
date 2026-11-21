# Plan: one shared display tolerance for state output

**Slug:** `display-tolerance` · **Branch:** `feat/display-tolerance` · **Date:** 2026-11-21
**Status:** IMPLEMENTED, awaiting review · **Depth:** standard · **Tasks:** 13 in 4 phases

Complexity: 3 (3 source files across Format / Step / Draw.Tables +3, follows
existing patterns −2, new shared helper +2, no tier 1/2 API change 0).

## Goal

"Is this amplitude zero for display?" has one answer, defined once in
`Qx.Format` (tier 3, `@moduledoc false`) and used by the state table,
`Qx.Step` and Dirac notation.

## Not in scope (decided by the user, 2026-11-21)

- No QuTiP-style `tidyup` that changes or returns cleaned state values.
- `Qx.get_state/1` keeps returning raw amplitudes.
- No opt-in cleaning helper.
- The Bloch pole guard (`@pole_epsilon` in `lib/qx/draw/svg/bloch.ex`) is a
  geometric guard on sin θ, not a display threshold. Left alone.

## Where the answer is given today

| Site | Cut-off | On | Role |
|---|---|---|---|
| `Qx.Format.dirac_notation/2` default `:threshold` (`format.ex:117`) | 1.0e-6 | probability | drops terms |
| `Qx.Step` Inspect `@prob_threshold` (`step.ex:122`) | 1.0e-6 | probability | drops terms, then a top-4 fallback |
| `Qx.Draw.Tables` `hide_zeros` (`tables.ex:88`) | 1.0e-10 | probability | drops rows |
| `Qx.Format.format_term/4` (`format.ex:146`) | 1.0e-6 | imaginary part | prints a complex amplitude as real |

Callers of `dirac_notation/2`: `Qx.Step.show/1` (`step.ex:89`), the `Qx.Step`
Inspect impl (`step.ex:161-173`), `Qx.Register.show_state/1`
(`register.ex:774`, deprecated calc engine).

## Measured (this session; script and output in `scratchpad.md`)

- **Rounding residue is small.** Circuits built as U then U⁻¹ (exact result
  |0…0⟩), 2 to 14 qubits, 100 to 1,740 gates: the largest probability left
  on any other basis state was **2.3e-13** (amplitude 4.8e-7).
- **Real amplitudes stay well above it.** The smallest probability in a
  uniform state at the 20-qubit limit is **9.5e-7** (amplitude 9.8e-4,
  printed `0.001` at 3 decimals).
- So there is a gap of about six orders of magnitude between residue and the
  smallest uniform amplitude Qx supports. One absolute cut-off inside that
  gap separates the two for every supported size. No relative threshold is
  needed for the "is it zero" question.
- **1.0e-6 is the wrong side of that gap.** It is above 9.5e-7, which is why
  `Qx.Step` needed its top-4 fallback
  (`.claude/solutions/phoenix-issues/absolute-display-threshold-fails-at-scale-qx-step-20260703.md`).
  `Qx.Step.show/1` and `Qx.Register.show_state/1` call `dirac_notation/2`
  without that fallback, so they still print `0.000|0…0⟩` in that regime.

## Design

Two questions, kept apart (the lesson of the July solution doc):

1. **Is it zero?** A noise question, absolute, set from the float width.
   - `@noise_floor_amplitude 1.0e-5` and its square,
     `@noise_floor_probability 1.0e-10`, in `Qx.Format`.
   - 1.0e-10 is 400 times the largest residue measured and 10,000 times
     below the smallest 20-qubit uniform probability. It is the value
     `hide_zeros` already uses, so the state table does not change.
   - Iron Law #8: both are far above float32 ε² and ε; no sub-epsilon target.
2. **Is it worth printing in a one-line Dirac string?** A presentation
   question, depends on the precision asked for.
   - A term that is not zero but whose magnitude prints as all zeros at the
     requested precision (`0.000`) adds nothing to a one-line summary.
   - Rule (see **D1**): drop such terms, unless that would drop every term;
     then keep the largest ones. This is the existing `Qx.Step` fallback,
     moved into `Qx.Format` so every caller gets it.

New internal functions in `Qx.Format`:

- `negligible?(probability)` — question 1.
- `significant_terms(terms, opts)` — questions 1 and 2 for a list of
  `{basis, amplitude, probability}`; returns the terms to print, in index
  order. Options `:precision` (default 3) and `:threshold` (see **D2**).
- `format_term/4` uses `@noise_floor_amplitude` for the imaginary part.

Then:

- `dirac_notation/2` calls `significant_terms/2`.
- The `Qx.Step` Inspect impl loses `@prob_threshold`, `top_terms/1` and
  `truncated_dirac/2`; it takes the first 4 of `significant_terms/2` and adds
  ` + …` when there are more.
- `Qx.Draw.Tables` `hide_zeros` calls `negligible?/1`.

## Decisions for the user

- **D1. Dirac strings: drop terms that print as `0.000`?** Recommended: yes,
  with the keep-the-largest fallback. The alternative is to print every
  non-zero term, which gives strings such as `1.000|0⟩ + 0.000|1⟩`.
  Visible effect of the recommendation, at the default precision of 3:
  terms with amplitude between 5.0e-4 and 1.0e-3 (probability 2.5e-7 to
  1.0e-6) are printed as `0.001` where today they are dropped. Nothing that
  prints today disappears.
- **D2. Keep the `:threshold` option of `dirac_notation/2`?** It is an
  internal function; the only non-default uses are `threshold: 0.0` in
  `step.ex` (removed by this plan) and one test. Recommended: remove it, and
  with it the test "respects custom threshold" (`format_test.exs:145`).
  Alternative: keep it as an extra minimum probability.
- **D3. Existing tests.** These assert today's thresholds and need a decision
  each; none may be edited without approval:
  - `test/qx/format_test.exs:145` "respects custom threshold" — removed
    under D2, or kept if the option stays.
  - `test/qx/format_test.exs:207` asserts `"0.000|0⟩"` for an all-zero input.
    Expected to keep passing (the fallback prints the largest term); confirm
    in P0.
  - `test/qx/step_test.exs:172` "Inspect fallback below the probability
    threshold" — expected to keep passing with its comment out of date
    (probability 8.1e-7 is no longer "below the threshold": it is simply
    printed). Proposed: reword the describe and comments only.
  - `doctest Qx.Format`: the `dirac_notation/2` docs list `:threshold`;
    updated under D2. Confirm the doctest count does not fall.

## Phase 0: characterise (no source change)

- [x] [P0-T1] Add the measurement script's result to a characterization test:
  `test/qx/format_tolerance_test.exs`, tagged so it stays fast (2 and 6
  qubits, U then U⁻¹), asserting the largest residue probability is below
  1.0e-11. Records the evidence the constant rests on. — done in `test/qx/format_tolerance_test.exs`; depth cut to 10 layers because a longer circuit trips the test-env norm-drift assertion.
- [x] [P0-T2] Run the four existing test files that touch these paths
  (`format_test.exs`, `step_test.exs`, `draw_test.exs`,
  `draw_contracts_test.exs`) and record the baseline counts and the doctest
  count of `Qx.Format` and `Qx.Step` in `scratchpad.md`. — baseline 89 passed (11 doctests, 78 tests).

## Phase 1: tests first (all must fail before P2)

- [x] [P1-T1] `negligible?/1`: true at 2.3e-13 and 1.0e-11; false at 9.5e-7,
  1.0e-9 and 1.0; boundary at 1.0e-10.
- [x] [P1-T2] `significant_terms/2`: drops noise; drops a `0.000` term when
  another term prints; keeps the largest terms when every term would print
  as zero; a miniature 20-qubit-uniform case (amplitude 9.0e-4 on every
  term) returns every term; precision 5 keeps a term that precision 3 drops;
  order is index order.
- [x] [P1-T3] `dirac_notation/2`: a 9.8e-4 uniform list prints `0.001|…⟩`
  terms, not `0.000|0…0⟩`; an amplitude with imaginary part 5.0e-6 prints as
  real; one with imaginary part 5.0e-4 prints as complex.
- [x] [P1-T4] `Qx.Step.show/1` on a miniature all-small state (the fixture
  trick from the July solution doc) does not return `"0.000|00⟩"`. This is
  the latent bug; it must fail on `main`.
- [x] [P1-T5] One state, three surfaces agree: for a state with one noise
  amplitude (1.0e-7), `Qx.draw_state(hide_zeros: true)`, `inspect(step)` and
  `Qx.Step.show/1` all leave that basis state out.
- [x] [P1-T6] No constant left behind: a test that reads the three source
  files and fails if `1.0e-6` or `1.0e-10` appears in `step.ex` or
  `tables.ex` display code (anchored to the lines, not a blanket grep), so
  a fourth private threshold cannot return unnoticed.

## Phase 2: implement

- [x] [P2-T1] `Qx.Format`: the two constants with a comment citing the
  measurements, `negligible?/1`, `significant_terms/2`; `dirac_notation/2`
  and `format_term/4` use them. Apply D1 and D2. — `significant_terms/2` returns `{terms, cut?}` and takes `:max`; 'prints as zero' is judged per real and imaginary part.
- [x] [P2-T2] `Qx.Step` Inspect impl: remove `@prob_threshold`,
  `top_terms/1`, `truncated_dirac/2`; use `significant_terms/2`.
- [x] [P2-T3] `Qx.Draw.Tables`: `hide_zeros` uses `Format.negligible?/1`.
- [x] [P2-T4] Apply the approved edits to existing tests (D3), and nothing
  else in those files. — removed `format_test.exs` 'respects custom threshold'; reworded the Step test's describe and comments only.

## Phase 3: verify and record

- [x] [P3-T1] Gate: `mix compile --warnings-as-errors && mix format
  --check-formatted && mix credo --strict && mix test`, `mix dialyzer`,
  `mix docs` warning count ≤ 23. Doctest counts for `Qx.Format` and
  `Qx.Step` not below the P0 baseline. — 1860 passed (364 doctests, 1496 tests), credo, format, dialyzer, docs warnings 23.
- [x] [P3-T2] CHANGELOG `[Unreleased]` → Fixed: `Qx.Step.show/1` printed
  `0.000|0…0⟩` for a wide uniform state; Changed: Dirac strings print
  amplitudes between 5.0e-4 and 1.0e-3 as `0.001`. Patch-level: no API
  change (Iron Law #6: `Qx.Format` is tier 3; `Qx.Step.show/1` output text
  changes only in the regime that was wrong).
- [x] [P3-T3] Update the July solution doc with a pointer: the fallback now
  lives in `Qx.Format.significant_terms/2`.

## Risks

- **A caller relies on the old 1.0e-6 cut.** Only `Qx.Register.show_state/1`
  (deprecated) and `Qx.Step` call `dirac_notation/2`. Covered by P1-T4/T5
  and the existing suites.
- **Residue larger than measured** on circuits deeper than 1,740 gates or
  with `renormalize:` off for long runs. The floor has a 400× margin; P0-T1
  keeps the evidence under test. If a real case exceeds it, the constant is
  one line.
- **Iron Law #9 / #7:** no instruction shapes or error paths change.
- **Hex dependency research:** none run; no dependency is added.

## Verification

Per task: `mix compile --warnings-as-errors`. Per phase: the four affected
test files plus `mix credo --strict`. Final gate: P3-T1.
