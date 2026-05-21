defmodule Qx.Patterns do
  @moduledoc """
  Composite circuit-building patterns: thin wrappers that emit multiple
  instructions in one call.

  Where `Qx.Operations` emits exactly one instruction per call (one gate, one
  qubit), this module bundles the recurring "apply X to every qubit" /
  "measure every qubit" / "CNOT chain" motifs that appear in tutorials and
  algorithm circuits (Grover diffuser, Bernstein-Vazirani oracle, GHZ
  preparation, etc.).

  All helpers are additive over `Qx.Operations` and `Qx.QuantumCircuit`; they
  introduce no new exception types. Out-of-range qubit indices or insufficient
  classical bits surface the existing typed errors (`Qx.QubitIndexError`,
  `Qx.ClassicalBitError`) from the underlying primitives.

  See also:

  - `Qx.Operations` — one-instruction-per-call gate API.
  - `Qx.StateInit` — sibling module for composite *state-vector* recipes
    (Bell state, GHZ state, W state). `Qx.Patterns` is the *circuit-instruction*
    analogue.

  ## Examples

      # Equal superposition over all qubits (replaces a private `apply_h_all`
      # helper used in tutorials).
      iex> qc = Qx.create_circuit(3) |> Qx.Patterns.h_all()
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      3

      # Measure every qubit into its same-index classical bit.
      iex> qc = Qx.create_circuit(2, 2) |> Qx.Patterns.measure_all()
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:measure, [0, 0], []}, {:measure, [1, 1], []}]

      # GHZ-style linear CNOT chain.
      iex> qc = Qx.create_circuit(4) |> Qx.Patterns.cx_chain([0, 1, 2, 3])
      iex> length(Qx.QuantumCircuit.get_instructions(qc))
      3
  """

  alias Qx.{Operations, QuantumCircuit}

  @doc """
  Applies a Hadamard gate to every qubit in `circuit`.

  Equivalent to `Enum.reduce(0..(n - 1), circuit, &Qx.h(&2, &1))` where `n` is
  `circuit.num_qubits`, but expresses the intent directly.

  ## Examples

      iex> qc = Qx.create_circuit(3) |> Qx.Patterns.h_all()
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:h, [0], []}, {:h, [1], []}, {:h, [2], []}]
  """
  @spec h_all(QuantumCircuit.t()) :: QuantumCircuit.t()
  def h_all(%QuantumCircuit{num_qubits: n} = circuit) do
    Enum.reduce(0..(n - 1), circuit, fn q, acc -> Operations.h(acc, q) end)
  end

  @doc """
  Applies a Pauli-X gate to every qubit in `circuit`.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.Patterns.x_all()
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:x, [0], []}, {:x, [1], []}]
  """
  @spec x_all(QuantumCircuit.t()) :: QuantumCircuit.t()
  def x_all(%QuantumCircuit{num_qubits: n} = circuit) do
    Enum.reduce(0..(n - 1), circuit, fn q, acc -> Operations.x(acc, q) end)
  end

  @doc """
  Applies a Pauli-Y gate to every qubit in `circuit`.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.Patterns.y_all()
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:y, [0], []}, {:y, [1], []}]
  """
  @spec y_all(QuantumCircuit.t()) :: QuantumCircuit.t()
  def y_all(%QuantumCircuit{num_qubits: n} = circuit) do
    Enum.reduce(0..(n - 1), circuit, fn q, acc -> Operations.y(acc, q) end)
  end

  @doc """
  Applies a Pauli-Z gate to every qubit in `circuit`.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.Patterns.z_all()
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:z, [0], []}, {:z, [1], []}]
  """
  @spec z_all(QuantumCircuit.t()) :: QuantumCircuit.t()
  def z_all(%QuantumCircuit{num_qubits: n} = circuit) do
    Enum.reduce(0..(n - 1), circuit, fn q, acc -> Operations.z(acc, q) end)
  end

  @doc """
  Measures every qubit into its same-index classical bit.

  Emits `n` measurement instructions where `n = circuit.num_qubits`, each
  mapping qubit `i` to classical bit `i`.

  Raises `Qx.ClassicalBitError` if `circuit.num_classical_bits < num_qubits` —
  the circuit shape is the caller's decision (made at `create_circuit/2`),
  and no auto-grow happens.

  ## Examples

      iex> qc = Qx.create_circuit(3, 3) |> Qx.Patterns.measure_all()
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:measure, [0, 0], []}, {:measure, [1, 1], []}, {:measure, [2, 2], []}]
  """
  @spec measure_all(QuantumCircuit.t()) :: QuantumCircuit.t()
  def measure_all(%QuantumCircuit{num_qubits: n} = circuit) do
    Enum.reduce(0..(n - 1), circuit, fn i, acc ->
      QuantumCircuit.add_measurement(acc, i, i)
    end)
  end

  @doc """
  Adds a single barrier instruction spanning every qubit in `circuit`.

  Equivalent to `Qx.Operations.barrier(circuit, Enum.to_list(0..(n - 1)))`.

  ## Examples

      iex> qc = Qx.create_circuit(3) |> Qx.Patterns.barrier_all()
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:barrier, [0, 1, 2], []}]
  """
  @spec barrier_all(QuantumCircuit.t()) :: QuantumCircuit.t()
  def barrier_all(%QuantumCircuit{num_qubits: n} = circuit) do
    Operations.barrier(circuit, Enum.to_list(0..(n - 1)))
  end

  @doc """
  Applies a linear cascade of CNOTs along `qubits`.

  For `qubits = [q0, q1, q2, ..., qk]`, emits CNOTs `cx(q0, q1), cx(q1, q2),
  …, cx(q_{k-1}, q_k)` — i.e. each qubit controls the next. This is the
  shape used to build GHZ states (e.g. `H(0) → cx(0,1) → cx(1,2)`).

  Lists of length 0 or 1 are deliberate no-ops and return `circuit`
  unchanged.

  ## Examples

      iex> qc = Qx.create_circuit(4) |> Qx.Patterns.cx_chain([0, 1, 2, 3])
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:cx, [0, 1], []}, {:cx, [1, 2], []}, {:cx, [2, 3], []}]

      iex> qc = Qx.create_circuit(2) |> Qx.Patterns.cx_chain([])
      iex> Qx.QuantumCircuit.get_instructions(qc)
      []

      iex> qc = Qx.create_circuit(2) |> Qx.Patterns.cx_chain([0])
      iex> Qx.QuantumCircuit.get_instructions(qc)
      []
  """
  @spec cx_chain(QuantumCircuit.t(), [non_neg_integer()]) :: QuantumCircuit.t()
  def cx_chain(%QuantumCircuit{} = circuit, qubits) when is_list(qubits) do
    qubits
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(circuit, fn [c, t], acc -> Operations.cx(acc, c, t) end)
  end
end
