# Scratchpad: deprecated-alias-removal

## DECISION: test edits on the recommended default (2026-07-03)

Removing the aliases necessarily touches 2 hook-protected files:
`state_init_test.exs` (alias describes + 2 integration callers) and
`qx_manual_test.livemd` (16 `Qx.histogram` calls). AskUserQuestion timed
out (user away); proceeded on the recommended "Approve both" default —
delete the duplicate alias describes (canonical coverage exists in
`state_init_vector_test.exs`), re-point the integration tests, rename
the livemd calls. Same pattern as the calc-mode-demotion interview.
FLAGGED for override at the merge gate: if the human prefers re-pointing
the describes instead of deleting, it's a small follow-up.

## NOTE: comment contradicted ROADMAP

`lib/qx.ex`'s histogram comment said "removed in v1.0"; ROADMAP
schedules the removal for v0.10 ("one minor after draw_histogram
shipped", pre-1.0 breaking allowed). ROADMAP wins; the comment goes with
the alias.

## NOTE: Math.basis_state had zero callers

ROADMAP said "only internal callers remain"; by removal day even those
were gone (Format.basis_state and StateInit.basis_state are different
functions that match a bare `basis_state(` grep — don't be fooled).
