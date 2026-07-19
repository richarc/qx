# Plan: First-class circuit stepper (`Qx.steps/1` + `%Qx.Step{}`)

**Slug:** circuit-stepper
**Branch:** `feat/circuit-stepper` (create from `main` before `/phx:work`)
**Status:** DONE (merged to main as 403db05, 2026-07-03)
**Depth:** standard
**Complexity:** 7 (new domain concept +3, crosses Simulation/Operations/facade +3, public API +3, follows existing reduce pattern -2)
**Design:** `spec/unified-circuit-stepper-design.md` (amended 2026-07-03; all API decisions settled there)
**ROADMAP:** v0.10 stepper item (tick in the squash-merge commit)
**Research:** `research/hex-library-researcher-report.md` — no new deps; stdlib `Stream` + explicit `:rand` state threading

## Summary

Add `Qx.steps/1,2`: a lazy `Stream` of `%Qx.Step{}` structs, one per
executed operation, built over the timeline reduce
(`create_instruction_timeline/1` + `process_timeline_item/6` in
`lib/qx/simulation.ex`). The timeline substrate is the point: mid-circuit
measurement and `c_if` work, so teleportation is steppable. Circuits with
measurements yield one seeded stochastic trajectory per materialisation.
Display comes from an `Inspect` impl on `%Qx.Step{}` plus `Qx.Step.show/1`
(the `Register.show_state/1` display map, rehomed over `Qx.Format`).

Additive public API (`Qx.Step`, `Qx.steps`): CHANGELOG `### Added`, no
version bump at merge (bump happens at v0.10 release prep). TDD per phase:
tests written first, must fail, then implement.

## Phase 1: `Qx.Step` struct and display

