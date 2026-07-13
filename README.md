# Qx - Quantum Computing Simulator for Elixir

[![Hex.pm](https://img.shields.io/hexpm/v/qx_sim.svg)](https://hex.pm/packages/qx_sim)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/qx_sim/)
[![License](https://img.shields.io/hexpm/l/qx_sim.svg)](LICENSE)
[![CI](https://github.com/richarc/qx/actions/workflows/ci.yml/badge.svg)](https://github.com/richarc/qx/actions/workflows/ci.yml)
[![Release](https://github.com/richarc/qx/actions/workflows/release.yml/badge.svg)](https://github.com/richarc/qx/actions/workflows/release.yml)

Qx is a quantum computing simulator built for Elixir that provides an intuitive API for creating and simulating quantum circuits. The primary goal of the project is to enhance my understanding of quantum computing concepts, quantum simulators and the Elixir Nx library. My hope is that it is eventualy valuable for others to learn quantum computing. It supports up to 20 qubits (an arbitrary number that I feel is useful but still below the memory cliff that would occurs around 30 qubits).

## Features

- **Simple API**: Easy-to-use functions for quantum circuit creation and simulation
- **Step-Through Inspection**: Replay any circuit one operation at a time with `Qx.steps/2` and watch the state evolve (great for learning!)
- **Up to 20 Qubits**: Supports quantum circuits with up to 20 qubits
- **Statevector Simulation**: Uses statevector method for accurate quantum state representation
- **Optional Acceleration**: Add EXLA or EMLX backends for speedup (CPU/GPU)
- **Visualization**: Built-in plotting capabilities with SVG and VegaLite support, plus circuit diagram generation
- **Growing Range of Gates**: Supports H, X, Y, Z, S, S†, T, T†, RX, RY, RZ, CNOT, CY, CZ, CP, CRX, CRY, CRZ, SWAP, iSWAP, U (general single-qubit unitary), CSWAP (Fredkin), and Toffoli gates
- **Composite Patterns** (`Qx.Patterns`): Whole-circuit and sub-register helpers (`h_all`, `x_all`, `y_all`, `z_all`, `measure_all`, `cx_chain`), plus state-prep **appenders** — `Qx.bell_pair(qc, q0, q1)` and `Qx.ghz(qc, 1..3)` — that entangle chosen qubits inside a larger circuit. Each `_all` helper accepts an optional list or range — e.g. `Qx.h_all(qc, 0..2)` — and `Qx.barrier/2` spans a list or range of qubits
- **Measurements**: Quantum measurements with classical bit storage; basis-explicit `Qx.measure_x/3`, `Qx.measure_y/3`, `Qx.measure_z/3` for X/Y/Z-basis measurement
- **Conditional Operations**: Mid-circuit measurement with classical feedback for quantum processes like teleportation and error correction
- **OpenQASM 3.0 Round-Trip**: Export Qx circuits to OpenQASM 3.0 and import OpenQASM 3.0 source produced by Qx, Qiskit, or IBM Quantum — directly from the facade: `Qx.to_qasm/2`, `Qx.from_qasm/1`, and `Qx.from_qasm!/1`
- **Remote Execution**: Run circuits on real IBM Quantum hardware via `Qx.Hardware`, with transpilation through the Qx Portal service
- **LiveBook Integration**: Full support with interactive visualizations in LiveBook

## Installation

```elixir
def deps do
  [
    {:qx, "~> 0.11", hex: :qx_sim}
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
    {:qx, github: "richarc/qx", branch: "main"}
  ]
end
```

This installs Qx with the default `Nx.BinaryBackend`, which works on all platforms but is slower for larger quantum circuits (10+ qubits).

> **Want better performance?** See [Performance & Acceleration](#performance--acceleration) to add optional EXLA (CPU/GPU) or EMLX (Apple Silicon GPU) backends.

## Quick Start

```elixir
iex> # Put a qubit in superposition and check the probabilities
iex> qc = Qx.create_circuit(1) |> Qx.h(0)
iex> Qx.get_probabilities(qc)
#Nx.Tensor<[0.5, 0.5]>

iex> # Build, measure, and run a Bell state circuit
iex> result =
...>   Qx.create_circuit(2, 2)
...>   |> Qx.h(0)
...>   |> Qx.cx(0, 1)
...>   |> Qx.measure_all()
...>   |> Qx.run()
iex> IO.inspect(result.counts)
%{"00" => 502, "11" => 522}

iex> # Visualize the results
iex> Qx.draw(result)
```

For the complete API, see the [hexdocs](https://hexdocs.pm/qx_sim/Qx.html).

## Getting Started with LiveBook

[LiveBook](https://livebook.dev/) is the perfect environment for interactive quantum computing with Qx. The full tutorial series (quantum states through Grover's search, as downloadable notebooks) lives on the Qx Portal at [qxquantum.com](https://www.qxquantum.com) — it is the maintained home for learning material, and this repo deliberately carries no copies. To start a notebook of your own, add this in the setup cell:

```elixir
Mix.install([
  {:qx, "~> 0.11", hex: :qx_sim},
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

result = Qx.run(circuit, shots: 1000)
Qx.draw_counts(result)
```

**Tips for LiveBook users:**
- Start with the basic setup for learning and small circuits, add [acceleration](#livebook-acceleration-snippets) when needed
- Use `Qx.steps/2` to walk a circuit one operation at a time; each step prints as a readable state line
- `Qx.draw_counts/1` returns VegaLite specs that render beautifully in LiveBook
- Use `tap_state/2` and `tap_probabilities/2` in pipelines for immediate feedback


## Inspecting States

Circuits are recipes. Gates are recorded as you build, then applied when
you run. To watch the state change gate by gate, step through the
circuit with `Qx.steps/2`:

```elixir
Qx.create_circuit(2)
|> Qx.h(0)
|> Qx.cx(0, 1)
|> Qx.steps()
|> Enum.each(&IO.inspect/1)
# #Qx.Step<0: h(0)  0.707|00⟩ + 0.707|10⟩>
# #Qx.Step<1: cx(0, 1)  0.707|00⟩ + 0.707|11⟩>
```

See [Step Through a Circuit](#step-through-a-circuit) for measurements,
trajectories, and seeding. `Qx.Step.show/1` gives the full display map
of any step: Dirac string, amplitudes, probabilities.

### Upgrading from calc mode

Earlier releases documented a second, eager way to apply gates (calc
mode: Qx.Qubit / Qx.Register). Those modules still work, so old
notebooks keep running. But they're internal now: hidden from the docs,
no stability guarantee. The stepper covers the same ground:

```elixir
# before (calc mode)
Qx.Qubit.new() |> Qx.Qubit.h() |> Qx.Qubit.show_state()

# now (circuit mode + stepper)
Qx.create_circuit(1) |> Qx.h(0) |> Qx.steps() |> Enum.at(-1) |> Qx.Step.show()
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
result = Qx.run(qc, shots: 1000)  # 1000 measurement shots

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
  |> Qx.run(shots: 1000)
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

result = Qx.run(qc, shots: 1000)
# Qubit 2 now contains the teleported state!
```

### Step Through a Circuit

`Qx.steps/1` turns a circuit into a lazy stream of `Qx.Step` structs, one per
executed operation: the operation, the statevector right after it, and the
classical bits so far. Printing the steps of the teleportation circuit above
shows the whole story, collapse and corrections included:

```elixir
qc |> Qx.steps(seed: 42) |> Enum.each(fn step -> IO.puts(inspect(step)) end)
# #Qx.Step<0: x(0)  1.000|100⟩  cbits: [0, 0, 0]>
# #Qx.Step<1: h(1)  0.707|100⟩ + 0.707|110⟩  cbits: [0, 0, 0]>
# #Qx.Step<2: cx(1, 2)  0.707|100⟩ + 0.707|111⟩  cbits: [0, 0, 0]>
# #Qx.Step<3: cx(0, 1)  0.707|101⟩ + 0.707|110⟩  cbits: [0, 0, 0]>
# #Qx.Step<4: h(0)  0.500|001⟩ + 0.500|010⟩ - 0.500|101⟩ - 0.500|110⟩  cbits: [0, 0, 0]>
# #Qx.Step<5: measure q0 → c0 ⇒ 0.707|001⟩ + 0.707|010⟩  cbits: [0, 0, 0]>
# #Qx.Step<6: measure q1 → c1 ⇒ 1.000|010⟩  cbits: [0, 1, 0]>
# #Qx.Step<7: c_if(c1==1) x(2) taken  1.000|011⟩  cbits: [0, 1, 0]>
# #Qx.Step<8: c_if(c0==1) not_taken  1.000|011⟩  cbits: [0, 1, 0]>
# #Qx.Step<9: measure q2 → c2 ⇒ 1.000|011⟩  cbits: [0, 1, 1]>
```

Measurement makes a circuit stochastic, so each pass through the stream
samples one fresh trajectory. The `seed:` option pins the trajectory down
for slides, tests, and teaching material; it never touches your process's
random state.

For the full display map of any step (Dirac string, amplitudes,
probabilities), use `Qx.Step.show/1`. See `Qx.steps/2` for the trajectory
semantics and options.

## Examples

### Bell State

```elixir
result =
  Qx.create_circuit(2, 2)
  |> Qx.h(0)
  |> Qx.cx(0, 1)
  |> Qx.measure_all()
  |> Qx.run(shots: 1000)

IO.inspect(result.counts)
# => %{"00" => ~500, "11" => ~500}
Qx.draw_counts(result)
```

### GHZ-3 State (using `Qx.Patterns`)

```elixir
# Linear CNOT cascade + bulk measurement using Qx.Patterns helpers
qc = Qx.create_circuit(3, 3)
     |> Qx.h(0)                    # Put qubit 0 in superposition
     |> Qx.cx_chain([0, 1, 2])     # CX(0,1) ; CX(1,2)
     |> Qx.measure_all()           # Measure every qubit into its bit

result = Qx.run(qc, shots: 1000)
IO.inspect(result.counts)
# => %{"000" => ~500, "111" => ~500}
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

result = Qx.run(qc, shots: 1000)

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
Qx.draw_histogram(probs)
```

**Step by step:**
```elixir
# Watch the state change after each gate
qc = Qx.create_circuit(1)
     |> Qx.h(0)
     |> Qx.z(0)

qc |> Qx.steps() |> Enum.each(&IO.inspect/1)
# #Qx.Step<0: h(0)  0.707|0⟩ + 0.707|1⟩>
# #Qx.Step<1: z(0)  0.707|0⟩ - 0.707|1⟩>

# Full display map of the final state
state_info = qc |> Qx.steps() |> Enum.at(-1) |> Qx.Step.show()
IO.puts(state_info.state)  # "0.707|0⟩ - 0.707|1⟩"
IO.inspect(state_info.probabilities)  # [{"|0⟩", 0.5}, {"|1⟩", 0.5}]
```

## Visualization

Qx's visualization functions each return one artifact type that works everywhere: VegaLite chart specs, and SVG/table artifact structs that render themselves in Livebook (see "Using Qx outside Livebook" below for standalone use).

**Results visualization:**

```elixir
result = Qx.bell_state() |> Qx.run(shots: 1000)

Qx.draw(result)                  # Probability distribution (VegaLite spec)
Qx.draw_counts(result)           # Measurement counts (VegaLite spec)
```

Every draw function returns one static artifact type in every
environment. Livebook renders charts through kino_vega_lite and the
SVG/table artifacts through `Kino.Render`; a standalone application
uses the returned value directly (see "Using Qx outside Livebook"
below).

**Circuit diagrams:**

```elixir
circuit = Qx.create_circuit(2, 2)
          |> Qx.h(0)
          |> Qx.cx(0, 1)
          |> Qx.measure(0, 0)
          |> Qx.measure(1, 1)

image = Qx.draw_circuit(circuit, "Bell State")
File.write!("bell_state.svg", image.svg)
```

In Livebook a cell that simply returns a circuit renders the diagram
automatically.

Circuit diagrams support all quantum gates with proper IEEE notation, parametric gates with displayed angles, multi-qubit gates, barriers, and measurements with classical bit connections.

**Bloch sphere (single qubit):**

```elixir
Qx.create_circuit(1) |> Qx.h(0) |> Qx.get_state() |> Qx.draw_bloch()
```

**Probability histograms:**

```elixir
probs = Qx.get_probabilities(circuit)
Qx.draw_histogram(probs)     # VegaLite spec
```

### Using Qx outside Livebook

Everything above works identically in a Mix application or a plain
script; the difference is what you do with the returned artifact:

| You have | In Livebook | Standalone |
|---|---|---|
| `VegaLite.t()` (charts) | renders via kino_vega_lite | feed it to any Vega renderer |
| `Qx.Draw.Image` (Bloch, circuit) | renders inline | `File.write!("out.svg", image.svg)` |
| `Qx.Draw.StateTable` | renders as a table | `table.text` / `.markdown` / `.html` |

The chart functions need the optional `:vega_lite` dependency and
raise `Qx.MissingDependencyError` naming the fix when it's absent.
You never add `:kino` yourself outside Livebook — the rich rendering
comes from `Kino.Render` implementations that activate only when
Livebook's runtime provides Kino.

## Importing OpenQASM

Qx can read OpenQASM 3.0 source produced by itself, by Qiskit, or by IBM Quantum. Combined with `Qx.to_qasm/1` this provides round-trip interoperability, straight from the facade.

### Import a complete program

```elixir
qasm = """
OPENQASM 3.0;
include "stdgates.inc";
qubit[2] q;
bit[2] c;
h q[0];
cx q[0], q[1];
c[0] = measure q[0];
c[1] = measure q[1];
"""

{:ok, circuit} = Qx.from_qasm(qasm)
result = Qx.run(circuit, shots: 1024)
```

Errors come back as typed exceptions:

* `Qx.QasmParseError` — grammar/syntax problems (with `:line`, `:column`, `:snippet`)
* `Qx.QasmUnsupportedError` — valid QASM that uses a feature outside the supported subset (multi-register, gate modifiers, `else`, …)

`from_qasm!/1` is the bang variant.

### Import a `gate` definition as an Elixir function

For storing user-defined gates as reusable circuit-transforming functions (e.g. in [qxportal](https://github.com/richarc/qxportal)), use `from_qasm_function/1`:

```elixir
qasm = """
OPENQASM 3.0;
include "stdgates.inc";
gate bell a, b {
  h a;
  cx a, b;
}
"""

{:ok, %{name: "bell", arity: 3, source: source}} =
  Qx.Export.OpenQASM.from_qasm_function(qasm)

# source is a self-contained module, e.g.
#   defmodule Qx.Generated.Bell_a1b2c3 do
#     def bell(circuit, a, b) do
#       circuit
#       |> Qx.h(a)
#       |> Qx.cx(a, b)
#     end
#   end

# Compile it and call the generated module directly — Code.compile_string/1
# hands back the module atom (interned safely, only when the module loads):
[{mod, _bin}] = Code.compile_string(source)
new_circuit = mod.bell(Qx.create_circuit(2), 0, 1)

# `module` in the result map is the module *name as a string* (for display or
# storage). Don't turn it into an atom yourself for untrusted input — eagerly
# interning one atom per incoming program risks atom-table exhaustion.
```

The signature is `(circuit, params…, qubits…)` — circuit first, then declared parameters in source order, then qubit arguments in source order.

### Supported subset

See `Qx.Export.OpenQASM` module documentation for the full list of supported gates, decompositions, and explicitly-excluded features.

## Running on IBM Quantum Hardware

Qx can submit circuits directly to IBM Quantum hardware via `Qx.Hardware`. Circuits are exported to OpenQASM 3.0, transpiled through the qxportal service, submitted to IBM, and results are returned as `Qx.SimulationResult` structs.

### Prerequisites

1. A [qxportal](https://qxquantum.com) account and API token.
2. An IBM Cloud account with the Quantum service enabled — you'll need:
   - IBM Cloud API key
   - Quantum service CRN (Cloud Resource Name)
   - Region (e.g. `"us-east"`)

### Setup

The simplest path uses environment variables and `Qx.Hardware.Config.from_env!/1`:

```bash
export QX_PORTAL_URL=https://api.qxquantum.com
export QX_PORTAL_TOKEN=<your qxportal token>
export QX_IBM_API_KEY=<your IBM Cloud API key>
export QX_IBM_CRN=<your IBM Quantum service CRN>
export QX_IBM_REGION=us-east
export QX_IBM_BACKEND=ibm_brisbane
```

```elixir
config = Qx.Hardware.Config.from_env!()
```

Or construct the struct directly:

```elixir
{:ok, config} =
  Qx.Hardware.Config.new(
    portal_url: "https://api.qxquantum.com",
    portal_token: System.fetch_env!("QX_PORTAL_TOKEN"),
    ibm_api_key: System.fetch_env!("QX_IBM_API_KEY"),
    ibm_crn: System.fetch_env!("QX_IBM_CRN"),
    ibm_region: "us-east",
    backend: "ibm_brisbane",
    optimization_level: 1,
    shots: 4096
  )
```

### Run a Circuit on Hardware

```elixir
circuit =
  Qx.QuantumCircuit.new(2, 2)
  |> Qx.h(0)
  |> Qx.cx(0, 1)
  |> Qx.measure(0, 0)
  |> Qx.measure(1, 1)

{:ok, result} = Qx.Hardware.run(circuit, config, on_status: &IO.inspect/1)

IO.inspect(result.counts)
# => %{"00" => 2050, "11" => 2046}  (approximately)
```

`Qx.Hardware.run/3` is synchronous: it blocks until the IBM job reaches a terminal status. Status callback events fire at each pipeline stage (authentication, transpile, submit, poll, results).

### Lower-Level Entry Points

  * `Qx.Hardware.submit_qasm/3` — submit a hand-authored OpenQASM 3.0 program.
  * `Qx.Hardware.transpile/3` — transpile only (no submission), useful for inspection.
  * `Qx.Hardware.list_backends/2` — enumerate backends visible to the configured account.
  * `Qx.Hardware.cancel/3` — best-effort job cancellation.

### Privacy invariant

`Qx.Hardware` uses two independent HTTP clients (`Qx.Hardware.Portal` for qxportal, `Qx.Hardware.Ibm` for IBM Cloud). The portal token never reaches IBM, and the IBM API key never reaches the portal — both clients read only their own fields from the shared `Qx.Hardware.Config`.

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
    {:qx, "~> 0.11", hex: :qx_sim},
    {:exla, "~> 0.12"}  # Add this line (match Qx's Nx version)
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
    {:qx, "~> 0.11", hex: :qx_sim},
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
  {:qx, "~> 0.11", hex: :qx_sim},
  {:exla, "~> 0.12"},
  {:kino, "~> 0.12"},
  {:vega_lite, "~> 0.1.11"},
  {:kino_vega_lite, "~> 0.1.11"}
])

Application.put_env(:nx, :default_backend, EXLA.Backend)
```

**EMLX GPU (Apple Silicon):**
```elixir
Mix.install([
  {:qx, "~> 0.11", hex: :qx_sim},
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
  {:qx, "~> 0.11", hex: :qx_sim},
  {:exla, "~> 0.12"},
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

Exception types include `QubitIndexError`, `StateNormalizationError`, `MeasurementError`, `ConditionalError`, `ClassicalBitError`, `GateError`, `QubitCountError`, and `MissingDependencyError`. See the [hexdocs](https://hexdocs.pm/qx_sim/Qx.html) for details.

## Requirements & Limitations

- Elixir 1.18+, Nx 0.12+
- Optional: VegaLite 0.1+ (chart functions only), EXLA 0.12+ or EMLX for acceleration
- Maximum 20 qubits
- Statevector simulation only (no density matrix or noise modeling)

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned features and the strategic direction of Qx.

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

Current version: 0.10.1

For detailed API documentation, see the [hexdocs](https://hexdocs.pm/qx_sim/Qx.html).
