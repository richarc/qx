# Test Review: feat/from-qasm-function-atom

## Summary

One new test added to `test/qx/export/openqasm/codegen_test.exs` (describe
`"from_qasm_function/1"`, flat — not actually nested inside a `"wraps the
generated def"` describe block; there is no such nested describe, all tests
in that block are siblings) plus an extension of the `from_qasm_function/1`
doctest in `lib/qx/export/openqasm.ex`. No existing test assertion was
modified — verified by reading the full pre-existing test bodies (lines
7–100, 136–210 of `codegen_test.exs`); the new test is appended at lines
102–134, purely additive.

`module_ref` coverage is functionally complete for what it claims:
- atom-ness: `assert is_atom(module_ref)`
- string/atom consistency: `assert inspect(module_ref) == module`, asserted
  *before* `Code.compile_string/1` runs — this is a meaningful detail: it
  proves `module_ref` is produced by `Module.concat/1` independent of
  whether the module has been compiled yet (matches `Codegen.generate/1`,
  which builds `module_ref` before returning, not by introspecting a
  compiled artifact).
- real compile+call execution: compiles `source`, asserts `compiled ==
  module_ref`, then `apply(module_ref, :bell, [circuit, 0, 1])` and checks
  `result.instructions`.
- cleanup: `on_exit(fn -> :code.purge(module_ref); :code.delete(module_ref) end)`
  mirrors the existing pattern in the prior test (lines 89–92), correctly
  registered after compilation.

## Iron Law Violations

None. `async: true` is correct (no global state touched — the dynamically
loaded module is purged/deleted per-test via `on_exit`). No mocking
involved.

## Issues Found

### Critical

None.

### Warnings

- [ ] **Duplicate QASM source across two compiling tests risks a latent
  module-identity coupling.** The new test (`codegen_test.exs:102-134`) uses
  byte-for-byte the same QASM source as the pre-existing "generated source
  compiles to its isolated module" test (`codegen_test.exs:73-100`). Because
  `Codegen.generated_module_name/2` hashes the emitted `def_source`
  (`lib/qx/export/openqasm/codegen.ex:84-91`), identical QASM ⇒ identical
  generated module atom (`Qx.Generated.Bell_<same-hash>`) in both tests.
  Both tests `Code.compile_string/1` that same module and `on_exit`
  purge/delete it. This is safe *only* because ExUnit executes tests within
  one case sequentially (not interleaved), so test A's `on_exit` fully
  removes the module before test B recompiles it. That's an implicit,
  undocumented dependency on ExUnit's execution model rather than test
  independence — a future change to test ordering/parallelism, or a
  `--seed`-triggered re-order edge case, could produce a "redefining
  module" warning or a purge/delete race. Fix: vary the QASM body slightly
  (e.g. add a no-op qubit rename or swap gate order) between the two tests
  so they generate distinct module names, or extract a shared helper that
  builds a fresh/unique circuit per test.

### Suggestions

- [ ] `from_qasm_function!/1`'s success test (`codegen_test.exs:195-203`)
  only asserts `%{name: "bell", arity: 3}`, not `module_ref`. Since
  `from_qasm_function!/1` simply unwraps `from_qasm_function/1`'s `{:ok,
  result}`, this is low risk, but adding `module_ref` to that pattern match
  would keep bang/non-bang coverage symmetric and catch a future
  regression where the bang wrapper accidentally reshapes the result map.
- [ ] The new test substantially overlaps the existing "generated source
  compiles to its isolated module" test (same source, same compile+apply+
  assert-instructions flow) — the only net-new assertions are the three
  `module_ref`-specific ones (`is_atom`, `inspect(module_ref) == module`,
  `compiled == module_ref`). Consider trimming the new test to just those
  three assertions (it can still compile to prove the equality holds
  end-to-end) rather than re-asserting `result.instructions`, to reduce
  duplication and make the delta this test is pinning obvious at a glance.

## Verdict

**PASS** (no Iron Law violations, no Critical findings). One Warning
(latent test-independence coupling via identical generated module names)
worth fixing before/soon after merge, plus two minor Suggestions.

Counts: Critical 0, Warnings 1, Suggestions 2.
