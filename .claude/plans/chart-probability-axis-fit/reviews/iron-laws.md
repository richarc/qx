# Iron Law Report: chart-probability-axis-fit

Verified by reading only (no code run). Checked 5 laws (#1, #2, #5, #6, #7, #8 per brief; #1/#2 not affected). Violations: 0 blocking, 2 nits.

## #6 Public API surface / breaking change: PASS
- CHANGELOG.md:42-51 states the behaviour correctly. The axis is fixed 0 to 1 "when at least one bar reaches 0.2", otherwise fitted. It sits under `[Unreleased]` > Changed, in the bullet that already warns "check [your code] against the new output" (:24-26).
- It is not breaking vs released 0.12.0: 0.12.0 always fitted the axis, and the fixed axis exists only in this unreleased block. Net change vs 0.12.0 is "sometimes fixed, sometimes fitted", already covered by that bullet. No `**Breaking:**` tag needed.
- Docs match: tier-2 `Qx.Draw` (lib/qx/draw.ex:55-57 moduledoc, :92-94 `plot/2`, :203-205 `histogram/2`) and the `Qx` facade (lib/qx.ex:1430-1432 `draw/2`, :1534-1536 `draw_histogram/2`).
- Nit (LOW): the docs say "under 0.2" while the code threshold is `0.2 - 1.0e-6` (vega_lite.ex:98). Harmless.
- Nit (LOW): the CHANGELOG (:46) and doc paragraphs have over-long lines left after the edit. ROADMAP.md:49 still says "fixed 0 to 1 probability axis" without the 0.2 qualifier.
- Nit (LOW): the fitted axis drops the `.2f` tick format (vega_lite.ex:100). That is deliberate per the test comment, but the CHANGELOG does not mention it.

## #8 Tolerances on derived quantities: PASS
- vega_lite.ex:98 `@fixed_axis_min 0.2 - 1.0e-6`. The f32 spacing near 0.2 is about 1.5e-8 (the f32 value is 0.20000000298...), so the margin is about 65 ulps, which is feasible.
- Probabilities are f32 widened exactly to f64 by `Nx.to_flat_list`, and an f32 0.2 already compares `>=` 0.2. Rounding error from summing amplitudes is about 1e-7 or less, below 1e-6. The margin is neither infeasibly tight nor loose enough to matter (a band of 1e-6 is visually negligible).
- Test chart_style_test.exs:132-146 uses 0.2 (f32) and 0.19, which both land correctly.

## #5 No host-side O(2^n) loops: PASS
- The new `Enum.max` (vega_lite.ex:133) runs inside `VL.histogram/4`, after `validate_size!` in both entry points. `plot/2` is at draw.ex:131 and calls `VL.plot` (:136), which delegates to `histogram/4` (vega_lite.ex:68). `histogram/2` is at draw.ex:242 and calls `VL.histogram` (:247).
- `validate_size!` raises `Qx.DrawSizeError` when the size exceeds `2^max_qubits` (validation.ex:345-349). The `Enum.max` is therefore bounded by `max_qubits` (default 12, so at most 4096 elements). It is also O(n) in a pass that already does `with_index |> map` over the same list, so it adds no new asymptotic cost.

## #7 Typed errors: PASS
- No new error path. `Enum.max(list, fn -> 0 end)` handles the empty list via the empty fallback. For non-numeric terms (`:nan`, `:infinity`, Complex structs) `Enum.max` uses term ordering and does not raise. The input is always the output of `Nx.to_flat_list` after the draw option and size validation.
- The only raises on these paths are the existing `Qx.OptionError` and `Qx.DrawSizeError`.

## Not touched
#1, #2, #3, #4, #9.
