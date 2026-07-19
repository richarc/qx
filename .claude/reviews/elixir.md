# Code Review: feat/circuit-stepper (git diff main...HEAD)

## Summary
- **Status**: ⚠️ Changes Requested
- **Issues Found**: 5

## Critical Issues

None. RNG threading (`:rand.uniform_s/1` via explicit `rand_state`) correctly
replaces process-dict `:rand.uniform/0` in the measurement path; `seed_rand/1`
is invoked once per `Stream.transform` start-function call (i.e. once per
materialisation), which matches the documented "fresh entropy per
materialisation" / "seeding never touches the caller's process `:rand` state"
contract, and both are covered by `simulation_steps_test.exs` ("seeding does
not mutate the caller's process :rand state", "the same seed gives an
identical trajectory"). No behavioural regression found in `run/2`: the
non-conditional path's `perform_measurements/3` is untouched (still uses
global `:rand.uniform/0`), and the conditional path's `execute_single_shot/2`
discards emissions and threads count/rand exactly as before, just explicitly
instead of via the process dictionary.

## Warnings

1. **`lib/qx/simulation.ex:376-389` (`to_step/2`) — `tap_state/2` and
   `tap_probabilities/2` now pay for every step's probability vector, not
   just the one they need.**
   `Operations.final_step/2` (`lib/qx/operations.ex:950-960`) drives
   `tap_state/2`/`tap_probabilities/2` through `Simulation.steps/2 |>
   Enum.at(-1)`. Every emitted `%Qx.Step{}` computes `Math.probabilities(state)`
   in `to_step/2` regardless of whether the caller wants the last step. Before
   this refactor these taps executed the circuit once (`execute_circuit/2`)
   and computed the probability vector once; now they pay for one
   `Math.probabilities/1` call — O(2^n) — per *gate*, not once for the whole
   circuit. For a long circuit at the qubit-count ceiling this is a
   meaningful, silent regression on a function whose docs already warn "use
   sparingly in performance-critical code" — the warning is now understating
   the cost. Consider a stepping variant that defers/skips probability
   computation until `Step.show/1` or the `Inspect` impl actually need it
   (e.g. lazily compute `probabilities` from `state` only when accessed,
   or add an internal opt to `steps/2` to skip probability computation for
   this internal consumer).

2. **`lib/qx/step.ex:114-115,146-155` (`@prob_threshold 1.0e-6`) — the Dirac
   truncation's "no significant terms" fallback silently stops truncating on
   large equal-superposition circuits.**
   `dirac/1`'s `Enum.split({[], _})` branch falls back to
   `Format.dirac_notation(terms)` — the *full*, untruncated term list — when
   no term clears `@prob_threshold`. Qx supports up to 20 qubits; a uniform
   superposition over `2^20 ≈ 1.05e6` basis states gives each term
   probability `≈9.5e-7`, which is *below* `@prob_threshold = 1.0e-6`. At that
   qubit count `inspect/1` (and any debug `IO.inspect` in user code) would
   print a ~1-million-term Dirac string instead of the intended truncated
   summary — the opposite of the feature's purpose. Either scale
   `@prob_threshold` relative to `2^num_qubits`, or make the empty-`significant`
   fallback also cap at `@max_dirac_terms` (e.g. take the first N terms by
   probability) instead of dumping everything.

## Suggestions

1. **`lib/qx/operations.ex:959` — `Enum.at(-1)` on a `Stream` forces a full
   list materialisation to find the last element.**
   `Enum.fetch/2` with a negative index has no way to slice a `Stream`, so it
   must convert the whole enumerable to a list first. `Enum.reduce(stream,
   nil, fn step, _ -> step end)` (or `List.last(Enum.to_list(stream))`, which
   is no better, so prefer the reduce) walks the stream once without building
   an intermediate list of every step, which matters more now that each step
   carries a state tensor + probability tensor.

2. **`lib/qx/simulation.ex:812-848` (`step_conditional/7`) — `Enum.reduce/3`
   with an explicit accumulator list + final `Enum.reverse/1`** works but a
   named-clause pair (`when Enum.at(cbits, cbit) == value` — not expressible
   as a guard since it calls a function, so the `if` here is fine)
   is acceptable as-is; no action needed, noted only because the surrounding
   code otherwise favors pattern matching in function heads. No change
   requested.

3. **`lib/qx/step.ex:41` — `@enforce_keys []`** declares no required keys even
   though `kind`, `operation`, `index`, and `state` are meaningless as `nil`
   (confirmed by `step_test.exs`'s "has the documented fields with nil
   defaults" test, which asserts this is intentional for whitebox testing).
   Since `%Qx.Step{}` is constructed exclusively inside `Qx.Simulation` — never
   by end users per the module doc ("One executed operation from
   `Qx.steps/2`") — this is fine; flagged only as a note in case future public
   construction is intended, in which case `@enforce_keys [:kind, :operation,
   :index, :state]` would catch misuse earlier.

## Verified, no issue

- `Qx.steps/2` facade delegation (`lib/qx.ex:1073-1074`) matches
  `Qx.Simulation.steps/2`'s arity/opts and is confirmed identical output via
  `qx_steps_facade_test.exs`.
- Typed-error contract holds: `steps/2` raises only `Qx.GateError` (unsupported
  gate) and `Qx.OptionError` (bad `:renormalize`), no raw `Nx`/`ArgumentError`
  leakage, confirmed by `simulation_steps_test.exs`.
- `Stream.transform/4` accumulator shape `{state, cbits, count, step_index,
  rand}` is threaded correctly through `step_timeline_item/7` /
  `step_conditional/7`; `step_index + length(emissions)` correctly advances
  past multi-emission conditional blocks.
- `final_step/2`'s frozen-contract raise (measured/conditional prefix) is
  pre-checked before touching `Simulation.steps/2`, preserving the exact
  original `Qx.MeasurementError` message text.

## Overall: PASS (with the two warnings above recommended for triage before
merge — neither blocks correctness, both are pre-existing-pattern-consistent
but worth a follow-up plan item).
