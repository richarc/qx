# Iron Law Judge: chart-label-expr-host-theme

Checked 4 AGENTS.md laws (#6, #1, #5, #7): 0 violations. Verified by reading only; nothing was run.

## #6 Public API breaking changes: PASS
- CHANGELOG.md:109-113 adds the entry under `## [Unreleased]` -> `### Fixed` (the Unreleased section starts at line 8 and the Fixed subsection at line 75). The 0.12.0 section starts at line 118, so the entry is not in it.
- lib/qx/draw/vega_lite.ex:6 is `@moduledoc false`, which is tier 3. The tier 2 surface is `Qx.Draw`. Its documented return is a chart, and the exact `labelExpr` string is an internal detail, not a declared contract.
- 0.12.0 had no labelExpr: I found no mention in its CHANGELOG section (lines 118 onward). The only hits are the new entry itself. I did not inspect the released tag, so this rests on the CHANGELOG plus your statement. If so, the change adds a wrapper to an expression that is itself unreleased, and the diff is not breaking. It is a bug fix and needs no minor bump.
- The tests that asserted the old exact strings were updated in the same diff (chart_style_test.exs:199-211).

## #1 Expression injection: PASS
- lib/qx/draw/vega_lite.ex:203 interpolates `expression` into `"isString(datum.value) ? #{expression} : ''"`.
- `label_expr/1` is `defp` and has exactly two callers, at lines 192 and 195. Both pass compile-time string literals (`"slice(datum.value, 1, -1)"` and `"'|' + datum.value + '⟩'"`). A grep of the file for `label_expr` found no other call site.
- No chart title, counts key or other user data reaches the interpolation. User data reaches the chart only as the `datum.value` field at render time, as data. The data is not part of the expression text. The bit-string/ket text is concatenated by Vega at runtime and never parsed as an expression.
- The `label_form/2` arguments `kind.x_values` and `bars` come from internal config (lines 38 and 48) and an integer count.

## #5 Public-API surface and moduledoc tier: PASS
- No new public function. The only new function is the private `label_expr/1`, so no new tier annotation is needed. The module stays `@moduledoc false`.

## #7 Typed errors: PASS
- The diff adds no raise path and no `Nx`/`Complex`/`ArgumentError` leak. It changes a string constant only.

Note: AGENTS.md #5 is "NO host-side loops over 2^n amplitudes" and #7 is "Public functions raise typed Qx.*Error". I read #5 here as the generic Iron Law (pin values in queries), which does not apply: no Ecto, Oban or `String.to_atom` appears in the file or the diff. I also checked the AGENTS.md #5 reading: the diff has no loop over amplitudes. Both readings pass.
