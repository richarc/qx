defmodule Qx.IswapGateTest do
  use ExUnit.Case

  alias Qx.Export.OpenQASM

  describe "iswap gate instruction" do
    test "adds {:iswap, [qubit_a, qubit_b], []} to circuit instructions" do
      qc = Qx.create_circuit(2) |> Qx.iswap(0, 1)

      assert [{:iswap, [0, 1], []}] = Qx.QuantumCircuit.get_instructions(qc)
    end

    test "preserves qubit indices" do
      qc = Qx.create_circuit(3) |> Qx.iswap(2, 0)

      assert [{:iswap, [2, 0], []}] = Qx.QuantumCircuit.get_instructions(qc)
    end
  end

  describe "iswap gate statevector behaviour" do
    test "iswap on |00⟩ produces |00⟩ (no change)" do
      state = Qx.create_circuit(2) |> Qx.iswap(0, 1) |> Qx.get_state()

      assert_in_delta Complex.real(Nx.to_number(state[0])), 1.0, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[1])), 0.0, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[2])), 0.0, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[3])), 0.0, 1.0e-5
    end

    test "iswap on |11⟩ produces |11⟩ (no change)" do
      state =
        Qx.create_circuit(2)
        |> Qx.x(0)
        |> Qx.x(1)
        |> Qx.iswap(0, 1)
        |> Qx.get_state()

      assert_in_delta Complex.real(Nx.to_number(state[3])), 1.0, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[0])), 0.0, 1.0e-5
    end

    test "iswap on |01⟩ produces i|10⟩ (imaginary phase on swapped state)" do
      # qubit 0 = |0⟩, qubit 1 = |1⟩ → state index 1
      # After iswap: qubit 0 = |1⟩, qubit 1 = |0⟩ with factor i → state index 2
      state =
        Qx.create_circuit(2)
        |> Qx.x(1)
        |> Qx.iswap(0, 1)
        |> Qx.get_state()

      amp = Nx.to_number(state[2])
      assert_in_delta Complex.real(amp), 0.0, 1.0e-5
      assert_in_delta Complex.imag(amp), 1.0, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[1])), 0.0, 1.0e-5
    end

    test "iswap on |10⟩ produces i|01⟩" do
      # qubit 0 = |1⟩, qubit 1 = |0⟩ → state index 2
      # After iswap: qubit 0 = |0⟩, qubit 1 = |1⟩ with factor i → state index 1
      state =
        Qx.create_circuit(2)
        |> Qx.x(0)
        |> Qx.iswap(0, 1)
        |> Qx.get_state()

      amp = Nx.to_number(state[1])
      assert_in_delta Complex.real(amp), 0.0, 1.0e-5
      assert_in_delta Complex.imag(amp), 1.0, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[2])), 0.0, 1.0e-5
    end

    test "iswap applied twice: |01⟩ → -|01⟩ (iSWAP² ≠ identity)" do
      state =
        Qx.create_circuit(2)
        |> Qx.x(1)
        |> Qx.iswap(0, 1)
        |> Qx.iswap(0, 1)
        |> Qx.get_state()

      # After two iSWAPs: (i)(i) = -1, so |01⟩ → -|01⟩
      amp = Nx.to_number(state[1])
      assert_in_delta Complex.real(amp), -1.0, 1.0e-5
      assert_in_delta Complex.imag(amp), 0.0, 1.0e-5
    end
  end

  describe "iswap gate error handling" do
    test "raises FunctionClauseError for equal qubit indices" do
      qc = Qx.create_circuit(2)
      assert_raise FunctionClauseError, fn -> Qx.iswap(qc, 0, 0) end
    end

    test "raises FunctionClauseError for out-of-range qubit index" do
      qc = Qx.create_circuit(2)
      assert_raise FunctionClauseError, fn -> Qx.iswap(qc, 0, 5) end
    end
  end

  describe "iswap gate OpenQASM export" do
    test "exports iswap gate as iswap q[a], q[b];" do
      circuit = Qx.create_circuit(2) |> Qx.iswap(0, 1)
      qasm = OpenQASM.to_qasm(circuit)

      assert qasm =~ "iswap q[0], q[1];"
    end
  end
end
