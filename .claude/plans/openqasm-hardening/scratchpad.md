# Scratchpad — openqasm-hardening

## Decisions

- **Item 1 (paren-depth) = pre-parse scan**, not in-grammar. Mirror
  `enforce_size/1`: add `enforce_paren_depth/1` after it in BOTH `from_qasm/1`
  and `from_qasm_function/1`'s `with` chains. O(n) running-depth scan; reject
  over `@max_paren_depth` (recommend 64) with `Qx.QasmParseError`.
- **Item 2 (codegen) = `defmodule Qx.Generated.<Camelize(name)>` envelope.**
  `name` already validated `[A-Za-z_]\w*` by `Codegen.validate_identifier/1`, so
  `Macro.camelize` is safe. Add `:module` to the result map.
- **Typed errors** (Iron Law #7): `Qx.QasmParseError.exception(reason:)`.

## Verified facts

- Grammar recursion: parser.ex ~176 `( expr_ref )` re-enters `:expression`.
- `@max_qasm_size 1_048_576` + `enforce_size/1` at openqasm.ex:129/483.
- `from_qasm/1` (≈474) and `from_qasm_function/1` (≈491) both `with :ok <- enforce_size(source), …`.
- `Codegen.generate/1` returns `%{name, arity, source}`, source = bare
  `"def #{name}(circuit, …) do … end"`; rescues QasmParseError/QasmUnsupportedError.
- `validate_identifier/1` regex `\A[A-Za-z_][A-Za-z0-9_]*\z` → safe camelize.
- doctest openqasm.ex ~468-474 asserts `source =~ "def bell(circuit, a, b)"`
  (still true inside the wrapped module → minimal doctest impact).
- Test files: parser_test.exs, codegen_test.exs, expr_test.exs (unit);
  openqasm_test.exs / openqasm_import_test.exs (from_qasm public entry).

## Open questions (resolve at /phx:work)

- Depth cap = 64? scan precision (comments/strings counted — fine, fail-closed)?
  module collision policy (same gate name → same module; caller's concern)?
  add `:module` to map (recommend yes)?

## Dead ends

- In-grammar nimble_parsec depth counter — no clean hook; pre-scan is simpler
  and rejects before any frame is pushed.
