# Documentation refresh for v0.8 additions

**Branch:** `docs/0.8-refresh`
**Source:** User request — "check that documentation is updated in line
with the recent changes. Including any necessary changes to `README.md`
(don't make large changes to `README.md` — only where it makes sense in
context of the new functionality added). Check that ExDoc is also up to
date."

**Target version:** Documentation work folds into the unreleased `0.8.0`
release scope. No `mix.exs` version bump; no CHANGELOG entry needed
(this is doc-only).

## Recent functionality being audited

Two merges that landed on `main` since the last doc pass:

1. **`circuit-helpers` (commit `8e9f346`)** — new `Qx.Patterns` module
   with 7 composite helpers (`h_all/1`, `x_all/1`, `y_all/1`, `z_all/1`,
   `measure_all/1`, `barrier_all/1`, `cx_chain/2`), all delegated from
   the top-level `Qx` module.
2. **`qaal-parity` (commit `69efeca`)** — QAAL parity additions:
   - **A1**: 4 controlled rotation gates (`cy/3`, `crx/4`, `cry/4`,
     `crz/4`) in `Qx.Operations` + top-level delegates + OpenQASM
     round-trip.
   - **A2**: 3 basis-explicit measurement helpers (`measure_x/3`,
     `measure_y/3`, `measure_z/3`) in `Qx.Operations` + top-level
     delegates.
   - **B1**: `/2` overload for every `Qx.Patterns._all/1` helper,
     accepting a list or `Range.t()` of qubit indices.

## Audit findings (pre-plan survey)

### `README.md`
- **L21 (Features bullet, gates list):** `H, X, Y, Z, S, S†, T, RX, RY,
  RZ, CNOT, CZ, CP, SWAP, iSWAP, U …, CSWAP (Fredkin), and Toffoli`
  — *missing* the 4 new controlled rotations (`CY`, `CRX`, `CRY`,
  `CRZ`). **Must fix.**
- **L11–26 (Features section):** no mention of `Qx.Patterns` composite
  helpers or basis-explicit measurement. **Should add** one tight
  bullet each (no large additions).
- **L220–263 (Circuit Mode section):** the Bell-state example uses
  `Qx.h(0) |> Qx.cx(0,1) |> Qx.measure(0,0) |> Qx.measure(1,1)`. Could
  be tightened to `|> Qx.measure_all()`, but the existing form is
  already pedagogically clear and changing it removes the explicit
  per-qubit measurement pattern users learn first. **Decision: leave
  the canonical example unchanged.**
- **L286+ (Examples section):** would benefit from a small example
  showcasing `Qx.Patterns` (e.g. GHZ-3 with `cx_chain`) and/or a
  controlled rotation (e.g. CRz in a mini phase circuit). **Add at
  most one short example block; do not bloat.**
- **No `Installation` section change** — `qx_sim` dep still pins
  `~> 0.6.0` in the README (this predates 0.7/0.8 releases and is a
  *separate* documentation-debt item, not in scope for this plan).

### ExDoc (`mix.exs`, module-level docs)
- **`mix.exs` `groups_for_modules`:** `"Composite Patterns":
  [Qx.Patterns]` already present (added in `circuit-helpers`). ✅
- **`Qx.Patterns` `@moduledoc`:** updated in `qaal-parity` to mention
  the `/1` + `/2` dual-arity. ✅
- **`Qx` top-level `@moduledoc`:** updated to list both the new gates
  and the `Qx.Patterns` sub-register overload. ✅
- **`Qx.Operations` `@moduledoc`:** **not updated**. Still reads:
  *"single-qubit gates (H, X, Y, Z), two-qubit gates (CNOT), and
  three-qubit gates (CCNOT/Toffoli)"*. **Should update** to mention
  basis-explicit measurement and controlled rotations (it's
  pedagogically the discovery surface for those helpers).
- **`@doc` and `@spec` coverage for every new public function:**
  verified during `qaal-parity` work — every new helper has
  docstring + spec + at least one doctest. ✅
