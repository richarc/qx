# Iron Law Judge — feat/docs-sweep

Scope: pure-Elixir library, no Phoenix/Ecto/LiveView/Oban — only the
Qx-tailored Iron Laws (#6 breaking-change discipline, #7 typed raises,
docs-warning discipline) apply. Reviewed lib/qx.ex, operations.ex,
quantum_circuit.ex, draw.ex, math.ex, state_init.ex,
export/openqasm.ex, patterns.ex, simulation.ex, simulation_result.ex,
step.ex, CHANGELOG.md.

## Summary
- Files scanned: 12
- Iron Laws checked: #6, #7, docs-warning discipline (3 of 22 general
  laws — the rest don't apply to this repo/sweep)
- Violations found: 0 blockers, 0 warnings-that-block, 1 suggestion

## Findings

### [#6 non-breaking discipline] — PASS, verified
- `float()` → `number()` widening confirmed complete and consistent:
  `rx/ry/rz/phase` in `lib/qx/operations.ex` (lines 207, 234, 261, 288)
  now all read `number()`, matching the sibling `u/cp/crx/cry/crz`
  family (already `number()`). No stray `float()` spec remains on any
  angle/phase parameter. Grep of `float()` across `lib/` turns up only
  unrelated, correctly-typed sites (`probability/2` return, OpenQASM
  parser/eval internals, `Step.basis_terms/1`, `Validation` internals,
  `Simulation` internals) — none narrowed.
- `Qx.SimulationResult.filter_by_probability/2` spec is `number()` in
  code, matching the CHANGELOG's stated `float() → number()` widening.
- No public function signature or return type was narrowed anywhere in
  the diff; all changes are additive (@spec added where absent, @doc
  sections added, moduledoc prose only).
- CHANGELOG `[Unreleased]` has both a `### Changed` entry (angle-spec
  widening, `filter_by_probability` widening, `Qx.Behaviours.QuantumState`
  demotion, build-time parameter validation) and a `### Documentation`
  entry (the 47/55/18 sweep + tier openers + tap-warning copy-up +
  OpenQASM doc-rot fix) — present and accurate against the diff. No
  version bump present, correctly, since the sweep is additive/docs-only.

### [#7 typed raises accuracy] — PASS, verified
- Cross-checked a sample of the 18 new `## Raises` sections against
  actual `raise` call sites: `Qx.StateNormalizationError` (math.ex:82,
  validation.ex:78), `Qx.MissingDependencyError` (draw.ex:256),
  `Qx.BasisError`, `Qx.GateError`/`Qx.ConditionalError`/`Qx.OptionError`
  (openqasm.ex), `Qx.MeasurementError` (simulation.ex) — all exist in
  `lib/qx/errors.ex` and are raised on the documented path.
  `Qx.Operations.cswap/4`, `swap/3`, `iswap/3`, `cp/4`, `cy/3`,
  `crx/4`, `cry/4`, `crz/4`, `measure_x/3`, `measure_y/3`,
  `tap_state/2`, `tap_probabilities/2` raises all trace to their
  documented error types via `Validation`/`QuantumCircuit`/`Simulation`.
- Confirmed the deferred finding is honored: `Qx.superposition/1`
  (lib/qx.ex:1624-1643, delegating to `Qx.Patterns.superposition_circuit/1`)
  has no `## Raises` section, matching the stated deferral (raw
  `FunctionClauseError` leak not yet fixed/documented).
- `sweep #3` fallback clauses (`Qx.Operations.c_if/4`,
  `Qx.Patterns.bell_state_circuit/1`, `Qx.Patterns.ghz_state_circuit/1`)
  correctly route former `FunctionClauseError` leaks to typed errors
  and match their new/updated `## Raises` docs.

### Docs-warning / doc-prose accuracy — PASS on sampled refs
- No doc-prose function reference found pointing to a non-existent
  function in the sampled files (`Qx.Patterns` "See also", `Qx.Math`
  deprecation replacements, `Qx.StateInit` replacements all resolve).

## Suggestion (non-blocking)

### [CHANGELOG accuracy] Tier-2 moduledoc-opener claim slightly overbroad
- **File**: `CHANGELOG.md` (Documentation entry, "Every tier-2 module
  moduledoc now opens with the §3 tier marker...")
- **Files**: `lib/qx/math.ex:1-12`, `lib/qx/state_init.ex:1-15`
- **Issue**: `Qx.Math` and `Qx.StateInit` (both in the changed-files
  list) do not open with the "Utility module: reached from `Qx.*`..."
  tier-2 marker used by `Operations`, `Patterns`, `Draw`, `Simulation`,
  `OpenQASM`. They instead retain their pre-existing "public surface is
  X; the rest is deprecated" framing (consistent with the v0.11 tier
  trim). This is very likely a deliberate, spec-correct deviation (same
  category as the tier-1 struct opener deviation already called out in
  the task), but the CHANGELOG's "every tier-2 module" wording doesn't
  carve out the exception the way it does for the tier-1 structs.
- **Confidence**: REVIEW
- **Fix**: Either add the tier-2 marker line to `Math`/`StateInit`
  alongside their existing trimmed-surface framing, or soften the
  CHANGELOG wording to note these two are intentionally exempted
  (deprecated-heavy, trimmed-surface modules).
