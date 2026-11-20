---
module: "Qx.Draw.SVG.Circuit"
date: "2026-11-20"
problem_type: logic_error
component: validation
symptoms:
  - "Qx.create_circuit(1, 2) |> Qx.measure(0, 1) |> Qx.draw_circuit() raised Qx.QubitIndexError for a valid circuit"
  - "The same circuit ran and exported correctly; only drawing failed"
  - "Any measurement into a classical bit whose index was >= num_qubits failed to draw"
root_cause: "The drawer validated every instruction with one generic clause that checked each element of the instruction's index list against num_qubits. A :measure instruction is {:measure, [qubit, classical_bit], []}: its second index lives in a different register with a different bound. The bug stayed hidden because tests used circuits with as many qubits as classical bits, where the wrong bound happens to accept every valid index"
severity: medium
iron_law_number: 9
tags: [measure, classical-bit, validation, instruction-shape, draw-circuit, heterogeneous-index-list]
related_solutions:
  - ".claude/solutions/phoenix-issues/dead-special-case-masks-missing-dispatch-arm-qx-simulation-20260703.md"
  - ".claude/solutions/phoenix-issues/shared-noop-arm-skips-measure-in-conditional-body-qx-cif-20261114.md"
---

# A generic index check validated a measurement's classical bit as a qubit

## Symptoms

```elixir
Qx.create_circuit(1, 2) |> Qx.measure(0, 1) |> Qx.draw_circuit()
# ** (Qx.QubitIndexError)   -- on 0.12.0
```

`Qx.run/2` and the OpenQASM export accepted the same circuit.

## Root cause

```elixir
defp validate_instruction!({gate, qubits, _params}, circuit) do
  Enum.each(qubits, &Validation.validate_qubit_index!(&1, circuit.num_qubits))
end
```

The second field of an instruction is called `qubits`, but for `:measure`
it is `[qubit, classical_bit]` and for `:c_if` it is
`[classical_bit, value]`. One clause for every instruction applies the
qubit bound to all of them.

## Solution

Give each heterogeneous shape its own clause, placed before the generic
one, and validate each field against its own register:

```elixir
defp validate_instruction!({:measure, [qubit, classical_bit], _params}, circuit) do
  Validation.validate_qubit_index!(qubit, circuit.num_qubits)
  Validation.validate_classical_bit!(classical_bit, circuit.num_classical_bits)
end
```

The generic clause now also checks the qubit count per gate against a
table, so `{:measure, [0], []}` cannot fall through to it and pass.

## Prevention

- Before writing a catch-all over instructions, list the shapes the
  producers emit (`Qx.Operations`, `Qx.Patterns`, the OpenQASM lowering)
  and mark which index lists are not all qubits: today `:measure` and
  `:c_if`.
- Test validation with **asymmetric registers**: a circuit with fewer
  qubits than classical bits, and one with more. Equal sizes hide every
  wrong-register bound.
- Compare consumers: if `run/2` accepts a circuit and a second consumer
  (draw, export) rejects it, the second consumer's validation is wrong.
