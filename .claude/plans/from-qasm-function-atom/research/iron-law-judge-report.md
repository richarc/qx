# Iron Law Violations Report — `feat/from-qasm-function-atom`

## Summary

- Files scanned: `lib/qx/export/openqasm/codegen.ex`, `lib/qx/export/openqasm.ex`, `CHANGELOG.md`, `.claude/plans/from-qasm-function-atom/{plan,scratchpad}.md`
- Iron Laws checked: #1 (atom-table exhaustion), #6 (public API), #7 (typed errors)
- Violations found: 1 (1 critical)

## Critical Violations

### [#1] Atom-table exhaustion — `Module.concat/1` runs unconditionally at parse time, not gated by compilation

- **File**: `lib/qx/export/openqasm/codegen.ex:69` (`module_ref = Module.concat([module])`), called unconditionally from `generate/1` (invoked by `Qx.Export.OpenQASM.from_qasm_function/1` at `lib/qx/export/openqasm.ex:504`)
- **Code**:
  ```elixir
  module = generated_module_name(name, def_source)
  module_ref = Module.concat([module])   # <-- interns the atom NOW
  source = IO.iodata_to_binary([...])
  {:ok, %{name: name, arity: arity, module: module, module_ref: module_ref, source: source}}
  ```
- **Confidence**: DEFINITE
- **Analysis — the plan's safety argument is incomplete**:
  The plan/scratchpad argue: *"the atom already comes into existence when the caller compiles `source`... `Module.concat/1` on the same qx-generated, validated name creates no atom that compiling `source` wouldn't."* This is true **only for the subset of calls where the caller goes on to compile**. It is not true in general, and this PR changes the timing of atom creation from "caller-gated" to "unconditional at call time":
  - **Before this change**: `from_qasm_function/1` returned `module` as a *string only*. No atom was interned unless/until the caller called `Code.compile_string(source)` (which itself defines the module, interning the atom as a side effect of compilation — a caller-controlled, typically bounded action).
  - **After this change**: `Codegen.generate/1` calls `Module.concat([module])` itself, on every successful parse, **before the caller decides whether to compile anything**. The `@doc` example in `openqasm.ex:494` confirms this — `is_atom(module_ref)` is asserted directly off the `from_qasm_function/1` result, with no `Code.compile_string` step preceding it.
  - `name` in the generated module string (`"Qx.Generated.#{Macro.camelize(name)}_#{hash}"`) is caller-chosen — `validate_identifier/1` only constrains it to `[A-Za-z_]\w*`, it does not constrain the *set* of distinct names a caller may submit. `def_source`'s content-hash further means even a fixed name with a varied gate body produces a distinct module string.
  - **Consequence**: any caller — or any attacker able to reach `from_qasm_function/1` with attacker-supplied QASM text (e.g. a hypothetical qxportal "preview my gate" transpilation endpoint that does not itself go on to compile every submission) — can mint one permanent, never-GC'd atom per call, simply by varying the `gate <name> ...` identifier (or body) across repeated calls. There is no rate limit, no cap on distinct calls, and no reuse/interning check inside `qx` itself. `enforce_size/1` bounds the *size* of a single source blob (1 MB) but does nothing to bound the *number* of calls or the *number of distinct atoms* created across calls.
  - This is exactly the repeated-calls-with-distinct-input shape Iron Law #1 exists to catch, and it is **newly introduced** by this diff — the pre-existing code path had no atom-creation surface reachable without a compile step.
- **Fix** (pick one, in order of preference):
  1. **Don't eagerly intern.** Remove the `Module.concat/1` call from `Codegen.generate/1`. Keep `module` (string) as the sole return value from parsing; document `Module.concat([module])` as the one-line idiom callers run themselves, *after* they decide to compile. This restores the original invariant — atom creation stays gated behind the caller's own compile decision — at the cost of losing the (minor) convenience this feature adds (it saves callers exactly one stdlib call).
  2. If the eager atom is kept, **loudly document the hazard** in both the `@doc` for `from_qasm_function/1` and the moduledoc: calling this function mints a permanent atom per distinct gate name/body *even if the source is never compiled*; any caller exposing it to repeated/untrusted invocation (rate-limited or not) must itself cap the number of distinct gate submissions accepted per unit time / per session. Flag explicitly for qxportal's transpilation-service integration, since that is the one caller in this workspace positioned to receive external, attacker-influenced QASM text repeatedly.
  3. Add an internal safety valve in `qx` itself — e.g. bound the number of distinct `Qx.Generated.*` atoms created per process/runtime (a `:persistent_term` or ETS-backed counter with a hard ceiling, erroring with a typed exception past the ceiling) — but this is a larger design change than the plan's stated 2-file/complexity-3 scope and should be a separate ROADMAP item if pursued.

**Recommendation**: do not merge as-is without at minimum applying fix (2) — the doc/moduledoc hazard warning — and ideally fix (1), given the feature is a one-line convenience whose eager form reopens an atom-exhaustion vector this codebase has otherwise been careful to close (see the existing `@max_qasm_size`/`@max_paren_depth` hardening in the same file for the established bar).

## High Violations

None found.

## Medium Violations

None found.

## Non-violations confirmed (per audit scope)

- **#6 (public API)**: Confirmed additive — `module:` (string) unchanged, `module_ref:` is a new map key only; existing tests (`codegen_test.exs:68/69/94`) untouched. `CHANGELOG.md:30-35` `[Unreleased] → Added` entry present and correctly worded as non-breaking. No version bump present or required (correct per Iron Law #6 — only breaking changes require a bump).
- **#7 (typed errors)**: Confirmed unchanged — `Codegen.generate/1`'s `rescue e in [Qx.QasmParseError, Qx.QasmUnsupportedError] -> {:error, e}` clause is untouched; the new `module_ref` key is only added on the `:ok` branch. `from_qasm_function/1`'s `with` chain and `enforce_size`/`enforce_paren_depth`/parser error paths are unmodified.
- No `String.to_atom/1` anywhere in the diff — the only atom-creation call is `Module.concat/1`, and the input to it is a qx-generated string (`Macro.camelize(name) <> "_" <> hash`), not raw caller text; the finding above is about *timing/repetition* of atom creation, not about the identifier-validation itself, which is sound (`validate_identifier/1` regex-anchored `[A-Za-z_][A-Za-z0-9_]*`).
