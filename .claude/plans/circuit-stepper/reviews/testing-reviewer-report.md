# Test Review: feat/circuit-stepper — Circuit Stepper Tests

**Files reviewed:** `test/qx/step_test.exs`, `test/qx/simulation_steps_test.exs`, `test/qx/qx_steps_facade_test.exs`
**Implementation reviewed:** `lib/qx/step.ex`, `lib/qx/simulation.ex` (`steps/2`, `step_timeline_item/7`, `step_conditional/7`), barrier/tap handling in `lib/qx/operations.ex`

## Iron Law Violations
None found. All three files use `async: true`. No database/global state. No mocking (pure functional stream code). `@tolerance 1.0e-6` correctly declared and matches the `:c64` float32 epsilon rule.

## Issues Found

### Critical
- None.

### Warnings (HIGH)

1. **No coverage for multi-instruction `c_if` blocks** — every `c_if` fixture uses exactly one inner gate per block. `step_conditional/7` emits **one step per inner gate** and threads the gate counter across them (the W1 fix); needs a dedicated test with ≥2 inner gates, asserting per-step `operation` and that `renormalize: {:every, n}` counts through the block. *(RESOLVED in fix cycle: "multi-gate c_if blocks" describe added — 2 and 3 inner-gate cases, ops/order/condition/index + renormalize: 2 normalization.)*

2. **No test with a `:barrier` instruction in the timeline** — `Qx.Operations.barrier/2` stores `{:barrier, qubits, []}` with the full qubit list, but `apply_instruction/3` only special-cases `:barrier` at `length(qubits) == 0`; a multi-qubit barrier dispatches to the gate arms and raises `Qx.GateError`. Likely a latent PRE-EXISTING bug in `run/2` too. *(TRIAGED: confirmed pre-existing on main by direct repro — `run/2` raises today, untouched by this branch. Recorded in ROADMAP + scratchpad; fix on its own `fix/` branch.)*

3. **No empty-circuit test** — `steps/2` on a zero-instruction circuit never exercised. *(RESOLVED in fix cycle: empty-stream test + tap-on-empty-circuit test added.)*

### Suggestions (MEDIUM/LOW)

4. **MEDIUM** — `renormalize: true` never tested against `steps/2`. *(RESOLVED: acceptance test added.)*
5. **MEDIUM** — `Qx.Step.show/1` untested on `:measurement` steps despite documented collapsed-state behaviour. *(RESOLVED: show/1-on-measurement test added.)*
6. **LOW** — describe block named "steps/1" while the API is `steps/2`. *(Accepted: the describe covers default-arity calls; harmless.)*
7. **LOW** — truncation test pins exactly-4 terms via one excluded basis label; a count-based assertion would be tighter. *(Accepted.)*
8. **LOW** — facade forwards only `seed:`-checked; `backend:`/`renormalize:` passthrough untested at facade level. *(Accepted: defdelegate makes divergence impossible; engine-level tests cover both options.)*

## Flakiness Assessment
No flaky assertions identified. Stochastic tests are branch-covering; step counts are trajectory-invariant by construction; the fixed final-bit assertion encodes the teleportation protocol's deterministic guarantee.

## Verdict
**PASS with follow-up required.** Follow-ups #1, #3, #4, #5 resolved in the same cycle; #2 triaged as a pre-existing bug tracked in ROADMAP.
