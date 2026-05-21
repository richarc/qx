defmodule Qx.OperationsTypedErrorsTest do
  use ExUnit.Case, async: true

  alias Qx.{Operations, QuantumCircuit}

  describe "barrier/2 typed errors (Iron Law #7)" do
    test "out-of-range qubit raises Qx.QubitIndexError, not ArgumentError" do
      qc = QuantumCircuit.new(3, 0)

      assert_raise Qx.QubitIndexError, ~r/Qubit index 5 out of range/, fn ->
        Operations.barrier(qc, [0, 5])
      end
    end

    test "negative qubit raises Qx.QubitIndexError" do
      qc = QuantumCircuit.new(3, 0)

      assert_raise Qx.QubitIndexError, ~r/Qubit index -1 out of range/, fn ->
        Operations.barrier(qc, [-1, 0])
      end
    end
  end

  describe "c_if/4 typed errors (Iron Law #7)" do
    test "out-of-range classical bit raises Qx.ClassicalBitError, not ArgumentError" do
      qc = QuantumCircuit.new(2, 1)

      assert_raise Qx.ClassicalBitError, ~r/Classical bit index 5 out of range/, fn ->
        Operations.c_if(qc, 5, 1, fn c -> Operations.x(c, 1) end)
      end
    end

    test "invalid value raises Qx.ConditionalError, not ArgumentError" do
      qc = QuantumCircuit.new(2, 2)

      assert_raise Qx.ConditionalError, ~r/0 or 1/, fn ->
        Operations.c_if(qc, 0, 2, fn c -> Operations.x(c, 1) end)
      end
    end

    test "non-function gate_fn raises Qx.ConditionalError, not ArgumentError" do
      qc = QuantumCircuit.new(2, 2)

      assert_raise Qx.ConditionalError, ~r/function/, fn ->
        Operations.c_if(qc, 0, 1, :not_a_function)
      end
    end

    test "nested conditionals raise Qx.ConditionalError, not ArgumentError" do
      qc = QuantumCircuit.new(3, 3)

      assert_raise Qx.ConditionalError, ~r/Nested conditional/, fn ->
        Operations.c_if(qc, 0, 1, fn c ->
          Operations.c_if(c, 1, 1, fn c2 -> Operations.x(c2, 2) end)
        end)
      end
    end
  end
end
