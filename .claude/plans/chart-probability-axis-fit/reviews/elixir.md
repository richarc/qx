# Review: fix/chart-probability-axis-fit (read only, nothing run)

Status: approved, no BLOCKER, no WARNING. 3 suggestions.

## Verified by reading
- `lib/qx/draw/vega_lite.ex:118-136`. `plot/4` (line 68) and `Draw.histogram/2` (draw.ex:247) both go through `histogram/4`, so both entry points get the rule.
- `Enum.max(list, fn -> 0 end)`: a 0-arity function is the empty fallback in `Enum.max/2`.
  - Empty list gives 0, so the fitted axis. Data is empty, so there is nothing to draw. The old code gave a fixed axis. Not a crash.
  - All zeros gives the fitted axis. A real normalised state cannot be all zeros.
- NaN/infinity come back from `Nx.to_flat_list` as the atoms `:nan`, `:infinity` and `:neg_infinity`. Atoms sort above numbers in Erlang term order, so `Enum.max` returns the atom and `atom >= float` is true. The fixed axis is chosen and nothing raises. `Enum.max` itself does not raise on mixed atoms and numbers.
- Values slightly over 1 (such as 1.0000001) take the fixed branch, the same as before.
- `@fixed_axis_min 0.2 - 1.0e-6` is evaluated at compile time. A float32 0.2 (about 0.2000000030) is above the threshold.
- `%{@probability | y_options: ...}` is valid because the key exists. `bar_chart` appends `kind.y_options` to the y encoding, so the fitted branch omits `axis`. The test's `refute Map.has_key?(y, "axis")` matches that.
- The text layer shares the y encoding, so it follows the fitted scale. It has its own `format: ".2f"` (`kind.value_format`), which is untouched.
- Docs in `lib/qx.ex:1430` and `:1534`, `lib/qx/draw.ex:57`, `:92` and `:203`, and CHANGELOG:43-46 all state the 0.2 rule correctly.
- `test/qx_manual_test.livemd:1094` and `:1118` are updated.

## SUGGESTION
1. `lib/qx/draw/vega_lite.ex:128`. UNVERIFIED: with ".2f" value labels at 8 bars or fewer, the fitted axis can disagree with the labels. The maximum is at least 1/8 for a normalised input, so the fitted branch is reachable with at most 8 bars (for example 8 uniform bars of 0.125). The label then reads "0.13" or "0.12", depending on rounding. The axis has fine ticks such as 0.02 and 0.14. This is consistent enough. Smaller bars among them can show "0.00" or "0.01". Acceptable by the owner's rule. If it matters, make `value_format` follow the branch.
2. `lib/qx/draw/vega_lite.ex:133`. UNVERIFIED: a degenerate all-zero input gives a [0, 0] domain, and I did not check how Vega pads that. It is unreachable for a valid state, so no action is needed. A test is not worth adding.
3. `ROADMAP.md:49` still says "a fixed 0 to 1 probability axis". It is now conditional. Also, the doc wording "runs from 0 to 1 ... fits the data" in `lib/qx.ex` and `lib/qx/draw.ex` could say "otherwise" to match the 0.2 rule more directly. The new doc lines are long (over 98 columns, for example `lib/qx.ex:1432`, `lib/qx/draw.ex:94`). Run `mix format` or rewrap.
