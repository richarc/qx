# Testing review — feat/draw-rework, test/ diff (main...HEAD)

Verdict: **PASS WITH WARNINGS**

Scope reviewed: `test/qx/draw_test.exs` (rewrite), `test/qx/draw_contracts_test.exs`
(new), `test/qx/typed_errors_sweep_test.exs` (deletions), five SVG geometry files
under `test/qx/draw/`. All 65 tests in the changed files pass
(`mix test`, seed 741143, 0 failures).

## 1. Coverage: old vs new draw_test.exs, describe-by-describe

**bloch_sphere/2 → bloch/2** — |0⟩, |1⟩, |+⟩, |−⟩ all preserved (inputs moved
from `Qx.Qubit` constructors to circuit + `get_state`; `Qx.Qubit.t` is just
`Nx.Tensor.t()`, so it is the same code path — no input-type coverage lost
here). "supports SVG format" is correctly obsolete (output is always an
`Image` carrying SVG). Title coverage is *stronger* (asserts both the struct
field and the SVG content).

- **W1 (minor): size assertion weakened.** Old: `result =~ "width=\"600\""`.
  New: `svg =~ "600"` — matches any coordinate, viewBox value, or rounding
  artifact containing "600". Restore `svg =~ ~s(width="600")`.

**state_table/2** — single/two/three-qubit tables, `hide_zeros`, `precision`,
HTML structure, and markdown pipe-escaping (`| \\|00⟩`) all preserved.
Markdown escaping intent survives in two places (draw_test + contracts test).
The `:auto`/`:markdown`/`:html` format tests are correctly deleted — the
`:format` option is gone and the renderings are now struct fields, which the
new tests assert directly.

- **W2 (minor): the `%Qx.Register{}` happy path in `Tables.render/2` is now
  untested.** Old tests ("displays two-qubit register", "works with
  three-qubit register", "displays Bell state") passed `Qx.Register.new(N)`.
  The clause survives in `lib/qx/draw/tables.ex:35` and is documented in
  `Qx.Draw.state_table/2` ("an internal calc-engine register struct also
  works"); plan T1-14 explicitly lets tier 2 keep it. A retained, documented
  input clause deserves one test:
  `assert %StateTable{} = Tables.render(Qx.Register.new(2))`.
- **W3 (trivial): numeric-correctness assertion dropped.** Old Bell-state test
  asserted `table =~ "0.5"`. No new table test asserts a probability *value*
  (the precision regex checks formatting only). Amplitude math is covered
  elsewhere in the suite, so this is a nice-to-have, not a gap.

**Facade delegates** — `Qx.draw_bloch`, `Qx.draw_state` preserved;
`Qx.draw_circuit` added (was untested on main). The `Qx.Qubit.draw_bloch`
delegate is covered by its doctest (`doctest Qx.Qubit` runs
`is_struct(image, Qx.Draw.Image)`).

## 2. Deleted format OptionError tests + RegisterError path

Deletion is correct: the `:format` option no longer exists on
`plot/plot_counts/bloch_sphere/histogram` (`plot_counts` and `bloch_sphere`
themselves are gone — the contracts test asserts
`refute function_exported?(Qx.Draw, :plot_counts, 2)`). Replacement coverage
is adequate: the contracts test pins one static return type per function
*with options passed*, which is the behavior the OptionError tests were
guarding by other means.

`Tables.render/2`'s `Qx.RegisterError` path is still tested —
`test/qx/typed_errors_sweep_test.exs:73-76` keeps
`assert_raise Qx.RegisterError, fn -> Tables.render(:not_a_register) end`
with the `{:invalid_input, :not_a_register}` reason assertion.

## 3. draw_contracts_test.exs quality

- **No-sniffing grep test** — acceptable as an architecture tripwire, and it
  is cwd-safe (`mix test` always runs from the project root, so
  `Path.wildcard("lib/**/*.ex")` resolves correctly). Two caveats:
  1. It tests source *text*, not behavior, and only the two exact retired
     idioms (`kino_available?`, `apply(Kino`). New sniffing spelled
     differently (e.g. runtime `Code.ensure_loaded?(Kino)` inside a function
     body) passes; a comment mentioning the old helper name would fail.
     A blanket `ensure_loaded` grep (which plan Phase 2 sketched) is
     impossible — module-level `Code.ensure_loaded?` guards are the
     sanctioned optional-dep pattern (`image.ex:45`, `state_table.ex:45`,
     `kino_render.ex:5`, `vega_lite.ex:4`) and `ensure_vega_lite!`
     (`draw.ex:243`) is deliberate fail-fast. The narrow grep is the right
     call; add a one-line comment in the test saying *why* only these two
     strings, so a future editor doesn't "improve" it into a false-positive
     machine. **(W4, minor)**
- **Kino.Render impl_for test** — sound. `struct(mod, %{})` bypasses
  `@enforce_keys`, so it cannot raise; asserting `impl != Kino.Render.Any`
  for all five modules is exactly the right check while kino is a dev/test
  dep, and the describe name records the gating assumption.
- **W5 (minor): MissingDependencyError has zero test coverage and the
  pointer to it is wrong.** The comment at
  `test/qx/typed_errors_sweep_test.exs:79-83` says coverage "lives in
  draw_contracts_test.exs to the extent it is testable" — but
  draw_contracts_test.exs never mentions `MissingDependencyError`
  (repo-wide grep of test/: only that comment). The raise-*site* condition
  (`Code.ensure_loaded?(VegaLite)` false) is genuinely untestable with deps
  present — agreed, and the sweep comment is the only place that says so;
  fine. But the exception's `message/1` (`lib/qx/errors.ex:501`) *is*
  testable today without unloading anything:
  `assert_raise Qx.MissingDependencyError, ~r/vega_lite/, fn -> raise Qx.MissingDependencyError, {:vega_lite, "~> 0.1"} end`
  — the message that "names the fix" is a plan Phase 1 deliverable and is
  currently unasserted. Recommend adding that one test to
  draw_contracts_test.exs (which also makes the sweep comment true).

## 4. SVG geometry tests (.svg accessor migration)

Purely mechanical: in `circuit_test.exs`, `cswap_svg_test.exs`,
`iswap_svg_test.exs`, `swap_svg_test.exs`, `u_svg_test.exs` the only change
is `Qx.Draw.circuit(...)` → `Qx.Draw.circuit(...).svg`. Every geometry
assertion is byte-identical: the swap 5-`<line>` count, the iSW label count
of 2, the `>U(` label, `<rect>`/`<circle>`/`×` presence, and the
polygon-coordinate setup in circuit_test all operate on the same string as
before. No weakening.

## Summary of findings

| # | Severity | Finding |
|---|----------|---------|
| W1 | minor | bloch size test weakened: `=~ "600"` vs old `width="600"` |
| W2 | minor | `Tables.render` `%Qx.Register{}` happy-path clause (tables.ex:35) untested; old tests covered it |
| W3 | trivial | No table test asserts a probability value (old Bell test checked "0.5") |
| W4 | minor | No-sniffing grep is deliberately narrow but undocumented as such |
| W5 | minor | MissingDependencyError: zero coverage; sweep comment points at coverage that does not exist; message/1 is testable today |

No blocking issues. Deletions are all justified by the clean-break API;
the contracts test is a real net gain (facade alignment, removed-function
checks, Inspect and Kino.Render coverage that main never had).
