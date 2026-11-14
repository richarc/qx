defmodule Qx.ConditionalMeasurementGuardTest do
  use ExUnit.Case, async: true

  alias Qx.Export.OpenQASM
  alias Qx.QuantumCircuit

  # A measurement inside a `c_if` block was accepted and then skipped by the
  # simulator: the gates in the block ran, the classical bit was never set.
  # The block is now rejected where it is built.

  describe "Qx.c_if/4 with a measurement in the block" do
    setup do
      %{qc: Qx.create_circuit(2, 2) |> Qx.x(0) |> Qx.measure(0, 0)}
    end

    test "raises Qx.ConditionalError at build time", %{qc: qc} do
      message =
        "Measurement is not supported inside a conditional block; " <>
          "measure after the c_if block instead"

      assert_raise Qx.ConditionalError, message, fn ->
        Qx.c_if(qc, 0, 1, fn c -> Qx.measure(c, 1, 1) end)
      end
    end

    test "raises when the measurement follows a gate", %{qc: qc} do
      assert_raise Qx.ConditionalError, ~r/[Mm]easurement.*conditional block/, fn ->
        Qx.c_if(qc, 0, 1, fn c -> c |> Qx.x(1) |> Qx.measure(1, 1) end)
      end
    end

    test "raises for a basis measurement helper, which ends in a measurement", %{qc: qc} do
      assert_raise Qx.ConditionalError, ~r/[Mm]easurement.*conditional block/, fn ->
        Qx.c_if(qc, 0, 1, fn c -> Qx.measure_x(c, 1, 1) end)
      end
    end

    test "a block of gates only is accepted and runs", %{qc: qc} do
      circuit =
        qc
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
        |> Qx.measure(1, 1)

      assert Qx.run(circuit, shots: 10).counts == %{"11" => 10}
    end
  end

  describe "OpenQASM import with a measurement in an if block" do
    @header """
    OPENQASM 3.0;
    include "stdgates.inc";
    qubit[2] q;
    bit[2] c;
    x q[0];
    c[0] = measure q[0];
    """

    # The `if` is on line 7 and the measurement on line 9.
    @source @header <>
              """
              if (c[0] == 1) {
                x q[1];
                c[1] = measure q[1];
              }
              """

    test "from_qasm/1 returns a Qx.QasmUnsupportedError naming the line" do
      assert {:error, %Qx.QasmUnsupportedError{} = error} = OpenQASM.from_qasm(@source)

      assert error.feature == "measurement inside an `if` block"
      assert error.line == 9
      assert error.hint == "Measure after the `if` block instead"
    end

    test "a measurement that is the only statement in the block is rejected" do
      source = @header <> "if (c[0] == 1) { c[1] = measure q[1]; }\n"

      assert {:error, %Qx.QasmUnsupportedError{line: 7}} = OpenQASM.from_qasm(source)
    end

    test "an unbraced measurement is rejected" do
      source = @header <> "if (c[0] == 1) c[1] = measure q[1];\n"

      assert {:error, %Qx.QasmUnsupportedError{} = error} = OpenQASM.from_qasm(source)
      assert error.feature == "measurement inside an `if` block"
    end

    test "the arrow form of a measurement is rejected" do
      source = @header <> "if (c[0] == 1) { measure q[1] -> c[1]; }\n"

      assert {:error, %Qx.QasmUnsupportedError{} = error} = OpenQASM.from_qasm(source)
      assert error.feature == "measurement inside an `if` block"
    end

    test "a measurement after the block still imports and runs" do
      source = @header <> "if (c[0] == 1) { x q[1]; }\nc[1] = measure q[1];\n"

      assert Qx.run(OpenQASM.from_qasm!(source), shots: 10).counts == %{"11" => 10}
    end

    test "from_qasm!/1 raises Qx.QasmUnsupportedError" do
      assert_raise Qx.QasmUnsupportedError, ~r/measurement inside an `if` block/, fn ->
        OpenQASM.from_qasm!(@source)
      end
    end
  end

  describe "a one-qubit :measure instruction" do
    # No producer emits this shape; a measurement always carries [qubit, cbit].
    # It used to be a silent no-op in the gate dispatch.
    test "raises Qx.GateError when run" do
      circuit = QuantumCircuit.put_instructions(Qx.create_circuit(1, 1), [{:measure, [0], []}])

      assert_raise Qx.GateError, fn -> Qx.run(circuit, shots: 1) end
    end

    test "raises Qx.GateError when stepped" do
      circuit = QuantumCircuit.put_instructions(Qx.create_circuit(1, 1), [{:measure, [0], []}])

      assert_raise Qx.GateError, fn -> Enum.to_list(Qx.steps(circuit)) end
    end
  end
end
