# Iron Laws: feat/bloch-even-rim

Checked 4 of the 8 numbered laws in AGENTS.md (#1, #5, #6, #7): 0 violations. Verified by reading `.diff.patch`, `AGENTS.md:384-404`, `CHANGELOG.md:8-57` and grepping `lib/qx/draw/svg/bloch.ex`. Nothing was run.

Note: the law numbers in AGENTS.md differ from the plugin's. #1 is atoms, #5 is host-side loops over 2^n amplitudes, #6 is the public-API breaking-change rule and #7 is typed errors.

## #6 Breaking changes, tier 1/2: PASS
- `lib/qx/draw/svg/bloch.ex:2` is `@moduledoc false`, so it is tier 3 and outside the covered surface. The tier-2 `Qx.Draw.bloch/2` and the tier-1 `Qx.draw_bloch/2` keep their signatures and return type (`Qx.Draw.Image`). Only the SVG string content changes. The diff touches no `def` or option.
- CHANGELOG: the `[Unreleased]` "Changed" section (`CHANGELOG.md:20-26`) already says the SVG content changes and tells readers to check code that parses the markup. The diff reworded the Bloch bullet at `CHANGELOG.md:36-37` to "an even, darker rim of shading", so the change is reflected.
- No new Breaking marker is needed. Relative to 0.12.0 nothing is removed or retyped. The existing `**Breaking:**` entry at `CHANGELOG.md:61` is for `:title` validation and is unaffected.
- Minor note: the Bloch bullet describes the whole redesign, not this increment. This is correct for an unreleased entry.

## #1 No String.to_atom / Module.concat: PASS
- The grep of `bloch.ex` found no `to_atom`, `binary_to_atom`, `list_to_atom` or `Module.concat`.
- The new `rim_id/1` (diff hunk near `bloch.ex:277`) is a binary `<>` concatenation, so it interns no atom.

## #5 No host-side loops over 2^n amplitudes: PASS
- The change adds no `for` or `Enum` call. `gradients/1` returns a fixed list, and `disc/2` and the extra `group("rim", ...)` are constant-size. `amplitudes!/1` (`bloch.ex:156-158`) is unchanged and handles a 2-element tensor.

## #7 Typed errors: PASS
- The diff adds no `raise` and no error path. The existing `raise Qx.StateShapeError` and `raise Qx.StateNormalizationError` (`bloch.ex:159,164,175`) are untouched.

## Other
- `bloch.ex` holds `@rim_start` and `@rim_opacity` as module attributes. The `-rim` gradient id derives from the unique body id, and the test that checks distinct ids covers both gradients.
