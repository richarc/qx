defmodule Qx.Operations do
  @moduledoc """
  Quantum gate operations for quantum circuits.

  This module provides functions for applying quantum gates to quantum circuits,
  including single-qubit gates (H, X, Y, Z), two-qubit gates (CNOT), and
  three-qubit gates (CCNOT/Toffoli).
  """

  alias Qx.QuantumCircuit

  @doc """
  Applies a Hadamard gate to the specified qubit.

  The Hadamard gate creates superposition, transforming |0⟩ to (|0⟩ + |1⟩)/√2
  and |1⟩ to (|0⟩ - |1⟩)/√2.

  ## Parameters
    * `circuit` - The quantum circuit
    * `qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 0)
      iex> qc = Qx.Operations.h(qc, 0)
      iex> [{gate, qubits, _params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate, qubits}
      {:h, [0]}
  """
  def h(%QuantumCircuit{} = circuit, qubit) do
    QuantumCircuit.add_gate(circuit, :h, qubit)
  end

  @doc """
  Applies a Pauli-X gate (bit flip) to the specified qubit.

  The X gate flips |0⟩ to |1⟩ and |1⟩ to |0⟩.

  ## Parameters
    * `circuit` - The quantum circuit
    * `qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 0)
      iex> qc = Qx.Operations.x(qc, 0)
      iex> [{gate, qubits, _params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate, qubits}
      {:x, [0]}
  """
  def x(%QuantumCircuit{} = circuit, qubit) do
    QuantumCircuit.add_gate(circuit, :x, qubit)
  end

  @doc """
  Applies a Pauli-Y gate to the specified qubit.

  The Y gate applies both bit flip and phase flip transformations.

  ## Parameters
    * `circuit` - The quantum circuit
    * `qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 0)
      iex> qc = Qx.Operations.y(qc, 0)
      iex> [{gate, qubits, _params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate, qubits}
      {:y, [0]}
  """
  def y(%QuantumCircuit{} = circuit, qubit) do
    QuantumCircuit.add_gate(circuit, :y, qubit)
  end

  @doc """
  Applies a Pauli-Z gate (phase flip) to the specified qubit.

  The Z gate leaves |0⟩ unchanged and applies a phase of -1 to |1⟩.

  ## Parameters
    * `circuit` - The quantum circuit
    * `qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 0)
      iex> qc = Qx.Operations.z(qc, 0)
      iex> [{gate, qubits, _params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate, qubits}
      {:z, [0]}
  """
  def z(%QuantumCircuit{} = circuit, qubit) do
    QuantumCircuit.add_gate(circuit, :z, qubit)
  end

  @doc """
  Applies a controlled-X (CNOT) gate.

  The CNOT gate flips the target qubit if and only if the control qubit is |1⟩.

  ## Parameters
    * `circuit` - The quantum circuit
    * `control_qubit` - Control qubit index
    * `target_qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 0)
      iex> qc = Qx.Operations.cx(qc, 0, 1)
      iex> [{gate, qubits, _params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate, qubits}
      {:cx, [0, 1]}
  """
  def cx(%QuantumCircuit{} = circuit, control_qubit, target_qubit) do
    QuantumCircuit.add_two_qubit_gate(circuit, :cx, control_qubit, target_qubit)
  end

  @doc """
  Applies a controlled-controlled-X (CCNOT/Toffoli) gate.

  The CCNOT gate flips the target qubit if and only if both control qubits are |1⟩.

  ## Parameters
    * `circuit` - The quantum circuit
    * `control1` - First control qubit index
    * `control2` - Second control qubit index
    * `target` - Target qubit index

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(3, 0)
      iex> qc = Qx.Operations.ccx(qc, 0, 1, 2)
      iex> [{gate, qubits, _params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate, qubits}
      {:ccx, [0, 1, 2]}
  """
  def ccx(%QuantumCircuit{} = circuit, control1, control2, target) do
    QuantumCircuit.add_three_qubit_gate(circuit, :ccx, control1, control2, target)
  end

  @doc """
  Applies a rotation around the X-axis by the specified angle.

  ## Parameters
    * `circuit` - The quantum circuit
    * `qubit` - Target qubit index
    * `theta` - Rotation angle in radians

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(1, 0)
      iex> qc = Qx.Operations.rx(qc, 0, :math.pi/2)
      iex> [{gate, qubits, params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate, qubits, length(params)}
      {:rx, [0], 1}
  """
  def rx(%QuantumCircuit{} = circuit, qubit, theta) do
    QuantumCircuit.add_gate(circuit, :rx, qubit, [theta])
  end

  @doc """
  Applies a rotation around the Y-axis by the specified angle.

  ## Parameters
    * `circuit` - The quantum circuit
    * `qubit` - Target qubit index
    * `theta` - Rotation angle in radians

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(1, 0)
      iex> qc = Qx.Operations.ry(qc, 0, :math.pi/2)
      iex> [{gate, qubits, params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate, qubits, length(params)}
      {:ry, [0], 1}
  """
  def ry(%QuantumCircuit{} = circuit, qubit, theta) do
    QuantumCircuit.add_gate(circuit, :ry, qubit, [theta])
  end

  @doc """
  Applies a rotation around the Z-axis by the specified angle.

  ## Parameters
  * `circuit` - The quantum circuit
  * `qubit` - Target qubit index
  * `theta` - Rotation angle in radians

  ## Examples

  iex> qc = Qx.QuantumCircuit.new(1, 0)
  iex> qc = Qx.Operations.rz(qc, 0, :math.pi/2)
  iex> [{gate, qubits, params}] = Qx.QuantumCircuit.get_instructions(qc)
  iex> {gate, qubits, length(params)}
  {:rz, [0], 1}
  """
  def rz(%QuantumCircuit{} = circuit, qubit, theta) do
    QuantumCircuit.add_gate(circuit, :rz, qubit, [theta])
  end

  @doc """
  Applies a phase gate with the specified phase.

  ## Parameters
    * `circuit` - The quantum circuit
    * `qubit` - Target qubit index
    * `phi` - Phase angle in radians

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(1, 0)
      iex> qc = Qx.Operations.phase(qc, 0, :math.pi/4)
      iex> [{gate, qubits, params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate, qubits, length(params)}
      {:phase, [0], 1}
  """
  def phase(%QuantumCircuit{} = circuit, qubit, phi) do
    QuantumCircuit.add_gate(circuit, :phase, qubit, [phi])
  end

  @doc """
  Applies an S gate (phase gate with π/2 phase).

  ## Parameters
    * `circuit` - The quantum circuit
    * `qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(1, 0)
      iex> qc = Qx.Operations.s(qc, 0)
      iex> [{gate, qubits, _params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate, qubits}
      {:s, [0]}
  """
  def s(%QuantumCircuit{} = circuit, qubit) do
    QuantumCircuit.add_gate(circuit, :s, qubit)
  end

  @doc """
  Applies a T gate (phase gate with π/4 phase).

  ## Parameters
    * `circuit` - The quantum circuit
    * `qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(1, 0)
      iex> qc = Qx.Operations.t(qc, 0)
      iex> [{gate, qubits, _params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate, qubits}
      {:t, [0]}
  """
  def t(%QuantumCircuit{} = circuit, qubit) do
    QuantumCircuit.add_gate(circuit, :t, qubit)
  end

  @doc """
  Adds a measurement operation to the circuit.

  ## Parameters
    * `circuit` - The quantum circuit
    * `qubit` - Qubit index to measure
    * `classical_bit` - Classical bit index to store the result

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 2)
      iex> qc = Qx.Operations.measure(qc, 0, 0)
      iex> [{qubit, classical_bit}] = Qx.QuantumCircuit.get_measurements(qc)
      iex> {qubit, classical_bit}
      {0, 0}
  """
  def measure(%QuantumCircuit{} = circuit, qubit, classical_bit) do
    QuantumCircuit.add_measurement(circuit, qubit, classical_bit)
  end
end
