# Iron Law Judge: bloch-shaded-edge

Checked 4 laws (AGENTS.md #6, #1, #5, #7) by reading the diff and source. Nothing was run. Violations: 0.

## #6 Public API surface: PASS, no Breaking marker needed
- `lib/qx/draw/svg/bloch.ex` is `Qx.Draw.SVG.*`, which AGENTS.md:403 lists as tier 3 (`@moduledoc false`, no stability guarantee). The change touches no tier 1 or tier 2 function, option or return type. `Qx.draw_bloch/2` and `Qx.Draw.bloch/2` still return `Qx.Draw.Image`. Only the SVG string content changes.
- Recorded in CHANGELOG `[Unreleased]` at CHANGELOG.md:36-37, in the existing "Every drawing has a new look" bullet (lines 20-26). That bullet already warns that readers of the SVG markup must check their code against the new output. The diff changes line 36 to "no outline (the darker rim of the shading is its edge)".
- Breaking marker not needed. 0.12.0 shipped the silhouette outline. The new look is already a documented content change under "Changed", and no tier 1/2 contract moves. The only "Breaking:" items in this section are the option-validation raises (lines 61, 64).
- Minor note, not a violation: the "Bloch sphere" bullet could say a `silhouette` `<g data-part>` group is gone. The general markup warning at lines 24-26 covers it.

## #1 Atoms: PASS
- The diff adds no `String.to_atom`, `Module.concat`, `binary_to_atom` or `list_to_atom`. The grep of bloch.ex found none.
- The new stop uses `Theme.color(:back)` (bloch.ex:281). It is a fixed theme atom, and theme.ex:14 and :27 define `back` as `#A9B1BD`. The test at bloch_style_test.exs:157 expects that value.

## #5 Host loops: PASS
- The diff only removes `silhouette/1` (a single `<circle>`) and adds one `<stop>` string. No loop or `Enum` call is added. The remaining `for`/`Enum` uses in bloch.ex (299-539) are untouched, and none iterates over `2^n` amplitudes.

## #7 Typed errors: PASS
- The diff adds no `raise` and no error path. The existing raises (bloch.ex:154-170) are `Qx.StateShapeError` and `Qx.StateNormalizationError` and are unchanged.

## Other
- The `@silhouette_stroke` attribute, the `silhouette/1` function and its `group` call were all removed. A grep for `silhouette` across `.ex`/`.exs`/`.md`/`.livemd` found only plan files plus the refute in bloch_style_test.exs:168, so nothing is left dangling.
- The `bloch.ex:13-17` comment and the docstring at line 194 are updated.
- Not verified: compile, format, credo and tests, because I cannot run code.
