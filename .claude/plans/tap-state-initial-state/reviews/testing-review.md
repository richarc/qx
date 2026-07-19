# Test Review: test/qx/operations_tap_test.exs

## Summary

Small, focused ExUnit file (6 tests) covering the bug fix for `tap_state/2`
and `tap_probabilities/2` executing the circuit-so-far instead of the stored
initial state. `async: true`, no global state, no Mox, no factories —
Iron Laws #1-#7 don't really apply here and are all satisfied trivially.
Tolerance discipline (Iron Law #8) is respected: `@tolerance 1.0e-6` with a
comment explaining the float32 epsilon. Message-passing pattern for
capturing tap callbacks (`send(parent, {:tapped, state})` +
`assert_receive`) is correct and idiomatic — no `Process.sleep`.

The main gaps are coverage: the file undertests the conditional branch of
the fix and the "unchanged circuit" tests are weaker than they look.

## Iron Law Violations

None. `async: true` present, no sleep, no mocks, tolerance ≥ 1.0e-6.

## Issues Found

### Critical

None.

### Warnings

- **Coverage gap: `c_if` without `measure` never exercised** (whole file).
  `Qx.Simulation.get_state/2` and `get_probabilities/2` raise
  `Qx.MeasurementError` when `has_measurements?/1` **or**
  `has_conditionals?/1` is true (lib/qx/simulation.ex:220, :269) — two
  independent predicates. Both tap tests only build a circuit via
  `Operations.measure/3` (lines 32-41, 70-79), so the `has_conditionals?`
  branch is untested. Since the bug being fixed is specifically about
  "measurements/conditionals" in the prefix (per the task description),
  a circuit built with `c_if/4` but no `measure/3` call would isolate that
  branch and should be added as a 7th case (one per tap function, or a
  shared helper via `describe "raises on conditional prefix"`).

- **`assert tapped == circuit` is a weak identity check** (lines 24-30,
  62-68). `tap_state/2` and `tap_probabilities/2` don't mutate the input at
  all (`fun.(state); circuit`), so this assertion can't fail even if the
  side-effecting callback body were entirely broken — it only proves the
  function is pass-through, which was never in doubt (unlike the actual bug,
  which was about *what state is computed*, not what's returned). Consider
  either dropping these tests (redundant with the "receives the state after
  instructions" tests, which already assert the pipeline continues by
  chaining) or strengthening them to also assert on a tapped value to give
  them a reason to exist independently.

### Suggestions

- **No multi-gate-then-tap coverage.** Both "receives the state" tests use
  a short prefix (1-2 gates). Given the fix is about "state after the
  instructions so far", a case with 3+ heterogeneous gates (e.g. h, cx, x)
  before the tap would more convincingly pin down "executes the full
  prefix" versus "executes the first instruction only" — a regression that
  a single-gate test wouldn't catch.

- **`tap_circuit/2` is untested in this file** (mentioned only in the task
  description as pre-existing/one-line). Since this PR touches the
  `tap_*` family and the fix could plausibly affect shared helper logic in
  future refactors, consider at minimum a doc-comment / `@tag :skip` note
  or a follow-up ROADMAP/scratchpad line so it isn't silently assumed
  covered. Not a blocker since `tap_circuit/2` doesn't call
  `Qx.Simulation` and isn't touched by this bug fix.

- **No test asserting the *message* of `Qx.MeasurementError`.** Per the
  testing skill checklist ("assert_raise includes message pattern when
  verifying exceptions"), lines 38-40 and 76-78 use `assert_raise
  Qx.MeasurementError, fn -> ... end` without a message pattern. The error
  module raises a specific string ("Cannot get pure state from circuit
  with measurements or conditionals. Use run/2 instead.") — asserting on
  it (even a substring) would catch accidental message/behaviour drift and
  more directly document the "same contract as `Qx.Simulation.get_state/2`"
  claim in the docstring at lib/qx/operations.ex:862-864.

- Both `describe` blocks are well-named and each test name reads as a
  clear behavioral spec — no changes needed there.
