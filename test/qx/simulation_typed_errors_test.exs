defmodule Qx.SimulationTypedErrorsTest do
  use ExUnit.Case, async: true

  alias Qx.{QuantumCircuit, Simulation}

  describe "Simulation.run/2 typed errors (Iron Law #7)" do
    test "unsupported 0-qubit gate raises Qx.GateError, not RuntimeError" do
      qc = QuantumCircuit.new(2, 0)
      qc = %{qc | instructions: [{:not_a_gate, [], []}]}

      assert_raise Qx.GateError, ~r/Unsupported gate/, fn ->
        Simulation.run(qc, shots: 1)
      end
    end

    test "unsupported single-qubit gate raises Qx.GateError, not RuntimeError" do
      qc = QuantumCircuit.new(2, 0)
      qc = %{qc | instructions: [{:not_a_gate, [0], []}]}

      assert_raise Qx.GateError, ~r/Unsupported gate/, fn ->
        Simulation.run(qc, shots: 1)
      end
    end

    test "unsupported two-qubit gate raises Qx.GateError, not RuntimeError" do
      qc = QuantumCircuit.new(2, 0)
      qc = %{qc | instructions: [{:not_a_gate, [0, 1], []}]}

      assert_raise Qx.GateError, ~r/Unsupported gate/, fn ->
        Simulation.run(qc, shots: 1)
      end
    end

    test "unsupported three-qubit gate raises Qx.GateError, not RuntimeError" do
      qc = QuantumCircuit.new(3, 0)
      qc = %{qc | instructions: [{:not_a_gate, [0, 1, 2], []}]}

      assert_raise Qx.GateError, ~r/Unsupported gate/, fn ->
        Simulation.run(qc, shots: 1)
      end
    end

    test "unsupported four-or-more-qubit gate raises Qx.GateError, not RuntimeError" do
      qc = QuantumCircuit.new(4, 0)
      qc = %{qc | instructions: [{:not_a_gate, [0, 1, 2, 3], []}]}

      assert_raise Qx.GateError, ~r/Unsupported gate/, fn ->
        Simulation.run(qc, shots: 1)
      end
    end
  end
end
