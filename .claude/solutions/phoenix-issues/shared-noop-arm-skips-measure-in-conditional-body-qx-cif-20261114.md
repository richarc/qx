---
module: "Qx.Operations / Qx.Simulation / Qx.Export.OpenQASM.Lowering"
date: "2026-11-14"
problem_type: logic_error
component: instruction_dispatch
symptoms:
  - "`Qx.c_if(qc, 0, 1, fn c -> c |> Qx.x(1) |> Qx.measure(1, 1) end)` was accepted; `Qx.run/2` returned counts `%{\"10\" => 20}`: q1 was flipped but classical bit 1 stayed 0. No error, no warning"
  - "OpenQASM import of `if (c[0] == 1) { x q[1]; c[1] = measure q[1]; }` succeeded and ran with the same wrong counts"
  - "The `c_if/4` docs said 'Gates in conditional block cannot contain measurements'; only a nested `c_if` was actually rejected, and no test built such a block"
root_cause: "The gate dispatch has a `:measure -> state` no-op arm that is correct for one caller only: a circuit with no `c_if` runs every instruction through the dispatch and samples measurements afterwards. The conditional path reuses the same dispatch for the instructions inside a taken block, so a measurement there hit the no-op and was dropped, although on that path measurements must collapse the state and write a classical bit. The constraint that would have kept the shape out was written in a docstring and enforced nowhere, and there were two producers of `{:c_if, _, body}` (`Qx.Operations.c_if/4` and the OpenQASM lowering), neither of which checked the body."
severity: high
tags: [dispatch, no-op-arm, c_if, measurement, silent-wrong-result, documented-constraint-unenforced, second-producer, openqasm-import]
elixir_version: "1.20.2"
iron_law_number: 9
related_solutions:
  - ".claude/solutions/phoenix-issues/dead-special-case-masks-missing-dispatch-arm-qx-simulation-20260703.md"
  - ".claude/solutions/testing-issues/test-rejected-and-chained-conditionals-qx-cif-20260626.md"
---

# A no-op dispatch arm that is right for one path silently drops the instruction on another

## Symptoms

- A measurement inside a `c_if` block was accepted at build time and skipped
  at run time. The gates around it ran; its classical bit stayed 0.
- The same program imported from OpenQASM behaved the same way.
- Found by accident, while probing the dispatch to decide whether a refactor
  was worth doing. No user report, no failing test.

## Investigation

1. Probed `apply_instruction/3` with shapes around the edges of what
   producers emit. `{:measure, [0], []}` (no producer emits it) returned the
   state unchanged: a dead arm. That prompted the question of where the
   *live* two-qubit `:measure -> state` arm is reached from.
2. It is reached from two places: the no-`c_if` run path (correct, the
   measurement is sampled later) and `step_conditional/7`, which applies a
   taken block's instructions with `apply_gate_step/5` (wrong).
3. Grepped producers of `{:c_if, …}`. Two: `Qx.Operations.c_if/4` and
   `lib/qx/export/openqasm/lowering.ex`. The second does not go through the
   first, so a guard in `validate_conditional_block/1` alone would have left
   the import path broken.
4. A reviewer later claimed the two-qubit arm was dead as well. Deleting it
   and running `x(0) |> measure(0, 0)` crashed in
   `apply_controlled_target_op`; it stays.

## Root Cause

One dispatch, two callers with different contracts for the same instruction.
A no-op is the right answer for "measure" only where something else performs
the measurement. The arm cannot tell which caller it serves, so the shape has
to be kept out of the other caller's input, and nothing did that.

## Solution

Reject at both producers, each with its own typed error:

```elixir
# Qx.Operations.validate_conditional_block/1
{:measure, _, _} ->
  raise Qx.ConditionalError, :measurement_in_conditional

# Qx.Export.OpenQASM.Lowering, before lowering the if body
defp reject_measurement_in_body(body) do
  case Enum.find(body, &match?({:measure, _qubit, _cbit, _meta}, &1)) do
    nil -> :ok
    {:measure, _qubit, _cbit, meta} ->
      {:error,
       Qx.QasmUnsupportedError.exception(
         feature: "measurement inside an `if` block",
         line: Keyword.get(meta, :line),
         hint: "Measure after the `if` block instead"
       )}
  end
end
```

The dead one-qubit `:measure` arm was deleted; the live two-qubit arm got a
comment saying which path reaches it. Marked **Breaking** in the CHANGELOG:
input that was accepted now raises.

Tests: `test/qx/conditional_measurement_guard_test.exs` (12 tests; braced,
unbraced and arrow-form QASM, `measure_x`, run and steps).

## Prevention

- For every no-op arm in a dispatch, list each caller that can reach it and
  ask whether "do nothing" is correct for that caller. A no-op that is right
  on one path is a silent drop on any other.
- A constraint in a docstring ("cannot contain X") is a claim to verify: grep
  for the check and for a test that the rejection fires. If neither exists,
  the constraint is not enforced.
- When adding a guard at a producer, grep for every producer of that
  instruction shape first. In Qx the OpenQASM lowering builds instruction
  tuples directly and bypasses `Qx.Operations`.
- Before deleting an arm a reviewer calls dead, delete it locally and run one
  real circuit of each kind (with and without `c_if`). It takes a minute.
