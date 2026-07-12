defmodule Qx do
  @moduledoc """
  Qx - A Quantum Computing Simulator for Elixir

  Qx provides a simple and intuitive API for quantum computing simulations.
  It supports up to 20 qubits with statevector simulation using Nx as the
  computational backend for efficient processing.

  ## Applying gates

  Gate functions like `Qx.h/2` record onto a `Qx.QuantumCircuit`; run the
  finished circuit with `Qx.run/2`.

  Want the state after each operation? `Qx.steps/2` replays the circuit
  one instruction at a time, and `Qx.Step.show/1` turns any step into
  amplitudes plus probabilities.

  Earlier releases also documented a calc mode (eager per-gate state
  evolution, no circuit). Those modules are now an internal engine:
  still present and functional, hidden from these docs, no stability
  guarantee.

  ## Example Usage

      # Create a Bell state circuit
      qc = Qx.create_circuit(2, 2)
      |> Qx.h(0)
      |> Qx.cx(0, 1)
      |> Qx.measure(0, 0)
      |> Qx.measure(1, 1)

      result = Qx.run(qc)
      Qx.draw(result)

  ## Modules

  The Qx library consists of several modules:

  - `Qx` - Main API (this module)
  - `Qx.QuantumCircuit` - Quantum circuit creation and management
  - `Qx.Operations` - Quantum gate operations, including basis-explicit
    measurement (`measure_x`/`measure_y`/`measure_z`) and controlled
    rotations (`cy`, `crx`, `cry`, `crz`)
  - `Qx.Patterns` - Composite circuit-building patterns. Each `_all` helper
    accepts either no second arg (whole-circuit) or a list/range of qubit
    indices (sub-register) — e.g. `Qx.h_all(qc, 0..2)`.
  - `Qx.Simulation` - Circuit execution and simulation
  - `Qx.SimulationResult` - Struct returned by `Qx.run/2` (statevector + counts)
  - `Qx.Step` - One executed operation from `Qx.steps/2` (step-through
    inspection of a running circuit, mid-circuit measurement included)
  - `Qx.Draw` - Visualization of results
  - `Qx.Math` - Core mathematical functions for quantum mechanics
  - `Qx.StateInit` - Basis-state vector constructor
  - `Qx.Export.OpenQASM` - Export circuits to OpenQASM for real quantum hardware
  - `Qx.Hardware` - Run circuits on cloud QPUs (e.g. IBM Quantum)
  - `Qx.Hardware.Config` - Hardware backend configuration (IBM Quantum via qxportal)

  ## Exporting to Real Quantum Hardware

  Qx can export circuits to OpenQASM format for execution on real quantum computers:

      # Create a Bell state circuit
      circuit = Qx.create_circuit(2, 2)
        |> Qx.h(0)
        |> Qx.cx(0, 1)
        |> Qx.measure(0, 0)
        |> Qx.measure(1, 1)

      # Export to OpenQASM 3.0
      qasm = Qx.Export.OpenQASM.to_qasm(circuit)
      File.write!("bell_state.qasm", qasm)

  See `Qx.Export.OpenQASM` for more details and examples.
  """

  alias Qx.{Draw, Operations, Patterns, QuantumCircuit, Simulation}
  alias Qx.Export.OpenQASM

  @type circuit :: QuantumCircuit.t()
  @type simulation_result :: Simulation.simulation_result()

  @doc """
  Creates a new quantum circuit with specified qubits and classical bits.

  ## Parameters
    * `num_qubits` - Number of qubits (1-20 recommended)
    * `num_classical_bits` - Number of classical bits for measurements

  ## Returns

  A new `Qx.QuantumCircuit` initialised in the |0…0⟩ state.

  ## Examples

      iex> qc = Qx.create_circuit(2, 2)
      iex> qc.num_qubits
      2
      iex> qc.num_classical_bits
      2

  ## Raises

    * `Qx.QubitCountError` - If `num_qubits` is not an integer, or is an integer outside the supported range (1..20)
    * `Qx.ClassicalBitError` - If `num_classical_bits` is not a non-negative integer
  """
  @spec create_circuit(pos_integer(), non_neg_integer()) :: circuit()
  defdelegate create_circuit(num_qubits, num_classical_bits), to: QuantumCircuit, as: :new

  @doc """
  Creates a new quantum circuit with only qubits (no classical bits).

  ## Parameters
    * `num_qubits` - Number of qubits (1-20 recommended)

  ## Returns

  A new `Qx.QuantumCircuit` initialised in the |0…0⟩ state.

  ## Examples

      iex> qc = Qx.create_circuit(3)
      iex> qc.num_qubits
      3
      iex> qc.num_classical_bits
      0

  ## Raises

    * `Qx.QubitCountError` - If `num_qubits` is not an integer, or is an integer outside the supported range (1..20)
  """
  @spec create_circuit(pos_integer()) :: circuit()
  defdelegate create_circuit(num_qubits), to: QuantumCircuit, as: :new

  @doc """
  Applies a Hadamard gate to the specified qubit.

  Creates superposition: |0⟩ → (|0⟩ + |1⟩)/√2, |1⟩ → (|0⟩ - |1⟩)/√2

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.h(0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit index is out of range
  """
  @spec h(circuit(), non_neg_integer()) :: circuit()
  defdelegate h(circuit, qubit), to: Operations

  @doc """
  Applies a Pauli-X gate (bit flip) to the specified qubit.

  Flips |0⟩ ↔ |1⟩

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.x(0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit index is out of range
  """
  @spec x(circuit(), non_neg_integer()) :: circuit()
  defdelegate x(circuit, qubit), to: Operations

  @doc """
  Applies a Pauli-Y gate to the specified qubit.

  Combines bit flip and phase flip transformations.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.y(0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit index is out of range
  """
  @spec y(circuit(), non_neg_integer()) :: circuit()
  defdelegate y(circuit, qubit), to: Operations

  @doc """
  Applies a Pauli-Z gate (phase flip) to the specified qubit.

  Leaves |0⟩ unchanged, applies -1 phase to |1⟩

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.z(0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit index is out of range
  """
  @spec z(circuit(), non_neg_integer()) :: circuit()
  defdelegate z(circuit, qubit), to: Operations

  @doc """
  Applies a controlled-X (CNOT) gate.

  Flips target qubit if and only if control qubit is |1⟩

  ## Parameters
    * `circuit` - Quantum circuit
    * `control_qubit` - Control qubit index
    * `target_qubit` - Target qubit index

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.cx(0, 1)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit indices are out of range or equal
  """
  @spec cx(circuit(), non_neg_integer(), non_neg_integer()) :: circuit()
  defdelegate cx(circuit, control_qubit, target_qubit), to: Operations

  @doc """
  Applies a controlled-Z (CZ) gate.

  Applies a Z gate to the target qubit if and only if the control qubit is |1⟩.
  This is a symmetric two-qubit gate that applies a phase flip when both qubits are |1⟩.

  ## Parameters
    * `circuit` - Quantum circuit
    * `control_qubit` - Control qubit index
    * `target_qubit` - Target qubit index

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.cz(0, 1)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit indices are out of range or equal
  """
  @spec cz(circuit(), non_neg_integer(), non_neg_integer()) :: circuit()
  defdelegate cz(circuit, control_qubit, target_qubit), to: Operations

  @doc """
  Applies a SWAP gate, exchanging the quantum states of two qubits.

  Both qubits are treated symmetrically — there is no control/target distinction.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit_a` - Index of the first qubit
    * `qubit_b` - Index of the second qubit

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.swap(0, 1)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit indices are out of range or equal
  """
  @spec swap(circuit(), non_neg_integer(), non_neg_integer()) :: circuit()
  defdelegate swap(circuit, qubit_a, qubit_b), to: Operations

  @doc """
  Applies an iSWAP gate, exchanging qubit states while applying an i phase factor
  to the swapped components.

  Native to superconducting qubit hardware (Google Sycamore, Rigetti).
  Unlike SWAP, applying iSWAP twice is not the identity — it produces a -1 phase.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit_a` - Index of the first qubit
    * `qubit_b` - Index of the second qubit

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.iswap(0, 1)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit indices are out of range or equal
  """
  @spec iswap(circuit(), non_neg_integer(), non_neg_integer()) :: circuit()
  defdelegate iswap(circuit, qubit_a, qubit_b), to: Operations

  @doc """
  Applies a controlled-phase (CP) gate.

  Applies a phase of e^(i*theta) to the |11⟩ basis state only.
  All other basis states are unchanged.

  ## Parameters
    * `circuit` - Quantum circuit
    * `control_qubit` - Control qubit index
    * `target_qubit` - Target qubit index
    * `theta` - Phase angle in radians

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.cp(0, 1, :math.pi())
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit indices are out of range or equal
    * `Qx.ParameterError` - If theta is not a number
  """
  @spec cp(circuit(), non_neg_integer(), non_neg_integer(), number()) :: circuit()
  defdelegate cp(circuit, control_qubit, target_qubit, theta), to: Operations

  @doc """
  Applies a controlled-Y (CY) gate. See `Qx.Operations.cy/3`.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.cy(0, 1)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit indices are out of range or equal
  """
  @spec cy(circuit(), non_neg_integer(), non_neg_integer()) :: circuit()
  defdelegate cy(circuit, control_qubit, target_qubit), to: Operations

  @doc """
  Applies a controlled rotation about the X-axis. See `Qx.Operations.crx/4`.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.crx(0, 1, :math.pi() / 2)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit indices are out of range or equal
    * `Qx.ParameterError` - If `theta` is not a number
  """
  @spec crx(circuit(), non_neg_integer(), non_neg_integer(), number()) :: circuit()
  defdelegate crx(circuit, control_qubit, target_qubit, theta), to: Operations

  @doc """
  Applies a controlled rotation about the Y-axis. See `Qx.Operations.cry/4`.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.cry(0, 1, :math.pi() / 2)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit indices are out of range or equal
    * `Qx.ParameterError` - If `theta` is not a number
  """
  @spec cry(circuit(), non_neg_integer(), non_neg_integer(), number()) :: circuit()
  defdelegate cry(circuit, control_qubit, target_qubit, theta), to: Operations

  @doc """
  Applies a controlled rotation about the Z-axis. See `Qx.Operations.crz/4`.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.crz(0, 1, :math.pi() / 2)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit indices are out of range or equal
    * `Qx.ParameterError` - If `theta` is not a number
  """
  @spec crz(circuit(), non_neg_integer(), non_neg_integer(), number()) :: circuit()
  defdelegate crz(circuit, control_qubit, target_qubit, theta), to: Operations

  @doc """
  Applies a controlled-controlled-X (CCNOT/Toffoli) gate.

  Flips target qubit if and only if both control qubits are |1⟩

  ## Parameters
    * `circuit` - Quantum circuit
    * `control1` - First control qubit index
    * `control2` - Second control qubit index
    * `target` - Target qubit index

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(3) |> Qx.ccx(0, 1, 2)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit indices are out of range or equal
  """
  @spec ccx(circuit(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: circuit()
  defdelegate ccx(circuit, control1, control2, target), to: Operations

  @doc """
  Applies a Fredkin (controlled-SWAP) gate.

  Swaps the quantum states of `target_a` and `target_b` when the `control` qubit is |1⟩.
  When the control qubit is |0⟩, the targets are unchanged.

  ## Parameters
    * `circuit` - Quantum circuit
    * `control` - Control qubit index (0-based)
    * `target_a` - First target qubit index (0-based)
    * `target_b` - Second target qubit index (0-based)

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(3) |> Qx.cswap(0, 1, 2)
      iex> [{:cswap, [0, 1, 2], []}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> :ok
      :ok

  ## Raises

    * `Qx.QubitIndexError` - If any two qubit indices are equal or any index is out of range
  """
  @spec cswap(circuit(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: circuit()
  defdelegate cswap(circuit, control, target_a, target_b), to: Operations

  @doc """
  Applies an S gate (phase gate with π/2 phase).

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.s(0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit index is out of range
  """
  @spec s(circuit(), non_neg_integer()) :: circuit()
  defdelegate s(circuit, qubit), to: Operations

  @doc """
  Applies an S† (S-dagger) gate (-π/2 phase on |1⟩).

  Rotates the Y-basis back to the X-basis. The inverse of `s/2`.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.sdg(0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit index is out of range
  """
  @spec sdg(circuit(), non_neg_integer()) :: circuit()
  defdelegate sdg(circuit, qubit), to: Operations

  @doc """
  Applies a T gate (phase gate with π/4 phase).

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.t(0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit index is out of range
  """
  @spec t(circuit(), non_neg_integer()) :: circuit()
  defdelegate t(circuit, qubit), to: Operations

  @doc """
  Applies a T† (T-dagger) gate — the adjoint of `t/2` (−π/4 phase on |1⟩).

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.tdg(0)
      iex> [{gate, qubits, _params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate, qubits}
      {:tdg, [0]}

  ## Raises

    * `Qx.QubitIndexError` - If qubit index is out of range
  """
  @spec tdg(circuit(), non_neg_integer()) :: circuit()
  defdelegate tdg(circuit, qubit), to: Operations

  @doc """
  Applies a rotation around the X-axis.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index
    * `theta` - Rotation angle in radians

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.rx(0, :math.pi/2)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.ParameterError` - If `theta` is not a number (validated at build time)
    * `Qx.QubitIndexError` - If qubit index is out of range or not an integer
  """
  @spec rx(circuit(), non_neg_integer(), number()) :: circuit()
  defdelegate rx(circuit, qubit, theta), to: Operations

  @doc """
  Applies a rotation around the Y-axis.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index
    * `theta` - Rotation angle in radians

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.ry(0, :math.pi/2)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.ParameterError` - If `theta` is not a number (validated at build time)
    * `Qx.QubitIndexError` - If qubit index is out of range or not an integer
  """
  @spec ry(circuit(), non_neg_integer(), number()) :: circuit()
  defdelegate ry(circuit, qubit, theta), to: Operations

  @doc """
  Applies a rotation around the Z-axis.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index
    * `theta` - Rotation angle in radians

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.rz(0, :math.pi/2)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.ParameterError` - If `theta` is not a number (validated at build time)
    * `Qx.QubitIndexError` - If qubit index is out of range or not an integer
  """
  @spec rz(circuit(), non_neg_integer(), number()) :: circuit()
  defdelegate rz(circuit, qubit, theta), to: Operations

  @doc """
  Applies a phase gate with specified phase.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index
    * `phi` - Phase angle in radians

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.phase(0, :math.pi/4)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      1

  ## Raises

    * `Qx.ParameterError` - If `phi` is not a number (validated at build time)
    * `Qx.QubitIndexError` - If qubit index is out of range or not an integer
  """
  @spec phase(circuit(), non_neg_integer(), number()) :: circuit()
  defdelegate phase(circuit, qubit, phi), to: Operations

  @doc """
  Applies the general single-qubit unitary gate U(θ,φ,λ).

  U(θ,φ,λ) = [[cos(θ/2),             -e^(iλ)·sin(θ/2) ],
               [e^(iφ)·sin(θ/2),  e^(i(φ+λ))·cos(θ/2) ]]

  Follows the **OpenQASM 3.0** specification built-in `U` gate /
  Qiskit `qiskit.circuit.library.UGate` convention.

  Decomposition identity: `U(θ,φ,λ) = RZ(φ)·RY(θ)·RZ(λ)` up to the
  global phase `e^{i(φ+λ)/2}`. For the X/H/I/Y special cases the
  result is exact — Qiskit's `UGate` carries no extra global phase.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Target qubit index (0-based)
    * `theta` (θ) - Polar rotation angle in radians
    * `phi` (φ) - Phase angle in radians
    * `lambda` (λ) - Phase angle in radians

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.u(0, :math.pi(), 0, :math.pi())
      iex> [{:u, [0], params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> length(params)
      3

  ## Raises

    * `Qx.ParameterError` - If theta, phi, or lambda is not a number
    * `Qx.QubitIndexError` - If qubit index is out of range
  """
  @spec u(circuit(), non_neg_integer(), number(), number(), number()) :: circuit()
  defdelegate u(circuit, qubit, theta, phi, lambda), to: Operations

  @doc """
  Adds a measurement operation to the circuit.

  ## Parameters
    * `circuit` - Quantum circuit
    * `qubit` - Qubit index to measure
    * `classical_bit` - Classical bit index to store result

  ## Returns

  The updated `Qx.QuantumCircuit` with the measurement appended.

  ## Examples

      iex> qc = Qx.create_circuit(2, 2) |> Qx.measure(0, 0)
      iex> length(Qx.QuantumCircuit.get_measurements(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit index is out of range
    * `Qx.ClassicalBitError` - If classical_bit index is out of range
  """
  @spec measure(circuit(), non_neg_integer(), non_neg_integer()) :: circuit()
  defdelegate measure(circuit, qubit, classical_bit), to: Operations

  @doc """
  Performs a Z-basis (computational) measurement. Alias of `measure/3` for
  symmetry with `measure_x/3` and `measure_y/3`. See `Qx.Operations.measure_z/3`.

  ## Returns

  The updated `Qx.QuantumCircuit` with the measurement appended.

  ## Examples

      iex> qc = Qx.create_circuit(1, 1) |> Qx.measure_z(0, 0)
      iex> length(Qx.QuantumCircuit.get_measurements(qc))
      1

  ## Raises

    * `Qx.QubitIndexError` - If qubit index is out of range
    * `Qx.ClassicalBitError` - If classical bit index is out of range
  """
  @spec measure_z(circuit(), non_neg_integer(), non_neg_integer()) :: circuit()
  defdelegate measure_z(circuit, qubit, classical_bit), to: Operations

  @doc """
  Performs an X-basis measurement. See `Qx.Operations.measure_x/3`.

  ## Returns

  The updated `Qx.QuantumCircuit` with the measurement appended.

  ## Examples

      iex> qc = Qx.create_circuit(1, 1) |> Qx.measure_x(0, 0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      2

  ## Raises

    * `Qx.QubitIndexError` - If qubit index is out of range
    * `Qx.ClassicalBitError` - If classical bit index is out of range
  """
  @spec measure_x(circuit(), non_neg_integer(), non_neg_integer()) :: circuit()
  defdelegate measure_x(circuit, qubit, classical_bit), to: Operations

  @doc """
  Performs a Y-basis measurement. See `Qx.Operations.measure_y/3`.

  ## Returns

  The updated `Qx.QuantumCircuit` with the measurement appended.

  ## Examples

      iex> qc = Qx.create_circuit(1, 1) |> Qx.measure_y(0, 0)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      3

  ## Raises

    * `Qx.QubitIndexError` - If qubit index is out of range
    * `Qx.ClassicalBitError` - If classical bit index is out of range
  """
  @spec measure_y(circuit(), non_neg_integer(), non_neg_integer()) :: circuit()
  defdelegate measure_y(circuit, qubit, classical_bit), to: Operations

  @doc """
  Applies a Hadamard gate to every qubit in the circuit.

  Convenience for the recurring `Enum.reduce(0..(n - 1), qc, &Qx.h(&2, &1))`
  motif (Grover diffuser, Bernstein-Vazirani oracle, equal-superposition
  preparation). See `Qx.Patterns` for the full set of composite patterns.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(3) |> Qx.h_all()
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      3
  """
  @spec h_all(circuit()) :: circuit()
  defdelegate h_all(circuit), to: Patterns

  @doc """
  Applies a Hadamard gate to every qubit in the given list or range.
  See `Qx.Patterns.h_all/2`.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(5) |> Qx.h_all(0..2)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      3

  ## Raises

    * `Qx.QubitIndexError` - If any listed qubit index is out of range
  """
  @spec h_all(circuit(), Patterns.qubits()) :: circuit()
  defdelegate h_all(circuit, qubits), to: Patterns

  @doc """
  Applies a Pauli-X gate to every qubit in the circuit.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.x_all()
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      2
  """
  @spec x_all(circuit()) :: circuit()
  defdelegate x_all(circuit), to: Patterns

  @doc """
  Applies a Pauli-X gate to every qubit in the given list or range.
  See `Qx.Patterns.x_all/2`.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Raises

    * `Qx.QubitIndexError` - If any listed qubit index is out of range
  """
  @spec x_all(circuit(), Patterns.qubits()) :: circuit()
  defdelegate x_all(circuit, qubits), to: Patterns

  @doc """
  Applies a Pauli-Y gate to every qubit in the circuit.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.y_all()
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      2
  """
  @spec y_all(circuit()) :: circuit()
  defdelegate y_all(circuit), to: Patterns

  @doc """
  Applies a Pauli-Y gate to every qubit in the given list or range.
  See `Qx.Patterns.y_all/2`.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Raises

    * `Qx.QubitIndexError` - If any listed qubit index is out of range
  """
  @spec y_all(circuit(), Patterns.qubits()) :: circuit()
  defdelegate y_all(circuit, qubits), to: Patterns

  @doc """
  Applies a Pauli-Z gate to every qubit in the circuit.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.z_all()
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      2
  """
  @spec z_all(circuit()) :: circuit()
  defdelegate z_all(circuit), to: Patterns

  @doc """
  Applies a Pauli-Z gate to every qubit in the given list or range.
  See `Qx.Patterns.z_all/2`.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Raises

    * `Qx.QubitIndexError` - If any listed qubit index is out of range
  """
  @spec z_all(circuit(), Patterns.qubits()) :: circuit()
  defdelegate z_all(circuit, qubits), to: Patterns

  @doc """
  Measures every qubit into its same-index classical bit.

  Raises `Qx.ClassicalBitError` if `circuit.num_classical_bits < num_qubits` —
  the caller owns the circuit shape (see `Qx.Patterns.measure_all/1`).

  ## Returns

  The updated `Qx.QuantumCircuit` with the measurement appended.

  ## Examples

      iex> qc = Qx.create_circuit(3, 3) |> Qx.measure_all()
      iex> length(Qx.QuantumCircuit.get_measurements(qc))
      3

  ## Raises

    * `Qx.ClassicalBitError` - If `num_classical_bits < num_qubits`
  """
  @spec measure_all(circuit()) :: circuit()
  defdelegate measure_all(circuit), to: Patterns

  @doc """
  Measures every qubit in the given list or range into its same-index
  classical bit. See `Qx.Patterns.measure_all/2`.

  ## Returns

  The updated `Qx.QuantumCircuit` with the measurement appended.

  ## Raises

    * `Qx.ClassicalBitError` - If any listed qubit has no corresponding
      classical bit
  """
  @spec measure_all(circuit(), Patterns.qubits()) :: circuit()
  defdelegate measure_all(circuit, qubits), to: Patterns

  @doc """
  Adds a barrier across the given qubits.

  Barriers are pure visualisation markers with no effect on the
  quantum state. Used to group logical sections of a circuit when
  generating diagrams.

  See `Qx.Operations.barrier/2`. For a barrier across every qubit,
  see `Qx.barrier_all/1`.

  ## Returns

  The updated `Qx.QuantumCircuit` with the barrier appended.

  ## Examples

      iex> qc = Qx.create_circuit(3) |> Qx.barrier([0, 2])
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:barrier, [0, 2], []}]

      iex> qc = Qx.create_circuit(3) |> Qx.barrier(0..2)
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:barrier, [0, 1, 2], []}]

  ## Raises

    * `Qx.QubitIndexError` - If any qubit index is out of range
  """
  @spec barrier(circuit(), [non_neg_integer()] | Range.t()) :: circuit()
  defdelegate barrier(circuit, qubits), to: Operations

  @doc """
  Adds a single barrier instruction spanning every qubit.

  ## Returns

  The updated `Qx.QuantumCircuit` with the barrier appended.

  ## Examples

      iex> qc = Qx.create_circuit(3) |> Qx.barrier_all()
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:barrier, [0, 1, 2], []}]
  """
  @spec barrier_all(circuit()) :: circuit()
  defdelegate barrier_all(circuit), to: Patterns

  @doc """
  Adds a single barrier spanning the given list or range of qubits.

  > #### Deprecated {: .warning}
  > Use `Qx.barrier/2`, which now accepts a list **or range** and produces the
  > same single-barrier instruction. `barrier_all/2` is redundant and will be
  > removed in Qx 1.0. (`barrier_all/1` — barrier over every qubit — stays.)

  ## Returns

  The updated `Qx.QuantumCircuit` with the barrier appended.

  ## Raises

    * `Qx.QubitIndexError` - If any listed qubit index is out of range
  """
  @deprecated "Use `Qx.barrier/2`, which now accepts a list or range. Will be removed in Qx 1.0"
  @spec barrier_all(circuit(), Patterns.qubits()) :: circuit()
  defdelegate barrier_all(circuit, qubits), to: Patterns

  @doc """
  Applies a linear cascade of CNOTs along `qubits`.

  For `qubits = [q0, q1, …, qk]`, emits `cx(q0, q1) → cx(q1, q2) → …`. Empty
  and single-element lists are no-ops. See `Qx.Patterns.cx_chain/2`.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(3) |> Qx.h(0) |> Qx.cx_chain([0, 1, 2])
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      3

  ## Raises

    * `Qx.QubitIndexError` - If any qubit index is out of range
  """
  @spec cx_chain(circuit(), [non_neg_integer()]) :: circuit()
  defdelegate cx_chain(circuit, qubits), to: Patterns

  @doc """
  Appends the gates that entangle qubits `q0` and `q1` into one of the four
  Bell states onto an existing `circuit`.

  Where `Qx.bell_state/1` *creates* a fresh 2-qubit circuit, `bell_pair/4`
  *appends* onto `circuit` at caller-chosen qubits, so it composes inside a
  larger pipeline. See `Qx.Patterns.bell_pair/4` for the per-`which` gate
  sequence.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(3) |> Qx.bell_pair(1, 2)
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:h, [1], []}, {:cx, [1, 2], []}]

  ## Raises

    * `Qx.QubitIndexError` - If `q0` or `q1` is out of range, or if `q0 == q1`
    * `Qx.OptionError` - If `which` is not one of `:phi_plus`, `:phi_minus`, `:psi_plus`, `:psi_minus`
  """
  @spec bell_pair(circuit(), non_neg_integer(), non_neg_integer(), Patterns.bell_state_type()) ::
          circuit()
  defdelegate bell_pair(circuit, q0, q1, which \\ :phi_plus), to: Patterns

  @doc """
  Appends the GHZ-preparation gates over `qubits` onto an existing `circuit`.

  Where `Qx.ghz_state/1` *creates* a fresh `n`-qubit circuit over `0..n-1`,
  `ghz/2` *appends* onto `circuit` at caller-chosen qubits (a list or range of
  at least two indices). See `Qx.Patterns.ghz/2` for the gate sequence.

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      iex> qc = Qx.create_circuit(4) |> Qx.ghz(1..3)
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:h, [1], []}, {:cx, [1, 2], []}, {:cx, [2, 3], []}]

  ## Raises

    * `Qx.QubitCountError` - If fewer than two qubits are given
    * `Qx.QubitIndexError` - If any qubit index is out of range
  """
  @spec ghz(circuit(), Patterns.qubits()) :: circuit()
  defdelegate ghz(circuit, qubits), to: Patterns

  @doc """
  Applies gates conditionally based on a classical bit value.

  Enables mid-circuit measurement with classical feedback - a key capability
  for quantum error correction, quantum teleportation, and adaptive algorithms.

  ## Parameters
    * `circuit` - Quantum circuit
    * `classical_bit` - Classical bit index to check (must have been measured)
    * `value` - Value to compare (0 or 1)
    * `gate_fn` - Function that applies gates when condition is true

  ## Returns

  The updated `Qx.QuantumCircuit`, so calls chain in a pipeline.

  ## Examples

      # Apply X gate to qubit 1 if classical bit 0 equals 1
      iex> qc = Qx.create_circuit(2, 2)
      ...> |> Qx.h(0)
      ...> |> Qx.measure(0, 0)
      ...> |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      3

      # Multiple gates in conditional block
      iex> qc = Qx.create_circuit(3, 2)
      ...> |> Qx.measure(0, 0)
      ...> |> Qx.c_if(0, 1, fn c ->
      ...>      c |> Qx.x(1) |> Qx.h(2)
      ...>    end)
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      2

  ## Raises

    * `Qx.ClassicalBitError` - If `classical_bit` is not a valid classical bit index
    * `Qx.ConditionalError` - If `value` is not 0 or 1, the block nests another conditional, or `gate_fn` is not a 1-arity function

  ## See Also
    * OpenQASM 3.0 if-statements for hardware compatibility
    * Quantum teleportation example in documentation
  """
  @spec c_if(circuit(), non_neg_integer(), 0 | 1, (circuit() -> circuit())) :: circuit()
  defdelegate c_if(circuit, classical_bit, value, gate_fn), to: Operations

  @doc """
  Executes the quantum circuit and returns simulation results.

  ## Parameters
    * `circuit` - Quantum circuit to execute
    * `options` - A keyword list of options (see below). Passing a bare integer
      as the number of shots (`Qx.run(qc, 1000)`) is a **soft-deprecated**
      shorthand for `Qx.run(qc, shots: 1000)`: it still works exactly as before
      (no warning), but prefer the keyword form — the integer overload may be
      removed in Qx 1.0.

  ## Options
    * `:shots` - Number of measurement shots (default: 1024)
    * `:backend` - Nx backend to use, e.g. `Nx.BinaryBackend` (default) or
      `{EXLA.Backend, client: :host}` if EXLA is added to your deps (see README)
    * `:renormalize` - Counter unitary float drift (default: `false`).
      `false` = off; `true` = renormalize at measurement-time;
      positive integer `N` = renormalize every `N` gates and at
      measurement-time. Other values raise `Qx.OptionError`. See
      `Qx.Simulation.run/2` for the float32 accuracy note.

  ## Returns

  A `Qx.SimulationResult` struct with these fields:

    * `:probabilities` - real probability tensor `|ψ|²` over all
      `2^n` basis states
    * `:classical_bits` - one classical-bit vector per shot, each
      a list of `0` / `1` values
    * `:state` - final statevector (complex-valued `:c64` tensor)
    * `:shots` - number of shots simulated
    * `:counts` - frequency map of outcome strings to counts
      (keys are binary strings like `"01"`)

  Helpers on the struct: `Qx.SimulationResult.most_frequent/1`,
  `Qx.SimulationResult.outcomes/1`,
  `Qx.SimulationResult.probability/2`.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.h(0)
      iex> %Qx.SimulationResult{shots: shots} = Qx.run(qc)
      iex> shots
      1024

      # Specify backend at runtime
      # Qx.run(qc, backend: {EXLA.Backend, client: :host})

      # Backward compatible: pass shots as integer
      # Qx.run(qc, 2048)
  """
  @spec run(circuit(), pos_integer() | keyword()) :: Qx.SimulationResult.t()
  def run(circuit, options \\ [])

  def run(circuit, shots) when is_integer(shots) do
    Simulation.run(circuit, shots: shots)
  end

  def run(circuit, options) when is_list(options) do
    Simulation.run(circuit, options)
  end

  @doc """
  Executes a circuit and returns only the final quantum state.

  ## Parameters
    * `circuit` - Quantum circuit to execute
    * `options` - Optional parameters

  ## Options
    * `:backend` - Nx backend to use, e.g. `Nx.BinaryBackend` (default) or
      `{EXLA.Backend, client: :host}` if EXLA is added to your deps (see README)

  ## Returns

  An `Nx.Tensor` statevector (complex `:c64`) of length `2^n`.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.h(0)
      iex> state = Qx.get_state(qc)
      iex> Nx.shape(state)
      {2}

      # Specify backend at runtime
      # Qx.get_state(qc, backend: {EXLA.Backend, client: :host})

  ## Raises

    * `Qx.MeasurementError` - If circuit contains measurements or conditionals
  """
  @spec get_state(circuit(), keyword()) :: Nx.Tensor.t()
  def get_state(circuit, options \\ []) do
    Simulation.get_state(circuit, options)
  end

  @doc """
  Gets probability distribution for computational basis states.

  ## Parameters
    * `circuit` - Quantum circuit
    * `options` - Optional parameters

  ## Options
    * `:backend` - Nx backend to use, e.g. `Nx.BinaryBackend` (default) or
      `{EXLA.Backend, client: :host}` if EXLA is added to your deps (see README)

  ## Returns

  An `Nx.Tensor` of real probabilities over the `2^n` basis states.

  ## Examples

      iex> qc = Qx.create_circuit(1) |> Qx.h(0)
      iex> probs = Qx.get_probabilities(qc)
      iex> Nx.shape(probs)
      {2}

      # Specify backend at runtime
      # Qx.get_probabilities(qc, backend: {EXLA.Backend, client: :host})

  ## Raises

    * `Qx.MeasurementError` - If circuit contains measurements or conditionals
  """
  @spec get_probabilities(circuit(), keyword()) :: Nx.Tensor.t()
  def get_probabilities(circuit, options \\ []) do
    Simulation.get_probabilities(circuit, options)
  end

  @doc """
  Steps through a circuit: a lazy stream of `Qx.Step` structs, one per
  executed operation.

  Each step carries the operation just applied, the statevector right
  after it, its probabilities, and the classical bits so far. Print a
  step to get a readable one-liner; call `Qx.Step.show/1` for the full
  display map.

  Unlike `get_state/2`, stepping works on circuits with mid-circuit
  measurement and `c_if`, so you can walk through teleportation:

      Qx.create_circuit(3, 3)
      |> Qx.x(0)                                # the state to teleport
      |> Qx.h(1)
      |> Qx.cx(1, 2)                            # Bell pair
      |> Qx.cx(0, 1)
      |> Qx.h(0)                                # Bell measurement basis
      |> Qx.measure(0, 0)
      |> Qx.measure(1, 1)
      |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)  # corrections
      |> Qx.c_if(0, 1, fn c -> Qx.z(c, 2) end)
      |> Qx.measure(2, 2)
      |> Qx.steps()
      |> Enum.to_list()
      # one readable line per step, e.g.
      # #Qx.Step<5: measure q0 → c0 ⇒ 0.707|010⟩ + 0.707|011⟩  cbits: [0, 0, 0]>

  Measurement steps show the collapsed state and record the outcome in
  `classical_bits`; each gate inside a taken `c_if` block yields its own
  step, and a block that doesn't run yields one step flagged
  `:not_taken`.

  ## One trajectory at a time

  A circuit with measurements is stochastic. Each materialisation of the
  stream samples one fresh trajectory, so two `Enum.to_list/1` calls can
  collapse differently, and a single trajectory is a different thing
  from the 1024-shot ensemble `run/2` reports. Pass `seed:` when you
  need the same trajectory every time (slides, doctests, regression
  tests). Seeding never touches your process's `:rand` state.

  One caveat for `measure_x/3` and `measure_y/3`: they lower to
  basis-change gates plus a Z-measurement, and the post-measurement
  state deliberately stays Z-aligned. Mid-circuit that means a step
  shows `|1⟩` where the math says `|−⟩`. See `Qx.Operations.measure_x/3`.

  ## Options

    * `:seed` - integer; reproduces the trajectory (default: fresh
      entropy per materialisation)
    * `:backend` - Nx backend, same pass-through as `run/2`
    * `:renormalize` - same contract as `run/2` (default: `false`)

  ## Returns

  A lazy `Enumerable` of `Qx.Step` structs, one per executed operation.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
      iex> steps = qc |> Qx.steps() |> Enum.to_list()
      iex> Enum.map(steps, & &1.operation)
      [{:h, [0], []}, {:cx, [0, 1], []}]
      iex> steps |> List.last() |> Qx.Step.show() |> Map.get(:state)
      "0.707|00⟩ + 0.707|11⟩"
  """
  @spec steps(circuit(), keyword()) :: Enumerable.t()
  defdelegate steps(circuit, opts \\ []), to: Simulation

  @doc """
  Visualizes probability distribution from simulation results.

  Convenience function for quickly plotting the probability distribution
  from a simulation result. The probabilities are automatically extracted
  from the result map.

  For plotting raw probability tensors (e.g., from `get_probabilities/1`),
  use `draw_histogram/2` instead.

  Returns a `VegaLite.t()` chart spec in every environment; Livebook
  renders it via kino_vega_lite, standalone apps feed it to any Vega
  renderer.

  ## Parameters
    * `result` - Simulation result from `run/1` or `run/2`
    * `options` - Optional plotting parameters

  ## Options
    * `:title` - Plot title
    * `:width` - Plot width (default: 400)
    * `:height` - Plot height (default: 300)

  ## Returns
  A `VegaLite.t()` chart specification.

  ## Raises
    * `Qx.MissingDependencyError` - if the optional `:vega_lite`
      dependency is not available

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
      iex> result = Qx.run(qc)
      iex> plot = Qx.draw(result)
      iex> is_struct(plot, VegaLite)
      true

  ## See Also
    * `draw_histogram/2` - For plotting raw probability tensors
    * `draw_counts/2` - For plotting measurement counts
  """
  @spec draw(simulation_result(), keyword()) :: VegaLite.t()
  defdelegate draw(result, options \\ []), to: Draw, as: :plot

  @doc """
  Visualizes measurement counts as a bar chart.

  Returns a `VegaLite.t()` chart spec in every environment; Livebook
  renders it via kino_vega_lite. Works with results from both local
  simulation and `Qx.Hardware` execution.

  ## Parameters
    * `result` - Simulation result containing measurement data
    * `options` - Optional plotting parameters (`:title`, `:width`, `:height`)

  ## Returns
  A `VegaLite.t()` chart specification.

  ## Raises
    * `Qx.MissingDependencyError` - if the optional `:vega_lite`
      dependency is not available

  ## Examples

      iex> qc = Qx.create_circuit(2, 2) |> Qx.h(0) |> Qx.measure(0, 0)
      iex> result = Qx.run(qc)
      iex> plot = Qx.draw_counts(result)
      iex> is_struct(plot, VegaLite)
      true
  """
  @spec draw_counts(simulation_result(), keyword()) :: VegaLite.t()
  defdelegate draw_counts(result, options \\ []), to: Draw, as: :counts

  @doc """
  Creates a histogram from a raw probability tensor.

  Use this function when you have a probability tensor and want to visualize it.
  This is useful for:
  - Plotting probabilities from `get_probabilities/1` without running simulation
  - Visualizing custom or theoretical probability distributions
  - Comparing different probability distributions

  For quick visualization of simulation results, use `draw/2` instead.

  ## Parameters
    * `probabilities` - Nx tensor of probabilities (should sum to 1.0)
    * `options` - Optional plotting parameters

  ## Returns

  A `VegaLite.t()` chart specification.

  ## Examples

      # Visualize probabilities without full simulation
      iex> qc = Qx.create_circuit(2) |> Qx.h(0)
      iex> probs = Qx.get_probabilities(qc)
      iex> hist = Qx.draw_histogram(probs)
      iex> is_struct(hist, VegaLite)
      true

  ## Raises

    * `Qx.MissingDependencyError` - If the optional `:vega_lite` dependency is not available

  ## See Also
    * `draw/2` - For plotting from simulation results
    * `get_probabilities/1` - To obtain probability tensors
  """
  @spec draw_histogram(Nx.Tensor.t(), keyword()) :: VegaLite.t()
  defdelegate draw_histogram(probabilities, options \\ []), to: Draw, as: :histogram

  @doc """
  Visualizes a single qubit state on the Bloch sphere.

  The Bloch sphere provides a geometric representation of a pure qubit state.
  Handy for seeing what a single-qubit gate did to the state.

  ## Parameters
    * `qubit` - Single-qubit state tensor (2 amplitudes), e.g. from
      `Qx.get_state/1` on a 1-qubit circuit or from a `Qx.Step`
    * `options` - Optional plotting parameters

  Returns a `Qx.Draw.Image` artifact in every environment: Livebook
  renders it inline (via `Kino.Render`), standalone applications read
  the SVG from `image.svg`.

  ## Options
    * `:title` - Plot title (default: "Bloch Sphere")
    * `:size` - Sphere size (default: 400)

  ## Returns
  A `Qx.Draw.Image` struct carrying the SVG.

  ## Examples

      # Visualize |0⟩ state
      iex> state = Qx.create_circuit(1) |> Qx.get_state()
      iex> image = Qx.draw_bloch(state)
      iex> is_struct(image, Qx.Draw.Image)
      true

      # Visualize superposition state
      iex> state = Qx.create_circuit(1) |> Qx.h(0) |> Qx.get_state()
      iex> image = Qx.draw_bloch(state, title: "Superposition State")
      iex> String.contains?(image.svg, "<svg")
      true

  ## See Also
    * `draw_state/2` - Display multi-qubit state as table
    * `Qx.steps/2` - State after each operation of a circuit
  """
  @spec draw_bloch(Nx.Tensor.t(), keyword()) :: Qx.Draw.Image.t()
  defdelegate draw_bloch(qubit, options \\ []), to: Draw, as: :bloch

  @doc """
  Displays a quantum state as a formatted table.

  Shows basis states with their amplitudes and probabilities. Useful for
  inspecting a multi-qubit state without running the full circuit.

  Returns a `Qx.Draw.StateTable` artifact in every environment:
  Livebook renders the markdown table (via `Kino.Render`), IEx prints
  the text form, and the `:text`/`:markdown`/`:html` fields carry the
  renderings for standalone use.

  ## Parameters
    * `state` - state tensor, e.g. from `Qx.get_state/1`
    * `options` - Optional display parameters

  ## Options
    * `:precision` - Decimal places (default: 3)
    * `:hide_zeros` - Hide zero-amplitude states (default: false)

  ## Returns
  A `Qx.Draw.StateTable` struct.

  ## Examples

      # Display Bell state
      iex> state = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1) |> Qx.get_state()
      iex> table = Qx.draw_state(state)
      iex> table.text =~ "Basis State"
      true

      # Hide zero states
      iex> state = Qx.create_circuit(3) |> Qx.h(0) |> Qx.get_state()
      iex> table = Qx.draw_state(state, hide_zeros: true)
      iex> table.text =~ "|111⟩"
      false

  ## See Also
    * `draw_bloch/2` - Bloch sphere visualization for single qubits
    * `Qx.Step.show/1` - The same view for one step of `Qx.steps/2`
  """
  @spec draw_state(Nx.Tensor.t(), keyword()) :: Qx.Draw.StateTable.t()
  defdelegate draw_state(register_or_state, options \\ []), to: Draw, as: :state_table

  @doc """
  Draws a quantum circuit diagram.

  Returns a `Qx.Draw.Image` artifact in every environment: Livebook
  renders the diagram inline (via `Kino.Render` — a cell that simply
  returns a circuit already renders it), standalone applications read
  the SVG from `image.svg`.

  ## Parameters
    * `circuit` - The quantum circuit to visualize
    * `title` - Optional diagram title (default: `nil`)

  ## Returns
  A `Qx.Draw.Image` struct carrying the SVG diagram.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
      iex> image = Qx.draw_circuit(qc, "Bell")
      iex> String.contains?(image.svg, "<svg")
      true

  ## See Also
    * `draw_state/2` - The state the circuit produces, as a table
  """
  @spec draw_circuit(circuit(), String.t() | nil) :: Qx.Draw.Image.t()
  defdelegate draw_circuit(circuit, title \\ nil), to: Draw, as: :circuit

  # OpenQASM interoperability — thin facade over Qx.Export.OpenQASM.

  @doc """
  Exports `circuit` to an OpenQASM program string. See
  `Qx.Export.OpenQASM.to_qasm/2` for options and the supported gate set.

  ## Returns

  The OpenQASM program as a `String.t()`.

  ## Examples

      iex> qasm = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1) |> Qx.to_qasm()
      iex> qasm =~ "OPENQASM 3.0;"
      true

  ## Raises

    * `Qx.OptionError` - If `:version` is not a supported QASM version
  """
  @spec to_qasm(circuit(), keyword()) :: String.t()
  defdelegate to_qasm(circuit, options \\ []), to: OpenQASM

  @doc """
  Parses an OpenQASM program string into a `Qx.QuantumCircuit`. See
  `Qx.Export.OpenQASM.from_qasm/1`.

  ## Returns

    * `{:ok, circuit}` on success
    * `{:error, exception}` on a parse/lowering failure

  ## Examples

      iex> {:ok, circuit} = Qx.from_qasm("OPENQASM 3.0;\\nqubit[1] q;\\nh q[0];\\n")
      iex> Qx.QuantumCircuit.get_instructions(circuit)
      [{:h, [0], []}]
  """
  @spec from_qasm(String.t()) :: {:ok, circuit()} | {:error, Exception.t()}
  defdelegate from_qasm(source), to: OpenQASM

  @doc """
  Like `from_qasm/1` but returns the circuit directly and raises on error.
  See `Qx.Export.OpenQASM.from_qasm!/1`.

  ## Returns

  The parsed `Qx.QuantumCircuit`.

  ## Examples

      iex> circuit = Qx.from_qasm!("OPENQASM 3.0;\\nqubit[1] q;\\ntdg q[0];\\n")
      iex> Qx.QuantumCircuit.get_instructions(circuit)
      [{:tdg, [0], []}]

  ## Raises

    * `Qx.QasmParseError` / `Qx.QasmUnsupportedError` - On invalid or unsupported input
  """
  @spec from_qasm!(String.t()) :: circuit()
  defdelegate from_qasm!(source), to: OpenQASM

  # Convenience functions for creating common quantum states and circuits

  @doc """
  Creates one of the four Bell-state circuits (maximally entangled
  two-qubit states). See `Qx.Patterns.bell_state_circuit/1`.

  | Atom          | State                                  |
  | ------------- | -------------------------------------- |
  | `:phi_plus`   | `\|Φ+⟩ = (\|00⟩ + \|11⟩)/√2` (default) |
  | `:phi_minus`  | `\|Φ-⟩ = (\|00⟩ - \|11⟩)/√2`           |
  | `:psi_plus`   | `\|Ψ+⟩ = (\|01⟩ + \|10⟩)/√2`           |
  | `:psi_minus`  | `\|Ψ-⟩ = (\|01⟩ - \|10⟩)/√2`           |

  ## Returns

  A `Qx.QuantumCircuit` that prepares the selected Bell state.

  ## Examples

      iex> bell_circuit = Qx.bell_state()
      iex> bell_circuit.num_qubits
      2

      iex> bell_circuit = Qx.bell_state(:psi_minus)
      iex> bell_circuit.num_qubits
      2

  ## Raises

    * `Qx.OptionError` - If `which` is not one of `:phi_plus`, `:phi_minus`, `:psi_plus`, `:psi_minus`

  ## See Also

    * `Qx.StateInit.bell_state_vector/2` — returns a state vector, not a
      circuit (deprecated, removal at 1.0 — run this circuit and
      `Qx.get_state/1` instead).
  """
  @type bell_state_type :: Patterns.bell_state_type()
  @spec bell_state(bell_state_type()) :: circuit()
  defdelegate bell_state(which \\ :phi_plus), to: Patterns, as: :bell_state_circuit

  @doc """
  Creates an `n`-qubit GHZ-state preparation circuit. Default is 3 qubits.

  Returns a circuit that prepares `|GHZ⟩ = (|0…0⟩ + |1…1⟩)/√2` on a
  `|0…0⟩` input. See `Qx.Patterns.ghz_state_circuit/1`.

  ## Returns

  A `Qx.QuantumCircuit` that prepares the `n`-qubit GHZ state.

  ## Examples

      iex> ghz_circuit = Qx.ghz_state()
      iex> ghz_circuit.num_qubits
      3

      iex> ghz_circuit = Qx.ghz_state(5)
      iex> ghz_circuit.num_qubits
      5

  ## Raises

    * `Qx.QubitCountError` - If `num_qubits` is not an integer in the range 2..20

  ## See Also

    * `Qx.StateInit.ghz_state_vector/2` — returns a state vector, not a
      circuit (deprecated, removal at 1.0 — run this circuit and
      `Qx.get_state/1` instead).
  """
  @spec ghz_state(pos_integer()) :: circuit()
  defdelegate ghz_state(num_qubits \\ 3), to: Patterns, as: :ghz_state_circuit

  @doc """
  Creates an `n`-qubit equal-superposition circuit (Hadamard on every
  qubit). Default is 1 qubit.

  > #### Deprecated {: .warning}
  > Use `Qx.create_circuit(n) |> Qx.h_all()` — it is the same circuit, expressed
  > through the primary gate surface. `superposition/1` will be removed in Qx 1.0.

  ## Returns

  A `Qx.QuantumCircuit` that prepares the equal superposition.

  ## Examples

      iex> sup_circuit = Qx.superposition()
      iex> sup_circuit.num_qubits
      1

      iex> sup_circuit = Qx.superposition(3)
      iex> length(Qx.QuantumCircuit.get_instructions(sup_circuit))
      3
  """
  @deprecated "Use `Qx.create_circuit(n) |> Qx.h_all()`. Will be removed in Qx 1.0"
  @spec superposition(pos_integer()) :: circuit()
  defdelegate superposition(num_qubits \\ 1), to: Patterns, as: :superposition_circuit

  @doc """
  Returns version information for the Qx library.

  ## Returns

  The Qx version string (or `unknown` if the application spec is unavailable).

  ## Examples

      iex> version = Qx.version()
      iex> is_binary(version)
      true
  """
  @spec version() :: String.t()
  def version do
    case Application.spec(:qx, :vsn) do
      nil -> "unknown"
      vsn -> List.to_string(vsn)
    end
  end

  # Tap-style debugging functions

  @doc """
  Inspects the circuit without breaking the pipeline.

  See `Qx.Operations.tap_circuit/2` for full documentation.

  **Debugging aid.** Runs `fun` for its side effects and returns the
  circuit unchanged. Unlike `tap_state/2` it does not execute the
  circuit, so it carries no simulation cost.

  ## Returns

  The original `Qx.QuantumCircuit`, unchanged — the tap is transparent in a pipeline.

  ## Examples

      # Inspect instructions while building circuit
      circuit = Qx.create_circuit(2)
        |> Qx.h(0)
        |> Qx.tap_circuit(fn c -> IO.puts("Gates: #\{length(c.instructions)}") end)
        |> Qx.cx(0, 1)

  """
  @spec tap_circuit(circuit(), (circuit() -> any())) :: circuit()
  defdelegate tap_circuit(circuit, fun), to: Operations

  @doc """
  Inspects the current quantum state without breaking the pipeline.

  See `Qx.Operations.tap_state/2` for full documentation.

  **Important:** This executes all instructions so far to get the current
  state. Use sparingly in performance-critical code.

  ## Returns

  The original `Qx.QuantumCircuit`, unchanged — the tap is transparent in a pipeline.

  ## Examples

      # Inspect quantum state while building circuit
      circuit = Qx.create_circuit(1)
        |> Qx.h(0)
        |> Qx.tap_state(fn s -> IO.puts("State shape: #\{inspect(Nx.shape(s))}") end)
        |> Qx.z(0)

  ## Raises

    * `Qx.MeasurementError` - If the circuit so far contains measurements or conditionals (tap before the first `measure/3` or `c_if/4`)
  """
  @spec tap_state(circuit(), (Nx.Tensor.t() -> any())) :: circuit()
  defdelegate tap_state(circuit, fun), to: Operations

  @doc """
  Inspects measurement probabilities without breaking the pipeline.

  See `Qx.Operations.tap_probabilities/2` for full documentation.

  **Important:** This executes all instructions so far to get the current
  probabilities. Use sparingly in performance-critical code.

  ## Returns

  The original `Qx.QuantumCircuit`, unchanged — the tap is transparent in a pipeline.

  ## Examples

      # Inspect probabilities while building circuit
      circuit = Qx.create_circuit(2)
        |> Qx.h(0)
        |> Qx.tap_probabilities(fn p -> IO.puts("Probs: #\{inspect(Nx.shape(p))}") end)
        |> Qx.cx(0, 1)

  ## Raises

    * `Qx.MeasurementError` - If the circuit so far contains measurements or conditionals (tap before the first `measure/3` or `c_if/4`)
  """
  @spec tap_probabilities(circuit(), (Nx.Tensor.t() -> any())) :: circuit()
  defdelegate tap_probabilities(circuit, fun), to: Operations
end
