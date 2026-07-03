# Design note: unify circuit/calc modes with a step-through stepper

**Status:** Implemented (2026-07-03) — `Qx.steps/1,2` + `%Qx.Step{}`, plan
`.claude/plans/circuit-stepper/plan.md`. Calc-mode demotion (the "still
open" question below) stays open; it's a separate v0.10 item.
**Date:** 2026-06-29. Amended 2026-07-03 after review: corrected the
`tap_state` premise (it is broken, worse than inefficient) and added the
mid-circuit measurement section, which retargets the stepper at the timeline
reduce and drops the `trace:` option.
**Question:** Qx exposes two user-facing models today, "circuit mode" and
"calculation mode". Would a single circuit API that can step through one
operation at a time (the inspect-after-each-gate feel of calc mode) be better
for developer experience? What do other simulators do?

## Background: the two modes today

| Mode | Modules | Shape | Eager/lazy |
| ---- | ------- | ----- | ---------- |
| Circuit | `Qx.QuantumCircuit`, `Qx.Operations`, the `Qx.*` facade, `Qx.Simulation` | `create_circuit -> Qx.h(qc, i) -> Qx.run/get_state` | Lazy: records instructions, runs the whole list |
| Calc | `Qx.Register` (multi-qubit engine), `Qx.Qubit` (single-qubit wrapper) | `Qx.Register.h(register, i)` returns the new register | Eager: applies a gate to a state and returns it |

Four facts make Qx an unusually clean candidate for unification:

1. **Both modes share one engine.** `Qx.Register` and `Qx.Simulation` apply the
   same `Qx.Calc` / `Qx.Gates` / `Qx.Math` kernels. Calc threads the state
   eagerly; circuit records instructions then `Enum.reduce`s over them applying
   those same kernels. The split is two APIs over one engine, not two engines.
2. **The engine is already a stepper.** `Qx.Simulation.execute_circuit/2` is
   `Enum.reduce(instructions, &apply_gate_step/...)`, and `apply_gate_step`
   already returns `{new_state, count}`. A step API mostly exposes what exists.
3. **A step affordance already half-exists, and it is broken.** `Qx.tap_state/2`
   and `tap_probabilities/2` claim to show the state of the circuit-so-far
   mid-pipeline. They actually read `QuantumCircuit.get_state/1`, which returns
   the stored *initial* state field (`quantum_circuit.ex:198`); circuit mode is
   lazy, so no instruction has been applied when the tap fires. Verified
   2026-07-03: `create_circuit(1, 0) |> h(0) |> tap_state(...)` prints
   `[1.0+0.0i, 0.0+0.0i]`, contradicting the tap's own doc examples. (An earlier
   draft of this note called the taps an O(gates^2) prefix re-run; they never
   re-ran anything.) A real stepper threads the state once and fixes this
   outright.
4. **Calc mode is already secondary.** 5 of 6 tutorials use circuit mode;
   `Qx.Register` / `Qx.Qubit` barely appear, yet they are most of the
   "Which `h` am I calling?" cognitive load (the four `h` entry points:
   `Qx.Qubit.h/1`, `Qx.Register.h/2`, `Qx.Operations.h/2`, `Qx.h/2`).

## What other simulators do

No single industry consensus exists, but the tools that prioritise debugging
and teaching converge on one object that offers both batch run and incremental
stepping. The deliberate two-API split appears only where the two paths have
genuinely different performance profiles.

