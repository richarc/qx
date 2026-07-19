# Testing Review: feat/qasm-facade-tdg

## Summary

Test coverage matches all five plan phases: construction + typed-error +
execution (Phase 1), draw labels (Phase 2), QASM export/import round-trip
(Phase 3), facade delegates (Phase 4). The Iron Law #9 execution requirement
is genuinely satisfied — `test/qx/operations_test.exs` exercises `:tdg` via
both `Qx.run/2` and `Qx.steps/2` with real state/probability comparisons, not
just construction. Tolerances are `1.0e-6` (state/probability, c64-appropriate
per Iron Law #8) and `1.0e-12` (host-side float param round-trip, not state
precision — fine). The `doctest :except` list is justified (5 pre-existing
broken doctests unrelated to `tdg`, recorded as ROADMAP debt) and does not
grow with this branch. The one existing-test removal (old `tdg → phase(-π/4)`
decomposition test in `lowering_test.exs`) is human-approved and leaves no
coverage hole — the new native `{"tdg", :tdg}` case in the same file's
stdgate-mapping loop covers the same import path, now asserting the (new,
correct) native shape instead of the decomposed one.

## Iron Law Violations

None found.

- **Iron Law #9 (dispatch completeness):** Satisfied. `operations_test.exs`
  traces `Operations.tdg` output through both `Qx.run/2` (state + probability
  comparison against a `phase(-π/4)` reference, and a `t |> tdg == identity`
  check) and `Qx.steps/2` (materializes the stream and asserts it doesn't
  raise `{:unsupported_gate, :tdg}`, then cross-checks final step probabilities
  against `run/2`). This is real execution coverage, not construction/draw/
  export dressed up as it.
- **Iron Law #8 (tolerance):** `assert_in_delta ..., 1.0e-6` and
  `max_diff < 1.0e-6` are used for `:c64` (float32) state/probability
  comparisons — at or above the epsilon floor, correctly not sub-epsilon.

## Issues Found

### Critical

None.

### Warnings

None.

### Suggestions

- `test/qx/operations_test.exs` line 61 uses `Enum.zip |> Enum.each` with
  `assert_in_delta` inside the `fn {r, o} ->` — idiomatic and fine, but note
  this pattern is repeated 3x across the new tests (lines 61, 91-92); consider
  a small private helper (e.g. `assert_probs_close(a, b, tol \\ 1.0e-6)`) if a
  fourth call site appears in a future gate PR, to avoid drift in the
  comparison idiom.
- The `doctest ... except: [...]` comment (lines 4-12) is thorough and
  explains scope, but since this is the *first* time `doctest Qx.Operations`
  is wired up, it may be worth a one-line addition confirming the doctest
  count increase was checked in `mix test` output (per the repo's own
  `CLAUDE.md` TDD rule #4) — this is process documentation, not a test defect,
  so not a blocking item.
- `lowering_test.exs`'s `describe "decompositions"` block retains a comment
  explaining the `tdg` move (lines 160-162) — good practice; no action needed.

## Coverage vs Plan Phases 1-5

| Phase | Plan requirement | Test evidence |
|---|---|---|
| 1 | `tdg/2` construction + typed error + execution (run/2 + steps/2) | `operations_test.exs` describe blocks `"tdg/2"` and `"tdg execution"` — all present |
| 2 | `:tdg`→"T†", `:sdg`→"S†" draw labels | `draw/circuit_test.exs` describe `"Draw.circuit/2 — dagger gate labels"` — both present |
| 3 | QASM export `tdg q[0];`, native import, round-trip | `export/openqasm_test.exs` (export + round-trip) and `lowering_test.exs` stdgate-mapping loop (import) — present; old decomposition test correctly removed (human-approved) |
| 4 | `Qx.tdg/2`, `Qx.to_qasm/2`, `Qx.from_qasm/1`, `Qx.from_qasm!/1` facade delegates | `operations_test.exs` (`Qx.tdg`) and `export/openqasm_test.exs` describe `"Qx facade delegates for OpenQASM"` — all four covered |
| 5 | CHANGELOG/verify — no test artifact expected | N/A (verify-only phase) |

No coverage gaps identified against the plan.

## Verdict

**PASS**

## Counts by Severity

- Critical: 0
- Warnings: 0
- Suggestions: 2
