# Requirements Coverage — OpenQASM Import

**Source**: `.claude/plans/openqasm-import/plan.md`
**Status: PARTIAL** — 19 MET · 1 PARTIAL · 1 UNMET · 0 UNCLEAR

| # | Requirement | Status | Evidence | Gap |
|---|-------------|--------|----------|-----|
| 1 | Round-trip: `to_qasm` output parses back to equivalent circuit | MET | `round_trip_test.exs:65–85` — Bell, GHZ-3, QFT-3, mixed-parametric assert statevector equality ≤1e-10 | — |
| 2 | Round-trip test covers Bell, GHZ-3, QFT-3, Grover-2, IBM-example with statevector equality | **PARTIAL** | All 5 fixture files exist and parse (`round_trip_test.exs:87–97`). Bell + GHZ-3 have statevector equality assertions (lines 100–114). | **Grover-2 and IBM-example only assert parse success**, not statevector equality. Plan Phase 6: "simulate both → assert state vectors equal within 1e-10" for *each* fixture. |
| 3 | `@stdgate_table` covers 23 required names (h…cswap, including CX, p/phase, u/u3, cp/cphase) | MET | `lowering.ex:29–57` | — |
| 4 | Decomposable set: tdg, sx, u1, u2, id | MET | `lowering.ex:267, 295–307` | — |
| 5 | Unsupported set: cy, ch, crx, cry, crz, cu, rxx, ryy, rzz, rzx | MET | `lowering.ex:60` | — |
| 6 | `from_qasm_function/1` returns `{:ok, %{name, arity, source}}` | MET | `codegen.ex:59–70`; `codegen_test.exs:17–35` | — |
| 7 | Generated source compiles via `Code.compile_string/1` | MET | `codegen_test.exs:53–76` | — |
| 8 | nimble_parsec ~1.4 dependency | MET | `mix.exs:47` | — |
| 9 | Single register; multi-register rejected with line of second decl | MET | `lowering.ex:140–166` | — |
| 10 | `else` rejected with refactor hint mentioning two-if pattern | MET | `parser.ex:625`; `parser_test.exs:274–284` | — |
| 11 | Param expressions: pi, +-*/, parens, sin/cos/tan/exp/ln/sqrt, unary minus, nested | MET | `expr.ex:27–62` | — |
| 12 | Out-of-scope features raise `QasmUnsupportedError` | MET | `lowering.ex:260–276`; `parser.ex:625` | — |
| 13 | `Qx.QasmParseError`/`Qx.QasmUnsupportedError` defined with line/col/snippet/hint | MET | `errors.ex:177–260` | — |
| 14 | No raw error leaks from malformed input | MET | `lowering.ex:102–105` rescue clause; parser returns typed error | — (cf. iron-law-judge WARNING about codegen path) |
| 15 | CHANGELOG under [0.6.0]: functions, gate set, decompositions, non-features, dep | MET | `CHANGELOG.md:10–34` | — |
| 16 | Version bump 0.5.2 → 0.6.0 in mix.exs | MET | `mix.exs:7` | — |
| 17 | README "Importing OpenQASM" section | MET | `README.md:429` | — |
| 18 | `@moduledoc` Importing section with subset table and decomposition list | MET | `openqasm.ex:1–43` | — |
| 19 | Iron Law 1: no String.to_atom on caller input | MET | `lowering.ex:29` whitelist; `expr.ex:51–62`; `codegen.ex:84–93` | — |
| 20 | Iron Laws 2/3/4/5: no process; no defn touched | MET | Pure function pipeline | — |
| 21 | README installation version updated to 0.6.0 | **UNMET** | — | `README.md:32, 82, 587, 681, 735` all still read `~> 0.5.2` (Phase 8 release prep didn't propagate the version bump to README installation snippets) |

## Gaps

1. **Grover-2 and IBM-example fixtures lack statevector equality assertions** — they only assert `{:ok, %QuantumCircuit{}}`. Plan Phase 6 explicitly requires statevector comparison for each fixture.
2. **README installation snippets still reference `~> 0.5.2`** — at minimum the "Add to mix.exs" code block in the Installation section needs the bump.
