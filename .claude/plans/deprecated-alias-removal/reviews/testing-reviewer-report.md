# Test Review: feat/deprecated-alias-removal

## Summary

Reviewed the new `deprecated_alias_removal_test.exs`, the edited
`state_init_test.exs` / `state_init_vector_test.exs` pair, and the 15
`Qx.histogram` → `Qx.draw_histogram` renames in `test/qx_manual_test.livemd`.
The new negative/positive existence test is correctly scoped and arity-exact.
Cross-referencing the plan's documented deletion (`state_init_test.exs`
`describe "bell_state/2"` + `describe "ghz_state/2"`, ~210–330) against the
current `state_init_vector_test.exs` shows the canonical file already carries
equivalent or better assertions — including the sign checks and per-N
probability/normalization checks called out in the review brief. No unique
assertion was identified as lost. One verification limitation: this review
has no `git`/`Bash` access in this environment, so the "deleted describes
were duplicates" claim is corroborated via the plan.md line-range citation
and coverage diffing against the surviving file, not a literal `git diff`
of the removed hunk — flagged below as a residual verification gap for the
human merge-gate check.

## Iron Law Violations

None. Both test files use `async: true` (pure Nx/StateInit computation, no
shared/global state); no Mox, no DB, no factories involved.

## Issues Found

### Critical

None.

### Warnings

- [ ] **Unverifiable without git diff** — `deprecated_alias_removal_test.exs`
  and the plan (`.claude/plans/deprecated-alias-removal/plan.md:49-53`)
  assert the deleted `state_init_test.exs` describes were "duplicate
  coverage of the `_vector` path," but I cannot access `git show
  HEAD~1:test/qx/state_init_test.exs` (no Bash/git tool in this
  environment) to confirm the deleted assertions byte-for-byte. Mitigated
  by content comparison: `state_init_vector_test.exs:13-95` already covers
  everything the review brief flags as at-risk — all 4 Bell types with
  sign checks on the |11⟩/|10⟩ amplitude (`real_at/2`, lines 22, 32, 42,
  52), GHZ 2/3/4-qubit probability layout (lines 58-77), 5-qubit
  normalization (79-84), and `:c128` tensor-type coverage (88-94) for both
  constructors. Recommend the human spot-check the actual pre-removal diff
  at the merge gate per the plan's own "FLAGGED for override" note
  (scratchpad.md:12-13), since this was a default-approved (not
  human-reviewed) test edit.

- [ ] **Test-count arithmetic not independently reconciled** — the brief's
  1000 → 991 with 5 added (net −14) is internally consistent with "5 new
  existence tests added, some N deleted from state_init_test.exs," but I
  could not run `mix test` or `git diff --stat` to confirm the exact
  before/after count myself. Treat the 991 figure as reported by the
  orchestrator, not independently re-derived here.

### Suggestions

- [ ] `deprecated_alias_removal_test.exs:39-47` — the single "canonical
  replacements still exported" test only checks `bell_state_vector/2` and
  `ghz_state_vector/2` (the max-arity clause). `function_exported?/3` is
  arity-exact, so this doesn't confirm the default-arg clauses
  (`bell_state_vector/0`, `/1`) still exist — though those are exercised
  indirectly via direct calls in `state_init_vector_test.exs:15,26,36,46`,
  so there's no real coverage gap, just an asymmetry versus how thoroughly
  the *removed* aliases are checked (full arity range 0..2 / 1..2 asserted
  refuted, but only top arity asserted present). Consider adding
  `assert function_exported?(Qx.StateInit, :bell_state_vector, 0)` and `1`
  for symmetry — low priority, cosmetic.

- [ ] `Qx.histogram`'s removal is checked only via `function_exported?`
  (`deprecated_alias_removal_test.exs:29-35`) plus the livemd rename;
  neither is a `mix test`-executed rendering assertion. The actual
  rendering behavior underneath is still covered because
  `Qx.draw_histogram/2` is a `defdelegate ... to: Draw, as: :histogram`
  (`lib/qx.ex:1145`), and `Draw.histogram/2` error-path is covered by
  `test/qx/typed_errors_sweep_test.exs:103-106`. No action needed — noting
  this as the trace that closes the "canonical coverage" claim in the
  brief, since `draw_test.exs` itself has zero `histogram` references and
  could otherwise look like a coverage hole.

## Verdict

**APPROVE**, with the two Warnings above surfaced for the human to spot-check
at the merge gate (per the plan's own explicit flag that these test edits
were default-approved, not human-reviewed). No unique assertions were found
to be lost: the deleted alias-only describes in `state_init_test.exs` are
superseded by equal-or-greater coverage already present in
`state_init_vector_test.exs` (sign checks, per-N GHZ probabilities,
normalization, and `:c128` tensor-type variants all present). The 2
re-pointed integration tests keep their original assertions unchanged. The
15 livemd renames are a straight 1:1 API rename with no test-semantic
change.
