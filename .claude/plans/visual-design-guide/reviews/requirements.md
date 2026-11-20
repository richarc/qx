## Requirements Coverage (from plan file .claude/plans/visual-design-guide/plan.md)

**47 MET, 3 PARTIAL, 0 UNMET, 2 UNCLEAR** (`mix test test/qx/draw test/qx/quantum_circuit_instruction_order_test.exs`: 206 passed, run by me. I did not re-run credo, dialyzer, docs, hex.build or the full suite, so P1-T9, P2-T9, P3-T8 and P4-T5 gate claims are UNCLEAR for those parts.)

| # | Requirement | Status | Evidence |
|---|---|---|---|
| G | Goal: shared palette and type, family-coloured circuits plus mono, sphere with near/far, three charts under one config; no function removed, no return type changed | MET | `lib/qx/draw/theme.ex:14-100`; `Draw.circuit/2` still returns `Image.t()` (`draw.ex:377`); chart builders call `Theme.vega_config()` (`vega_lite.ex:91,128`); CHANGELOG states no return type change |
| S-In1 | theme.ex (palette, families, fonts, vega config) | MET | `theme.ex` |
| S-In2 | markup.ex (escape, num, math label, width) | MET | `lib/qx/draw/svg/markup.ex`; `markup_test.exs` |
| S-In3 | circuit.ex rewritten + column layout | MET | `circuit.ex` (624 lines, `Theme.family` at :164, :515) |
| S-In4 | bloch.ex rewritten | MET | `bloch.ex` (641 lines, `project/2`) |
| S-In5 | vega_lite.ex: shared config, one colour, fixed axis, value labels, thinning | MET | `vega_lite.ex:91,128,141-188` |
| S-In6 | draw.ex / qx.ex options and docs | MET | `draw.ex:377-379`; `qx.ex:402` |
| S-In7 | New tests plus approved edits to six existing files | PARTIAL | 5 new test files; 4 existing draw test files edited (circuit, cswap, iswap, u). `swap_svg_test` correctly untouched. A 5th existing file outside the plan (`quantum_circuit_instruction_order_test.exs`) and `qx_manual_test.livemd` were also edited; see Deviations |
| S-In8 | README, CHANGELOG, ROADMAP (mix.exs only at release) | MET | all three in diff; `mix.exs` not in diff (version still 0.12.0, correct) |
| S-Out1 | StateTable/Tables untouched | MET | not in DIFF_FILES |
| S-Out2 | No dark theme | MET | none in `theme.ex` |
| S-Out3 | No new drawings | MET | none added |
| S-Out4 | No shared gate table; family map in theme and checked by test | MET | `theme.ex:44-72`; `theme_test.exs:64-92` |
| S-Out5 | No open control arm | MET | no such arm in `circuit.ex` |
| S-Out6 | No rendered images in docs/README | MET | README diff text-only |
| S-Out7 | kino_qx, qxportal untouched | MET | not in diff |
| API1 | `draw_circuit(circuit, title)` still works; `title:`/`style:` keyword form | MET | `validation.ex` `draw_circuit_options!/1`; `circuit_style_test.exs:688,697` |
| API2 | `:style` other than :color/:mono raises `Qx.OptionError` | MET | `validation.ex` `validate_draw_style!/1`; test `circuit_style_test.exs:712` |
| API3 | Ships as 0.13.0 under Changed, with SVG-parser note, not Breaking | MET | CHANGELOG `[Unreleased]`: Changed with bold parser note; no bump (correct) |
| P0-T1 | Approval for existing-test edits | MET | scratchpad L88-90 (approval 2026-11-19); the seventh file is approved at scratchpad L260-271 |
| P0-T2 | Three ROADMAP lines with `(plan: visual-design-guide)` | MET | ROADMAP diff: three added plus tag on Bloch line |
| P0-T3 | D2-D6 recorded | MET | scratchpad L91-97 |
| P1-T1 | Theme tests: producers have a family; guide hex pairs; 16% fill within 1 channel; vega_config == guide JSON | MET | `theme_test.exs:68,78` (Operations/Patterns, OpenQASM), `:110`, `:118`, `:170` against `@guide_config`. The producers are traced via `test/support/gate_catalogue.ex`, with a test that fails when a function has no entry (:64) |
| P1-T2 | Theme module | MET | `theme.ex`; neutrals/accent/data match the guide; `family/1` raises `Qx.GateError` (:84); controlled gates per plan (`:cz` is Pauli in the map, drawn with no colour) |
| P1-T3 | Markup tests | PARTIAL | escape (`markup_test:12`), math_label (:106-149), angle (:56-99), q subscript (:135) all asserted. The widths test (:191) uses the AMENDED spec (measured H 32, P(π/4) 56, Rx(π/2) 64, U 84 plus per-kind minimum), not the plan text "P(λ) 56, Rx(θ) 64 within 4px". Amendment recorded in the plan note and scratchpad L113-125; no human approval recorded |
| P1-T4 | Markup module | MET | `markup.ex` (`escape`, `num`, `math_label/2`, `angle`, `label_width`, `box_width/3`, `text/4`) |
| P1-T5 | vega_lite floor checked | MET | scratchpad L127-129; `mix.exs` unchanged |
| P1-T6 | Chart tests: config x3, blue x3, y domain, x title, label rules, value layer 8/9, counts order >32, y from 0, empty title, unchanged errors | MET | `chart_style_test.exs:66,77,92,101,111,123,146,162,176,193,211,222,236-248` |
| P1-T7 | VegaLite builder | MET | `vega_lite.ex:124-188` (`sort: nil`, sorted counts :99, `nice/zero` :42, label_expr and values thinning) |
| P1-T8 | Docs for the axis and ket labels | MET | `draw.ex` and `simulation_result.ex` diffs |
| P1-T9 | Phase gate | UNCLEAR | draw tests pass here; credo, format and `--no-optional-deps` not re-run. `theme.ex` has no `VegaLite` reference at compile time, which is consistent |
| P2-T1 | Geometry spike | MET | scratchpad L131-164 |
| P2-T2 | Circuit tests (each listed item) | MET | every function draws (`circuit_style_test:130-161`); family stroke/fill (:199-264); ink 1.25 wires (:406); cz/cx/ccx/cy (:271-340); font>=15 (:427); wide label column (:476); iswap (:375,389); register/meter/condition (:531-633); barrier dashed (:643); theme colours (:438); XML parse with `a <b> & "c"` (:457); role/aria (:448); mono (:739); `OptionError` and `QubitCountError` (:712-735) |
| P2-T3 | Options and validation, docs, doctest | MET | `draw.ex:377-379`; `validation.ex`; "IEEE" gone from `draw.ex`/`qx.ex` (grep empty). Doctest count rise 66 to 67 is claimed, not re-run |
| P2-T4 | Per-column widths | MET | test `circuit_style_test:469-523`; layout in `circuit.ex` |
| P2-T5 | Supported set from `Theme.family/1`; `:p` removed; five gates added | MET | `circuit.ex:162-164`; grep for `:p` empty; `theme.ex:56,63-66` |
| P2-T6 | Renderers; `_ = r` removed | MET | grep for `_ = r` empty |
| P2-T7 | Approved edits applied | MET | diffs of the four files. `circuit_test.exs` does more than a colour swap (see Deviations) |
| P2-T8 | Eye comparison recorded | MET | scratchpad L182-200; teleportation and QFT are also asserted by coordinate (`circuit_style_test:765,805`) |
| P2-T9 | Phase gate | UNCLEAR | docs warning count 23 not re-run |
| P3-T1 | Bloch tests (each item) | MET | great circles `bloch_style_test:194` (3 near, 3 far, `polyline == 8` excludes rings); silhouette and gradient (:144); accent-only vector and halo (:242,252); heads |0⟩/|+⟩ solid, |−⟩/|1⟩ hollow (:273); arcs and no-arcs at poles (:347,363); dot r 5.5 (:291,299) and threshold scales (:315); axes with no RGB (:379); letters and kets (:398,416); readout (:447-475); radius 33.5% (:165); size 240 fonts >= 80% (:509); title (:542,564); role/aria (:583); theme colours (:592); gradient ids (:181) |
| P3-T2 | Projection `project/2` | MET | `bloch.ex:26-33,218`; `@elevation = pi/10` (18°), azimuth pi/6 (30°) |
| P3-T3 | Great circles split at depth change | MET | `bloch.ex:308`; the halves-meet test (`bloch_style_test:219`) |
| P3-T4 | Body, plane, silhouette, axes, labels | MET | `bloch.ex` parts; tests :144-:430 |
| P3-T5 | Vector, head rule, dot, drop, arcs, readout; φ in [0, 2π) | MET | `bloch.ex:80-122` (`normalize_phi`, pole gives 0.0); head rule `near? = depth >= -@epsilon` (:540); short vector (:358,370) |
| P3-T6 | Scaling | PARTIAL | fonts clamp at 80% (`bloch.ex:182`, `@min_scale`). Strokes are also clamped, which departs from the plan wording (recorded in the P3-T6 note and scratchpad L218) |
| P3-T7 | Eye comparison recorded | MET | scratchpad L230-246 |
| P3-T8 | Phase gate | UNCLEAR | not re-run beyond the tests |
| P4-T1 | Draw moduledoc "Visual style" | MET | `draw.ex:30`; `qx.ex` docs |
| P4-T2 | README | MET | README diff, `style: :mono` snippet, "IEEE" removed |
| P4-T3 | CHANGELOG | MET | Added/Changed/Fixed in diff; the three required Fixed items present, plus two extras |
| P4-T4 | livemd cells | MET | `test/qx_manual_test.livemd` +185 lines; approval at scratchpad L88 |
| P4-T5 | Final gate | UNCLEAR | full suite, dialyzer, docs, hex.build not re-run by me. The draw subset passes |
| P4-T6 | Stop for review, no merge | MET | not verified beyond the git status given (working tree uncommitted) |
| IL#1,#2,#5,#6,#7,#9 | Iron Law section claims | MET | unknown atom raises (`theme.ex:84`); no processes; `validate_draw_size!` untouched at `draw.ex:397`; new modules `@moduledoc false`; options through `Validation`; `:p` deleted and the one-per-function test exists (`circuit_style_test:130`) |
| F1 | Fidelity: six family hex pairs | MET | `theme.ex:36-41` equals `design-guide.md` L38-75 (all 12 values) |
| F2 | Fidelity: Vega config | MET | `theme.ex:130-167` equals the guide JSON (design-guide.md L404-458) key for key. The test asserts the converted spec equals the guide's JSON (`theme_test:170`) |
| F3 | Fidelity: Bloch camera/radius/head/short vector/scale | MET | 30° and 18° (`bloch.ex:26-27`); radius 0.335 (:41); head solid when near, hollow when far (:540); short vector 20 and dot 5.5 (:53-54); fonts at 80% (:182) |

