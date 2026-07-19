# Code Review — OpenQASM Import (qx-0c5/openqasm-import)

**Date**: 2026-05-03
**Verdict**: 🔶 **REQUIRES CHANGES** — driven by Requirements UNMET (#21 README version) and PARTIAL (#2 fixture coverage). No code-quality BLOCKERs.

**Counts** (after deduplication and filtering):
- BLOCKERs: 0
- WARNINGs: 6 unique (3 cross-flagged by multiple agents)
- SUGGESTIONs: ~12
- Requirements: 19 MET · 1 PARTIAL · 1 UNMET

## Requirements Coverage

| # | Requirement | Status | Gap |
|---|---|---|---|
| 1 | Round-trip on circuits emitted by `to_qasm/1` | MET | — |
| 2 | Statevector equality for **all 5 fixtures** (Bell, GHZ-3, QFT-3, Grover-2, IBM-example) | **PARTIAL** | Only Bell + GHZ-3 assert statevector equality; Grover-2 and IBM-example only assert parse success. Plan Phase 6 explicitly required all 5. |
| 3–20 | Stdgate dispatch, decomposition, error types, CHANGELOG, version bump, moduledoc, README section, Iron Law compliance | MET | — |
| 21 | README installation version updated to 0.6.0 | **UNMET** | `README.md:32, 82, 587, 681, 735` still read `~> 0.5.2` |

## Verification Gate
✅ **PASS** — `mix compile --warnings-as-errors` clean · `mix format --check-formatted` clean · `mix credo --strict` 0 issues · `mix test` 226 doctests + 614 tests, 0 failures · `mix docs` no new warnings.

## WARNINGs (must address)

### W1. `lib/qx/export/openqasm/codegen.ex:190` — `expr_to_source/2` raises and leaks past API boundary (Iron Law 7)
*Cross-flagged by iron-law-judge and elixir-reviewer.*
`Codegen.generate/1` has no `rescue` block. A gate body with an unknown identifier raises `Qx.QasmParseError` from `expr_to_source/2` and escapes the `{:ok,_}|{:error,_}` contract.

**Fix**: add `rescue e in [Qx.QasmParseError, Qx.QasmUnsupportedError] -> {:error, e}` to `Codegen.generate/1`, mirroring `Lowering.lower/1` (lowering.ex:102-105). OR refactor `expr_to_source` to return `{:ok, src}|{:error, e}`.

### W2. `lib/qx/export/openqasm/parser.ex:23-26` — Quadratic block-comment scan (CPU DoS)
*Flagged by security-analyzer.* `block_comment` uses `repeat(lookahead_not(string("*/")) |> utf8_char([]))`, which is O(n²) in the body length. Attack: `"/*" <> String.duplicate("a", 10_000_000) <> "*/\nOPENQASM 3.0;..."` burns CPU proportional to input² for any caller that accepts QASM from end users.

**Fix (cheapest)**: input-size cap at `from_qasm/1`/`from_qasm_function/1` entry (~5 LOC). **Better**: replace the combinator with a manual linear scanner mirroring the `skip_to_block_close/1` pattern at parser.ex:660-662 (which the file already implements for the `else` lookahead).

### W3. `lib/qx/export/openqasm/lowering.ex:101-105` — `rescue` for own-code control flow
*Flagged by elixir-reviewer.* `lower/1` rescues exceptions raised by `expand_gate/5` and converts them to `{:error, _}`. `expand_gate` is Qx code; deliberately raising and catching internally is the "rescue for control flow" anti-pattern.

**Fix**: change `expand_gate/5` to return `{:ok, instrs} | {:error, e}` and thread through `with` in `lower_stmt/2`. Removes the rescue.

### W4. `lib/qx/export/openqasm/lowering.ex:245` — O(n²) `acc ++ ...` in `lower_body/2`
*Flagged by elixir-reviewer.* `acc ++ Enum.reverse(new_instrs)` per iteration is O(length(acc)).

**Fix**: prepend, reverse once at the end (consistent with the outer `lower/1` loop).

### W5. `lib/qx/export/openqasm.ex:484-494` — `find_first_gate_def/1` name/doc/code mismatch
*Flagged by elixir-reviewer (W2) and security-analyzer (I6).* Function name and `@doc` say "first" but code uses `List.last/1`. Reader confusion; the scratchpad documents the last-wins intent but readers won't check the scratchpad.

**Fix**: rename to `find_main_gate_def/1`, update `@doc` to match. Also add a regression test pinning that user-defined gate references inside another gate body are rejected (security I6).

### W6. Multiple test gaps
*Flagged by testing-reviewer.* Most actionable:
- `test/qx/export/openqasm/round_trip_test.exs:94, 101` — fragile relative `..` paths; use `Path.expand("../../../fixtures/qasm", __DIR__)` once.
- `test/qx/export/openqasm_import_test.exs:104-106` — `assert line >= 3` is too permissive; tighten to `assert line in [3, 4]`.
- `test/qx/export/openqasm/codegen_test.exs:53-75` — `Code.compile_string/1` test never purges the dynamically compiled module; add `on_exit(fn -> :code.purge(module); :code.delete(module) end)`.
- `parser_test.exs` — no test for unterminated block comment; add one (also pins W2 fix).

## Filtered (not actionable)

- testing-reviewer B1 (statevector compare): VERIFIED correct. `Qx.Simulation.get_state/1` returns `{:c, 64}` and `Nx.abs` on complex tensors computes modulus (`|i| = 1.0`, `|i - (-i)| = 2.0`). The `states_equal?/2` helper is correct.
- testing-reviewer B2 (doctest registration): `doctest Qx.Export.OpenQASM` exists at `test/qx/export/openqasm_test.exs:3`. The new doctests for `from_qasm/1` and `from_qasm_function/1` ARE running (file-scoped count went 1 → 2).

## SUGGESTIONs (defer or batch)

- `lowering.ex:256-276` — `cond` + `Map.has_key?` → `case Map.fetch` (elixir S1)
- `codegen.ex:57` — `validate_each/2` adapter → `Enum.find_value/3` (elixir S2)
- `parser.ex:739-746` — `|> case do` → standard `case` (elixir S3)
- `expr.ex:29` — `n / 1` → `n * 1.0` for clarity (elixir S4)
- `lowering.ex:122-130` — host-side 2^n list build; reuse `Qx.QuantumCircuit.new/1` (elixir S5; security I3)
- `codegen.ex:200-205` — `call_emit/1` no catch-all; `FunctionClauseError` on whitelist drift (iron-law SUGGESTION)
- `parser.ex:42-45` & `codegen.ex:84-93` — add `# SECURITY:` cross-reference comments (security W2)
- `lowering.ex:369-373` — rescue `ArithmeticError` (e.g. `rx(1/0) q[0];`); re-raise as `Qx.QasmParseError` (security I1)
- Tests: parser unicode-identifier rejection, `ArithmeticError` regression, large block comment, gate-def-references-user-gate regression
- README/installation: bump 0.5.2 → 0.6.0 in 5 places (this is the UNMET requirement #21)

## Recommended fix sequence

1. Bump README version (REQ #21) — 5-min mechanical change; clears UNMET.
2. Add statevector-equality assertions to Grover-2 and IBM-example fixtures (REQ #2 PARTIAL); use `drop_measurements/1` first for IBM-example since it has measurements.
3. W1 codegen rescue (Iron Law 7) — small, well-scoped.
4. W2 input-size cap at API entries — 5 LOC; safest mitigation for the DoS.
5. W5 rename + regression test — 10 min.
6. W3, W4, W6 polish — non-blocking but cheap.
7. SUGGESTIONs to defer to a follow-up PR.
