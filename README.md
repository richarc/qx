# Qx - Quantum Computing Simulator for Elixir

Qx is a quantum computing simulator built for Elixir that provides an intuitive API for creating and simulating quantum circuits. The primary goal of the project is to enhance my understanding of quantum computing concepts, quantum simulators and the Elixir Nx library. My hope is that it is eventualy valuable for others to learn quantum computing. It supports up to 20 qubits (an arbitrary number that I feel is useful but still below the memory cliff that would occurs around 30 qubits).

## Features

- **Two Modes of Operation**:
  - **Circuit Mode**: Build quantum circuits and execute them (traditional workflow)
  - **Calculation Mode**: Apply gates in real-time and inspect states immediately (great for learning!)
- **Simple API**: Easy-to-use functions for quantum circuit creation and simulation
- **Up to 20 Qubits**: Supports quantum circuits with up to 20 qubits
- **Statevector Simulation**: Uses statevector method for accurate quantum state representation
- **EXLA Backend**: Leverages Elixir Nx for faster execution (CPU/GPU)
- **Visualization**: Built-in plotting capabilities with SVG and VegaLite support, plus circuit diagram generation
- **Growing Range of Gates**: Supports H, X, Y, Z, S, T, RX, RY, RZ, CNOT, CZ, and Toffoli gates
- **Measurements**: Quantum measurements with classical bit storage
- **Conditional Operations**: Mid-circuit measurement with classical feedback for quantum processes like teleportation and error correction
- **LiveBook Integration**: Full support with interactive visualizations in LiveBook

## Installation (basic no acceleration)

Add `qx` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:qx, "~> 0.2.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Performance & Acceleration

### Optional GPU Acceleration (NVIDIA/AMD)

For even better performance, you can enable GPU support on Linux/Windows systems:

#### NVIDIA GPU (CUDA) - Linux/Windows
```bash
# 1. Install CUDA Toolkit (11.8 or later)
# https://developer.nvidia.com/cuda-downloads

# 2. Set environment variable before running
export XLA_TARGET=cuda118  # or cuda120

# 3. Configure in config/config.exs
config :nx, :default_backend, {EXLA.Backend, client: :cuda}
```

#### AMD GPU (ROCm) - Linux
```bash
# 1. Install ROCm (5.4 or later)
# https://rocm.docs.amd.com/

# 2. Configure in config/config.exs
config :nx, :default_backend, {EXLA.Backend, client: :rocm}
```

**Note for macOS/Apple Silicon Users**: EXLA does not currently support Metal GPU acceleration on M1/M2/M3/M4 Macs. However, you have two excellent options:
1. **EXLA CPU backend** (recommended): speedup through XLA's LLVM optimizations
2. **EMLX with Metal GPU**: additional speedup using MLX framework (see below)

### Apple Silicon GPU Acceleration with EMLX (M1/M2/M3/M4)

EMLX provides Metal GPU acceleration on Apple Silicon through the MLX framework, designed specifically for Apple's unified memory architecture:

```elixir
# Add to mix.exs dependencies
defp deps do
  [
    {:qx, "~> 0.2.0"},
    {:emlx, github: "elixir-nx/emlx", branch: "main"}
  ]
end
```

```elixir
# Configure in config/config.exs
import Config

# Use EMLX with Metal GPU
config :nx, :default_backend, {EMLX.Backend, device: :gpu}

# Optional: Enable JIT compilation for Metal kernels
# System.put_env("LIBMLX_ENABLE_JIT", "1")
```

**Installation:**
```bash
# Get dependencies - EMLX automatically downloads precompiled MLX binaries
mix deps.get

# Verify in IEx
iex -S mix
iex> Nx.default_backend({EMLX.Backend, device: :gpu})
iex> Nx.tensor([1, 2, 3]) |> IO.inspect()
```

**Note**: Metal does not support 64-bit floats, but Qx uses Complex64 which is fully supported.

## Quick Start

### Calculation Mode (Real-Time Gate Application)

