## Requirements Coverage (from plan file `.claude/plans/openqasm-hardening/plan.md`)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| P1-T1 | Paren-depth tests: deep input → `QasmParseError` for both `from_qasm/1` and `from_qasm_function/1`; normally-nested expression still parses | MET | `test/qx/export/openqasm_import_test.exs` describe block "expression nesting cap" — three tests cover deep rejection for both entry points and the passing case |
| P1-T2 | Codegen envelope test: `source` contains `defmodule Qx.Generated.Bell`; result map has `module:`; compiles to that module | MET | `test/qx/export/openqasm/codegen_test.exs:53` ("wraps the generated def") + `codegen_test.exs:73` ("generated source compiles to its isolated module"); `assert inspect(module) == module_name` at `:87` |
| P1-T3 | Tests confirmed RED before implementation | UNCLEAR | Process step — no code artifact; plan checkbox is `[x]` but cannot verify from diff alone |
| P2-T1 | `@max_paren_depth 64` added near `@max_qasm_size` | MET | `lib/qx/export/openqasm.ex:134` (`@max_paren_depth 64`) |
| P2-T2 | `enforce_paren_depth/1` byte scan: tracks running depth, early-exit, raises typed `QasmParseError` | MET | `lib/qx/export/openqasm.ex` — `scan_paren_depth/2` tail-recursive byte-scan clauses; raises `Qx.QasmParseError.exception(reason: "expression nesting too deep (max #{@max_paren_depth} parentheses)")` |
| P2-T3 | `:ok <- enforce_paren_depth(source)` wired after `enforce_size` in BOTH `from_qasm/1` and `from_qasm_function/1` | MET | `lib/qx/export/openqasm.ex:432` (`from_qasm/1`) and `:484` (`from_qasm_function/1`) |
| P3-T1 | `Codegen.generate/1` wraps def in `defmodule Qx.Generated.<Name>_<hash> do … end`; result map gains `:module` | MET | `lib/qx/export/openqasm/codegen.ex:65` (`defmodule #{module} do\n`); `:67` (`%{name:, arity:, module:, source:}`); `generated_module_name/2` at `:71` uses `Macro.camelize(name)` + 8-char SHA-256 prefix (hash-naming is the approved outcome) |
| P3-T2 | Moduledoc + `from_qasm_function/1` `@doc` updated to describe module envelope and new `:module` field; `@spec` map updated | MET | `lib/qx/export/openqasm.ex:30–44` (moduledoc diff); `:451–465` (`@doc` diff); `@spec` map updated to include `module: String.t()` |
| P3-T3 | Doctest updated: asserts both `"defmodule Qx.Generated.Bell"` and `"def bell(circuit, a, b)"` | MET | `lib/qx/export/openqasm.ex:481` — `source =~ "defmodule Qx.Generated.Bell" and source =~ "def bell(circuit, a, b)"` |
| P4-T1 | CHANGELOG `### Security` under `[Unreleased]`: (a) depth-cap note; (b) module-envelope behaviour-change note | MET | `CHANGELOG.md:10` (`### Security`); both bullets present — depth-cap and `defmodule Qx.Generated.<Name>_<hash>` behaviour-change with `:module` field callout |
| P4-T2 | Two v0.8.2 ROADMAP items ticked | MET | `ROADMAP.md` — both paren-depth and codegen-envelope lines flipped from `- [ ]` to `- [x]` with completion notes |
| Verification | `mix compile`, `mix format`, `mix credo --strict` clean; `mix test` 242 doctests + 932 tests, 0 failures | UNCLEAR | Plan checkboxes all `[x]`; prompt states these results; cannot independently run the suite from diff review alone |
| Scope discipline | Only Group C (OpenQASM) files touched; config / IBM / deps groups absent; braces not capped | MET | Diff limited to `lib/qx/export/openqasm.ex`, `lib/qx/export/openqasm/codegen.ex`, their tests, `CHANGELOG.md`, `ROADMAP.md` — no Group A/B/D files present |

**Summary**: 11 MET · 0 PARTIAL · 0 UNMET · 2 UNCLEAR
