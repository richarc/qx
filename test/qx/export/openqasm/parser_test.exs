defmodule Qx.Export.OpenQASM.ParserTest do
  use ExUnit.Case, async: true

  alias Qx.Export.OpenQASM.Expr
  alias Qx.Export.OpenQASM.Parser

  describe "parse/1 — header" do
    test "parses minimal OPENQASM 3.0 header" do
      assert {:ok, {:program, statements}} = Parser.parse("OPENQASM 3.0;\n")
      assert [{:openqasm_version, "3.0", line: 1}] = statements
    end

    test "header followed by include is ok" do
      src = """
      OPENQASM 3.0;
      include "stdgates.inc";
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)

      assert statements == [
               {:openqasm_version, "3.0", line: 1},
               {:include, "stdgates.inc", line: 2}
             ]
    end

    test "missing header returns parse error" do
      assert {:error, %Qx.QasmParseError{}} = Parser.parse("qubit[2] q;\n")
    end
  end

  describe "parse/1 — declarations" do
    test "modern qubit and bit declarations" do
      src = """
      OPENQASM 3.0;
      qubit[5] q;
      bit[3] c;
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)

      assert statements == [
               {:openqasm_version, "3.0", line: 1},
               {:qreg_decl, "q", 5, line: 2},
               {:creg_decl, "c", 3, line: 3}
             ]
    end

    test "legacy qreg / creg declarations" do
      src = """
      OPENQASM 2.0;
      qreg q[2];
      creg c[2];
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)

      assert statements == [
               {:openqasm_version, "2.0", line: 1},
               {:qreg_decl, "q", 2, line: 2},
               {:creg_decl, "c", 2, line: 3}
             ]
    end
  end

  describe "parse/1 — comments and whitespace" do
    test "skips // line comments" do
      src = """
      // top of file
      OPENQASM 3.0;
      // a comment
      qubit[1] q; // trailing comment
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)

      assert statements == [
               {:openqasm_version, "3.0", line: 2},
               {:qreg_decl, "q", 1, line: 4}
             ]
    end

    test "skips /* block */ comments" do
      src = """
      /* license header
         spans
         multiple lines */
      OPENQASM 3.0;
      /* inline */ qubit[1] q;
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)

      assert [{:openqasm_version, "3.0", _}, {:qreg_decl, "q", 1, _}] = statements
    end

    test "rejects unterminated block comment" do
      src = "/* never closed\nOPENQASM 3.0;\n"
      assert {:error, %Qx.QasmParseError{}} = Parser.parse(src)
    end

    test "tolerates blank lines and indentation" do
      src = "\n\n   OPENQASM 3.0;\n\n\tqubit[2] q;\n"

      assert {:ok, {:program, statements}} = Parser.parse(src)
      assert [{:openqasm_version, "3.0", _}, {:qreg_decl, "q", 2, _}] = statements
    end
  end

  describe "parse/1 — gate calls" do
    test "plain single-qubit gate" do
      src = """
      OPENQASM 3.0;
      qubit[1] q;
      h q[0];
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)

      assert [
               _,
               _,
               {:gate_call, "h", [], [{:qubit_ref, "q", 0}], line: 3}
             ] = statements
    end

    test "two-qubit gate" do
      src = """
      OPENQASM 3.0;
      qubit[2] q;
      cx q[0], q[1];
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)

      assert {:gate_call, "cx", [], [{:qubit_ref, "q", 0}, {:qubit_ref, "q", 1}], line: 3} =
               List.last(statements)
    end

    test "parametric gate with single param" do
      src = """
      OPENQASM 3.0;
      qubit[1] q;
      rx(pi/2) q[0];
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)

      assert {:gate_call, "rx", [param_ast], [{:qubit_ref, "q", 0}], line: 3} =
               List.last(statements)

      assert_in_delta Expr.eval(param_ast), :math.pi() / 2, 1.0e-12
    end

    test "u(theta, phi, lambda) with three params" do
      src = """
      OPENQASM 3.0;
      qubit[1] q;
      u(0, 0, pi) q[0];
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)

      assert {:gate_call, "u", [a, b, c], [{:qubit_ref, "q", 0}], line: 3} =
               List.last(statements)

      assert Expr.eval(a) == 0.0
      assert Expr.eval(b) == 0.0
      assert_in_delta Expr.eval(c), :math.pi(), 1.0e-12
    end

    test "uppercase CX is recognized as gate name" do
      src = """
      OPENQASM 3.0;
      qubit[2] q;
      CX q[0], q[1];
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)
      assert {:gate_call, "CX", _, _, _} = List.last(statements)
    end
  end

  describe "parse/1 — measurement" do
    test "modern syntax c[i] = measure q[j]" do
      src = """
      OPENQASM 3.0;
      qubit[1] q;
      bit[1] c;
      c[0] = measure q[0];
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)

      assert {:measure, {:qubit_ref, "q", 0}, {:cbit_ref, "c", 0}, line: 4} =
               List.last(statements)
    end

    test "legacy syntax measure q[j] -> c[i]" do
      src = """
      OPENQASM 2.0;
      qreg q[1];
      creg c[1];
      measure q[0] -> c[0];
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)

      assert {:measure, {:qubit_ref, "q", 0}, {:cbit_ref, "c", 0}, line: 4} =
               List.last(statements)
    end

    test "discarded result `measure q[j];` is rejected" do
      src = """
      OPENQASM 3.0;
      qubit[1] q;
      measure q[0];
      """

      assert {:error, %Qx.QasmParseError{}} = Parser.parse(src)
    end
  end

  describe "parse/1 — barrier" do
    test "explicit qubit list" do
      src = """
      OPENQASM 3.0;
      qubit[2] q;
      barrier q[0], q[1];
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)

      assert {:barrier, [{:qubit_ref, "q", 0}, {:qubit_ref, "q", 1}], line: 3} =
               List.last(statements)
    end

    test "whole register `barrier q;`" do
      src = """
      OPENQASM 3.0;
      qubit[3] q;
      barrier q;
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)
      assert {:barrier, {:all, "q"}, line: 3} = List.last(statements)
    end
  end

  describe "parse/1 — conditionals" do
    test "if (c[i] == N) { stmt; stmt; } braced multi-statement" do
      src = """
      OPENQASM 3.0;
      qubit[2] q;
      bit[1] c;
      if (c[0] == 1) { x q[1]; h q[1]; }
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)

      assert {:c_if, {:cbit_ref, "c", 0}, 1, body, line: 4} = List.last(statements)
      assert [{:gate_call, "x", _, _, _}, {:gate_call, "h", _, _, _}] = body
    end

    test "if (c[i] == N) stmt; single-instruction body" do
      src = """
      OPENQASM 3.0;
      qubit[2] q;
      bit[1] c;
      if (c[0] == 1) x q[1];
      """

      assert {:ok, {:program, statements}} = Parser.parse(src)

      assert {:c_if, {:cbit_ref, "c", 0}, 1, [{:gate_call, "x", _, _, _}], line: 4} =
               List.last(statements)
    end

    test "else branch is rejected with refactor hint" do
      src = """
      OPENQASM 3.0;
      qubit[2] q;
      bit[1] c;
      if (c[0] == 1) { x q[1]; } else { h q[1]; }
      """

      assert {:error, %Qx.QasmParseError{reason: reason}} = Parser.parse(src)
      assert reason =~ "else"
    end

    test "complex condition with && is rejected" do
      src = """
      OPENQASM 3.0;
      qubit[1] q;
      bit[2] c;
      if (c[0] == 1 && c[1] == 0) x q[0];
      """

      assert {:error, %Qx.QasmParseError{}} = Parser.parse(src)
    end

    test "register-wide condition `c == 5` is rejected (not bit-indexed)" do
      src = """
      OPENQASM 3.0;
      qubit[1] q;
      bit[3] c;
      if (c == 5) x q[0];
      """

      assert {:error, %Qx.QasmParseError{}} = Parser.parse(src)
    end
  end

  describe "parse/1 — identifier rules" do
    test "register name may contain digits and underscores after the first char" do
      src = """
      OPENQASM 3.0;
      qubit[2] q_main1;
      """

      assert {:ok, {:program, [_, {:qreg_decl, "q_main1", 2, _}]}} = Parser.parse(src)
    end

    test "register name starting with a digit is rejected" do
      src = """
      OPENQASM 3.0;
      qubit[2] 1q;
      """

      assert {:error, %Qx.QasmParseError{}} = Parser.parse(src)
    end
  end
end
