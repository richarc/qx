defmodule Qx.QuantumCircuitTypedErrorsTest do
  use ExUnit.Case, async: true

  alias Qx.QuantumCircuit

  describe "add_gate/4 typed errors (Iron Law #7)" do
    test "out-of-range qubit raises Qx.QubitIndexError, not FunctionClauseError" do
      qc = QuantumCircuit.new(2, 0)

      assert_raise Qx.QubitIndexError, ~r/Qubit index 5 out of range/, fn ->
        QuantumCircuit.add_gate(qc, :h, 5)
      end
    end

    test "negative qubit raises Qx.QubitIndexError" do
      qc = QuantumCircuit.new(2, 0)

      assert_raise Qx.QubitIndexError, ~r/Qubit index -1 out of range/, fn ->
        QuantumCircuit.add_gate(qc, :h, -1)
      end
    end
  end

  describe "add_two_qubit_gate/5 typed errors (Iron Law #7)" do
    test "out-of-range control raises Qx.QubitIndexError" do
      qc = QuantumCircuit.new(2, 0)

      assert_raise Qx.QubitIndexError, ~r/Qubit index 5 out of range/, fn ->
        QuantumCircuit.add_two_qubit_gate(qc, :cx, 5, 0)
      end
    end

    test "out-of-range target raises Qx.QubitIndexError" do
      qc = QuantumCircuit.new(2, 0)

      assert_raise Qx.QubitIndexError, ~r/Qubit index 5 out of range/, fn ->
        QuantumCircuit.add_two_qubit_gate(qc, :cx, 0, 5)
      end
    end

    test "equal control and target raises Qx.QubitIndexError, not FunctionClauseError" do
      qc = QuantumCircuit.new(2, 0)

      assert_raise Qx.QubitIndexError, ~r/distinct/, fn ->
        QuantumCircuit.add_two_qubit_gate(qc, :cx, 0, 0)
      end
    end
  end

  describe "add_three_qubit_gate/6 typed errors (Iron Law #7)" do
    test "out-of-range index raises Qx.QubitIndexError, not ArgumentError" do
      qc = QuantumCircuit.new(3, 0)

      assert_raise Qx.QubitIndexError, ~r/Qubit index 5 out of range/, fn ->
        QuantumCircuit.add_three_qubit_gate(qc, :ccx, 0, 1, 5)
      end
    end

    test "duplicate indices raise Qx.QubitIndexError, not ArgumentError" do
      qc = QuantumCircuit.new(3, 0)

      assert_raise Qx.QubitIndexError, ~r/distinct/, fn ->
        QuantumCircuit.add_three_qubit_gate(qc, :ccx, 0, 0, 2)
      end
    end

    test "non-integer index raises Qx.QubitIndexError, not ArgumentError" do
      qc = QuantumCircuit.new(3, 0)

      assert_raise Qx.QubitIndexError, ~r/must be integers/, fn ->
        QuantumCircuit.add_three_qubit_gate(qc, :ccx, 0, 1, :bad)
      end
    end
  end

  describe "set_state/2 typed errors (Iron Law #7)" do
    test "wrong-size 1-D state raises Qx.StateShapeError, not ArgumentError" do
      qc = QuantumCircuit.new(2, 0)
      bad = Nx.tensor([Complex.new(1.0, 0.0), Complex.new(0.0, 0.0)], type: :c64)

      assert_raise Qx.StateShapeError, ~r/expected 4, got 2/, fn ->
        QuantumCircuit.set_state(qc, bad)
      end
    end

    test "non-1-D state raises Qx.StateShapeError" do
      qc = QuantumCircuit.new(1, 0)
      bad = Nx.tensor([[Complex.new(1.0, 0.0)], [Complex.new(0.0, 0.0)]], type: :c64)

      assert_raise Qx.StateShapeError, ~r/must be 1-D/, fn ->
        QuantumCircuit.set_state(qc, bad)
      end
    end
  end

  describe "add_measurement/3 typed errors (Iron Law #7)" do
    test "out-of-range qubit raises Qx.QubitIndexError, not FunctionClauseError" do
      qc = QuantumCircuit.new(2, 2)

      assert_raise Qx.QubitIndexError, ~r/Qubit index 5 out of range/, fn ->
        QuantumCircuit.add_measurement(qc, 5, 0)
      end
    end

    test "out-of-range classical bit raises Qx.ClassicalBitError, not FunctionClauseError" do
      qc = QuantumCircuit.new(2, 2)

      assert_raise Qx.ClassicalBitError, ~r/Classical bit index 5 out of range/, fn ->
        QuantumCircuit.add_measurement(qc, 0, 5)
      end
    end
  end

  describe "new/1 and new/2 qubit-count enforcement (Iron Law #7)" do
    test "new/1 with > 20 qubits raises Qx.QubitCountError" do
      assert_raise Qx.QubitCountError, ~r/must be between 1 and 20/, fn ->
        QuantumCircuit.new(25)
      end
    end

    test "new/2 with > 20 qubits raises Qx.QubitCountError" do
      assert_raise Qx.QubitCountError, ~r/must be between 1 and 20/, fn ->
        QuantumCircuit.new(25, 25)
      end
    end

    test "new/1 with 20 qubits succeeds (boundary)" do
      qc = QuantumCircuit.new(20)
      assert qc.num_qubits == 20
    end

    test "new/2 with 1 qubit succeeds (boundary)" do
      qc = QuantumCircuit.new(1, 0)
      assert qc.num_qubits == 1
    end

    test "new/1 with 0 qubits raises Qx.QubitCountError (Iron Law #7 lower bound)" do
      assert_raise Qx.QubitCountError, ~r/must be between 1 and 20/, fn ->
        QuantumCircuit.new(0)
      end
    end

    test "new/1 with negative qubits raises Qx.QubitCountError" do
      assert_raise Qx.QubitCountError, ~r/must be between 1 and 20/, fn ->
        QuantumCircuit.new(-5)
      end
    end
  end
end
