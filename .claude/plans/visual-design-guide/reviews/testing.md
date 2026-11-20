# Test Review: visual-design-guide (branch feat/visual-design-guide vs main)

Scope: 6 new test files, 5 edited .exs files (diff hunks only), the livemd section 12.
All new modules are `async: true`, pure, no Mox/Ecto/sleep. No non-deterministic input reaches an
assertion (no `Qx.run` in the draw tests). Verdict: no BLOCKER; one test that passes for the wrong
reason, one weakened edited assertion, several untested branches.

## Iron Law violations
None. (async yes; no Process.sleep; no mocks. `doctest Qx` exists in test/qx_test.exs, so the new
`draw_circuit` iex example in lib/qx.ex is executed. Theme and Markup are `@moduledoc false` with no
iex examples.)

## BLOCKER
None.

## WARNING

1. test/qx/draw/circuit_style_test.exs:728 - passes for the wrong reason.
   `assert_raise Qx.QubitCountError, fn -> Qx.Draw.circuit(Qx.create_circuit(21)) end`.
   `QuantumCircuit.new/1` already raises `QubitCountError` for >20 (lib/qx/quantum_circuit.ex:69-74,
   validation.ex:172), and the construction is inside the closure. The drawer's own guard
   (circuit.ex:136 `num_qubits > @max_qubits`) is never reached. The test is titled "typed errors ...
   unchanged". Fix: build a 20-qubit circuit and widen it: `%{Qx.create_circuit(20) | num_qubits: 21}`.

2. test/qx/draw/circuit_test.exs:78-112 - edited "connector" test is weaker than the original.
   Original: connector `y2 == tip_y` exactly, at x == tip_x (a gap or overshoot of any size failed).
   New: two vertical ink-2 lines at tip_x +/- 1.5 (good, strict) but `base_y <= y2 <= tip_y`.
   The lines sit 1.5 off the axis; the triangle (9 wide, 7 tall) is only 3 wide at 2.33 above... i.e. a
   line ending within 2.33 of the tip pokes outside the arrowhead outline. Current code ends at
   tip - 6 (circuit.ex:427, `upper_line - 6.5`), so the test would still pass if y2 drifted down by ~3.7
   units into a visible overshoot. The comment promises "inside the arrowhead"; the assertion does not
   enforce it. Fix: require the triangle half-width at y2 >= 1.5 (`y2 <= tip_y - 7 * 1.5 / 4.5`), or pin
   `y2 == base_y + 1.0`-style exact value as the old test pinned the tip.
   Same file, lines 26-50 (first edited test): the register is now two lines and the check is against
   the lower one (max y = 119.5) while the tip is at 116.0, so the tolerance grew from 0 to 3.5. Compare
   to the upper line (as the second test does with `min`) to keep it as tight as before.

3. test/qx/draw/circuit_style_test.exs:133-139 and 441-446 - mono style is only checked on 2 circuits.
   The catalogue loop draws every gate in `:mono` but asserts only "parses" (133-139) or "colour is in
   the full palette" (438-446, allowed includes every family colour). A family colour leaking in mono
   for iswap, cswap, ccx, rx/ry/rz/u/phase, cy/cr*, sdg/tdg is not caught; the strict mono check (739-745)
   covers only teleportation and qft3 (h, cx, cp, swap, measure, c_if x/z, barrier). Fix: in the
   catalogue loop assert mono colours subset of `[ink, ink2, muted, paper, "none"]`.

