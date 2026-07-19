# Iron Law Violations Report — feat/qasm-facade-tdg

Note: this repo (qx) is a pure Elixir library, not Phoenix. Iron Laws
audited are the qx-specific ones defined in `qx/CLAUDE.md`
("Elixir Plugin — Mandatory Procedures" block), not the generic
LiveView/Ecto/Oban/Security laws (not applicable — no Phoenix/Ecto/
LiveView/Oban in this repo).

## Summary

- Files scanned: `lib/qx/operations.ex`, `lib/qx/simulation.ex`,
  `lib/qx/draw/svg/circuit.ex`, `lib/qx/export/openqasm.ex`,
  `lib/qx/export/openqasm/lowering.ex`, `lib/qx.ex`, `CHANGELOG.md`,
  `.claude/plans/qasm-facade-tdg/plan.md`, plus test files
  (`test/qx/operations_test.exs`, `test/qx/export/openqasm_test.exs`,
  `test/qx/draw/circuit_test.exs`, `test/qx/export/openqasm/lowering_test.exs`).
- qx Iron Laws checked: #6, #7, #8, #9 (the four flagged in the task).
- Violations found: **0**.

**Verdict: PASS** — no Iron Law violations found.

## Per-law findings

### #9 Dispatch completeness — PASS (traced by hand)

- Producer: `Qx.Operations.tdg/2` (`lib/qx/operations.ex:425-428`) emits
  `{:tdg, [qubit], []}` via `QuantumCircuit.add_gate/4`.
- Simulation: `apply_instruction/3` (`lib/qx/simulation.ex:479-498`)
  dispatches purely on `length(qubits)` (1 → `apply_single_qubit_op`),
  so a new single-qubit gate atom needs no separate "classifier" list —
  the plan's stated risk (missing classifier entry) does not apply to
  the actual code shape, but the outcome is correct regardless.
  `apply_single_qubit_op/5` (`lib/qx/simulation.ex:503-515`) has an
  explicit `:tdg -> Calc.apply_single_qubit_gate(state, Gates.t_dagger(), qubit, num_qubits)`
  arm (line 512), alongside the existing `:sdg`/`:t`/`:s` arms.
  `apply_gate_step/5` (line 425-430) is the single call site used by
  both `run/2` (line 106→403) and `steps/2` (line 337→812/852) —
  confirmed one shared dispatch path for both execution modes.
- Draw: `supported_gates` includes `:tdg` (and `:sdg`, fixing the
  pre-existing gap) at `lib/qx/draw/svg/circuit.ex:118,120`;
  `gate_label_and_color/2` has `:sdg -> {"S†", ...}` (line 679) and
  `:tdg -> {"T†", ...}` (line 681).
- QASM export: `instruction_to_qasm/2` has an explicit
  `{:tdg, qubits, params} -> single_qubit_gate_to_qasm("tdg", qubits, params)`
  arm (`lib/qx/export/openqasm.ex:291-292`).
- QASM import: `@stdgate_table` maps `"tdg" => {:tdg, 1, 0}`
  (`lib/qx/export/openqasm/lowering.ex:19`). The old decompose path is
  correctly removed: `@decomposable_gates` (line 226) is now
  `~w(sx u1 u2 id)` — `tdg` is NOT a member — and no
  `expand_gate({:decompose, "tdg"}, ...)` clause remains (only `sx`,
  `u1`, `u2`, `id` clauses at lines 274-285). No dead special-case arm
  left behind.
- Execution tests exist for BOTH `run/2` and `steps/2`, not just
  construction/draw/export:
  - `test/qx/operations_test.exs:48-62` — `t` then `tdg` is identity
    via `run/2`, tolerance `1.0e-6`.
  - `test/qx/operations_test.exs:64-78` — `tdg` state equals
    `phase(-π/4)` reference via `run/2`, tolerance `1.0e-6`.
  - `test/qx/operations_test.exs:80-93` — `:tdg` dispatched by
    `steps/2` without raising `Qx.GateError {:unsupported_gate, :tdg}`,
    with a final-state cross-check against `run/2`, tolerance `1.0e-6`.
  - `test/qx/export/openqasm/lowering_test.exs:73` — `"tdg"` now
    resolves via the "direct stdgate mapping" loop (native `{:tdg,...}`),
    not decomposition; a comment at lines 160-162 documents the
    behaviour change.

### #6 Public API — PASS

- Purely additive: `Operations.tdg/2` (new), `Qx.tdg/2` (new
  delegate, `lib/qx.ex:612-613`), `Qx.to_qasm/2` (`lib/qx.ex:1645-1646`),
  `Qx.from_qasm/1` (`lib/qx.ex:1663-1664`), `Qx.from_qasm!/1`
  (`lib/qx.ex:1684-1685`) — no existing public signature changed.
- The `from_qasm` `tdg → :tdg` (was `:phase`) import behaviour change
  is documented as `CHANGELOG.md` **Changed** (lines 31-38), correctly
  scoped as a non-breaking behaviour refinement (same observable
  simulation result, not a signature/return-type break) — matches Iron
  Law #6's SemVer carve-out for non-breaking changes.
- CHANGELOG **Added** entries present for `Qx.tdg/2` and the three QASM
  facade delegates (lines 22-29).

### #7 Typed errors — PASS

- `Operations.tdg/2` → `QuantumCircuit.add_gate/4`
  (`lib/qx/quantum_circuit.ex:102-111`) → `Qx.Validation.validate_qubit_index!/2`,
  which raises `Qx.QubitIndexError` on out-of-range qubit — no raw
  `ArgumentError`/`Nx`/`Complex` leak. Confirmed by
  `test/qx/operations_test.exs:33-39` (`assert_raise Qx.QubitIndexError`).
- QASM facade delegates (`Qx.to_qasm/2`, `Qx.from_qasm/1`,
  `Qx.from_qasm!/1`) are thin `defdelegate`s to `Qx.Export.OpenQASM`,
  which already raises typed `Qx.Qasm*Error`/returns `{:error, Exception.t()}` —
  no new raw-error surface introduced by the facade itself.

### #8 Tolerance — PASS

- All tdg-vs-phase / tdg-identity equivalence assertions use
  `assert_in_delta ..., 1.0e-6` or `max_diff < 1.0e-6`
  (`test/qx/operations_test.exs:61, 77, 92`) — at or above the
  `:c64` float32 epsilon floor (`1.0e-6`), consistent with Iron Law #8's
  sub-epsilon prohibition.

## Notes (non-violations, for context)

- The plan's risk #2 ("single-qubit classifier miss") describes a
  dispatch shape (separate gate-name allowlist before routing to
  `apply_single_qubit_op`) that doesn't match the actual code (dispatch
  is by qubit-count arity, not a gate-name allowlist) — this is a plan
  narrative imprecision, not a code defect; the real dispatch is
  correctly wired and tested.
