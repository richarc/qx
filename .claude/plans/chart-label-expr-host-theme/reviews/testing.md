# Test Review: test/qx/draw/chart_style_test.exs (label expression guard)

Verified by reading only (diff, test helpers lines 18-66, vega_lite.ex lines 28-53 and the diff's label_form clauses). Nothing was run.

## Summary
The new test fails if the guard is removed from either expression, and it reaches a labelExpr for all three functions. Its one real weakness is that it can pass vacuously. The two updated assertions keep their intent.

## BLOCKER
None.

## WARNING
- test/qx/draw/chart_style_test.exs:83-84 (the `_no_expression -> :ok` arm). The test never checks that any expression was seen. If `x_encoding/1` returned nil (no "bar" view found; `nil["axis"]` is nil in Elixir) or the key were renamed, all 15 iterations would hit `:ok` and the test would pass. Fix: collect the expressions and assert the count, or assert per function that at least one bar count yields an expression. Per function it should be: plot and histogram at 17, 64 and 128 (kets, above 16); counts at 2 and 16 (bit strings, 16 or fewer).

## SUGGESTION
- test/qx/draw/chart_style_test.exs:78-81. `starts_with?` plus `ends_with?` is a loose pin. It would pass for `isString(datum.value) ? a : '' ... : ''`, or if the inner expression were dropped. The two exact-string tests at lines 202 and 211 cover the inner expression for kets (32 bars, plot/histogram/counts) and bit strings (16 bars, counts), so the loose pin is acceptable. The `ends_with?` assert at line 81 has no message, unlike line 78.
- Redundancy: the new test mostly repeats the two exact assertions. What it adds is the 17, 64 and 128 kets cases and plot/histogram at 2 and 16 bars. Keep it, but the vacuity guard above is what makes it worth keeping.
- Mutation check. Removing the guard from `label_form(:kets, _)` fails plot/histogram at 17+ (and counts, whose kets-above-16 path is not reached, so it does not matter). Removing it from `label_form(:bit_strings, _)` fails counts at 2 and 16. Both are covered.
- Not covered: bit strings above 16 bars (labelAngle only, no expression) and kets at 16 or fewer (no expression). These are correctly skipped, and tests elsewhere cover them.
- Updated assertions at lines 202 and 211: same inputs (counts at 16, all functions at 32). The `refute labelAngle` and `refute values` follow-ups are untouched, so the intent is kept.

## Limit of pinning the string
Pinning the string is a reasonable limit with no browser. The failure is a Vega runtime evaluation of `datum.value` as undefined, which no Elixir-side check can reproduce.

Stronger options that need no browser:
1. Assert the guarded form structurally, as the tests do now.
2. Pin that the spec's own `config` does not set `axisBand.tickExtra`, so the guard remains the only protection.
3. An opt-in test, tagged and excluded by default, that runs the spec through `vega` or `vega-lite` on Node. This adds a JS dependency, so it is probably not worth it for a one-line fix.
