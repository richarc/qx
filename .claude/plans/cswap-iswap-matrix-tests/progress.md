# Progress: cswap-iswap-matrix-tests (/phx:full)

State machine: INITIALIZING → DISCOVERING → **PLANNING ✓** → WORKING →
VERIFYING → REVIEWING → COMPLETED → COMPOUNDING

## Current state: PLANNING complete — paused for fresh session

- [x] DISCOVERING — read qx-uos (read-only; bd deprecated), assessed
      complexity ~5, traced cswap/iswap consumers, found the cswap
      `{8,8,2}` vs iswap `:c64` repr split and that `Gates.cswap/4` has
      no simulation consumer.
- [x] PLANNING — `plan.md` + `scratchpad.md` written; 3 scoping
      questions answered by user (normalize cswap→c64; doc in both;
      branch created).
- [ ] WORKING — Phase 1 (normalize cswap/4), Phase 2 (docs),
      Phase 3 (matrix tests). NOT STARTED.
- [ ] VERIFYING — full gate.
- [ ] REVIEWING — /phx:review merge gate (hard stop).
- [ ] COMPOUNDING — extend testing-issues solution doc.

## Resume instructions (fresh session)

```
cd /Users/richarc/Development/qxquantum/qx
git checkout feat/cswap-iswap-matrix-tests   # already created, no commits yet
/phx:work .claude/plans/cswap-iswap-matrix-tests/plan.md
```

Branch `feat/cswap-iswap-matrix-tests` exists locally (0 commits;
`.claude/plans/` is gitignored so nothing to push yet). Start at
Phase 1 `[P1-T1]`. Read `scratchpad.md` first — it has the
low-risk rationale and the exact reference-matrix conventions.

Note: workspace CLAUDE.md prohibits TaskCreate — plan checkboxes +
this file are the single source of truth. The merge gate
(`/phx:review` PASS) is a hard stop for human authorization.
