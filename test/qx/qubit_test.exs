defmodule Qx.QubitTest do
  use ExUnit.Case
  doctest Qx.Qubit

  alias Qx.Qubit

  # Helper function to check if two probabilities are approximately equal
  defp approx_equal?(a, b, tolerance \\ 0.01) do
    abs(a - b) < tolerance
  end

  describe "qubit creation" do
    test "new/0 creates |0⟩ state" do
      q = Qubit.new()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 1.0)
      assert approx_equal?(Enum.at(probs, 1), 0.0)
    end

    test "one/0 creates |1⟩ state" do
      q = Qubit.one()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.0)
      assert approx_equal?(Enum.at(probs, 1), 1.0)
    end

    test "plus/0 creates |+⟩ state" do
      q = Qubit.plus()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.5)
      assert approx_equal?(Enum.at(probs, 1), 0.5)
    end

    test "minus/0 creates |-⟩ state" do
      q = Qubit.minus()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      # |-⟩ has same probabilities as |+⟩ but different phase
      assert approx_equal?(Enum.at(probs, 0), 0.5)
      assert approx_equal?(Enum.at(probs, 1), 0.5)
    end
  end

  describe "Hadamard gate (h/1)" do
    test "applies H to |0⟩ creates equal superposition" do
      q = Qubit.new() |> Qubit.h()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.5)
      assert approx_equal?(Enum.at(probs, 1), 0.5)
    end

    test "applies H to |1⟩ creates equal superposition" do
      q = Qubit.one() |> Qubit.h()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.5)
      assert approx_equal?(Enum.at(probs, 1), 0.5)
    end

    test "H twice returns to original state (|0⟩)" do
      q = Qubit.new() |> Qubit.h() |> Qubit.h()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 1.0)
      assert approx_equal?(Enum.at(probs, 1), 0.0)
    end

    test "H is its own inverse" do
      q = Qubit.one() |> Qubit.h() |> Qubit.h()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.0)
      assert approx_equal?(Enum.at(probs, 1), 1.0)
    end
  end

  describe "Pauli-X gate (x/1)" do
    test "applies X to |0⟩ creates |1⟩" do
      q = Qubit.new() |> Qubit.x()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.0)
      assert approx_equal?(Enum.at(probs, 1), 1.0)
    end

    test "applies X to |1⟩ creates |0⟩" do
      q = Qubit.one() |> Qubit.x()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 1.0)
      assert approx_equal?(Enum.at(probs, 1), 0.0)
    end

    test "X twice returns to original state" do
      q = Qubit.new() |> Qubit.x() |> Qubit.x()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 1.0)
      assert approx_equal?(Enum.at(probs, 1), 0.0)
    end
  end

  describe "Pauli-Y gate (y/1)" do
    test "applies Y to |0⟩" do
      q = Qubit.new() |> Qubit.y()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      # Y|0⟩ = i|1⟩, so probability should be in |1⟩
      assert approx_equal?(Enum.at(probs, 0), 0.0)
      assert approx_equal?(Enum.at(probs, 1), 1.0)
    end

    test "Y twice returns to original state" do
      q = Qubit.new() |> Qubit.y() |> Qubit.y()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 1.0)
      assert approx_equal?(Enum.at(probs, 1), 0.0)
    end

    test "Y is its own inverse" do
      q = Qubit.plus() |> Qubit.y() |> Qubit.y()
      assert Qubit.valid?(q)
    end
  end

  describe "Pauli-Z gate (z/1)" do
    test "Z has no effect on |0⟩" do
      q = Qubit.new() |> Qubit.z()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 1.0)
      assert approx_equal?(Enum.at(probs, 1), 0.0)
    end

    test "Z changes phase of |1⟩ but not probability" do
      q = Qubit.one() |> Qubit.z()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      # Probabilities unchanged
      assert approx_equal?(Enum.at(probs, 0), 0.0)
      assert approx_equal?(Enum.at(probs, 1), 1.0)
    end

    test "Z twice returns to original state" do
      q = Qubit.plus() |> Qubit.z() |> Qubit.z()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.5)
      assert approx_equal?(Enum.at(probs, 1), 0.5)
    end

    test "H-Z-H equals X gate" do
      # This is a known quantum gate identity
      q1 = Qubit.new() |> Qubit.h() |> Qubit.z() |> Qubit.h()
      q2 = Qubit.new() |> Qubit.x()

      probs1 = Qubit.measure_probabilities(q1) |> Nx.to_flat_list()
      probs2 = Qubit.measure_probabilities(q2) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs1, 0), Enum.at(probs2, 0))
      assert approx_equal?(Enum.at(probs1, 1), Enum.at(probs2, 1))
    end
  end

  describe "S gate (s/1)" do
    test "S gate preserves qubit validity" do
      q = Qubit.new() |> Qubit.s()
      assert Qubit.valid?(q)
    end

    test "S has no effect on |0⟩ probabilities" do
      q = Qubit.new() |> Qubit.s()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 1.0)
      assert approx_equal?(Enum.at(probs, 1), 0.0)
    end

    test "S changes phase of |1⟩ but not probability" do
      q = Qubit.one() |> Qubit.s()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.0)
      assert approx_equal?(Enum.at(probs, 1), 1.0)
    end

    test "S twice equals Z gate" do
      q1 = Qubit.plus() |> Qubit.s() |> Qubit.s()
      q2 = Qubit.plus() |> Qubit.z()

      probs1 = Qubit.measure_probabilities(q1) |> Nx.to_flat_list()
      probs2 = Qubit.measure_probabilities(q2) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs1, 0), Enum.at(probs2, 0))
      assert approx_equal?(Enum.at(probs1, 1), Enum.at(probs2, 1))
    end
  end

  describe "T gate (t/1)" do
    test "T gate preserves qubit validity" do
      q = Qubit.new() |> Qubit.t()
      assert Qubit.valid?(q)
    end

    test "T has no effect on |0⟩ probabilities" do
      q = Qubit.new() |> Qubit.t()
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 1.0)
      assert approx_equal?(Enum.at(probs, 1), 0.0)
    end

    test "T twice equals S gate" do
      q1 = Qubit.plus() |> Qubit.t() |> Qubit.t()
      q2 = Qubit.plus() |> Qubit.s()

      probs1 = Qubit.measure_probabilities(q1) |> Nx.to_flat_list()
      probs2 = Qubit.measure_probabilities(q2) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs1, 0), Enum.at(probs2, 0))
      assert approx_equal?(Enum.at(probs1, 1), Enum.at(probs2, 1))
    end
  end

  describe "rotation gates" do
    test "RX with π flips the qubit" do
      q = Qubit.new() |> Qubit.rx(:math.pi())
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.0)
      assert approx_equal?(Enum.at(probs, 1), 1.0)
    end

    test "RX with 2π returns to original" do
      q = Qubit.new() |> Qubit.rx(2 * :math.pi())
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 1.0)
      assert approx_equal?(Enum.at(probs, 1), 0.0)
    end

    test "RY with π flips the qubit" do
      q = Qubit.new() |> Qubit.ry(:math.pi())
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.0)
      assert approx_equal?(Enum.at(probs, 1), 1.0)
    end

    test "RY with π/2 creates superposition" do
      q = Qubit.new() |> Qubit.ry(:math.pi() / 2)
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.5)
      assert approx_equal?(Enum.at(probs, 1), 0.5)
    end

    test "RZ preserves |0⟩ state" do
      q = Qubit.new() |> Qubit.rz(:math.pi() / 4)
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 1.0)
      assert approx_equal?(Enum.at(probs, 1), 0.0)
    end

    test "RZ changes phase but not probabilities" do
      q = Qubit.plus() |> Qubit.rz(:math.pi() / 2)
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      # Probabilities unchanged
      assert approx_equal?(Enum.at(probs, 0), 0.5)
      assert approx_equal?(Enum.at(probs, 1), 0.5)
    end
  end

  describe "phase gate (phase/1)" do
    test "phase gate preserves qubit validity" do
      q = Qubit.new() |> Qubit.phase(:math.pi() / 4)
      assert Qubit.valid?(q)
    end

    test "phase has no effect on |0⟩" do
      q = Qubit.new() |> Qubit.phase(:math.pi() / 3)
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 1.0)
      assert approx_equal?(Enum.at(probs, 1), 0.0)
    end

    test "phase changes phase of |1⟩ but not probability" do
      q = Qubit.one() |> Qubit.phase(:math.pi() / 2)
      probs = Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs, 0), 0.0)
      assert approx_equal?(Enum.at(probs, 1), 1.0)
    end
  end

  describe "state_vector/1" do
    test "returns the qubit tensor" do
      q = Qubit.new()
      state = Qubit.state_vector(q)

      assert Nx.shape(state) == {2}
      assert Nx.type(state) == {:c, 64}
    end

    test "state_vector shows complex amplitudes" do
      q = Qubit.new() |> Qubit.h()
      state = Qubit.state_vector(q)

      # Extract amplitudes
      alpha = Nx.to_number(state[0])
      beta = Nx.to_number(state[1])

      # Both should be approximately 1/√2
      expected = 1.0 / :math.sqrt(2)
      assert approx_equal?(Complex.abs(alpha), expected)
      assert approx_equal?(Complex.abs(beta), expected)
    end

    test "state_vector can be piped through multiple operations" do
      state =
        Qubit.new()
        |> Qubit.h()
        |> Qubit.z()
        |> Qubit.state_vector()

      assert Nx.shape(state) == {2}
      assert Qubit.valid?(state)
    end
  end

  describe "gate chaining" do
    test "can chain multiple gates together" do
      q =
        Qubit.new()
        |> Qubit.h()
        |> Qubit.x()
        |> Qubit.z()
        |> Qubit.h()

      assert Qubit.valid?(q)
    end

    test "complex gate sequence produces correct result" do
      # X-H-X-H should be equivalent to Z
      q1 = Qubit.plus() |> Qubit.x() |> Qubit.h() |> Qubit.x() |> Qubit.h()
      q2 = Qubit.plus() |> Qubit.z()

      probs1 = Qubit.measure_probabilities(q1) |> Nx.to_flat_list()
      probs2 = Qubit.measure_probabilities(q2) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs1, 0), Enum.at(probs2, 0))
      assert approx_equal?(Enum.at(probs1, 1), Enum.at(probs2, 1))
    end

    test "chain with rotation gates" do
      q =
        Qubit.new()
        |> Qubit.rx(:math.pi() / 4)
        |> Qubit.ry(:math.pi() / 3)
        |> Qubit.rz(:math.pi() / 6)

      assert Qubit.valid?(q)
    end
  end

  describe "comparison with circuit mode" do
    test "calculation mode H matches circuit mode H" do
      # Calculation mode
      calc_q = Qubit.new() |> Qubit.h()
      calc_probs = Qubit.measure_probabilities(calc_q) |> Nx.to_flat_list()

      # Circuit mode
      circuit_result = Qx.create_circuit(1) |> Qx.h(0) |> Qx.run()
      circuit_probs = Nx.to_flat_list(circuit_result.probabilities)

      assert approx_equal?(Enum.at(calc_probs, 0), Enum.at(circuit_probs, 0))
      assert approx_equal?(Enum.at(calc_probs, 1), Enum.at(circuit_probs, 1))
    end

    test "calculation mode X matches circuit mode X" do
      calc_q = Qubit.new() |> Qubit.x()
      calc_probs = Qubit.measure_probabilities(calc_q) |> Nx.to_flat_list()

      circuit_result = Qx.create_circuit(1) |> Qx.x(0) |> Qx.run()
      circuit_probs = Nx.to_flat_list(circuit_result.probabilities)

      assert approx_equal?(Enum.at(calc_probs, 0), Enum.at(circuit_probs, 0))
      assert approx_equal?(Enum.at(calc_probs, 1), Enum.at(circuit_probs, 1))
    end

    test "calculation mode gate sequence matches circuit mode" do
      # H-X-H sequence
      calc_q = Qubit.new() |> Qubit.h() |> Qubit.x() |> Qubit.h()
      calc_probs = Qubit.measure_probabilities(calc_q) |> Nx.to_flat_list()

      circuit_result = Qx.create_circuit(1) |> Qx.h(0) |> Qx.x(0) |> Qx.h(0) |> Qx.run()
      circuit_probs = Nx.to_flat_list(circuit_result.probabilities)

      assert approx_equal?(Enum.at(calc_probs, 0), Enum.at(circuit_probs, 0))
      assert approx_equal?(Enum.at(calc_probs, 1), Enum.at(circuit_probs, 1))
    end

    test "rotation gates match between modes" do
      theta = :math.pi() / 3

      calc_q = Qubit.new() |> Qubit.ry(theta)
      calc_probs = Qubit.measure_probabilities(calc_q) |> Nx.to_flat_list()

      circuit_result = Qx.create_circuit(1) |> Qx.ry(0, theta) |> Qx.run()
      circuit_probs = Nx.to_flat_list(circuit_result.probabilities)

      assert approx_equal?(Enum.at(calc_probs, 0), Enum.at(circuit_probs, 0))
      assert approx_equal?(Enum.at(calc_probs, 1), Enum.at(circuit_probs, 1))
    end
  end

  describe "edge cases" do
    test "all gates preserve normalization" do
      gates = [
        &Qubit.h/1,
        &Qubit.x/1,
        &Qubit.y/1,
        &Qubit.z/1,
        &Qubit.s/1,
        &Qubit.t/1
      ]

      Enum.each(gates, fn gate ->
        q = Qubit.new() |> gate.()
        assert Qubit.valid?(q)
      end)
    end

    test "rotation gates preserve normalization" do
      angles = [:math.pi() / 6, :math.pi() / 4, :math.pi() / 2, :math.pi()]

      Enum.each(angles, fn theta ->
        assert Qubit.valid?(Qubit.new() |> Qubit.rx(theta))
        assert Qubit.valid?(Qubit.new() |> Qubit.ry(theta))
        assert Qubit.valid?(Qubit.new() |> Qubit.rz(theta))
        assert Qubit.valid?(Qubit.new() |> Qubit.phase(theta))
      end)
    end

    test "zero angle rotation is identity" do
      q1 = Qubit.new() |> Qubit.rx(0)
      q2 = Qubit.new()

      probs1 = Qubit.measure_probabilities(q1) |> Nx.to_flat_list()
      probs2 = Qubit.measure_probabilities(q2) |> Nx.to_flat_list()

      assert approx_equal?(Enum.at(probs1, 0), Enum.at(probs2, 0))
      assert approx_equal?(Enum.at(probs1, 1), Enum.at(probs2, 1))
    end
  end
end
