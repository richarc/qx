defmodule Qx.Export.OpenQASM.LoweringTest do
  use ExUnit.Case, async: true

  alias Qx.Export.OpenQASM.Lowering
  alias Qx.Export.OpenQASM.Parser

  defp lower!(src) do
    {:ok, ast} = Parser.parse(src)
    {:ok, circuit} = Lowering.lower(ast)
    circuit
  end

  defp lower_error(src) do
    {:ok, ast} = Parser.parse(src)
    Lowering.lower(ast)
  end

  describe "register declarations" do
    test "single qubit + bit register" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[3] q;
        bit[2] c;
        """)

      assert circuit.num_qubits == 3
      assert circuit.num_classical_bits == 2
      assert circuit.instructions == []
    end

    test "legacy qreg/creg accepted" do
      circuit =
        lower!("""
        OPENQASM 2.0;
        qreg q[2];
        creg c[2];
        """)

      assert circuit.num_qubits == 2
      assert circuit.num_classical_bits == 2
    end

    test "two qubit registers raises QasmUnsupportedError pointing at second decl" do
      assert {:error, %Qx.QasmUnsupportedError{feature: feature, line: line}} =
               lower_error("""
               OPENQASM 3.0;
               qubit[2] q;
               qubit[1] r;
               """)

      assert feature =~ "multiple qubit registers"
      assert line == 3
    end

    test "no qubit register raises" do
      assert {:error, %Qx.QasmParseError{}} =
               lower_error("""
               OPENQASM 3.0;
               """)
    end
  end

  describe "direct stdgate mapping" do
    for {qasm_name, atom} <- [
          {"h", :h},
          {"x", :x},
          {"y", :y},
          {"z", :z},
          {"s", :s},
          {"sdg", :sdg},
          {"t", :t}
        ] do
      test "#{qasm_name} maps to #{atom}" do
        circuit =
          lower!("""
          OPENQASM 3.0;
          qubit[1] q;
          #{unquote(qasm_name)} q[0];
          """)

        assert circuit.instructions == [{unquote(atom), [0], []}]
      end
    end

    test "cx" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[2] q;
        cx q[0], q[1];
        """)

      assert circuit.instructions == [{:cx, [0, 1], []}]
    end

    test "uppercase CX is alias for cx" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[2] q;
        CX q[0], q[1];
        """)

      assert circuit.instructions == [{:cx, [0, 1], []}]
    end

    test "ccx (Toffoli)" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[3] q;
        ccx q[0], q[1], q[2];
        """)

      assert circuit.instructions == [{:ccx, [0, 1, 2], []}]
    end

    test "rx with parameter expression" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[1] q;
        rx(pi/2) q[0];
        """)

      assert [{:rx, [0], [theta]}] = circuit.instructions
      assert_in_delta theta, :math.pi() / 2, 1.0e-12
    end

    test "p alias maps to phase" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[1] q;
        p(pi/4) q[0];
        """)

      assert [{:phase, [0], [theta]}] = circuit.instructions
      assert_in_delta theta, :math.pi() / 4, 1.0e-12
    end

    test "u(theta, phi, lambda)" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[1] q;
        u(0, 0, pi) q[0];
        """)

      assert [{:u, [0], [a, b, c]}] = circuit.instructions
      assert a == 0.0
      assert b == 0.0
      assert_in_delta c, :math.pi(), 1.0e-12
    end
  end

  describe "decompositions" do
    test "tdg → phase(-pi/4)" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[1] q;
        tdg q[0];
        """)

      assert [{:phase, [0], [theta]}] = circuit.instructions
      assert_in_delta theta, -:math.pi() / 4, 1.0e-12
    end

    test "sx → u(pi/2, -pi/2, pi/2)" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[1] q;
        sx q[0];
        """)

      assert [{:u, [0], [a, b, c]}] = circuit.instructions
      assert_in_delta a, :math.pi() / 2, 1.0e-12
      assert_in_delta b, -:math.pi() / 2, 1.0e-12
      assert_in_delta c, :math.pi() / 2, 1.0e-12
    end

    test "u1(λ) → phase(λ)" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[1] q;
        u1(pi/3) q[0];
        """)

      assert [{:phase, [0], [theta]}] = circuit.instructions
      assert_in_delta theta, :math.pi() / 3, 1.0e-12
    end

    test "u2(φ, λ) → u(pi/2, φ, λ)" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[1] q;
        u2(0.5, 0.7) q[0];
        """)

      assert [{:u, [0], [a, b, c]}] = circuit.instructions
      assert_in_delta a, :math.pi() / 2, 1.0e-12
      assert_in_delta b, 0.5, 1.0e-12
      assert_in_delta c, 0.7, 1.0e-12
    end

    test "id is dropped (no instruction emitted)" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[1] q;
        h q[0];
        id q[0];
        x q[0];
        """)

      assert circuit.instructions == [{:h, [0], []}, {:x, [0], []}]
    end
  end

  describe "unsupported stdgates" do
    for unsupported <- ~w(cy ch crx cry crz cu rxx ryy rzz rzx) do
      test "#{unsupported} raises QasmUnsupportedError" do
        gate = unquote(unsupported)
        # Pick correct call pattern based on whether it takes a param.
        call =
          if gate in ~w(crx cry crz cu rxx ryy rzz rzx) do
            "#{gate}(0.5) q[0], q[1];"
          else
            "#{gate} q[0], q[1];"
          end

        src = "OPENQASM 3.0;\nqubit[2] q;\n#{call}\n"
        assert {:error, %Qx.QasmUnsupportedError{feature: feature}} = lower_error(src)
        assert feature =~ gate
      end
    end
  end

  describe "validation" do
    test "register name mismatch raises" do
      assert {:error, %Qx.QasmUnsupportedError{}} =
               lower_error("""
               OPENQASM 3.0;
               qubit[2] q;
               h r[0];
               """)
    end

    test "out-of-bounds qubit index raises" do
      assert {:error, %Qx.QubitIndexError{}} =
               lower_error("""
               OPENQASM 3.0;
               qubit[2] q;
               h q[5];
               """)
    end
  end

  describe "measurement and barrier" do
    test "modern measure produces :measure instruction" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[1] q;
        bit[1] c;
        c[0] = measure q[0];
        """)

      assert circuit.instructions == [{:measure, [0, 0], []}]
    end

    test "legacy measure produces :measure instruction" do
      circuit =
        lower!("""
        OPENQASM 2.0;
        qreg q[1];
        creg c[1];
        measure q[0] -> c[0];
        """)

      assert circuit.instructions == [{:measure, [0, 0], []}]
    end

    test "explicit barrier list" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[3] q;
        barrier q[0], q[2];
        """)

      assert circuit.instructions == [{:barrier, [0, 2], []}]
    end

    test "whole-register barrier expands to all qubits" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[3] q;
        barrier q;
        """)

      assert circuit.instructions == [{:barrier, [0, 1, 2], []}]
    end
  end

  describe "conditionals" do
    test "if (c[0] == 1) lowers to :c_if" do
      circuit =
        lower!("""
        OPENQASM 3.0;
        qubit[2] q;
        bit[1] c;
        if (c[0] == 1) x q[1];
        """)

      assert [{:c_if, [0, 1], inner}] = circuit.instructions
      assert inner == [{:x, [1], []}]
    end
  end
end
