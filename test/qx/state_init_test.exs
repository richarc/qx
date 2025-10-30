defmodule Qx.StateInitTest do
  use ExUnit.Case
  doctest Qx.StateInit

  alias Qx.StateInit

  defp approx_equal?(a, b, tolerance \\ 0.01) do
    abs(a - b) < tolerance
  end

  describe "basis_state/3" do
    test "creates |0⟩ state" do
      state = StateInit.basis_state(0, 2)
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 1.0)
      assert approx_equal?(Enum.at(probs, 1), 0.0)
    end

    test "creates |1⟩ state" do
      state = StateInit.basis_state(1, 2)
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.0)
      assert approx_equal?(Enum.at(probs, 1), 1.0)
    end

    test "creates |11⟩ state for 2 qubits" do
      state = StateInit.basis_state(3, 4)
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 3), 1.0)
      assert Enum.sum(Enum.take(probs, 3)) == 0.0
    end

    test "creates arbitrary basis state" do
      state = StateInit.basis_state(5, 8)
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 5), 1.0)
      assert Enum.sum(List.delete_at(probs, 5)) == 0.0
    end

    test "is normalized" do
      state = StateInit.basis_state(2, 8)
      probs = Qx.Math.probabilities(state)
      total = Nx.sum(probs) |> Nx.to_number()

      assert approx_equal?(total, 1.0, 1.0e-6)
    end
  end

  describe "zero_state/2" do
    test "creates |0⟩ for single qubit" do
      state = StateInit.zero_state(1)
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 1.0)
      assert approx_equal?(Enum.at(probs, 1), 0.0)
    end

    test "creates |00⟩ for 2 qubits" do
      state = StateInit.zero_state(2)
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 1.0)
      assert Enum.sum(Enum.drop(probs, 1)) == 0.0
    end

    test "creates |000⟩ for 3 qubits" do
      state = StateInit.zero_state(3)
      assert Nx.shape(state) == {8}

      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      assert approx_equal?(Enum.at(probs, 0), 1.0)
    end

    test "has correct dimension" do
      state = StateInit.zero_state(4)
      assert Nx.shape(state) == {16}
    end
  end

  describe "one_state/1" do
    test "creates |1⟩ state" do
      state = StateInit.one_state()
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.0)
      assert approx_equal?(Enum.at(probs, 1), 1.0)
    end
  end

  describe "plus_state/1" do
    test "creates |+⟩ state with equal superposition" do
      state = StateInit.plus_state()
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.5)
      assert approx_equal?(Enum.at(probs, 1), 0.5)
    end

    test "is normalized" do
      state = StateInit.plus_state()
      probs = Qx.Math.probabilities(state)
      total = Nx.sum(probs) |> Nx.to_number()

      assert approx_equal?(total, 1.0, 1.0e-6)
    end
  end

  describe "minus_state/1" do
    test "creates |-⟩ state with equal superposition" do
      state = StateInit.minus_state()
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.5)
      assert approx_equal?(Enum.at(probs, 1), 0.5)
    end

    test "is normalized" do
      state = StateInit.minus_state()
      probs = Qx.Math.probabilities(state)
      total = Nx.sum(probs) |> Nx.to_number()

      assert approx_equal?(total, 1.0, 1.0e-6)
    end

    test "has opposite phase to |+⟩" do
      plus = StateInit.plus_state()
      minus = StateInit.minus_state()

      # Check that amplitudes have opposite signs
      plus_amp_1 = Nx.to_number(plus[1])
      minus_amp_1 = Nx.to_number(minus[1])

      assert Complex.real(plus_amp_1) > 0
      assert Complex.real(minus_amp_1) < 0
    end
  end

  describe "superposition_state/2" do
    test "creates equal superposition for 1 qubit" do
      state = StateInit.superposition_state(1)
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      assert Enum.all?(probs, &approx_equal?(&1, 0.5))
    end

    test "creates equal superposition for 2 qubits" do
      state = StateInit.superposition_state(2)
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      assert Enum.all?(probs, &approx_equal?(&1, 0.25))
    end

    test "creates equal superposition for 3 qubits" do
      state = StateInit.superposition_state(3)
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      assert Enum.all?(probs, &approx_equal?(&1, 0.125))
    end

    test "is normalized" do
      state = StateInit.superposition_state(4)
      probs = Qx.Math.probabilities(state)
      total = Nx.sum(probs) |> Nx.to_number()

      assert approx_equal?(total, 1.0, 1.0e-6)
    end

    test "has correct dimension" do
      state = StateInit.superposition_state(3)
      assert Nx.shape(state) == {8}
    end
  end

  describe "random_state/2" do
    test "creates valid single qubit state" do
      state = StateInit.random_state(1)
      assert Qx.Validation.valid_qubit?(state)
    end

    test "creates valid multi-qubit state" do
      state = StateInit.random_state(3)
      probs = Qx.Math.probabilities(state)
      total = Nx.sum(probs) |> Nx.to_number()

      assert approx_equal?(total, 1.0, 1.0e-6)
    end

    test "creates different states on multiple calls" do
      state1 = StateInit.random_state(2)
      state2 = StateInit.random_state(2)

      probs1 = Qx.Math.probabilities(state1) |> Nx.to_flat_list()
      probs2 = Qx.Math.probabilities(state2) |> Nx.to_flat_list()

      # Very unlikely to get identical random states
      refute Enum.zip(probs1, probs2) |> Enum.all?(fn {p1, p2} -> approx_equal?(p1, p2, 0.001) end)
    end

    test "has correct dimension" do
      state = StateInit.random_state(4)
      assert Nx.shape(state) == {16}
    end
  end

  describe "bell_state/1" do
    test "creates |Φ+⟩ Bell state" do
      state = StateInit.bell_state()
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      # |Φ+⟩ = (|00⟩ + |11⟩)/√2
      assert approx_equal?(Enum.at(probs, 0), 0.5)  # |00⟩
      assert approx_equal?(Enum.at(probs, 1), 0.0)  # |01⟩
      assert approx_equal?(Enum.at(probs, 2), 0.0)  # |10⟩
      assert approx_equal?(Enum.at(probs, 3), 0.5)  # |11⟩
    end

    test "is normalized" do
      state = StateInit.bell_state()
      probs = Qx.Math.probabilities(state)
      total = Nx.sum(probs) |> Nx.to_number()

      assert approx_equal?(total, 1.0, 1.0e-6)
    end

    test "is maximally entangled" do
      state = StateInit.bell_state()
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      # Only |00⟩ and |11⟩ have non-zero probability
      assert Enum.at(probs, 1) + Enum.at(probs, 2) == 0.0
    end
  end

  describe "ghz_state/2" do
    test "creates GHZ state for 2 qubits (same as Bell)" do
      state = StateInit.ghz_state(2)
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.5)
      assert approx_equal?(Enum.at(probs, 3), 0.5)
      assert Enum.at(probs, 1) + Enum.at(probs, 2) == 0.0
    end

    test "creates GHZ state for 3 qubits" do
      state = StateInit.ghz_state(3)
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      # (|000⟩ + |111⟩)/√2
      assert approx_equal?(Enum.at(probs, 0), 0.5)  # |000⟩
      assert approx_equal?(Enum.at(probs, 7), 0.5)  # |111⟩

      # All others are zero
      assert Enum.sum(Enum.slice(probs, 1..6)) == 0.0
    end

    test "creates GHZ state for 4 qubits" do
      state = StateInit.ghz_state(4)
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      # (|0000⟩ + |1111⟩)/√2
      assert approx_equal?(Enum.at(probs, 0), 0.5)   # |0000⟩
      assert approx_equal?(Enum.at(probs, 15), 0.5)  # |1111⟩

      # All others are zero
      assert Enum.sum(Enum.slice(probs, 1..14)) == 0.0
    end

    test "is normalized" do
      state = StateInit.ghz_state(5)
      probs = Qx.Math.probabilities(state)
      total = Nx.sum(probs) |> Nx.to_number()

      assert approx_equal?(total, 1.0, 1.0e-6)
    end
  end

  describe "w_state/2" do
    test "creates W state for 3 qubits" do
      state = StateInit.w_state(3)
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      expected_prob = 1.0 / 3.0

      # (|001⟩ + |010⟩ + |100⟩)/√3
      assert approx_equal?(Enum.at(probs, 0), 0.0)  # |000⟩
      assert approx_equal?(Enum.at(probs, 1), expected_prob)  # |001⟩
      assert approx_equal?(Enum.at(probs, 2), expected_prob)  # |010⟩
      assert approx_equal?(Enum.at(probs, 3), 0.0)  # |011⟩
      assert approx_equal?(Enum.at(probs, 4), expected_prob)  # |100⟩
      assert approx_equal?(Enum.at(probs, 5), 0.0)  # |101⟩
      assert approx_equal?(Enum.at(probs, 6), 0.0)  # |110⟩
      assert approx_equal?(Enum.at(probs, 7), 0.0)  # |111⟩
    end

    test "creates W state for 4 qubits" do
      state = StateInit.w_state(4)
      probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

      expected_prob = 1.0 / 4.0

      # States with exactly one |1⟩: |0001⟩, |0010⟩, |0100⟩, |1000⟩
      single_one_indices = [1, 2, 4, 8]

      Enum.each(single_one_indices, fn idx ->
        assert approx_equal?(Enum.at(probs, idx), expected_prob)
      end)

      # All other states should be zero
      other_indices = Enum.to_list(0..15) -- single_one_indices
      other_probs = Enum.map(other_indices, &Enum.at(probs, &1))
      assert Enum.sum(other_probs) == 0.0
    end

    test "is normalized" do
      state = StateInit.w_state(5)
      probs = Qx.Math.probabilities(state)
      total = Nx.sum(probs) |> Nx.to_number()

      assert approx_equal?(total, 1.0, 1.0e-6)
    end
  end

  describe "integration with Qx modules" do
    test "states work with Register" do
      state = StateInit.superposition_state(2)
      reg = %Qx.Register{num_qubits: 2, state: state}

      assert Qx.Validation.valid_register?(reg)
    end

    test "basis states can be used directly" do
      state = StateInit.basis_state(3, 4)
      reg = %Qx.Register{num_qubits: 2, state: state}

      # Apply gate
      reg = Qx.Register.h(reg, 0)

      assert Qx.Validation.valid_register?(reg)
    end

    test "Bell state creation matches H + CNOT" do
      # Method 1: Use StateInit.bell_state()
      bell_direct = StateInit.bell_state()
      probs_direct = Qx.Math.probabilities(bell_direct) |> Nx.to_flat_list()

      # Method 2: Create with gates
      bell_gates =
        Qx.Register.new(2)
        |> Qx.Register.h(0)
        |> Qx.Register.cx(0, 1)

      probs_gates = Qx.Register.get_probabilities(bell_gates) |> Nx.to_flat_list()

      # Should be equivalent
      Enum.zip(probs_direct, probs_gates)
      |> Enum.each(fn {p1, p2} ->
        assert approx_equal?(p1, p2)
      end)
    end

    test "GHZ state creation matches H + multiple CNOTs" do
      # Method 1: Use StateInit.ghz_state()
      ghz_direct = StateInit.ghz_state(3)
      probs_direct = Qx.Math.probabilities(ghz_direct) |> Nx.to_flat_list()

      # Method 2: Create with gates
      ghz_gates =
        Qx.Register.new(3)
        |> Qx.Register.h(0)
        |> Qx.Register.cx(0, 1)
        |> Qx.Register.cx(0, 2)

      probs_gates = Qx.Register.get_probabilities(ghz_gates) |> Nx.to_flat_list()

      # Should be equivalent
      Enum.zip(probs_direct, probs_gates)
      |> Enum.each(fn {p1, p2} ->
        assert approx_equal?(p1, p2)
      end)
    end
  end
end
