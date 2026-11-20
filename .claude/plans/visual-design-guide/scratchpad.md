# Scratchpad: visual-design-guide

## Open decisions (defaults are what the plan assumes)

### D1: Ship the five undrawable gates as a patch first? RESOLVED
`Qx.draw_circuit/2` raises `Qx.GateError` for `cy`, `crx`, `cry`, `crz` and
`phase` in the released 0.12.0.
**User decision (2026-11-18): fold into Phase 2 and ship with 0.13.0.** No
0.12.1 patch.

### D2: CHANGELOG label for the new look
Default: **Changed**, with a note for anyone parsing the SVG or spec. Not
**Breaking**: no signature or return type changes. Alternative: mark it
Breaking because the chart x title, y domain and bar order change.

### D3: iSWAP on non-adjacent wires
The guide defines one box spanning both wires "when they are adjacent" and
says nothing for the other case. Default: two Exchange-family boxes labelled
*i*SWAP joined by an ink connector. Needs the guide author's answer.

### D4: Which fractions of π are shown
The guide: "fractions of π where they are within 0.001 of one, otherwise two
decimals". It does not list the fractions. Default: denominators 1, 2, 3, 4,
6, 8, 12 and 16, any sign, magnitude up to 2π; forms `π/2`, `3π/4`, `−π/8`,
`2π`, `0`. Today's code uses a tolerance of 0.01 and only ±π, ±π/2, ±π/4.

### D5: Prose versus drawings where the guide disagrees with itself
Found so far:
- Wire run-in: prose says 14 before the first column; the drawings start the
  wire at x 54 and the first box at x 66 (12).
- Label size: rule 03 says never below 15; the iSWAP specimen sets its label
  at 13.
- Controlled-rotation specimens show symbolic `(θ)`; real output shows the
  angle.
Default: the drawings win for geometry; iSWAP is the one permitted 13px
label. Worth correcting in the guide itself.

### D6: One merge or several
Default: one branch, one review, one squash merge, because `/phx:work` runs
all phases. Alternative: split into three plans (theme and charts; circuits;
Bloch), each with its own review and merge. Smaller reviews, three cycles.

## Decisions taken while planning

- `Qx.Draw.Theme` and `Qx.Draw.SVG.Markup` are tier 3 (`@moduledoc false`).
  The guide calls the theme name "proposed"; keeping it internal leaves room
  to change it and adds nothing to the Iron Law #6 surface.
- No research agents were spawned. No dependency is added, the skill's rule
  is not to spawn `hex-library-researcher` for an existing dep, and the code
  reading was four files. The repo's AGENTS.md table says to spawn it on
  every `/phx:plan`; the two rules conflict here and this is the reading
  taken. The one open library question (the vega_lite floor) is task P1-T5.
- Reference drawings were extracted from the artifact into
  `research/guide-svgs/` (39 files, about 350 KB) so a fresh session can work
  without reading the artifact. They can be deleted after the work merges.
- Arrowhead stays a `<polygon>` and swap crosses stay `<line>` elements, to
  keep the intent of the existing geometry tests with the smallest edits.

## Geometry read from the reference drawings (to confirm in P2-T1)

- Wire pitch 48. First wire y 52 with a title, 26 without.
- Box 32 × 32, radius 2, stroke 1.25. 24 between adjacent columns.
- Label baseline 5.1 below the wire, size 15; subscript `dy` 4.2 at 10.8;
  superscript `dy` −5.4 at 10.8.
- Control dot radius 3.5. ⊕ radius 9. Swap cross ±5, stroke 1.75, round caps.
- Meter: arc radius 9 centred 6 below the wire, needle to (+7, −8).
- Register: two lines 3 apart, 42.5 and 45.5 below the last wire, Ink 2,
  width 1. Drop: two lines 3 apart; arrowhead 9 wide, 7 tall; bit index at
  10.5 in Ink 2 to the right.
- Condition: dot radius 3.5 on the register; label `c_k = v` at 11, 17.7
  below the register centre.
- Barrier: `4 3` dash, Muted, width 1, 20 beyond the wires.
- Title: sans 13 semibold at x 24, y 18.
- Bloch gradient: radial, centre 36% 30%, radius 75%, stops `#FFFFFF`,
  `#EEF1F5` at 0.6, `#CBD3DD`. Dashes `3.9 3.2` and `3.9 3.9` at size 280.

## Out of scope, noted for ROADMAP

