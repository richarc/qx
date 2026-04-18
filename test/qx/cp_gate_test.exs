defmodule Qx.CpGateTest do
  use ExUnit.Case

  alias Qx.Export.OpenQASM

  describe "cp gate instruction" do
    test "adds {:cp, [control, target], [theta]} to circuit instructions" do
      qc = Qx.create_circuit(2) |> Qx.cp(0, 1, :math.pi())

      assert [{:cp, [0, 1], [theta]}] = Qx.QuantumCircuit.get_instructions(qc)
      assert_in_delta theta, :math.pi(), 1.0e-10
    end

    test "preserves control and target qubit indices" do
      qc = Qx.create_circuit(3) |> Qx.cp(2, 0, 0.5)

      assert [{:cp, [2, 0], [0.5]}] = Qx.QuantumCircuit.get_instructions(qc)
    end
  end

  describe "cp gate statevector behaviour" do
    test "cp with theta=π on |11⟩ produces same statevector as cz" do
      cp_state =
        Qx.create_circuit(2)
        |> Qx.x(0)
        |> Qx.x(1)
        |> Qx.cp(0, 1, :math.pi())
        |> Qx.get_state()

      cz_state =
        Qx.create_circuit(2)
        |> Qx.x(0)
        |> Qx.x(1)
        |> Qx.cz(0, 1)
        |> Qx.get_state()

      for i <- 0..3 do
        cp_amp = Nx.to_number(cp_state[i])
        cz_amp = Nx.to_number(cz_state[i])
        assert abs(Complex.real(cp_amp) - Complex.real(cz_amp)) < 1.0e-5
        assert abs(Complex.imag(cp_amp) - Complex.imag(cz_amp)) < 1.0e-5
      end
    end

    test "cp on |01⟩ produces no phase change (control qubit is |0⟩)" do
      # qubit 0 = |0⟩ (control), qubit 1 = |1⟩ (target) — no phase applied
      before_state =
        Qx.create_circuit(2)
        |> Qx.x(1)
        |> Qx.get_state()

      after_state =
        Qx.create_circuit(2)
        |> Qx.x(1)
        |> Qx.cp(0, 1, :math.pi())
        |> Qx.get_state()

      for i <- 0..3 do
        before_amp = Nx.to_number(before_state[i])
        after_amp = Nx.to_number(after_state[i])
        assert abs(Complex.real(before_amp) - Complex.real(after_amp)) < 1.0e-5
        assert abs(Complex.imag(before_amp) - Complex.imag(after_amp)) < 1.0e-5
      end
    end

    test "cp on |10⟩ produces no phase change (target qubit is |0⟩)" do
      # qubit 0 = |1⟩ (control), qubit 1 = |0⟩ (target) — no phase applied
      before_state =
        Qx.create_circuit(2)
        |> Qx.x(0)
        |> Qx.get_state()

      after_state =
        Qx.create_circuit(2)
        |> Qx.x(0)
        |> Qx.cp(0, 1, :math.pi())
        |> Qx.get_state()

      for i <- 0..3 do
        before_amp = Nx.to_number(before_state[i])
        after_amp = Nx.to_number(after_state[i])
        assert abs(Complex.real(before_amp) - Complex.real(after_amp)) < 1.0e-5
        assert abs(Complex.imag(before_amp) - Complex.imag(after_amp)) < 1.0e-5
      end
    end

    test "cp with theta=0 acts as identity" do
      before_state =
        Qx.create_circuit(2)
        |> Qx.h(0)
        |> Qx.h(1)
        |> Qx.get_state()

      after_state =
        Qx.create_circuit(2)
        |> Qx.h(0)
        |> Qx.h(1)
        |> Qx.cp(0, 1, 0.0)
        |> Qx.get_state()

      for i <- 0..3 do
        before_amp = Nx.to_number(before_state[i])
        after_amp = Nx.to_number(after_state[i])
        assert abs(Complex.real(before_amp) - Complex.real(after_amp)) < 1.0e-5
        assert abs(Complex.imag(before_amp) - Complex.imag(after_amp)) < 1.0e-5
      end
    end
  end

  describe "cp gate error handling" do
    test "raises ArgumentError when theta is not a number" do
      qc = Qx.create_circuit(2)
      assert_raise ArgumentError, fn -> Qx.cp(qc, 0, 1, "not_a_number") end
    end

    test "raises FunctionClauseError when qubit index is out of range" do
      qc = Qx.create_circuit(2)
      assert_raise FunctionClauseError, fn -> Qx.cp(qc, 0, 5, :math.pi()) end
    end
  end

  describe "cp gate OpenQASM export" do
    test "exports cp gate with theta parameter" do
      circuit = Qx.create_circuit(2) |> Qx.cp(0, 1, :math.pi())
      qasm = OpenQASM.to_qasm(circuit)

      assert qasm =~ "cp("
      assert qasm =~ "q[0], q[1];"
    end
  end
end
