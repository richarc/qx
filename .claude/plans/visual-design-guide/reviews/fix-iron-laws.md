# Iron Law Judge: fix commit f0c1dec (feat/visual-design-guide)

Method: read the fix diff, CHANGELOG [Unreleased], circuit.ex, bloch.ex, draw.ex, validation.ex, quantum_circuit.ex producers, operations.ex, lowering.ex. Nothing was run.

Checked 7 of 9 applicable Qx laws (#1, #2, #5, #6, #7, #8, #9; #3/#4 untouched). Violations: 0 critical, 1 WARNING (#6 flagging), 2 SUGGESTIONS (#7 residuals).

## #9 Dispatch completeness: PASS
Producer shapes traced against circuit.ex `@qubit_counts` (lines 69-73) and the validate_instruction! clauses (163-197):
- Single-qubit gates: `QuantumCircuit.add_gate` stores `{g, [q], params}` (quantum_circuit.ex:141). All of `@boxed` map to 1. `:u` stores 3 params, which are not count-checked, so it passes.
- Two-qubit gates (cx, cz, swap, iswap, cp, cy, crx, cry, crz): `add_two_qubit_gate` stores `{g, [c, t], params}` (quantum_circuit.ex:167). All map to 2.
- ccx and cswap: `add_three_qubit_gate` stores 3 qubits (quantum_circuit.ex:187), mapped to 3.
- measure: `{:measure, [q, c], []}` (quantum_circuit.ex:225). It hits the dedicated clause at circuit.ex:170 before the generic one.
- barrier: `{:barrier, qubits, []}` (quantum_circuit.ex:242). A non-empty list passes (circuit.ex:179). `[]` is the intended GateError.
- c_if: `{:c_if, [bit, value], block}` with `value in [0, 1]` (operations.ex:847), so `is_integer(value) and is_list(block)` holds. The block is built by running gate_fn on a temp circuit, so its members are ordinary gates.
- Patterns (`reduce_qubits`, `measure_all`, `barrier_all`) delegate to Operations, so they introduce no new shapes.
- OpenQASM lowering: the direct table gives `{atom, n, p}` with `expand_gate` checking `expected_q` (lowering.ex:274-291). sx, u1 and u2 decompose into `:u` and `:phase` with 1 qubit. `id` yields `[]`. Barriers and `c_if` are as above. Every table atom is in `@qubit_counts` (28 rows; the test pins 24 atoms).
- No producer shape is rejected. The only new special-case arm is `{:barrier, [], _}`, which is reachable (`Qx.barrier(qc, [])`) and tested. No unreachable arm was added.

## #7 Typed errors: PASS for the targeted paths, 2 residual SUGGESTIONS
Verified typed on all five functions:
- circuit.ex:197 `malformed!` raises Qx.GateError for any non-3-tuple.
- circuit.ex:205 raises Qx.GateError for integers above 1e300.
- Unknown gate atoms raise through `Theme.family`.
- Bad qubit and bit indices raise through Validation.
- bloch.ex:148-158 `amplitudes!` raises Qx.StateShapeError for a wrong size or a non-tensor.
- draw.ex:129,186,239,288 and validation.ex:582-599 raise Qx.OptionError for non-keyword or unknown options.
- validation.ex:621-629 raises Qx.OptionError for a bad `:size`.

Residuals (REVIEW, not regressions):
1. SUGGESTION: the first argument is unchecked. `Qx.draw_circuit(:x)` still raises FunctionClauseError, because `Draw.circuit` pattern-matches the struct (draw.ex:389). `Draw.plot`, `counts` and `histogram` with a non-result or non-tensor raise KeyError, BadMapError or an Nx error (draw.ex:130,187,240). Pre-existing, but the law says not to leak these.
2. SUGGESTION: bloch.ex:130 calls `Complex.abs` on `Nx.to_flat_list` output. A tensor holding NaN or inf yields `:nan` or `:infinity` atoms, which probably raise an untyped error. The tensor type is not validated either (an integer or s64 tensor of size 2 goes through).
3. Minor: gate params are not length-checked. `{:rx, [0], []}` draws as "(θ)" (circuit.ex:327), so it is safe. `:width` and `:height` in the chart options are not type-validated.

## #6 Public API and CHANGELOG: WARNING
Every behaviour change is in CHANGELOG [Unreleased] (lines 54-69, 91-101):
- Unknown options raise Qx.OptionError (60-65).
- `:size` capped at 10000 (57-59).
- `title: ""` treated as nil (66-67).
- The empty-counts title (68-69).
- Typed errors for barrier, angle, shape and Bloch shape (91-98).
- Non-keyword options (63-65).
- XML character stripping (99-101).

Problem: none of these is marked **Breaking:**, although 0.12.0 used that marker (CHANGELOG line 107). Relative to released 0.12.0, these make previously working calls raise:
- Extra or misspelt options passed to `Qx.draw/2`, `draw_counts/2`, `draw_histogram/2` and `draw_bloch/2` used to be ignored and now raise.
- `draw_bloch(size: > 10000)` used to render and now raises.
- Hand-built circuits with an extra qubit, which used to raise FunctionClauseError (these were errors already, so lower impact).

Fix: prefix the unknown-option and size-cap bullets with **Breaking:**, in the same style as 0.12.0, and note the minor bump to 0.13.0 as the signal. The CHANGELOG correctly notes that `draw_state/2` is unchanged. `Qx.Draw.VegaLite.histogram/4` changed its argument (list of maps to probabilities), but the module is `@moduledoc false`, so that is not public.

## #8 float32 tolerances: PASS
- bloch.ex:130 `atan2(|β|, |α|)` is stable and needs no clamp. It correctly gives θ=0 for |α|=1.0000001 (tested).
- bloch.ex:79,134: `@pole_epsilon 1.0e-5` is sin θ, roughly 100x the float32 eps of about 1.2e-7 (and above the 7e-4 acos error the comment cites for θ near 0, since sin θ ≈ 3.5e-4 there). That is a sound tolerance, and `@epsilon` 1e-6 is kept for the equator and φ=0 cases.
- A state exactly at the cutoff (sin θ just above 1e-5) keeps a noisy φ, but the effect is imperceptible.

## #1 and #5: not applicable
No Repo, Ecto, `from(`, fragment or interpolation in the diff. LiveView laws are not touched.

## #2 (process law): not applicable
No new processes.

Verdict: PASS WITH WARNINGS. The one WARNING is the CHANGELOG breaking-change flag. The two #7 residuals are optional.
