defmodule Qx.CswapGateTest do
  use ExUnit.Case

  alias Qx.Export.OpenQASM

  describe "cswap gate instruction" do
    test "adds {:cswap, [control, target_a, target_b], []} to circuit instructions" do
      qc = Qx.create_circuit(3) |> Qx.cswap(0, 1, 2)

      assert [{:cswap, [0, 1, 2], []}] = Qx.QuantumCircuit.get_instructions(qc)
    end

    test "preserves qubit indices" do
      qc = Qx.create_circuit(3) |> Qx.cswap(2, 0, 1)

      assert [{:cswap, [2, 0, 1], []}] = Qx.QuantumCircuit.get_instructions(qc)
    end
  end

  describe "cswap gate statevector behaviour" do
    # Qubit 0 is MSB. State index encodes |q0,q1,q2⟩ as (q0<<2)|(q1<<1)|q2.
    # |0,0,1⟩ = index 1, |0,1,0⟩ = index 2, |1,0,1⟩ = index 5, |1,1,0⟩ = index 6

    test "control=|0⟩: |0,0,1⟩ unchanged (no swap)" do
      # Prepare |0,0,1⟩ = index 1
      state =
        Qx.create_circuit(3)
        |> Qx.x(2)
        |> Qx.cswap(0, 1, 2)
        |> Qx.get_state()

      assert_in_delta Complex.real(Nx.to_number(state[1])), 1.0, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[2])), 0.0, 1.0e-5
    end

    test "control=|0⟩: |0,1,0⟩ unchanged (no swap)" do
      # Prepare |0,1,0⟩ = index 2
      state =
        Qx.create_circuit(3)
        |> Qx.x(1)
        |> Qx.cswap(0, 1, 2)
        |> Qx.get_state()

      assert_in_delta Complex.real(Nx.to_number(state[2])), 1.0, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[1])), 0.0, 1.0e-5
    end

    test "control=|1⟩: |1,0,1⟩ → |1,1,0⟩ (targets swapped)" do
      # Prepare |1,0,1⟩ = index 5; after CSWAP → |1,1,0⟩ = index 6
      state =
        Qx.create_circuit(3)
        |> Qx.x(0)
        |> Qx.x(2)
        |> Qx.cswap(0, 1, 2)
        |> Qx.get_state()

      assert_in_delta Complex.real(Nx.to_number(state[6])), 1.0, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[5])), 0.0, 1.0e-5
    end

    test "control=|1⟩: |1,1,0⟩ → |1,0,1⟩ (targets swapped)" do
      # Prepare |1,1,0⟩ = index 6; after CSWAP → |1,0,1⟩ = index 5
      state =
        Qx.create_circuit(3)
        |> Qx.x(0)
        |> Qx.x(1)
        |> Qx.cswap(0, 1, 2)
        |> Qx.get_state()

      assert_in_delta Complex.real(Nx.to_number(state[5])), 1.0, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[6])), 0.0, 1.0e-5
    end

    test "control=|1⟩: |1,0,0⟩ unchanged (targets already equal)" do
      # Prepare |1,0,0⟩ = index 4; both targets are |0⟩, so no effective change
      state =
        Qx.create_circuit(3)
        |> Qx.x(0)
        |> Qx.cswap(0, 1, 2)
        |> Qx.get_state()

      assert_in_delta Complex.real(Nx.to_number(state[4])), 1.0, 1.0e-5
    end

    test "cswap is self-inverse: applying twice returns original state" do
      state =
        Qx.create_circuit(3)
        |> Qx.x(0)
        |> Qx.x(2)
        |> Qx.cswap(0, 1, 2)
        |> Qx.cswap(0, 1, 2)
        |> Qx.get_state()

      # Should return to |1,0,1⟩ = index 5
      assert_in_delta Complex.real(Nx.to_number(state[5])), 1.0, 1.0e-5
    end
  end

  describe "cswap gate error handling" do
    test "raises ArgumentError for equal control and target_a indices" do
      qc = Qx.create_circuit(3)
      assert_raise ArgumentError, fn -> Qx.cswap(qc, 0, 0, 2) end
    end

    test "raises ArgumentError for equal target_a and target_b indices" do
      qc = Qx.create_circuit(3)
      assert_raise ArgumentError, fn -> Qx.cswap(qc, 0, 1, 1) end
    end

    test "raises ArgumentError for out-of-range qubit index" do
      qc = Qx.create_circuit(3)
      assert_raise ArgumentError, fn -> Qx.cswap(qc, 0, 1, 5) end
    end
  end

  describe "cswap gate OpenQASM export" do
    test "exports cswap gate as cswap q[c], q[a], q[b];" do
      circuit = Qx.create_circuit(3) |> Qx.cswap(0, 1, 2)
      qasm = OpenQASM.to_qasm(circuit)

      assert qasm =~ "cswap q[0], q[1], q[2];"
    end
  end
end
