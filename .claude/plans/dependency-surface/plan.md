# Widen the runtime dependency surface (nx/complex/req) + resolve the exla/emlx story

**Slug:** `dependency-surface`
**Branch:** `feat/dependency-surface`
**ROADMAP:** qx v0.9 (Security & Hardening), Group D — deps LOW + deps MED. **Last v0.9 item.**
**Approach:** empirical-probe-first (a dep bump is verify-driven; the 944-test
suite + bench is the real gate). Researched latest versions, then bumped and let
compile/test/bench tell the truth.

## Outcome — clean bump, no functional impact

### Part 1 — exla/emlx "optional" story (option (a): delete)
- Qx **never calls** `EXLA.*`/`EMLX.*` — they appear only as a pass-through
  `:backend` option value in docstrings + the README acceleration guide. So there
  is nothing to `Code.ensure_loaded?`-guard.
- [x] Deleted the two dead commented `optional:` deps from `mix.exs`.
- [x] Clarified the EXLA docstrings (`simulation.ex`, `qx.ex` ×3) to state EXLA is
      a user-added dep (closes the coupled v0.11 `UndefinedFunctionError` item).

### Part 2 — widen dep specs
- [x] `nx ~> 0.10 → ~> 0.12` (locked 0.10.0 → 0.12.1).
- [x] `complex ~> 0.6 → ~> 0.7` (0.6.0 → 0.7.0) — **mandatory**: nx 0.12.1 requires `complex ~> 0.7`.
- [x] `req ~> 0.5 → ~> 0.6` (0.5.18 → 0.6.2; pulled finch 0.22 → 0.23).

### Verification
- [x] `mix deps.get` — resolved clean, no conflicts.
- [x] `mix compile --force --warnings-as-errors` — clean, **no deprecations** from any bump.
- [x] `mix test` — 944 tests: the only fallout was **2 `Qx.Math` doctests** that
      hard-coded Nx's *old* verbose f32 rendering (`0.7071067690849304`); Nx 0.12
      prints f32 at native precision (`0.70710677`) — **identical values**.
      Updated both doctest strings (`lib/qx/math.ex`) → **0 failures**.
- [x] Scanned `lib/` for other verbose-f32 doctest strings — none (no latent brittleness).
- [x] `mix format` / `mix credo --strict` — clean (0 issues).
- [ ] `mix bench` — running; sanity-check the GHZ/QFT/renorm kernels aren't
      regressed (no stored 0.10 baseline, so this is a "runs at normal speed" check).

## Decisions (do not re-litigate)
- exla/emlx = **delete** (not uncomment+guard): nothing in Qx references those
  modules, so `optional:` deps would be pure noise.
- The `defn` kernels (`calc.ex`, `calcfast.ex`, `math.ex`) needed **no changes** —
  nx 0.12 changed only float32 tensor *display*, not numerics or the tensor API
  Qx uses (reshape/contraction/take/`:c64`).

## Iron Laws
- #3/#4/#5/#8 (Nx kernels): re-verified — full suite green incl. exact gate
  matrices, norm guards, and the f32 tolerance tests. No sub-ε tolerance changes.
- #6 (public API): no API change; the min-version raise is a `### Changed`
  CHANGELOG entry (consumers now need nx 0.12+).

## Files changed
`mix.exs`, `mix.lock`, `lib/qx/math.ex` (2 doctests), `lib/qx/simulation.ex` +
`lib/qx.ex` (EXLA docstrings), `CHANGELOG.md`, `ROADMAP.md`.

## Done = merge-ready
Bench sane → `/phx:review` → squash-merge (all 3 ROADMAP items ticked) → push.
**Then v0.9 is fully checked → release 0.9.0** (release-manager).
