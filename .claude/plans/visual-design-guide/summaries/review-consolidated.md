# Consolidated Summary

**Strategy**: Compress
**Input**: 4 files (elixir.md, testing.md, iron-laws.md, requirements.md), ~10k tokens
**Output**: ~5k tokens (~50% reduction)

Branch: feat/visual-design-guide. Reviewers: elixir-reviewer (elixir.md), testing-reviewer (testing.md), iron-law-judge (iron-laws.md), requirements verifier (requirements.md).

## What reviewers did NOT run or could not confirm

- **elixir-reviewer**: read-only, nothing was run. Items marked UNCONFIRMED could not be verified by reading alone.
- **testing-reviewer**: no statement of commands run or not run. Review was by reading the diff and tests.
- **iron-law-judge**: static read only, no Bash. `mix compile`, `mix format`, `mix credo`, `mix test` were NOT run, so VERIFICATION is unconfirmed. `Qx.barrier_all(qc, [])` was not read (unconfirmed). Plan claims full suite 1800/1800, dialyzer clean, docs warnings same as main (P4-T4/T5); the orchestrator should run `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict`.
- **requirements verifier**: ran `mix test test/qx/draw test/qx/quantum_circuit_instruction_order_test.exs` (206 passed). Did NOT re-run credo, dialyzer, docs, hex.build, `--no-optional-deps` compile or the full suite. The doctest count rise 66 to 67 is claimed, not re-run. So the P1-T9, P2-T9, P3-T8 and P4-T5 gate claims are UNCLEAR for those parts.

## BLOCKERs

None from any reviewer (elixir, testing, iron-law-judge; the verifier reports 0 UNMET).

## WARNINGs

### Source code

**W-A. Empty barrier raises raw `Enum.EmptyError`** (flagged by both iron-law-judge W1 and elixir-reviewer W1; iron-law-judge version kept)
- `lib/qx/draw/svg/circuit.ex:445`, `:446`, also `:217`, `:221` (`Enum.min/max([])`).
- Input: `Qx.create_circuit(2) |> Qx.barrier([]) |> Qx.draw_circuit()`. `Operations.barrier/2` accepts `[]` (`validate_qubit_indices!([])` is `:ok`) and `add_barrier/2` emits `{:barrier, [], []}`. Same for `Qx.barrier_all(qc, [])` (iron-law-judge: not read, unconfirmed).
- `place/2` is fine (its barrier clause ignores `qubits`). The OpenQASM importer always supplies indices, so only the builder API reaches it. The old renderer also took `Enum.min(qubits)` on barriers (removed lines near diff line 2290), so probably not new.
- Suggested fix: in `validate_instruction!` treat `{:barrier, [], _}` as nothing to draw (drop in `flatten/1`), raise a typed `Qx.GateError`/`Qx.QubitIndexError`, or draw a full-height barrier (elixir-reviewer).

**W-B. Malformed instruction shape raises raw `FunctionClauseError`** (iron-law-judge W2)
- `circuit.ex:163-166` `validate_instruction!/2` checks only that the atom has a family and the indices are in range, not arity. The old code had a catch-all `raise Qx.GateError, {:unsupported_gate, gate_name}`; the new `draw/3` has none.
- Input: `Qx.QuantumCircuit.put_instructions(qc, [{:cx, [0], []}])` then `draw_circuit` (also `{:h, [0, 1], []}`, `{:measure, [0], []}`). `put_instructions/2` is `@doc false` and does not validate. No public producer emits these.
- Fix: add a final catch-all `defp draw(%{gate: gate, qubits: qubits}, _x, _context)` raising `Qx.GateError`, or check arity per gate.

