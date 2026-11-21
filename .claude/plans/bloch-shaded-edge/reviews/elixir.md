# Review: bloch-shaded-edge (feat/bloch-shaded-edge vs main)

Status: Approved with suggestions. No BLOCKER, no WARNING.

Verified by reading only (nothing was run).

## Verified clean
- lib/qx/draw/svg/bloch.ex: no `silhouette` or `@silhouette_stroke` remains. A grep of the repo, excluding .claude, _build and deps, finds `silhouette` only in the new `refute` at test/qx/draw/bloch_style_test.exs:168.
- Module attributes: every remaining attribute in the 26-79 range is still used. `@near_stroke`, `@far_stroke` and `@axis_stroke` are referenced by the half and axis code.
- Group-order comment, bloch.ex:15-17: now lists body, plane, far, axes-hidden, shadow, arcs, near, labels, vector, centre, axes, title, readout. This matches the `group(...)` calls at bloch.ex:~229-236.
- `Theme.color(:back)` exists. theme.ex:14 has `@back "#A9B1BD"`, theme.ex:27 has `back: @back`, and theme.ex:90 has `color/1` using `Map.fetch!`. `:sphere_mid` and `:sphere_edge` exist at theme.ex:32-33. The test's expected stops (`#EEF1F5`, `#CBD3DD`, `#A9B1BD`) match the theme values.
- The great-circle halves share end points through the point list itself (bloch.ex:308-324), not through the outline. The code never assumed the outline covered the joins.
- `axis_pieces` at bloch.ex:402-411 is pure geometry. Its variable `outline` means the sphere's projected silhouette radius, not the drawn stroke. Its logic is unaffected.
- Docs: lib/qx/draw.ex, lib/qx.ex and README.md contain no description of a Bloch outline. draw.ex:33 says "outlines" in the generic ink-chrome sense, not for the sphere.
- CHANGELOG.md:36 is accurate. The remaining wording at lines 36-39 (great circles solid near and dashed far, ink axes) still holds. No other CHANGELOG entry mentions a Bloch outline.

## SUGGESTION
1. bloch.ex:402-404: the comment says "comes out from behind the outline". After this change a reader may take "outline" to mean the removed stroke. The variable `outline` at bloch.ex:406 has the same problem. Consider "the sphere's edge" and `edge`. This is optional, because the meaning is the projected disc boundary.
2. bloch.ex:468 and bloch.ex:607 use "outline" for text halos and the hollow arrowhead. These are unrelated to the sphere and need no change.
3. notebooks/visual_design_guide.livemd, diff lines 86-87: the edited comment now has one over-long line. Re-wrap it.
4. Visual note only, since the design is decided. The gradient is anchored at cx=36%, cy=30%, r=75%. By my arithmetic from those values, the upper-left edge falls at offset of roughly 0.35, so it is nearly paper. On a white page that edge is faint. Only the lower-right edge reaches the 0.86 to 1.0 rim. Worth a quick look in Livebook. If the upper-left edge is too faint, the fix is a gradient tweak, not a code change.
