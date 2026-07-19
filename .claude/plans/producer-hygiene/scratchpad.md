# Scratchpad — producer-hygiene (v0.11)

## Outcome (2026-07-12)

All 5 phases done. Pure internal, byte-identical refactor. Full gate green:
compile --warnings-as-errors, format, credo --strict (no issues), 315 doctests
+ 1071 tests 0 failures, mix docs == 36 baseline.

Merge-gate review: **3× PASS** (elixir-reviewer, testing-reviewer, iron-law-judge).
- iron-law-judge #9: repo-wide grep confirmed ZERO remaining inline
  `instructions: … ++` append sites in Operations/Patterns — all six producers
  (`add_gate`, `add_two_qubit_gate`, `add_three_qubit_gate`, `add_measurement`,
  new `add_barrier`, new `add_conditional`) centralized in `QuantumCircuit`.
- c_if orchestration/append split verified correct (temp-circuit gate_fn run +
  validation stay in Operations; only `{:c_if,…}` build+append moved).
- No circular dep: Patterns → Operations → QuantumCircuit is a strict DAG.

## DISCOVERED WORK (out of scope — recorded)

- **Second producer surface in QASM import.** `lib/qx/export/openqasm/lowering.ex`
  builds `{:measure,…}`/`{:barrier,…}`/`{:c_if,…}`/gate tuples DIRECTLY on a raw
  lowering-state map (it constructs an instructions LIST from parsed QASM, then
  wraps it in a `QuantumCircuit` at the end — a legitimately different, bulk
  construction path than the incremental `add_*` API). Flagged by iron-law-judge
  as a second place instruction shapes are emitted (Iron Law #9-adjacent). Not
  refactored here (would be awkward — add_* appends one-at-a-time to a struct).
  Recorded to ROADMAP backlog: at minimum a moduledoc caveat, or a shared
  shape-constructor both paths use.

## Non-blocking review suggestions (NOT applied — minimal-diff refactor)

- elixir-reviewer: comment-wording parity (operations.ex); `measure_all/2` could
  reuse the private `reduce_qubits/3` helper. Cosmetic.
- testing-reviewer: extra construction-level invariants for `barrier_all`,
  `measure_all/2` range form, chained `c_if`. Existing suite already covers
  behaviour; skipped to keep the refactor minimal.
