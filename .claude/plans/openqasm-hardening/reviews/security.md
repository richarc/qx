# Security Review: OpenQASM hardening (v0.8.2)

**Verdict: PASS — no BLOCKERs.** Both findings are correctly closed. Two
SUGGESTIONs only.

## ITEM 1 — Parenthesis-depth cap (DoS)

`enforce_paren_depth/1` is wired BEFORE `Parser.parse` in both `from_qasm/1`
(openqasm.ex:432-433) and `from_qasm_function/1` (487-488). Correct.

- **Early-exit: confirmed.** `scan_paren_depth/2` (511-529) errors the instant
  `depth > 64` on the 65th net-unmatched `(` — a `(((…` bomb is rejected after
  ~65 bytes, never scanning the 1 MB. For non-bomb input the full scan is O(n),
  n≤1 MB — trivially bounded, not itself a DoS.
- **Net-depth is the right metric.** Each parser recursion frame consumes one
  `(` (primary paren-expr, `fun_name(...)`, `param_list`). Max simultaneous
  unmatched `(` == max recursion depth, so cap 64 ⇒ parser depth ≤64. Tight and
  correct. `()()()…` (depth 1) correctly passes — it causes no deep recursion.
- **UTF-8: safe.** The `<<_, rest::binary>>` catch-all (529) consumes one byte;
  UTF-8 continuation/lead bytes are all ≥0x80 and never collide with `(`/`)`
  (0x28/0x29). Cannot crash (total catch-all) nor miscount.
- **Counts `(` in comments/strings: acceptable.** Fail-closed; 64-deep parens
  inside a comment/`include` literal is implausible. No realistic false-reject.
- **64 is a safe cap.** No legitimate gate-param arithmetic nests 64 parens deep.
- **No residual recursion vector.** Verified parser: `[` (qubit/cbit refs)
  encloses only `unsigned_integer` — no recursion. `{` gate/if bodies do NOT
  nest in v1 (parser.ex:369; gate bodies hold gate calls only). `-` unary does
  not self-recurse (primary ≠ unary). So `(` is the sole deep-recursion vector
  and it is fully capped.

## ITEM 2 — Codegen module wrapping (code-injection defence-in-depth)

- **Module name attacker-uninfluenced.** `name` is `[A-Za-z_][A-Za-z0-9_]*` at
  the parser (parser.ex:40-43) AND re-validated by `validate_identifier/1`
  (codegen.ex:101-110, anchored `\A…\z`). No `.` possible ⇒ `Macro.camelize`
  cannot emit a dotted alias, cannot escape `Qx.Generated.*`, cannot yield
  `Elixir.Kernel` (always prefixed `Qx.Generated.` + `_<8hex>` suffix). Worst
  case a crafted `name` lands at `Qx.Generated.<Camel>_<hash>` — isolated.
- **Wrapping achieves isolation.** Generated `def` now lives in a fresh
  `defmodule`, so `Code.compile_string/1` cannot inject `name/arity` into the
  caller's module. Body calls (`Qx.h/2` …) resolve to the real Qx module —
  intended.
- **Body is whitelist-only.** `emit_stmt` emits solely `@stdgate_emit` `Qx.*`
  helpers; non-whitelisted/decomposable/user-gate refs → typed error
  (codegen.ex:121-138). `expr_to_source` emits only numeric literals, six
  whitelisted `:math.*` calls (`call_emit/1` raises otherwise), and identifiers
  proven `in env` (validated param names). Qubit refs checked against validated
  `qubit_names`. No path smuggles an arbitrary atom/call into the body.
- **Typed errors retained** (`Qx.QasmParseError`/`QasmUnsupportedError`); no
  secrets logged.

## Suggestions (non-blocking)

- **SUGGESTION:** `scan_paren_depth` counts parens inside block comments and
  string literals. Harmless today, but if a future grammar legitimately allows
  deep parenthesised data in a string, the raw scan would false-reject. A
  one-line code comment noting the deliberate fail-closed tradeoff would prevent
  a later "bug fix" from weakening it.
- **SUGGESTION:** Add a regression test asserting a `(`×65 source returns
  `{:error, %Qx.QasmParseError{}}` and that a balanced `()`×100k (depth 1)
  still parses — locks in the net-depth semantics against future refactors.

Checked: input validation, atom-exhaustion, code-injection, DoS/recursion,
UTF-8 handling, error typing, secret logging — all clean.

_Static review only (Read/Grep). Recommend `mix sobelow --exit medium` and
`mix test` for confirmation._