- [x] Write failing tests `test/qx/step_test.exs`: struct fields and
      defaults; `Qx.Step.show/1` returns
      `%{state: dirac, amplitudes: [...], probabilities: [...]}` for a Bell
      state (match `Register.show_state/1`'s shape exactly); `inspect/1`
      renders index, operation, Dirac string, and `cbits` when non-empty;
      tolerances 1.0e-6 (Iron Law #8)
- [x] Create `lib/qx/step.ex`: `defstruct [:kind, :operation, :index,
      :state, :probabilities, :classical_bits, :condition]`; `@type t`;
      `kind :: :gate | :measurement | :conditional`;
      `condition :: nil | {cbit, value, :taken | :not_taken}`; full
      `@moduledoc`/`@doc` (style contract: `anti-ai-writing-style.md`)
- [x] `Qx.Step.show/1`: lift the display-map assembly from
      `Qx.Register.show_state/1` (`register.ex:798`) onto `Qx.Format`
      (`basis_state/2`, `dirac_notation/1`, `complex/2`); works on a
      `%Qx.Step{}`; `Register.show_state/1` body unchanged (calc-mode
      demotion handles it later)
- [x] `defimpl Inspect, for: Qx.Step`: single line
      `#Qx.Step<{index}: {op} {dirac}  cbits: [...]>`, condition flag for
      conditional steps, measurement arrow for measurement steps; truncate
      Dirac to a sane width for large n
- [x] Verify: `mix compile --warnings-as-errors && mix format
      --check-formatted && mix credo --strict && mix test`

## Phase 2: engine stream (`Qx.Simulation.steps/2`)

- [x] Write failing tests `test/qx/simulation_steps_test.exs`:
  - unitary circuit: `steps/1` yields one step per gate; step k's `state`
    equals `get_state/1` of the k-gate prefix (1.0e-6); `probabilities`
    consistent with `Math.probabilities(state)`
  - laziness: `Stream` returned; `Enum.take(steps, 1)` does not execute
    the whole circuit (probe via a tap-like counter or timeline length)
  - teleportation (README circuit): full trajectory has the right step
    count; measurement steps populate `classical_bits`; conditional inner
    gates carry `{cbit, value, :taken}`; a not-taken `c_if` yields one
    `:conditional` step flagged `:not_taken`; final teleported qubit
    consistent with the classical bits
  - seed: same `seed:` gives an identical trajectory (states and cbits);
    stream re-materialisation without seed is allowed to differ; seeding
    does NOT mutate the caller's process `:rand` state (assert
    `:rand.export_seed/0` unchanged)
  - every yielded state stays normalized (the `@assert_norm` test-env
    guard fires on violation)
  - `Qx.MeasurementError`/`Qx.GateError` never replaced by raw errors
    (Iron Law #7)
- [x] Refactor `lib/qx/simulation.ex`: thread explicit RNG state.
      `perform_single_measurement/3` gains a sibling taking and returning
      `:rand` state (`:rand.uniform_s/1`); `execute_single_shot/2` and the
      new stream share one step function; `run/2` behaviour and results
      unchanged (existing 952 tests + 242 doctests stay green untouched)
- [x] Add `Qx.Simulation.steps(circuit, opts)`: `Stream.transform/3` over
      `create_instruction_timeline/1`, accumulator
      `{state, cbits, count, rand_state}`; emits `%Qx.Step{}` per gate,
      per measurement, per conditional inner gate (not-taken block emits
      one flagged step). Options: `seed:` (`:rand.seed_s(:exsss, seed)`;
      default `:rand.seed_s(:exsss)` from entropy), `backend:` (same
      pass-through as `run/2`), `renormalize:` (reuse
      `resolve_renormalize/1` + `apply_gate_step/5` so the every-n cadence
      counts c_if inner gates identically; default `false`)
- [x] Iron Law check: no new host-side 2^n loops (#5; reuse existing
      collapse path, its host loop is pre-existing and scheduled for
      v0.11), correct on `Nx.BinaryBackend` (#4), no processes (#2)
- [x] Verify gate (as Phase 1) and offer `mix bench` (simulation.ex
      execution path touched)

## Phase 3: public facade and taps

- [x] Write failing tests: `Qx.steps/1,2` delegate exists and streams; a
      doctest-friendly example; existing
      `test/qx/operations_tap_test.exs` must stay green unchanged (tap
      contract is frozen: shipped in 24cd1cf)
- [x] `lib/qx.ex`: `defdelegate steps(circuit, opts \\ []), to: Simulation`
      with facade docs: teleportation walk-through, single-trajectory +
      `seed:` semantics, the per-trajectory vs `run/2`-ensemble caveat,
      and the measure_x/y Z-aligned mid-circuit visibility note (design §4)
- [x] Reimplement `Operations.tap_state/2` and `tap_probabilities/2`
      internals on the stepper (guard: raise `Qx.MeasurementError` on
      measured/conditional prefixes exactly as today, then take the final
      step's state/probabilities). No user-visible change; single
      execution path. Scratchpad records why trajectory-sampling taps were
      rejected
- [x] Add `Qx.Step` and `Qx.steps` to the `lib/qx.ex` `## Modules` list
      and the Iron Law #6 declared-public surface in `AGENTS.md`/CLAUDE.md
- [x] Verify gate

## Phase 4: docs and release prep

- [x] CHANGELOG `### Added` under `[Unreleased]`: `Qx.steps/1,2`,
      `%Qx.Step{}`, `Qx.Step.show/1`, seeded trajectories; note the taps
      now share the stepper's execution path
- [x] README: a "Step through a circuit" section (teleportation example;
      style contract applies)
- [x] `spec/unified-circuit-stepper-design.md`: flip Status to
      implemented, pointing here
- [x] Full verify gate + `mix docs` build clean
- [x] Merge gate: `/phx:review` must PASS (or all findings triaged);
      squash-merge ticks the ROADMAP stepper item (PASS ×3 agents;
      merged to main as 403db05 with the ROADMAP tick, 2026-07-03)

## Risks

- **RNG threading regression**: switching `execute_single_shot/2` to
  explicit rand state could subtly change `run/2` sampling. Mitigation:
  run-path results are distribution-checked by existing tests; keep the
  refactor mechanical (same call order, same algorithm family).
- **Renorm cadence drift**: the W1 fix (inner c_if gates advance the gate
  counter) must hold in the stream. Covered by reusing
  `apply_gate_step/5` and a dedicated test.
- **Probabilities per step cost O(2^n)/step**: accepted for an inspection
  API at teaching scale; scratchpad records the lazy-compute alternative
  if it ever matters.

## Verification (every phase)

```
mix compile --warnings-as-errors && mix format --check-formatted \
  && mix credo --strict && mix test
```

TDD: new tests written and failing before implementation; existing tests
never modified (hook-enforced; tap tests are the frozen contract).