4. Untested branches in lib/qx/draw/svg/circuit.ex (input that reaches each):
   - 170-174 `Qx.ConditionalError`: `put_instructions(c, [{:c_if,[0,1],[{:c_if,[0,1],[{:x,[0],[]}]}]}])`
     and `[{:c_if,[0,1],[{:measure,[0,0],[]}]}]`. No draw test references ConditionalError.
   - 150-153 c_if with out-of-range classical bit: `{:c_if,[5,1],[{:x,[0],[]}]}` -> ClassicalBitError.
   - 156-159 `{:measure,[q,c],[]}` *instruction* with bad q or c. Test 733 covers only the
     `measurements:` field, not the instruction clause.
   - 621 `aria_label` for 1 qubit and no title ("Quantum circuit, 1 qubit"): test 449-451 uses 2 qubits.
   - 333 control below target for cx/ccx/cswap (`Qx.cx(1,0)`, `Qx.ccx(0,2,1)`, `Qx.cswap(2,0,1)`):
     only `cp(1,0)` (343) and the guide circuits exercise reversed order. `iswap(1,0)`, `swap(2,0)` too
     (min/max at 381-382).
   - 216-217 `occupied_wires` for a *multi-qubit* gate inside c_if (cy/crz in a c_if): test 152 only checks
     `<svg`, so column placement and condition line start (`bottom`) are unverified.

5. Untested branches in lib/qx/draw/svg/bloch.ex:
   - 123 clamp `max(-1.0, min(1.0, |alpha|))`: `Nx.tensor([Complex.new(1.0000001,0.0), Complex.new(0.0,0.0)], type: :c64)`
     would raise ArithmeticError in `acos` without it. No test.
   - 609-612 the `"2.00" -> "0.00"` readout branch: phi = 2*pi - 0.001 (above the 1e-6 normalise epsilon,
     rounds to 2.00). The noise test at bloch_style_test.exs:475 only covers the <1e-6 path (146).
   - Global phase on a non-pole state (e.g. general() times e^{i}): only pole states are tested for
     phase invariance (471).
   - 508-ish/453 thresholds `@hidden_epsilon` (0.02) at a state a hair off a pole: untested boundary.
   - Stroke floor: the 240-size test (509-518) checks fonts only; stroke widths at 80% are not asserted.

6. test/support/gate_catalogue.ex:108-116 - regex-reading lowering.ex is not a sound tracking mechanism.
   - Couples to source formatting (`"name" => {:atom, N, N}` on one line); an entry reshaped (4-tuple,
     computed arity, multi-line) is silently dropped. The only guard is `length(atoms) >= 20`
     (theme_test.exs:80) against 24 real atoms, so losing up to 4 passes.
   - Relative path `File.read!("lib/...")` depends on cwd.
   - Tracks only the table; atoms the importer emits outside it (measure, barrier, c_if) are not seen.
   - It adds almost nothing today: every table atom is already a catalogue atom, so `qasm_atoms` cannot
     make any test fail unless the importer gains an atom no Operations function emits - exactly the case
     where a regex miss would hide it.
   Better: a `@doc false` accessor on the lowering module (`gate_atoms/0` from `@stdgate_table`), or drive the
   real importer with one snippet per table key. Also `String.to_existing_atom` (115) is safe only because the
   atoms exist elsewhere; an importer-only atom raises ArgumentError instead of a useful message.
   `uncovered/0` itself: matches `{module, name}` not arity; no reverse check (stale entry for a removed
   function never fails); a new non-gate public helper in Operations/Patterns fails 2 tests until added
   to `@not_producers`; the `{Module, :name, circuit}` tag is a label never checked against what the circuit
   calls (a copy-paste mismatch is undetected). Only `Qx.Operations` and `Qx.Patterns` are watched.

## SUGGESTION

1. test/qx/draw/chart_style_test.exs:225 - `Enum.shuffle |> Map.new` does nothing: a 40-key map has hash
   order whatever the insertion order. The test is still sound (hash order is unsorted so it fails without
   the sort), but the comment's claim is untrue. Delete the shuffle.

2. bloch_style_test.exs:524, 528 - `Enum.zip` without a length assertion (the 240 test has one at 513, the 800
   test does not). Add `assert length(a) == length(b)` to both.

3. Float `==` on parsed, 1-decimal-rounded attribute values: circuit_style_test.exs:225, 334, 492, 582, 595,
   616, 620. Pass today because every centre is a multiple of 0.5 (widths are 32/56/64/84 or a multiple of 4).
   They will fail for a harmless width change (e.g. 30 or 33). Use `assert_in_delta ..., 0.05`.

