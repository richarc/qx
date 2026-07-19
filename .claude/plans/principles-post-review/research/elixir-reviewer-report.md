# Elixir Reviewer Report — docs/principles-post-review

Scope: docs-only diff (spec/api-design-principles.md §3/§6/§8/§9, five moduledoc
tier openers, AGENTS.md Iron Law #6 + STEP 2). Reviewed for accuracy against
`lib/`, not style.

## Summary

- **Status**: Approved
- **Issues Found**: 0 (all claims verified against code)

## Verification detail (all PASS)

1. **§6 naming-family rows** — every member exists with the claimed shape:
   - `run/2` → `lib/qx/simulation.ex:106`, `@spec run(...) :: simulation_result()`
     returning `%SimulationResult{}` (confirmed via `Qx.run/2` delegate at
     `lib/qx.ex:1267-1275`).
   - `steps/2` → `lib/qx/simulation.ex:337`, `@spec steps(...) :: Enumerable.t()`,
     built with `Stream.transform/3` — genuinely lazy.
   - `barrier/2` → `lib/qx/operations.ex:689-697` accepts `%Range{}` (converted to
     list) or a raw list, matching the "list or range" claim.
   - `c_if/4` → `lib/qx/operations.ex:837+`, single family member, matches doc.
   - `cx_chain/2` → `lib/qx/patterns.ex:293`, matches `*_chain` row.
   - `bell_pair/4` (`lib/qx/patterns.ex:395-428`) and `ghz/2`
     (`lib/qx/patterns.ex:333-346`) are appenders; `bell_state_circuit/1` and
     `ghz_state_circuit/1` (`lib/qx/patterns.ex:434-458`, `@doc false`) are thin
     wrappers over them, exercised by byte-identical invariant tests
     (`test/qx/patterns_test.exs:625-638`).
   - `sdg`/`tdg` both exist as native gates (`lib/qx/operations.ex:378,426`),
     matching the updated `*dg` row.

2. **Documented exceptions** — all three match code exactly:
   - `Qx.version/0` (`lib/qx.ex:1818-1823`) uses `Application.spec(:qx, :vsn)`.
   - `Qx.measure_z/3` (`lib/qx.ex:807-808`, delegate) and `Qx.Operations.measure_z/3`
     (`lib/qx/operations.ex:734-736`) are byte-identical in body to
     `measure/3` (`lib/qx/operations.ex:716-718`) — both call
     `QuantumCircuit.add_measurement(circuit, qubit, classical_bit)`.
   - `Qx.get_state/2` (`lib/qx.ex:1306-1309`) delegates to
     `Qx.Simulation.get_state/2` (`lib/qx/simulation.ex:227-243`), which raises
     `Qx.MeasurementError` with message "...Use run/2 instead." when the circuit
     has measurements or conditionals — matches "steers to run/2" claim exactly.

3. **Tier snapshot / moduledoc openers** — grepped `lib/` for both opener
   strings; every module named in the AGENTS.md Iron Law #6 snapshot and in
   §3's tier lists carries the claimed opener:
   - Tier 1 structs: `simulation_result.ex`, `step.ex`, `draw/image.ex`,
     `draw/state_table.ex`, `quantum_circuit.ex` all open "Tier 1: a core Qx
     type" (or the QuantumCircuit variant, same phrase).
   - Tier 2: `operations.ex`, `simulation.ex`, `patterns.ex`, `state_init.ex`,
     `math.ex`, `draw.ex`, `hardware.ex`, `hardware/config.ex`,
     `export/openqasm.ex` all open "Utility module: …".
   - No module in the snapshot lacks an opener; no extra/missing entries found.

4. **No stale flat-list in AGENTS.md** — confirmed only one tier-related
   paragraph (Iron Law #6) plus the STEP 2 complexity-table row reference it;
   no leftover bullet-list "public surface" enumeration exists elsewhere in
   the file.

5. **Adjudication notes (§9 #6/#7/#8)** — all state true facts:
   - #6 `tdg`: confirmed native (own dispatch, own drawing glyph "T†" per
     `lib/qx/operations.ex` doc, not re-verified line-by-line for QASM
     round-trip but gate + dispatch existence confirmed).
   - #7: AGENTS.md Iron Law #6 does define the surface via moduledoc tier
     annotations, with an explicitly-labelled "informative" snapshot —
     matches the diff description.
   - #8: appenders `bell_pair/4`/`ghz/2` shipped, creators reframed as
     byte-identical wrappers (test-verified above), and `superposition/1`
     is `@deprecated` in `lib/qx.ex:1800` ("Use `Qx.create_circuit(n) |>
     Qx.h_all()`. Will be removed in Qx 1.0") — all three sub-claims true.

## Notes (non-blocking, informative only)

- `Qx.Patterns` moduledoc (§3 tier-2 opener) still documents
  `superposition_circuit/1` without a deprecation notice at the
  `Qx.Patterns` level (only the `Qx.superposition/1` facade carries
  `@deprecated`) — this is pre-existing and outside this diff's scope
  (the diff didn't touch `patterns.ex` itself), not a doc-accuracy defect
  in the reviewed changes.

No code-behavior changes were present in this diff (docs-only), and no
inaccuracies were found in the reviewed documentation against the current
code.
