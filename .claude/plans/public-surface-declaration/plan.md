# Declare Qx's public API surface to match reality

**Slug:** `public-surface-declaration`
**Branch:** `feat/public-surface-declaration`
**ROADMAP:** qx v0.8.1 — closes 4 items: #23 (public-api **S2 HIGH**),
#29 (arch LOW), #30 (public-api LOW), #24 (public-api LOW ×3).
**Type:** Documentation / governance. No code signatures change → no version bump.

## Problem

README and every tutorial alias-import `Qx.Qubit`, `Qx.Register`,
`Qx.StateInit`, `Qx.Patterns`, `Qx.Math`, `Qx.Hardware`, `Qx.Hardware.Config`,
`Qx.Export.OpenQASM`, and `Qx.Draw` as primary surface — yet Iron Law #6's
declared public surface lists only `Qx`, `Qx.QuantumCircuit`, `Qx.Operations`,
`Qx.Simulation`, `Qx.SimulationResult`, and `Qx.Behaviours.*`. A breaking change
to any of the nine **would not trip Iron Law #6 today** (the S2 HIGH gap).

Symmetrically, internal helper modules (`Qx.Draw.SVG.*`, `Qx.Export.OpenQASM`
sub-modules, `Qx.Hardware.Ibm`/`Portal`) render full HexDocs pages and read as
public when they are not.

## Decided constraints (do not re-litigate)

- **Scope = broad.** Declare the 9 public modules, resolve `Qx.StateInit`
  (→ public) and `Qx.Validation` (→ **internal**), AND mark the internal
  sub-modules `@moduledoc false`. One coherent commit; 4 ROADMAP ticks.
- **`Qx.Validation` → internal** (`@moduledoc false`, examples dropped). The
  public error contract is the typed `Qx.*Error` exceptions (their own doc
  pages), not the validation hub. It has **no** tutorial/README references.
- **`CLAUDE.md` is a symlink to `AGENTS.md`** — edit `AGENTS.md` once.
- **`lib/qx/draw/svg/circuit.ex` already has `@moduledoc false`** — verify and
  skip; only touch modules still missing it.
- **No doctest risk from the 12 Draw/Export/Hardware modules** — verified
  `iex>`-count 0 in every one. Only `Qx.Validation` carries doctests.
- **Expected doctest delta: 245 → 242.** Hiding `Qx.Validation`'s moduledoc
  removes its 3 moduledoc doctests; the `valid_qubit?`/`valid_register?`
  `@doc` doctests still run (`@moduledoc false` does not disable `@doc`
  doctests). `test/qx/validation_test.exs:3` keeps its `doctest Qx.Validation`.
- **No API/behaviour change** → no major bump. CHANGELOG: a short `### Changed`
  docs note only (HexDocs visibility shifts; see Phase 4).

## Iron Law check

- **#6:** This change *strengthens* Law #6 (widens the guarded surface). No
  signature changes; nothing breaking. CHANGELOG docs note added. ✅
- **#7 / #8:** No error paths or tolerances touched. ✅
- **anti-ai-writing-style.md** applies to every prose edit (AGENTS.md list
  entries, the `lib/qx.ex` `## Modules` list).

---

## Phase 1 — Declare the public surface (#23, #29)

