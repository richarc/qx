# Triage: visual-design-guide

**Review:** `visual-design-guide-review.md` (PASS WITH WARNINGS, 12 warnings)
**Date:** 2026-11-20
**Decided by:** the user, in four selection dialogs and one follow-up.
**Result:** 16 to fix, 0 skipped, 0 deferred.

## User guidance

- **S1 and S3a:** raise the typed error in the drawer only. No change to
  `Qx.Operations`.
- **Unknown option keys:** raise `Qx.OptionError` in the draw functions
  touched on this branch. CHANGELOG under Changed.
- **Approach:** fix directly, tests first, each failing before its fix; then
  the full gate, commit, push, and a re-review of the fix diff.
- **T2** is an edit to an existing test file (`circuit_test.exs`); selecting
  it approved that edit.

## Deviations accepted (2026-11-20)

- P1-T3: label widths are a per-kind minimum plus measured growth.
- P3-T6: Bloch strokes are clamped at 80% as well as fonts.
- `iswap_svg_test.exs`: the rewritten non-adjacent assertion.
- The extra `Qx.OptionError` cases on `draw_bloch` and `draw_circuit`.

## Fix Queue

### Source: new on this branch
- [x] S3b `draw_bloch(state, size: 1.0e160)` raises `ArithmeticError`: bound `:size`
- [x] S6 XML-illegal control characters pass `Markup.escape/1`
- [x] S5 float32 noise can defeat the Bloch pole guard

### Source: same on `main` (Iron Law #7)
- [x] S1 empty barrier drawn raises `Enum.EmptyError`: `Qx.GateError` in the drawer
- [x] S2 wrong-shape instruction raises `FunctionClauseError`: validate the shape
- [x] S3a huge angle drawn raises `ArithmeticError`: `Qx.GateError` in the drawer
- [x] S4 non-qubit tensor to `draw_bloch` (`MatchError`); non-keyword options to
      `Draw.bloch/2` and the chart functions (`FunctionClauseError`)

### Tests
- [x] T1 the ">20 qubits" test must reach the drawer's guard
- [x] T2 connector test asserts the exact end point (existing file, approved)
- [x] T3 mono asserted strictly over the whole catalogue
- [x] T4 untested branches (circuit and Bloch)
- [x] T5 `GateCatalogue.qasm_atoms/0`: exact count, anchored path

### Suggestions
- [x] Options: `title: ""` is no title; unknown keys raise `Qx.OptionError`;
      the empty-counts chart keeps its `:title`
- [x] Formatting: no `−0.00`; the φ readout near 2π
- [x] Test tidy: the no-op shuffle, length assertions before `Enum.zip`,
      the shared text helper, the duplicate `width/1` call

## Skipped

None.

## Deferred

None.

## Outcome (2026-11-20)

All 16 fixed. Each new behaviour test failed before its fix (21 failing,
then 0). Gate: 1832 of 1832 tests, credo, format, dialyzer, docs warnings 23
(equal to `main`), `--no-optional-deps` compile.

- S3b: `:size` is capped at 10000.
- S5: θ is `2·atan2(|β|, |α|)`, not `2·acos(|α|)`, and the pole guard is
  `sin θ < 1.0e-5`. The `acos` clamp is gone with it.
- S2: the drawer checks the qubit count of every gate, and that the qubit
  and parameter fields are lists. It does not check the parameter count: a
  missing angle is still drawn as θ.
- S3a: an integer angle beyond 1.0e300 raises; a float angle of any size
  draws (as a long decimal).
- T1, T2, T3 and most of T4 passed when written: they close test gaps, they
  did not find defects.
- Left as they are, from the grouped suggestions: the title width estimate
  from the grapheme count, exact attribute-order matches in tests, and
  `Mix.ensure_application!(:xmerl)` in two test files.

## Re-review of the fix diff (2026-11-20)

elixir-reviewer, testing-reviewer and iron-law-judge read commit `f0c1dec`
(reports: `fix-elixir.md`, `fix-testing.md`, `fix-iron-laws.md`). No
blocker. None of the three ran code.

Fixed in a follow-up commit:
- A classical bit that is not an integer raised `FunctionClauseError` from
  `Validation.validate_classical_bit!/2`; it raises `Qx.ClassicalBitError`.
- A NaN or infinite amplitude raised `ArithmeticError` in `draw_bloch`
  (a regression from the `atan2` change); it raises
  `Qx.StateNormalizationError`.
- The `state_table/2` docs had gained a claim about non-keyword options
  that the code does not meet; the claim is removed.
- CHANGELOG: the unknown-option and size-cap entries are marked
  **Breaking:**; the pole fix and the unnormalised-state change are listed.
- Tests: the mono catalogue loop also asserts every gate box is ink on
  paper; the global-phase test compares coordinates within 1e-5, not
  markup; the "above 1" test is renamed.

Not changed:
- The drawer raises `Qx.GateError` for `Qx.barrier(qc, [])`. The reviewer
  would skip the barrier instead; raising is the user's triage decision.
- The arrowhead tip test in `circuit_test.exs` (existing file) is left as
  it is: the tip's exact position is already asserted by the teleportation
  reference test in `circuit_style_test.exs`.
- A wrong first argument (a non-circuit, a non-result) still raises an
  untyped error in every draw function. Same on `main`.
- `untyped/1` stays in two test files.