- Rendered example images in HexDocs and the README.
- Dark theme.
- `spec/CIRCUIT_VISUALIZATION.md` and `spec/visualization_guide.md` describe
  the old look.
- `lib/qx/draw/kino_render.ex` has no `@moduledoc`.

## Work log (/phx:work, 2026-11-19)

### P0: approvals and decisions (user, 2026-11-19)
- **P0-T1 / P4-T4 approved**: the P0-T1 table edits to the five circuit test
  files and the new cells in `test/qx_manual_test.livemd`. Nothing else in an
  existing test file is touched.
- **D2** accepted default: CHANGELOG **Changed**, not Breaking.
- **D3** accepted default: non-adjacent iSWAP is two Exchange boxes labelled
  *i*SWAP joined by an ink connector.
- **D4** accepted default: denominators 1, 2, 3, 4, 6, 8, 12, 16 within 0.001,
  otherwise two decimals.
- **D5** accepted default: drawings win over prose; iSWAP is the one 13px label.
- **D6** accepted default: one branch, one review, one squash merge.

### R5 guide version check (2026-11-19)
Live version is `1795125708-5062`, the plan was written against
`1795037097-5ccd`. Compared: the text of all four artboards is identical to
`research/design-guide.md` (whitespace-insensitive) and all 39 files in
`research/guide-svgs/` match the live drawings byte for byte. The 6 extra
live SVGs are the palette swatches on the Foundations sheet, never saved.
No refresh needed.

### Tooling note
The test-file hook guards any file that already exists under `test/`, so a
new test file can be written once with Write and is then guarded too. Fixes
to test files created in this plan, and the approved P0-T1 edits, go through
a scripted edit; no other existing test file is modified.

### P1-T3 amendment: label widths (2026-11-19)
The plan asked `label_width/2` to reproduce P(λ) 56 and Rx(θ) 64 to within
4px. Measured against the references: `P(λ)`, `P(π/2)` and `P(π/4)` are all
drawn in a 56 box, and `Rx(θ)`, `Ry(φ)`, `Rx(π/2)` and `Rz(π/2)` all in a 64
box. One advance table cannot give `(λ)` and `(π/2)` the same width (they
differ by about 12px at 15px), so the guide's widths are slots per gate
kind, not text measurements. Implemented as: box width = the larger of the
kind's minimum (phase with an angle 56, single-angle rotation 64, U 84,
everything else 32) and the measured label plus 16, rounded up to 4. With
the advance table in `Qx.Draw.SVG.Markup` the measured widths alone give
H 32, P(π/4) 56, Rx(π/2) 64, U(θ, φ, λ) 84 and iSWAP at 13px 56, all equal
to the guide. Every drawing in the guide is reproduced; a longer label
widens its box.

### P1-T5 vega_lite floor (2026-11-19)
`VegaLite.config/2` and `VegaLite.layers/2` are both in the 0.1.0 package
source (fetched and read). `~> 0.1` stays.

### P2-T1 spike: circuit geometry constants (2026-11-19)
Each constant was read from at least two reference drawings (T =
teleportation, Q = qft3, V = variational, A = anatomy, S = a specimen).

