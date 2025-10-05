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

    # Check amplitudes (c64 representation)
    amp_0 = Nx.to_number(state[0])
    amp_1 = Nx.to_number(state[1])
    expected_amp = 1.0 / :math.sqrt(2)

    # Hadamard should create equal superposition with real coefficients
    assert abs(Complex.real(amp_0) - expected_amp) < 0.01
    assert abs(Complex.real(amp_1) - expected_amp) < 0.01
    assert abs(Complex.imag(amp_0)) < 0.01
    assert abs(Complex.imag(amp_1)) < 0.01
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

  # Conditional execution tests
  describe "conditional operations" do
    test "c_if adds conditional instruction to circuit" do
      qc =
        Qx.create_circuit(2, 2)
        |> Qx.h(0)
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)

      instructions = Qx.QuantumCircuit.get_instructions(qc)
      # H, measure, c_if = 3 instructions
      assert length(instructions) == 3
      assert {:c_if, [0, 1], _} = List.last(instructions)
    end

    test "c_if raises error for invalid classical bit" do
      qc = Qx.create_circuit(2, 1)

      assert_raise ArgumentError, fn ->
        Qx.c_if(qc, 5, 1, fn c -> Qx.x(c, 1) end)
      end
    end

    test "c_if raises error for invalid value" do
      qc = Qx.create_circuit(2, 2)

      assert_raise ArgumentError, fn ->
        Qx.c_if(qc, 0, 2, fn c -> Qx.x(c, 1) end)
      end
    end

    test "c_if captures multiple gates in conditional block" do
      qc =
        Qx.create_circuit(3, 2)
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c ->
          c |> Qx.x(1) |> Qx.h(2)
        end)

      {:c_if, [0, 1], instructions} =
        qc |> Qx.QuantumCircuit.get_instructions() |> List.last()

      assert length(instructions) == 2
      assert {:x, [1], []} in instructions
      assert {:h, [2], []} in instructions
    end

    test "executes conditional gate when condition is true" do
      # Create circuit that measures |1⟩ and conditionally applies X
      qc =
        Qx.create_circuit(2, 2)
        # Set qubit 0 to |1⟩
        |> Qx.x(0)
        # Measure (always gets 1)
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
        |> Qx.measure(1, 1)

      result = Qx.run(qc, 100)

      # All shots should measure classical bits as [1, 1]
      assert result.counts[[1, 1]] == 100
    end

    test "skips conditional gate when condition is false" do
      # Measure |0⟩ and check for c==1 (always false)
      qc =
        Qx.create_circuit(2, 2)
        # Measure |0⟩ (always gets 0)
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
        |> Qx.measure(1, 1)

      result = Qx.run(qc, 100)

      # All shots should measure classical bits as [0, 0]
      assert result.counts[[0, 0]] == 100
    end

    test "conditional gate with value == 0" do
      # Test checking for classical bit == 0
      qc =
        Qx.create_circuit(2, 2)
        # Qubit 0 starts in |0⟩
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 0, fn c -> Qx.x(c, 1) end)
        |> Qx.measure(1, 1)

      result = Qx.run(qc, 100)

      # All shots should measure classical bits as [0, 1]
      assert result.counts[[0, 1]] == 100
    end

    test "handles probabilistic conditionals correctly" do
      # H gate creates 50/50 superposition
      qc =
        Qx.create_circuit(2, 2)
        |> Qx.h(0)
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
        |> Qx.measure(1, 1)

      result = Qx.run(qc, 1000)

      # Should get roughly 50% [0,0] and 50% [1,1]
      count_00 = Map.get(result.counts, [0, 0], 0)
      count_11 = Map.get(result.counts, [1, 1], 0)

      assert_in_delta count_00, 500, 100
      assert_in_delta count_11, 500, 100
      assert count_00 + count_11 == 1000
    end

    test "quantum teleportation with conditionals" do
      # Full teleportation circuit
      qc =
        Qx.create_circuit(3, 3)
        # Prepare |1⟩ to teleport
        |> Qx.x(0)
        # Create Bell pair
        |> Qx.h(1)
        |> Qx.cx(1, 2)
        # Bell measurement
        |> Qx.cx(0, 1)
        |> Qx.h(0)
        |> Qx.measure(0, 0)
        |> Qx.measure(1, 1)
        # Conditional corrections
        |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)
        |> Qx.c_if(0, 1, fn c -> Qx.z(c, 2) end)
        |> Qx.measure(2, 2)

      result = Qx.run(qc, 100)

      # Qubit 2 should always measure |1⟩
      total_measure_1 =
        Enum.reduce(result.counts, 0, fn {bits, count}, acc ->
          if Enum.at(bits, 2) == 1, do: acc + count, else: acc
        end)

      assert total_measure_1 == 100
    end

    test "multiple conditionals in sequence" do
      qc =
        Qx.create_circuit(3, 3)
        |> Qx.x(0)
        |> Qx.x(1)
        |> Qx.measure(0, 0)
        |> Qx.measure(1, 1)
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 2) end)
        |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)
        |> Qx.measure(2, 2)

      result = Qx.run(qc, 100)

      # Both conditionals fire, so X applied twice (no net effect)
      # Qubit 2 should measure |0⟩
      assert result.counts[[1, 1, 0]] == 100
    end

    test "nested conditionals raise error" do
      qc = Qx.create_circuit(3, 3)

      assert_raise ArgumentError, ~r/Nested conditionals/, fn ->
        Qx.c_if(qc, 0, 1, fn c ->
          Qx.c_if(c, 1, 1, fn c2 -> Qx.x(c2, 2) end)
        end)
      end
    end
  end
end
