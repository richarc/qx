# Plan: draw-rework — one static contract per draw function

**Slug:** draw-rework
**Branch:** `feat/draw-rework` (create from `main` at work start)
**Status:** READY — clean-break-in-v0.10 decided by Craig 2026-07-04
**Origin:** api-consistency-review findings T1-01, T1-02, T1-13, T1-14,
D-01..D-15 (Draw cluster) + principles §6 (environment independence,
artifact corollary, kino_* package boundary) + §7 bare-IEx test
**Complexity:** 8 (4+ files across Draw/facade/mix.exs +3, public API
change +3, dependency semantics +2) → comprehensive plan; the
api-consistency-review reports are the research corpus
**ROADMAP:** add to the **v0.10 section** at work start — this ships
IN v0.10 and the release waits for it (v0.10 is untagged, mix.exs is
still 0.9.0, and v0.9.0 itself is held: nothing after 0.8.1 is on
Hex, so there are no public users of the surface being broken)

## Summary

The Draw layer carries three incompatible return contracts across six
entry points: VegaLite structs, SVG strings, and a Kino-or-string
chameleon that sniffs `Code.ensure_loaded?(Kino)` on two format paths
and calls a module qx doesn't even declare as a dependency. The rework
gives every function one static return type, moves Livebook richness
to `Kino.Render` implementations behind an optional `kino` dep, aligns
the five-way facade/Draw naming split, and closes the facade gap that
forces the README into tier 2 for circuit drawing.

Strategy: **clean break, inside v0.10** (Craig, 2026-07-04). No
deprecation shims, no dual formats, no alias windows: old contracts
are deleted outright and the new ones are the only ones v0.10 ever
publishes. Rationale: nothing after 0.8.1 is on Hex and the rewritten
tutorials are themselves unreleased, so this is the last free window
for a breaking cut — a shimmed v0.11 would carry the debt into the
first surface real users meet. Iron Law #6 is satisfied by the
CHANGELOG `### Changed` (breaking) entries landing in the same
unreleased v0.10 block.

Decisions adopted with the clean break (from the Phase 0 review):
the contract table below as drafted; `vega_lite` becomes optional
with a typed missing-dependency error; chart-SVG's fate goes to the
Phase 0 inventory (zero real consumers → deleted, not deprecated).

## Phase 0: lock the contracts (decision gate — Craig signs)

- [ ] Usage inventory: every call site of each draw function and each
      `:format` value across qx (`examples/`, livebooks, README,
      doctests), qxportal (`priv/static/tutorials/`, guides), and
      kino_qx. Known so far: tutorials use `draw_bloch(format: :svg)`
      (BlochHelper) and rely on `draw_state`'s auto-Kino markdown;
      kino_qx calls `Qx.Draw.plot_counts/2` only
- [ ] Decide the per-function return-type table (recommendations
      below), record it in this plan, and add any surviving
      exceptions to `spec/api-design-principles.md` §6
- [ ] Decide `vega_lite`: optional dep + typed
      missing-dependency error (recommended) vs keep hard
- [ ] Decide SVG story: `format: :svg` today is a separate hand-rolled
      generator, so it cannot become a post-hoc converter of VegaLite
      specs. Recommended: SVG stays, as its own statically-typed
      access path (see table), and the Bloch SVG remains primary
      (v0.11 already plans its visual upgrade)
- [x] Breaking strategy: RESOLVED — clean break inside the
      unreleased v0.10 (Craig 2026-07-04); loud CHANGELOG breaking
      entries in the v0.10 block satisfy Iron Law #6

### Recommended contract table (Phase 0 confirms or amends)

| Facade | Returns (always) | Livebook richness via |
|---|---|---|
| `draw/2` | `VegaLite.t()` | kino_vega_lite (existing) |
| `draw_counts/2` | `VegaLite.t()` | kino_vega_lite |
| `draw_histogram/2` | `VegaLite.t()` | kino_vega_lite |
| `draw_bloch/2` | `%Qx.Draw.Image{}` (SVG inside) | `Kino.Render` impl |
| `draw_state/2` | `%Qx.Draw.StateTable{}` | `Kino.Render` impl |
| `draw_circuit/2` (new delegate) | `%Qx.Draw.Image{}` | `Kino.Render` impl |

The two structs are the artifact pattern from principles §6: plain
data, `Inspect` shows the text/table form in IEx, `Kino.Render` shows
the rich form in Livebook, `String.Chars`/accessor exposes the raw
SVG/markdown for standalone apps writing files. One static type per
function in every environment, and the bare-IEx test passes by
construction. `format:` options that switch return kind are deleted outright —
no shims (clean-break decision above).

## Phase 1: dependency + protocol plumbing

- [ ] `mix.exs`: add `{:kino, "~> 0.12", optional: true}`; flip
      `vega_lite` to `optional: true` (per Phase 0)
- [ ] Conditional-compilation scaffolding for optional-dep protocol
      impls (compile `defimpl Kino.Render` only when Kino is present);
      must stay clean under `--warnings-as-errors` both with and
      without the optional deps
- [ ] Typed `Qx.MissingDependencyError` raised by VegaLite-returning
      functions when `vega_lite` is absent — message names the fix
      ("add {:vega_lite, \"~> 0.1\"} to your deps")
