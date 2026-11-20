# Plan: Align Qx drawing output with the Qx visual design guide

**Branch:** `feat/visual-design-guide` (created 2026-11-19)
**ROADMAP:** v0.13, "Improve Bloch sphere SVG visual quality (qx-w93)", plus three new lines added by P0-T2
**Depth:** deep
**Complexity:** 9 (4+ files across Draw modules +3, new domain concept: theme,
gate families, mono style +3, tier 1/2 public API change: `draw_circuit/2`
options +3, external dep API: `VegaLite.config/2` and layers +2, follows the
existing `Qx.Draw.Image` artifact pattern −2)
**Design source:** <https://claude.ai/artifact/V2gcoTJo4owcDr7L5JMRhp>
(version `1795037097-5ccd`, read 2026-11-18). Text extract:
`research/design-guide.md`. The 39 reference drawings: `research/guide-svgs/`.

## Goal

Every image Qx renders follows the guide: one shared palette and type system,
quantikz-style circuit diagrams coloured by gate family with a mono style, a
Bloch sphere that reads as a sphere and shows near and far, and the three
Vega-Lite charts under one config.

No function is removed and no return type changes. What changes is the
content of the SVG and the Vega-Lite spec.

## Findings that shape the plan

Measured on `main` at `45590b2` (v0.12.0) on 2026-11-18.

1. **`Qx.draw_circuit/2` raises on five gates the public API produces.**
   `Qx.cy`, `Qx.crx`, `Qx.cry`, `Qx.crz` and `Qx.phase` each raise
   `Qx.GateError` "Unsupported gate". The drawer lists `:p`, which no
   producer emits; `Qx.phase/3` emits `:phase`. The `Kino.Render`
   implementation for `Qx.QuantumCircuit` calls the same drawer, so a
   Livebook cell that ends in such a circuit fails. This is the Iron Law #9
   pattern (an arm for a shape nothing emits, standing in for the real one).
   The guide's catalogue covers all five, so Phase 2 fixes it. User decision
   (2026-11-18): fixed here and shipped with 0.13.0, no 0.12.1 patch.
2. **Titles are written into the SVG unescaped.** A title of `a <b> & "c"`
   produces malformed XML in both the circuit and the Bloch renderer.
3. **The Bloch readout shows a negative φ** (`φ: -0.5π` for `S†H|0⟩`) while
   the function doc says 0 to 2π.
4. **`counts/4` builds bars in map order**, which is sorted only for maps of
   32 keys or fewer. The guide's config needs `sort: nil`, so the data must
   be sorted explicitly.
5. **Existing tests assert on the current markup** and will fail under the
   guide. They may not be edited without explicit human approval (TDD rule 2
   and the test-file hook). See P0-T1.
6. `VegaLite.config/2` and `VegaLite.layers/2` exist in the locked
   vega_lite 0.1.11. The declared requirement is `~> 0.1`; the floor has not
   been checked (P1-T5).
7. No sibling repo reads the SVG or the spec internals: `kino_qx` calls
   `Qx.draw_counts/2` for display only and `qxportal/lib` does not call the
   draw functions.

## Scope

**In:**
- `lib/qx/draw/theme.ex` (new, tier 3): palette, gate families, font stacks, Vega-Lite config.
- `lib/qx/draw/svg/markup.ex` (new, tier 3): XML escaping, number formatting, mathematics-voice label building, label width estimate.
- `lib/qx/draw/svg/circuit.ex`: rewritten renderer and column layout.
- `lib/qx/draw/svg/bloch.ex`: rewritten renderer.
- `lib/qx/draw/vega_lite.ex`: shared config, one colour, fixed probability axis, value labels, label thinning.
- `lib/qx/draw.ex`, `lib/qx.ex`: `circuit/2` accepts options (`title:`, `style:`); docs.
- New test files under `test/qx/draw/`; approved edits to six existing test files.
- `README.md`, `CHANGELOG.md`, `ROADMAP.md`, `mix.exs` (version at release only).

