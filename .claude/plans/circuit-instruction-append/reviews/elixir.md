# Code Review: circuit-instruction-append (lib/ changes)

## Summary
- Status: Changes requested (one warning: stale examples). No blockers.
- Issues: 0 BLOCKER, 1 WARNING, 3 SUGGESTION

## BLOCKER
None. Grepped all of lib/ for `instructions`/`reversed_instructions`. Only `quantum_circuit.ex` names `reversed_instructions`. No missed reader or writer of the old field. Other `instructions` hits are:
- the `%Diagram{}` struct field in draw/svg/circuit.ex (its own key);
- lowering.ex's `state.instructions` accumulator (unrelated);
- local variables.

Order checks:
- Producers prepend (lines 143, 169, 189, 231, 242, 256).
- `get_instructions/1` reverses.
- `put_instructions/2` reverses its circuit-order input.
- lowering.ex reverses its newest-first accumulator once into `put_instructions/2`, so the final order is circuit order (correct).
- `c_if/4` clears the temp circuit with `put_instructions(circuit, [])` and reads back with `get_instructions`, so the block stays in circuit order.
- `add_conditional` stores the block as given.

## WARNING
1. examples/openqasm/round_trip.exs:19, :29, :69 and examples/openqasm/import_gate_definition.exs:47 still read `.instructions`. They will raise `KeyError`.
   Fix: use `Qx.QuantumCircuit.get_instructions/1`. Line 69 becomes `length(Qx.QuantumCircuit.get_instructions(qft_circuit))`. These files are outside lib/ and test/, and are probably not covered by `mix test`.

## SUGGESTION
1. lib/qx.ex:1885: the `tap_circuit` example now prints `"Gates: #{depth(c)}"`. `depth/1` is `length(reversed_instructions)`, so the value is correct, but "depth" is a misleading name for a gate count in docs. Consider `length(Qx.QuantumCircuit.get_instructions(c))`, or leave it. It is fine functionally.
2. lib/qx/operations.ex:909: the doc example line is long. It is probably not a doctest because of `%Qx.QuantumCircuit{...}`. Consider binding the result to a variable first for readability.
3. lib/qx/quantum_circuit.ex:365: `put_instructions/2` has a `is_list` guard and an accurate spec. `Enum.reverse/1` on an improper list raises, which is acceptable. `any_instruction?/2` is fine: the spec `as_boolean(term())` is valid and the `is_function(fun, 1)` guard is right. Both are `@doc false` and use `#` comments rather than `@doc false` plus a doc. This is consistent with neighbouring helpers, so no change is needed.

## Checks with no finding
- `get_instructions/1` call counts:
  - draw `render/2`: one call, passed into `validate_circuit!/2` and `analyze_circuit/3`;
  - `create_instruction_timeline/1`: one call;
  - simulation.ex:406 (steps): one call, outside the loop;
  - openqasm.ex `generate_instructions`: one call;
  - c_if: one call;
  - no call sits inside a per-instruction or per-shot loop.
- Simulation hoist: `create_instruction_timeline/1` is pure. It depends only on the immutable `circuit`, and the timeline is read-only inside `step_timeline_item`. The result per shot is identical. With `shots = 0` (empty range) the timeline is now built once without being used, which is harmless. `execute_single_shot` is private, so the new arity breaks no callers.
- `has_conditionals?` and `final_step` use `any_instruction?`, which is order-independent, so there is no reverse cost. Only top-level `c_if` is scanned, same as before.
- Docs and CHANGELOG match the code:
  - `KeyError` on `circuit.instructions`: true for a struct without the field.
  - `%QuantumCircuit{instructions: ...}` fails at compile time: true.
  - `%{c | instructions: ...}` raises `KeyError`: true.
  - the moduledoc and `get_instructions` doc are accurate.
  - the comment "no other module names it" is true per grep.
  - `reset/1` and `new/2` use the new field.
- The `measure` producer still uses `measurements ++ [m]`. The CHANGELOG states this honestly.

## PRE-EXISTING
- lib/qx/quantum_circuit.ex:231 — `measurements ++ [measurement]` is still O(n) per measurement (acknowledged in the CHANGELOG).

## Not verified
- No shell, so I did not run tests, doctests, format or credo.
- I did not check `mix.exs` docs or extras, or the livebook/guides directories beyond the glob. The grep found no other `.instructions` readers in `*.md`, `*.livemd`, `*.ex` or `*.exs` outside `.claude/` plans.
- The benchmark numbers in the CHANGELOG are unverified.
