# Progress: calc-mode-demotion (/phx:full)

State: COMPLETED — merged to main as e1bb004 (2026-07-03), ROADMAP item ticked
Branch: feat/calc-mode-demotion @ 31c4024 (work committed), main at 0b06938.

## Log

- 2026-07-03 WORKING entered (plan was READY; discovery/planning done in the plan session).
- Phase 1 done: new test calc_mode_internal_test.exs (failed first, TDD),
  @moduledoc false + comment blocks on qubit.ex/register.ex, mix.exs docs
  group dropped, AGENTS.md Iron Law #6 lists updated ×2. Gate green
  (244 doctests + 1000 tests, doctest count unchanged — no moduledoc
  doctests existed).
- Phase 2 done: qx.ex moduledoc grid collapsed + Modules list + draw_bloch/
  draw_state docs+doctests rewritten to circuit mode; step.ex ×3,
  quantum_state.ex, errors.ex de-linked; draw.ex examples rewritten;
  draw_state @spec → `Nx.Tensor.t() | struct()`; CHANGELOG history handled
  via skip_undefined_reference_warnings_on. Docs warnings 198 → 54
  (baseline 110). bloch_sphere contract confirmed tensor-friendly
  (scratchpad RESOLVED).
- Phase 3 done: README (features, quick start, LiveBook tip, Inspecting
  States + migration note replacing the two-modes/calc sections, Working
  with Quantum States, Bloch sphere) + CHANGELOG Deprecated/Changed.
  Full gate green; docs warnings 46; zero hidden Qubit/Register refs.
- Committed 31c4024 on the feature branch.
- REVIEWING: elixir-reviewer, testing-reviewer, iron-law-judge all
  returned PASS (reports in reviews/). Findings all minor/non-blocking:
  draw_state @spec `struct()` breadth (deliberate), Code.fetch_docs
  7-tuple pin, pre-existing mix.exs docs-group gaps (Qx.Step ungrouped;
  4 error modules missing from Error Handling group — out of scope,
  ROADMAP-worthy).
- Branch pushed to origin (backup). STOPPED at merge gate: human
  authorizes `git merge --squash` + ROADMAP calc-mode tick.

## Metrics (so far)

| Metric | Value |
|--------|-------|
| Cycles | 1 |
| Phases | 3/3 implemented |
| Tasks completed | 15 (merge-gate item pending review) |
| Tasks blocked | 0 |
| Retries | 0 |
| Files modified | 12 |
| Tests added | 4 (1 new file) |
