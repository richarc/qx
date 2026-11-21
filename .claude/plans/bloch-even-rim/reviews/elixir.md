# Review: feat/bloch-even-rim (Bloch even rim)

Status: Approved. 0 BLOCKER, 0 WARNING, 2 SUGGESTION. Verified by reading only; nothing was run.

## Verified by reading
- Float interpolation (bloch.ex:46-47, 298-299): `"#{0.82}"` and `"#{0.32}"` use Elixir's shortest round-trip float formatting, which gives "0.82" and "0.32". Exponent form only appears for very small or very large magnitudes (around 1.0e-5 and below), so neither value is affected. The test asserts "0.82" and "0.32".
- `stop-opacity` is a valid presentation attribute on `<stop>`. `stop-color` is also valid there. The literal `"0"` and `"1"` offsets and opacities are fine.
- Id uniqueness (bloch.ex:277-280): body ids end in digits (e.g. `bloch-3000-1571--500`, where a negative phi gives a double dash). Rim ids end in `-rim`, so a rim id can never equal any body id. The rim id is derived from the body id, so the pair stays unique per state, size and phi. Two different spheres inlined on one page therefore share no id. Spheres with identical size, theta and phi share ids, but their defs are identical. This was already the case before the change.
- `r="50%"` with default `gradientUnits=objectBoundingBox` (bloch.ex:297): the circle's bounding box is 2r square and cx/cy 50% is its centre. A gradient radius of 50% of the box is exactly r, so offset 1 lands on the circle edge. No spreadMethod padding is visible and no pixel is clipped. The circle is a perfect square-box circle, so there is no aspect distortion.
- Leftovers: grep of `lib/` finds no `body(` or `gradient(` for the Bloch module. `body/2` is now `disc/2`, called at bloch.ex:232-233. `gradients/1` is the only caller of the rename. No dangling references.
- Muted colour: `Theme.color(:muted)` = #6B7482, matching the test's `@muted`.
- Layer order comment (bloch.ex:16) matches the emitted group order: body, rim, plane, ...
- CHANGELOG, docstring, livebook and manual-test wording ("an even, darker rim of shading") are consistent with the behaviour.

## SUGGESTION
1. bloch.ex:230-233: `gradient_id(size, theta, phi)` is computed three times (lines 230, 232, 233). Bind it once, for example `id = gradient_id(...)` before the list. This is cosmetic; the original code already called it twice.
2. bloch.ex:282-287 (comment): "Together they are the sphere's outline" is slightly loose. The rim is only an overlay, and the body's own lower-right shading still carries part of the edge. It is accurate enough, but "Together they make the edge" would be tighter.
