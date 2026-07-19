# Iron Law judge report — feat/draw-rework (git diff main...HEAD)

Date: 2026-07-04
Scope: Iron Laws #2, #6, #7 + declared-surface bookkeeping + optional-dep
hygiene, per the review brief. Baseline audience for #6: a 0.8.1 Hex user
upgrading to 0.10 (clean-break decision recorded in plan.md Phase 0,
Craig 2026-07-04; nothing after 0.8.1 is on Hex, v0.10 untagged).

## Verdict: PASS WITH WARNINGS

No Iron Law violation blocks the merge. Two CHANGELOG defects and one
surface-bookkeeping gap should be fixed before squash-merge; all are
small, mechanical edits.

---

## Iron Law #6 — public surface / CHANGELOG completeness

The clean-break governance is sound: the plan records the decision, the
breaking entries land in the same unreleased v0.10 block, and the
pre-1.0 SemVer position plus the recorded decision covers the
major-bump clause.

Break-by-break audit of the 0.8.1 draw surface against the Unreleased
CHANGELOG block (new entries + entries already on main):

| 0.8.1 surface | Break | CHANGELOG covers it? |
|---|---|---|
| `Qx.draw/2`, `draw_counts/2`, `draw_histogram/2` | return narrowed to `VegaLite.t()`; `format: :svg` deleted | YES (Changed + Removed) |
| `Qx.histogram/1,2` alias | removed | YES (pre-existing Removed entry, same block) |
| `Qx.draw_bloch/2` | VegaLite-default → `%Qx.Draw.Image{}`; VegaLite Bloch projection deleted | YES (Changed + Removed) |
| `Qx.draw_state/2` | string / `%Kino.Markdown{}` chameleon → `%Qx.Draw.StateTable{}`; `:format` (:auto/:text/:html/:markdown) deleted | YES (Changed, explicitly names the sniffing) |
| `Qx.Draw.plot_counts`, `Qx.Draw.bloch_sphere` | renamed `counts`, `bloch` | YES (Changed, tier-2 rename entry) |
| `Qx.Qubit.draw_bloch` | rides the Image change | Covered by the Qubit/Register demotion entry (module no longer public) |
| `vega_lite` dep | now optional; typed raise when absent | YES (Changed) |
| **`Qx.Draw.circuit/2`** | **SVG `String.t()` → `%Qx.Draw.Image{}`** | **NO — see W1** |

### W1 (fix before merge): `Qx.Draw.circuit/2` return change not enumerated

The Changed entry lists five functions' new return types; `circuit` is
absent, and the Added entry only introduces the *new* `Qx.draw_circuit/2`
delegate. But `Qx.Draw.circuit/2` existed in 0.8.1 and its own docs
taught `svg = Qx.Draw.circuit(circuit, "My Circuit");
File.write!("circuit.svg", svg)` — that exact idiom now raises (writes a
struct). One line in the Changed breaking entry fixes it:
"`Qx.Draw.circuit/2` returns `Qx.Draw.Image` (was an SVG string)".

### W2 (fix before merge): CHANGELOG structural bug — orphaned Added entries

The new draw sections were inserted after the original `### Added`
header, ending with the new `### Removed` section. The pre-existing
Added bullets (`Qx.steps/1,2`, `%Qx.Step{}`, `Qx.Step.show/1`,
`tap_state` internals — CHANGELOG.md lines ~54-68) now sit **under
"### Removed"**, reading as if the stepper was removed in v0.10. The
block also now carries duplicate `### Changed` / `### Removed` /
`### Fixed` headers, which Keep a Changelog disallows per release.
Re-home the stepper bullets under the single `### Added` and merge the
duplicate headers.

### Minor (accepted): silent option ignore

`format: :svg` passed by a 0.8.1 caller is now silently ignored (chart
returned as VegaLite) instead of raising `Qx.OptionError`. The option
deletion is documented; the silent-ignore is a consequence of the clean
break. No action required, noted for completeness.

## Iron Law #7 — typed errors

- `Qx.MissingDependencyError` (lib/qx/errors.ex): correct shape —
  `defexception [:dependency, :message]`, `exception({dep, requirement})`
  carries the pattern-matchable `:dependency` atom and the message names
  the exact `mix.exs` line. Raised by `ensure_vega_lite!/0`
  (lib/qx/draw.ex:244) ahead of every `Qx.Draw.VegaLite` call, and that
  module compiles only when VegaLite is present, so no
  `UndefinedFunctionError` path exists. PASS.
