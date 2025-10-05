# Qx - Quantum Computing Simulator for Elixir

Qx is a quantum computing simulator built for Elixir that provides an intuitive API for creating and simulating quantum circuits. It supports up to 20 qubits with statevector simulation using Nx as the computational backend for efficient processing.

## Features

- **Simple API**: Easy-to-use functions for quantum circuit creation and simulation
- **Up to 20 Qubits**: Supports quantum circuits with up to 20 qubits
- **Statevector Simulation**: Uses statevector method for accurate quantum state representation
- **Nx Backend**: Leverages Nx for efficient numerical computations with GPU support
- **Visualization**: Built-in plotting capabilities with SVG and VegaLite support, plus circuit diagram generation
- **Circuit Diagrams**: Generate publication-quality SVG circuit diagrams following Qiskit conventions
- **Comprehensive Gates**: Supports H, X, Y, Z, S, T, RX, RY, RZ, CNOT, CZ, and Toffoli gates
- **Measurements**: Quantum measurements with classical bit storage
- **Conditional Operations**: Mid-circuit measurement with classical feedback for quantum teleportation and error correction
- **OpenQASM 3.0 Compatible**: Conditional operations map to OpenQASM 3.0 for real hardware execution
- **LiveBook Integration**: Works seamlessly with LiveBook for interactive quantum computing

## Installation

Add `qx` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:qx, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Quick Start

### Creating a Bell State

```elixir
# Create a Bell state (maximally entangled two-qubit state)
result = Qx.bell_state() |> Qx.run()

# Visualize the results
Qx.draw(result)
```

### Basic Circuit Construction

```elixir
# Create a circuit with 2 qubits and 2 classical bits
qc = Qx.create_circuit(2, 2)
     |> Qx.h(0)           # Apply Hadamard gate to qubit 0
     |> Qx.cx(0, 1)       # Apply CNOT gate (control: 0, target: 1)
     |> Qx.measure(0, 0)  # Measure qubit 0, store in classical bit 0
     |> Qx.measure(1, 1)  # Measure qubit 1, store in classical bit 1

# Run the simulation
result = Qx.run(qc, 1000)  # 1000 measurement shots

# Display results
IO.inspect(result.counts)
```

## API Reference

The 'Qx' module implements a handy API for the majority of functions needed to create simple quantum circuits. It is a series of delegations to the following modules:
- `Qx.Qubit` - Define and initialise individual qubits (not used in circuits)
- `Qx.QuantumCircuit` - Structure and functions for a quantum circuit
- `Qx.Operations` - Gate operations on Qubits
- `Qx.Simulation` - Simulation and execution of circuits

### Circuit Creation

- `Qx.create_circuit(num_qubits)` - Create circuit with only qubits
- `Qx.create_circuit(num_qubits, num_classical_bits)` - Create circuit with qubits and classical bits

### Single-Qubit Gates

- `Qx.h(circuit, qubit)` - Hadamard gate (creates superposition)
- `Qx.x(circuit, qubit)` - Pauli-X gate (bit flip)
- `Qx.y(circuit, qubit)` - Pauli-Y gate
- `Qx.z(circuit, qubit)` - Pauli-Z gate (phase flip)
- `Qx.s(circuit, qubit)` - S gate (phase gate π/2)
- `Qx.t(circuit, qubit)` - T gate (phase gate π/4)

### Rotation Gates

- `Qx.rx(circuit, qubit, theta)` - Rotation around X-axis
- `Qx.ry(circuit, qubit, theta)` - Rotation around Y-axis
- `Qx.rz(circuit, qubit, theta)` - Rotation around Z-axis
- `Qx.phase(circuit, qubit, phi)` - Phase gate with custom angle

### Multi-Qubit Gates

- `Qx.cx(circuit, control, target)` - CNOT gate
- `Qx.cz(circuit, control, target)` - Controlled-Z gate
- `Qx.ccx(circuit, control1, control2, target)` - Toffoli gate (CCNOT)

### Measurements

- `Qx.measure(circuit, qubit, classical_bit)` - Measure qubit and store result

### Conditional Operations (Mid-Circuit Measurement with Feedback)

- `Qx.c_if(circuit, classical_bit, value, gate_fn)` - Apply gates conditionally based on classical bit value

Enables quantum error correction, quantum teleportation, and adaptive algorithms through mid-circuit measurements with classical feedback.

**Example:**
```elixir
# Quantum teleportation with conditional corrections
qc = Qx.create_circuit(3, 3)
     |> Qx.x(0)                    # State to teleport
     |> Qx.h(1) |> Qx.cx(1, 2)     # Create Bell pair
     |> Qx.cx(0, 1) |> Qx.h(0)     # Bell measurement
     |> Qx.measure(0, 0)
     |> Qx.measure(1, 1)
     # Conditional corrections based on measurement
     |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)
     |> Qx.c_if(0, 1, fn c -> Qx.z(c, 2) end)
     |> Qx.measure(2, 2)

result = Qx.run(qc, 1000)
# Qubit 2 now contains the teleported state!
```

See `examples/conditional_gates_example.exs` for more examples.

