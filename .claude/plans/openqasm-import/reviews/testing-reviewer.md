# Testing Reviewer — OpenQASM Import

⚠️ Captured from agent chat output — agent's Write was denied.

**Summary**: Six test files, ~103 tests. `async: true` everywhere is correct (no shared state). Macro-generated tests include gate names in titles. Quality is high overall.

## BLOCKER

### B1. `test/qx/export/openqasm/round_trip_test.exs:27` — `states_equal?/2` may silently compare only real parts of complex statevectors
`Nx.subtract |> Nx.abs |> Nx.reduce_max` is correct *only* if `get_state/1` returns a complex-typed tensor (`{:c, 64}`). If the tensor is a real-float rank-2 matrix of shape `[2^n, 2]` (stacked real/imag), `Nx.abs` is element-wise float abs — not complex modulus — and the test would pass even if real and imaginary parts were swapped or had opposite signs.

**Fix**: Add `assert Nx.type(a) == {:c, 64}` precondition in `states_equal?/2`, or compute `Nx.LinAlg.norm(Nx.subtract(a, b))` which handles complex correctly.

### B2. `test/qx/export/openqasm_import_test.exs` — Doctests in new public API may not be running
The new `from_qasm/1` and `from_qasm_function/1` doctests live in `lib/qx/export/openqasm.ex` but no test file calls `doctest Qx.Export.OpenQASM`. (Note: parent counted "1 doctest" in earlier `mix test` runs but feature was added since.) Verify a `doctest` declaration exists or doctests aren't actually executed.

**Fix**: Add `doctest Qx.Export.OpenQASM` to a test file (e.g. `test/qx/export/openqasm_test.exs`) or confirm it's already there.

## WARNINGS

### W1. `test/qx/export/openqasm/round_trip_test.exs:94, 101` — Fragile relative `..` fixture paths
`Path.join([__DIR__, "..", "..", "..", "fixtures", ...])`. Moving the test file silently breaks all fixture tests with a `File.read!` runtime error.

**Fix**: Define a `@fixture_dir Path.expand("../../../fixtures/qasm", __DIR__)` module attribute, or use `Application.app_dir/2`.

### W2. `test/qx/export/openqasm_import_test.exs:104-106` — Missing-semicolon line accuracy is too permissive
`assert line >= 3` passes for any line ≥ 3. Comment admits "line 3 or 4 (eof)".

**Fix**: `assert line in [3, 4]`.

### W3. `test/qx/export/openqasm/codegen_test.exs:53-75` — `Code.compile_string/1` test never purges dynamically compiled module
Modules accumulate in BEAM across runs. Add `on_exit(fn -> :code.purge(module); :code.delete(module) end)` after line 71.

### W4. `test/qx/export/openqasm/parser_test.exs` — Missing test for unterminated block comment
`/* never closed` should return `{:error, %QasmParseError{}}`, not crash or hang.

### W5. `test/qx/export/openqasm/parser_test.exs` — No test for block comment that spans a string literal
e.g. `include "std/*.inc";` where `*` could confuse a naive comment scanner. Low risk but a real edge case.

### W6. `test/qx/export/openqasm_import_test.exs:77-79` — `from_qasm!/1` raise test doesn't pin message
`assert_raise Qx.QasmParseError, fn -> ... end` passes for any `QasmParseError`. Add `~r/header|OPENQASM/` pattern.

## SUGGESTIONS

- `expr_test.exs:82-86` — `assert_raise` for unknown function omits message pattern (`~r/foo/`).
- `codegen_test.exs:99-101` — `assert feature =~ "inner" or feature =~ "user"` uses `or` (truthy OR). Prefer `||` for boolean.
- `lowering_test.exs` — No test for valid program with empty instruction list (just registers, no gates).
- `parser_test.exs` — No test for unicode in identifiers (e.g., `qubit[1] θ;`); QASM 3 is ASCII-only.
- `round_trip_test.exs:100-106` — `bell.qasm` fixture test near-duplicates the `for`-loop bell test. Differentiate by including measurements in the fixture so measurement instructions get round-trip coverage.

## Verified OK
- `async: true` correct everywhere (no shared state)
- AAA structure consistent
- Macro-generated tests label cases by gate name
- Tolerance 1e-10 in round-trip is appropriate for double-precision after ~10 gates
