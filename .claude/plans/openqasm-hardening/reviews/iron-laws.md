# Iron Law Violations Report

## Summary

- Files scanned: `lib/qx/export/openqasm.ex`, `lib/qx/export/openqasm/codegen.ex`, `CHANGELOG.md`, `mix.exs`
- Iron Laws checked: 3 (the three scoped in the prompt: #1, #6, #7)
- Violations found: 1 (0 critical, 0 high, 1 medium/WARNING)

---

## Medium Violations (WARNING)

### [#6] Breaking Public API — Version Bump Insufficient

- **File**: `mix.exs:7` and `CHANGELOG.md` (Unreleased section)
- **Confidence**: LIKELY
- **Detail**:

  Two behaviour changes ship against `Qx.Export.OpenQASM`, a declared-public
  module:

  1. `from_qasm_function/1` — the returned `source` changed from a bare `def …`
     to a self-contained `defmodule … do … end`, and the result map gained a
     `:module` key. Any caller that pattern-matched on the old shape, passed
     `source` to `Code.eval_string/1` expecting a bare function, or ignored
     the extra key carelessly now behaves differently.

  2. `from_qasm/1` (and `from_qasm!/1`) — inputs with parenthesis nesting > 64
     that previously parsed now return `{:error, %Qx.QasmParseError{}}` (or
     raise). That is a stricter acceptance envelope; callers relying on the
     old behaviour see new errors.

  The CHANGELOG documents both changes correctly under `### Security`, with an
  explicit "Behaviour change:" call-out for the `from_qasm_function/1` shape.
  That satisfies the CHANGELOG requirement of Iron Law #6.

  What is not satisfied: the version has not moved. `mix.exs` still reads
  `version: "0.8.1"` (the last released tag). If these changes ship as
  `v0.8.2` (a patch increment), that violates SemVer and Iron Law #6, which
  requires a version bump proportional to the change. For a pre-1.0 library
  (`0.x.y`), the SemVer convention is that breaking changes increment the
  **minor** component — so the correct target is `v0.9.0`, not `v0.8.2`.

- **Fix**: Before tagging, bump `version:` in `mix.exs` to `"0.9.0"` and add a
  `## [0.9.0]` section to `CHANGELOG.md`. Do not use `0.8.2` for these two
  behaviour changes.

---

## Passing (no finding needed, confirmations for the three scoped checks)

Checked 3 of the 22 Iron Laws against the diff. 1 violation found.

**#7 — Typed errors, no raw leak (CLEAN).**
`enforce_paren_depth/1` delegates to the tail-recursive `scan_paren_depth/2`,
which returns `{:error, Qx.QasmParseError.exception(reason: …)}` — a typed
exception struct, not a raw string or bare atom. This slots into the `with`
pipeline in both `from_qasm/1` and `from_qasm_function/1` without
modification, so the typed error propagates correctly to callers.
`from_qasm!/1` matches `{:error, exception}` and calls `raise exception`,
which unwraps the struct cleanly. No raw error leaks.

**#1 — No atom creation from user input (CLEAN).**
`Codegen.generated_module_name/2` calls `Macro.camelize(name)` (string → string)
then interpolates the result into a binary string:
`"Qx.Generated.#{Macro.camelize(name)}_#{hash}"`.
No call to `String.to_atom/1`, `Module.concat/1`, or
`:erlang.binary_to_atom/2` appears anywhere in codegen. The returned
`module` value is a plain `String.t()`, stored as-is in the result map and
interpolated into the `defmodule … do` source string. A BEAM atom is only
created if and when a downstream caller passes `source` to
`Code.compile_string/1` — that is their choice and their process, not Qx's.
The Iron Law is not violated.