```elixir
# Create and manipulate qubits directly - gates apply immediately!
q = Qx.Qubit.new()
  |> Qx.Qubit.h()
  |> Qx.Qubit.show_state()

# Output:
# %{
#   state: "0.707|0⟩ + 0.707|1⟩",
#   amplitudes: [{"|0⟩", "0.707+0.000i"}, {"|1⟩", "0.707+0.000i"}],
#   probabilities: [{"|0⟩", 0.5}, {"|1⟩", 0.5}]
# }

# Inspect state at any step
q = Qx.Qubit.new()
Qx.Qubit.measure_probabilities(q)  # [1.0, 0.0] - definitely |0⟩

q = Qx.Qubit.x(q)
Qx.Qubit.measure_probabilities(q)  # [0.0, 1.0] - definitely |1⟩

q = Qx.Qubit.h(q)
Qx.Qubit.measure_probabilities(q)  # [0.5, 0.5] - superposition!
```

### Circuit Mode (Build Then Execute)

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
- `Qx.Qubit` - Calculation mode: Define and manipulate individual qubits in real-time
- `Qx.Register` - Calculation mode: Multi-qubit registers with entanglement
- `Qx.QuantumCircuit` - Circuit mode: Structure and functions for quantum circuits
- `Qx.Operations` - Gate operations on circuits
- `Qx.Simulation` - Simulation and execution of circuits

### Calculation Mode (Qx.Qubit)

Work with qubits directly - gates apply immediately!

**Qubit Creation:**
- `Qx.Qubit.new()` - Create |0⟩ state
- `Qx.Qubit.new(alpha, beta)` - Create custom state α|0⟩ + β|1⟩
- `Qx.Qubit.one()` - Create |1⟩ state
- `Qx.Qubit.plus()` - Create |+⟩ state
- `Qx.Qubit.minus()` - Create |-⟩ state
- `Qx.Qubit.from_basis(0 | 1)` - Create from computational basis
- `Qx.Qubit.from_bloch(theta, phi)` - Create from Bloch sphere coordinates
- `Qx.Qubit.from_angle(theta)` - Create from angle (simplified Bloch sphere)

**Single-Qubit Gates (Calculation Mode):**
- `Qx.Qubit.h/1` - Hadamard gate
- `Qx.Qubit.x/1` - Pauli-X gate
- `Qx.Qubit.y/1` - Pauli-Y gate
- `Qx.Qubit.z/1` - Pauli-Z gate
- `Qx.Qubit.s/1` - S gate
- `Qx.Qubit.t/1` - T gate
- `Qx.Qubit.rx/2` - X-rotation
- `Qx.Qubit.ry/2` - Y-rotation
- `Qx.Qubit.rz/2` - Z-rotation
- `Qx.Qubit.phase/2` - Phase gate

**State Inspection:**
- `Qx.Qubit.state_vector/1` - Get raw state tensor
- `Qx.Qubit.show_state/1` - Get human-readable state (Dirac notation, amplitudes, probabilities)
- `Qx.Qubit.measure_probabilities/1` - Get measurement probabilities
- `Qx.Qubit.alpha/1` - Get |0⟩ amplitude
- `Qx.Qubit.beta/1` - Get |1⟩ amplitude

### Calculation Mode (Qx.Register)

Work with multi-qubit registers - gates apply immediately with full entanglement support!

**Register Creation:**
- `Qx.Register.new(num_qubits)` - Create register with n qubits (all |0⟩)
- `Qx.Register.new([qubit1, qubit2, ...])` - Create from list of qubits via tensor product
- `Qx.Register.from_basis_states([0, 1, 0])` - Create from list of basis states (e.g., |010⟩)
- `Qx.Register.from_superposition(n)` - Create n-qubit register in equal superposition

**Single-Qubit Gates (on specific qubits):**
- `Qx.Register.h(register, qubit_index)` - Hadamard gate
- `Qx.Register.x(register, qubit_index)` - Pauli-X gate
- `Qx.Register.y(register, qubit_index)` - Pauli-Y gate
- `Qx.Register.z(register, qubit_index)` - Pauli-Z gate
- `Qx.Register.s(register, qubit_index)` - S gate
- `Qx.Register.t(register, qubit_index)` - T gate
- `Qx.Register.rx(register, qubit_index, theta)` - X-rotation
- `Qx.Register.ry(register, qubit_index, theta)` - Y-rotation
- `Qx.Register.rz(register, qubit_index, theta)` - Z-rotation
- `Qx.Register.phase(register, qubit_index, phi)` - Phase gate

