# Review: fix/chart-label-expr-host-theme

Status: Approved. No BLOCKER, no WARNING. Verified by reading only; nothing was run.

## Verified
- Every labelExpr is guarded. A grep of `lib/` for `label_expr|labelExpr|datum.` finds only vega_lite.ex:192, 195 and the helper at 203. The other two `label_form` clauses (:189, :197) emit no expression.
- The string is valid Vega. `"isString(datum.value) ? #{expression} : ''"` expands to `isString(datum.value) ? '|' + datum.value + '⟩' : ''`.
  - Single quotes need no escaping inside an Elixir double-quoted string.
  - `⟩` is UTF-8 in a binary and interpolation keeps it. The old code already emitted it.
  - Vega expressions support `?:`. `isString` is a Vega built-in. The ternary binds looser than `+`, so the whole concatenation is the true branch.
  - `slice(datum.value, 1, -1)` is unchanged.
- `Enum.map(&Map.fetch!(&1, x_field))` at :208 builds `values` from the data rows, so it cannot see a valueless tick. An explicit `values` list also generally makes the axis skip tickExtra. UNVERIFIED: I did not read Vega's source for this.
- No other expression or datum reference exists in the file. The theme module was not read for `datum`, but the grep of `lib/` covers it.
- The test's `for` + `case` falls through on axes without `labelExpr`. It would pass vacuously if no case ever produced one, but the exact-string tests at chart_style_test.exs:~202 and ~211 cover that.

## SUGGESTION
1. vega_lite.ex:199-202. The comment explains the Livebook cause as well as the invariant. Keeping only "tick may have no value (host themes set tickExtra); guard every expression" would be enough. This is optional.
2. CHANGELOG (diff lines 9-13).
   - The claim "more than 16 bars" is right for the :kets form, which is `@ket_limit`, assuming that value is 16. The test uses 16 for the bit_strings expression, so check that.
   - For `Qx.draw_histogram/2`, the bit-string form uses the expression at 16 bars or fewer, and the ket form at more than 16. A reader may be confused that the failing expression differs by form. If the second expression (`'|' + datum.value + '⟩'`) would also have rendered `|undefined⟩` rather than failed, the entry's "failed" still holds for the slice case only. Consider "failed or showed a stray label". Minor wording only.
