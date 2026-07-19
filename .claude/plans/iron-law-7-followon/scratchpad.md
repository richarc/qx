# Scratchpad — iron-law-7-followon

## Decisions
- **Param error type:** new `Qx.ParameterError` (carries `:value`). Considered and rejected:
  reusing `Qx.GateError {:invalid_parameter, gate, param}` (would need to thread the gate atom
  through 5 call sites) and a bare-message `Qx.GateError` (no gate context). User chose the
  dedicated type for descriptiveness / one-error-per-concept symmetry.

## Latent gaps discovered (out of scope here — candidates for ROADMAP)
- `validate_qubits_different!/1` and `validate_state_shape!/2` have **no `lib/` callers**. The
  distinctness check in particular looks like it *should* guard multi-qubit gates but doesn't —
  `Qx.QuantumCircuit.add_two_qubit_gate` raises its own `{:duplicate, …}` instead. Worth a
  ROADMAP line: "wire `validate_qubits_different!/1` into the multi-qubit op path, or delete it."

## Discovered during /phx:work (out of scope — for ROADMAP/next plan)
- **`lib/qx.ex` also documented `ArgumentError` for the same gates** (rx/ry/rz delegators at
  305/338/355/372 + `u` at 570). These ARE the public surface and were updated in this plan —
  the Phase 3 grep-confirm step caught them (plan text said only operations.ex). Resolved here.
- **`Qx.Operations.u` still leaks `FunctionClauseError` for an out-of-range qubit**
  (operations.ex:290 doc is accurate — the guard `when qubit >= 0 and qubit < num_qubits`
  fails with no fallback clause, instead of routing through `validate_qubit_index!`). Iron Law #7
  leak, pre-existing, NOT a parameter error → out of scope. Candidate for the broader
  `ArgumentError`/`FunctionClauseError` → typed sweep already on the v0.8.1 roadmap.
- **`register.ex` (11 raw `ArgumentError` sites) + `qubit.ex:290`** — already the separate
  v0.8.1 roadmap line "`ArgumentError` → typed `Qx.*Error` sweep across the rest of the public
  surface (audit: arch HIGH cluster)". Untouched here by design. Note: register.ex:569/704
  ("All qubit indices must be different") and :510/538/657/680/746 (distinctness) are exactly the
  cases `validate_qubits_different!/1` was built for — wiring that helper in would resolve several
  at once.

## Open questions
- (none blocking)
