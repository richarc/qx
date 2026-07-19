# Test Review: openqasm-hardening test changes

## Summary

Two test files changed. Both use `async: true` with no shared global state — async safety is intact. No Iron Law violations. The compile test is a valid end-to-end proof. One Warning, three Suggestions.

## Iron Law Violations

None.

## Issues Found

### Critical

None.

### Warnings

- [ ] **Broad error-reason regex may mask wrong rejection path** (`openqasm_import_test.exs`, line 38). The assertion `reason =~ ~r/nest|deep|paren/i` would pass if the implementation bails with a generic "unexpected parenthesis" parse error rather than the intended depth-cap guard. If the depth scanner is ever disabled by refactor, the test continues to green because the deeply-nested source is still syntactically odd enough to produce a parser error that mentions "paren". Pin the error more tightly — e.g., assert against `"depth"` or a constant the implementation actually emits — so the test guards the right code path.

### Suggestions

- [ ] **No at-boundary depth test** (`openqasm_import_test.exs`, lines 33–51). The three tests use depth 200 (far over), depth 3 (far under), and depth 3 again in the passing case. None exercise depth 64 (should succeed) versus depth 65 (should fail). Without a boundary test, a regression that moves the cap to, say, 50 or 100 would not be caught by this suite. Adding two cases — `String.duplicate("(", 64)` accepted, `String.duplicate("(", 65)` rejected — would pin the exact contract.

- [ ] **`Code.compile_string` result allows extra modules** (`codegen_test.exs`, line 86). The pattern `[{module, _bin} | _]` accepts a list of any length. A single `defmodule` wrapping one `def` should produce exactly one entry. Using `[{module, _bin}]` (no tail wildcard) would catch codegen accidentally emitting helper modules or extra artifacts, making the test a tighter proof.

- [ ] **`on_exit` registered after compilation** (`codegen_test.exs`, lines 89–92). If `Code.compile_string/1` raises unexpectedly, `on_exit` is never registered and any partial module load is not cleaned up. Registering `on_exit` before the compile call — using a reference captured via `module_name` and the `String.to_atom/1` of the known deterministic name — would ensure cleanup fires regardless of compile outcome. (Not urgent because well-formed source from `from_qasm_function/1` should not raise, but defensive ordering is a best practice in async test suites.)

## Confirmed Safe (items the prompt asked to verify)

**Async redefinition race**: Only `"generated source compiles to its isolated module"` calls `Code.compile_string`. The `"wraps the generated def"` test inspects the source string only. Both tests use the same bell-gate input and would produce the same hash-deterministic module name, but since compilation happens in exactly one test, no async collision exists.

**Old bare-`def` shape not broken**: The remaining source-content assertions (`source =~ "def bell(circuit, a, b)"`, etc.) remain valid because the new `defmodule` envelope still contains those substrings. No other test file references `source` from `from_qasm_function`.

**`on_exit` purge correctness**: `module` in the `on_exit` closure is the atom returned by `Code.compile_string` (not the string `module_name`). `:code.purge/1` and `:code.delete/1` take atoms, so the call is correctly typed. The hash-deterministic module name means repeated runs purge the right entry.

**Deep-paren error path**: The 200-deep string is syntactically plausible as a nested expression (not a bare-paren syntax error), so a correct depth scanner must be what rejects it — the parse can only reach the depth guard before falling to a generic parser error. The concern (Warning above) is that the regex is too permissive to distinguish depth-cap from parser-level paren errors if the implementation changes.
