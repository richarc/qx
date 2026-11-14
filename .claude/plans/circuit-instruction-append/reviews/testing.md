# Test Review: circuit-instruction-append

Not run by me (no shell). Not verified: that the SVG regex matches current renderer output, the measured reduction numbers, OTP != 29 behaviour.

## BLOCKER
None.

## WARNING

- [ ] examples/openqasm/round_trip.exs:19,29,69 and examples/openqasm/import_gate_definition.exs:47 still read `.instructions` (KeyError now; `length(qft_circuit.instructions)` too). Not tests, but same access-path breakage; change to `Qx.QuantumCircuit.get_instructions/1`. (grep covered test/, lib/, examples/, bench/ only.)

- [ ] test/qx/quantum_circuit_instruction_order_test.exs:250-270 (complexity test): the failing-side margin depends on how ERTS charges reductions inside the `++` BIF (about 0.02 reductions per copied element, from the file's own numbers). That is an implementation detail and can change across OTP versions. It was measured on OTP 29 only. GC copy cost is not counted in reductions at all. Fix: make it scale-free. Measure per-gate reductions for gates 1..N and for N+1..2N (or 5k vs 50k) and assert `late / early < 2`. Keep the absolute cap (140) as a second guard. A ratio fails for any O(n) append whatever the per-element charge.
- [ ] Same test, line 260: `assert` runs inside `Task.async`. A failure there crashes the linked test process with an exit, not an ExUnit assertion diff. Return `{spent, depth}` from the task and assert in the test process.
- [ ] Same test, lines 250-254: only `Qx.h/2` (single-qubit) is measured. `add_two_qubit_gate`, `add_three_qubit_gate`, `add_barrier`, `add_conditional` and `add_measurement` are each separately edited but not covered. The claim "adding an instruction is O(1)" is wider than the evidence. `add_measurement` (quantum_circuit.ex ~L228) still does `circuit.measurements ++ [measurement]`, so measuring is still O(n) in measurements. Fix: add a small producer-mix loop (cx, barrier, a c_if with a tiny body) to the measured loop. Decide whether the measurement path is in scope, or note it as a known limit in the test comment.

## SUGGESTION

- [ ] order_test.exs:6-13 and 231-247: comments narrate history ("used to append with `++`", "Measured 2026-11-14", the 19 s old-build time). Repo comment rule puts that in the commit message. Keep the durable fact (why reductions, why 140).
- [ ] order_test.exs:249: `@tag timeout: 300_000` is far larger than needed. The new code runs in under a second; the old code took ~19 s, which is under ExUnit's 60 s default. Drop it, or use 120_000. If kept, the `Task.await(:infinity)` is redundant. Use a finite timeout so a hang fails.
- [ ] order_test.exs:151-164 (SVG regex): brittle in three ways. The pattern requires `x` to be the first attribute of `<text>`. It requires the label to be the only `<text ...>X</text>` in the SVG (any new "H" or "X" label, such as a legend, breaks `assert [[_, x]]`). It assumes x increases with position. A formatting or attribute-order change in the renderer fails with an unrelated message. The assertion does fail correctly if order is reversed (it compares left-to-right positions). Fix: allow `<text\s[^>]*\bx="..."`, or compare a stable data attribute if the renderer can emit one. Draw is only covered for plain gates. Add one circuit with a measure and a `c_if` so those draw paths are also covered (draw/svg/circuit.ex was edited).
- [ ] order_test.exs:142-149 (QASM round trip): compares two `get_instructions` results, so it is order-agnostic if export and import were both reversed. The exact-tuple tests above it already pin the order, so this only adds coverage that export then import is consistent. Fine, but it is the weakest assertion in the file. Add `c_if` and `barrier` to the circuit.
- [ ] order_test.exs:108-116 (`to_qasm`) filters only two lines, so it cannot see a measure or `c_if` line out of place. Compare the full ordered list of non-header lines on the conditional circuit.
- [ ] order_test.exs:118-140 (`from_qasm`): no `if (c[0]==1)`, no user `gate` definition (multi-instruction expansion goes through `prepend/2` in lowering.ex:151), no barrier. Existing lowering_test covers each shape singly, but not a mix in one circuit. Add one mixed source.
- [ ] Missing consumers and producers: `Qx.Patterns` producers (bell etc.) only appear in the codegen test with a 2-element list. `Qx.run` on a circuit with measurements but no `c_if` (the non-conditional measure path) is not order-tested. Nested or multiple `c_if` order in `run`/`steps` is not covered. `any_instruction?/2` has no direct test; it is only reached through `run`. Optional property test (StreamData, if the dep exists): random gate list pushed through builders equals the list given to `put_instructions` then `get_instructions`.
- [ ] Struct contract (order_test.exs:166-197): `refute Map.has_key?(..., :instructions)` is the only negative check. `put_instructions/2` guard (`is_list`) is not exercised (`assert_raise FunctionClauseError`). `get_instructions` is not checked to be non-mutating or idempotent. Minor.
- [ ] Doctests: `doctest Qx.QuantumCircuit` exists at test/qx/quantum_circuit_state_test.exs:6, so the repo rule is satisfied. The moduledoc example has two consecutive `iex>` lines in one test, and the two `get_instructions/1` examples are separate blocks; both are fine.

## Edits to the 8 existing test files (every hunk read)

All edits are inside the approved access-path scope. No expected value, assertion strength, or exercised behaviour changed.

- codegen_test.exs:99, lowering_test.exs (all 16 hunks), openqasm_import_test.exs:85 and :150: `x.instructions` becomes `get_instructions(x)`; expected lists unchanged; pattern-match forms (`[{:rx,[0],[theta]}] = ...`) keep the same pattern.
- openqasm_test.exs:400, simulation_typed_errors_test.exs (5 hunks): `%{qc | instructions: l}` becomes `put_instructions(qc, l)`. Single-element lists, so order is irrelevant. Same input.
- simulation_steps_test.exs:88-93: `qc.instructions ++ [bogus]` becomes `get_instructions(qc) ++ [bogus]` passed to `put_instructions`. Same poisoned list, and it still asserts lazy `Enum.take(_, 1)`. Cosmetic: the added blank line is fine.
- round_trip_test.exs `drop_measurements/1`: filter now reads `get_instructions`; the rewrite splits the map update (`measurements: [], measured_qubits: MapSet.new()`) from `put_instructions`. Net result is identical: measure tuples are dropped, measurements and `measured_qubits` are cleared, and the order of the remaining instructions is preserved (read in circuit order, written in circuit order).
- typed_errors_sweep_test.exs:100-116: struct literals become `put_instructions(%Qx.QuantumCircuit{num_qubits: 1, num_classical_bits: 0}, [...])`. The literal had `state: nil` and defaults before and still does. `put_instructions` pattern-matches `%QuantumCircuit{}`, which still holds. Same circuit, same `SvgCircuit.render` input and assertions (`e.gate == :bogus`, `QubitIndexError`).

Empty: BLOCKER; existing-test-edit violations.
