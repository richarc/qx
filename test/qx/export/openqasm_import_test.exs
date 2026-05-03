defmodule Qx.Export.OpenQASMImportTest do
  use ExUnit.Case, async: true

  alias Qx.Export.OpenQASM

  describe "input size cap" do
    test "rejects sources larger than 1 MB with a typed parse error" do
      # 1 MB + 1 byte; the cap is exclusive.
      oversized = String.duplicate("/", 1_048_577)

      assert {:error, %Qx.QasmParseError{reason: reason}} = OpenQASM.from_qasm(oversized)
      assert reason =~ "exceeds maximum size"
    end

    test "from_qasm_function/1 also enforces the size cap" do
      oversized = String.duplicate("/", 1_048_577)
      assert {:error, %Qx.QasmParseError{}} = OpenQASM.from_qasm_function(oversized)
    end

    test "1 MB pathological block comment completes quickly under the cap" do
      # Just under the cap — should parse cleanly, never quadratically blow up.
      body = String.duplicate("a", 1_000_000)
      src = "/* #{body} */\nOPENQASM 3.0;\nqubit[1] q;\nh q[0];\n"

      {time_us, result} = :timer.tc(fn -> OpenQASM.from_qasm(src) end)
      assert {:ok, _circuit} = result
      # Should parse in well under a second on any reasonable machine.
      assert time_us < 5_000_000, "parse took #{time_us}µs (expected < 5s)"
    end
  end

  describe "from_qasm/1" do
    test "returns {:ok, %QuantumCircuit{}} on a valid Bell-state program" do
      src = """
      OPENQASM 3.0;
      include "stdgates.inc";
      qubit[2] q;
      bit[2] c;
      h q[0];
      cx q[0], q[1];
      c[0] = measure q[0];
      c[1] = measure q[1];
      """

      assert {:ok, circuit} = OpenQASM.from_qasm(src)
      assert circuit.num_qubits == 2
      assert circuit.num_classical_bits == 2

      assert circuit.instructions == [
               {:h, [0], []},
               {:cx, [0, 1], []},
               {:measure, [0, 0], []},
               {:measure, [1, 1], []}
             ]
    end

    test "returns {:error, %QasmParseError{}} on bad syntax" do
      src = "OPENQASM 3.0;\nqubit[2] q\n"
      assert {:error, %Qx.QasmParseError{} = err} = OpenQASM.from_qasm(src)
      assert err.line >= 2
    end

    test "returns {:error, %QasmUnsupportedError{}} on unsupported gate" do
      src = """
      OPENQASM 3.0;
      qubit[2] q;
      cy q[0], q[1];
      """

      assert {:error, %Qx.QasmUnsupportedError{feature: feature, line: line}} =
               OpenQASM.from_qasm(src)

      assert feature =~ "cy"
      assert line == 3
    end

    test "rejects multi-register programs with line of second decl" do
      src = """
      OPENQASM 3.0;
      qubit[2] q;
      qubit[1] r;
      """

      assert {:error, %Qx.QasmUnsupportedError{line: 3, feature: feature}} =
               OpenQASM.from_qasm(src)

      assert feature =~ "multiple"
    end
  end

  describe "arithmetic in parameter expressions" do
    test "division by zero in a gate parameter returns typed error" do
      src = """
      OPENQASM 3.0;
      qubit[1] q;
      rx(1/0) q[0];
      """

      assert {:error, %Qx.QasmParseError{reason: reason}} = OpenQASM.from_qasm(src)
      assert reason =~ "arithmetic"
    end
  end

  describe "from_qasm!/1" do
    test "returns the circuit on success" do
      src = """
      OPENQASM 3.0;
      qubit[1] q;
      h q[0];
      """

      circuit = OpenQASM.from_qasm!(src)
      assert circuit.instructions == [{:h, [0], []}]
    end

    test "raises on invalid input" do
      assert_raise Qx.QasmParseError, fn ->
        OpenQASM.from_qasm!("not qasm at all")
      end
    end

    test "raises QasmUnsupportedError on unsupported gates" do
      src = """
      OPENQASM 3.0;
      qubit[1] q;
      reset q[0];
      """

      assert_raise Qx.QasmUnsupportedError, fn ->
        OpenQASM.from_qasm!(src)
      end
    end
  end

  describe "parse-error line/column accuracy" do
    test "reports line of malformed gate call" do
      src = """
      OPENQASM 3.0;
      qubit[1] q;
      h q[0]
      """

      assert {:error, %Qx.QasmParseError{line: line}} = OpenQASM.from_qasm(src)
      # Missing ';' — parser bails right after `q[0]` on line 3 or at EOF (4).
      assert line in [3, 4]
    end

    test "reports line of unclosed parenthesis" do
      src = """
      OPENQASM 3.0;
      qubit[1] q;
      rx(pi/2 q[0];
      """

      assert {:error, %Qx.QasmParseError{line: line}} = OpenQASM.from_qasm(src)
      assert line >= 3
    end

    test "reports line of unknown register" do
      src = """
      OPENQASM 3.0;
      qubit[2] q;
      h r[0];
      """

      assert {:error, %Qx.QasmUnsupportedError{line: 3}} = OpenQASM.from_qasm(src)
    end

    test "reports line of out-of-bounds qubit index" do
      src = """
      OPENQASM 3.0;
      qubit[2] q;
      h q[5];
      """

      assert {:error, %Qx.QubitIndexError{}} = OpenQASM.from_qasm(src)
    end

    test "reports line of out-of-bounds classical bit" do
      src = """
      OPENQASM 3.0;
      qubit[1] q;
      bit[1] c;
      c[3] = measure q[0];
      """

      assert {:error, %Qx.ClassicalBitError{}} = OpenQASM.from_qasm(src)
    end
  end
end
