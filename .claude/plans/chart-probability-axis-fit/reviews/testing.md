# Test Review: test/qx/draw/chart_style_test.exs (fix/chart-probability-axis-fit)

Verified by reading only (nothing run): the diff, the whole test file, lib/qx/draw/vega_lite.ex (probability_axis/1, bar_chart/5, marks/3), Draw.plot/histogram call paths (both end in VL.histogram via Nx.to_flat_list), and a grep of test/ for other assertions on scale, domain or `.2f`.

## Summary
The three tests pin the rule on both sides of 0.2 and would fail on a straight revert. Both functions are covered on each side of the boundary, but only by uniform inputs. The explicit boundary cases use `Draw.histogram` only, and never put the maximum anywhere but first. No other test in the file is broken by the change. No Iron Law violations (async: true, no mocks, no sleeps).

## BLOCKER
None.

## WARNING
- [ ] chart_style_test.exs:132-149. Every non-uniform input has its maximum at index 0 (0.2, 0.19, 0.9). `Enum.max` could be replaced with `hd/1` and every test would still pass. Real distributions (Bell [0.5,0,0,0.5], any peak not at |0...0>) would then be misclassified. Fix: put the maximum in a non-first position in at least the "exactly" and "under" cases, e.g. `[0.1, 0.1, 0.2, 0.1, ...]` and `[0.11, 0.1, 0.19, ...]`.
- [ ] chart_style_test.exs:133 and lib/qx/draw/vega_lite.ex:96-98. The "float32 boundary" test does not exercise the 1.0e-6 margin. The f32 nearest 0.2 is 0x3E4CCCCD = 0.20000000298..., which rounds up, so `Nx.tensor([0.2, ...], type: :f32)` gives a value >= 0.2 without the margin. The test passes with `@fixed_axis_min 0.2`, and the source comment ("keeps a float32 0.2 on the fixed side") overstates what the margin does. The case is sound as a boundary test, but it cannot catch removal of the margin. The margin matters for a computed f32 value just under 0.2 (e.g. `0.2 - 2.0e-7`, or an amplitude squared). Fix: add a case with a value such as 0.1999995 (inside the margin, expect fixed). Pin the other side with a value like 0.19998 (expect fitted).
- [ ] chart_style_test.exs:132-149. The boundary test covers `Draw.histogram` only. Both functions reach the same code, so the risk is low, but the replaced test looped over `[:plot, :histogram]`. Fix: loop the three cases over both, building the plot input with `result(probabilities: tensor)`.

## SUGGESTION
- [ ] chart_style_test.exs:4 (moduledoc). It still says "a fixed probability axis". Reword to "a probability axis fixed at 0 to 1 unless every bar is under 0.2".
- [ ] chart_style_test.exs:139-149. Threshold mutations 0.19 and 0.1999 are not caught, because f32 0.19 = 0.18999999762 is below the double 0.19. The "under" value 0.19 does not sit tightly under the threshold. Use 0.1999 (f64) or 0.199 so `under` is nearer the boundary. The 0.15 and 0.25 mutations are caught.
- [ ] chart_style_test.exs:144-148. The "peaked" case (0.9, 63 small bars) adds little over the 2/4-bar test. Use it for the large-bar-count fixed case it seems meant for (a max in a 64+ bar chart where the x axis thins), or move the maximum to the middle (see first warning).
- [ ] No test for empty probabilities (`Enum.max(..., fn -> 0 end)` branch at vega_lite.ex:133 goes to fitted). Probably unreachable through Draw; ignore unless a size guard allows it.
- [ ] The fitted test at 117-130 asserts `scale == %{zero, nice}` with no `domain`, and `refute Map.has_key?(y, "axis")`. Together these are exact and would fail on a revert. The comment "2 to 37 pixels tall" depends on the default chart height and will go stale if the height changes. Consider dropping the figure.

## Replaced-test coverage
The old test asserted `scale.domain == [0,1]`, field, and title over bars 2, 8, 32 for both functions. Now:
- field/title: still asserted in both new tests.
- domain at 2 and 4 bars: kept. The old 8 and 32 bar cases were intentionally flipped to fitted.
- Gained: `axis.format == ".2f"` on the fixed side, and exact scale maps.
- Uncovered, minor: a fixed-axis chart with more than 16 bars (labels rotated). Only the "peaked" 64-bar case touches it, and only the scale.

## Other tests in the file
- Lines 233-249 (text layer, 1 and 8 bars): the 8-bar uniform now takes the fitted axis. They assert only the text mark, format ".2f", field and x encoding, none of the y scale. Unaffected. The text layer's `.2f` is `value_format`, independent of the axis format.
- Lines 251-258 (9 bars), 68-94 (colour/config), 173-182 (field names), 185-230 (labels, via x only), 277-331: none read the y scale. Unaffected.
- The counts axis test (151-161) is untouched by the change.
- Other files: grep found no assertions on the probability scale or axis format outside this file.
- One behavioural note, not a test defect: with the fitted axis, a text-layer chart at 8 bars labels bars with `.2f` (0.12), which is coarse next to a fitted axis. That is the owner's decision, so I did not flag it further.
