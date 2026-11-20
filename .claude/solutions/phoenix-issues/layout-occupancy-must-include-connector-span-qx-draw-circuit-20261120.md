---
module: "Qx.Draw.SVG.Circuit"
date: "2026-11-20"
problem_type: logic_error
component: layout
symptoms:
  - "In a circuit diagram the double line joining a c_if gate to the classical register was drawn across a gate on a lower wire in the same column"
  - "A gate added after a barrier could be drawn in a column before the barrier"
  - "Each gate looked correct in isolation; only circuits with a gate on a lower wire in the same time step showed the overlap"
root_cause: "Column placement asked 'which wires does this gate act on' (its qubits) instead of 'which wires does its drawing cross'. A conditional gate's connector runs from the gate down to the register, a measurement's from the meter down to the register, and a barrier is a slice through the circuit; none of that ink was counted as occupying the wires it crosses, so the packer was free to put another gate there"
severity: medium
tags: [circuit-layout, column-packing, c-if, barrier, measure, connector, svg]
---

# Column packing must reserve every wire a gate's drawing crosses

## Symptoms

```elixir
Qx.create_circuit(3, 1)
|> Qx.measure(0, 0)
|> Qx.c_if(0, 1, &Qx.x(&1, 1))
|> Qx.h(2)
|> Qx.draw_circuit()
# the condition line from X on q1 to the register ran through H on q2
```

## Root cause

The layout gives each gate the first column in which the wires it
"occupies" are free. Occupancy was the gate's own qubits (min..max for a
multi-qubit gate). A conditional gate on q1 therefore left q2 free in its
column, although its connector to the register passes over q2.

## Solution

Occupancy is defined by the ink, per kind of gate:

```elixir
# a slice through the whole circuit
defp occupied_wires(%{gate: :barrier}, n), do: Enum.to_list(0..(n - 1))
# drops to the register
defp occupied_wires(%{gate: :measure, qubits: [q, _bit]}, n), do: Enum.to_list(q..(n - 1))
# joined to the register from below
defp occupied_wires(%{qubits: qs, condition: {_bit, _value}}, n),
  do: Enum.to_list(Enum.min(qs)..(n - 1))
# crosses every wire between its qubits
defp occupied_wires(%{qubits: qs}, _n), do: Enum.to_list(Enum.min(qs)..Enum.max(qs))
```

The barrier clause also gives a barrier a column of its own, so a gate
added after it is drawn after it.

## Prevention

- In any packed layout, derive occupancy from the drawn extent (lines
  included), not from the logical operands. When a draw clause gains a
  line that leaves the gate's own wires, update occupancy in the same
  change.
- Test layout with a **bystander**: for every gate kind that draws a
  connector, add a single-qubit gate on each wire the connector crosses
  and assert the two get different columns.
- Order-sensitive marks (barriers) need a test that a later instruction
  never lands in an earlier column.
