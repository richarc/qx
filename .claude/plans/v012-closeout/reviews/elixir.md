# Code Review: v012-closeout (measurement in c_if guard)

## Summary
- Status: Approved (minor suggestions only)
- Issues: 0 critical, 0 warnings, 3 suggestions

## Producer-path analysis (verified by reading code)
- Instruction shape: `QuantumCircuit.add_measurement/3` (quantum_circuit.ex:225) is the only producer in Operations/Patterns (measure, measure_z, measure_x, measure_y, Patterns.measure_all all route through it). Shape is always `{:measure, [q, c], []}`, a 3-tuple, so the `{:measure, _, _}` clause in `validate_conditional_block/1` (operations.ex:895) catches all of them.
- `c_if` runs `gate_fn` on a temp circuit and validates the collected instructions before `add_conditional`, so nothing in Operations bypasses it. Nested `c_if` is already rejected.
- Bypass only via `@doc false` internals: `QuantumCircuit.add_conditional/4` (quantum_circuit.ex:253) and `put_instructions/2` accept unvalidated lists. Not public API; acceptable.
- OpenQASM parser: the if-body grammar (parser.ex:370-389) allows only measure_modern, measure_legacy, measure_discarded (a parse error), barrier, and gate_call. Both measure forms are tagged `{:measure, qref, cref, line: n}` (parser.ex:599, 603), the 4-tuple that `reject_measurement_in_body/1` matches. No other shape exists. Unbraced bodies use the same `inner_statement`. `if` cannot nest in the grammar (inner_statement excludes if_stmt). User gates cannot contain a measure (gate_body_inner). So the lowering check is complete.
- `:hint` is a valid option of `Qx.QasmUnsupportedError` (errors.ex:595-619).
- Test regex `[Mm]easurement.*conditional block` matches the new message (errors.ex diff).

## Suggestions
1. test/qx/conditional_measurement_guard_test.exs:308 — only the braced modern form (`c[1] = measure q[1];`) is covered. The unbraced body (`if (c[0] == 1) c[1] = measure q[1];`) and the legacy form (`measure q[1] -> c[1];`) go through different parser tags (tag_measure_legacy). Add one case each. (Verified: both reach lowering as 4-tuple measures; not run.)
2. lowering.ex:213 — `Enum.find` plus re-matching in the case is a bit redundant. A pattern-matching helper, or `Enum.find_value`, would drop the duplicate match. Style only.
3. operations.ex:893 and lowering.ex:210 — the comments explain "simulator skips it", which is a durable invariant, so they are fine. The CHANGELOG and ROADMAP carry the history.

## Doc accuracy (verified)
- qx.ex:1206 `## Raises` and Operations `c_if` docs now match behaviour. OpenQASM moduledoc "Not supported" list updated. The new `## Raises` in Operations documents ClassicalBitError for non-integer, matching the final fallback clause (operations.ex:882).
- CHANGELOG says the Qx.measure/measure_x/measure_y cases are covered: verified. measure_z is an alias of measure, so it is also covered.
- Removing the one-qubit `:measure` arm: grep shows the only remaining `:measure` dispatch in simulation.ex is line 570 (the two-qubit arm) plus timeline matches at 702/755. Consistent with the claim.

## Pre-existing (unchanged code, one line each, inferred/not deep-checked)
- lib/qx/operations.ex:849 — temp circuit keeps parent `measurements`/`measured_qubits`; harmless because only instructions are read back.
- lib/qx/quantum_circuit.ex:229 — `circuit.measurements ++ [measurement]` is a quadratic append, inconsistent with the O(1) instruction append work.
