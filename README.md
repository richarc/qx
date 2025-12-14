# Qx - Quantum Computing Simulator for Elixir

[![Hex.pm](https://img.shields.io/hexpm/v/qx_sim.svg)](https://hex.pm/packages/qx_sim)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/qx_sim/)
[![License](https://img.shields.io/hexpm/l/qx_sim.svg)](LICENSE)

Qx is a quantum computing simulator built for Elixir that provides an intuitive API for creating and simulating quantum circuits. The primary goal of the project is to enhance my understanding of quantum computing concepts, quantum simulators and the Elixir Nx library. My hope is that it is eventualy valuable for others to learn quantum computing. It supports up to 20 qubits (an arbitrary number that I feel is useful but still below the memory cliff that would occurs around 30 qubits).

## Features

- **Two Modes of Operation**:
  - **Circuit Mode**: Build quantum circuits and execute them (traditional workflow)
  - **Calculation Mode**: Apply gates in real-time and inspect states immediately (great for learning!)
- **Simple API**: Easy-to-use functions for quantum circuit creation and simulation
- **Up to 20 Qubits**: Supports quantum circuits with up to 20 qubits
- **Statevector Simulation**: Uses statevector method for accurate quantum state representation
- **Optional Acceleration**: Add EXLA or EMLX backends for speedup (CPU/GPU)
- **Visualization**: Built-in plotting capabilities with SVG and VegaLite support, plus circuit diagram generation
- **Growing Range of Gates**: Supports H, X, Y, Z, S, T, RX, RY, RZ, CNOT, CZ, and Toffoli gates
- **Measurements**: Quantum measurements with classical bit storage
- **Conditional Operations**: Mid-circuit measurement with classical feedback for quantum processes like teleportation and error correction
- **LiveBook Integration**: Full support with interactive visualizations in LiveBook

## Installation

### Basic Installation (All Platforms)

Qx works immediately on any platform without additional acceleration libraries:

```elixir
def deps do
  [
    {:qx_sim, "~> 0.2.3"}
  ]
end
```

Then run:

```bash
mix deps.get
```

Or install from GitHub for the latest development version:

```elixir
def deps do
  [
    {:qx_sim, github: "richarc/qx", branch: "main"}
  ]
end
```

This installs Qx with the default `Nx.BinaryBackend`, which works on all platforms but is slower for larger quantum circuits (10+ qubits).

> **Want better performance?** See [Performance & Acceleration](#performance--acceleration) below to add optional EXLA (CPU/GPU) or EMLX (Apple Silicon GPU) for backend speedup.

## Performance & Acceleration

Qx works out-of-the-box with `Nx.BinaryBackend` on all platforms, but you can add acceleration backends for significant speedups, especially for circuits with 10+ qubits.

### Performance Options

| Backend | Platform | Compilation Required |
|---------|----------|---------------------|
| **Nx.BinaryBackend** | All | No (default) |
| **EXLA (CPU)** | All | Yes (C++ compiler needed) |
| **EXLA (CUDA)** | Linux/Windows + NVIDIA GPU | Yes + CUDA Toolkit |
| **EXLA (ROCm)** | Linux + AMD GPU | Yes + ROCm |
| **EMLX (Metal)** | macOS Apple Silicon | No (precompiled) |

### Choose Your Acceleration Backend

Select the option that matches your platform and needs:

- **[EXLA CPU (All Platforms)](#exla-cpu-acceleration-recommended-for-most-users)** ← Recommended for most users
- **[EXLA + NVIDIA GPU (Linux/Windows)](#exla--nvidia-gpu-cuda)** ← For NVIDIA GPU acceleration
- **[EXLA + AMD GPU (Linux)](#exla--amd-gpu-rocm)** ← For AMD GPU acceleration
- **[EMLX + Apple Silicon GPU (macOS)](#emlx--apple-silicon-gpu-metal)** ← For M1/M2/M3/M4 Macs

---

### EXLA CPU Acceleration (Recommended for Most Users)

**Best for**: All platforms • No GPU required

EXLA provides significant speedup through XLA's LLVM optimizations without requiring GPU hardware.

#### Prerequisites

**macOS:**
```bash
# Install Xcode Command Line Tools
xcode-select --install
```

**Linux (Debian/Ubuntu):**
```bash
sudo apt install build-essential
```

**Linux (Fedora/RHEL):**
```bash
sudo dnf groupinstall "Development Tools"
```

**Windows:**
- Install [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/) with C++ support, OR
- Use [WSL2](https://docs.microsoft.com/en-us/windows/wsl/install) (recommended)

#### Step 1: Add EXLA Dependency

Edit your `mix.exs`:

```elixir
def deps do
  [
    {:qx_sim, "~> 0.2.1"},
    {:exla, "~> 0.10"}  # Add this line
  ]
end
```

#### Step 2: Install Dependencies

```bash
mix deps.get
```

**Note**: First-time EXLA compilation takes several minutes. See [EXLA installation guide](https://hexdocs.pm/exla/EXLA.html) if compilation fails.

#### Step 3: Configure Backend

Create or edit `config/config.exs`:

```elixir
import Config

# Use EXLA with CPU
config :nx, :default_backend, EXLA.Backend
```

#### Step 4: Verify Setup

```bash
iex -S mix
```

```elixir
iex> Nx.default_backend()
EXLA.Backend

iex> # Test with a quantum circuit
iex> Qx.create_circuit(10, 0) |> Qx.h(0) |> Qx.get_state()
# Should execute quickly with EXLA
```

---

### EXLA + NVIDIA GPU (CUDA)

**Best for**: Linux/Windows with NVIDIA GPU

Provides massive acceleration for larger quantum circuits using CUDA.

#### Step 1: Install CUDA Toolkit

Download and install CUDA Toolkit 11.8 or 12.0:
- **[CUDA Downloads](https://developer.nvidia.com/cuda-downloads)**

Verify installation:
```bash
nvcc --version
```

You should see output like: `Cuda compilation tools, release 11.8` or `release 12.0`

#### Step 2: Set Environment Variable

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, or `~/.bash_profile`):

```bash
# For CUDA 11.x
export XLA_TARGET=cuda118

# For CUDA 12.x
export XLA_TARGET=cuda120
```

Then reload your shell:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

#### Step 3: Add EXLA Dependency

Edit your `mix.exs`:

```elixir
def deps do
  [
    {:qx_sim, "~> 0.2.1"},
    {:exla, "~> 0.10"}  # Add this line
  ]
end
```

#### Step 4: Install Dependencies

```bash
mix deps.get
```

**Note**: EXLA will compile with CUDA support (15-45 minutes on first install).

#### Step 5: Configure Backend

Create or edit `config/config.exs`:

```elixir
import Config

# Use EXLA with CUDA GPU
config :nx, :default_backend, {EXLA.Backend, client: :cuda}
```

#### Step 6: Verify GPU Setup

```bash
iex -S mix
```

```elixir
iex> Nx.default_backend()
{EXLA.Backend, [client: :cuda]}

iex> EXLA.Client.get_supported_platforms()
# Should show :cuda in the list

iex> # Check GPU is detected
iex> :cuda in EXLA.Client.get_supported_platforms()
true
```

#### Troubleshooting

- **"CUDA not found"**: Ensure `XLA_TARGET` environment variable is set correctly (check with `echo $XLA_TARGET`)
- **Compilation fails**: Verify CUDA toolkit version matches `XLA_TARGET` value
- **Runtime errors**: Update NVIDIA drivers to latest version (`nvidia-smi` to check current version)
- **Out of memory**: Reduce circuit size or qubit count

---

### EXLA + AMD GPU (ROCm)

**Best for**: Linux with AMD GPU

Provides similar acceleration to CUDA for AMD GPUs on Linux.

#### Step 1: Install ROCm

Follow the official installation guide for your Linux distribution:
- **[ROCm Installation Guide](https://rocm.docs.amd.com/)**

Minimum version: ROCm 5.4 or later

Verify installation:
```bash
rocm-smi
```

#### Step 2: Add EXLA Dependency

Edit your `mix.exs`:

```elixir
def deps do
  [
    {:qx_sim, "~> 0.2.1"},
    {:exla, "~> 0.10"}  # Add this line
  ]
end
```

#### Step 3: Install Dependencies

```bash
mix deps.get
```

**Note**: EXLA will compile with ROCm support (Several minutes on first install).

#### Step 4: Configure Backend

Create or edit `config/config.exs`:

```elixir
import Config

# Use EXLA with ROCm GPU
config :nx, :default_backend, {EXLA.Backend, client: :rocm}
```

#### Step 5: Verify Setup

```bash
iex -S mix
```

```elixir
iex> Nx.default_backend()
{EXLA.Backend, [client: :rocm]}

iex> EXLA.Client.get_supported_platforms()
# Should show :rocm in the list
```

---

### EMLX + Apple Silicon GPU (Metal)

**Best for**: macOS M1/M2/M3/M4 • No compilation required

**Note**: EXLA does not support Metal GPU acceleration. For Apple Silicon GPU acceleration, use EMLX. For CPU-only acceleration on Apple Silicon, use [EXLA CPU](#exla-cpu-acceleration-recommended-for-most-users) instead.

EMLX provides Metal GPU acceleration through Apple's MLX framework, designed specifically for Apple's unified memory architecture.

#### Step 1: Add EMLX Dependency

Edit your `mix.exs`:

```elixir
def deps do
  [
    {:qx_sim, "~> 0.2.1"},
    {:emlx, github: "elixir-nx/emlx", branch: "main"}  # Add this line
  ]
end
```

#### Step 2: Install Dependencies

```bash
mix deps.get
```

**Note**: EMLX automatically downloads precompiled MLX binaries (no compilation needed).

#### Step 3: Configure Backend

Create or edit `config/config.exs`:

```elixir
import Config

# Use EMLX with Metal GPU
config :nx, :default_backend, {EMLX.Backend, device: :gpu}
```

#### Step 4: Verify Setup

```bash
iex -S mix
```

```elixir
iex> Nx.default_backend()
{EMLX.Backend, [device: :gpu]}

iex> # Test with a simple tensor
iex> Nx.tensor([1, 2, 3]) |> IO.inspect()
# Should show EMLX backend in use
```

#### Notes

- Metal does not support 64-bit floats, but Qx uses Complex64 which is fully supported
- EMLX downloads precompiled binaries, so no C++ compiler is needed
- For CPU-only acceleration on Apple Silicon, use EXLA CPU instead (requires compilation but works without GPU)

## Quick Start

### Calculation Mode (Real-Time Gate Application)

```elixir
# Create and manipulate qubits directly - gates apply immediately!
q = Qx.Qubit.new()
  |> Qx.Qubit.h()

Qx.Qubit.show_state(q)
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

## Using Qx with LiveBook

[LiveBook](https://livebook.dev/) is the perfect environment for interactive quantum computing with Qx!

### Basic Setup (No Acceleration)

Create a new LiveBook notebook and add this in the 'setup' cell:

```elixir
Mix.install([
  {:qx_sim, "~> 0.2.1"},
  {:kino, "~> 0.12"},
  {:vega_lite, "~> 0.1.11"},
  {:kino_vega_lite, "~> 0.1.11"}
])
```

This works immediately on all platforms without compilation or acceleration libraries. Best for small circuits (< 10 qubits) and learning.

### Accelerated Setup Options

For better performance with larger circuits, choose the setup that matches your platform:

#### EXLA CPU Acceleration (All Platforms - Recommended)


```elixir
Mix.install([
  {:qx_sim, "~> 0.2.1"},
  {:exla, "~> 0.10"},
  {:kino, "~> 0.12"},
  {:vega_lite, "~> 0.1.11"},
  {:kino_vega_lite, "~> 0.1.11"}
])

# Configure EXLA backend
Application.put_env(:nx, :default_backend, EXLA.Backend)
```

**Prerequisites**: See [EXLA CPU setup](#exla-cpu-acceleration-recommended-for-most-users) for installing C++ compiler.

#### EMLX GPU for Apple Silicon (M1/M2/M3/M4 Macs)

```elixir
Mix.install([
  {:qx_sim, "~> 0.2.1"},
  {:emlx, github: "elixir-nx/emlx", branch: "main"},
  {:kino, "~> 0.12"},
  {:vega_lite, "~> 0.1.11"},
  {:kino_vega_lite, "~> 0.1.11"}
])

# Configure for Metal GPU
Application.put_env(:nx, :default_backend, {EMLX.Backend, device: :gpu})
```

#### EXLA GPU for NVIDIA (Linux/Windows)


**Prerequisites**:
1. Install CUDA Toolkit (see [NVIDIA GPU setup](#exla--nvidia-gpu-cuda))
2. Set `export XLA_TARGET=cuda118` (or `cuda120`) in your shell profile
3. Restart your terminal/shell

```elixir
Mix.install([
  {:qx_sim, "~> 0.2.1"},
  {:exla, "~> 0.10"},
  {:kino, "~> 0.12"},
  {:vega_lite, "~> 0.1.11"},
  {:kino_vega_lite, "~> 0.1.11"}
])

# Configure for CUDA GPU
Application.put_env(:nx, :default_backend, {EXLA.Backend, client: :cuda})
```

#### EXLA GPU for AMD (Linux Only)


**Prerequisites**: Install ROCm (see [AMD GPU setup](#exla--amd-gpu-rocm))

```elixir
Mix.install([
  {:qx_sim, "~> 0.2.1"},
  {:exla, "~> 0.10"},
  {:kino, "~> 0.12"},
  {:vega_lite, "~> 0.1.11"},
  {:kino_vega_lite, "~> 0.1.11"}
])

# Configure for ROCm GPU
Application.put_env(:nx, :default_backend, {EXLA.Backend, client: :rocm})
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

# Create a qubit and apply Hadamard gate
qubit = new() |> h()

# Display the state
show_state(qubit) |> Kino.render()

# Apply more gates and see immediate results
qubit
|> x()
|> show_state()
|> Kino.render()
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

1. **Start Simple**: Begin with the basic setup (no acceleration) for learning and small circuits, then add acceleration when needed

2. **Use Calculation Mode for Learning**: Real-time gate application with `Qx.Qubit` and `Qx.Register` is perfect for understanding quantum mechanics interactively

3. **Leverage Kino Widgets**: Use `Kino.render()` to create interactive controls for gate parameters

4. **Performance**: Add EXLA or EMLX to your Mix.install for better performance with larger circuits (10+ qubits)

5. **Visualization**: `Qx.draw_counts/1` returns VegaLite specs that render beautifully in LiveBook

6. **Debugging**: Use tap functions (`tap_state`, `tap_probabilities`) in pipelines with `IO.inspect` for immediate feedback

### Example LiveBook Notebooks

Check out example notebooks in the repository:
- `examples/livebook/getting_started.livemd` - Basic introduction
- `examples/livebook/quantum_teleportation.livemd` - Complete teleportation tutorial
- `examples/livebook/grovers_algorithm.livemd` - Search algorithm implementation

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

# Show the state
state_info = Qx.Qubit.show_state(q)
IO.puts(state_info.state)  # "0.707|0⟩ - 0.707|1⟩"
IO.inspect(state_info.probabilities)  # [{"|0⟩", 0.5}, {"|1⟩", 0.5}]

# From basis constructors
q = Qx.Qubit.from_basis(1)         # Create |1⟩ directly
  |> Qx.Qubit.h()

# Create from Bloch sphere (theta=π/2, phi=0 gives |+⟩)
q = Qx.Qubit.from_bloch(:math.pi() / 2, 0)
Qx.Qubit.show_state(q)

# Chain multiple operations
q = Qx.Qubit.new()
  |> Qx.Qubit.rx(:math.pi() / 4)
  |> Qx.Qubit.ry(:math.pi() / 3)
  |> Qx.Qubit.rz(:math.pi() / 6)

Qx.Qubit.show_state(q)
```

**Calculation Mode (Multi-Qubit Register):**
```elixir
# Create a Bell state in real-time
reg = Qx.Register.new(2)
  |> Qx.Register.h(0)
  |> Qx.Register.cx(0, 1)

Qx.Register.show_state(reg)
# Output shows entangled state:
# %{
#   state: "0.707|00⟩ + 0.707|11⟩",
#   amplitudes: [{"|00⟩", "0.707+0.000i"}, {"|01⟩", "0.000+0.000i"}, ...],
#   probabilities: [{"|00⟩", 0.5}, {"|01⟩", 0.0}, {"|10⟩", 0.0}, {"|11⟩", 0.5}]
# }

# Create from basis states
reg = Qx.Register.from_basis_states([0, 1, 0])  # |010⟩ state
Qx.Register.show_state(reg)

# Create in equal superposition
reg = Qx.Register.from_superposition(3)  # All 8 states equally likely
Qx.Register.get_probabilities(reg)

# Create register from existing qubits
q1 = Qx.Qubit.new(0.6, 0.8)  # Custom state
q2 = Qx.Qubit.plus()          # |+⟩ state
reg = Qx.Register.new([q1, q2])
  |> Qx.Register.h(0)

Qx.Register.get_probabilities(reg)
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

### Base Requirements
These are the versions I've developed and tested with:

- Elixir 1.18+
- Nx 0.10+ (for numerical computations)
- VegaLite 0.1+ (for visualization)

### Optional Acceleration Dependencies

For better performance, you can add:

- **EXLA 0.10+** - CPU/GPU acceleration via XLA (see [Performance & Acceleration](#performance--acceleration))
- **EMLX 0.2+** - Apple Silicon GPU acceleration via Metal (see [Apple Silicon GPU setup](#emlx--apple-silicon-gpu-metal))

## Limitations

Current version limitations:

- Maximum 20 qubits
- Statevector simulation only (no density matrix)
- Ideal gates only (no noise modeling)

## Running Examples

### For Qx Developers (Cloned Repository)

If you've cloned the Qx repository, you can run examples directly:

```bash
# Run circuit visualization examples
mix run examples/circuit_visualization_example.exs

# Run basic usage examples
elixir examples/basic_usage.exs

# Run conditional gates examples
elixir examples/conditional_gates_example.exs
```

### For Qx Users (Installed as Dependency)

If you've installed Qx as a dependency in your project, **don't run examples from `deps/qx/`**. Instead:

#### Option 1: Copy Examples to Your Project (Recommended)

```bash
# Copy example files to your project
cp deps/qx/examples/*.exs ./

# Run them from your project root
mix run circuit_visualization_example.exs
```

#### Option 2: Use Code Examples in This README

All major features have example code throughout this README that you can copy directly into:
- Your own `.exs` scripts
- IEx sessions (`iex -S mix`)
- LiveBook notebooks (see [Using Qx with LiveBook](#using-qx-with-livebook))

#### Option 3: Use LiveBook Examples

Check out the interactive LiveBook notebooks in the repository:
- `examples/livebook/getting_started.livemd`
- `examples/livebook/quantum_teleportation.livemd`
- `examples/livebook/grovers_algorithm.livemd`

Copy these to your project or open them directly in LiveBook for an interactive experience.

## Testing

Run the test suite:

```bash
mix test
```

## License

This project is licensed under the Apache License 2.0.

## Acknowledgments

- Built with [Nx](https://github.com/elixir-nx/nx) for numerical computations
- Visualization powered by [VegaLite](https://github.com/livebook-dev/vega_lite)
- Inspired by quantum computing frameworks like Qiskit and Cirq

## Version

Current version: 0.2.3

For detailed API documentation, run:

```bash
mix docs
```
