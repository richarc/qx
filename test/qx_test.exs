defmodule QxTest do
  use ExUnit.Case
  doctest Qx

  test "create simple quantum circuit" do
    qc = Qx.create_circuit(2, 2)
    assert qc.num_qubits == 2
    assert qc.num_classical_bits == 2
  end

  test "create circuit with only qubits" do
    qc = Qx.create_circuit(1)
    assert qc.num_qubits == 1
    assert qc.num_classical_bits == 0
  end

  test "apply hadamard gate" do
    qc = Qx.create_circuit(1) |> Qx.h(0)
    instructions = Qx.QuantumCircuit.get_instructions(qc)
    assert length(instructions) == 1
    assert [{:h, [0], []}] = instructions
  end

  test "apply x gate" do
    qc = Qx.create_circuit(1) |> Qx.x(0)
    instructions = Qx.QuantumCircuit.get_instructions(qc)
    assert length(instructions) == 1
    assert [{:x, [0], []}] = instructions
  end

  test "apply cnot gate" do
    qc = Qx.create_circuit(2) |> Qx.cx(0, 1)
    instructions = Qx.QuantumCircuit.get_instructions(qc)
    assert length(instructions) == 1
    assert [{:cx, [0, 1], []}] = instructions
  end

  test "add measurement" do
    qc = Qx.create_circuit(2, 2) |> Qx.measure(0, 0)
    measurements = Qx.QuantumCircuit.get_measurements(qc)
    assert length(measurements) == 1
    assert [{0, 0}] = measurements
  end

  test "run simple circuit" do
    qc = Qx.create_circuit(1)
    result = Qx.run(qc)
    assert is_map(result)
    assert Map.has_key?(result, :probabilities)
    assert Map.has_key?(result, :state)
    assert Map.has_key?(result, :shots)
  end

  test "run hadamard circuit" do
    qc = Qx.create_circuit(1) |> Qx.h(0)
    result = Qx.run(qc)
    probs = Nx.to_flat_list(result.probabilities)

    # After Hadamard, should have equal probabilities for |0⟩ and |1⟩
    assert abs(Enum.at(probs, 0) - 0.5) < 0.01
    assert abs(Enum.at(probs, 1) - 0.5) < 0.01
  end

  test "bell state creation" do
    bell_circuit = Qx.bell_state()
    assert bell_circuit.num_qubits == 2
    instructions = Qx.QuantumCircuit.get_instructions(bell_circuit)
    assert length(instructions) == 2
    assert [{:h, [0], []}, {:cx, [0, 1], []}] = instructions
  end

  test "ghz state creation" do
    ghz_circuit = Qx.ghz_state()
    assert ghz_circuit.num_qubits == 3
    instructions = Qx.QuantumCircuit.get_instructions(ghz_circuit)
    assert length(instructions) == 3
  end

  test "superposition creation" do
    sup_circuit = Qx.superposition()
    assert sup_circuit.num_qubits == 1
    instructions = Qx.QuantumCircuit.get_instructions(sup_circuit)
    assert length(instructions) == 1
    assert [{:h, [0], []}] = instructions
  end

  test "bell state simulation" do
    result = Qx.bell_state() |> Qx.run()
    probs = Nx.to_flat_list(result.probabilities)

    # Bell state should have equal probabilities for |00⟩ and |11⟩, zero for |01⟩ and |10⟩
    # |00⟩
    assert abs(Enum.at(probs, 0) - 0.5) < 0.01
    # |01⟩
    assert abs(Enum.at(probs, 1) - 0.0) < 0.01
    # |10⟩
    assert abs(Enum.at(probs, 2) - 0.0) < 0.01
    # |11⟩
    assert abs(Enum.at(probs, 3) - 0.5) < 0.01
  end

  test "measurement with bell state" do
    qc =
      Qx.create_circuit(2, 2)
      |> Qx.h(0)
      |> Qx.cx(0, 1)
      |> Qx.measure(0, 0)
      |> Qx.measure(1, 1)

    result = Qx.run(qc, 100)
    assert result.shots == 100
    assert is_map(result.counts)

    # Should have measurements for classical bits
    assert length(result.classical_bits) == 100
  end

  test "get state directly" do
    state = Qx.create_circuit(1) |> Qx.h(0) |> Qx.get_state()
    assert Nx.shape(state) == {2}

    state_list = Nx.to_flat_list(state)
    # Hadamard should create equal superposition
    assert abs(abs(Enum.at(state_list, 0)) - 1.0 / :math.sqrt(2)) < 0.01
    assert abs(abs(Enum.at(state_list, 1)) - 1.0 / :math.sqrt(2)) < 0.01
  end

  test "get probabilities directly" do
    probs = Qx.create_circuit(1) |> Qx.h(0) |> Qx.get_probabilities()
    assert Nx.shape(probs) == {2}

    prob_list = Nx.to_flat_list(probs)
    assert abs(Enum.at(prob_list, 0) - 0.5) < 0.01
    assert abs(Enum.at(prob_list, 1) - 0.5) < 0.01
  end

  test "version returns string" do
    version = Qx.version()
    assert is_binary(version)
  end

  test "complex circuit with multiple gates" do
    qc =
      Qx.create_circuit(3, 3)
      |> Qx.h(0)
      |> Qx.x(1)
      |> Qx.cx(0, 2)
      |> Qx.measure(0, 0)
      |> Qx.measure(1, 1)
      |> Qx.measure(2, 2)

    result = Qx.run(qc)
    assert is_map(result)
    # default shots
    assert result.shots == 1024
  end
end
