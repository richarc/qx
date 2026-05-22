defmodule Qx.Export.OpenQASMControlledRotationsTest do
  use ExUnit.Case, async: true

  alias Qx.Export.OpenQASM
  alias Qx.{Operations, QuantumCircuit}

  describe "to_qasm/1 — controlled rotations" do
    test "cy lowers to `cy q[c], q[t];`" do
      qasm =
        QuantumCircuit.new(2, 0)
        |> Operations.cy(0, 1)
        |> OpenQASM.to_qasm()

      assert qasm =~ "cy q[0], q[1];"
    end

    test "crx lowers to `crx(θ) q[c], q[t];`" do
      qasm =
        QuantumCircuit.new(2, 0)
        |> Operations.crx(0, 1, :math.pi() / 2)
        |> OpenQASM.to_qasm()

      assert qasm =~ "crx("
      assert qasm =~ ") q[0], q[1];"
    end

    test "cry lowers to `cry(θ) q[c], q[t];`" do
      qasm =
        QuantumCircuit.new(2, 0)
        |> Operations.cry(0, 1, 0.5)
        |> OpenQASM.to_qasm()

      assert qasm =~ "cry(0.5) q[0], q[1];"
    end

    test "crz lowers to `crz(θ) q[c], q[t];`" do
      qasm =
        QuantumCircuit.new(2, 0)
        |> Operations.crz(0, 1, 0.25)
        |> OpenQASM.to_qasm()

      assert qasm =~ "crz(0.25) q[0], q[1];"
    end
  end

  describe "from_qasm/1 — controlled rotations" do
    test "parses cy" do
      qasm = """
      OPENQASM 3.0;
      include "stdgates.inc";
      qubit[2] q;
      cy q[0], q[1];
      """

      assert {:ok, circuit} = OpenQASM.from_qasm(qasm)
      assert [{:cy, [0, 1], []}] = QuantumCircuit.get_instructions(circuit)
    end

    test "parses crx with parameter" do
      qasm = """
      OPENQASM 3.0;
      include "stdgates.inc";
      qubit[2] q;
      crx(0.5) q[0], q[1];
      """

      assert {:ok, circuit} = OpenQASM.from_qasm(qasm)
      assert [{:crx, [0, 1], [0.5]}] = QuantumCircuit.get_instructions(circuit)
    end

    test "parses cry and crz with parameters" do
      qasm = """
      OPENQASM 3.0;
      include "stdgates.inc";
      qubit[2] q;
      cry(1.0) q[0], q[1];
      crz(2.0) q[1], q[0];
      """

      assert {:ok, circuit} = OpenQASM.from_qasm(qasm)

      assert [{:cry, [0, 1], [1.0]}, {:crz, [1, 0], [2.0]}] =
               QuantumCircuit.get_instructions(circuit)
    end
  end

  describe "round-trip: to_qasm |> from_qasm" do
    test "cy round-trips" do
      original =
        QuantumCircuit.new(2, 0)
        |> Operations.cy(0, 1)

      qasm = OpenQASM.to_qasm(original)
      assert {:ok, parsed} = OpenQASM.from_qasm(qasm)

      assert QuantumCircuit.get_instructions(parsed) ==
               QuantumCircuit.get_instructions(original)
    end

    test "crx/cry/crz round-trip" do
      original =
        QuantumCircuit.new(2, 0)
        |> Operations.crx(0, 1, 0.5)
        |> Operations.cry(0, 1, 1.0)
        |> Operations.crz(1, 0, 1.5)

      qasm = OpenQASM.to_qasm(original)
      assert {:ok, parsed} = OpenQASM.from_qasm(qasm)

      assert QuantumCircuit.get_instructions(parsed) ==
               QuantumCircuit.get_instructions(original)
    end
  end
end