4. Markup coupling: exact-string matches of attribute order at circuit_style_test.exs:542, 566, 385, 267-268
   and the edited regexes `stroke="#5D3A9B"[^>]*stroke-linecap="round"` (cswap_svg_test), `<text x="..."[^>]*><tspan`
   (quantum_circuit_instruction_order_test.exs:160) and `<line x1=.. y1=.. x2=.. y2=.. stroke=` (circuit_test.exs:32,55,
   second connector regex). A harmless attribute reorder breaks them; circuit_style_test already has an
   order-independent `elements/attributes` helper. Move it (and the "plain text of every <text>" helper that is
   pasted 6 times across circuit_test/iswap/u) into test/support and reuse.
   Bloch tests depend on the `<g data-part>` seam with a lazy `</g>` regex (bloch_style_test.exs:87); breaks if
   groups nest. Acceptable but note it is an implementation-private contract.

5. Mono assertion at circuit_style_test.exs:757-758 `geometry.(mono) == geometry.(color)` only compares boxes;
   wires/dots/text positions are not compared.

6. Chart gaps: `axis: [format: ".2f"]` on the probability y axis (vega_lite.ex:32) is not asserted; plot/histogram at 17
   and 65 bars not tested (counts is). Bar counts 1, 9, 17, 65 are not powers of two, so `state_label`
   output for them is meaningless; harmless today since no label is asserted for those sizes.

7. Option edges not pinned: `title: ""` (truthy in `if title`, gives top=52, empty title text and `aria-label=""` in both circuit and
   Bloch); unknown keys such as `[stile: :mono]` are silently ignored by `draw_circuit_options!`;
   `size: -1`/`0.5` for Bloch (only 0 and "400" tested). Decide and pin.

8. `setup_all Mix.ensure_application!(:xmerl)` (circuit_style_test.exs:25, bloch_style_test.exs:26): works under mix
   test and is idempotent, so async-safe. But `xmerl` is not in `extra_applications` (mix.exs:50), and `parse_xml!`
   only proves well-formedness (xmerl `exit`s on error, which fails the test; the returned record is always truthy).
   Bloch SVG has no XML declaration, so non-ASCII bytes from `:binary.bin_to_list` parse as Latin-1 codepoints, not
   as the intended characters. Move the helper and ensure call to one place (test_helper.exs or support module).

9. theme_test.exs:155-157, 148-153 - `palette/0` is only checked for inclusion; extras are not detected; the
   `:sphere_mid`/`:sphere_edge` colours are not asserted in theme_test (they are, by hex, in bloch_style_test:150).
   theme_test.exs:88-91 "gates/0 is exactly the set emitted" forbids Theme from ever supporting an extra gate;
   intended, but say so in the name.

10. bloch_style_test.exs:385-387 - refuting four legacy hex colours (#FF5733...) is dead weight given the palette test
    at 592-600; remove.

## Edited existing tests (intent check)

| File | Verdict |
|---|---|
| circuit_test.exs 29-60 (colour 778899 -> 4A5261) | colour swap fine; bottom-line tolerance loosened 0 -> 3.5 (see WARNING 2) |
| circuit_test.exs:78 connector | weakened (see WARNING 2); double-line offsets check is a good addition |
| circuit_test.exs:138,151 T†/S† | equivalent or stronger (needs a standalone "T†" label); does not check the dagger is raised |
| cswap_svg_test.exs | stronger than `=~ "×"` (4 round-capped exchange lines); does not tie crosses to the two targets |
| iswap_svg_test.exs | intent deliberately changed (one box vs two labels); new asserts are strict |
| u_svg_test.exs | equivalent (`starts_with?("U(")`); two identical copies |
| quantum_circuit_instruction_order_test.exs:160 | intent kept (exactly one matching label); regex now assumes a single bare `<tspan>` |
| qx_manual_test.livemd s12 | consistent with the code: `pi` defined line 11, Kino/kino_vega_lite installed, column order in the controlled-gate cell matches `place/2`, S† over U column correct |

## Pre-existing (one line each)
- iswap_svg_test / u_svg_test / cswap_svg_test "SVG contains rect elements" is satisfied by the background `<rect>` alone.
- `doctest Qx` is declared twice (test/qx_test.exs:3, test/complex_support_test.exs:3).
