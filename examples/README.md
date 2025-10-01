# Quantum Circuit Visualization Examples

This directory contains example scripts demonstrating the circuit visualization feature in Qx.

## Running the Examples

```bash
mix run examples/circuit_visualization_example.exs
```

## Generated Files

The example script generates three SVG circuit diagrams:

- `bell_state.svg` - A simple Bell state preparation circuit
- `teleportation.svg` - Quantum teleportation protocol
- `grover.svg` - Simplified 2-qubit Grover's algorithm

## Usage in Your Code

```elixir
# Create a quantum circuit
circuit = Qx.QuantumCircuit.new(2, 2)
  |> Qx.Operations.h(0)
  |> Qx.Operations.cx(0, 1)
  |> Qx.Operations.measure(0, 0)
  |> Qx.Operations.measure(1, 1)

# Generate SVG visualization
svg = Qx.Draw.circuit(circuit, "My Circuit")

# Save to file
File.write!("my_circuit.svg", svg)
```

## Supported Features

- All single-qubit gates (H, X, Y, Z, S, T, RX, RY, RZ, P)
- Multi-qubit gates (CNOT/CX, CZ, Toffoli/CCX)
- Measurement operations
- Barriers for visual grouping
- Parametric gate display (e.g., RX(π/2))
- Automatic collision avoidance for multi-qubit gates
- Optional circuit titles

## Visual Style

The diagrams follow the Qiskit visualization conventions:
- Horizontal qubit lines (q0, q1, q2, ...)
- Gates arranged left to right in execution order
- Classical bit registers shown with double lines (c/n notation)
- Color-coded gates (blue for Hadamard, red for Pauli gates, etc.)
- IEEE standard symbols for controlled gates
