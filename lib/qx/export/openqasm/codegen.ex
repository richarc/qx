defmodule Qx.Export.OpenQASM.Codegen do
  @moduledoc """
  Translates a single OpenQASM `gate` definition into Elixir source code
  that defines an equivalent circuit-transforming function.

  The generated function has the signature

      def name(circuit, p1, p2, ..., q1, q2, ...)

  — `circuit` first, then declared parameters in source order, then qubit
  arguments in source order — and returns a new circuit with the
  expanded gate body applied.

  Only stdgate references are emitted in v1; nested user-defined gate
  references and modifiers (`inv`, `pow`, `ctrl`, `negctrl`) are rejected
  with `Qx.QasmUnsupportedError` upstream in the parser/lowering layer.
  """

  # Supported QASM gate name → emitted Elixir helper. Same whitelist as
  # Lowering's @stdgate_table but emits Elixir source rather than
  # instruction tuples.
  @stdgate_emit %{
    "h" => {"Qx.h", :single, 0},
    "x" => {"Qx.x", :single, 0},
    "y" => {"Qx.y", :single, 0},
    "z" => {"Qx.z", :single, 0},
    "s" => {"Qx.s", :single, 0},
    "sdg" => {"Qx.sdg", :single, 0},
    "t" => {"Qx.t", :single, 0},
    "rx" => {"Qx.rx", :single, 1},
    "ry" => {"Qx.ry", :single, 1},
    "rz" => {"Qx.rz", :single, 1},
    "p" => {"Qx.phase", :single, 1},
    "phase" => {"Qx.phase", :single, 1},
    "u" => {"Qx.u", :single, 3},
    "cx" => {"Qx.cx", :two, 0},
    "CX" => {"Qx.cx", :two, 0},
    "cz" => {"Qx.cz", :two, 0},
    "swap" => {"Qx.swap", :two, 0},
    "iswap" => {"Qx.iswap", :two, 0},
    "cp" => {"Qx.cp", :two, 1},
    "cphase" => {"Qx.cp", :two, 1},
    "ccx" => {"Qx.ccx", :three, 0},
    "cswap" => {"Qx.cswap", :three, 0}
  }

  @decomposable ~w(tdg sx u1 u2 id)

  @doc """
  Generates a `%{name, arity, source}` map from a `:gate_def` AST node.

  Returns `{:ok, map}` or `{:error, exception}`.
  """
  @spec generate(tuple()) :: {:ok, map()} | {:error, Exception.t()}
  def generate({:gate_def, name, param_names, qubit_names, body, _meta}) do
    with :ok <- validate_identifier(name),
         :ok <- validate_all_identifiers(param_names ++ qubit_names),
         {:ok, body_lines} <- emit_body(body, param_names, qubit_names) do
      arity = 1 + length(param_names) + length(qubit_names)
      args = ["circuit"] ++ param_names ++ qubit_names

      source =
        IO.iodata_to_binary([
          "def #{name}(#{Enum.join(args, ", ")}) do\n",
          "  circuit\n",
          Enum.map(body_lines, &["  ", &1, "\n"]),
          "end"
        ])

      {:ok, %{name: name, arity: arity, source: source}}
    end
  rescue
    e in [Qx.QasmParseError, Qx.QasmUnsupportedError] -> {:error, e}
  end

  # Validate that EVERY name passes `validate_identifier/1`. Stops at the
  # first failure and returns its `{:error, exception}`.
  defp validate_all_identifiers(names) do
    Enum.find_value(names, :ok, fn name ->
      case validate_identifier(name) do
        :ok -> nil
        error -> error
      end
    end)
  end

  # SECURITY: Identifiers must match `[A-Za-z_][A-Za-z0-9_]*` exactly.
  # The parser's `identifier` combinator (parser.ex) is the primary
  # enforcement; this regex is defence-in-depth so that any future change
  # to the parser charset cannot silently break codegen safety. The
  # `def …` source produced by `generate/1` is fed to
  # `Code.compile_string/1` by callers, so any identifier that escapes
  # this check could become arbitrary Elixir code.
  defp validate_identifier(name) when is_binary(name) do
    if Regex.match?(~r/\A[A-Za-z_][A-Za-z0-9_]*\z/, name) do
      :ok
    else
      {:error,
       Qx.QasmParseError.exception(
         reason: "invalid identifier in gate definition: #{inspect(name)}"
       )}
    end
  end

  defp emit_body(body, param_names, qubit_names) do
    Enum.reduce_while(body, {:ok, []}, fn stmt, {:ok, acc} ->
      case emit_stmt(stmt, param_names, qubit_names) do
        {:ok, line} -> {:cont, {:ok, acc ++ [line]}}
        err -> {:halt, err}
      end
    end)
  end

  defp emit_stmt({:gate_call, gate_name, params, qubits, _meta}, param_names, qubit_names) do
    cond do
      Map.has_key?(@stdgate_emit, gate_name) ->
        emit_stdgate(gate_name, params, qubits, param_names, qubit_names)

      gate_name in @decomposable ->
        {:error,
         Qx.QasmUnsupportedError.exception(
           feature:
             "gate `#{gate_name}` inside a `gate` body — codegen does not yet expand decompositions"
         )}

      true ->
        {:error,
         Qx.QasmUnsupportedError.exception(
           feature: "user-defined gate reference `#{gate_name}` inside another gate body"
         )}
    end
  end

  defp emit_stdgate(gate_name, params, qubits, param_names, qubit_names) do
    {emit_fun, shape, expected_p} = Map.fetch!(@stdgate_emit, gate_name)

    if length(params) != expected_p do
      {:error,
       Qx.QasmParseError.exception(
         reason: "gate `#{gate_name}` expects #{expected_p} parameter(s), got #{length(params)}"
       )}
    else
      with {:ok, qubit_args} <- map_qubit_refs(qubits, qubit_names) do
        param_args = Enum.map(params, &expr_to_source(&1, param_names))
        ordered_args = order_args(shape, qubit_args, param_args)
        line = "|> #{emit_fun}(#{Enum.join(ordered_args, ", ")})"
        {:ok, line}
      end
    end
  end

  # Qx.rx(qubit, theta) — qubits before params for parametric single-qubit
  # Qx.cp(c, t, theta)  — qubits before param for cp
  # Qx.h(qubit), Qx.cx(c, t), Qx.ccx(c1, c2, t), Qx.u(q, t, p, l)
  defp order_args(_shape, qubit_args, []), do: qubit_args
  defp order_args(_shape, qubit_args, param_args), do: qubit_args ++ param_args

  defp map_qubit_refs(qubits, qubit_names) do
    qubit_set = MapSet.new(qubit_names)

    Enum.reduce_while(qubits, {:ok, []}, fn
      {:qubit_ref, name, _idx}, {:ok, acc} ->
        if MapSet.member?(qubit_set, name) do
          {:cont, {:ok, acc ++ [name]}}
        else
          {:halt,
           {:error,
            Qx.QasmParseError.exception(
              reason: "qubit `#{name}` not declared as a parameter of the surrounding gate"
            )}}
        end
    end)
  end

  # Convert an expression AST to an Elixir source fragment that, when
  # evaluated in scope of the generated function (with declared parameter
  # names bound), produces the same float as Expr.eval would.
  defp expr_to_source({:expr, :pi}, _env), do: ":math.pi()"

  defp expr_to_source({:expr, n}, _env) when is_integer(n), do: "#{n}"

  defp expr_to_source({:expr, n}, _env) when is_float(n) do
    :erlang.float_to_binary(n, [:short])
  end

  defp expr_to_source({:expr, :neg, [a]}, env), do: "-(#{expr_to_source(a, env)})"

  defp expr_to_source({:expr, op, [a, b]}, env) when op in [:add, :sub, :mul, :div] do
    "(#{expr_to_source(a, env)} #{op_string(op)} #{expr_to_source(b, env)})"
  end

  defp expr_to_source({:expr, :call, [name, [arg]]}, env) do
    "#{call_emit(name)}(#{expr_to_source(arg, env)})"
  end

  defp expr_to_source({:expr, :ident, name}, env) do
    if name in env do
      name
    else
      raise Qx.QasmParseError,
        reason: "unknown identifier `#{name}` in gate body parameter expression"
    end
  end

  defp op_string(:add), do: "+"
  defp op_string(:sub), do: "-"
  defp op_string(:mul), do: "*"
  defp op_string(:div), do: "/"

  defp call_emit("sin"), do: ":math.sin"
  defp call_emit("cos"), do: ":math.cos"
  defp call_emit("tan"), do: ":math.tan"
  defp call_emit("exp"), do: ":math.exp"
  defp call_emit("ln"), do: ":math.log"
  defp call_emit("sqrt"), do: ":math.sqrt"

  # Defence-in-depth: should be unreachable because the parser's `fun_name`
  # combinator only matches the same six names. If those drift apart we'd
  # rather raise a typed error than `FunctionClauseError` past the boundary.
  defp call_emit(name) do
    raise Qx.QasmUnsupportedError,
      feature: "function `#{name}` not supported in gate-body codegen"
  end
end