- **`mix docs` generation:** runs cleanly. Warnings present are
  **all pre-existing**:
  - "Illegal attributes ignored in IAL" on `lib/qx/operations.ex:223`
    — caused by an existing `rz` doctest `{:rz, [0], 1}` that ExDoc
    misreads as a markdown IAL block. Not introduced by recent work.
  - References to `LICENSE` / `ROADMAP.md` / `RELEASE.md` in some
    docstring links — files exist at the repo root but aren't in
    `mix.exs` `extras`. Pre-existing.
  - `Qx.bell_state/2` reference in CHANGELOG — pre-existing.
  - `Nx.default_backend/2` reference in CHANGELOG — pre-existing.
  - `Qx.Hardware.ConfigError.t()` / `NoMeasurementsError.t()`
    undefined-type warnings — pre-existing.
  **Decision: out of scope for this plan.** None of these were
  introduced by `circuit-helpers` or `qaal-parity`. Tracked
  separately if the user wants to address them.

### Other doc surfaces
- **`CHANGELOG.md`** — `## [0.8.0]` `### Added` already lists
  `Qx.Patterns`, controlled rotations, basis-explicit measurement,
  and the `/2` overload. ✅
- **`ROADMAP.md`** — v0.8 has ticked items for both `circuit-helpers`
  and `qaal-parity`; v0.9 has the `Qx.reset/2` entry from A3;
  Backlog has the A4 named-register entry; v0.8.1 has the new
  `validate_parameter!` typed-error follow-on. ✅
- **`spec/`** — `EXDOC_UPDATE_SUMMARY.md` and `README_UPDATE_SUMMARY.md`
  are historical artifacts of past doc-refresh passes. Not part of
  the live documentation surface; not relevant here.
- **`CONTRIBUTING.md`** / **`RELEASE.md`** / **`AGENTS.md`** —
  process docs; no API changes touched the development workflow.
  No updates needed.

## Scope (what this plan changes)

| # | File | Change | Lines |
|---|---|---|---|
| 1 | `README.md` (L21) | Append `CY, CRX, CRY, CRZ` to the supported-gates bullet. | ~1 |
| 2 | `README.md` (L11–26, Features) | Add one bullet for `Qx.Patterns` composite helpers (whole-circuit + sub-register form). | ~1 |
| 3 | `README.md` (L11–26, Features) | Add one bullet for basis-explicit measurement (`measure_x` / `measure_y` / `measure_z`). | ~1 |
| 4 | `README.md` (Examples section, after Bell State) | Add a short "GHZ State" example using `Qx.h(0) |> Qx.cx_chain([0,1,2]) |> Qx.measure_all()`. | ~10 |
| 5 | `lib/qx/operations.ex` (`@moduledoc`) | Mention basis-explicit measurement and controlled rotations alongside the existing gate-category sentence. | ~2 |
| 6 | Verify `mix docs` still runs cleanly (same warning set as pre-plan baseline). | — | — |

**Net change budget: ~15 lines in `README.md`, ~2 lines in
`operations.ex`, no other files.**

## Out of scope (deferred / tracked elsewhere)

- **`README.md` Installation dep version pin (`~> 0.6.0`)** — separate
  doc-debt item; should be updated at the *next* hex release, not
  ahead of it. The current pin matches what's on hex.pm.
- **ExDoc IAL warning on `rz` doctest** — pre-existing markdown-
  parser quirk; not introduced by recent work.
- **Missing `LICENSE` / `RELEASE.md` / `ROADMAP.md` in `mix.exs`
  `extras`** — pre-existing; would require deciding which of these
  should ship in published docs vs. stay repo-only.
- **`Qx.bell_state/2`, `Nx.default_backend/2` reference warnings in
  CHANGELOG** — historical CHANGELOG entries that reference
  functions/arities that no longer exist or were never public.
  Editing historical CHANGELOG entries breaks reproducibility.
- **Tutorial updates in `qxportal/`** — cross-repo follow-on (the
  qaal-parity branch's plan already notes this for after the v0.8
  Hex release). Not in this qx-repo plan.

## Phases

