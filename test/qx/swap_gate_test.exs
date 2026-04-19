defmodule Qx.SwapGateTest do
  use ExUnit.Case

  alias Qx.Export.OpenQASM

  describe "swap gate instruction" do
    test "adds {:swap, [qubit_a, qubit_b], []} to circuit instructions" do
      qc = Qx.create_circuit(2) |> Qx.swap(0, 1)

      assert [{:swap, [0, 1], []}] = Qx.QuantumCircuit.get_instructions(qc)
    end

    test "preserves qubit indices" do
      qc = Qx.create_circuit(3) |> Qx.swap(2, 0)

      assert [{:swap, [2, 0], []}] = Qx.QuantumCircuit.get_instructions(qc)
    end
  end

  describe "swap gate statevector behaviour" do
    test "swap on |01⟩ produces |10⟩" do
      state =
        Qx.create_circuit(2)
        |> Qx.x(1)
        |> Qx.swap(0, 1)
        |> Qx.get_state()

      # |10⟩ = index 2 in 2-qubit system (MSB: qubit 0 is bit 1)
      assert_in_delta Complex.real(Nx.to_number(state[2])), 1.0, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[1])), 0.0, 1.0e-5
    end

    test "swap on |10⟩ produces |01⟩" do
      state =
        Qx.create_circuit(2)
        |> Qx.x(0)
        |> Qx.swap(0, 1)
        |> Qx.get_state()

      # |01⟩ = index 1 in 2-qubit system
      assert_in_delta Complex.real(Nx.to_number(state[1])), 1.0, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[2])), 0.0, 1.0e-5
    end

    test "swap on |00⟩ is identity" do
      state_before = Qx.create_circuit(2) |> Qx.get_state()
      state_after = Qx.create_circuit(2) |> Qx.swap(0, 1) |> Qx.get_state()

      for i <- 0..3 do
        assert_in_delta Complex.real(Nx.to_number(state_before[i])),
                        Complex.real(Nx.to_number(state_after[i])),
                        1.0e-5
      end
    end

    test "swap on |11⟩ is identity" do
      state_before =
        Qx.create_circuit(2)
        |> Qx.x(0)
        |> Qx.x(1)
        |> Qx.get_state()

      state_after =
        Qx.create_circuit(2)
        |> Qx.x(0)
        |> Qx.x(1)
        |> Qx.swap(0, 1)
        |> Qx.get_state()

      for i <- 0..3 do
        assert_in_delta Complex.real(Nx.to_number(state_before[i])),
                        Complex.real(Nx.to_number(state_after[i])),
                        1.0e-5
      end
    end

    test "swap is self-inverse: applying twice returns original state" do
      state_before =
        Qx.create_circuit(2)
        |> Qx.h(0)
        |> Qx.get_state()

      state_after =
        Qx.create_circuit(2)
        |> Qx.h(0)
        |> Qx.swap(0, 1)
        |> Qx.swap(0, 1)
        |> Qx.get_state()

      for i <- 0..3 do
        assert_in_delta Complex.real(Nx.to_number(state_before[i])),
                        Complex.real(Nx.to_number(state_after[i])),
                        1.0e-5

        assert_in_delta Complex.imag(Nx.to_number(state_before[i])),
                        Complex.imag(Nx.to_number(state_after[i])),
                        1.0e-5
      end
    end
  end

  describe "swap gate error handling" do
    test "raises FunctionClauseError for equal qubit indices" do
      qc = Qx.create_circuit(2)
      assert_raise FunctionClauseError, fn -> Qx.swap(qc, 0, 0) end
    end

    test "raises FunctionClauseError for out-of-range qubit index" do
      qc = Qx.create_circuit(2)
      assert_raise FunctionClauseError, fn -> Qx.swap(qc, 0, 5) end
    end
  end

  describe "swap gate OpenQASM export" do
    test "exports swap gate as swap q[a], q[b];" do
      circuit = Qx.create_circuit(2) |> Qx.swap(0, 1)
      qasm = OpenQASM.to_qasm(circuit)

      assert qasm =~ "swap q[0], q[1];"
    end
  end
end