**OpenQASM 3.0 Compatibility:** Conditional operations map directly to OpenQASM 3.0 if-statements for execution on real quantum hardware.

### Circuit Visualization

- `Qx.barrier(circuit, qubits)` - Add visual barrier for circuit organization

### Simulation

- `Qx.run(circuit)` - Run simulation with default 1024 shots
- `Qx.run(circuit, shots)` - Run simulation with specified number of shots
- `Qx.get_state(circuit)` - Get quantum state vector directly
- `Qx.get_probabilities(circuit)` - Get probability distribution

### Visualization

**Results Visualization:**
- `Qx.draw(result)` - Plot probability distribution (VegaLite)
- `Qx.draw(result, format: :svg)` - Plot as SVG
- `Qx.draw_counts(result)` - Plot measurement counts
- `Qx.histogram(probabilities)` - Create probability histogram

**Circuit Diagrams:**
- `Qx.Draw.circuit(circuit)` - Generate SVG circuit diagram
- `Qx.Draw.circuit(circuit, title)` - Generate circuit diagram with title

### Convenience Functions

- `Qx.bell_state()` - Create Bell state circuit
- `Qx.ghz_state()` - Create GHZ state circuit
- `Qx.superposition()` - Create single-qubit superposition

## Examples

### Circuit Visualization

```elixir
# Create a Bell state circuit
circuit = Qx.create_circuit(2, 2)
          |> Qx.h(0)
          |> Qx.cx(0, 1)
          |> Qx.measure(0, 0)
          |> Qx.measure(1, 1)

# Generate and save circuit diagram
svg = Qx.Draw.circuit(circuit, "Bell State")
File.write!("bell_state.svg", svg)
```

The circuit diagram feature supports:
- All quantum gates with proper IEEE notation
- Parametric gates (displays angles like RX(π/2))
- Multi-qubit gates with collision avoidance
- Barriers for visual organization
- Measurements with classical bit connections
- Publication-quality SVG output

See `examples/circuit_visualization_example.exs` for more examples.

### Quantum Teleportation Setup

```elixir
# Create a quantum teleportation circuit
qc = Qx.create_circuit(3, 3)
     |> Qx.h(1)           # Create Bell pair between qubits 1 and 2
     |> Qx.cx(1, 2)
     |> Qx.cx(0, 1)       # Bell measurement on qubits 0 and 1
     |> Qx.h(0)
     |> Qx.measure(0, 0)  # Measure qubit 0
     |> Qx.measure(1, 1)  # Measure qubit 1

result = Qx.run(qc)
Qx.draw_counts(result)
```

### Grover's Algorithm (Simplified)

```elixir
# Simplified Grover's algorithm for 2 qubits
grover = Qx.create_circuit(2)
         |> Qx.h(0)        # Initialize superposition
         |> Qx.h(1)
         # Oracle (flip phase of target state)
         |> Qx.z(0)
         |> Qx.z(1)
         # Diffusion operator
         |> Qx.h(0)
         |> Qx.h(1)
         |> Qx.x(0)
         |> Qx.x(1)
         |> Qx.cx(0, 1)
         |> Qx.x(0)
         |> Qx.x(1)
         |> Qx.h(0)
         |> Qx.h(1)

result = Qx.run(grover)
Qx.draw(result)
```

### Working with Quantum States

```elixir
# Create a 3-qubit GHZ state and examine its properties
ghz_circuit = Qx.ghz_state()

# Get the quantum state vector
state = Qx.get_state(ghz_circuit)
IO.inspect(Nx.to_flat_list(state))

# Get probabilities for all computational basis states
probs = Qx.get_probabilities(ghz_circuit)
Qx.histogram(probs)
```

## Module Structure

The Qx library consists of several modules:

- **`Qx`** - Main API providing convenient functions
- **`Qx.Qubit`** - Qubit creation and manipulation functions
- **`Qx.QuantumCircuit`** - Quantum circuit structure and management
- **`Qx.Operations`** - Quantum gate operations
- **`Qx.Simulation`** - Circuit execution and simulation engine
- **`Qx.Draw`** - Visualization and plotting functions
- **`Qx.Math`** - Core mathematical functions for quantum mechanics

## Requirements
These are the versions I've developed and tested with

- Elixir 1.18+
- Nx 0.10+ (for numerical computations)
- VegaLite 0.1+ (for visualization)

## Limitations

Current version limitations:

- Maximum 20 qubits
- Statevector simulation only (no density matrix)
- Ideal gates only (no noise modeling)

## Running Examples

The library includes example scripts:

```bash
# Run circuit visualization examples
mix run examples/circuit_visualization_example.exs

# Run basic usage examples (if available)
elixir examples/basic_usage.exs

# Run validation tests (if available)
elixir examples/validation.exs
```

## Testing

Run the test suite:

```bash
mix test
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the Apache License 2.0.

## Acknowledgments

- Built with [Nx](https://github.com/elixir-nx/nx) for numerical computations
- Visualization powered by [VegaLite](https://github.com/livebook-dev/vega_lite)
- Inspired by quantum computing frameworks like Qiskit and Cirq

## Version

Current version: 0.1.0

For detailed API documentation, run:

```bash
mix docs
```