- [ ] Delete the undeclared `apply(Kino.Markdown, :new, ...)` calls
      and `kino_available?/0` from `lib/qx/draw/tables.ex` (the §6
      package-boundary violation)

## Phase 2: draw_state / StateTable

- [ ] `%Qx.Draw.StateTable{}` struct: text + markdown renderings as
      data; `Inspect` impl (text table), `Kino.Render` impl
      (markdown), accessor for embedding
- [ ] `draw_state/2` returns the struct always; the `:format`
      option is deleted; `:text`/`:markdown` renderings live on the
      struct as fields/accessors
- [ ] Facade `@spec`/docs corrected (today's `String.t()` claim is
      false — T1-02); drop the tier 3 `Qx.Register` escape hatch from
      the tier 1 signature (T1-14; tier 2 may keep it)
- [ ] Tests: struct contract, Inspect output, Kino.Render presence
      gated on kino, no env sniffing anywhere (`grep ensure_loaded`)

## Phase 3: chart functions + naming + facade gaps

- [ ] `draw/draw_counts/draw_histogram` return `VegaLite.t()` only;
      chart `format: :svg` deleted or re-homed per the Phase 0
      inventory — no shims
- [ ] `draw_bloch` → `%Qx.Draw.Image{}` per table (or as Phase 0
      amends); tutorials' `format: :svg` call sites accounted for in
      the cross-repo sweep
- [ ] Add `Qx.draw_circuit/2` delegate (README currently drops to
      tier 2 for it — D finding)
- [ ] Align the five-way naming split: tier 2 `Draw` function names
      match their facade delegates (final table confirmed in Phase 0);
      old names deleted outright — kino_qx's `Draw.plot_counts` call
      site updates in the Phase 6 sweep
- [ ] Fix tier 1 doc cross-references (`histogram/2` → 
      `draw_histogram/2`, T1-13)

## Phase 4: Kino.Render for the taught structs

- [ ] `QuantumCircuit` → circuit SVG in Livebook (renders the diagram
      when a cell returns a circuit — the single biggest tutorial
      quality win)
- [ ] `SimulationResult` → counts summary/table
- [ ] `Step` → the `Step.show/1` map as a table (keeps the existing
      `Inspect` one-liner)
- [ ] Tests for each impl, plus a no-kino compile/test lane so the
      optional path stays honest (CI matrix or a `mix test` run with
      `--exclude kino` mirroring the qiskit-tag pattern in qxportal)

## Phase 5: docs

- [ ] "Using Qx outside Livebook" guide section (README or guides/):
      what each artifact type is and what to do with it standalone —
      the single owner the principles §6 docs rule requires
- [ ] First-paragraph Livebook notes on every draw doc; `## Returns`
      on all six
- [ ] Bare-IEx pass over every tier 1 doc example (§7 test)
- [ ] CHANGELOG: `### Added` (structs, delegates, protocol impls,
      optional deps), `### Deprecated` (old names/formats),
      `### Changed`/breaking notes per the Phase 0 decision

## Phase 6: cross-repo sweep

- [ ] qxportal: run `scripts/validate_tutorial.exs` on all 6 tutorials
      against path qx; update `BlochHelper` cells if `draw_bloch`'s
      contract changed; re-run calc grep
- [ ] kino_qx: compile + tests against path qx (`Draw.plot_counts`
      rename shim must keep it green)
- [ ] **Release coupling (resolved by the clean-break decision):**
      the rewritten tutorials are themselves unreleased (qxportal
      `feat/tutorial-stepper-rewrite`, awaiting merge). Update their
      draw call sites (`BlochHelper`, `draw_state` cells) against the
      new contracts BEFORE either release, re-run the tutorial
      harness, and the `~> 0.10` pin is then simply correct. qx v0.10
      must not be tagged until this plan and the tutorial updates are
      both done — note in both repos' ROADMAPs

## Phase 7: verify + merge gate

- [ ] `mix compile --warnings-as-errors && mix format
      --check-formatted && mix credo --strict && mix test` (+ the
      no-kino lane) + `mix docs` warning count ≤ baseline
- [ ] Review: elixir-reviewer + testing-reviewer + iron-law-judge;
      human authorizes squash-merge

## Risks

- **v0.10 grows a second gate.** The release already waits on the
  qxportal tutorial rewrite; it now also waits on this plan. That's
  the price of the clean break, accepted deliberately — the
  alternative was shipping a Draw surface we already know is wrong
  and shimming it forever.
- **Optional-dep compilation.** Protocol impls behind optional deps
  are fiddly under `--warnings-as-errors`; the no-kino test lane
  exists to keep both worlds honest.
- **Tutorial double-touch.** The just-rewritten tutorials get a
  second, smaller edit (draw call sites). Contained: the harness
  re-validates all 6 files in minutes.

## Verification (every phase)

Standard gates after each phase; Phase 4 onward also runs the no-kino
lane. No ExUnit surface exists for "renders nicely in Livebook" — the
Phase 6 manual Livebook pass on one tutorial + kino_qx smoke is the
human gate for the protocol impls.
