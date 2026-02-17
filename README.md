# Qx - Quantum Computing Simulator for Elixir

[![Hex.pm](https://img.shields.io/hexpm/v/qx_sim.svg)](https://hex.pm/packages/qx_sim)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/qx_sim/)
[![License](https://img.shields.io/hexpm/l/qx_sim.svg)](LICENSE)
[![CI](https://github.com/richarc/qx/actions/workflows/ci.yml/badge.svg)](https://github.com/richarc/qx/actions/workflows/ci.yml)
[![Release](https://github.com/richarc/qx/actions/workflows/release.yml/badge.svg)](https://github.com/richarc/qx/actions/workflows/release.yml)

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
- **Remote Execution**: Run circuits on real quantum hardware via QxServer, a standalone backend service supporting IBM Quantum and other providers
- **LiveBook Integration**: Full support with interactive visualizations in LiveBook

## Installation

```elixir
def deps do
  [
    {:qx_sim, "~> 0.4.0"}
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

> **Want better performance?** See [Performance & Acceleration](#performance--acceleration) to add optional EXLA (CPU/GPU) or EMLX (Apple Silicon GPU) backends.

## Quick Start

```elixir
iex> # Create a qubit and put it in superposition
iex> q = Qx.Qubit.new() |> Qx.Qubit.h()
iex> Qx.Qubit.measure_probabilities(q)
#Nx.Tensor<[0.5, 0.5]>

iex> # Build and run a Bell state circuit
iex> result = Qx.bell_state() |> Qx.run()
iex> IO.inspect(result.counts)
%{"00" => 512, "11" => 512}

iex> # Visualize the results
iex> Qx.draw(result)
```

For the complete API, see the [hexdocs](https://hexdocs.pm/qx_sim/Qx.html).

## Getting Started with LiveBook

[LiveBook](https://livebook.dev/) is the perfect environment for interactive quantum computing with Qx. Create a new notebook and add this in the setup cell:

```elixir
Mix.install([
  {:qx, "~> 0.4.0", hex: :qx_sim},
  {:kino, "~> 0.12"},
  {:vega_lite, "~> 0.1.11"},
  {:kino_vega_lite, "~> 0.1.11"}
])
```

For interactive guides and tutorials, visit [qxquantum.com/guides](https://www.qxquantum.com/guides).

Try creating a Bell state and visualizing it:

```elixir
circuit = Qx.create_circuit(2, 2)
          |> Qx.h(0)
          |> Qx.cx(0, 1)
          |> Qx.measure(0, 0)
          |> Qx.measure(1, 1)

result = Qx.run(circuit, 1000)
Qx.draw_counts(result)
```

**Tips for LiveBook users:**
- Start with the basic setup for learning and small circuits, add [acceleration](#livebook-acceleration-snippets) when needed
- Use Calculation Mode (`Qx.Qubit` / `Qx.Register`) for interactive exploration
- `Qx.draw_counts/1` returns VegaLite specs that render beautifully in LiveBook
- Use `tap_state/2` and `tap_probabilities/2` in pipelines for immediate feedback


## Understanding the Two Modes

Qx offers two ways to work with quantum states:

**Calculation Mode** (`Qx.Qubit` / `Qx.Register`): Gates apply immediately and you can inspect state at any step. Best for learning, debugging, and interactive exploration.

**Circuit Mode** (`Qx.create_circuit`): Build a circuit description first, then execute it with `Qx.run/2`. Best for multi-shot simulations, measurements with classical feedback, exporting to OpenQASM, and running on real hardware.

| | Calculation Mode | Circuit Mode |
|---|---|---|
| Gates apply | Immediately | On `Qx.run/2` |
| State inspection | Anytime | Before measurements only |
| Measurements | Probabilities only | Full measurement + classical bits |
| Multi-shot | No | Yes |
| Hardware export | No | Yes (OpenQASM) |

## Calculation Mode

### Single Qubits (Qx.Qubit)

Create qubits and apply gates in real-time:

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

Qubits can be created from various starting points: `Qx.Qubit.new()` for |0⟩, `Qx.Qubit.one()` for |1⟩, `Qx.Qubit.plus()` / `Qx.Qubit.minus()` for superposition states, or `Qx.Qubit.from_bloch(theta, phi)` for arbitrary Bloch sphere coordinates.

#### Pipeline Patterns & Debugging

**Transformation operations** return qubits and continue the pipeline:
```elixir
result = Qx.Qubit.new()
  |> Qx.Qubit.h()
  |> Qx.Qubit.x()
  |> Qx.Qubit.ry(:math.pi() / 4)
```

**`tap_state/2`** inspects state without breaking the chain:
```elixir
result = Qx.Qubit.new()
  |> Qx.Qubit.h()
  |> Qx.Qubit.tap_state(label: "After Hadamard")  # Prints state, returns qubit
  |> Qx.Qubit.x()
  |> Qx.Qubit.tap_state(label: "After X gate")    # Prints state, returns qubit
```

**Terminal operations** return data and end the pipeline:
```elixir
state_info = Qx.Qubit.new()
  |> Qx.Qubit.h()
  |> Qx.Qubit.x()
  |> Qx.Qubit.show_state()  # Returns map with state data

IO.puts(state_info.state)  # "0.707|0⟩ - 0.707|1⟩"
```

### Multi-Qubit Registers (Qx.Register)

Registers support multi-qubit gates and entanglement with the same immediate-apply behavior:

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

# Create in equal superposition
reg = Qx.Register.from_superposition(3)  # All 8 states equally likely

# Create register from existing qubits
q1 = Qx.Qubit.new(0.6, 0.8)  # Custom state
q2 = Qx.Qubit.plus()          # |+⟩ state
reg = Qx.Register.new([q1, q2])
  |> Qx.Register.h(0)
```

## Circuit Mode

### Building & Running Circuits

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

The `Qx.run/2` function returns a `SimulationResult` struct with helper functions:

```elixir
{most_common, count} = Qx.SimulationResult.most_frequent(result)
outcomes = Qx.SimulationResult.outcomes(result)
prob = Qx.SimulationResult.probability(result, "00")
```

For circuits without measurements, you can inspect the quantum state directly:

```elixir
state = Qx.get_state(circuit)
probs = Qx.get_probabilities(circuit)
```

Pipeline-friendly tap functions allow inspecting circuits during construction:

```elixir
result = Qx.create_circuit(2)
  |> Qx.h(0)
  |> Qx.tap_state(&IO.inspect(&1, label: "State after H"))
  |> Qx.cx(0, 1)
  |> Qx.tap_probabilities(fn p -> IO.puts("Bell state created!") end)
  |> Qx.run(1000)
```

### Conditional Operations & Mid-Circuit Measurement

`Qx.c_if/4` applies gates conditionally based on classical bit values, enabling quantum teleportation, error correction, and adaptive algorithms:

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

## Examples

### Bell State

```elixir
result = Qx.bell_state() |> Qx.run(1000)
IO.inspect(result.counts)
# => %{"00" => ~500, "11" => ~500}
Qx.draw_counts(result)
```

### Quantum Teleportation

```elixir
# Teleport |1⟩ state from qubit 0 to qubit 2
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

result = Qx.run(qc, 1000)

# Analyze results
{most_common, count} = Qx.SimulationResult.most_frequent(result)
IO.puts("Most frequent: #{most_common} (#{count} times)")
# All outcomes should have rightmost bit = 1 (successful teleportation)

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

**Calculation Mode:**
```elixir
# Create and inspect qubit states in real-time
q = Qx.Qubit.new()
  |> Qx.Qubit.h()
  |> Qx.Qubit.z()

state_info = Qx.Qubit.show_state(q)
IO.puts(state_info.state)  # "0.707|0⟩ - 0.707|1⟩"
IO.inspect(state_info.probabilities)  # [{"|0⟩", 0.5}, {"|1⟩", 0.5}]

# Create from Bloch sphere (theta=π/2, phi=0 gives |+⟩)
q = Qx.Qubit.from_bloch(:math.pi() / 2, 0)
Qx.Qubit.show_state(q)

# Chain rotation gates
q = Qx.Qubit.new()
  |> Qx.Qubit.rx(:math.pi() / 4)
  |> Qx.Qubit.ry(:math.pi() / 3)
  |> Qx.Qubit.rz(:math.pi() / 6)

Qx.Qubit.show_state(q)
```

## Visualization

Qx provides several visualization functions that work in both LiveBook (VegaLite) and standalone (SVG) environments.

**Results visualization:**

```elixir
result = Qx.bell_state() |> Qx.run(1000)

Qx.draw(result)                  # Probability distribution (VegaLite)
Qx.draw(result, format: :svg)    # Probability distribution (SVG)
Qx.draw_counts(result)           # Measurement counts
```

**Circuit diagrams:**

```elixir
circuit = Qx.create_circuit(2, 2)
          |> Qx.h(0)
          |> Qx.cx(0, 1)
          |> Qx.measure(0, 0)
          |> Qx.measure(1, 1)

svg = Qx.Draw.circuit(circuit, "Bell State")
File.write!("bell_state.svg", svg)
```

Circuit diagrams support all quantum gates with proper IEEE notation, parametric gates with displayed angles, multi-qubit gates, barriers, and measurements with classical bit connections.

**Bloch sphere (Calculation Mode):**

```elixir
Qx.Qubit.new() |> Qx.Qubit.h() |> Qx.Qubit.draw_bloch()
```

**Probability histograms:**

```elixir
probs = Qx.get_probabilities(circuit)
Qx.histogram(probs)
```

## Running on Quantum Hardware via QxServer

Qx can submit circuits to real quantum hardware through [QxServer](https://github.com/richarc/qx_server), a standalone backend service. Circuits are exported to OpenQASM 3.0, submitted via HTTP, and results are returned as `Qx.SimulationResult` structs.

### Prerequisites

1. A running QxServer instance (see [qx_server](https://github.com/richarc/qx_server))
2. Provider credentials configured on the server (e.g., IBM Quantum API key)

### Setup

```elixir
config = Qx.Remote.Config.new!(
  url: "http://localhost:4040",
  api_key: System.get_env("QX_SERVER_API_KEY")
)
```

### Run a Circuit on Hardware

```elixir
# Build a Bell state circuit
circuit = Qx.create_circuit(2, 2)
  |> Qx.h(0)
  |> Qx.cx(0, 1)
  |> Qx.measure(0, 0)
  |> Qx.measure(1, 1)

# Submit to hardware and wait for results
{:ok, result} = Qx.Remote.run(circuit, config,
  backend: "ibm_fez",
  shots: 4096
)

IO.inspect(result.counts)
# => %{"00" => 2048, "11" => 2048}  (approximately)
```

### Step-by-Step Execution

For more control, submit and await separately:

```elixir
# Submit (non-blocking)
{:ok, job} = Qx.Remote.submit(circuit, config, backend: "ibm_fez")
IO.puts("Job submitted: #{job["job_id"]}")

# Poll with status callback
{:ok, result} = Qx.Remote.await(job["job_id"], config,
  on_status: fn status -> IO.puts("Status: #{status["status"]}") end
)
```

### List Available Backends

```elixir
{:ok, backends} = Qx.Remote.list_backends(config, provider: "ibm")

for b <- backends do
  IO.puts("#{b["name"]} - #{b["qubits"]} qubits")
end
```

## Performance & Acceleration

Qx works out-of-the-box with `Nx.BinaryBackend` on all platforms, but you can add acceleration backends for significant speedups, especially for circuits with 10+ qubits.

### Choosing a Backend

| Backend | Platform | Compilation Required |
|---------|----------|---------------------|
| **Nx.BinaryBackend** | All | No (default) |
| **EXLA (CPU)** | All | Yes (C++ compiler needed) |
| **EXLA (CUDA)** | Linux/Windows + NVIDIA GPU | Yes + CUDA Toolkit |
| **EXLA (ROCm)** | Linux + AMD GPU | Yes + ROCm |
| **EMLX (Metal)** | macOS Apple Silicon | No (precompiled) |

### EXLA CPU (Recommended)

**Best for**: All platforms, no GPU required

EXLA provides significant speedup through XLA's LLVM optimizations.

**Prerequisites:**
- **macOS:** `xcode-select --install`
- **Linux (Debian/Ubuntu):** `sudo apt install build-essential`
- **Linux (Fedora/RHEL):** `sudo dnf groupinstall "Development Tools"`
- **Windows:** [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/) with C++ support, or [WSL2](https://docs.microsoft.com/en-us/windows/wsl/install) (recommended)

**Step 1:** Add EXLA to `mix.exs`:

```elixir
def deps do
  [
    {:qx_sim, "~> 0.4.0"},
    {:exla, "~> 0.10"}  # Add this line
  ]
end
```

**Step 2:** Install and configure:

```bash
mix deps.get
```

Create or edit `config/config.exs`:

```elixir
import Config
config :nx, :default_backend, EXLA.Backend
```

**Note**: First-time EXLA compilation takes several minutes. See [EXLA installation guide](https://hexdocs.pm/exla/EXLA.html) if compilation fails.

**Step 3:** Verify:

```elixir
iex> Nx.default_backend()
EXLA.Backend
```

---

### EXLA + NVIDIA GPU (CUDA)

**Best for**: Linux/Windows with NVIDIA GPU

**Step 1:** Install [CUDA Toolkit](https://developer.nvidia.com/cuda-downloads) 11.8 or 12.0 and verify with `nvcc --version`.

**Step 2:** Set environment variable in your shell profile:

```bash
# For CUDA 11.x
export XLA_TARGET=cuda118

# For CUDA 12.x
export XLA_TARGET=cuda120
```

**Step 3:** Add EXLA to `mix.exs` (same as CPU above) and run `mix deps.get`.

**Step 4:** Configure in `config/config.exs`:

```elixir
import Config
config :nx, :default_backend, {EXLA.Backend, client: :cuda}
```

**Step 5:** Verify GPU is detected:

```elixir
iex> :cuda in EXLA.Client.get_supported_platforms()
true
```

**Troubleshooting:** If CUDA is not found, ensure `XLA_TARGET` is set correctly (`echo $XLA_TARGET`). For runtime errors, update NVIDIA drivers (`nvidia-smi` to check).

---

### EXLA + AMD GPU (ROCm)

**Best for**: Linux with AMD GPU

**Step 1:** Install [ROCm](https://rocm.docs.amd.com/) 5.4+ and verify with `rocm-smi`.

**Step 2:** Add EXLA to `mix.exs` (same as CPU above) and run `mix deps.get`.

**Step 3:** Configure in `config/config.exs`:

```elixir
import Config
config :nx, :default_backend, {EXLA.Backend, client: :rocm}
```

---

### EMLX + Apple Silicon (Metal)

**Best for**: macOS M1/M2/M3/M4, no compilation required

**Note**: EXLA does not support Metal GPU acceleration. For CPU-only acceleration on Apple Silicon, use EXLA CPU instead.

**Step 1:** Add EMLX to `mix.exs`:

```elixir
def deps do
  [
    {:qx_sim, "~> 0.4.0"},
    {:emlx, github: "elixir-nx/emlx", branch: "main"}  # Add this line
  ]
end
```

**Step 2:** `mix deps.get` (EMLX downloads precompiled binaries automatically).

**Step 3:** Configure in `config/config.exs`:

```elixir
import Config
config :nx, :default_backend, {EMLX.Backend, device: :gpu}
```

**Notes:**
- Metal does not support 64-bit floats, but Qx uses Complex64 which is fully supported
- For CPU-only acceleration on Apple Silicon, use EXLA CPU instead

---

### Runtime Backend Selection

Starting with Qx v0.3.0, you can select backends at runtime without compile-time configuration:

```elixir
qc = Qx.create_circuit(10) |> Qx.h(0) |> Qx.cx(0, 1)

# Run with EXLA backend (even if binary backend is default)
result = Qx.run(qc, backend: EXLA.Backend)

# Run with EXLA + CUDA
result = Qx.run(qc, backend: {EXLA.Backend, client: :cuda})

# Run with EMLX on Apple Silicon
result = Qx.run(qc, backend: {EMLX.Backend, device: :gpu})

# Combine with other options
result = Qx.run(qc, backend: EXLA.Backend, shots: 2048)
```

The `:backend` option also works with `Qx.get_state/2` and `Qx.get_probabilities/2`.

You can combine both approaches: set a default in `config/config.exs` and override it at runtime when needed.

---

### LiveBook Acceleration Snippets

For LiveBook, add the acceleration backend to your `Mix.install` call:

**EXLA CPU (all platforms):**
```elixir
Mix.install([
  {:qx, "~> 0.4.0", hex: :qx_sim},
  {:exla, "~> 0.10"},
  {:kino, "~> 0.12"},
  {:vega_lite, "~> 0.1.11"},
  {:kino_vega_lite, "~> 0.1.11"}
])

Application.put_env(:nx, :default_backend, EXLA.Backend)
```

**EMLX GPU (Apple Silicon):**
```elixir
Mix.install([
  {:qx, "~> 0.4.0", hex: :qx_sim},
  {:emlx, github: "elixir-nx/emlx", branch: "main"},
  {:kino, "~> 0.12"},
  {:vega_lite, "~> 0.1.11"},
  {:kino_vega_lite, "~> 0.1.11"}
])

Application.put_env(:nx, :default_backend, {EMLX.Backend, device: :gpu})
```

**EXLA CUDA (NVIDIA GPU):** Requires `XLA_TARGET` env var set (see [CUDA setup](#exla--nvidia-gpu-cuda)).
```elixir
Mix.install([
  {:qx, "~> 0.4.0", hex: :qx_sim},
  {:exla, "~> 0.10"},
  {:kino, "~> 0.12"},
  {:vega_lite, "~> 0.1.11"},
  {:kino_vega_lite, "~> 0.1.11"}
])

Application.put_env(:nx, :default_backend, {EXLA.Backend, client: :cuda})
```

## Error Handling

Qx provides domain-specific exceptions for clear error messages:

```elixir
try do
  circuit |> Qx.h(999)
rescue
  Qx.QubitIndexError -> IO.puts("Invalid qubit index!")
  Qx.GateError -> IO.puts("Gate operation failed!")
end
```

Exception types include `QubitIndexError`, `StateNormalizationError`, `MeasurementError`, `ConditionalError`, `ClassicalBitError`, `GateError`, `QubitCountError`, and `RemoteError`. See the [hexdocs](https://hexdocs.pm/qx_sim/Qx.html) for details.

## Requirements & Limitations

- Elixir 1.18+, Nx 0.10+, VegaLite 0.1+
- Optional: EXLA 0.10+ or EMLX 0.2+ for acceleration
- Maximum 20 qubits
- Statevector simulation only (no density matrix or noise modeling)

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and ensure tests pass (`mix test`)
4. Run code quality checks (`mix credo --strict`)
5. Commit and open a Pull Request

For maintainers preparing a release, see [RELEASE.md](RELEASE.md).

## License

This project is licensed under the Apache License 2.0.

## Acknowledgments

- Built with [Nx](https://github.com/elixir-nx/nx) for numerical computations
- Visualization powered by [VegaLite](https://github.com/livebook-dev/vega_lite)
- Inspired by quantum computing frameworks like Qiskit and Cirq

## Version

Current version: 0.4.0

For detailed API documentation, see the [hexdocs](https://hexdocs.pm/qx_sim/Qx.html).
