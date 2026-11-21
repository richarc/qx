# Testing review: feat/bloch-even-rim

Reported in chat by the testing-reviewer (it could not write this file);
recorded here by the orchestrating session. Read only; nothing was run.

**No BLOCKER, no WARNING, three SUGGESTIONs.**

- The rim test fails if the rim is removed, moved, given a stroke, or its
  start or opacity changes.
- The body test lost nothing: the "only circle of that radius" check is now
  `== [body, rim]`, which is stricter.
- `take(4)` / `drop(4)` on the stops are sound: document order.
- The other single-circle reads of `part("body")` still hold; the rim is in
  its own group.

Suggestions: check the rim radius at other sizes; assert the stop count
(done: `length(stops) == 6`); the id assertions are mild.
