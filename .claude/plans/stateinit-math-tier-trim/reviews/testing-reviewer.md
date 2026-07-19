# Testing Review: stateinit-math-tier-trim

## Files reviewed
- test/qx/tier_trim_test.exs (new)
- test/qx/math_test.exs (two describe blocks deleted)

## BLOCKER
(none)

## WARNING
- test/qx/tier_trim_test.exs — no test asserts that a deprecated function still *works* (returns a correct value / doesn't raise). The suite relies entirely on the pre-existing describe blocks in math_test.exs / state_init_test.exs (which are untouched and still call e.g. `Math.kron/2`, `Math.trace/1`, `StateInit.zero_state/2` for correctness) to cover that. This is true today but the coupling is implicit — nothing in tier_trim_test.exs documents or enforces "deprecated ⇒ still functional until 1.0" as a property. Consider one `describe "deprecated functions still work"` block (or a comment pointing at math_test.exs/state_init_test.exs) so a future edit that guts those correctness tests doesn't silently lose the "must still work" guarantee this trim depends on.
- test/qx/tier_trim_test.exs:37-44 and 62-69 — the `is_binary(meta[...])` assertion only checks *a* deprecation message exists, not that it's non-empty/meaningful (e.g. it would pass for `@deprecated ""`). Minor; `String.trim(msg) != ""` or a length check would be stricter given the plan promises each notice "carries a drop-in replacement."

## SUGGESTION
- test/qx/tier_trim_test.exs — `Code.fetch_docs/1` is the right mechanism (it inspects compiled `@deprecated` metadata directly, matching how `mix docs`/Hex/IDE tooling actually surface deprecation, unlike grepping source). Good choice over source-text grep.
- The trim list (8 Math / 9 StateInit) was cross-checked against lib/qx/math.ex and lib/qx/state_init.ex: every `@deprecated` function in both modules is covered by `@math_deprecated`/`@state_init_deprecated`, and the arities match doc-entry max arity (functions with default args, e.g. `zero_state/2`, `bell_state_vector/2`, appear once at max arity as the test comment notes). No misses found. `Qx.Math.complex_matrix/1` (internal, `@doc false`, not deprecated) and `Qx.Math.normalize/1`/`probabilities/1`/`StateInit.basis_state/3` (survivors) are correctly excluded.
- test/qx/math_test.exs deletion: the `complex_to_tensor/1` and `tensor_to_complex/1` describe blocks (old 209-237) tested functions that no longer exist in lib/qx/math.ex — confirmed via Read; no dead references remain. No coverage loss: these were pure internal converters with no other callers exercising them, and their removal is asserted by `tier_trim_test.exs:53-58` (`refute function_exported?/3`). Deletion is correctly paired with a positive assertion of absence rather than just silently vanishing.
- All 8 Math and 9 StateInit deprecated functions remain fully correctness-tested in their original (unmodified) describe blocks in math_test.exs and state_init_test.exs — verified by reading both files. This is good: it means "deprecated but still works" is de facto covered, just not explicitly labeled as such (see WARNING above).
- `async: true` correctly used (pure functions, `Code.fetch_docs` reads compiled BEAM metadata, no shared/global state) — Iron Law 1 satisfied.
- No Mox/DB/LiveView surface in this file — not applicable.

## Pre-existing issues (not in scope, one-line each)
(none observed in the two changed files during this review — no unrelated pre-existing issues were flagged.)