## Deviations

| # | Deviation | Recorded? | Approval needed / recorded? |
|---|---|---|---|
| D-1 | P1-T3 label-width test amended from per-text measurement (P(λ) 56, Rx(θ) 64) to measured widths plus per-kind minimum slot | Yes (plan P1-T3 note; scratchpad L113-125) | Applies to a NEW test, so no TDD approval is required. No explicit user sign-off is recorded for the amendment |
| D-2 | Bloch strokes clamped at 80% as well as fonts | Yes (P3-T6 note; scratchpad L218) | Plan wording only; no approval recorded. The justification (the 280px references) is recorded, and the drawings-win rule D5 was approved |
| D-3 | Seventh existing test edited: `test/qx/quantum_circuit_instruction_order_test.exs:~160` | Yes (scratchpad L260-271; P4-T5 note) | Required and recorded as approved by the user 2026-11-19 |
| D-4 | `circuit_test.exs` connector test renamed and its assertion changed ("terminates exactly at tip" became "both lines end inside the arrowhead", range check) | Yes (scratchpad L176-180: "more than a colour change; flagged for the review") | Covered by the P0-T1 approval row only loosely: the row promised "the same four geometric checks"; the test name and assertion strength changed. Flagged here for the human reviewer |
| D-5 | `iswap_svg_test.exs` also rewrote the non-adjacent assertion (`svg =~ "iSW"`) to a two-box check | Not separately recorded | Within the spirit of the P0-T1 iswap row (adjacent only is named); unrecorded. Low risk |
| D-6 | `test/qx_manual_test.livemd`: new cells | Yes (P4-T4) | Approved |
| D-7 | Extra option validation: `Qx.draw_bloch/2` `:title`/`:size`, `draw_circuit` `:title` and non-keyword second argument raise `Qx.OptionError` (`validation.ex` `validate_draw_title!`, `validate_draw_image_size!`) | Yes (scratchpad L244-246; CHANGELOG) | Behaviour change beyond the plan; no explicit approval recorded. Iron Law #7 is the stated justification |
| D-8 | Extra bug fixes: classical-bit index error; c_if gate-in-block validation (previously `FunctionClauseError`); conditional line crossing a gate (conditional gate now reserves wires to the register) | Yes (scratchpad L174-208; CHANGELOG, though the plan lists only three Fixed items) | None needed. The column-reservation change alters layout for conditional gates |
| D-9 | Barrier column: plan says "24-wide column"; implementation uses a zero-width column between two 24 gaps (a barrier takes the slot on every wire) | Yes (scratchpad P2-T1 table, layout decisions) | Equivalent to the drawings; not an approval matter |
| D-10 | Run-in 12 and run-out 16 instead of the prose's 14 and 4 | Yes (D5, accepted) | Approved (D5) |
| D-11 | Swap-cross, arrowhead and register slash markup differ from the guide's SVG (`line` vs `path`) | Yes (scratchpad L197-200; plan Decisions) | None |
| D-12 | Plan said "five circuit test files" (P2-T7) but P0-T1 table names six (swap_svg untouched, so four edited) | Yes (P2-T7 note) | None |
| D-13 | Added theme API beyond plan: `gates/0`, `palette/0`, `font/1`, `color/1` and extra `sphere_mid`/`sphere_edge` colours | Partly (P1-T2 note lists `gates/0`, `palette/0`) | None |
| D-14 | P1-T7: y title "Counts" and `.2f` ticks, no colour encoding; `label_expr` used for kets, so data values are unchanged | Yes (P1-T7 note; CHANGELOG) | None |
| D-15 | Readout is two spans with `dx 14` rather than two literal spaces; values use two decimals ("0.65π") | Not recorded | Cosmetic; the plan gives `θ = aπ  φ = bπ` loosely |
| D-16 | Bloch far-half dash `3 3` at 400 (the reference's 2.1 at 280 is consistent) | Not recorded | None |

## Details for non-MET items

- **S-In7 (PARTIAL).** The plan says "six existing test files" but four draw files are edited, plus one outside the plan (instruction_order, approved) and the livemd (approved, P4-T4). Nothing is unapproved, but the plan text and reality differ.
- **P1-T3 (PARTIAL).** The plan's literal assertion (P(λ) 56 and Rx(θ) 64 from `label_width/2` within 4px) is not tested, because the amended test (`markup_test.exs:191-201`) replaces it. The slots are tested through the minimum-width test (:201). The amendment has no recorded user sign-off, only a recorded reason.
- **P3-T6 (PARTIAL).** The plan said only fonts are clamped. Strokes are clamped too, so a 240px sphere has thicker strokes relative to its size than a pure `size/400` scale. The test at `bloch_style_test:509` checks fonts only; the stroke clamp has no explicit test below 400 (`:520` tests only growth above 400).
- **UNCLEAR gates (P1-T9, P2-T9, P3-T8, P4-T5).** Credo, dialyzer, `mix docs` warning count, `hex.build`, the `--no-optional-deps` compile and the full 1800-test run were not re-executed. Only the draw directory plus the instruction-order test (206 tests) were run, and they pass.
- **Doctest count (P2-T3)** 66 to 67 is claimed, not re-run.