| Simulator | Step-through / inspect intermediate state | Unified? |
| --------- | ----------------------------------------- | -------- |
| Cirq | `Simulator.simulate_moment_steps()`, a first-class iterator that yields the state vector per moment | Yes: one `Simulator`, two methods |
| QuTiP `qutip-qip` | `CircuitSimulator.step()` runs one gate and exposes `.state`; `precompute_unitary=true` for batch | Yes: closest match to the proposal |
| Q# | `DumpMachine()` / `DumpRegister()` anytime, plus an IDE step debugger | n/a (eager, no circuit object) |
| Qiskit | eager `Statevector.evolve()` vs lazy `QuantumCircuit` + `AerSimulator`; `save_statevector` snapshots need a full re-run | No (split; unified higher up via Sampler/Estimator) |
| PennyLane | `qml.Snapshot` / `qml.snapshots` (re-runs per snapshot on some devices), plus a `breakpoint()` debugger | Partial |
| Yao.jl | a "block" is both a circuit and an applicable op: `apply!(reg, block)`, `reg \|> X \|> Y` | Yes (true unification) |
| stim | `TableauSimulator` (interactive, one op at a time) vs `Circuit` (batch sampler) | No, deliberately |
| ProjectQ, Braket Local | eager-looking / batch; little mid-circuit inspection | n/a |

The most relevant precedents for the proposal are **QuTiP's `CircuitSimulator.step()`**
(a single circuit simulator class with a `step()` method and a batch flag) and
**Cirq's `simulate_moment_steps()`** (a first-class stepper on the same simulator
that runs batches). Both treat stepping as a first-class method on the circuit
runner, not a separate mode.

## Recommendation

Adopt the Cirq / QuTiP shape: keep one circuit API, add a first-class efficient
stepper, and demote calc mode.

1. **One front door stays:** `create_circuit -> Qx.h(qc, i) -> Qx.run / get_state`.
2. **Add a first-class stepper** that threads the state once and yields after
   each operation. Sketch:

   ```elixir
   Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
   |> Qx.steps()    # lazy Stream of step structs (see below)
   |> Enum.each(&IO.inspect/1)
   ```

   A thin lazy stream over the engine's existing reduce, so it threads the
   state once. Which reduce it wraps matters; see the mid-circuit measurement
   section below. It gives the calc-mode feel (inspect after each operation)
   inside circuit mode, and re-implements `tap_state` / `tap_probabilities`
   (broken today, see fact 3) on a working substrate. An earlier draft also
   floated `Qx.run(qc, trace: true)`; that option is dropped, see below.
3. **Reposition calc mode.** Make `Qx.Register` / `Qx.Qubit` an internal engine
   (`@moduledoc false`), or a clearly-demoted "advanced: operate on a raw state
   vector directly" escape hatch (the niche Qiskit's `Statevector.evolve` fills).
   Either way, stop presenting it as a co-equal mode. That is what removes the
   "Which `h`?" confusion.

The payoff lands on the Algorithms & Learning milestone and the educational
positioning: a "watch the state evolve gate by gate" experience is a teaching
differentiator, and it is what the learning-focused simulators invested in.

## Mid-circuit measurement and `c_if`: the stepper must wrap the timeline reduce

*(Added 2026-07-03. The original draft never mentioned measurement or `c_if`,
and its proposed substrate cannot execute them.)*

The sketch above wraps `execute_circuit/2`. That is the wrong reduce. The
engine has two execution paths (`simulation.ex`):

1. `run_without_conditionals` -> `execute_circuit/2`: pure unitary evolution.
   It treats `:measure` instructions as identity no-ops
   (`simulation.ex:427-428`, `454-455`) and raises `Qx.GateError` on a
   `{:c_if, ...}` instruction (the tuple pattern-matches as a two-qubit gate
   and falls through the dispatch).
2. `run_with_conditionals` -> `execute_single_shot/2`: a per-shot reduce over
   a timeline of `{:instruction, ...} | {:measurement, ...} | {:conditional, ...}`
   items, threading `{state, classical_bits, count}`, with real stochastic
   collapse in `perform_single_measurement/3`.

A stepper over path 1 either crashes on teleportation or silently yields
"states" in which the Bell measurement never collapsed anything. And
teleportation is the flagship: the README sells `c_if` with it, and it is the
circuit every quantum course wants to step through. `get_state/2` and
`get_probabilities/2` raise `Qx.MeasurementError` on such circuits today; if
`Qx.steps/1` inherits that precedent it excludes its own best use case.

So build the stepper over path 2's timeline reduce. `process_timeline_item/6`
already handles all three item kinds and threads exactly the tuple a step
should yield; unitary-only circuits degenerate to path 1 behaviour for free.
That choice forces four decisions:

