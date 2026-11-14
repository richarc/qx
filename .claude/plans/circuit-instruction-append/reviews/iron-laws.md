# Iron Law Review: circuit-instruction-append

Checked the 9 AGENTS.md laws: 0 law violations. 1 non-law finding (stale examples, WARNING). Evidence read from code, not comments.

## Per-law verdicts

| # | Law | Verdict | Evidence |
|---|-----|---------|----------|
| 1 | No eager atom interning | NOT APPLICABLE | Diff adds no `String.to_atom`, `Module.concat`, or `binary_to_atom`. Only tuple/list moves. |
| 2 | No needless process | PASS | No `use GenServer/Agent`, no `Task` in lib. `Task.async` appears only in the new test (`quantum_circuit_instruction_order_test.exs:252`) as a test-local VM-isolation device. |
| 3 | Nx: contraction over gather | NOT APPLICABLE | No `calc*.ex` or `defn` touched. |
| 4 | defn correct on BinaryBackend | NOT APPLICABLE | No `defn` touched. |
| 5 | No host loops over 2^n | PASS | Only `Enum.reverse` / `Enum.any?` / `length` over the instruction list (O(gates)) at `quantum_circuit.ex:366,379,399,408`. `Simulation.run` now builds the timeline once outside the shot loop (`simulation.ex:175-184`), which lowers host work. Nothing iterates amplitudes. |
| 6 | Breaking change: CHANGELOG + version signal | PASS (see note) | `CHANGELOG.md:30-45`: "**Breaking:**" entry under `[Unreleased]` / `### Changed`. It names the removed field, the migration (`circuit.instructions` -> `get_instructions/1`), the failure modes (`KeyError`, compile error on the struct literal), and says the new field is internal. `Qx.QuantumCircuit` is tier 1 (`quantum_circuit.ex:3`). The perf note at `CHANGELOG.md:87-94` is under the non-breaking section, which is correct. |
| 7 | Typed errors at API boundary | PASS (see note) | `put_instructions/2` (`quantum_circuit.ex:365`) and `any_instruction?/2` (`:398`) are `@doc false`, so tier 3 with no stability guarantee. See #7 note below. |
| 8 | Precision targets feasible at c64 | NOT APPLICABLE | The new test uses `@tolerance 1.0e-6` (`quantum_circuit_instruction_order_test.exs:15`), which is feasible at c64 anyway. |
| 9 | Dispatch completeness | PASS | See trace below. |

### #6 note: version bump not in the diff
The law (AGENTS.md:403) requires a CHANGELOG entry and a bump of the minor version while < 1.0. It does not say the bump must be in the same commit as the change. The release-manager flow and the "Public API change" row of the POST-ACTION table put the `mix.exs` bump at release time.

`mix.exs:7` is `0.11.0`, and `[Unreleased]` already holds another breaking change (`Qx.DrawSizeError`, `CHANGELOG.md:12`). So the single next release is the minor bump to 0.12.0. The recent commit subjects `fix!: ... (v0.12)` confirm that intent. Omitting the bump is consistent. The gate is at release: this must ship as 0.12.0, never 0.11.x, since patch releases must not break. A bump on this branch would be harmless but unnecessary.

### #7 note: FunctionClauseError from `@doc false` helpers
Not a violation. The law covers "public functions", meaning the documented tier 1/2 surface. These helpers are `@doc false` and are used only by `Qx.Operations`, the lowering code, and tests. Their guards fail fast on programmer error. The public entry points still validate: `Operations.c_if/4` has typed clauses (`operations.ex:857-870`). One behavioural difference: before this change, `%{circuit | instructions: bad}` silently stored anything, and `put_instructions/2` still does not validate tuples (documented at `quantum_circuit.ex:385`). The unsupported-gate execution paths still raise `Qx.GateError`, per the updated tests (`simulation_typed_errors_test.exs`).