**Out:**
- `Qx.Draw.StateTable` and `Qx.Draw.Tables` (text and markdown; the guide does not cover them).
- A dark theme. The guide fixes paper at `#FFFFFF`.
- New drawings (phase circle, step-through widget): ROADMAP backlog.
- A shared gate table for simulation, OpenQASM and the drawer (ROADMAP backlog line 82). The family map lives in the theme and is checked against the producers by a test instead.
- Open controls. The guide defines one; no Qx API produces it, so no arm is added.
- Rendered example images in HexDocs or the README.
- `kino_qx` and `qxportal`.

## Public API and versioning

- `Qx.draw_circuit(circuit, title)` keeps working. New:
  `Qx.draw_circuit(circuit, title: "Bell", style: :mono)`. The second argument
  is a binary, `nil`, or a keyword list. `:style` is `:color` (default) or
  `:mono`; anything else raises `Qx.OptionError`. Additive.
- No other signature changes. Output content changes for all five image and
  chart functions.
- Ships in **0.13.0**. Recorded in the CHANGELOG under **Changed**, with a
  note for anyone who parses the SVG or the spec. Not marked **Breaking**:
  the documented contract is the artifact type, which is unchanged
  (scratchpad D2 if you want it marked otherwise).

## Phases

Each phase ends green on
`mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict`
and the affected test files. Tests are written first and must fail before the
implementation (TDD rules 1 and 3).

### Phase 0: Approvals and roadmap

- [x] [P0-T1] (approved by the user 2026-11-19, all rows plus P4-T4) Get explicit approval for these edits to existing tests, then
  make them in the phase that changes the behaviour. Nothing else in an
  existing test file is touched.

  | File | Assertion today | Why it fails | Replacement |
  |---|---|---|---|
  | `test/qx/draw/circuit_test.exs` (4 geometry tests) | regex on `stroke="#778899"` register lines | classical colour becomes Ink 2 `#4A5261`, width 1 | same four geometric checks against the Ink 2 double line; arrowhead stays a `<polygon>` with the tip first, so the rest of each test holds |
  | `test/qx/draw/circuit_test.exs:127,132` | `svg =~ "T†"`, `"S†"` | the dagger is a superscript `tspan` | assert the letter and `†` are in one `<text>` element |
  | `test/qx/draw/iswap_svg_test.exs` | two `iSW` labels | one box labelled *i*SWAP on adjacent wires | one Exchange-family box spanning both wires, label text `iSWAP` |
  | `test/qx/draw/cswap_svg_test.exs:18` | `svg =~ "×"` | crosses are drawn, not typed | two crosses in the Exchange stroke |
  | `test/qx/draw/u_svg_test.exs:17,33` | `svg =~ ">U("` | `U` is an italic `tspan` | label text of the gate starts `U(` |
  | `test/qx/draw/swap_svg_test.exs:19` | `<line` count ≥ 5 | passes if crosses stay `<line>` elements | none if P2-T6 keeps `<line>`; listed so the choice is deliberate |

- [x] [P0-T2] (three lines added; Bloch line tagged with the plan) Add to `ROADMAP.md` under `## v0.13`: shared draw theme and
  chart config; circuit diagrams to the guide (with the five missing gates);
  `draw_circuit` options and mono style. Keep the existing Bloch line. Each
  carries `(plan: visual-design-guide)`.
- [x] [P0-T3] (all defaults accepted 2026-11-19; recorded in the scratchpad) Resolve scratchpad decisions D2 to D6 with the user, or accept
  the recorded defaults. Record the answers in the scratchpad.

### Phase 1: Theme, markup helpers, charts

