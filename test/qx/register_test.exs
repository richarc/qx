defmodule Qx.RegisterTest do
  use ExUnit.Case
  doctest Qx.Register

  alias Qx.Register

  # Helper function for approximate equality
  defp approx_equal?(a, b, tolerance \\ 0.01) do
    abs(a - b) < tolerance
  end

  describe "register creation" do
    test "new/1 with integer creates register with all |0⟩ states" do
      reg = Register.new(2)
      assert reg.num_qubits == 2
      assert Nx.shape(reg.state) == {4}

      # Should be in |00⟩ state
      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()
      assert approx_equal?(Enum.at(probs, 0), 1.0)  # |00⟩
      assert approx_equal?(Enum.sum(Enum.drop(probs, 1)), 0.0)  # All others zero
    end

    test "new/1 with qubit list creates register from tensor product" do
      q1 = Qx.Qubit.one()  # |1⟩
      q2 = Qx.Qubit.new()  # |0⟩

      reg = Register.new([q1, q2])
      assert reg.num_qubits == 2

      # Should be in |10⟩ state (q1 is |1⟩, q2 is |0⟩)
      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()
      assert approx_equal?(Enum.at(probs, 2), 1.0)  # |10⟩ = index 2
    end

    test "new/1 with superposition qubits" do
      q1 = Qx.Qubit.plus()  # (|0⟩ + |1⟩)/√2
      q2 = Qx.Qubit.new()   # |0⟩

      reg = Register.new([q1, q2])
      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()

      # |+0⟩ = (|00⟩ + |10⟩)/√2
      assert approx_equal?(Enum.at(probs, 0), 0.5)  # |00⟩
      assert approx_equal?(Enum.at(probs, 2), 0.5)  # |10⟩
    end

    test "new/1 rejects empty list" do
      assert_raise ArgumentError, fn ->
        Register.new([])
      end
    end

    test "new/1 rejects too many qubits" do
      assert_raise ArgumentError, fn ->
        Register.new(21)
      end
    end

    test "new/1 validates qubits in list" do
      invalid_qubit = Nx.tensor([1.0, 1.0])  # Not normalized

      assert_raise ArgumentError, ~r/Invalid qubit/, fn ->
        Register.new([invalid_qubit])
      end
    end
  end

  describe "single-qubit gates" do
    test "h/2 applies Hadamard to specific qubit" do
      reg = Register.new(2) |> Register.h(0)
      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()

      # H on qubit 0 (leftmost): |00⟩ → (|00⟩ + |10⟩)/√2
      assert approx_equal?(Enum.at(probs, 0), 0.5)  # |00⟩
      assert approx_equal?(Enum.at(probs, 2), 0.5)  # |10⟩
    end

    test "x/2 flips specific qubit" do
      reg = Register.new(2) |> Register.x(1)
      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()

      # X on qubit 1 (rightmost): |00⟩ → |01⟩
      assert approx_equal?(Enum.at(probs, 1), 1.0)
    end

    test "can apply gates to different qubits" do
      reg = Register.new(2)
        |> Register.x(0)
        |> Register.x(1)

      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()

      # Should be |11⟩
      assert approx_equal?(Enum.at(probs, 3), 1.0)
    end

    test "y/2 preserves normalization" do
      reg = Register.new(2) |> Register.y(0)
      assert Register.valid?(reg)
    end

    test "z/2 applies phase without changing probabilities" do
      reg = Register.new(2) |> Register.h(0)
      probs_before = Register.get_probabilities(reg) |> Nx.to_flat_list()

      reg = Register.z(reg, 0)
      probs_after = Register.get_probabilities(reg) |> Nx.to_flat_list()

      # Z changes phase but not probabilities
      assert approx_equal?(Enum.at(probs_before, 0), Enum.at(probs_after, 0))
      assert approx_equal?(Enum.at(probs_before, 2), Enum.at(probs_after, 2))
    end

    test "s/2 and t/2 preserve normalization" do
      reg = Register.new(2)
        |> Register.s(0)
        |> Register.t(1)

      assert Register.valid?(reg)
    end

    test "raises on invalid qubit index" do
      reg = Register.new(2)

      assert_raise ArgumentError, fn ->
        Register.h(reg, 5)
      end
    end
  end

  describe "rotation gates" do
    test "rx/3 with π flips qubit" do
      reg = Register.new(2) |> Register.rx(0, :math.pi())
      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()

      # RX(π) on qubit 0 (leftmost): |00⟩ → |10⟩
      assert approx_equal?(Enum.at(probs, 2), 1.0)
    end

    test "ry/3 with π/2 creates superposition" do
      reg = Register.new(2) |> Register.ry(1, :math.pi() / 2)
      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()

      # RY(π/2) on qubit 1 (rightmost): |00⟩ → (|00⟩ + |01⟩)/√2
      assert approx_equal?(Enum.at(probs, 0), 0.5)
      assert approx_equal?(Enum.at(probs, 1), 0.5)
    end

    test "rz/3 preserves probabilities" do
      reg = Register.new(2) |> Register.h(0)
      probs_before = Register.get_probabilities(reg) |> Nx.to_flat_list()

      reg = Register.rz(reg, 0, :math.pi() / 4)
      probs_after = Register.get_probabilities(reg) |> Nx.to_flat_list()

      Enum.zip(probs_before, probs_after)
      |> Enum.each(fn {before, after_val} ->
        assert approx_equal?(before, after_val)
      end)
    end

    test "phase/3 gate preserves normalization" do
      reg = Register.new(3)
        |> Register.phase(0, :math.pi() / 3)
        |> Register.phase(1, :math.pi() / 6)
        |> Register.phase(2, :math.pi() / 12)

      assert Register.valid?(reg)
    end
  end

  describe "multi-qubit gates" do
    test "cx/3 creates Bell state" do
      reg = Register.new(2)
        |> Register.h(0)
        |> Register.cx(0, 1)

      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()

      # Bell state: (|00⟩ + |11⟩)/√2
      assert approx_equal?(Enum.at(probs, 0), 0.5)  # |00⟩
      assert approx_equal?(Enum.at(probs, 1), 0.0)  # |01⟩
      assert approx_equal?(Enum.at(probs, 2), 0.0)  # |10⟩
      assert approx_equal?(Enum.at(probs, 3), 0.5)  # |11⟩
    end

    test "cx/3 with control |0⟩ does nothing" do
      reg = Register.new(2)
        |> Register.x(1)  # |01⟩ (qubit 1 is rightmost)
        |> Register.cx(0, 1)

      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()

      # Control (qubit 0) is |0⟩, so target unchanged: stays |01⟩
      assert approx_equal?(Enum.at(probs, 1), 1.0)
    end

    test "cx/3 with control |1⟩ flips target" do
      reg = Register.new(2)
        |> Register.x(0)  # |10⟩
        |> Register.cx(0, 1)

      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()

      # Control is |1⟩, so target flips: |10⟩ → |11⟩
      assert approx_equal?(Enum.at(probs, 3), 1.0)
    end

    test "cz/3 gate works correctly" do
      reg = Register.new(2)
        |> Register.h(0)
        |> Register.h(1)
        |> Register.cz(0, 1)

      assert Register.valid?(reg)
    end

    test "ccx/3 Toffoli gate with both controls |1⟩" do
      reg = Register.new(3)
        |> Register.x(0)  # Control 1: |1⟩
        |> Register.x(1)  # Control 2: |1⟩
        |> Register.ccx(0, 1, 2)

      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()

      # Both controls |1⟩, target flips: |110⟩ → |111⟩
      assert approx_equal?(Enum.at(probs, 7), 1.0)  # |111⟩ = index 7
    end

    test "ccx/3 with one control |0⟩ does nothing" do
      reg = Register.new(3)
        |> Register.x(0)  # Qubit 0 (leftmost): |100⟩
        |> Register.ccx(0, 1, 2)

      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()

      # Only one control |1⟩, target unchanged: stays |100⟩
      assert approx_equal?(Enum.at(probs, 4), 1.0)  # |100⟩ = index 4
    end

    test "raises when control and target are same" do
      reg = Register.new(2)

      assert_raise ArgumentError, fn ->
        Register.cx(reg, 0, 0)
      end
    end

    test "raises when Toffoli qubits not all different" do
      reg = Register.new(3)

      assert_raise ArgumentError, fn ->
        Register.ccx(reg, 0, 0, 2)
      end
    end
  end

  describe "state inspection" do
    test "state_vector/1 returns the state tensor" do
      reg = Register.new(2)
      state = Register.state_vector(reg)

      assert Nx.shape(state) == {4}
      assert Nx.type(state) == {:c, 64}
    end

    test "get_probabilities/1 returns probability distribution" do
      reg = Register.new(2) |> Register.h(0) |> Register.h(1)
      probs = Register.get_probabilities(reg)

      assert Nx.shape(probs) == {4}

      # All states equally likely
      probs_list = Nx.to_flat_list(probs)
      Enum.each(probs_list, fn p ->
        assert approx_equal?(p, 0.25)
      end)
    end

    test "show_state/1 returns map with state info" do
      reg = Register.new(2)
      info = Register.show_state(reg)

      assert is_map(info)
      assert Map.has_key?(info, :state)
      assert Map.has_key?(info, :amplitudes)
      assert Map.has_key?(info, :probabilities)
    end

    test "show_state/1 for Bell state" do
      reg = Register.new(2)
        |> Register.h(0)
        |> Register.cx(0, 1)

      info = Register.show_state(reg)

      # Check that we have non-zero amplitudes for |00⟩ and |11⟩
      probs = info.probabilities

      # Find |00⟩ and |11⟩ probabilities
      prob_00 = probs |> Enum.find(fn {basis, _} -> basis == "|00⟩" end) |> elem(1)
      prob_11 = probs |> Enum.find(fn {basis, _} -> basis == "|11⟩" end) |> elem(1)

      assert approx_equal?(prob_00, 0.5)
      assert approx_equal?(prob_11, 0.5)
    end

    test "valid?/1 returns true for normalized register" do
      reg = Register.new(2)
        |> Register.h(0)
        |> Register.cx(0, 1)

      assert Register.valid?(reg)
    end
  end

  describe "gate chaining" do
    test "can chain multiple single-qubit gates" do
      reg = Register.new(3)
        |> Register.h(0)
        |> Register.x(1)
        |> Register.z(2)
        |> Register.s(0)

      assert Register.valid?(reg)
    end

    test "can chain single and multi-qubit gates" do
      reg = Register.new(3)
        |> Register.h(0)
        |> Register.h(1)
        |> Register.cx(0, 1)
        |> Register.cx(1, 2)

      assert Register.valid?(reg)
    end

    test "GHZ state creation" do
      reg = Register.new(3)
        |> Register.h(0)
        |> Register.cx(0, 1)
        |> Register.cx(1, 2)

      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()

      # GHZ: (|000⟩ + |111⟩)/√2
      assert approx_equal?(Enum.at(probs, 0), 0.5)  # |000⟩
      assert approx_equal?(Enum.at(probs, 7), 0.5)  # |111⟩
    end
  end

  describe "comparison with circuit mode" do
    test "Bell state matches circuit mode" do
      # Calculation mode
      calc_reg = Register.new(2)
        |> Register.h(0)
        |> Register.cx(0, 1)
      calc_probs = Register.get_probabilities(calc_reg) |> Nx.to_flat_list()

      # Circuit mode
      circuit = Qx.create_circuit(2)
        |> Qx.h(0)
        |> Qx.cx(0, 1)
      circuit_result = Qx.run(circuit)
      circuit_probs = Nx.to_flat_list(circuit_result.probabilities)

      Enum.zip(calc_probs, circuit_probs)
      |> Enum.each(fn {calc, circ} ->
        assert approx_equal?(calc, circ)
      end)
    end

    test "GHZ state matches circuit mode" do
      calc_reg = Register.new(3)
        |> Register.h(0)
        |> Register.cx(0, 1)
        |> Register.cx(1, 2)
      calc_probs = Register.get_probabilities(calc_reg) |> Nx.to_flat_list()

      circuit_result = Qx.ghz_state() |> Qx.run()
      circuit_probs = Nx.to_flat_list(circuit_result.probabilities)

      Enum.zip(calc_probs, circuit_probs)
      |> Enum.each(fn {calc, circ} ->
        assert approx_equal?(calc, circ)
      end)
    end

    test "single-qubit gate sequence matches" do
      calc_reg = Register.new(2)
        |> Register.h(0)
        |> Register.x(1)
        |> Register.z(0)
      calc_probs = Register.get_probabilities(calc_reg) |> Nx.to_flat_list()

      circuit = Qx.create_circuit(2)
        |> Qx.h(0)
        |> Qx.x(1)
        |> Qx.z(0)
      circuit_result = Qx.run(circuit)
      circuit_probs = Nx.to_flat_list(circuit_result.probabilities)

      Enum.zip(calc_probs, circuit_probs)
      |> Enum.each(fn {calc, circ} ->
        assert approx_equal?(calc, circ)
      end)
    end
  end

  describe "edge cases" do
    test "single qubit register works" do
      reg = Register.new(1) |> Register.h(0)
      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.5)
      assert approx_equal?(Enum.at(probs, 1), 0.5)
    end

    test "larger register (5 qubits)" do
      reg = Register.new(5)
        |> Register.h(0)
        |> Register.h(1)
        |> Register.h(2)
        |> Register.h(3)
        |> Register.h(4)

      assert reg.num_qubits == 5
      assert Nx.shape(reg.state) == {32}
      assert Register.valid?(reg)

      # All 32 states equally likely
      probs = Register.get_probabilities(reg) |> Nx.to_flat_list()
      Enum.each(probs, fn p ->
        assert approx_equal?(p, 1.0 / 32)
      end)
    end

    test "all gates preserve normalization" do
      reg = Register.new(3)

      gates = [
        &Register.h(&1, 0),
        &Register.x(&1, 1),
        &Register.y(&1, 2),
        &Register.z(&1, 0),
        &Register.s(&1, 1),
        &Register.t(&1, 2)
      ]

      final_reg = Enum.reduce(gates, reg, fn gate, r -> gate.(r) end)
      assert Register.valid?(final_reg)
    end
  end
end
