# Light review — dependency-surface (v0.9 Group D, LAST v0.9 item)

**Branch:** `feat/dependency-surface`
**Mode:** light (diff inspection, not the 5-agent pass) — proportionate to a
mechanical dep-spec widen with a fully green suite.
**Verdict:** ✅ **PASS** — one finding found and fixed during review.

## Diff reviewed (10 files)

`mix.exs`, `mix.lock`, `lib/qx/math.ex` (2 doctests), `lib/qx/simulation.ex`,
`lib/qx.ex` (×3 backend docstrings), `README.md`, `CHANGELOG.md`, `ROADMAP.md`.

## Checks

- **Spec bumps correct**: nx `~> 0.12` (0.12.1), complex `~> 0.7` (0.7.0, *required* by
  nx 0.12), req `~> 0.6` (0.6.2). `mix.lock` resolved clean (transitive finch 0.22→0.23,
  plug 1.19→1.20 test-dep). ✓
- **Doctest edits value-preserving**: `0.70710677` is the f32 nearest 1/√2; the old
  `0.7071067690849304` was its f64 expansion. Same value, Nx 0.12 renders f32 at native
  precision. Suite confirms. ✓
- **exla/emlx**: dead commented deps removed; Qx never calls those modules, so nothing to
  runtime-guard (option (a) correct). Code docstrings clarified (no em-dashes). ✓
- **Iron Laws #3/#4/#5/#8** (Nx kernels): full suite green incl. exact gate matrices, norm
  guards, f32 tolerance tests; `defn` kernels unchanged; bench sane. No sub-ε tolerance
  changes. ✓
- **Iron Law #6**: no API change; min-version raise correctly a `### Changed` in a minor. ✓

## FINDING (fixed during review)

**[WARNING → FIXED]** `README.md` pinned `{:exla, "~> 0.10"}` in three install examples
(lines 615/763/789). With Qx now requiring `nx ~> 0.12`, a user copy-pasting `exla ~> 0.10`
(which depends on `nx ~> 0.10`) would hit a **dependency-resolution conflict**. The nx bump
introduced this; the code-only docstring pass missed the README. Updated all three to
`~> 0.12`. (EMLX uses `github: main`, no version pin → unaffected.)

## Pre-existing (not this diff — noted, not fixed)

- README install examples pin stale Qx versions (`{:qx_sim, "~> 0.8.0"}`,
  `{:qx, "~> 0.6.0"}`) while Qx is at 0.8.1 → 0.9.0. Doc drift predating this change; best
  swept during the 0.9.0 release README refresh, not here.

## Verification (final, all changes in place)

compile `--warnings-as-errors` clean · format OK · credo `--strict` **0 issues** ·
**242 doctests + 944 tests, 0 failures** · `mix bench` completed, kernels at normal speed.

## Result

PASS. Mergeable. **This is the last v0.9 item → merging completes the v0.9 milestone
(0.9.0 release cue).**