### #9 trace (from code)
1. **Producers.** The six `add_*` functions build the same tuples as before. Only the container expression changed, from `circuit.instructions ++ [x]` to `[x | circuit.reversed_instructions]`:
   - `add_gate` `{gate_name, [qubit], params}` (`quantum_circuit.ex:140-143`)
   - `add_two_qubit_gate` `{gate_name, [control, target], params}` (`:166-169`)
   - `add_three_qubit_gate` `{gate_name, [c1, c2, t], params}` (`:186-189`)
   - `add_measurement`: `measurement_instruction` shape unchanged, with `measurements` still appended (`:228-232`)
   - `add_barrier` `{:barrier, qubits, []}` (`:242`)
   - `add_conditional` `{:c_if, [bit, value], body}` (`:254-256`)
2. **Lowering.** The `lowering.ex` shapes are untouched, apart from the end-of-lowering hand-off. Each of `{:measure,[qi,ci],[]}` (`:161`), `{:barrier,..,[]}` (`:178,192`), `{:c_if,[ci,value],body}` (`:204`) and the gate expansions is built exactly as before, in the module's own newest-first `state.instructions`. `build_circuit` reverses that once and calls `put_instructions/2` (`:104`). `put_instructions` reverses again into storage, so `get_instructions` yields source order. No double-reverse bug: reverse, reverse, reverse gives circuit order. The c_if body from `lower_body` (`:209-224`) is reversed to circuit order before being placed in the tuple.
3. **c_if path, by hand.**
   - `Operations.c_if/4` (`operations.ex:837-855`) calls `put_instructions(circuit, [])`, so the temp circuit's `reversed_instructions` is `[]`.
   - `gate_fn` prepends, giving newest-first `[z, x]` for `x |> z`.
   - `get_instructions(modified)` reverses it to `[x, z]`, which is circuit order.
   - `add_conditional(circuit, bit, value, [x, z])` stores `{:c_if, [bit, value], [x, z]}` with the body untouched, and prepends only the outer tuple.
   - Later, `get_instructions` reverses only the outer list, and the body stays `[x, z]`.
   - `create_instruction_timeline` (`simulation.ex:700-703`) matches `{:c_if, [cbit, value], sub}` -> `{:conditional, {cbit, value, sub}}`.
   - `step_timeline_item` (`:761`) calls `step_conditional` (`:775-801`), which `Enum.reduce`s `instructions` front to back. Body order is preserved.
   - The new test pins this: `quantum_circuit_instruction_order_test.exs:200-228` checks exact body tuples, and `:77-82` and `:95-106` execute them via `run/2` and `steps/2`. This is the required execution coverage.
4. **Dispatch arms.** The `simulation.ex` diff has no hunks in `apply_instruction` (`:486`), `create_instruction_timeline`'s case arms, `step_timeline_item`, or `step_conditional`. The hunks are:
   - the timeline built once before the shot loop (`:175-184`)
   - the `execute_single_shot` arity change (`:664-668`)
   - `has_conditionals?` via `any_instruction?` (`:660`)
   - `get_instructions` in the timeline builder (`:696`)
   - No arm added, removed, or altered. No special-case arm is introduced for an unproducible shape.
5. **`any_instruction?` order.** It scans `reversed_instructions` without reversing. Both callers (`has_conditionals?`, `final_step`, `validate_circuit_for_version!`) ask an order-independent existence question over top-level tuples, so this is correct.

## Non-law finding (WARNING, high confidence)

**Shipped examples still read the removed field.** These raise `KeyError` now:
- `examples/openqasm/round_trip.exs:19`: `IO.inspect(original.instructions)`
- `examples/openqasm/round_trip.exs:29`: `IO.inspect(reimported.instructions)`
- `examples/openqasm/round_trip.exs:69`: `length(qft_circuit.instructions)`
- `examples/openqasm/import_gate_definition.exs:47`: `IO.inspect(circuit.instructions)`

Fix: `Qx.QuantumCircuit.get_instructions(circuit)` in each place (and `length(...)` of that for `:69`; `Qx.QuantumCircuit.depth/1` also works there). The same sweep that fixed `lib/qx.ex:1885` and the tests missed `examples/`. This is the migration the CHANGELOG tells users to perform, so the repo's own examples should follow it. A grep of `*.md`, `*.livemd`, `lib/`, `test/` and `bench/` found no other readers of `.instructions`.

## PRE-EXISTING (unchanged code, not blocking)
- `quantum_circuit.ex:231`, `measurements: circuit.measurements ++ [measurement]` is still an O(n) append, noted in the CHANGELOG as unchanged (the measurement list is small).
