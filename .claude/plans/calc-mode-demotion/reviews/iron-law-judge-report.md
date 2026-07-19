# Iron Law Judge Report — feat/calc-mode-demotion

## Summary

- Files scanned: 11 changed (AGENTS.md, CHANGELOG.md, README.md, lib/qx.ex,
  lib/qx/behaviours/quantum_state.ex, lib/qx/draw.ex, lib/qx/errors.ex,
  lib/qx/qubit.ex, lib/qx/register.ex, lib/qx/step.ex, mix.exs,
  test/qx/calc_mode_internal_test.exs)
- Iron Laws checked: 8 of 9 (laws #3/#4/#5/#8, Nx kernels) — confirmed n/a,
  no `defn`/tensor-kernel code touched
- Violations found: 0

**Verdict: PASS**

## Law-by-law findings

**#1 `String.to_atom/1`** — n/a. No occurrences added in this diff. Pre-existing
`String.to_atom` usages exist in `lib/qx/export/openqasm/lowering.ex` and
`lib/qx/export/openqasm/expr.ex`, but neither file is in the changed-files list
for this branch — out of scope for this review.

**#2 processes (GenServer/Agent/Task)** — n/a. No process code in the diff.

**#3/#4/#5/#8 Nx kernels** — n/a, confirmed. No `defn`, no `lib/qx/calc*.ex`
touched, no tensor gather/select or host-side amplitude loops introduced.
`lib/qx/qubit.ex` and `lib/qx/register.ex` are unchanged in body — only the
`@moduledoc false` + explanatory comment block was added above each
`defmodule`.

**#6 Public API surface** — PASS, and correctly executed:
- `AGENTS.md` law #6 text (line 393) now lists `Qx.Qubit` and `Qx.Register`
  under the internal/no-guarantee set, explicitly noting "the calc engine,
  demoted v0.10."
- The complexity-score table's Iron-Law-#6 surface list (line 329) does
  **not** include `Qx.Qubit`/`Qx.Register` — correct, since they were never
  meant to be in the *declared-public* list being defined there (that table
  enumerates the modules whose API changes score +3; it was already silent
  on the two calc-mode modules pre-demotion, so no edit was needed there).
- `mix.exs` `docs()/groups_for_modules` no longer lists `Qx.Qubit`/`Qx.Register`
  in any group — consistent with hiding them from generated docs.
- `Qx.Qubit` and `Qx.Register` both carry `@moduledoc false` (qubit.ex:7,
  register.ex:7) plus a comment explaining the demotion and pointing at the
  design doc.
- `CHANGELOG.md` has a `### Deprecated` entry (lines 35–41) stating the
  modules are demoted, hidden from docs, dropped from the declared public
  surface, carry no stability guarantee, but still compile/run/pass tests —
  correctly framed as **non-breaking** (no major-version bump required,
  consistent with `mix.exs` staying at `0.9.0`).
- `README.md` adds a "Upgrading from calc mode" migration section
  (README.md:131–144) mapping the old `Qx.Qubit`/`Qx.Register` pattern onto
  the stepper — matches the CHANGELOG's "Changed" entry.
- New test `test/qx/calc_mode_internal_test.exs` asserts both modules'
  docs are `:hidden` via `Code.fetch_docs/1` and that both remain fully
  functional (`Qx.Register.h/2`, `Qx.Qubit.h/1`) — directly verifies the
  "no stability guarantee but still works" claim instead of just asserting it
  in prose.
- Note (non-blocking, REVIEW confidence): `lib/qx.ex:1227` widens
  `@spec draw_state/2` from `Qx.Register.t() | Nx.Tensor.t()` to
  `Nx.Tensor.t() | struct()`. This avoids referencing the now-internal
  `Qx.Register.t()` type from a public spec, which is defensible, but
  `struct()` is maximally generic and no longer documents that a
  `Qx.Register` struct is what's actually accepted. Not a law violation
  (spec widening is backward-compatible, not breaking), but worth a
  reviewer's eye on whether a narrower type (e.g. a private `@type` alias)
  would preserve the doc value without re-exposing `Qx.Register.t()`.

**#7 Typed errors (`Qx.*Error`)** — n/a for this diff's behavior. `errors.ex`
changed only via `mix format`/context — no new raise sites, no new exception
modules, no changed `exception/1` clauses found relative to what one would
expect for a docs-only change. All existing exceptions still fall back to
`is_binary(message)` clauses and none leak raw `Nx`/`Complex`/`ArgumentError`.

**#9 Dispatch completeness** — n/a, confirmed. No dispatch arms
(`apply_instruction/3` or similar) appear in the changed-file list, and
`lib/qx/step.ex`'s diff is docs/typespec only (struct shape, `@type`
definitions unchanged in substance).

## Conclusion

This is a clean docs-and-visibility-only demotion. The Iron Law #6 paper
trail (AGENTS.md law text, CHANGELOG Deprecated entry, README migration
note, mix.exs doc groups, `@moduledoc false`, and a dedicated regression
test) is complete and mutually consistent. No STOP-worthy violations found.
