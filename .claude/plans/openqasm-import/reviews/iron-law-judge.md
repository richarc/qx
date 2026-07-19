# Iron Law Judge — OpenQASM Import

⚠️ Captured from agent chat output — agent's Write was denied.

**Branch**: `qx-0c5/openqasm-import`
**Files scanned**: 8 | **Iron Laws checked**: Qx-specific set (7)
**Violations**: 2 (0 BLOCKER, 1 WARNING, 1 SUGGESTION)

## WARNING

### `lib/qx/export/openqasm/codegen.ex:190` — `expr_to_source/2` raises uncaught; breaks `{:ok,_}|{:error,_}` contract (Iron Law 7)
`Codegen.generate/1` has no `rescue` block. If a gate body contains an identifier not in `param_names`, the `raise Qx.QasmParseError` inside `expr_to_source/2` escapes the tagged-tuple contract and surfaces as an unhandled exception to callers of `from_qasm_function/1` (`openqasm.ex:440`). `Lowering.lower/1` correctly rescues at lowering.ex:102-105; codegen does not.

**Fix**: add `rescue e in [Qx.QasmParseError, Qx.QasmUnsupportedError] -> {:error, e}` to `Codegen.generate/1`, OR convert the raise to return `{:error, ...}` and thread through `emit_body`.

(Same finding as elixir-reviewer W3 — keep this iron-law-judge phrasing per deconfliction rule.)

## SUGGESTION

### `lib/qx/export/openqasm/codegen.ex:200-205` — `call_emit/1` has no catch-all; `FunctionClauseError` escapes on whitelist drift
Parser `fun_name` combinator and `call_emit/1` are currently in sync (sin/cos/tan/exp/ln/sqrt). If they drift, a `FunctionClauseError` escapes the API boundary instead of `Qx.QasmUnsupportedError`. Low risk now but fragile.

**Fix**: add `defp call_emit(name), do: raise Qx.QasmUnsupportedError, feature: "function #{name}"` and ensure the rescue from the WARNING above covers it.

## Verified OK

| Iron Law | Status | Evidence |
|---|---|---|
| 1. No `String.to_atom` on caller input | ✅ CLEAN | `@stdgate_table` (lowering.ex:29-57), `@stdgate_emit` (codegen.ex:22-45) are compile-time literal maps. `apply_fun/2` (expr.ex:51-62) whitelist-matches string literals. Identifiers stay binaries throughout. |
| 2. No process without runtime reason | ✅ CLEAN | No `GenServer`/`Agent`/`Task`/`start_link` in any new module. |
| 3. Reshape over gather in `defn` | ✅ N/A | No `defn` code in this feature. |
| 4. `defn` backend-agnostic | ✅ N/A | — |
| 5. No host loops over 2^n | ⚠️ See elixir-reviewer S5 | `initial_state_vector/1` allocates 2^n list before Nx.tensor; not strictly an Iron Law violation but borderline. |
| 6. CHANGELOG + version bump | ✅ VERIFIED | `mix.exs:6` `version: "0.6.0"`; `CHANGELOG.md` has complete `[0.6.0]` entry. Existing `to_qasm/1` signature unchanged. |
| 7. Typed errors at boundary | ⚠️ MOSTLY | `Qx.QasmParseError`/`Qx.QasmUnsupportedError` defined at errors.ex:177-260. `from_qasm/1` path clean. **Gap**: `from_qasm_function/1` path (see WARNING). |

## Codegen injection safety
✅ VERIFIED. Parser `identifier` combinator (parser.ex:42-45) limits chars to `[A-Za-z_][A-Za-z0-9_]*`. `validate_identifier/1` (codegen.ex:84) re-validates as defence-in-depth before any source string construction. Floats use `:erlang.float_to_binary/2` with no user-controlled interpolation.