**Multi-Qubit Gates:**
- `Qx.Register.cx(register, control, target)` - CNOT gate
- `Qx.Register.cz(register, control, target)` - Controlled-Z gate
- `Qx.Register.ccx(register, control1, control2, target)` - Toffoli gate

**State Inspection:**
- `Qx.Register.state_vector(register)` - Get full state vector
- `Qx.Register.get_probabilities(register)` - Get measurement probabilities for all basis states
- `Qx.Register.show_state(register)` - Get human-readable multi-qubit state representation
- `Qx.Register.valid?(register)` - Check if register is properly normalized

### Circuit Mode

**Circuit Creation:**
- `Qx.create_circuit(num_qubits)` - Create circuit with only qubits
- `Qx.create_circuit(num_qubits, num_classical_bits)` - Create circuit with qubits and classical bits

**Single-Qubit Gates (Circuit Mode):**

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

### Circuit Visualization

- `Qx.barrier(circuit, qubits)` - Add visual barrier for circuit organization

### Simulation

- `Qx.run(circuit)` - Run simulation with default 1024 shots (returns `SimulationResult`)
- `Qx.run(circuit, shots)` - Run simulation with specified number of shots
- `Qx.get_state(circuit)` - Get quantum state vector directly (only for circuits without measurements)
- `Qx.get_probabilities(circuit)` - Get probability distribution (only for circuits without measurements)

### Simulation Results

The `Qx.run/2` function returns a `SimulationResult` struct with helper functions:

- `Qx.SimulationResult.most_frequent(result)` - Get most common measurement outcome
- `Qx.SimulationResult.filter_by_probability(result, threshold)` - Filter outcomes by probability
- `Qx.SimulationResult.outcomes(result)` - Get list of all unique outcomes
- `Qx.SimulationResult.probability(result, outcome)` - Get probability of specific outcome
- `Qx.SimulationResult.to_map(result)` - Convert to map for backwards compatibility

### Debugging & Inspection

Pipeline-friendly tap functions for inspecting circuits during construction:

- `Qx.tap_circuit(circuit, fn)` - Inspect circuit metadata without breaking pipeline
- `Qx.tap_state(circuit, fn)` - Inspect quantum state during building
- `Qx.tap_probabilities(circuit, fn)` - Inspect measurement probabilities

**Example:**
```elixir
result = Qx.create_circuit(2)
  |> Qx.h(0)
  |> Qx.tap_circuit(fn c -> IO.puts("Gates: #{length(c.instructions)}") end)
  |> Qx.tap_state(&IO.inspect(&1, label: "State after H"))
  |> Qx.cx(0, 1)
  |> Qx.tap_probabilities(fn p -> IO.puts("Bell state created!") end)
  |> Qx.run(1000)
```

### Error Handling

Qx provides domain-specific exception types for better error handling:

- `Qx.QubitIndexError` - Qubit index out of range
- `Qx.StateNormalizationError` - Invalid quantum state normalization
- `Qx.MeasurementError` - Measurement-related errors
- `Qx.ConditionalError` - Conditional operation errors
- `Qx.ClassicalBitError` - Classical bit index errors
- `Qx.GateError` - Gate operation errors
- `Qx.QubitCountError` - Invalid qubit count

**Example:**
```elixir
try do
  circuit |> Qx.h(999)
rescue
  Qx.QubitIndexError -> IO.puts("Invalid qubit index!")
  Qx.GateError -> IO.puts("Gate operation failed!")
end
```

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

## Using Qx with LiveBook

