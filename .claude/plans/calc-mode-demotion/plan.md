# Plan: calc-mode demotion — `Qx.Qubit` / `Qx.Register` become internal

**Slug:** calc-mode-demotion
**Branch:** `feat/calc-mode-demotion` (created from `main` at 0b06938)
**Status:** DONE (merged e1bb004, 2026-07-03)
**Depth:** standard
**Complexity:** 4 (crosses Draw/facade/docs boundaries +3, declared-public API change +3, follows the v0.8.1 `@moduledoc false` demotion precedent -2)
**Design:** `spec/unified-circuit-stepper-design.md` §"Reposition calc mode" (the "Still open: Calc mode's fate" question, resolved by interview 2026-07-03: internal engine, non-breaking)
**ROADMAP:** v0.10 calc-mode item (tick in the squash-merge commit)
**Scope guard:** qx repo only; the 6 qxportal tutorial rewrites are a
separate downstream item (tracked in ROADMAP; they matter only at the
v0.10 release). Full module removal is deferred to v1.0. No dep changes
(hex-library-researcher not applicable — nothing added).

## Summary

`Qx.steps/2` + `Qx.Step.show/1` now cover "inspect the state after each
operation" inside circuit mode, so calc mode's last unique value is
gone. Demote `Qx.Qubit` and `Qx.Register` to an internal engine:
`@moduledoc false`, out of the Iron Law #6 declared-public surface, out
of the docs/README, with circuit mode + stepper as the one documented
path. NON-BREAKING: both modules keep compiling, running, and passing
their existing tests untouched; learners' current notebooks keep
working. The "Which `h` am I calling?" grid collapses to one answer.

Inventory (2026-07-03 greps, this session):

- Hide: `lib/qx/qubit.ex` (826 lines), `lib/qx/register.ex` (846 lines)
- Facade: `lib/qx.ex` moduledoc "Which `h`" grid + `## Modules` entries
- Docs config: `mix.exs` `groups_for_modules` "Calculation Mode" group
- Public docs that autolink the demoted modules (each backticked ref
  becomes an ex_doc "references hidden module" warning once hidden):
  `lib/qx/behaviours/quantum_state.ex` moduledoc (Register named as the
  implementor, Qubit as deliberate non-implementor),
  `lib/qx/errors.ex` `Qx.RegisterError` docs, `lib/qx/draw.ex`
  `bloch_sphere/2` + state-table doc examples built on Qubit/Register
  pipelines
- Internal refs that need NO change: `lib/qx/calc.ex`,
  `lib/qx/format.ex`, `lib/qx/validation.ex` (all `@moduledoc false`
  already), `lib/qx/draw/tables.ex` `%Qx.Register{}` input clause
  (keeps working — module still exists)
- README: Features bullet, Quick Start (currently opens with
  `Qx.Qubit`!), "Understanding the Two Modes" (113–128), "Calculation
  Mode" (129–220), guidance bullet at 108, "Working with Quantum
  States" (393+) — audit and rewrite
- AGENTS.md: Iron Law #6 surface list ×2 (law text + complexity table)
- Existing tests: `register_test.exs`, `qubit_test.exs`, and ~10 files
  using them as helpers stay green UNTOUCHED. `@moduledoc false` does
  not disable `@doc` doctests; if either module carries doctests inside
  its `@moduledoc` string those examples vanish from the doctest count
  — acceptable, tests still pass (verify count change is explainable)

## Phase 1: visibility flip

- [x] Write failing test `test/qx/calc_mode_internal_test.exs`:
      `Code.fetch_docs(Qx.Register)` and `Code.fetch_docs(Qx.Qubit)`
      return `:hidden` module docs; both modules still function
      (`Qx.Register.new(2) |> Qx.Register.h(0)` evolves state;
      `Qx.Qubit.new() |> Qx.Qubit.h()` superposes — the non-breaking
      guarantee as an executable assertion)
- [x] `lib/qx/qubit.ex` + `lib/qx/register.ex`: `@moduledoc false` with
      a short `#` comment block (internal calc engine; demoted v0.10,
      design doc pointer; public path is circuit mode + `Qx.steps/2`).
      Preserve any `@moduledoc` doctest examples worth keeping by
      relocating into the relevant `@doc` (style contract applies)
