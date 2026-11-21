# Test Review: test/qx/draw/bloch_style_test.exs (bloch-shaded-edge)

Verified by reading only; nothing was run.

## Summary
The change is sound. No BLOCKER and no WARNING. Three stale-text SUGGESTIONS.

## Answers
1. Ten redirected tests keep their intent. `body/2` (lib/qx/draw/svg/bloch.ex:287-290) emits cx/cy/r from `view.cx`, `view.cy` and `view.radius`. The removed `silhouette/1` used the same three values, so the numbers are identical. `part("body")` holds exactly one circle (bloch.ex:227). The gradient lives in `<defs>`, outside the group, so the `[x] =` single-element matches hold. Affected tests: lines 173/176/179, 228, 263, 274, 409, 440, 573/574.
2. The rewritten test (148-170) fails if the outline returns.
   - A `silhouette` group fails `refute "silhouette" in parts(svg)` (168).
   - A stroke on the body fails `refute Map.has_key?(body, "stroke")` (164).
   - A differently named ring circle of the same radius fails `[^body]` (169).
   - Dropping the rim stop fails the exact four-stop list equality (154-159). The 0.86 and 1 offsets and the colours are pinned.
   - `#A9B1BD` matches Theme `:back` and the test's `@back`. `#CBD3DD` is `:sphere_edge` (theme.ex:21).
3. `assert [^body] = Enum.filter(...)` is sound. The other circles are the centre dot (r = 2k, bloch.ex:389), the shadow foot (2.2k, bloch.ex:504) and the vector dot (5.5k, bloch.ex:573). None can equal r=134 at the default size. The pin compares the whole attribute map, so the check is strict.
4. No other test expects an outline. Grep of test/ for silhouette, outline and 1.5 found only the stale text below. circuit_style_test uses its own helpers and has no Bloch coupling. No vacuous passes found. Every `part("body")` read is still non-nil and single-element, and a nil part would crash `elements/2` rather than pass.

## BLOCKER
None.

## WARNING
None.

## SUGGESTION
- [ ] bloch_style_test.exs:4: moduledoc still says "a shaded body with a firm outline". Reword it to "a shaded body whose edge is shading alone".
- [ ] bloch_style_test.exs:147: `describe "body and outline"` is now misleading. Rename it, e.g. "body and edge".
- [ ] bloch_style_test.exs:239-240: the comment "which is on the outline" is stale. Say "on the edge of the body".
- [ ] Optional hardening: line 169 would not catch a ring drawn as `<ellipse>` or `<path>`. This is low risk. A `refute svg =~ "stroke-width=\"1.5\""` or an ink-stroked-circle check would close it.
