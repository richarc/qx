# Iron Law Violations Report — typed-error-sweep-3

## Summary
- Files scanned: qx.ex, errors.ex, validation.ex, math.ex, operations.ex,
  patterns.ex, quantum_circuit.ex, simulation.ex, simulation_result.ex,
  state_init.ex, test/qx/typed_error_sweep_test.exs
- Iron Laws checked: #3, #4, #5, #6, #7, #8, #9 (Qx-tailored set) — all applicable
- Violations found: 0

## Verification of the deliberately-implicated Iron Laws (all SATISFIED)

- **#7 (typed errors)**: Every fallback clause added by the sweep
  (`QuantumCircuit.new/1,2`, `add_gate`/`add_two_qubit_gate` via
  `validate_qubit_index!`, `Operations.c_if/4` final clause,
  `StateInit.basis_state/3` fallback, `Patterns.bell_state_circuit/1` and
  `ghz_state_circuit/1` fallbacks, `SimulationResult.filter_by_probability/2`
  fallback, `Qx.Math.normalize/1` zero-norm check) raises a typed `Qx.*Error`
  routed through `Qx.Validation` (or, for `Math.normalize/1`, raised directly
  per the documented exception to that pattern). No raw `Nx`/`Complex`/
  `ArgumentError`/`FunctionClauseError` leaks were found at the mapped sites.
  Confidence: DEFINITE.

- **#5/#8 (Nx host sync)**: `Qx.Math.normalize/1` (math.ex:77-86) is a host
  `def` doing exactly one `Nx.to_number/1` (the zero-norm check), then
  delegates to `normalize_unchecked/1` (a pure `defn`, `@doc false`,
  math.ex:94-97). Correctly NOT compile-gated — it's a permanent public-path
  validation, distinct from the `@assert_norm`-gated dev/test guard in
  simulation.ex:35-43/454-458 (compiled dead in `:prod` per
  `config/config.exs`). The renorm hot path
  (`simulation.ex:438` `maybe_measurement_renorm/2` and `simulation.ex:445`
  `maybe_gate_renorm/3`) calls `Math.normalize_unchecked/1` — no added
  per-step host sync. Confidence: DEFINITE.

- **#3/#4 (Nx kernels)**: `normalize_unchecked/1` body
  (`Nx.sqrt(Nx.sum(Nx.abs(state) ** 2))`, `state / norm`) is byte-identical
  to the former public `defn normalize/1` — no gather/mask added, correct on
  `Nx.BinaryBackend`. The host `def normalize/1` uses `Nx.abs(state) |>
  Nx.pow(2) |> ...` (function form, not the defn-only `**` operator) —
  appropriate for host code. No `defn` calls the host `def normalize/1`
  (grepped: only `random_state/2` in state_init.ex and the test call it, both
  from host code). Confidence: DEFINITE.

- **#6 (public API / SemVer)**: All changes are additive/non-breaking —
  fallback clauses only fire on inputs that already crashed on `main`
  (`FunctionClauseError`), so no valid-today input starts raising. The
  `filter_by_probability/2` integer-widening (`is_number` guard, was
  `is_float`) is additive. `CHANGELOG.md` `[Unreleased]` has both a `Changed`
  entry (threshold widening, build-time parameter validation) and a `Fixed`
  entry (typed-error sweep #3 + the `Math.normalize/1` zero-norm fix)
  enumerating every mapped site. Confidence: DEFINITE.

- **#9 (dispatch completeness)**: No new instruction shapes were added by
  this change — `{:barrier, qubits, params}` handling in
  `simulation.ex:apply_gate_step/5` is untouched, and no new gate/instruction
  atom appears in `quantum_circuit.ex`, `operations.ex`, or
  `simulation.ex`'s dispatch tables. #9 is correctly n/a for this diff.

## Fallback-clause behavior-for-valid-input check

Traced each new/modified fallback clause against its guarded sibling clause
to confirm the fallback is unreachable for valid input (would indicate a
non-breaking-claim risk):

- `QuantumCircuit.new/2` fallback (quantum_circuit.ex:74-77): only reached
  when the main clause's guard (`is_integer(num_qubits) and
  is_integer(num_classical_bits) and num_classical_bits >= 0`) fails — i.e.
  strictly on invalid input. Always raises (never falls through to return an
  atom) because `validate_num_qubits!`/`validate_num_classical_bits!`
  exhaustively cover the guard's negation. No valid input reaches it.
- `StateInit.basis_state/3` fallback (state_init.ex:81-95): same pattern,
  cond-checked in priority order, correct.
- All other fallbacks reviewed are single-purpose (unreachable for valid
  input by construction of the guard they complement).

No violations found; no behavior change for valid input detected.
