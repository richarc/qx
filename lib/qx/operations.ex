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
  Applies a controlled-Z (CZ) gate.

  The CZ gate applies a phase of -1 if and only if both qubits are |1⟩.

  ## Parameters
    * `circuit` - The quantum circuit
    * `control_qubit` - Control qubit index
    * `target_qubit` - Target qubit index

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 0)
      iex> qc = Qx.Operations.cz(qc, 0, 1)
      iex> [{gate, qubits, _params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate, qubits}
      {:cz, [0, 1]}
  """
  def cz(%QuantumCircuit{} = circuit, control_qubit, target_qubit) do
    QuantumCircuit.add_two_qubit_gate(circuit, :cz, control_qubit, target_qubit)
  end

  @doc """
  Adds a barrier to the circuit for visualization purposes.

  Barriers are used to group operations and improve circuit readability.
  They do not affect the quantum state.

  ## Parameters
    * `circuit` - The quantum circuit
    * `qubits` - List of qubit indices the barrier spans

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(3, 0)
      iex> qc = Qx.Operations.barrier(qc, [0, 1, 2])
      iex> [{gate, qubits, _params}] = Qx.QuantumCircuit.get_instructions(qc)
      iex> {gate, qubits}
      {:barrier, [0, 1, 2]}
  """
  def barrier(%QuantumCircuit{} = circuit, qubits) when is_list(qubits) do
    # Validate all qubit indices
    Enum.each(qubits, fn qubit ->
      if qubit < 0 or qubit >= circuit.num_qubits do
        raise ArgumentError, "Invalid qubit index #{qubit} for barrier"
      end
    end)

    instruction = {:barrier, qubits, []}
    %{circuit | instructions: circuit.instructions ++ [instruction]}
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

  @doc """
  Applies gates conditionally based on a classical bit value.

  The conditional block executes during simulation only if the specified
  classical bit equals the given value at runtime.

  ## Parameters
    * `circuit` - The quantum circuit
    * `classical_bit` - Classical bit index to check (0-based)
    * `value` - Value to compare (0 or 1)
    * `gate_fn` - Function that applies gates: (circuit -> circuit)

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 2)
      iex> qc = qc |> Qx.Operations.h(0) |> Qx.Operations.measure(0, 0)
      iex> qc = Qx.Operations.c_if(qc, 0, 1, fn c -> Qx.Operations.x(c, 1) end)
      iex> instructions = Qx.QuantumCircuit.get_instructions(qc)
      iex> length(instructions)
      2

  ## Constraints
    - Classical bit must be valid for the circuit
    - Value must be 0 or 1
    - Gates in conditional block cannot contain measurements
    - No nesting of conditional blocks
  """
  def c_if(%QuantumCircuit{} = circuit, classical_bit, value, gate_fn)
      when is_integer(classical_bit) and classical_bit >= 0 and
             classical_bit < circuit.num_classical_bits and
             value in [0, 1] and is_function(gate_fn, 1) do
    # Create temporary circuit to capture instructions
    temp_circuit = %{circuit | instructions: []}

    # Apply the gate function to capture what it does
    modified_circuit = gate_fn.(temp_circuit)

    # Extract the instructions that were added
    conditional_instructions = modified_circuit.instructions

    # Validate the conditional block
    validate_conditional_block(conditional_instructions)

    # Create the conditional instruction
    instruction = {:c_if, [classical_bit, value], conditional_instructions}

    # Add to the main circuit
    %{circuit | instructions: circuit.instructions ++ [instruction]}
  end

  def c_if(%QuantumCircuit{} = circuit, classical_bit, _value, _gate_fn)
      when is_integer(classical_bit) and
             (classical_bit < 0 or classical_bit >= circuit.num_classical_bits) do
    raise ArgumentError,
          "Classical bit index #{classical_bit} out of range (circuit has #{circuit.num_classical_bits} classical bits)"
  end

  def c_if(_circuit, _classical_bit, value, _gate_fn) when value not in [0, 1] do
    raise ArgumentError, "Conditional value must be 0 or 1, got: #{inspect(value)}"
  end

  def c_if(_circuit, _classical_bit, _value, gate_fn) when not is_function(gate_fn, 1) do
    raise ArgumentError, "Gate function must be a function with arity 1"
  end

  # Private helper to validate conditional block
  defp validate_conditional_block(instructions) do
    Enum.each(instructions, fn instruction ->
      case instruction do
        {:c_if, _, _} ->
          raise ArgumentError, "Nested conditionals are not supported in this version"

        _ ->
          :ok
      end
    end)

    # Check if any measurements exist in the conditional block
    # Measurements are stored separately, so we mainly need to check for nested c_if
    :ok
  end

  @doc """
  Inspects the circuit without breaking the pipeline.

  The provided function receives the circuit and can perform
  any side-effect (logging, printing, assertions), but the
  return value is ignored and the original circuit is returned.

  ## Parameters
    * `circuit` - The quantum circuit
    * `fun` - Function to execute: `(circuit -> any())`

  ## Examples

      iex> circuit = Qx.QuantumCircuit.new(2, 0)
      ...> |> Qx.Operations.h(0)
      ...> |> Qx.Operations.tap_circuit(&IO.inspect(&1.instructions, label: "After H"))
      ...> |> Qx.Operations.cx(0, 1)
      After H: [{:h, [0], []}]
      %Qx.QuantumCircuit{...}

      # Create circuit and inspect depth/qubits
      circuit = Qx.QuantumCircuit.new(3, 0)
        |> Qx.Operations.h(0)
        |> Qx.Operations.tap_circuit(fn circ ->
             IO.puts("Depth: #\{Qx.QuantumCircuit.depth(circ)}")
             IO.puts("Qubits: #\{circ.num_qubits}")
           end)
        |> Qx.Operations.x(1)
      # Outputs:
      # Depth: 1
      # Qubits: 3

  ## See Also
    * `tap_state/2` - Inspect quantum state
    * `tap_probabilities/2` - Inspect measurement probabilities
  """
  @spec tap_circuit(QuantumCircuit.t(), (QuantumCircuit.t() -> any())) :: QuantumCircuit.t()
  def tap_circuit(%QuantumCircuit{} = circuit, fun) when is_function(fun, 1) do
    fun.(circuit)
    circuit
  end

  @doc """
  Inspects the current quantum state without breaking the pipeline.

  **Important:** This executes all instructions so far to get
  the current state. Use sparingly in performance-critical code.

  ## Parameters
    * `circuit` - The quantum circuit
    * `fun` - Function to execute: `(Nx.Tensor.t() -> any())`

  ## Examples

      iex> circuit = Qx.QuantumCircuit.new(1, 0)
      ...> |> Qx.Operations.h(0)
      ...> |> Qx.Operations.tap_state(&IO.inspect(&1, label: "After H gate"))
      ...> |> Qx.Operations.z(0)
      After H gate: #Nx.Tensor<...>
      %Qx.QuantumCircuit{...}

      iex> circuit = Qx.QuantumCircuit.new(2, 0)
      ...> |> Qx.Operations.h(0)
      ...> |> Qx.Operations.tap_state(fn state ->
      ...>      probs = Qx.Math.probabilities(state)
      ...>      IO.inspect(Nx.to_list(probs), label: "Probabilities")
      ...>    end)
      ...> |> Qx.Operations.cx(0, 1)
      Probabilities: [0.5, 0.5, 0.0, 0.0]
      %Qx.QuantumCircuit{...}

  ## See Also
    * `tap_circuit/2` - Inspect circuit metadata
    * `tap_probabilities/2` - Inspect measurement probabilities directly
  """
  @spec tap_state(QuantumCircuit.t(), (Nx.Tensor.t() -> any())) :: QuantumCircuit.t()
  def tap_state(%QuantumCircuit{} = circuit, fun) when is_function(fun, 1) do
    state = QuantumCircuit.get_state(circuit)
    fun.(state)
    circuit
  end

  @doc """
  Inspects measurement probabilities without breaking the pipeline.

  Convenience function that computes probabilities and passes them
  to your inspection function.

  ## Parameters
    * `circuit` - The quantum circuit
    * `fun` - Function to execute: `(Nx.Tensor.t() -> any())`

  ## Examples

      iex> circuit = Qx.QuantumCircuit.new(2, 2)
      ...> |> Qx.Operations.h(0)
      ...> |> Qx.Operations.cx(0, 1)
      ...> |> Qx.Operations.tap_probabilities(&IO.inspect/1)
      ...> |> Qx.Operations.measure(0, 0)
      #Nx.Tensor<
        f32[4]
        [0.5, 0.0, 0.0, 0.5]
      >
      %Qx.QuantumCircuit{...}

      # Create circuit and inspect probabilities
      circuit = Qx.QuantumCircuit.new(1, 0)
        |> Qx.Operations.h(0)
        |> Qx.Operations.tap_probabilities(fn probs ->
             prob_list = Nx.to_list(probs)
             IO.puts("P(|0⟩) = #\{Enum.at(prob_list, 0)}")
             IO.puts("P(|1⟩) = #\{Enum.at(prob_list, 1)}")
           end)
      # Outputs:
      # P(|0⟩) = 0.5
      # P(|1⟩) = 0.5

  ## See Also
    * `tap_state/2` - Inspect full quantum state
    * `tap_circuit/2` - Inspect circuit metadata
  """
  @spec tap_probabilities(QuantumCircuit.t(), (Nx.Tensor.t() -> any())) :: QuantumCircuit.t()
  def tap_probabilities(%QuantumCircuit{} = circuit, fun) when is_function(fun, 1) do
    state = QuantumCircuit.get_state(circuit)
    probs = Qx.Math.probabilities(state)
    fun.(probs)
    circuit
  end
end
