# Security Analyzer — OpenQASM Import

⚠️ Captured from agent chat output — agent's Write was denied.

## Executive Summary

No exploitable code-injection or atom-exhaustion vector found. Identifier production is strict ASCII `[A-Za-z_][A-Za-z0-9_]*`, defensively re-validated in codegen. Function-name dispatch is a literal `case`/whitelist in `Expr` and `Codegen`. No `String.to_atom/1` anywhere. Gate definitions are correctly ignored by `from_qasm/1`'s lowering path so untrusted source cannot smuggle codegen-bound bodies through the safe API. Two WARNINGs worth addressing as defence-in-depth, plus low-severity INFO items.

## BLOCKER
None. The high-risk `from_qasm_function/1` → `Code.compile_string/1` path is properly hardened.

## WARNING

### W1. `lib/qx/export/openqasm/parser.ex:23-26` — Quadratic block-comment scan (CPU DoS)
- Combinator: `block_comment = string("/*") |> repeat(lookahead_not(string("*/")) |> utf8_char([])) |> string("*/")`. The `lookahead_not` is checked at every byte → O(n²) on long bodies.
- Note: a linear scanner (`skip_to_block_close/1` at lines 660-662) already exists for if-else handling; the authors clearly know the linear pattern.
- **Attack input**: `"/*" <> String.duplicate("a", 10_000_000) <> "*/\nOPENQASM 3.0;\nqubit[1] q;\nh q[0];\n"`. Caller-controlled CPU burn proportional to (input_size)².
- **Fix**: (a) input-size cap (~5 LOC) at `from_qasm/1` entry; (b) replace combinator with manual linear scanner mirroring `skip_to_block_close/1`.
- CWE-1333 (Inefficient Regex Complexity).

### W2. `lib/qx/export/openqasm/parser.ex:42-45` & `lib/qx/export/openqasm/codegen.ex:84-93` — Identifier-charset invariant is undocumented
The ASCII-only `identifier` rule is the security invariant `Codegen.validate_identifier/1` relies on, plus the invariant that error-message interpolation (`name`, `reg_name`, `gate_name` at lowering.ex:212, 263, 332) is safe. Today consistent (both `[A-Za-z_][A-Za-z0-9_]*`); future widening would silently break the codegen safety contract.

**Fix**: Add `# SECURITY:` comments on `identifier` and `validate_identifier/1` cross-referencing each other.

## INFO

### I1. `lib/qx/export/openqasm/lowering.ex:369-373` — `ArithmeticError` on `1/0` leaks untyped exception
`evaluate_params/2` rescues only `Qx.QasmParseError`/`Qx.QasmUnsupportedError`. Untrusted QASM with `rx(1/0) q[0];` raises `ArithmeticError`, violating Iron Law 7. Not a security issue, but a contract bug.

**Fix**: Rescue `ArithmeticError` and re-raise as `Qx.QasmParseError`.

### I2. Float formatter output is safe
`:erlang.float_to_binary(n, [:short])` at codegen.ex:173 always emits `[+-]?\d+\.\d+(e[+-]?\d+)?`; never produces `nan`/`inf`/`:`/`#`/whitespace. ✅

### I3. Identifier length unbounded
parser.ex:42-45 has no `max:` cap. Mitigated by the W1 input-size cap recommendation.

### I4. Recursive `parsec(:expression)` stack depth
`((((1))))` × N consumes BEAM stack. Practical impact small; mitigated by W1 cap.

### I5. Gate-def isolation verified
`Lowering.lower_stmt({:gate_def, ...}, state)` at lowering.ex:138 silently ignores gate defs. ✅ Safe boundary between `from_qasm/1` and `from_qasm_function/1`.

### I6. `find_first_gate_def/1` actually returns LAST
`lib/qx/export/openqasm.ex:484-494` uses `List.last/1` despite the name. The "earlier defs are helpers" assumption is security-relevant: `Codegen.emit_stmt/3` (codegen.ex:117-120) rejects user-defined gate references inside another gate body, closing the smuggle path. **Recommend a regression test pinning that invariant**, plus rename to `find_main_gate_def/1`.

## Iron-Law Compliance

| Law | Status | Note |
|---|---|---|
| `String.to_atom/1` on user input | PASS | Verified absent across parser/lowering/codegen/expr |
| Pattern-match dispatch over dynamic atoms | PASS | All literal |
| Public functions raise typed `Qx.*Error` | MOSTLY PASS | See I1 |
| No needless processes | PASS | Pure functional |
| Validate at boundaries | PASS | Parser charset + `validate_identifier/1` |

## Recommendations (priority order)

1. **(Medium)** Address W1: input-size cap (cheap) or rewrite `block_comment` as linear scanner. Caps also mitigate I3 + I4.
2. **(Low)** Catch `ArithmeticError` in `evaluate_params/2` (I1).
3. **(Low, doc)** Add `# SECURITY:` cross-reference comments (W2).
4. **(Low)** Rename `find_first_gate_def` → `find_main_gate_def`; add regression test pinning user-defined gate ref rejection inside gate bodies (I6).

## Suggested security tests
- Identifiers with `\n`, `"`, `#{}`, NUL, backslash → parser rejects
- 1 MB block comment → completes under timeout (pins W1 fix)
- `rx(1/0) q[0];` → `Qx.QasmParseError` (pins I1)
- Gate def whose body references another user-defined gate → `Qx.QasmUnsupportedError` (pins I6)

## Manual tools
- `mix sobelow --exit medium`
- `mix deps.audit`
- `mix hex.audit`