[LiveBook](https://livebook.dev/) is the perfect environment for interactive quantum computing with Qx! Here's how to set it up with full EXLA acceleration.

### Basic Setup

Create a new LiveBook notebook and add this setup cell:

```elixir
Mix.install([
  {:qx, github: "richarc/qx"},
  {:kino, "~> 0.12"},
  {:vega_lite, "~> 0.1.11"},
  {:kino_vega_lite, "~> 0.1.11"}
])
```

### Setup with EXLA Acceleration (Recommended)

For maximum performance, include EXLA in your setup:

```elixir
Mix.install([
  {:qx, github: "richarc/qx"},
  {:exla, "~> 0.10"},
  {:kino, "~> 0.12"},
  {:vega_lite, "~> 0.1.11"},
  {:kino_vega_lite, "~> 0.1.11"}
])

# Configure EXLA backend for speedup
Application.put_env(:nx, :default_backend, EXLA.Backend)
```

### GPU Acceleration in LiveBook

**For Apple Silicon (M1/M2/M3/M4 Macs)**:

```elixir
Mix.install([
  {:qx, github: "richarc/qx"},
  {:emlx, github: "elixir-nx/emlx", branch: "main"},
  {:kino, "~> 0.12"},
  {:vega_lite, "~> 0.1.11"},
  {:kino_vega_lite, "~> 0.1.11"}
])

# Configure for Metal GPU
Application.put_env(:nx, :default_backend, {EMLX.Backend, device: :gpu})
```

**For NVIDIA/AMD GPUs (Linux/Windows)**:

```elixir
Mix.install([
  {:qx, github: "richarc/qx"},
  {:exla, "~> 0.10"},
  {:kino, "~> 0.12"},
  {:vega_lite, "~> 0.1.11"},
  {:kino_vega_lite, "~> 0.1.11"}
])

# Configure for CUDA GPU (NVIDIA - Linux/Windows)
Application.put_env(:nx, :default_backend, {EXLA.Backend, client: :cuda})

# Or for AMD ROCm GPU (Linux only)
# Application.put_env(:nx, :default_backend, {EXLA.Backend, client: :rocm})
```

### Interactive Visualization Example

Once set up, you can create beautiful interactive visualizations:

```elixir
# Create a Bell state
circuit = Qx.create_circuit(2, 2)
          |> Qx.h(0)
          |> Qx.cx(0, 1)
          |> Qx.measure(0, 0)
          |> Qx.measure(1, 1)

# Run simulation
result = Qx.run(circuit, 1000)

# Visualize with Kino
Qx.draw_counts(result)
```

### Real-Time State Inspection

LiveBook's reactive cells make quantum state exploration intuitive:

```elixir
# Calculation Mode - perfect for learning!
import Qx.Qubit

qubit = new()
        |> h()
        |> show_state()
        |> Kino.render()

# Apply more gates and see immediate results
qubit
|> x()
|> show_state()
```

### Performance Verification

Check that EXLA is active:

```elixir
# Verify backend
IO.inspect(Nx.default_backend(), label: "Active Backend")

# Run a quick benchmark
{time, _result} = :timer.tc(fn ->
  Qx.create_circuit(15, 0)
  |> Qx.h(0)
  |> Qx.cx(0, 1)
  |> Qx.cx(1, 2)
  |> Qx.get_state()
end)

IO.puts("15-qubit circuit execution: #{time / 1000} ms")
# Should see ~90ms with EXLA, vs 15+ seconds without
```

### Tips for LiveBook Users

1. **Use Calculation Mode for Learning**: Real-time gate application with `Qx.Qubit` and `Qx.Register` is perfect for understanding quantum mechanics interactively

2. **Leverage Kino Widgets**: Use `Kino.render()` to create interactive controls for gate parameters

3. **Performance**: Always include EXLA in your Mix.install for best performance

4. **Visualization**: `Qx.draw_counts/1` returns VegaLite specs that render beautifully in LiveBook

5. **Debugging**: Use tap functions (`tap_state`, `tap_probabilities`) in pipelines with `IO.inspect` for immediate feedback

### Example LiveBook Notebooks

Check out example notebooks in the repository:
- `examples/livebook/getting_started.livemd` - Basic introduction
- `examples/livebook/quantum_teleportation.livemd` - Complete teleportation tutorial
- `examples/livebook/grovers_algorithm.livemd` - Search algorithm implementation

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

### Quantum Teleportation

```elixir
# Create a quantum teleportation circuit (teleport |1⟩ state)
qc = Qx.create_circuit(3, 3)
     |> Qx.x(0)                           # Prepare |1⟩ to teleport
     |> Qx.h(1)                           # Create Bell pair
     |> Qx.cx(1, 2)                       # between qubits 1 and 2
     |> Qx.cx(0, 1)                       # Bell measurement
     |> Qx.h(0)
     |> Qx.measure(0, 0)                  # Measure qubit 0
     |> Qx.measure(1, 1)                  # Measure qubit 1
     |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)  # Conditional corrections
     |> Qx.c_if(0, 1, fn c -> Qx.z(c, 2) end)
     |> Qx.measure(2, 2)                  # Measure teleported qubit

# Run simulation
result = Qx.run(qc, 1000)

# Analyze with new SimulationResult helpers
{most_common, count} = Qx.SimulationResult.most_frequent(result)
IO.puts("Most frequent: #{most_common} (#{count} times)")

# All outcomes should have rightmost bit = 1 (successful teleportation)
# Output: "001", "011", "101", or "111" - all with last bit = 1

# Visualize
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

**Circuit Mode:**
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

**Calculation Mode (Single Qubit):**
```elixir
# Create and inspect qubit states in real-time
q = Qx.Qubit.new()
  |> Qx.Qubit.h()
  |> Qx.Qubit.z()
  |> Qx.Qubit.show_state()

IO.puts(q.state)  # "0.707|0⟩ - 0.707|1⟩"
IO.inspect(q.probabilities)  # [{"|0⟩", 0.5}, {"|1⟩", 0.5}]

# 🆕 Using new constructors
q = Qx.Qubit.from_basis(1)         # Create |1⟩ directly
  |> Qx.Qubit.h()

# 🆕 Create from Bloch sphere (theta=π/2, phi=0 gives |+⟩)
q = Qx.Qubit.from_bloch(:math.pi() / 2, 0)
  |> Qx.Qubit.show_state()

# Chain multiple operations
final_state = Qx.Qubit.new()
  |> Qx.Qubit.rx(:math.pi() / 4)
  |> Qx.Qubit.ry(:math.pi() / 3)
  |> Qx.Qubit.rz(:math.pi() / 6)
  |> Qx.Qubit.show_state()
```

**Calculation Mode (Multi-Qubit Register):**
```elixir
# Create a Bell state in real-time
reg = Qx.Register.new(2)
  |> Qx.Register.h(0)
  |> Qx.Register.cx(0, 1)
  |> Qx.Register.show_state()

# Output shows entangled state:
# %{
#   state: "0.707|00⟩ + 0.707|11⟩",
#   amplitudes: [{"|00⟩", "0.707+0.000i"}, {"|01⟩", "0.000+0.000i"}, ...],
#   probabilities: [{"|00⟩", 0.5}, {"|01⟩", 0.0}, {"|10⟩", 0.0}, {"|11⟩", 0.5}]
# }

# 🆕 Create from basis states
reg = Qx.Register.from_basis_states([0, 1, 0])  # |010⟩ state
  |> Qx.Register.show_state()

# 🆕 Create in equal superposition
reg = Qx.Register.from_superposition(3)  # All 8 states equally likely
  |> Qx.Register.get_probabilities()

# Create register from existing qubits
q1 = Qx.Qubit.new(0.6, 0.8)  # Custom state
q2 = Qx.Qubit.plus()          # |+⟩ state
reg = Qx.Register.new([q1, q2])
  |> Qx.Register.h(0)
  |> Qx.Register.get_probabilities()
```

## Module Structure

The Qx library consists of several modules:

- **`Qx`** - Main API providing convenient functions
- **`Qx.Qubit`** - Calculation mode: Real-time single-qubit manipulation
- **`Qx.Register`** - Calculation mode: Multi-qubit registers with entanglement
- **`Qx.QuantumCircuit`** - Circuit mode: Quantum circuit structure and management
- **`Qx.Operations`** - Quantum gate operations for circuits
- **`Qx.Simulation`** - Circuit execution and simulation engine
- **`Qx.SimulationResult`** - Structured simulation results with helper functions
- **`Qx.Draw`** - Visualization and plotting functions
- **`Qx.Math`** - Core mathematical functions for quantum mechanics
- **`Qx.Validation`** - Input validation with custom exceptions
- **`Qx.Behaviours.QuantumState`** - Behaviour for consistent quantum state APIs

## Calculation Mode vs Circuit Mode

**When to use Calculation Mode (`Qx.Qubit` / `Qx.Register`):**
- Learning quantum computing concepts
- Exploring single or multi-qubit gates and states
- Creating and inspecting entangled states interactively
- Debugging quantum algorithms step-by-step
- Interactive experimentation with immediate feedback
- Immediate state inspection needed at each step

**When to use Circuit Mode (`Qx.create_circuit`):**
- Multi-shot simulations for statistics
- Measurements with classical bit storage
- Conditional operations based on measurements
- Building reusable quantum circuits
- Performance-critical batch simulations
- Exporting to OpenQASM for real hardware

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
