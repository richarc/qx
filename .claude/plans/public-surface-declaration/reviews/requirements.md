## Requirements Coverage (from plan file `.claude/plans/public-surface-declaration/plan.md`)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | P1-T1: AGENTS.md Iron Law #6 lists all 14 public modules + internal carve-out | MET | `AGENTS.md:387` — law reworded; full 14-module surface + Validation/Draw.SVG.*/OpenQASM.*/Hardware.Ibm/Portal carve-out present |
| 2 | P1-T2: complexity-table row reconciled to Iron Law #6 surface (all 14 modules) | MET | `AGENTS.md:326` — row now reads "any declared-public module (the Iron Law #6 surface: …)" with all 14 listed |
| 3 | P1-T3: lib/qx.ex `## Modules` adds Register, StateInit, Hardware, Hardware.Config | MET | `lib/qx.ex:25,35,37,38` — all four entries present in diff |
| 4 | P1-T4: `mix compile --warnings-as-errors` clean | UNCLEAR | implementer asserts clean; cannot verify from diff alone |
| 5 | P2-T1: `Qx.Draw.SVG.Bloch` → `@moduledoc false` | MET | `lib/qx/draw/svg/bloch.ex:2` |
| 6 | P2-T2: `Qx.Draw.SVG.Charts` → `@moduledoc false` | MET | `lib/qx/draw/svg/charts.ex:2` |
| 7 | P2-T3: `Qx.Draw.SVG.Circuit` verified already `@moduledoc false`; no-op | UNMET | `lib/qx/draw/svg/circuit.ex:2` still has `@moduledoc """` (prose doc); `@moduledoc false` at line 31 belongs to the inner `CircuitDiagram` submodule, not `Qx.Draw.SVG.Circuit`. The no-op claim is incorrect — `Qx.Draw.SVG.Circuit` still publishes HexDocs pages |
| 8 | P2-T4: `Qx.Draw.Tables` → `@moduledoc false` | MET | `lib/qx/draw/tables.ex:2` |
| 9 | P2-T5: `Qx.Draw.VegaLite` → `@moduledoc false` | MET | `lib/qx/draw/vega_lite.ex:2` |
| 10 | P2-T6: `Qx.Export.OpenQASM.AST` → `@moduledoc false` | MET | `lib/qx/export/openqasm/ast.ex:2` |
| 11 | P2-T7: `Qx.Export.OpenQASM.Codegen` → `@moduledoc false` | MET | `lib/qx/export/openqasm/codegen.ex:2` |
| 12 | P2-T8: `Qx.Export.OpenQASM.Expr` → `@moduledoc false` | MET | `lib/qx/export/openqasm/expr.ex:2` |
| 13 | P2-T9: `Qx.Export.OpenQASM.Lowering` → `@moduledoc false` | MET | `lib/qx/export/openqasm/lowering.ex:2` |
| 14 | P2-T10: `Qx.Export.OpenQASM.Parser` → `@moduledoc false` | MET | `lib/qx/export/openqasm/parser.ex:2` |
| 15 | P2-T11: `Qx.Hardware.Ibm` → `@moduledoc false` | MET | `lib/qx/hardware/ibm.ex:2` |
| 16 | P2-T12: `Qx.Hardware.Portal` → `@moduledoc false` | MET | `lib/qx/hardware/portal.ex:2` |
| 17 | P2-T13: `mix compile --warnings-as-errors` clean after Phase 2 | UNCLEAR | implementer asserts 11 recompiled, format OK; cannot verify from diff |
| 18 | P3-T1: `lib/qx/validation.ex` `@moduledoc false`; `valid_qubit?`/`valid_register?` `@doc` intact | MET | `lib/qx/validation.ex:2` (`@moduledoc false`); `lib/qx/validation.ex:4` and `:42` (`@doc` blocks present) |
| 19 | P3-T2: `mix test` on validation_test — 4 doctests, 49 tests, 0 failures | UNCLEAR | implementer reports this result; cannot verify from diff alone |
| 20 | P4-T1: CHANGELOG `### Changed` docs note (surface declared, internals `@moduledoc false`, no API change, `Qx.*Error` stays public) | MET | `CHANGELOG.md:30-42` — all stated content present |
| 21 | Verification gate: compile + format + credo clean; `mix test` 242 doctests + 916 tests, 0 failures | UNCLEAR | implementer self-reports all green; not independently verifiable from diff |
| 22 | Scope discipline: no code signature or behaviour changes | MET | diff is exclusively `@moduledoc` replacements and doc-prose edits; no function definitions, specs, or call-sites altered |
| 23 | ROADMAP #23/#29 addressed (public surface declared in AGENTS.md + lib/qx.ex) | MET | AGENTS.md and lib/qx.ex changes directly resolve the "breaking change won't trip Iron Law #6" gap |
| 24 | ROADMAP #30 addressed (`Qx.Validation` → `@moduledoc false`) | MET | `lib/qx/validation.ex:2` |
| 25 | ROADMAP #24 addressed (all internal sub-modules `@moduledoc false`) | PARTIAL | 11 of 12 sub-modules done; `Qx.Draw.SVG.Circuit` (`lib/qx/draw/svg/circuit.ex`) retains its prose `@moduledoc` — the item is not fully closed |

**Summary**: 17 MET · 1 PARTIAL · 1 UNMET · 6 UNCLEAR