- **W3 (warning):** zero tests exercise `Qx.MissingDependencyError`, and
  the comment at test/qx/typed_errors_sweep_test.exs:81 claims its
  "coverage lives in draw_contracts_test.exs" — no such test exists
  there (grep: no match for `MissingDependency` or `vega` in that file).
  The constructor is unit-testable with deps present
  (`Qx.MissingDependencyError.exception({:vega_lite, "~> 0.1"})`).
  Either add that test or correct the stale comment (test edits need
  the human's approval per the test-file guard).
- `@enforce_keys` on `Qx.Draw.Image`/`Qx.Draw.StateTable`: raises only
  when a caller hand-builds the struct literal — standard struct
  semantics, and every public path populates all keys
  (Draw.bloch/circuit, Tables.render). Not an API-boundary leak. PASS.
- Pre-existing raw errors, not introduced by this diff but now
  reachable from tier 1: `Qx.draw_circuit/2` with a non-circuit raises
  `FunctionClauseError` (the `%Qx.QuantumCircuit{} =` head in
  `Qx.Draw.circuit/2`), and `draw_bloch/2` with a wrong-shaped tensor
  hits `[alpha, beta] = Nx.to_flat_list(qubit)` (MatchError) in
  `Qx.Draw.SVG.Bloch.qubit_to_bloch_coordinates/1`. Follow-up
  candidates for a scratchpad/ROADMAP line, not blockers here.
- `Tables.render/2` invalid input still raises typed `Qx.RegisterError`. PASS.

## Iron Law #2 — no processes

PASS. Grep of the full diff for GenServer / Agent / Task / spawn /
start_link: no hits. The `Kino.Render` impls build structs and delegate
to `Kino.Render.to_livebook/1`; no process is started by Qx code.

## Declared-surface bookkeeping — W4 (fix before merge)

`Qx.Draw.Image` and `Qx.Draw.StateTable` are new public modules (public
`@moduledoc`, documented return types of tier-1 functions) but are
missing from:

1. the Iron Law #6 declared-surface list in qx `AGENTS.md`/`CLAUDE.md`
   (the list ends at `Qx.Draw` + `Qx.Behaviours.*`; the "everything
   else is internal" clause currently mislabels them);
2. `groups_for_modules` in mix.exs (Visualization group lists only
   `Qx.Draw`, so both structs render ungrouped in the docs sidebar);
3. `Qx.MissingDependencyError` is likewise absent from the mix.exs
   "Error Handling" docs group, which lists every other `Qx.*Error`.

The surface list drives the complexity scorer and future reviews;
update all three at the same time.

## Optional-dependency hygiene

PASS. mix.exs declares `{:kino, "~> 0.12", optional: true}` and flips
`vega_lite` to `optional: true`. Every `Kino.*` call in lib/ sits
inside an `if Code.ensure_loaded?(Kino.Render)` block
(lib/qx/draw/image.ex:45, lib/qx/draw/state_table.ex:45,
lib/qx/draw/kino_render.ex:5); remaining `Kino` mentions are doc prose.
The undeclared `apply(Kino.Markdown, :new, ...)` calls and
`kino_available?/0` sniffing are deleted from lib/qx/draw/tables.ex.
`Qx.Draw.VegaLite` is compile-gated on `Code.ensure_loaded?(VegaLite)`
with the typed-error guard in front of every call site. Draw takes no
alias of `VegaLite`, so the guard checks the library module, not the
sub-module. `mix compile --warnings-as-errors` is clean on the branch.

## Warning summary

| # | Severity | Finding | Fix |
|---|---|---|---|
| W1 | Should-fix | `Qx.Draw.circuit/2` string→Image break missing from CHANGELOG | one line in the Changed breaking entry |
| W2 | Should-fix | Stepper Added entries orphaned under new `### Removed`; duplicate section headers | re-home bullets, merge headers |
| W3 | Minor | `MissingDependencyError` untested + stale pointer comment in typed_errors_sweep_test.exs:81 | add constructor test (with approval) or fix comment |
| W4 | Should-fix | Image/StateTable absent from declared-surface list + docs groups; MissingDependencyError absent from Error Handling group | update AGENTS.md list + mix.exs groups_for_modules |