1. **A step-through of a measuring circuit is one stochastic trajectory.**
   Each materialisation of the stream samples fresh outcomes, so two
   `Enum.to_list(Qx.steps(qc))` calls can differ, and one trajectory differs
   from the 1024-shot ensemble `run/2` reports. Cirq's
   `simulate_moment_steps()` has the same semantics, so there is precedent.
   Document it, and add a `seed:` option (`:rand.seed/2` is process-local) so
   teaching material reproduces.
2. **The step struct needs more than `%{gate, state, probabilities}`.**
   Teleportation needs `classical_bits` (to show the Bell outcomes) and a
   step kind (`:gate | :measurement | :conditional`), plus a taken/not-taken
   flag on conditional steps. Granularity: the gate counter already counts
   gates inside a `c_if` block individually (the W1 fix,
   `simulation.ex:702-715`), so yield one step per inner gate, annotated with
   its condition, rather than one opaque step per block.
3. **`run(qc, trace: true)` is ill-defined for conditional circuits** and is
   dropped from this proposal. With 1024 shots there are 1024 distinct
   trajectories; which one is "the trace"? The conditional path already
   returns the last shot's state as "representative"
   (`simulation.ex:178-181`), a documented wart, and `trace: true` would
   compound it. Ship only `Qx.steps/1`, explicitly single-trajectory.
4. **Basis-measurement visibility.** `measure_x/3` and `measure_y/3` lower to
   basis-change gates plus a Z-measure, and the post-measurement state
   deliberately stays Z-aligned (documented in `operations.ex:648-653`).
   Harmless at end-of-circuit; a stepper puts that state on screen
   mid-circuit, so students will see `|1⟩` where the math says `|−⟩`. Needs a
   doc note on the step struct, or a collapse-and-rotate-back treatment for
   the lowered basis measurements.

## Display: what replaces `show_state`

*(Added 2026-07-03, second review pass.)*

Calc mode's inspection entry points are `Qx.Qubit.show_state/1` and
`Qx.Register.show_state/1`: a display map with a Dirac string
(`"0.707|00⟩ + 0.707|11⟩"`), `:amplitudes`, and `:probabilities`. Demoting
calc mode removes those entry points, so the stepper needs a display story of
its own. The machinery survives untouched: all the actual formatting (Dirac
notation, basis labels, complex rendering) lives in `Qx.Format`, which is
already internal and mode-neutral; `Register.show_state/1` is a thin
assembler over it (`register.ex:798`).

The step struct itself stays raw data: `kind`, `operation`, `index`, `state`
(the same `c64` tensor `Qx.get_state/1` returns), `probabilities`,
`classical_bits`, and a `condition` field on conditional steps. Display
layers on top, two ways:

1. **An `Inspect` implementation for `%Qx.Step{}`.** The sketch in the
   recommendation is `Qx.steps() |> Enum.each(&IO.inspect/1)`, so inspecting
   a step must already be the readable form. Roughly:

   ```
   #Qx.Step<4: measure q0 → c0  0.707|010⟩ + 0.707|110⟩ ⇒ |110⟩  cbits: [1,0,0]>
   #Qx.Step<6: c_if(c1==1) x(2) taken  |111⟩  cbits: [1,1,0]>
   ```

2. **`Qx.Step.show/1`**, returning the same display map `show_state` returns
   today (`%{state: dirac, amplitudes: [...], probabilities: [...]}`), built
   from the same `Qx.Format` calls. A lift-and-rewire of
   `Register.show_state/1`'s ~30 lines into a mode-neutral home. Calc-mode
   migration then reads:

   ```elixir
   # was: Qx.Qubit.new() |> Qx.Qubit.h() |> Qx.Qubit.show_state()
   Qx.create_circuit(1) |> Qx.h(0)
   |> Qx.steps() |> Enum.at(-1) |> Qx.Step.show()
   ```

