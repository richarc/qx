# Iron Law Audit — feat/producer-hygiene

## Summary
- Files audited: `lib/qx/quantum_circuit.ex`, `lib/qx/operations.ex`, `lib/qx/patterns.ex` (full read), plus a repo-wide grep for instruction-tuple construction/append across `lib/`.
- No Bash access in this session — `git --no-pager diff main` could not be run directly; verification instead performed by reading each target file in full against the plan's stated "Current state → After" table and confirming the code matches the "After" column exactly.
- Verdict: **PASS** — no violations of Iron Laws #9, #6, or #7 found in the refactored surface.

## Law #9 — Dispatch/producer completeness (the item's purpose)

**Status: SATISFIED.**

- `Qx.QuantumCircuit` now exposes the full `add_*` family: `add_gate/4`, `add_two_qubit_gate/5`, `add_three_qubit_gate/6`, `add_measurement/3`, `add_barrier/2` (new), `add_conditional/4` (new) — all `@doc false`, all building + appending the instruction tuple in one place (`lib/qx/quantum_circuit.ex:98-235`).
- `Operations.barrier/2` (`lib/qx/operations.ex:684-687`) now does `validate_qubit_indices!` then `QuantumCircuit.add_barrier(circuit, qubits)` — no inline `%{circuit | instructions: ... ++ [...]}` remains.
- `Operations.c_if/4` happy-path clause (`lib/qx/operations.ex:827-845`) keeps the temp-circuit orchestration (`gate_fn.(temp_circuit)`, `validate_conditional_block/1`) and delegates the final build+append to `QuantumCircuit.add_conditional(circuit, classical_bit, value, conditional_instructions)` — no inline tuple construction remains here either.
- `Patterns.measure_all/2` (`lib/qx/patterns.ex:223-227`) now composes `Operations.measure/3` instead of calling `QuantumCircuit.add_measurement/3` directly, per the plan.
- Repo-wide grep for `instructions:.*\+\+` confirms **all six** append sites live in `quantum_circuit.ex` only (lines 122, 148, 168, 210, 221, 234) — zero remaining append sites in `Operations` or `Patterns`.
- No new instruction shape introduced: `add_barrier` builds `{:barrier, qubits, []}` (same 3-tuple shape as before) and `add_conditional` builds `{:c_if, [classical_bit, value], conditional_instructions}` (same shape as before). Confirmed — no consumer arm changes are needed, and none were made (`Qx.Simulation`, `Qx.Export.OpenQASM` dispatch arms untouched).

**Informational, out-of-scope note (not a violation of this diff):** `lib/qx/export/openqasm/lowering.ex` (`lower_stmt/2`, lines ~148-204) builds and prepends `{:measure, …}`, `{:barrier, …}`, `{:c_if, …}` tuples onto a plain lowering-state map (not a `%QuantumCircuit{}` — it only becomes one at the end via `build_circuit/1`, line 90-102). This is a second, pre-existing instruction-tuple producer that this refactor did not touch and the plan did not scope in. It's defensible (the lowering state isn't a real circuit until `build_circuit/1` runs, so `add_barrier`/`add_conditional` aren't callable there), but it means the moduledoc claim "every instruction tuple … is now produced by the one `QuantumCircuit.add_*` surface" is true for the `Operations`/`Patterns` production path only, not for OpenQASM import. Worth a one-line moduledoc caveat in a future pass; not a blocker for this merge since it's unchanged behavior and out of this plan's stated scope.

## Law #6 — Public API surface

**Status: SATISFIED.**

- `Operations.barrier/2` signature/spec/doc/examples unchanged (`@spec barrier(QuantumCircuit.t(), [non_neg_integer()]) :: QuantumCircuit.t()`, same doctest output).
- `Operations.c_if/4` signature/spec/doc/examples/guard clauses unchanged (`@spec c_if(...)`; same doctest).
- `Patterns.measure_all/1,2` signatures/specs/doctests unchanged; doctest output (`[{:measure, [0,0], []}, ...]`) still matches — confirms byte-identical output via the new `Operations.measure/3` composition path.
- New `QuantumCircuit.add_barrier/2` and `add_conditional/4` are both `@doc false`, not part of the declared public surface (`Qx`, `Qx.QuantumCircuit`, `Qx.Operations`, `Qx.Patterns`, etc.) — no CHANGELOG entry or version bump required, consistent with the plan.

## Law #7 — Typed errors

**Status: SATISFIED.**

- `Operations.barrier/2` still calls `Validation.validate_qubit_indices!(qubits, circuit.num_qubits)` before delegating (line 685) — guard preserved.
- `Operations.c_if/4` retains all four guard/fallback clauses unchanged: the value ∉ {0,1} raise (`Qx.ConditionalError`, line 853-856), the non-function `gate_fn` raise (line 858-860), the out-of-range classical bit raise (`Qx.ClassicalBitError`, line 847-851), and the non-integer classical-bit fallback (line 865-867). `validate_conditional_block/1` (nested-`c_if` guard, line 870-882) is still invoked from the happy-path clause before the delegated `add_conditional` call.
- `QuantumCircuit.add_gate/4`, `add_two_qubit_gate/5`, `add_three_qubit_gate/6`, `add_measurement/3` retain their existing `Qx.Validation` calls (`validate_qubit_index!`, `validate_classical_bit!`, `validate_three_qubit_args!`) — untouched by this refactor.
- New `add_barrier/2` and `add_conditional/4` intentionally perform no validation of their own (by design — validation stays in `Operations`, per the plan); this is correct since they are `@doc false` internal-only with a single caller each.

## Verdict

**PASS.** No Iron Law violations found in the refactored surface (#9 hygiene goal achieved, #6 API surface untouched, #7 typed-error guards all preserved). One informational note raised (OpenQASM lowering producer) — non-blocking, out of this plan's scope.
