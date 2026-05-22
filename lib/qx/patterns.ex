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

  Each `_all` helper has two arities:

  - `/1` — apply to every qubit in the circuit (whole-circuit form).
  - `/2` — apply to a sub-list or range of qubits (sub-register form), e.g.
    `Qx.Patterns.h_all(qc, 0..2)` or `Qx.Patterns.h_all(qc, [0, 2, 4])`.

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

      # Equal superposition over a sub-register.
      iex> qc = Qx.create_circuit(5) |> Qx.Patterns.h_all(0..2)
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

  @typedoc """
  A list or range of non-negative qubit indices.

  Used as the second argument to the `/2` form of `h_all`, `x_all`, `y_all`,
  `z_all`, `measure_all`, and `barrier_all` to select a sub-register.
  """
  @type qubits :: [non_neg_integer()] | Range.t()

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
    h_all(circuit, 0..(n - 1))
  end

  @doc """
  Applies a Hadamard gate to every qubit in the given list or range.

  ## Examples

      iex> qc = Qx.create_circuit(5) |> Qx.Patterns.h_all([0, 2, 4])
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:h, [0], []}, {:h, [2], []}, {:h, [4], []}]

      iex> qc = Qx.create_circuit(5) |> Qx.Patterns.h_all(1..3)
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:h, [1], []}, {:h, [2], []}, {:h, [3], []}]
  """
  @spec h_all(QuantumCircuit.t(), qubits()) :: QuantumCircuit.t()
  def h_all(%QuantumCircuit{} = circuit, qubits) do
    reduce_qubits(circuit, qubits, &Operations.h/2)
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
    x_all(circuit, 0..(n - 1))
  end

  @doc """
  Applies a Pauli-X gate to every qubit in the given list or range.

  ## Examples

      iex> qc = Qx.create_circuit(4) |> Qx.Patterns.x_all([0, 3])
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:x, [0], []}, {:x, [3], []}]
  """
  @spec x_all(QuantumCircuit.t(), qubits()) :: QuantumCircuit.t()
  def x_all(%QuantumCircuit{} = circuit, qubits) do
    reduce_qubits(circuit, qubits, &Operations.x/2)
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
    y_all(circuit, 0..(n - 1))
  end

  @doc """
  Applies a Pauli-Y gate to every qubit in the given list or range.

  ## Examples

      iex> qc = Qx.create_circuit(3) |> Qx.Patterns.y_all(0..1)
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:y, [0], []}, {:y, [1], []}]
  """
  @spec y_all(QuantumCircuit.t(), qubits()) :: QuantumCircuit.t()
  def y_all(%QuantumCircuit{} = circuit, qubits) do
    reduce_qubits(circuit, qubits, &Operations.y/2)
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
    z_all(circuit, 0..(n - 1))
  end

  @doc """
  Applies a Pauli-Z gate to every qubit in the given list or range.

  ## Examples

      iex> qc = Qx.create_circuit(3) |> Qx.Patterns.z_all([2])
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:z, [2], []}]
  """
  @spec z_all(QuantumCircuit.t(), qubits()) :: QuantumCircuit.t()
  def z_all(%QuantumCircuit{} = circuit, qubits) do
    reduce_qubits(circuit, qubits, &Operations.z/2)
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
    measure_all(circuit, 0..(n - 1))
  end

  @doc """
  Measures every qubit in the given list or range into its same-index
  classical bit (qubit `i` → classical bit `i`).

  ## Examples

      iex> qc = Qx.create_circuit(3, 3) |> Qx.Patterns.measure_all([0, 2])
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:measure, [0, 0], []}, {:measure, [2, 2], []}]
  """
  @spec measure_all(QuantumCircuit.t(), qubits()) :: QuantumCircuit.t()
  def measure_all(%QuantumCircuit{} = circuit, qubits) do
    Enum.reduce(qubits_to_list(qubits), circuit, fn i, acc ->
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
    barrier_all(circuit, 0..(n - 1))
  end

  @doc """
  Adds a single barrier instruction spanning the given list or range of
  qubits.

  An empty list or empty range is a no-op (returns `circuit` unchanged).

  ## Examples

      iex> qc = Qx.create_circuit(4) |> Qx.Patterns.barrier_all([0, 2])
      iex> Qx.QuantumCircuit.get_instructions(qc)
      [{:barrier, [0, 2], []}]
  """
  @spec barrier_all(QuantumCircuit.t(), qubits()) :: QuantumCircuit.t()
  def barrier_all(%QuantumCircuit{} = circuit, qubits) do
    list = qubits_to_list(qubits)

    if list == [] do
      circuit
    else
      Operations.barrier(circuit, list)
    end
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

  # Internal: normalise `qubits` (list or Range) to a list, then reduce the
  # circuit by applying `op_fn.(acc, qubit)` for each qubit in iteration
  # order. Empty input is a deliberate no-op.
  defp reduce_qubits(circuit, qubits, op_fn) do
    Enum.reduce(qubits_to_list(qubits), circuit, fn q, acc -> op_fn.(acc, q) end)
  end

  defp qubits_to_list(qubits) when is_list(qubits), do: qubits
  defp qubits_to_list(%Range{} = qubits), do: Enum.to_list(qubits)
end