| Constant | Value | Confirmed in |
|---|---|---|
| Wire pitch | 48 | T, Q, A ("48 row pitch") |
| First wire y | 52 with a title, 26 without | T, Q, V / A, S |
| Wire start x, wire label x | 54, 46 (right-aligned) | T, Q, V, A |
| Run-in to the first column | 12 (first box at 66) | T, Q, V, A. Prose says 14; drawings win (D5) |
| Run-out after the last column | 16 | T (514 to 530), Q (530 to 546), A (210 to 226). Prose says 4; drawings win (D5) |
| Image width | wire end + 10 | T 540, Q 556, V 408 |
| Box | 32 x 32, radius 2, stroke 1.25 | all |
| Gap between columns | 24 | T, Q, A ("56 column pitch" = 32 + 24) |
| Slot of a dot, target or cross column | 32 | T (122 to 154), Q (498 to 530) |
| Barrier column | zero width, the usual 24 gap either side | T (154, 178, 202), Q (450, 474, 498). The guide's "24px column" is the same thing measured from the neighbours' gaps |
| Barrier line | Muted, 1, dash `4 3`, 20 beyond its first and last wire | T, Q, S |
| Label baseline | wire y + 5.1, size 15 | all |
| Sub / superscript | dy 0.28 em / -0.36 em at 72% size | Q, V, S (4.2, -5.4, 10.8 at 15; 3.1, 7.9 at 11) |
| Control dot | radius 3.5, ink fill and stroke | T, Q, S |
| Target | circle radius 9 in Pauli, cross to the rim | T, V, S |
| Connector | ink 1.25, to the centre of a target, to the edge of a box | T, Q, S (cy, cp) |
| Swap cross | +/- 5, stroke 1.75, round caps, Exchange | Q, S (swap, cswap) |
| iSWAP adjacent | one box 56 wide from 16 above the upper wire to 16 below the lower; label 13px, baseline mid + 4.4 | S only (one drawing exists) |
| Meter | neutral box; arc radius 9 centred 6 below the wire; needle to (+7, -8) | T, A, S |
| Register | two lines 3 apart, centre 44 below the last wire, Ink 2, width 1 | T, A, S |
| Register slash and count | (61, +6) to (67, -6) about the centre; count at x 69, 7 above the centre, 10.5 | T, A |
| Drop from a meter | two lines 3 apart from the box to 6.5 above the upper register line | T, A, S |
| Arrowhead | 9 wide, 7 tall, tip 0.5 above the upper register line | T, A, S |
| Bit index | x + 8, 5.5 above the upper register line, 10.5, Ink 2 | T, A, S |
| Condition | two lines 3 apart from the box to the register centre; dot radius 3.5 in Ink 2; label 11px, 17.7 below the centre | T, S |
| Height | last wire + 26; with a register, register centre + 24 | Q 174, V 126 / T 216, S 94 |
| Title | sans 13, weight 600, x 24, y 18 | T, Q, V |
| Mono style | family stroke becomes ink, fill becomes paper; barrier stays Muted, register stays Ink 2 | qft3-mono |

Layout decisions taken with the spike:
- A barrier occupies every qubit's column slot, so its column holds nothing
  else and later gates on any qubit are drawn after it. It is drawn only
  over the wires it covers.
- A conditional gate now reserves the wires from its top qubit down to the
  register when its column is chosen, as a measurement already did. Before,
  only its own qubits were checked, so the double line up from the register
  could cross a box on a lower wire.
- The register slash is a `path`, not a `line`, so the existing geometry
  tests keep measuring the register lines and nothing else.
- The measurement drop is a double line either side of the arrowhead tip
  (as the guide draws it), so the existing "connector terminates at the tip"
  test is rewritten to check both lines end inside the arrowhead. This is
  one of the four approved `circuit_test.exs` edits, but it is more than a
  colour change; flagged for the review.

### P2-T8 by-eye comparison: circuits (2026-11-19)
Rendered with Qx and rasterised with Quick Look next to the references.

- **Teleportation, QFT**: no visible difference. A test compares the box,
  wire, barrier, target, arrowhead and label coordinates with the reference
  drawings.
- **Variational**: the guide shows symbolic angles (θ, φ, λ); Qx shows the
  real ones, so `U(π/2, π/4, π/8)` is wider than the guide's 84 and the
  image is 448 wide, not 408. Expected; recorded, not fixed.
- **A circuit with every gate and awkward angles** (`Rx(−7π/16)`,
  `U(−3π/4, 2.50, −0.01)`, non-adjacent iSWAP, a conditional CNOT): nothing
  overlaps, every label is inside its box, in colour and mono.
- **Fallback font (R1)**: the same circuit with the stack forced to Times
  New Roman: every label inside its box. Cambria and Latin Modern Roman are
  not installed here, so they are not checked.
- **Markup differences that do not show**: the arrowhead is a `polygon` and
  the swap crosses are `line` elements (the guide uses `path`); a `tspan`
  with no shift omits `dy`; whole numbers are printed without `.0`; the
  circuit SVG keeps its XML declaration.

### Found while rewriting the circuit renderer
- In 0.12.0 a measurement into a classical bit whose index is at least the
  qubit count (`create_circuit(1, 2) |> measure(0, 1)`) raises
  `Qx.QubitIndexError` when drawn: the validator read the classical bit as a
  qubit. Fixed; goes in the CHANGELOG with the five undrawable gates.
- In 0.12.0 a gate inside a `c_if` block was not validated by the drawer, so
  a two-qubit gate in a block raised `FunctionClauseError`. Fixed.
- The plugin's debug-statement hook flags three `IO.puts` in `lib/qx.ex`.
  They are in the doc examples of the `tap_*` functions, were there before
  this branch, and are not debug output. Left alone.