- [x] `mix.exs`: drop the "Calculation Mode" `groups_for_modules` group
- [x] AGENTS.md: move `Qx.Qubit`/`Qx.Register` from the Iron Law #6
      declared-public list to the internal list (law #6 text AND the
      complexity-score table copy); note the stepper as the replacement
- [x] Verify gate: `mix compile --warnings-as-errors && mix format
      --check-formatted && mix credo --strict && mix test`

## Phase 2: public-doc sweep (no new ex_doc warnings)

- [x] Baseline `mix docs` warning count on the branch BEFORE changes
      (was 110 on main at 4830b51); after each edit the count must not
      exceed baseline
- [x] `lib/qx.ex` moduledoc: collapse the "Which `h` am I calling?"
      grid — circuit mode is the documented path; one short "internal
      engine" note replaces the calc column. Remove `Qx.Qubit`/
      `Qx.Register` from `## Modules`. Point state inspection at
      `Qx.steps/2` / `Qx.Step.show/1`
- [x] `lib/qx/behaviours/quantum_state.ex` moduledoc: reword so the
      public behaviour doc no longer autolinks hidden modules (plain
      prose, no backticked module refs, or de-link)
- [x] `lib/qx/errors.ex` `Qx.RegisterError`: de-link hidden-module
      references in docs (runtime message strings unchanged)
- [x] `lib/qx/draw.ex`: rewrite `bloch_sphere/2` and state-table doc
      examples over circuit mode (`Qx.create_circuit(1) |> Qx.h(0) |>
      Qx.get_state()` / a `Qx.Step` state). First CHECK what
      `bloch_sphere/2` actually accepts (`Bloch.qubit_to_bloch_
      coordinates/1` input contract) — if it takes only `%Qx.Qubit{}`,
      the example keeps a tensor-based path or the function gains a
      tensor clause ONLY if one already effectively exists; no
      behaviour change in this plan
- [x] Verify gate + `mix docs` warning count ≤ baseline
- [x] Iron Law check: #6 surface edit is the deliverable (additive
      contract shrink, CHANGELOG'd, non-breaking code); #7 untouched;
      no kernels touched (#3/#4/#5/#8 n/a); no processes (#2)

## Phase 3: README + CHANGELOG

- [x] README: Features bullet reframed (one mode + step-through
      inspection); Quick Start rewritten to circuit mode; "Understanding
      the Two Modes" + "Calculation Mode" sections replaced by a short
      "Inspecting states" pointer (stepper section already exists at
      §"Step Through a Circuit") plus a compact migration note
      (`Qx.Qubit.h |> show_state` → `Qx.create_circuit(1) |> Qx.h(0) |>
      Qx.steps() |> Enum.at(-1) |> Qx.Step.show()`); audit "Working
      with Quantum States" and guidance bullets; style contract
      (`anti-ai-writing-style.md`) applies to every word
- [x] CHANGELOG `### Deprecated` under `[Unreleased]`: `Qx.Qubit` and
      `Qx.Register` demoted to internal engine (hidden from docs, no
      stability guarantee, still functional; removal/restructure
      deferred to v1.0); `### Changed`: docs/README lead with circuit
      mode + stepper
- [x] Full verify gate + `mix docs` clean vs baseline
- [x] Merge gate: `/phx:review` PASS (or all findings triaged);
      squash-merge ticks the ROADMAP calc-mode item (the item's
      qxportal-tutorial precondition is a RELEASE gate, not a merge
      gate — restate it in the ROADMAP done-note)

## Risks

- **Doctest count drop**: `@moduledoc false` erases moduledoc-embedded
  doctests. Mitigation: relocate the valuable ones into `@doc`s;
  explain any residual count change in the phase log.
- **ex_doc hidden-ref warnings**: every backticked `Qx.Qubit`/
  `Qx.Register` in a public doc becomes a new warning. Mitigation: the
  Phase 2 sweep is inventory-driven (list above) + a final grep of
  public `@moduledoc`/`@doc` strings; warning-count baseline check.
- **qxportal learners**: unaffected until the v0.10 release; the
  release checklist (ROADMAP) carries the tutorial-rewrite gate.

## Verification (every phase)

```
mix compile --warnings-as-errors && mix format --check-formatted \
  && mix credo --strict && mix test
```

Plus `mix docs` warning-count ≤ baseline in Phases 2–3. TDD: the
Phase 1 hidden/functional test written first and failing; existing
tests never modified (hook-enforced).