### Phase 1 — README updates

- [x] **Update Features supported-gates bullet** (L21): append
      `CY, CRX, CRY, CRZ` to the gate list. Result: "Supports H, X,
      Y, Z, S, S†, T, RX, RY, RZ, CNOT, CY, CZ, CP, CRX, CRY, CRZ,
      SWAP, iSWAP, U …".
- [x] **Add Features bullet for `Qx.Patterns`**: one line, after the
      gates bullet, summarising "composite helpers (`h_all`,
      `measure_all`, `cx_chain`, …) with whole-circuit *and*
      sub-register (`0..2` / `[0,2]`) forms."
- [x] **Add Features bullet for basis-explicit measurement**: one
      line, near the measurement bullet, summarising "X/Y/Z-basis
      measurement (`measure_x`, `measure_y`, `measure_z`) for direct
      QAAL-style transcription."
- [x] **Add a short GHZ-3 example block** under `## Examples`, after
      Bell State, using `cx_chain` + `measure_all`. Keep it concise
      (≤ 12 lines including comments and expected output).
- [x] Verify the README still renders cleanly:
      `mix format --check-formatted` (no Elixir change), and
      visual scan for markdown formatting consistency.

### Phase 2 — `Qx.Operations` moduledoc

- [x] Update `Qx.Operations` `@moduledoc` to mention basis-explicit
      measurement and controlled rotations alongside the existing
      gate-category sentence. One sentence; do not restructure the
      surrounding text.

### Phase 3 — ExDoc verification

- [x] Run `mix docs` and capture the warning set; confirm it
      matches the pre-plan baseline (no *new* warnings).
- [x] Open `doc/index.html` in a browser (or visual inspection of
      `doc/Qx.Patterns.html`, `doc/Qx.Operations.html`) to confirm
      the new helpers are visible in the navigation, the
      "Composite Patterns" group, and the top-level `Qx` module.
- [x] If `Qx.h_all`, `Qx.measure_x`, `Qx.cy`, etc. show up correctly
      with their docstrings, doctests, and `@spec`s — pass.

### Phase 4 — Verification gate

- [x] `mix compile --warnings-as-errors` (sanity: moduledoc change).
- [x] `mix format --check-formatted`.
- [x] `mix credo --strict` (no rule should fire on a docstring
      change, but confirm).
- [x] `mix test` (no test change; verifies doctests in updated
      moduledocs still pass).

## Verification gate (qx CLAUDE.md mandatory)

```
mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict
mix test
```

Plus the manual `mix docs` warning-diff check.

## Notes / Iron Law compliance

- **No code change.** This is pure documentation.
- **Iron Law #6** (public API surface) — N/A: no API change.
- **Iron Law #7** (typed errors) — N/A: no exception change.
- **No new tests required.** The doctests in `Qx.Operations` /
  `Qx.Patterns` / `Qx` for the new helpers are exercised by the
  existing `mix test` suite (264 doctests / 818 tests / 0 failures
  on the merged `main`).

## Risks

1. **Markdown formatting regressions in README** — bullet style and
   indentation must match the existing Features list exactly.
   Mitigation: read the surrounding bullets carefully before
   editing.
2. **Example block stretches the README** — the GHZ example must
   stay short (≤ 12 lines). If it grows, drop it; the Bell State
   example already covers the patterns idiom for newcomers.
3. **`Qx.Operations` moduledoc rewording could accidentally change
   doctest line numbers cited elsewhere** — the IAL warning is
   already on line 223 of that file; an insert above line 223
   shifts that warning's line number. Mitigation: insert the new
   sentence into the existing introduction paragraph rather than
   adding a new paragraph above it, so line numbers stay stable
   for the doctest section.

## Stop conditions

Per qx CLAUDE.md: skill stops at the merge gate after `/phx:review`
PASS (or all findings triaged). Human authorizes the squash-merge.

Given this is a doc-only plan with ~17 lines net change, the
`/phx:review` step can be downgraded — a single `elixir-reviewer`
agent pass is sufficient (no testing-reviewer, no
security-analyzer).