### P3 Bloch sphere: constants read from the references (2026-11-19)
From the six 280px state drawings and the 520px anatomy drawing:
- Camera: right = (-sin 30°, cos 30°, 0), up = (-cos 30° sin 18°,
  -sin 30° sin 18°, cos 18°), toward = (cos 30° cos 18°, sin 30° cos 18°,
  sin 18°). Checked against the axis tips of the reference to 0.1px.
- Lengths scale with k = size / 400. Fonts **and strokes** scale with
  max(k, 0.8): the 280px drawings have strokes at 80% (1.20, 0.88, 0.80,
  2.4), not 70%. The plan said only fonts are clamped; the drawings win (D5).
- Axes run from t = -1.14 to t = 1.30; arrowhead 7 x 6; letter 11 beyond
  the tip, 15px italic.
- Arc radii 0.36 (θ) and 0.27 (φ); letters 0.135 further out, 13px italic.
- Vector head 13 x 11; shaft 3 on a 6 halo; hollow outline 1.75.
- Readout 14 above the bottom edge, `dx` 14 between θ and φ, 11px mono.
- Title at (16, 26), 13px, weight 600; a title moves the sphere down by 6.
- Gradient id: the reference builds it from size, θ and φ; so does Qx
  (`bloch-<size*10>-<θ*1000>-<φ*1000>`), which answers R2.

### P3-T7 by-eye comparison: Bloch sphere (2026-11-19)
- **General state (280) and the anatomy state (520, titled)**: no visible
  difference from the references.
- **|−⟩**: hollow head inside the dashed arcs, as the reference.
- **A vector aimed at the reader, and one aimed away** (no reference
  drawing exists): a solid accent disc and a hollow accent ring. The first
  render put the ink centre point on top, which made a ring with a point
  in it: the usual symbol for "out of the page", wrong for the far case.
  Fixed: no centre point under a dot.
- **Recorded, not fixed**: the `|1⟩` label's paper halo cuts a little of
  the outline below the south pole. The reference does the same.
- **Markup differences that do not show**: each great-circle half is one
  polyline (the reference splits a near half in two where its sampling
  starts); each axis is two or three lines, not sixty short ones.
- Added beyond the plan: `Qx.Draw.bloch/2` now raises `Qx.OptionError` for a
  `:title` that is not a string or nil and a `:size` that is not a positive
  number (Iron Law #7; before, a bad size raised `ArithmeticError`).

### P4-T5 final gate (2026-11-19)
| Check | Result |
|---|---|
| `mix compile --warnings-as-errors` | clean |
| `mix format --check-formatted` | clean |
| `mix credo --strict` | no issues (125 files) |
| `mix test` | 1800 of 1800 after the approved edit below (1799 before it) |
| `mix dialyzer` | passed |
| `mix docs` warnings | 23, the same list as `main` |
| `mix compile --no-optional-deps --warnings-as-errors` | clean |
| `mix hex.build` | builds `qx_sim-0.12.0.tar` with the two new modules; tarball deleted |

### RESOLVED (approved by the user 2026-11-19): a seventh existing test needed an edit
`test/qx/quantum_circuit_instruction_order_test.exs:151` ("draw_circuit/1
places gates left to right in call order") fails. Its helper
`gate_label_x/2` (line 160) matches `<text x="..." ...>X</text>`, the label
directly inside the text element. A label is now set in a `tspan`
(`<text ...><tspan font-style="italic">X</tspan></text>`), so the pattern
finds nothing. The behaviour under test is intact: X is drawn at x 82 and H
at x 138. The plan's P0-T1 table missed this file because it is outside
`test/qx/draw/`. It is not covered by the 2026-11-19 approval, so it has not
been edited without asking. The user approved this one-line edit to the helper, and it is applied:

    pattern = Regex.compile!(~s{<text x="([0-9.]+)"[^>]*><tspan[^>]*>#{label}</tspan></text>})

## Dead ends

(none yet)

### 2026-11-20 Triage of the merge-gate review

All 12 warnings and the three suggestion groups selected for fixing; see
`reviews/visual-design-guide-triage.md`. User decisions: typed errors for an
empty barrier and a huge angle are raised in the drawer only; unknown draw
options raise `Qx.OptionError`; the four unsigned deviations are accepted.
Further approved edits to existing tests: `circuit_test.exs` (exact connector
end point), and the shared label helper in `circuit_test.exs`,
`iswap_svg_test.exs` and `u_svg_test.exs`.

Out of scope, for ROADMAP if wanted: validate at construction
(`Qx.barrier(qc, [])`, angles that do not fit a float) in `Qx.Operations`.
