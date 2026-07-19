# Elixir Review: feat/docs-sweep

## Summary
- **Status**: Approved
- **Issues Found**: 3 (0 blocker, 1 warning, 2 suggestion)

Reviewed lib/qx.ex, lib/qx/operations.ex, lib/qx/quantum_circuit.ex,
lib/qx/draw.ex, lib/qx/math.ex, lib/qx/state_init.ex,
lib/qx/export/openqasm.ex, lib/qx/patterns.ex, lib/qx/simulation.ex
(header), CHANGELOG.md. Spot-checked every new `@spec` against its
implementation and delegate target; spot-checked every `## Raises`
claim against the actual raise sites.

All 47 `@spec`s verified type-accurate: gate builders → `circuit()`/
`QuantumCircuit.t()`, `get_state`/`get_probabilities` → `Nx.Tensor.t()`,
`Draw.plot/counts/histogram` → `VegaLite.t()`, `Draw.bloch/circuit` →
`Qx.Draw.Image.t()` (type confirmed defined), `Draw.state_table` →
`Qx.Draw.StateTable.t()` (confirmed defined), `StateInit.basis_state/3`
→ `Nx.Type.t()` type param (consistent with existing
`bell_state_vector/2` usage), `Export.OpenQASM.to_qasm/2` →
`String.t()`. `number()` widening on `rx/ry/rz/phase` in both the
facade and `Qx.Operations` is consistent with the already-`number()`
`u/cp/crx/cry/crz` and matches `Validation.validate_parameter!/1`,
which doesn't discriminate integer vs float. No arity mismatches;
default-arg specs follow the codebase's existing single-arity-spec
convention (e.g. `bell_state/1`, `steps/2`) rather than introducing a
new pattern.

`## Raises` sections all traced to real raise sites: e.g. `Qx.Math.normalize/1`
→ `Qx.StateNormalizationError` on zero norm (confirmed in body);
`Operations.tap_state/tap_probabilities` → `Qx.MeasurementError` via
`final_step/2`; `Patterns.bell_state_circuit`/`ghz_state_circuit`
fallback clauses → `Qx.OptionError`/`Qx.QubitCountError` (confirmed).
`Qx.Export.OpenQASM.to_qasm/2` Raises list (`GateError`,
`ConditionalError`, `OptionError`) matches `validate_version!`,
`validate_circuit_for_version!`, and the `instruction_to_qasm`
catch-all. The stale `Qx.circuit`/`Qx.cnot` example refs are fixed
throughout (now `Qx.create_circuit`/`Qx.h`/`Qx.cx`).

## Warnings

1. **lib/qx/state_init.ex:5** — Moduledoc opener says "The public
   surface of this module is `basis_state/3`", but CHANGELOG.md:14 and
   the workspace CLAUDE.md Iron Law #6 both describe the supported
   surface as `basis_state/2,3`. Since `basis_state/3` has a default
   arg (`type \\ :c64`), `/2` is technically covered by the same spec,
   but the opener text reads as if `/2` isn't a supported call shape.
   Minor wording drift — consider "`basis_state/2,3`" to match the
   other tier openers' phrasing.

## Suggestions

1. **lib/qx/operations.ex:655-661 (`barrier/2`)** — The facade
   (`Qx.barrier/2`) documents `## Raises Qx.QubitIndexError`, but
   `Qx.Operations.barrier/2`'s own doc (unchanged by this sweep) has no
   `## Raises` section despite calling
   `Validation.validate_qubit_indices!/2`. Pre-existing gap, not
   introduced by this diff — flagging as a one-line note since the
   sweep touched every other gate doc's Raises section but skipped
   this one.

2. **lib/qx.ex:1124** (`c_if/4` spec formatting) — the multi-line
   `@spec` for the function-argument type is a little awkward
   (`(circuit() -> circuit())` wrapped across lines with unusual
   indentation). Not a correctness issue — `mix format` would leave it
   as-is since it's already valid — just a minor readability nit,
   pre-existing (not touched by this sweep).

No blockers. The sweep is accurately mechanical: no behavior changes
observed, and the added specs/docs match their implementations.
