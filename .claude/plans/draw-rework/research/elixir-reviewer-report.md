# elixir-reviewer report — feat/draw-rework

**Scope:** commits 12a56c6 + 170bc47 vs main (draw-rework plan).
**Verdict: PASS WITH WARNINGS** — contracts, structs, and protocol
impls are correct and idiomatic; two plan claims about the optional-dep
lanes don't hold as written, plus a handful of doc leftovers.

## Verified working (evidence, not vibes)

- **Empirical no-dep consumer test** (scratch mix project, path dep on
  qx, no vega_lite/kino): qx compiles, `Qx.draw_circuit/2`,
  `Qx.draw_state/2`, `Qx.draw_bloch/2` all return correct artifacts,
  `Inspect`/`String.Chars` behave, and `Qx.draw/2` raises
  `Qx.MissingDependencyError` with the exact message
  `Add {:vega_lite, "~> 0.1"} to your deps to use this function.`
- In-repo gates: `mix compile --warnings-as-errors` clean,
  `mix format --check-formatted` clean, `mix test` 251 doctests +
  1000 tests, 0 failures. `mix credo --strict` exits 0.
- `Kino.Render` impls use the correct chain (`Kino.Image.new/2` /
  `Kino.Markdown.new/1` piped into `Kino.Render.to_livebook/1`) and
  all live behind compile-time `Code.ensure_loaded?(Kino.Render)`
  guards. Because `:kino` is declared as an optional dep, mix will
  recompile qx when a host adds kino — the guards re-evaluate. Correct.
- Edge cases traced by hand: `Qx.Step` impl is safe for a not-taken
  conditional (`operation` is nil but unused; producers always set
  `state`); empty `counts` renders `_no measurements_`; markdown pipe
  escaping of basis labels is handled.
- Leftover-reference grep over `lib/`, `README.md`, `CHANGELOG.md`,
  `examples/*.exs`: clean. Historical CHANGELOG entries mentioning
  `plot_counts`/`Charts` are correctly untouched. Examples updated to
  `Qx.draw_circuit(...).svg`.

## Findings

### F1 — MEDIUM: qx does not compile *cleanly* as a dep without vega_lite

**Evidence:** in the scratch consumer, compiling qx emits three
warnings:

    warning: Qx.Draw.VegaLite.plot/4 is undefined (module Qx.Draw.VegaLite is not available or is yet to be defined)
      lib/qx/draw.ex:67  (also :106 counts/4, :151 histogram/4)

`lib/qx/draw/vega_lite.ex` is guarded (module not defined without the
dep) but the three call sites in `lib/qx/draw.ex` are only guarded at
*runtime* by `ensure_vega_lite!/0`, so the compiler flags the calls.
Plan Phase 1 claims "must stay clean under `--warnings-as-errors` both
with and without the optional deps" — false for the without-vega_lite
case. Deps aren't compiled with `--warnings-as-errors`, so nothing
breaks, but every no-vega_lite consumer sees three warnings on first
compile. The no-kino side IS clean (all Kino refs sit inside
compile-time guards).

**Fix (one line):** in `Qx.Draw`, add the standard optional-dep idiom
used by Phoenix/Ecto:

```elixir
@compile {:no_warn_undefined, Qx.Draw.VegaLite}
```

### F2 — MEDIUM: the "no-kino lane" (Phase 4, ticked) is not reproducible

