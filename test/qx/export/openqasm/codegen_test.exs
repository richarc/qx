defmodule Qx.Export.OpenQASM.CodegenTest do
  use ExUnit.Case, async: true

  alias Qx.Export.OpenQASM

  describe "from_qasm_function/1" do
    test "simple non-parametric gate" do
      src = """
      OPENQASM 3.0;
      include "stdgates.inc";
      gate bell a, b {
        h a;
        cx a, b;
      }
      """

      assert {:ok, %{name: "bell", arity: 3, source: source}} = OpenQASM.from_qasm_function(src)
      assert source =~ "def bell(circuit, a, b)"
      assert source =~ "Qx.h(a)"
      assert source =~ "Qx.cx(a, b)"
    end

    test "parametric gate: theta and phi before qubits" do
      src = """
      OPENQASM 3.0;
      include "stdgates.inc";
      gate myr(theta) a {
        rx(theta) a;
      }
      """

      assert {:ok, %{name: "myr", arity: 3, source: source}} = OpenQASM.from_qasm_function(src)
      # Param order: circuit, params (in decl order), qubits (in decl order).
      assert source =~ "def myr(circuit, theta, a)"
      assert source =~ "Qx.rx(a, theta)"
    end

    test "two params, two qubits" do
      src = """
      OPENQASM 3.0;
      include "stdgates.inc";
      gate g(theta, phi) a, b {
        rx(theta) a;
        rz(phi) b;
        cx a, b;
      }
      """

      assert {:ok, %{name: "g", arity: 5, source: source}} = OpenQASM.from_qasm_function(src)
      assert source =~ "def g(circuit, theta, phi, a, b)"
    end

    test "generated source compiles" do
      src = """
      OPENQASM 3.0;
      include "stdgates.inc";
      gate bell a, b {
        h a;
        cx a, b;
      }
      """

      {:ok, %{source: source}} = OpenQASM.from_qasm_function(src)

      module_source = """
      defmodule TestGen.Bell#{:erlang.unique_integer([:positive])} do
        #{source}
      end
      """

      assert [{module, _bin} | _] = Code.compile_string(module_source)

      on_exit(fn ->
        :code.purge(module)
        :code.delete(module)
      end)

      circuit = Qx.create_circuit(2)
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      result = apply(module, :bell, [circuit, 0, 1])
      assert result.instructions == [{:h, [0], []}, {:cx, [0, 1], []}]
    end

    test "rejects modifiers in body (`ctrl @ h a;`)" do
      src = """
      OPENQASM 3.0;
      gate bad a, b {
        ctrl @ h a;
      }
      """

      assert {:error, %Qx.QasmUnsupportedError{}} = OpenQASM.from_qasm_function(src)
    end

    test "rejects nested user-gate references" do
      src = """
      OPENQASM 3.0;
      include "stdgates.inc";
      gate inner a { h a; }
      gate outer a { inner a; }
      """

      assert {:error, %Qx.QasmUnsupportedError{feature: feature}} =
               OpenQASM.from_qasm_function(src)

      assert feature =~ "inner" || feature =~ "user"
    end

    test "rejects adversarial gate name (newline)" do
      # Gate names that aren't valid identifiers should never reach codegen.
      src = "OPENQASM 3.0;\ngate q\nIO.puts(\"pwn\") a { h a; }\n"
      assert {:error, _} = OpenQASM.from_qasm_function(src)
    end

    test "unknown identifier in body parameter expression returns typed error" do
      # `gamma` isn't a declared parameter; codegen.expr_to_source would raise.
      # This pins the API contract: from_qasm_function/1 must return {:error, _},
      # never let the raise escape past the boundary.
      src = """
      OPENQASM 3.0;
      include "stdgates.inc";
      gate myr(theta) a {
        rx(gamma) a;
      }
      """

      assert {:error, %Qx.QasmParseError{}} = OpenQASM.from_qasm_function(src)
    end

    test "errors when no gate definition is present" do
      src = """
      OPENQASM 3.0;
      qubit[1] q;
      h q[0];
      """

      assert {:error, %Qx.QasmParseError{reason: reason}} = OpenQASM.from_qasm_function(src)
      assert reason =~ "no `gate`"
    end
  end

  describe "from_qasm_function!/1" do
    test "returns the map on success" do
      src = """
      OPENQASM 3.0;
      include "stdgates.inc";
      gate bell a, b { h a; cx a, b; }
      """

      assert %{name: "bell", arity: 3} = OpenQASM.from_qasm_function!(src)
    end

    test "raises on invalid input" do
      assert_raise Qx.QasmParseError, fn ->
        OpenQASM.from_qasm_function!("not a gate def")
      end
    end
  end
end
