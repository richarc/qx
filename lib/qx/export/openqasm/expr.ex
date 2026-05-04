defmodule Qx.Export.OpenQASM.Expr do
  @moduledoc """
  Evaluator for OpenQASM parameter expressions.

  Handles numeric literals, the `pi` constant, the four arithmetic operators,
  unary minus, and the function set `sin`, `cos`, `tan`, `exp`, `ln`, `sqrt`.

  Identifier references are resolved against an `env` map, used when
  evaluating bodies of `gate` definitions whose parameter names are bound
  to caller-supplied values. For top-level `gate_call` parameters the env is
  empty — any identifier reference there raises `Qx.QasmParseError`.

  Function names are matched against a literal whitelist; unknown names
  raise `Qx.QasmUnsupportedError`. Per Iron Law 1, no `String.to_atom/1`
  on caller-supplied identifiers.
  """

  @type expr :: tuple()
  @type env :: %{optional(String.t()) => float()}

  @doc """
  Evaluates an expression AST node to a float.
  """
  @spec eval(expr(), env()) :: float()
  def eval(expr, env \\ %{})

  def eval({:expr, :pi}, _env), do: :math.pi()

  def eval({:expr, n}, _env) when is_integer(n), do: n * 1.0
  def eval({:expr, n}, _env) when is_float(n), do: n

  def eval({:expr, :neg, [a]}, env), do: -eval(a, env)
  def eval({:expr, :add, [a, b]}, env), do: eval(a, env) + eval(b, env)
  def eval({:expr, :sub, [a, b]}, env), do: eval(a, env) - eval(b, env)
  def eval({:expr, :mul, [a, b]}, env), do: eval(a, env) * eval(b, env)
  def eval({:expr, :div, [a, b]}, env), do: eval(a, env) / eval(b, env)

  def eval({:expr, :call, [name, args]}, env) when is_binary(name) do
    apply_fun(name, Enum.map(args, &eval(&1, env)))
  end

  def eval({:expr, :ident, name}, env) when is_binary(name) do
    case Map.fetch(env, name) do
      {:ok, value} -> value * 1.0
      :error -> raise Qx.QasmParseError, reason: "unknown identifier: #{name}"
    end
  end

  # Whitelist of supported scalar functions. Hand-mapped so user-supplied
  # function names never reach `String.to_atom/1`.
  defp apply_fun("sin", [x]), do: :math.sin(x)
  defp apply_fun("cos", [x]), do: :math.cos(x)
  defp apply_fun("tan", [x]), do: :math.tan(x)
  defp apply_fun("exp", [x]), do: :math.exp(x)
  defp apply_fun("ln", [x]), do: :math.log(x)
  defp apply_fun("sqrt", [x]), do: :math.sqrt(x)

  defp apply_fun(name, _args) do
    raise Qx.QasmUnsupportedError,
      feature: "function #{name}",
      hint: "Supported: sin, cos, tan, exp, ln, sqrt"
  end
end