No CI matrix, no `@tag :kino` anywhere in `test/`, nothing in
`scratchpad.md` recording how the lane was run. The
"Kino.Render implementations" describe block in
`test/qx/draw_contracts_test.exs` calls `Kino.Render.impl_for/1`
unconditionally — under an actual no-kino test run it would fail, so
the `--exclude kino` mechanism the plan names cannot work as the tests
stand. (Note: optional deps of the *current* project are always
fetched, so the lane necessarily lives in a downstream scratch
consumer — like the one used for F1's evidence.)

**Fix:** tag the Kino-dependent tests `@tag :kino`, and record the
lane (a scripted no-dep consumer compile/run, or a CI step) so the
optional path stays honest per the plan's own risk note.

### F3 — LOW: stale return-type doc in `lib/qx/qubit.ex:41`

"⚠️ This is a terminal operation that returns an SVG string or
VegaLite struct, not a qubit." — it now returns `%Qx.Draw.Image{}`.
Module is internal (`@moduledoc false`) but the sentence is simply
false now, and the same doc block was otherwise updated in this
branch.

### F4 — LOW: `test/qx_manual_test.livemd` broke and the scratchpad said it would be updated

13 sites of `Qx.draw_bloch(..., format: :svg) |> Kino.HTML.new()`.
`format:` is now silently ignored and the pipe feeds `%Image{}` into
`Kino.HTML.new/1`, which expects a binary — every one of those cells
now crashes in Livebook. Scratchpad: "qx_manual_test.livemd's 13
`draw_bloch(format: :svg)` sites get a mechanical update in Phase 6 if
the file survives." The file survived; the update didn't happen.
(`examples/tutorials/*.livemd` carry the same pattern but are
explicitly waived as stale deletion candidates.) Fix or delete before
v0.10.

### F5 — LOW: README intro sentence contradicts the rework

`README.md:352`: "visualization functions that work in both LiveBook
(VegaLite) and standalone (SVG) environments" — the old dual-format
story. Chart-SVG is deleted; the accurate framing (one static artifact
per function) sits in the new section two paragraphs below. Reword the
intro line.

### F6 — LOW: unknown options are now silently ignored

Pre-rework, `format: :bogus` raised `Qx.OptionError`; now `:format`
(and any unknown key) is silently dropped (`Keyword.get` only). That's
exactly how F4's call sites migrated to wrong behaviour without a
signal. Consider `Keyword.validate!/2` (wrapped into `Qx.OptionError`)
on the six draw entry points — consistent with Iron Law #7's typed-
error-on-misuse posture. Acceptable to defer; worth a scratchpad line.

### F7 — LOW: 4 new credo notes, all in `lib/qx/draw.ex`

3× "nested modules could be aliased" (the `Qx.Draw.VegaLite.*` calls —
deliberately unaliased, and *correctly* so: aliasing would shadow the
external `VegaLite` that `ensure_vega_lite!/0` checks) and 1× alias
ordering at line 31 (`Qx.Draw.SVG` group before `Qx.Draw` group).
Exit code is 0 so the gate passes, but these are new on this branch.
Fix the ordering; suppress the three alias suggestions with a
`# credo:disable-for-lines` + comment explaining the optional-dep
reason, so they don't accumulate as noise.

### F8 — INFO: nil-field structs would crash render/inspect

Hand-built `%Qx.SimulationResult{}` with `counts: nil` crashes the
`Kino.Render` impl (`Enum.sort_by(nil)`), `%Qx.Step{}` with
`state: nil` crashes `show/1`/`Inspect`, `struct(Image, %{})` with
`svg: nil` crashes `Inspect` (`byte_size(nil)`). No producer emits
these shapes, `@enforce_keys` guards literal construction of the new
structs, and the Step/Inspect behaviour is pre-existing parity — no
action needed, recorded for completeness.

### F9 — INFO: doc placement nit in the facade

`Qx.draw_bloch/2`'s "Returns a `Qx.Draw.Image` artifact…" paragraph
sits *inside* the `## Parameters` section (`lib/qx.ex` ~1179); the
sibling functions put it in the intro. Cosmetic; renders oddly on
HexDocs.

## Files reviewed

- `lib/qx/draw.ex`, `lib/qx/draw/{image,state_table,kino_render,tables,vega_lite}.ex`, `lib/qx/errors.ex`, `lib/qx.ex`, `lib/qx/qubit.ex`, `mix.exs`
- `test/qx/draw_contracts_test.exs`, `test/qx/draw_test.exs`, `test/qx/typed_errors_sweep_test.exs`, SVG test updates
- `README.md`, `CHANGELOG.md`, `ROADMAP.md`, `examples/`, `test/qx_manual_test.livemd`
