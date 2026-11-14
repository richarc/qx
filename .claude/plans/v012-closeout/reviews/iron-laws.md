# Iron Law Review: fix/v012-closeout

Phoenix, Ecto, LiveView and Oban laws do not apply. Judged against the AGENTS.md project laws (#6, #7, #9).
Blockers: 0. Warnings: 1. Suggestions: 1.

## Answers to the specific questions (all verified by reading code)

1. Is the two-qubit `:measure -> state` arm in `apply_two_qubit_op` reachable? Yes.
   - `run_without_conditionals` (simulation.ex:149-155) calls `execute_circuit`.
   - `execute_circuit` (403-414) reduces over ALL instructions via `apply_gate_step`, including `{:measure,[q,c],[]}`.
   - That reaches `apply_instruction` (length 2) and then `apply_two_qubit_op(:measure, ...)`, which is the no-op arm at line 570.
   - Every measured circuit without a `c_if` takes this path, so the arm is live and deliberate. Keep it.
   - On the conditional path, `create_instruction_timeline` (702) intercepts top-level `{:measure,[q,c],[]}` as `{:measurement, ...}`, so the arm is not hit there.
   - The one-qubit arm was unreachable: every producer emits `[qubit, cbit]`. Deleting it is correct, and the new test covers it.

2. Can any producer still put `:measure` inside a `c_if` body? No (verified).
   - `Operations.c_if` (844-904) validates every captured instruction.
   - `measure_x/measure_y` end in `QuantumCircuit.add_measurement` (quantum_circuit.ex:225), so they are caught.
   - `Qx.Patterns` emits no `c_if` (grep).
   - `QuantumCircuit.add_conditional` has no other caller.
   - OpenQASM: the `inner_statement` combinator (parser.ex:370-378) has no nested `if`. `measure` and `barrier` can appear in a body. The measure case is now rejected in `lower_stmt({:c_if...})`.
   - The only remaining bypass is `QuantumCircuit.put_instructions/2`, an internal writer. It could place a measure inside a `c_if` body by hand. It is not a user-facing producer.
   - If one did, the two-qubit arm would silently no-op it in `step_conditional`. Law #9 is satisfied, but that residual hole is worth knowing about.

3. Is the CHANGELOG entry sufficient for #6? The content is, the labelling is not (WARNING).
   - `Qx.c_if/4` (tier 1) now raises where it used to accept, and `from_qasm` (tier 2) now returns an error where it used to import. Both are behaviour breaks.
   - The entries sit under `### Fixed` (CHANGELOG.md:115+) with no `**Breaking:**` marker.
   - Every other breaking change in this release carries `**Breaking:**` under `### Changed` (lines 12 and 30).
   - Add the marker, or move them to `### Changed`, so the 0.12.0 break is discoverable. The toffoli removal (tier 3, under Changed) is fine.

4. Raw error leaks: none introduced.
   - The new `Qx.ConditionalError.exception(:measurement_in_conditional)` clause (errors.ex:353) is typed.
   - The lowering returns `Qx.QasmUnsupportedError` as `{:error, ...}`, which matches the existing pattern.
   - `from_qasm!` raises the same typed error. The guard test covers it.

## Suggestion
- simulation.ex:570 — the retained `:measure -> state` arm has no comment saying why it is a no-op. The note should say that measurements are sampled in `perform_measurements` and that `execute_circuit` sees them in the non-conditional path. A future reader could delete it as "unreachable", the way the one-qubit arm was. Inferred, not a violation.

## Pre-existing (unchanged code), one line each
- None found in the lines I read. I did not scan the whole repo.
