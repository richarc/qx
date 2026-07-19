# Plan: deprecated-alias removal — close the 0.8.x windows

**Slug:** deprecated-alias-removal
**Branch:** `feat/deprecated-alias-removal` (created from `main` at 1d5bfc3)
**Status:** DONE (merged e8d28b2, 2026-07-03)
**Depth:** standard
**Complexity:** 3 (2–3 lib files +2, breaking removal from declared-public modules +3, follows the 0.8.x deprecation-window precedent -2)
**ROADMAP:** the 3 unchecked v0.10 removal items (tick all 3 in the squash-merge commit)
**Scope guard:** qx repo only. Cross-repo audit 2026-07-03 (recorded in
ROADMAP): zero downstream usage in qxportal and kino_qx. No dep changes.

## Summary

Three deprecated aliases whose windows ("through 0.8.x"; "one minor
after `draw_histogram`") close in v0.10:

1. `Qx.StateInit.bell_state/0,1,2` + `ghz_state/1,2` → `_vector` names
   are canonical. Alias-only coverage lives in `state_init_test.exs`
   (`describe "bell_state/2"` 210–280, `describe "ghz_state/2"`
   282–330ish, plus 2 integration callers ~402/423); canonical coverage
   already exists in `state_init_vector_test.exs`.
2. `Qx.Math.basis_state/2` shim — zero callers anywhere (better than
   ROADMAP's "only internal callers remain").
3. `Qx.histogram/1,2` defdelegate — zero code callers;
   `test/qx_manual_test.livemd` calls it 16×.

All three are `@doc false` already, so no ex_doc surface changes are
expected; still run the `mix docs` warning-baseline check per AGENTS.md.

**Test-guard approval:** modifying the two existing test files is
required by the removal itself. AskUserQuestion timed out; proceeding on
the recommended default (delete duplicate alias describes, re-point
integration tests, rename livemd calls) — flagged for override at the
merge gate. See scratchpad DECISION.

## Phase 1: removals (TDD)

- [x] Write failing test `test/qx/deprecated_alias_removal_test.exs`:
      `refute function_exported?` for `Qx.StateInit.bell_state/0,1,2`,
      `Qx.StateInit.ghz_state/1,2`, `Qx.Math.basis_state/2`,
      `Qx.histogram/1,2`; `assert function_exported?` for the canonical
      replacements (`bell_state_vector/2`, `ghz_state_vector/2`,
      `StateInit.basis_state/3`, `draw_histogram/2`)
- [x] `lib/qx/state_init.ex`: delete the `bell_state` and `ghz_state`
      alias defs with their `@deprecated`/`@doc false`/comment blocks
- [x] `lib/qx/math.ex`: delete the `basis_state/2` shim + comment block
- [x] `lib/qx.ex`: delete the `histogram` defdelegate + `@deprecated` +
      `@spec` + comment block
- [x] `test/qx/state_init_test.exs` (APPROVED via default): delete
      `describe "bell_state/2"` and `describe "ghz_state/2"` (duplicate
      coverage of the `_vector` path); re-point the 2 integration tests
      at `bell_state_vector()` / `ghz_state_vector(3)` (assertions
      unchanged)
- [x] `test/qx_manual_test.livemd` (APPROVED via default): 16×
      `Qx.histogram(` → `Qx.draw_histogram(`
- [x] Verify gate: `mix compile --warnings-as-errors && mix format
      --check-formatted && mix credo --strict && mix test`

## Phase 2: CHANGELOG + doc sweep

- [x] Grep docs/README for the removed names (`StateInit.bell_state`,
      `StateInit.ghz_state`, `Math.basis_state`, `Qx.histogram`) —
      expect none outside CHANGELOG history; fix any found
- [x] CHANGELOG `### Removed` under `[Unreleased]`: the three aliases,
      each naming its canonical replacement and the closed window
- [x] `mix docs` warning count ≤ 46 (current main baseline)
- [x] Full verify gate
- [x] Iron Law check: #6 — breaking removals from declared-public
      modules (`Qx.StateInit`, `Qx.Math`, `Qx`) with CHANGELOG entries;
      pre-1.0 minor per ROADMAP's stated policy, no major bump. Others
      n/a (no kernels, no processes, no dispatch changes)
- [x] Merge gate: `/phx:review` PASS (or all findings triaged);
      squash-merge ticks the 3 ROADMAP removal items

## Risks

- **Test deletion loses coverage** — mitigated: `state_init_vector_test.exs`
  covers the canonical path; the deleted describes only exercised the
  delegating aliases.
- **Default-approved test edits** — the human can reverse at the merge
  gate; the diff keeps test changes isolated and reviewable.
- **Doctest/doc references to removed names** — Phase 2 grep + docs
  warning baseline catches stragglers.

## Verification (every phase)

```
mix compile --warnings-as-errors && mix format --check-formatted \
  && mix credo --strict && mix test
```
