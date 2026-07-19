# Triage — OpenQASM Import

**Source review**: `.claude/plans/openqasm-import/reviews/openqasm-import-review.md`
**Date**: 2026-05-03

## Summary
Everything in the review approved for fix. **W1 auto-approved** (Iron Law 7). User selected all WARNINGs, all SUGGESTIONs, and both Requirements gaps. W2 fix approach: input-size cap at API entry.

## Fix Queue

### Requirements (must close to clear UNMET/PARTIAL)
- [ ] **REQ #21** Bump README install version `~> 0.5.2` → `~> 0.6.0` at `README.md:32, 82, 587, 681, 735` (5 places)
- [ ] **REQ #2** Add statevector-equality assertions for Grover-2 and IBM-example fixtures in `test/qx/export/openqasm/round_trip_test.exs` (use `drop_measurements/1` for IBM-example)

### WARNINGs

- [ ] **W1** (auto-approved, Iron Law 7) `lib/qx/export/openqasm/codegen.ex:190` — add `rescue e in [Qx.QasmParseError, Qx.QasmUnsupportedError] -> {:error, e}` to `Codegen.generate/1` so `expr_to_source/2`'s raise can't escape the public boundary
- [ ] **W2** `lib/qx/export/openqasm.ex` — add input-size cap (e.g. 1MB) at `from_qasm/1` and `from_qasm_function/1` entries; reject with typed `Qx.QasmParseError`. Also covers I3 (unbounded identifier) and I4 (deep parens) per security analyzer
- [ ] **W3** `lib/qx/export/openqasm/lowering.ex:101-105` — remove rescue-for-control-flow; refactor `expand_gate/5` to return `{:ok, instrs} | {:error, e}` and thread through `with` in `lower_stmt/2`
- [ ] **W4** `lib/qx/export/openqasm/lowering.ex:245` — `lower_body/2` should prepend + reverse-once instead of `acc ++ Enum.reverse(new_instrs)`
- [ ] **W5** `lib/qx/export/openqasm.ex:484-494` — rename `find_first_gate_def/1` → `find_main_gate_def/1`; update `@doc`; add a regression test pinning that a user-defined gate referenced inside another gate body returns `{:error, %Qx.QasmUnsupportedError{}}`
- [ ] **W6** Test polish:
  - `test/qx/export/openqasm/round_trip_test.exs:94, 101` — replace relative `..` with `@fixture_dir Path.expand("../../../fixtures/qasm", __DIR__)`
  - `test/qx/export/openqasm_import_test.exs:104-106` — `assert line in [3, 4]` (replace permissive `>= 3`)
  - `test/qx/export/openqasm/codegen_test.exs:53-75` — add `on_exit(fn -> :code.purge(module); :code.delete(module) end)` after compile_string test
  - `test/qx/export/openqasm/parser_test.exs` — add test for unterminated block comment

### SUGGESTIONs (batch in same PR)
- [ ] `lib/qx/export/openqasm/lowering.ex:256-276` — refactor `lookup_gate/2` to `case Map.fetch` (S1)
- [ ] `lib/qx/export/openqasm/codegen.ex:57` — replace `validate_each/2` adapter with `Enum.find_value/3` (S2)
- [ ] `lib/qx/export/openqasm/parser.ex:739-746` — `take_snippet/1` clean `case` instead of `|> case do` (S3)
- [ ] `lib/qx/export/openqasm/expr.ex:29` — `n / 1` → `n * 1.0` (S4)
- [ ] `lib/qx/export/openqasm/lowering.ex:122-130` — reuse `Qx.QuantumCircuit.new/1` initial state instead of building 2^n list host-side (S5)
- [ ] `lib/qx/export/openqasm/codegen.ex:200-205` — add catch-all to `call_emit/1` raising `Qx.QasmUnsupportedError` (iron-law SUGGESTION)
- [ ] `lib/qx/export/openqasm/parser.ex:42-45` and `lib/qx/export/openqasm/codegen.ex:84-93` — add `# SECURITY:` cross-reference comments (security W2)
- [ ] `lib/qx/export/openqasm/lowering.ex:369-373` — rescue `ArithmeticError` (e.g. `rx(1/0) q[0];`) and re-raise as `Qx.QasmParseError` (security I1)
- [ ] Tests: ArithmeticError regression, large-block-comment-completes-fast, gate-def-references-user-gate regression

## Skipped
None.

## Deferred
None.

## Notes
- W1 in the review document was cross-flagged by both elixir-reviewer (W3) and iron-law-judge (WARNING). Same fix; one task.
- W2 approach chosen: input-size cap (~5 LOC) at API entries rather than rewriting the block-comment combinator. Cap defaults to 1MB; raises `Qx.QasmParseError` with a clear message. Single change mitigates W2 + I3 + I4.
- Filtered (not in queue): testing-reviewer's two BLOCKER claims (statevector compare, doctest registration) — both verified already correct.