- [x] [P1-T1] `AGENTS.md` (Iron Law #6): added the 9 modules to the breaking-
      change list; reworded to "any declared-public module" + the full surface
      list + an explicit internal-modules carve-out (Validation, Draw.SVG.*,
      Export.OpenQASM.*, Hardware.Ibm/Portal) and a note that `Qx.*Error` stays
      public even though `Qx.Validation` is not.
- [x] [P1-T2] `AGENTS.md` (complexity-score table "Changes public API of …"
      row): reconciled to reference the Iron Law #6 surface (all 14 modules).
- [x] [P1-T3] `lib/qx.ex` `## Modules` list: added `Qx.Register` (after Qubit),
      `Qx.StateInit` (after Math), `Qx.Hardware` + `Qx.Hardware.Config` (after
      Export.OpenQASM).
- [x] [P1-T4] `mix compile --warnings-as-errors` — clean.

## Phase 2 — Mark internal sub-modules `@moduledoc false` (#24)

> 12 modules; `draw/svg/circuit.ex` is already done — verify, then skip it.
> Each currently has a prose `@moduledoc """…"""`; replace the whole string
> with `@moduledoc false`. If a module's prose carries implementation notes
> worth keeping for maintainers, demote it to a leading `#` comment (don't just
> delete genuinely useful WHY context). None contain doctests → no test impact.

- [x] [P2-T1] `lib/qx/draw/svg/bloch.ex` → `@moduledoc false`
- [x] [P2-T2] `lib/qx/draw/svg/charts.ex` → `@moduledoc false`
- [x] [P2-T3] `lib/qx/draw/svg/circuit.ex` → `@moduledoc false`. **Review caught
      this:** the pre-existing `@moduledoc false` was on the nested
      `CircuitDiagram`, not the outer module — the outer module still had a
      26-line prose moduledoc. Now hidden (outer line 2 + nested both false).
- [x] [P2-T4] `lib/qx/draw/tables.ex` → `@moduledoc false`
- [x] [P2-T5] `lib/qx/draw/vega_lite.ex` → `@moduledoc false`
- [x] [P2-T6] `lib/qx/export/openqasm/ast.ex` → `@moduledoc false`
- [x] [P2-T7] `lib/qx/export/openqasm/codegen.ex` → `@moduledoc false`
- [x] [P2-T8] `lib/qx/export/openqasm/expr.ex` → `@moduledoc false`
- [x] [P2-T9] `lib/qx/export/openqasm/lowering.ex` → `@moduledoc false`
- [x] [P2-T10] `lib/qx/export/openqasm/parser.ex` → `@moduledoc false`
- [x] [P2-T11] `lib/qx/hardware/ibm.ex` → `@moduledoc false`
- [x] [P2-T12] `lib/qx/hardware/portal.ex` → `@moduledoc false`
- [x] [P2-T13] `mix compile --warnings-as-errors` — clean (11 recompiled, format OK,
      no orphaned triple-quotes; prose moduledocs replaced wholesale).

## Phase 3 — `Qx.Validation` → internal (#30)

- [x] [P3-T1] `lib/qx/validation.ex`: replaced the `@moduledoc """…"""` with
      `@moduledoc false`. `@doc` blocks on `valid_qubit?/1` and
      `valid_register?/1` intact.
- [x] [P3-T2] `test/qx/validation_test.exs` unchanged; `mix test` on it →
      **4 doctests, 49 tests, 0 failures** (the 3 moduledoc doctests dropped,
      4 `@doc` doctests remain; `doctest Qx.Validation` still valid under
      `@moduledoc false`).

## Phase 4 — CHANGELOG (`CHANGELOG.md`, `[Unreleased]`)

- [x] [P4-T1] Added a `### Changed` docs note under `[Unreleased]`: surface
      declared explicitly, internals (+ `Qx.Validation`) now `@moduledoc false`,
      no API change, `Qx.*Error` stays public.

## Verification (mandatory gate)

- [x] `mix compile --warnings-as-errors` — clean.
- [x] `mix format --check-formatted` — clean.
- [x] `mix credo --strict` — 0 issues (826 mods/funs).
- [x] `mix test` — green at the expected counts: **242 doctests** (was 245;
      −3 from hiding `Qx.Validation`'s moduledoc) and **916 tests**, 0 failures.
- [ ] (Optional) `mix docs` visual confirmation — deferred; doc rendering is
      mechanically determined by `@moduledoc false`, verified by compile.

## Out of scope

- Any code-signature or behaviour change to the declared-public modules.
- The "Which `h` am I calling?" decision-tree doc (separate v0.8.1 item).
- `Qx.Patterns.ghz_state_circuit` `@doc false`/merge (separate v0.8.1 item).

## Done = merge-ready

All phases checked, verification green at 242/916, `/phx:review` PASS (or
findings triaged). Squash-merge, tick the 4 ROADMAP lines (#23, #29, #30, #24)
in that commit, push `main`.