- [x] [P1-T1] (13 tests; producers traced through `test/support/gate_catalogue.ex`, which fails if a producer function has no entry; the QASM importer's atoms are read from the lowering table) Tests first, `test/qx/draw/theme_test.exs`: every gate atom a
  producer emits has a family (trace the atoms from `Qx.Operations`,
  `Qx.Patterns` and `lib/qx/export/openqasm/lowering.ex` by running one
  circuit per public gate function, not by listing them by hand); each family
  has a stroke and fill equal to the guide's hex values; fill equals stroke
  at 16% on paper to within 1 per channel; `vega_config/0` equals the guide's
  JSON.
- [x] [P1-T2] (also `gates/0`, `palette/0`, `family_colors/2` with the mono style; `:cz` is Pauli per the guide's table and the drawer gives it no coloured mark) `Qx.Draw.Theme` (`@moduledoc false`): neutrals (ink `#16181D`,
  ink 2 `#4A5261`, muted `#6B7482`, back `#A9B1BD`, rule `#D9DEE5`, paper
  `#FFFFFF`), accent `#D55E00`, data blue `#0072B2`, the six families with
  stroke and fill, `family/1` (gate atom to family; unknown atom raises
  `Qx.GateError`), the three font stacks, `vega_config/0`. Controlled gates
  take the family of the gate they control: `:cx`, `:ccx`, `:cy` Pauli;
  `:cp` Phase; `:crx`, `:cry`, `:crz` Rotation; `:cswap` Exchange. `:cz` has
  no coloured mark.
- [x] [P1-T3] (27 tests. AMENDED: the guide draws P(λ) and P(π/2) in one 56 box and Rx(θ) and Rx(π/2) in one 64 box, so those widths are per-kind slots, not measurements; tested as measured widths for H 32, P(π/4) 56, Rx(π/2) 64, U(θ, φ, λ) 84 plus a per-kind minimum. See scratchpad) Tests first, `test/qx/draw/markup_test.exs`: `escape/1` on
  `& < > " '`; `math_label/1` output for `H`, `S†`, `Rx(π/2)`, `U(θ, φ, λ)`
  with real angles, `q` with subscript index; `angle/1` formatting (D4);
  `label_width/2` reproduces the guide's box widths to within 4px: `H` 32,
  `P(λ)` 56, `Rx(θ)` 64, `U(θ, φ, λ)` 84.
- [x] [P1-T4] (`math_label/2` and `box_width/3` (size and minimum added); also `text/4`; `num/1` prints whole numbers without a decimal point) `Qx.Draw.SVG.Markup` (`@moduledoc false`): `escape/1`,
  `num/1` (one decimal, no exponent form), `math_label/1` returning `tspan`
  markup (letters italic; digits, brackets, π and † upright; subscripts and
  superscripts at 72% size with `dy`), `angle/1`, `label_width/2` from a
  per-character advance table. SVG cannot measure text, so the estimate is
  sized for the widest face in the stack (scratchpad R1).
- [x] [P1-T5] (confirmed from the 0.1.0 package source: both `config/2` and `layers/2` are there; requirement stays `~> 0.1`) Check the vega_lite floor: confirm `VegaLite.config/2` and
  `VegaLite.layers/2` in 0.1.0 from the package changelog, or raise the
  optional requirement in `mix.exs` and `@vega_lite_requirement` to the
  first version that has both. Record which in the scratchpad.
- [x] [P1-T6] (19 tests) Tests first, `test/qx/draw/chart_style_test.exs`, asserting on
  `VegaLite.to_spec/1`: config equals `Theme.vega_config/0` for all three
  functions; bar colour is data blue for all three; probability y domain is
  `[0, 1]` for `plot` and `histogram`; x title is "Basis state"; labels are
  kets at 16 bars or fewer and bare bit strings rotated to vertical above
  16; above 64 bars only every fourth label is shown; a text layer with the
  values exists at 8 bars or fewer and not at 9; counts bars are in
  bit-string order for a result with more than 32 distinct outcomes; counts
  y axis starts at 0; the empty-counts chart still has the title
  "No Measurements"; `Qx.DrawSizeError` and `Qx.MissingDependencyError`
  behaviour unchanged (existing tests cover it; run them).
- [x] [P1-T7] (labels by axis `labelExpr`, so the data values are unchanged; every fourth label by axis `values`; y title `Counts` and `.2f` probability ticks as in the guide's specimens; no colour encoding, the config's `bar.color` applies) `Qx.Draw.VegaLite`: one private builder used by `plot/4`,
  `counts/4` and `histogram/4`; `VegaLite.config(Theme.vega_config())`;
  `sort: nil`; counts sorted by bit string; counts x labels as kets (the
  guide's counts specimen shows `|00⟩`); `scale: [domain: [0, 1]]` for
  probabilities and `nice: true, zero: true` for counts; label rules from
  P1-T6. Data field names (`"state"`, `"probability"`, `"measurement"`,
  `"count"`) stay as they are.
- [x] [P1-T8] (six doc blocks plus the `Qx.SimulationResult` counts-key sentence) Docs: `Qx.Draw.plot/2`, `counts/2`, `histogram/2` and the
  facade docs say the axis is fixed and the labels are kets.
- [x] [P1-T9] (compile, format, credo clean; 271 draw and facade tests; `--no-optional-deps` compile clean) Phase gate: the three checks, `mix test test/qx/draw test/qx/draw_test.exs test/qx/draw_contracts_test.exs test/qx/draw_size_cap_test.exs`,
  and `mix compile --no-optional-deps --warnings-as-errors` (the theme must
  not reference `VegaLite` at compile time).

### Phase 2: Circuit diagrams

Reference: `research/guide-svgs/circuits-*.svg`. Where the guide's prose and
its drawings differ, the drawings win (scratchpad D5).

- [x] [P2-T1] (table of 25 constants in the scratchpad, each from two or more drawings; run-in is 12 and run-out 16, the barrier column is zero-width between two 24 gaps) Spike, no production code: from the four whole-circuit
  references, write down the geometry as constants in the scratchpad: wire
  pitch 48, box 32 × 32 with radius 2, 24 between columns, first wire at
  y 52 with a title and 26 without, register double line 3 apart, barrier
  column 24, wire run-in and run-out. Confirm each against at least two
  drawings.
- [x] [P2-T2] (64 tests, 63 failing against the old renderer; two whole circuits are compared coordinate for coordinate with the guide's teleportation and QFT drawings) Tests first, `test/qx/draw/circuit_style_test.exs`:
  - every gate function in the public API draws without raising (one circuit
    per function, including `cy`, `crx`, `cry`, `crz`, `phase`, `measure_x`,
    `measure_y`, `barrier`, `c_if`); this is the regression test for finding 1;
  - each gate's box or mark uses its family stroke and fill;
  - wires, control dots and connectors are ink at 1.25;
  - `cz` draws two ink dots and no box; `cx` and `ccx` draw ⊕ of radius 9 in
    Pauli; `cy` draws a control and a `Y` box;
  - no gate label has a font size under 15 (except as decided in D5);
  - a wide label widens its box, and every gate in that column is centred on
    the same x;
  - `iswap` on adjacent wires is one box spanning both; on non-adjacent
    wires per D3;
  - the classical register is a double line in Ink 2 with a slash and the
    bit count; a measurement ends in an arrowhead on the register with its
    bit index; a condition draws a double line up from the register, a dot,
    and the label `c_k = v`;
  - a barrier is a dashed `4 3` line in Muted running 20 beyond the first
    and last wire it covers, in a 24-wide column;
  - every `fill` and `stroke` value in the output is a theme colour;
  - the output parses as XML (`:xmerl_scan`, loaded in the test with
    `Mix.ensure_application!(:xmerl)`), including with the title
    `a <b> & "c"`;
  - the root element has `role="img"` and an `aria-label`;
  - `style: :mono` output contains only ink, ink 2, muted and paper;
  - an invalid `:style` raises `Qx.OptionError`; a binary second argument
    still sets the title; the >20-qubit `Qx.QubitCountError` and index
    errors are unchanged.
- [x] [P2-T3] (option handling in `Qx.Validation.draw_circuit_options!/1`; a second argument that is neither a title nor a keyword list raises `Qx.OptionError`; `Qx` doctests 66 to 67) `Qx.Draw.circuit/2` and `Qx.draw_circuit/2`: accept
  `String.t() | nil | keyword()`; validate `:style` through `Qx.Validation`;
  specs and docs; drop the "IEEE notation" wording. `Qx.Draw.Image.title`
  keeps the title. Add a `doctest` line check: the facade example must run
  (TDD rule 4; `Qx` and `Qx.Draw` already have directives, confirm the count
  rises).
- [x] [P2-T4] (one rule: a gate takes the first column free on every wire it occupies; a barrier occupies all wires, a conditional gate occupies down to the register (it did not before)) Layout: replace the fixed column pitch with per-column widths.
  Keep the existing collision rules (`find_available_column`,
  `get_qubits_to_update`); after columns are assigned, compute each column's
  width as the widest gate in it and each column's centre x by prefix sum.
  A barrier takes a 24-wide column of its own.
- [x] [P2-T5] (`validate_instruction!/2` calls `Theme.family/1`; `:p` is gone; gates inside a `c_if` block are now validated too) Supported set: derive it from `Theme.family/1` instead of the
  hand-written list, so the drawer cannot fall behind the theme. Delete the
  `:p` entry and any other arm no producer emits (Iron Law #9). Add `:cy`,
  `:crx`, `:cry`, `:crz`, `:phase`.
- [x] [P2-T6] (each gate returns lines, shapes and texts, drawn in that order; `_ = r` gone with the old `render_cswap`) Renderers, one function per shape, all taking the style:
  boxed single-qubit gate; control dot and connector; ⊕ target; controlled
  boxed gate (`cy`, `cp`, `crx`, `cry`, `crz`); `cz`; `swap` and `cswap`
  crosses (as `<line>` elements, stroke 1.75, round caps); `iswap`;
  meter with drop, `<polygon>` arrowhead (tip first) and bit index;
  classical condition; barrier; wire labels in the mathematics voice;
  register bundle; left-aligned title in the sans voice. Remove the
  `_ = r` leftover in `render_cswap`.
- [x] [P2-T7] (four files edited by script, `swap_svg_test.exs` untouched; the connector test now checks both lines of the double drop end inside the arrowhead) Apply the approved edits to the five circuit test files
  (P0-T1).
- [x] [P2-T8] (teleportation and QFT indistinguishable from the references; differences listed in the scratchpad; labels fit in Times New Roman) Compare by eye: render the teleportation, QFT and variational
  circuits of the guide with Qx, write them next to the references in the
  scratchpad directory, and list every visible difference in the plan
  scratchpad. Fix or record each one.
- [x] [P2-T9] (compile, format, credo clean; 367 tests; `mix docs` 23 warnings before and after, lists identical) Phase gate: the three checks, all draw tests, and
  `mix docs 2>&1 | grep -c warning` no higher than before the phase.

### Phase 3: Bloch sphere

Reference: `research/guide-svgs/bloch-*.svg`.

- [x] [P3-T1] (42 tests, 37 of the first 39 failing against the old renderer; the drawing is grouped into `<g data-part>` elements and the tests read it part by part) Tests first, `test/qx/draw/bloch_style_test.exs`:
  - exactly three great circles, each drawn as a solid near half in Ink 2
    and a dashed far half in Back; no latitude or longitude rings;
  - a silhouette circle in ink at 1.5 (scaled) and a radial gradient body;
  - the state vector is the only accent-coloured mark; shaft on a paper halo;
  - the head is solid for a near-hemisphere tip and paper-filled with an
    accent outline for a far one: `|+⟩` solid, `|−⟩` hollow, `|1⟩` hollow,
    `|0⟩` solid;
  - θ and φ arcs are present for a general state and absent at both poles;
  - a vector whose projected length is under 20 (at size 400) ends in a dot
    of radius 5.5, solid or hollow by the same rule;
  - axes are ink or Ink 2 with no red, green or blue; axis letters and kets
    in the mathematics voice; six state labels;
  - the readout is `θ = aπ  φ = bπ` in the mono voice with φ in `[0, 2)`
    (finding 3), centred under the sphere;
  - radius is 33.5% of the size; `size: 240` keeps every font at 80% or
    more of its size at 400;
  - title left-aligned; a title of `x <y>` yields well-formed XML;
  - `role="img"` and an `aria-label` naming θ and φ;
  - every colour is a theme colour;
  - two spheres rendered for different states have different gradient ids
    (R2).
- [x] [P3-T2] (`project/2` with the page's right, up and toward vectors as module attributes; the `{y, z, x}` swap is gone) Projection: orthographic, camera 30° round from x and 18°
  above the equator, x toward the viewer and left, y right, z up. Replace
  the current engine-axis swap (`{y, z, x}`) with one `project/2` over Bloch
  coordinates, returning screen x, y and depth. Pure functions on floats;
  no tensors beyond the existing two-amplitude read.
- [x] [P3-T3] (each circle is sampled from the angle where it turns toward the reader, so the halves share end points and there is exactly one near and one far polyline per circle) Great circles: sample each circle, split at the depth sign
  change, emit the near and far halves as separate paths.
- [x] [P3-T4] (axes are cut where they leave the sphere and where they come out from behind the outline, then each stretch is solid or pale) Body, tinted equatorial plane, silhouette, axes (pale inside
  the sphere, solid with an arrowhead outside), state labels with paper
  halo.
- [x] [P3-T5] (φ is 0 at a pole and rounding noise just under zero reads as 0, not 2π; the centre point is left out under a short vector's dot) State vector, head rule, short-vector dot, drop line and
  shadow, θ and φ arcs with the pole exception, readout. Normalise φ into
  `[0, 2π)` in `qubit_to_bloch_coordinates/1` and correct its doc.
- [x] [P3-T6] (strokes are clamped at 80% as well as fonts, as the 280px reference drawings are; lengths and dashes scale freely) Scaling: every stroke and font scales with `size / 400`, fonts
  clamped at 80% of their 400 size.
- [x] [P3-T7] (general state and the titled anatomy drawing indistinguishable from the references; notes in the scratchpad) Compare by eye against the six state references and the
  anatomy drawing, as in P2-T8.
- [x] [P3-T8] (compile, format, credo clean; all draw tests pass. The ROADMAP Bloch line is ticked in the merge commit, not here) Phase gate: the three checks and all draw tests. Tick the
  ROADMAP Bloch line in the merge commit.

### Phase 4: Documentation and close

- [x] [P4-T1] (`Visual style` section with the family table; `bloch/2` and `draw_bloch/2` docs describe the vector head, the readout and the new `Qx.OptionError` cases) `Qx.Draw` moduledoc: a short "Visual style" section naming the
  five families, the mono style and the fixed probability axis. `Qx.Draw`
  and facade function docs updated where the look is described.
- [x] [P4-T2] (one sentence on the quantikz style and families, with a `style: :mono` snippet) `README.md`: replace "proper IEEE notation" (line 399) with
  one sentence on the quantikz style and families; show `style: :mono`.
- [x] [P4-T3] (Added, Changed and Fixed under `[Unreleased]`; every before/after claim was run against `main` first. Two fixes beyond the plan's three: the classical-bit index error and the conditional line crossing a gate) `CHANGELOG.md` under `[Unreleased]`: **Changed** (the look of
  all five drawings; chart x title; fixed probability axis; counts bar
  order), **Added** (`draw_circuit` options and mono style), **Fixed**
  (five gates that could not be drawn; unescaped titles; negative φ
  readout).
- [x] [P4-T4] (section 12 appended, 12 cells, all evaluated outside Livebook. The existing `# Expected: Dot at ...` comments on the Bloch cells were not touched; they still read correctly for the arrow tip) `test/qx_manual_test.livemd`: add cells that draw the guide's
  three circuits, the six Bloch states and both chart shapes, for a human
  check in Livebook. It is under `test/`, so the hook applies: needs the
  same approval as P0-T1.
- [x] [P4-T5] (full suite 1800 of 1800 (363 doctests); dialyzer passed; docs 23 warnings, the same list as `main`; `--no-optional-deps` compile clean; `mix hex.build` built and the tarball deleted. One existing test outside the P0-T1 table needed a one-line edit, approved by the user 2026-11-19 (`quantum_circuit_instruction_order_test.exs`, the `gate_label_x/2` pattern)) Final gate: `mix test` (full suite), `mix dialyzer`,
  `mix docs` warning count no higher than on `main`,
  `mix compile --no-optional-deps --warnings-as-errors`,
  `mix hex.build` then delete the tarball.
- [x] [P4-T6] (stopped here; nothing committed, nothing merged) Stop for `/phx:review`. Do not merge.

## Verification

Per task: `mix compile --warnings-as-errors`.
Per phase: `mix format --check-formatted && mix credo --strict && mix test <affected files>`.
Final: P4-T5.

`mix bench` is not needed: no file under `lib/qx/calc*.ex`, `gates.ex` or
`simulation.ex` changes.

## Iron Law check

- **#1** No atoms from input: family lookup is on existing gate atoms; an unknown atom raises.
- **#2** No processes.
- **#5** No loops over 2^n amplitudes are added. The chart builders still build one map per bar behind the existing `Qx.DrawSizeError` guard, which must stay the first call in each function.
- **#6** `Qx.draw_circuit/2` and `Qx.Draw.circuit/2` gain an option form; additive. New modules are `@moduledoc false`. CHANGELOG entry in P4-T3; minor bump to 0.13.0 at release.
- **#7** `:style` validated through `Qx.Validation`, raising `Qx.OptionError`. Unknown gates keep raising `Qx.GateError`.
- **#9** P2-T5 deletes the unreachable `:p` arm and adds the five emitted shapes. The law's execution-test clause concerns the simulator dispatch, which this plan does not touch; the drawing equivalent is P2-T2's one-circuit-per-public-function test.

## Risks

- **R1 Label width is an estimate.** SVG output cannot measure text and the
  reader's font is one of five in a stack. A box sized for STIX Two may clip
  in Times New Roman. Mitigation: size for the widest face, keep 8px each
  side, and check P2-T8 in a browser with STIX Two disabled.
- **R2 Gradient and marker ids collide** when two SVGs are inlined in one
  HTML page. Mitigation: derive the id from a hash of the rendered state and
  size, as the guide's drawings do.
- **R3 Scope.** Two renderers are rewritten, about 1,000 lines. Phases 1, 2
  and 3 are independent after the theme lands and can merge separately
  (scratchpad D6).
- **R4 Test churn.** Six existing test files need approved edits; without
  the approval Phase 2 cannot finish.
- **R5 The guide may change.** It is a live artifact. Re-read it at the start
  of each phase; if its version differs from `1795037097-5ccd`, refresh
  `research/` and note the differences before continuing.

### Self-check

- *What would make this plan wrong?* If the guide's prose, not its drawings,
  is the authority (D5), several constants in P2-T1 change.
- *What is most likely to be discovered late?* Label clipping in fallback
  fonts (R1), found only by looking at rendered output; hence P2-T8 and P3-T7.
- *What is deliberately not verified?* Colour-blind contrast figures. They
  are the guide's claims about its palette; the plan checks only that Qx
  uses those exact colours.
