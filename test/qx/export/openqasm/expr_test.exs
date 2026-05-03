defmodule Qx.Export.OpenQASM.ExprTest do
  use ExUnit.Case, async: true

  alias Qx.Export.OpenQASM.Expr

  defp eval(ast, env \\ %{}), do: Expr.eval(ast, env)

  describe "eval/2 — literals and constants" do
    test "integer literal" do
      assert eval({:expr, 3}) == 3.0
    end

    test "float literal" do
      assert eval({:expr, 1.5}) == 1.5
    end

    test "pi constant" do
      assert eval({:expr, :pi}) == :math.pi()
    end
  end

  describe "eval/2 — arithmetic" do
    test "addition" do
      assert eval({:expr, :add, [{:expr, 1}, {:expr, 2}]}) == 3.0
    end

    test "subtraction" do
      assert eval({:expr, :sub, [{:expr, 5}, {:expr, 2}]}) == 3.0
    end

    test "multiplication" do
      assert eval({:expr, :mul, [{:expr, 3}, {:expr, 4}]}) == 12.0
    end

    test "division" do
      assert eval({:expr, :div, [{:expr, :pi}, {:expr, 2}]}) == :math.pi() / 2
    end

    test "unary minus" do
      assert eval({:expr, :neg, [{:expr, :pi}]}) == -:math.pi()
    end

    test "nested expression: 2*pi/3" do
      ast =
        {:expr, :div,
         [
           {:expr, :mul, [{:expr, 2}, {:expr, :pi}]},
           {:expr, 3}
         ]}

      assert_in_delta eval(ast), 2 * :math.pi() / 3, 1.0e-12
    end
  end

  describe "eval/2 — function calls" do
    test "sin(0)" do
      assert eval({:expr, :call, ["sin", [{:expr, 0}]]}) == 0.0
    end

    test "cos(0)" do
      assert eval({:expr, :call, ["cos", [{:expr, 0}]]}) == 1.0
    end

    test "tan(pi/4)" do
      ast = {:expr, :call, ["tan", [{:expr, :div, [{:expr, :pi}, {:expr, 4}]}]]}
      assert_in_delta eval(ast), 1.0, 1.0e-12
    end

    test "sqrt(2)" do
      assert_in_delta eval({:expr, :call, ["sqrt", [{:expr, 2}]]}), :math.sqrt(2), 1.0e-12
    end

    test "exp(1) ≈ e" do
      assert_in_delta eval({:expr, :call, ["exp", [{:expr, 1}]]}), :math.exp(1), 1.0e-12
    end

    test "ln(e) == 1" do
      ast = {:expr, :call, ["ln", [{:expr, :call, ["exp", [{:expr, 1}]]}]]}
      assert_in_delta eval(ast), 1.0, 1.0e-12
    end

    test "unknown function raises QasmUnsupportedError" do
      assert_raise Qx.QasmUnsupportedError, fn ->
        eval({:expr, :call, ["foo", [{:expr, 1}]]})
      end
    end
  end

  describe "eval/2 — identifiers (gate-def parameters)" do
    test "looks up identifier from env" do
      assert eval({:expr, :ident, "theta"}, %{"theta" => 0.5}) == 0.5
    end

    test "missing identifier raises QasmParseError" do
      assert_raise Qx.QasmParseError, fn ->
        eval({:expr, :ident, "phi"}, %{})
      end
    end
  end
end
