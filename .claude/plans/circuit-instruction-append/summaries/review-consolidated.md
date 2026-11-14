# Consolidated Review Summary: circuit-instruction-append

**Strategy**: Compress
**Input**: 4 files, ~9k tokens
**Output**: ~2k tokens (~78% reduction)

## BLOCKER
None (elixir, testing, iron-laws all report 0 blockers; requirements reports 0 UNMET).

## WARNING

1. **Shipped examples still read the removed `.instructions` field (KeyError).** Kept from iron-law-judge. Also raised by elixir-reviewer and test-reviewer.
   - examples/openqasm/round_trip.exs:19, :29, :69
   - examples/openqasm/import_gate_definition.exs:47
   - Fix: `Qx.QuantumCircuit.get_instructions/1` (line 69: `length(get_instructions(qft_circuit))` or `depth/1`). Not covered by `mix test`; the sweep fixed lib/qx.ex:1885 and tests but missed examples/.
2. **Complexity test depends on ERTS reduction charging for `++`** (testing). test/qx/quantum_circuit_instruction_order_test.exs:250-270. Measured on OTP 29 only; may change across OTP versions. Fix: scale-free ratio (late/early < 2, e.g. gates 1..N vs N+1..2N), keep absolute cap 140 as a second guard.
3. **`assert` inside `Task.async`** (testing). order_test.exs:260. Failure crashes the linked process instead of giving an ExUnit diff. Return `{spent, depth}` and assert in the test process.
4. **Complexity test only measures `Qx.H`/single-qubit** (testing). order_test.exs:250-254. `add_two_qubit_gate`, `add_three_qubit_gate`, `add_barrier`, `add_conditional`, `add_measurement` are not covered, so the "O(1) add" claim is wider than the evidence. `add_measurement` (quantum_circuit.ex:231) still uses `measurements ++ [m]`. Fix: add cx/barrier/small c_if to the loop, or note the limit in the test comment.

## Iron Laws (iron-law-judge)
0 violations across 9 laws. #1, #3, #4, #8 N/A. #2, #5, #7, #9 PASS. #6 PASS: CHANGELOG.md:30-45 breaking entry. The version bump is not in the diff, which is acceptable. It must ship as 0.12.0 (mix.exs is 0.11.0, and [Unreleased] already holds another breaking change), never 0.11.x. The #9 dispatch trace is clean: all six producers build unchanged tuples, lowering reverses correctly (quantum_circuit.ex:104 via lowering.ex), c_if body stays in circuit order, and there are no changes to dispatch arms in simulation.ex. Elixir-reviewer's independent order trace agrees.

## SUGGESTIONS (compressed)

- **Comment hygiene / test config** (testing): order_test.exs:6-13, 231-247 narrate history (dates, 19 s old-build time), which belongs in the commit message. `@tag timeout: 300_000` at :249 is excessive (use 120_000 or drop it), and `Task.await(:infinity)` should be finite.
- **Test brittleness / coverage depth** (testing):
  - SVG regex at order_test.exs:151-164 assumes `x` is the first attribute and that the label is unique. Add a measure + c_if draw case.
  - QASM round trip at :142-149 is order-agnostic. Add c_if and barrier.
  - `to_qasm` test at :108-116 filters only 2 lines. Compare the full ordered list.
  - `from_qasm` test at :118-140 has no if/user gate/barrier mix.
  - Missing: Patterns producers, non-conditional measure `run`, nested c_if order, direct `any_instruction?` test, `put_instructions` guard (`FunctionClauseError`), optional StreamData property test.
- **Doc polish** (elixir): lib/qx.ex:1885 `tap_circuit` example prints "Gates: #{depth(c)}" (correct but misleading name; consider `length(get_instructions(c))`). lib/qx/operations.ex:909 doc line is long; bind to a variable.
- **No change needed** (elixir): quantum_circuit.ex:365 `put_instructions/2` guard and spec; `any_instruction?/2` is fine.
- Existing-test edits (8 files): testing-reviewer read every hunk. All are access-path only, with no assertion changes.

## PRE-EXISTING (not blocking)
- lib/qx/quantum_circuit.ex:231 `measurements ++ [measurement]` is O(n) per measurement. Acknowledged in the CHANGELOG. Found by elixir, iron-laws, testing.

## Requirements Coverage (requirements-verifier)
**Summary**: 31 MET . 1 PARTIAL (D8, literal deviation only) . 0 UNMET . 2 UNCLEAR (docs warning baseline, full verification not re-run)

- **PARTIAL D8** (complexity test without tight timing): a deterministic reductions metric is used (test :231-270; 1,654 vs limit 140 vs 8.64 post-change). It deviates from D8's first choice (whole build, 20k gates), but the deviation is recorded in the 1.5 note and scratchpad (42x, rejected). Within intent.
- **UNCLEAR 4.1/4.3**: docs warning baseline. `mix docs` was not re-run.
- **UNCLEAR 4.5**: full verification (compile, format, credo, full suite) not re-run. The new file passed 17/17.
- Claim 1.6 (red run recorded) is unverifiable now.
- Beyond-plan changes are all within intent: timeline hoisted out of the shot loop (simulation.ex:175-184), extra tests, the D8 metric, the extra moduledoc doctest, and the `reset/1` doctest edit.

## Not verified by reviewers
- elixir and testing had no shell: tests, doctests, format and credo were not run.
- CHANGELOG benchmark numbers are unverified.
- Whether the SVG regex matches current renderer output is unverified.
- Behaviour on OTP != 29 is unverified.
- `mix docs` was not run.

## Coverage

| File | Represented | Key Items |
|---|---|---|
| elixir.md | Yes | 1 warning (merged into W1), 3 suggestions, 1 pre-existing |
| testing.md | Yes | 4 warnings (W1-W4), ~9 suggestion groups |
| iron-laws.md | Yes | 0 violations, 1 warning (W1), law verdict summary |
| requirements.md | Yes | coverage summary line, 1 PARTIAL, 2 UNCLEAR |
