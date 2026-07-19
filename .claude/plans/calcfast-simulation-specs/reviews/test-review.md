# Test Review: calcfast-simulation-specs diff

## Summary

Pure `@spec` + `@typep` addition across `lib/qx/calc_fast.ex` and
`lib/qx/simulation.ex`. No logic changed, no test files touched, no `iex>`
examples added or removed. The test suite is unaffected.

## Iron Law Violations

None.

## Issues Found

### Critical

None.

### Warnings

None.

### Suggestions

- [SUGGESTION] **No Dialyzer — specs are unverified by tooling.** The ~37
  `@spec` and 10 `@typep` additions are compile-time annotations only. Without
  `dialyzer` (or `dialyxir`) in the toolchain, none of them is checked against
  the implementation. A type error in a spec (e.g. wrong return type, wrong
  arity annotation) would be silently ignored. The functions in `Qx.CalcFast`
  are exercised by `test/qx/calc_fast_test.exs` and the private functions in
  `Qx.Simulation` are covered through `Qx.Simulation.run/2`'s public-API tests,
  so an *egregiously wrong spec that also breaks runtime behaviour* (e.g. wrong
  arity) would be caught behaviourally — but a spec that mis-states a type
  without breaking runtime (e.g. `non_neg_integer()` where `integer()` is
  correct) would pass all tests undetected. Consider adding `dialyxir` as a dev
  dependency in a future roadmap item. (Noted out of scope for this plan per
  scratchpad.)

## Doctest Count Verification

- `Qx.CalcFast` is `@moduledoc false`; no test file calls `doctest
  Qx.CalcFast`. Its `@doc` blocks are internal documentation only and produce
  zero doctests. No new `iex>` examples were added in this diff. **Doctest
  count: unchanged.**
- `Qx.Simulation` already contained `iex>` examples in `run/2`'s `@doc`
  (unchanged by this diff). No test file calls `doctest Qx.Simulation`, so
  those examples do not run as doctests. **Doctest count: unchanged.**
- Expected suite totals remain **242 doctests + 916 tests, 0 failures**.

## No-test-file Confirmation

No `*_test.exs` file appears in this diff. The only changed files are
`lib/qx/calc_fast.ex` and `lib/qx/simulation.ex`, both limited to `@spec`
and `@typep` declarations.