The existing renderers already take raw tensors, so `step.state |>
Qx.draw_bloch()` and `Qx.draw_state/2` work unchanged; a rich Livebook
step widget belongs in `kino_qx`, downstream, later.

One subtlety to document on `Qx.Step.show/1`: it is per-trajectory. After a
measurement step the Dirac string shows the *collapsed* state of that sampled
run (the `⇒ |110⟩` above). That is the teaching win, but it is a different
object from the ensemble probabilities `run/2` reports.

## The counter-argument, and why it is weak here

stim keeps two APIs on purpose, so separation can be right. Its justification is
a hard performance split: an interactive Tableau simulator versus a kilohertz
batch sampler. Qx has no such split; both modes run the same math. The only real
costs are implementing an efficient stepper (additive) and deciding calc mode's
fate (removing `Qx.Register` from the public surface would be breaking).

## Decisions

Resolved by the 2026-07-03 review:

- **Stepper API shape:** `Qx.steps/1` lazy stream. It reads most idiomatically
  in Elixir and composes with `Enum`/`Stream`. The `Qx.run(qc, trace: true)`
  alternative is dropped (ill-defined for conditional circuits, see above);
  a `Qx.Stepper` struct with `step/1` adds nothing the stream lacks.
- **What a step yields:** a small struct with the step kind
  (`:gate | :measurement | :conditional`), the operation just applied, the
  state vector, probabilities, `classical_bits`, the position, and a
  taken/not-taken flag on conditional steps.
- **Substrate:** the timeline reduce (`execute_single_shot/2`), so mid-circuit
  measurement and `c_if` work. Single stochastic trajectory per
  materialisation; `seed:` option for reproducibility.
- **Efficiency:** the stepper threads the state once. The taps get rebuilt on
  top of it, which also fixes their initial-state bug (fact 3).
- **Display:** the step struct stays raw data; readability comes from an
  `Inspect` impl on `%Qx.Step{}` plus `Qx.Step.show/1`, a mode-neutral rehome
  of `Register.show_state/1`'s display map over the existing `Qx.Format`
  internals (see the Display section).

Still open:

- **Calc mode's fate:** internal (`@moduledoc false`, non-breaking) versus
  removal from the public surface (breaking). Removal is the cleaner end state
  and lands in the v0.10 API milestone (breaking changes are allowed in a 0.x
  minor). Precondition either way: audit `qxportal` and `kino_qx` for
  `Register` / `Qubit` usage first (workspace rule: downstream bumps are
  separate commits after a Qx release). Also note `Qx.Qubit.measure_x/y/z` are
  today the only eager-collapse APIs; the stepper covers that observability
  before they go internal.
- **Interim tap fix:** the taps' initial-state bug is live in a released
  public API. A small `fix/` patch (compute the prefix state properly) could
  ship before the stepper; the stepper then supersedes it. Tracked in
  `ROADMAP.md` under v0.10.

## Roadmap

- **v0.10 (the "API" minor):** add the first-class stepper, then the
  public-API cleanup it unlocks: demote `Qx.Register` / `Qx.Qubit` and remove
  the 0.8.x-deprecated aliases. Breaking removals are allowed in a 0.x minor.
  (The original draft said v0.9; v0.9 became the security & hardening minor.)

## Sources

- Cirq: https://quantumai.google/cirq/simulate/simulation ,
  https://quantumai.google/reference/python/cirq/Simulator
- QuTiP qutip-qip: https://qutip-qip.readthedocs.io/en/stable/qip-simulator.html
- Q#: https://learn.microsoft.com/en-us/qsharp/api/qsharp-lang/std.diagnostics/dumpmachine
- Qiskit: https://quantum.cloud.ibm.com/docs/api/qiskit/qiskit.quantum_info.Statevector ,
  https://qiskit.github.io/qiskit-aer/stubs/qiskit_aer.library.save_statevector.html
- PennyLane: https://docs.pennylane.ai/en/stable/code/api/pennylane.snapshots.html
- Yao.jl: https://docs.yaoquantum.org/dev/man/blocks.html
- stim: https://github.com/quantumlib/Stim