**W-C. Huge integer angle or oversized `:size` raises raw `ArithmeticError`** (iron-law-judge W3; angle half also elixir-reviewer SUGGESTION 14)
- `Markup.angle/1` `lib/qx/draw/svg/markup.ex:119`, `:140` (`value / :math.pi()`, `abs(value) * 1.0`). Input: `Qx.rx(qc, 0, 10 ** 400) |> Qx.draw_circuit()`. `validate_parameter!` accepts any number. `angle/1` promises a fallback to a plain number (elixir-reviewer; markup.ex:103-129).
- `Bloch.short_vector?` `bloch.ex:372` and `vector/2` `:539` square pixel distances. `validate_draw_image_size!` (`validation.ex:285`) accepts any positive number. Input: `Qx.draw_bloch(state, size: 1.0e160)`.
- Fix: cap `:size` (for example `<= 100_000`) and guard the angle with `is_float`/range.

**W-D. Bloch input and option shape give raw errors** (iron-law-judge W4; the `draw.ex` string-options part also flagged by elixir-reviewer W4; iron-law-judge version kept)
- `bloch.ex:120` `[alpha, beta] = Nx.to_flat_list(qubit)` raises `MatchError` for a non-2-element tensor. Input: `Qx.draw_bloch(Qx.get_state(two_qubit_circuit))`. For a large state it first builds the whole 2^n host list (Iron Law #5 hazard). Pre-existing line, still reachable.
- `Qx.draw_bloch(:not_a_tensor)` raises an Nx `ArgumentError`. A NaN tensor makes `Complex.abs(:nan)` fail.
- `Qx.draw_bloch(state, "My title")` raises `FunctionClauseError` from `Keyword.get` (`draw.ex:283-284`), inconsistent with `draw_circuit/2` which accepts a bare title. Likewise `Qx.draw(result, "title")`, `Qx.draw_counts/2`, `Qx.draw_histogram/2` at `draw.ex:127-129`, `:181-183`, `:228-230` (pre-existing per elixir-reviewer). Violates the typed-error rule in AGENTS.md.
- Fix: validate tensor shape (`Nx.size == 2`) in `Bloch.qubit_to_bloch_coordinates` via `Qx.Validation`; run options through a validator raising `Qx.OptionError`, as `draw_circuit_options!/1` does.

**W-E. Float32 noise defeats the Bloch pole guard, garbage φ in readout** (flagged by both iron-law-judge #8 note and elixir-reviewer W2; iron-law-judge version kept; both: UNCONFIRMED, not run)
- `lib/qx/draw/svg/bloch.ex:127` (elixir-reviewer: `:123-130`) tests `sin(theta) < 1.0e-6`. θ = 2·acos(|α|) amplifies noise: |α| = 1 − 6e-8 (one c64 ulp) gives θ ≈ 3.5e-4, sin θ ≈ 3.5e-4 (elixir-reviewer: |α| = 0.99999994 gives θ ≈ 6.9e-4), far above `@epsilon = 1e-6` (`bloch.ex:76`). φ = arg β − arg α is then taken from noise.
- Input: `Qx.create_circuit(1) |> Qx.h(0) |> Qx.h(0) |> Qx.get_state()`. Readout may show `θ = 0.00π  φ = 1.00π` or a random φ. Arcs are hidden at 0.02 but the readout is not. CHANGELOG claim "φ is 0 at a pole" holds only for exact poles.
- Suggested: threshold near 1e-3 (iron-law-judge); or take θ from `atan2(|β|, |α|)` (also correct for non-normalised input) and gate φ on |α|, |β| against about 1e-4 (elixir-reviewer).
- Related (elixir-reviewer): a non-normalised state such as (0.5, 0) draws a unit vector with θ from |α| alone and meaningless φ.

**W-F. `escape/1` does not strip XML 1.0 illegal characters** (elixir-reviewer W3 only)
- `lib/qx/draw/svg/markup.ex:68-76`, `circuit.ex:611`, `bloch.ex:595`.
- Input: `Qx.draw_circuit(qc, "a" <> <<0>> <> "b")` or `title: "x\u0001"` yields invalid SVG; browsers show an XML parse error. `Validation.validate_draw_title!/1` checks only `is_binary`, so invalid UTF-8 also passes.
- Fix: drop characters outside `#x9 | #xA | #xD | #x20-#xD7FF | #xE000-#xFFFD | #x10000-#x10FFFF` in `escape/1`, or require `String.valid?/1` plus a control-character check raising `Qx.OptionError`.

### Tests (testing-reviewer)

**W-G. Test passes for the wrong reason**: `test/qx/draw/circuit_style_test.exs:728`, `assert_raise Qx.QubitCountError, fn -> Qx.Draw.circuit(Qx.create_circuit(21)) end`. `QuantumCircuit.new/1` already raises for >20 (`lib/qx/quantum_circuit.ex:69-74`, `validation.ex:172`) inside the closure, so the drawer guard (`circuit.ex:136` `num_qubits > @max_qubits`) is never reached. Fix: `%{Qx.create_circuit(20) | num_qubits: 21}`.

**W-H. Edited connector test weaker than original**: `test/qx/draw/circuit_test.exs:78-112`. Original: connector `y2 == tip_y` exactly at `x == tip_x`. New: two vertical ink-2 lines at tip_x +/- 1.5 but only `base_y <= y2 <= tip_y`. Current code ends at tip - 6 (`circuit.ex:427`, `upper_line - 6.5`); the test would still pass if y2 drifted down about 3.7 units into a visible overshoot. Fix: require `y2 <= tip_y - 7 * 1.5 / 4.5`, or pin an exact y2. Also `circuit_test.exs:26-50`: register is now two lines and the check is against the lower (max y = 119.5, tip 116.0), so tolerance grew from 0 to 3.5; compare to the upper line. (Verifier D-4 flags the same test as changed beyond the approval row.)

**W-I. Mono style checked on only 2 circuits**: `circuit_style_test.exs:133-139` and `:441-446` (catalogue loop asserts only "parses" or "colour in full palette"); strict mono check `:739-745` covers only teleportation and qft3. A family colour leaking in mono for iswap, cswap, ccx, rx/ry/rz/u/phase, cy/cr*, sdg/tdg is undetected. Fix: in the catalogue loop assert mono colours subset of `[ink, ink2, muted, paper, "none"]`.

**W-J. Untested branches in `lib/qx/draw/svg/circuit.ex`** (concrete inputs):
- `:170-174` `Qx.ConditionalError`: `put_instructions(c, [{:c_if,[0,1],[{:c_if,[0,1],[{:x,[0],[]}]}]}])` and `[{:c_if,[0,1],[{:measure,[0,0],[]}]}]`. No draw test references ConditionalError.
- `:150-153` c_if out-of-range classical bit: `{:c_if,[5,1],[{:x,[0],[]}]}` gives ClassicalBitError.
- `:156-159` `{:measure,[q,c],[]}` instruction with bad q or c (test 733 covers only the `measurements:` field).
- `:621` `aria_label` for 1 qubit, no title ("Quantum circuit, 1 qubit"); test 449-451 uses 2 qubits.
- `:333` control below target: `Qx.cx(1,0)`, `Qx.ccx(0,2,1)`, `Qx.cswap(2,0,1)`; also `iswap(1,0)`, `swap(2,0)` (min/max at 381-382). Only `cp(1,0)` (343) and guide circuits cover reversed order.
- `:216-217` `occupied_wires` for a multi-qubit gate in c_if (cy/crz): test 152 only checks `<svg`, so column placement and condition line start (`bottom`) unverified.

**W-K. Untested branches in `lib/qx/draw/svg/bloch.ex`**:
- `:123` clamp `max(-1.0, min(1.0, |alpha|))`: `Nx.tensor([Complex.new(1.0000001,0.0), Complex.new(0.0,0.0)], type: :c64)` would raise ArithmeticError in `acos` without it.
- `:609-612` the `"2.00" -> "0.00"` readout branch: phi = 2*pi - 0.001. Noise test `bloch_style_test.exs:475` covers only the <1e-6 path (146).
- Global phase on a non-pole state (e.g. general() times e^{i}); only pole states tested (471).
- `@hidden_epsilon` (0.02) boundary at a state a hair off a pole (about 508/453).
- Stroke floor: 240-size test (509-518) checks fonts only; stroke widths at 80% not asserted (also noted by verifier under P3-T6).

**W-L. `test/support/gate_catalogue.ex:108-116` regex-reading `lowering.ex` is not a sound tracking mechanism**:
- Couples to source formatting (`"name" => {:atom, N, N}` on one line); a reshaped entry (4-tuple, computed arity, multi-line) is silently dropped. Only guard is `length(atoms) >= 20` (`theme_test.exs:80`) against 24 real atoms, so up to 4 can be lost.
- Relative path `File.read!("lib/...")` depends on cwd. Tracks only the table, not atoms emitted outside it (measure, barrier, c_if).
- Adds almost nothing today: `qasm_atoms` can fail a test only if the importer gains an atom no Operations function emits, which is exactly when a regex miss hides it.
- `String.to_existing_atom` (115) is safe only because atoms exist elsewhere; an importer-only atom raises ArgumentError rather than a useful message.
- `uncovered/0`: matches `{module, name}` not arity; no reverse check (stale entry never fails); a new non-gate public helper in Operations/Patterns fails 2 tests until added to `@not_producers`; the `{Module, :name, circuit}` tag is never checked against what the circuit calls; only `Qx.Operations` and `Qx.Patterns` watched.
- Better: a `@doc false` accessor `gate_atoms/0` on the lowering module from `@stdgate_table`, or drive the real importer with one snippet per table key.

## Iron Laws verdicts (iron-law-judge)

Law 7 WARNING (W-A to W-D above), Law 8 OK with the pole epsilon note (W-E), all others OK or N/A: #1 atoms OK (`test/support/gate_catalogue.ex:115` `to_existing_atom` is bounded and test-only), #2 OK, #3/#4 N/A, #5 OK (size guards precede host loops in `plot/2`, `counts/2`, `histogram/2`; pre-existing `bloch.ex:120` unguarded), #6 OK (CHANGELOG complete; release MUST be 0.13.0 minor, not 0.12.1 patch), #9 OK (all 27 atoms have Theme family, `width/1` and `draw/3` coverage; no dead clauses), TDD OK. Testing-reviewer also found no Iron Law violations in tests.

Doc nit (iron-law-judge): `Raises` blocks of `Qx.draw_circuit/2` and `Qx.Draw.circuit/2` omit `GateError`, `QubitIndexError`, `ClassicalBitError`, `ConditionalError`.

## SUGGESTIONs (compressed)

**Empty-string and unknown option handling** (elixir 5, 6; testing 7)
- `title: ""` is truthy in `if title` (`circuit.ex:96, 114, 619`): 52-unit top margin, empty `<text>`, `aria-label=""` in circuit and Bloch. Normalise to nil in the validator.
- Unknown keys silently ignored (`validation.ex:258-265`, e.g. `draw_circuit_options!(titel: "x")`, `[stile: :mono]`). Consider raising `Qx.OptionError`.
- Bloch `size: -1`/`0.5` untested (only 0 and "400"). Decide and pin.

**Number and readout formatting** (elixir 7, 8, 9)
- `markup.ex:104-111`: 0.0008 prints "0", 0.004 prints "0.00", -0.004 prints "-0.00".
- `bloch.ex:605-614`: for φ >= 1.995π the arc is drawn near full circle while readout shows "0.00π"; use the same rounded φ.
- `circuit.ex:616-617` title width by `String.length`; CJK/emoji can overflow the viewBox.

**Code duplication and performance** (elixir 10, 11, 12, 13)
- `circuit.ex:230` `width(gate)` computed twice per `Map.update` (allocates graphemes); bind once.
- `circuit.ex` no gate-count cap; 10k gates gives a multi-megabyte SVG; document.
- `draw.ex:235-241` vs `vega_lite.ex:62-68` duplicate state/probability data construction; share a helper.
- `vega_lite.ex:90` empty counts ignores caller `title` (always "No Measurements").

**Test fragility and style** (testing 1-5, 8-10)
- `chart_style_test.exs:225` `Enum.shuffle |> Map.new` is a no-op (hash order); delete, the comment claim is untrue.
- `bloch_style_test.exs:524, 528` `Enum.zip` without length assert (240 test has one at 513).
- Float `==` on 1-decimal-rounded attributes at `circuit_style_test.exs:225, 334, 492, 582, 595, 616, 620`; use `assert_in_delta ..., 0.05`.
- Markup-order coupling: exact attribute-order strings at `circuit_style_test.exs:542, 566, 385, 267-268`; edited regexes in cswap_svg_test, `quantum_circuit_instruction_order_test.exs:160`, `circuit_test.exs:32, 55`. Move the order-independent `elements/attributes` helper and the six-times-pasted "plain text of every `<text>`" helper (circuit_test/iswap/u) into `test/support`. Bloch tests depend on `<g data-part>` with a lazy `</g>` regex (`bloch_style_test.exs:87`), breaks if groups nest.
- Mono geometry compare (`circuit_style_test.exs:757-758`) only checks boxes.
- `setup_all Mix.ensure_application!(:xmerl)` (`circuit_style_test.exs:25`, `bloch_style_test.exs:26`): `xmerl` not in `extra_applications` (`mix.exs:50`); `parse_xml!` only proves well-formedness; Bloch SVG has no XML declaration so non-ASCII parses as Latin-1. Centralise in `test_helper.exs` or a support module.
- `theme_test.exs:155-157, 148-153` palette checked for inclusion only; `:sphere_mid`/`:sphere_edge` asserted only in `bloch_style_test:150`; `theme_test.exs:88-91` "gates/0 is exactly the set emitted" forbids extra gates (say so in the name).
- `bloch_style_test.exs:385-387` refuting four legacy hex colours is dead weight given the palette test at 592-600.

**Chart gaps** (testing 6): `axis: [format: ".2f"]` (`vega_lite.ex:32`) not asserted; plot/histogram at 17 and 65 bars not tested (counts is); bar counts 1, 9, 17, 65 are not powers of two so `state_label` output is meaningless there (harmless today).

**Edited existing tests intent check** (testing): `circuit_test.exs:138,151` T†/S† equivalent or stronger but do not check the dagger is raised; `cswap_svg_test` stronger but does not tie crosses to the two targets; `iswap_svg_test` intent deliberately changed (one box vs two labels); `u_svg_test` equivalent (two identical copies); `quantum_circuit_instruction_order_test.exs:160` regex assumes a single bare `<tspan>`; `qx_manual_test.livemd` s12 consistent with code.

**Pre-existing (one line each)**: iswap/u/cswap_svg_test "SVG contains rect elements" satisfied by the background `<rect>`; `doctest Qx` declared twice (`test/qx_test.exs:3`, `test/complex_support_test.exs:3`); `bloch.ex:120` and `draw.ex:127-129, 181-183, 228-230, 283-284` (see W-D).

**Checked and found OK (elixir-reviewer, brief)**: every `Theme.@gate_families` atom has a `draw/3` clause; `columns/1` contiguity; `num/2` "-0"; `normalize_phi/1` poles and φ≈0; near/far great-circle split; measure/conditional always has a register; Theme has no VegaLite reference; nil options map to JSON null; bar thresholds 16/17, 64/65 consistent; unequal-length counts keys do not crash.

## Requirements Coverage (from plan file .claude/plans/visual-design-guide/plan.md)

**47 MET, 3 PARTIAL, 0 UNMET, 2 UNCLEAR** (`mix test test/qx/draw test/qx/quantum_circuit_instruction_order_test.exs`: 206 passed, run by me. I did not re-run credo, dialyzer, docs, hex.build or the full suite, so P1-T9, P2-T9, P3-T8 and P4-T5 gate claims are UNCLEAR for those parts.)

(Note: the verifier's summary line counts 2 UNCLEAR, but its table marks four rows UNCLEAR: P1-T9, P2-T9, P3-T8, P4-T5. Reproduced as written.)

### PARTIAL and UNCLEAR rows

| # | Requirement | Status | Evidence |
|---|---|---|---|
| S-In7 | New tests plus approved edits to six existing files | PARTIAL | 5 new test files; 4 existing draw test files edited (circuit, cswap, iswap, u). `swap_svg_test` correctly untouched. A 5th existing file outside the plan (`quantum_circuit_instruction_order_test.exs`) and `qx_manual_test.livemd` were also edited; see Deviations |
| P1-T3 | Markup tests | PARTIAL | escape (`markup_test:12`), math_label (:106-149), angle (:56-99), q subscript (:135) all asserted. The widths test (:191) uses the AMENDED spec (measured H 32, P(π/4) 56, Rx(π/2) 64, U 84 plus per-kind minimum), not the plan text "P(λ) 56, Rx(θ) 64 within 4px". Amendment recorded in the plan note and scratchpad L113-125; no human approval recorded |
| P3-T6 | Scaling | PARTIAL | fonts clamp at 80% (`bloch.ex:182`, `@min_scale`). Strokes are also clamped, which departs from the plan wording (recorded in the P3-T6 note and scratchpad L218) |
| P1-T9 | Phase gate | UNCLEAR | draw tests pass here; credo, format and `--no-optional-deps` not re-run. `theme.ex` has no `VegaLite` reference at compile time, which is consistent |
| P2-T9 | Phase gate | UNCLEAR | docs warning count 23 not re-run |
| P3-T8 | Phase gate | UNCLEAR | not re-run beyond the tests |
| P4-T5 | Final gate | UNCLEAR | full suite, dialyzer, docs, hex.build not re-run by me. The draw subset passes |

Details for non-MET items:
- **S-In7 (PARTIAL).** The plan says "six existing test files" but four draw files are edited, plus one outside the plan (instruction_order, approved) and the livemd (approved, P4-T4). Nothing is unapproved, but the plan text and reality differ.
- **P1-T3 (PARTIAL).** The plan's literal assertion (P(λ) 56 and Rx(θ) 64 from `label_width/2` within 4px) is not tested, because the amended test (`markup_test.exs:191-201`) replaces it. The slots are tested through the minimum-width test (:201). The amendment has no recorded user sign-off, only a recorded reason.
- **P3-T6 (PARTIAL).** The plan said only fonts are clamped. Strokes are clamped too, so a 240px sphere has thicker strokes relative to its size than a pure `size/400` scale. The test at `bloch_style_test:509` checks fonts only; the stroke clamp has no explicit test below 400 (`:520` tests only growth above 400).
- **UNCLEAR gates (P1-T9, P2-T9, P3-T8, P4-T5).** Credo, dialyzer, `mix docs` warning count, `hex.build`, the `--no-optional-deps` compile and the full 1800-test run were not re-executed. Only the draw directory plus the instruction-order test (206 tests) were run, and they pass.
- **Doctest count (P2-T3)** 66 to 67 is claimed, not re-run.

All other rows (G, S-In1..6, S-In8, S-Out1..7, API1-3, P0-T1..3, P1-T1,2,4..8, P2-T1..8, P3-T1..5,7, P4-T1..4,6, IL#1,#2,#5,#6,#7,#9, F1-F3) are MET. P4-T6 "no merge" not verified beyond the given git status.

### Deviations (full list)

| # | Deviation | Recorded? | Approval needed / recorded? |
|---|---|---|---|
| D-1 | P1-T3 label-width test amended from per-text measurement (P(λ) 56, Rx(θ) 64) to measured widths plus per-kind minimum slot | Yes (plan P1-T3 note; scratchpad L113-125) | Applies to a NEW test, so no TDD approval is required. No explicit user sign-off is recorded for the amendment |
| D-2 | Bloch strokes clamped at 80% as well as fonts | Yes (P3-T6 note; scratchpad L218) | Plan wording only; no approval recorded. The justification (the 280px references) is recorded, and the drawings-win rule D5 was approved |
| D-3 | Seventh existing test edited: `test/qx/quantum_circuit_instruction_order_test.exs:~160` | Yes (scratchpad L260-271; P4-T5 note) | Required and recorded as approved by the user 2026-11-19 |
| D-4 | `circuit_test.exs` connector test renamed and its assertion changed ("terminates exactly at tip" became "both lines end inside the arrowhead", range check) | Yes (scratchpad L176-180: "more than a colour change; flagged for the review") | Covered by the P0-T1 approval row only loosely: the row promised "the same four geometric checks"; the test name and assertion strength changed. Flagged for the human reviewer |
| D-5 | `iswap_svg_test.exs` also rewrote the non-adjacent assertion (`svg =~ "iSW"`) to a two-box check | Not separately recorded | Within the spirit of the P0-T1 iswap row (adjacent only is named); unrecorded. Low risk |
| D-6 | `test/qx_manual_test.livemd`: new cells | Yes (P4-T4) | Approved |
| D-7 | Extra option validation: `Qx.draw_bloch/2` `:title`/`:size`, `draw_circuit` `:title` and non-keyword second argument raise `Qx.OptionError` (`validation.ex` `validate_draw_title!`, `validate_draw_image_size!`) | Yes (scratchpad L244-246; CHANGELOG) | Behaviour change beyond the plan; no explicit approval recorded. Iron Law #7 is the stated justification |
| D-8 | Extra bug fixes: classical-bit index error; c_if gate-in-block validation (previously `FunctionClauseError`); conditional line crossing a gate (conditional gate now reserves wires to the register) | Yes (scratchpad L174-208; CHANGELOG, though the plan lists only three Fixed items) | None needed. The column-reservation change alters layout for conditional gates |
| D-9 | Barrier column: plan says "24-wide column"; implementation uses a zero-width column between two 24 gaps | Yes (scratchpad P2-T1 table) | Equivalent to the drawings; not an approval matter |
| D-10 | Run-in 12 and run-out 16 instead of the prose's 14 and 4 | Yes (D5, accepted) | Approved (D5) |
| D-11 | Swap-cross, arrowhead and register slash markup differ from the guide's SVG (`line` vs `path`) | Yes (scratchpad L197-200; plan Decisions) | None |
| D-12 | Plan said "five circuit test files" (P2-T7) but P0-T1 table names six (swap_svg untouched, so four edited) | Yes (P2-T7 note) | None |
| D-13 | Added theme API beyond plan: `gates/0`, `palette/0`, `font/1`, `color/1` and extra `sphere_mid`/`sphere_edge` colours | Partly (P1-T2 note lists `gates/0`, `palette/0`) | None |
| D-14 | P1-T7: y title "Counts" and `.2f` ticks, no colour encoding; `label_expr` used for kets, so data values unchanged | Yes (P1-T7 note; CHANGELOG) | None |
| D-15 | Readout is two spans with `dx 14` rather than two literal spaces; values use two decimals ("0.65π") | Not recorded | Cosmetic |
| D-16 | Bloch far-half dash `3 3` at 400 (the reference's 2.1 at 280 is consistent) | Not recorded | None |

## Coverage

| File | Represented | Key Items |
|---|---|---|
| elixir.md | Yes | 4 WARNING (W-A, W-E, W-F, W-D), 10 SUGGESTION grouped, checked-OK list |
| testing.md | Yes | 0 BLOCKER, 6 WARNING (W-G to W-L), 10 SUGGESTION grouped, edited-test table |
| iron-laws.md | Yes | 0 BLOCKER, 4 WARNING (W-A to W-D) plus pole-epsilon note (W-E), law verdicts |
| requirements.md | Yes | Coverage line, 3 PARTIAL, 4 UNCLEAR rows, 16 deviations in full |

## Coverage Gaps

None.
