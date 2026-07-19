---
module: "Qx.Simulation"
date: "2026-07-03"
problem_type: logic_error
component: instruction_dispatch
symptoms:
  - "`Qx.barrier(qc, [0, 1]) |> Qx.run()` raises `** (Qx.GateError) Unsupported gate: :barrier` — same for `get_state/2` and `steps/2`, and for circuits built via `barrier_all/1,2` or imported from OpenQASM"
  - "The engine LOOKED like it handled barriers: `apply_instruction/3` had an explicit `:barrier -> state` no-op arm with a comment ('Handle 0-qubit gates like :barrier'), and the bug shipped unnoticed since `Qx.barrier/2` was exposed in v0.8.1"
  - "Zero test coverage: no test anywhere executed a circuit containing a barrier (drawing and QASM-export tests exist, but those consumers never execute)"
root_cause: "The dispatch special-cased a shape no producer emits. apply_instruction/3 dispatches on length(qubits) and only no-op'd :barrier in its 0-qubit arm, but every real producer (Operations.barrier/2, Patterns.barrier_all — which no-ops empty lists BEFORE emitting — and the OpenQASM lowering) stores {:barrier, qubits, []} with the spanned qubit list. Non-empty-arity barriers fell into the 1/2/3-qubit gate arms, none of which match :barrier, and raised. The dead arm was worse than no handling: it read as coverage, satisfied a reviewer's glance, and suppressed the 'is this instruction actually handled?' question for four releases."
severity: high
tags: [dispatch, dead-code, barrier, no-op-instruction, unsupported-gate, producer-consumer-shape, coverage-illusion]
iron_law_number: 9
related_solutions: ["issue-title-names-wrong-module-seam-qx-simulation-20260516"]
---

# A dead special case masked the missing dispatch arm

## Symptoms

Any circuit containing a barrier raised on execution:

```
** (Qx.GateError) Unsupported gate: :barrier
```

From all three entry points (`run/2`, `get_state/2`, `steps/2`), for
barriers built with `Qx.barrier/2`, `Qx.barrier_all/1,2`, or imported
from OpenQASM. Found by the testing-reviewer during the circuit-stepper
review, not by any test — barriers had zero execution coverage.

## Investigation

1. **Hypothesis: only the new stepper is affected** — refuted in one
   repro: `Qx.barrier(qc, [0,1]) |> Qx.run()` raises on `main` too.
   The dispatch code predates the stepper.
2. **Hypothesis: some producer emits the 0-qubit shape the engine
   handles** — refuted by tracing all three producers.
   `Operations.barrier/2` stores the full list; `barrier_all/2`
   short-circuits empty lists *before* emitting (so not even `[]`
   arrives); OpenQASM lowering stores resolved indices. The handled
   shape `{:barrier, [], []}` is unreachable from the public API.
3. **Root cause found**: consumer special-cased a shape the producers
   never emit; the real shapes fell through to the unsupported-gate
   raise.

## Root Cause

`apply_instruction/3` branches on `length(qubits)` and each arity arm
enumerates gate names. `:barrier` appeared only in the `0` arm:

```elixir
case length(qubits) do
  0 ->
    case gate_name do
      :barrier -> state           # dead: nothing emits {:barrier, [], []}
      _ -> raise Qx.GateError, {:unsupported_gate, gate_name}
    end
  1 -> apply_single_qubit_op(...) # {:barrier, [0], []} lands here → raise
  2 -> apply_two_qubit_op(...)    # {:barrier, [0, 1], []} here → raise
  ...
end
```

The deeper why: the producer and consumer disagreed on the
instruction's shape, and the dead arm made the consumer *look*
covered. Dead special cases are actively harmful — they answer the
"did we handle X?" question with a false yes.

## Solution

Intercept barriers before the arity dispatch, one head on the shared
gate-step function (which also serves `steps/2` and `c_if` bodies), and
delete the dead arm so the illusion can't recur:

```elixir
# A barrier is a visual separator, not a unitary op: state unchanged
# and the counter does NOT advance, so the renormalize: n cadence
# ignores it. {:barrier, qubits, []} always carries the spanned list.
defp apply_gate_step(state, {:barrier, _qubits, _params}, count, _num_qubits, _renorm) do
  {state, count}
end
```

Test-design corollary (from the review of this fix): the
counter-not-advanced semantic is unobservable at float32 tolerance
(renormalizing a normalized state is ~identity), so a `renormalize: 1`
"stays normalized" test passes even under a counter regression. The
honest assertion is the observable contract: step-for-step state
equivalence between the barrier and barrier-free circuits under
`renormalize: 2`, plus coverage of every dispatch call site (top-level
timeline, `c_if` body, unitary path, stepper).

### Files Changed

- `lib/qx/simulation.ex` — barrier head on `apply_gate_step/5`; dead
  0-qubit `:barrier` arm removed from `apply_instruction/3`
- `test/qx/barrier_dispatch_test.exs` — 9 tests across all dispatch
  paths, incl. barrier-only circuit and the empty-list shape

## Prevention

- [x] Add to agent checks — PROMOTED to Iron Law #9 in `AGENTS.md`
      ("Dispatch completeness", 2026-07-03): for any instruction
      handled in exactly one arity/shape arm of a dispatch, confirm
      that arm's shape is producible; delete unreachable special-case
      arms; every emittable instruction kind gets an execution test
- [x] Test pattern: every instruction kind a producer can emit gets at
      least one *execution* test (`run/2` or `steps/2`), not just
      construction/drawing/export tests
- Specific guidance: "When adding an instruction kind, trace one real
  producer output into the consumer's dispatch by hand. A special case
  for a shape you cannot produce from the public API is a bug wearing
  a comment."

## Related

- `.claude/solutions/phoenix-issues/issue-title-names-wrong-module-seam-qx-simulation-20260516.md`
  — earlier lesson about verifying which seam actually carries the data
- Iron Law #7: the raise itself was correctly typed (`Qx.GateError`);
  the bug was that it fired at all
