defmodule Qx.Export.OpenQASM.Lowering do
  @moduledoc """
  Converts a parsed OpenQASM AST (see `Qx.Export.OpenQASM.AST`) into a
  `%Qx.QuantumCircuit{}`.

  This stage performs:

  * **Register tracking** — accepts a single `qubit`/`bit` register; rejects
    multi-register programs with a typed error pointing at the second
    declaration.
  * **Gate-name resolution** — looks up each `gate_call` against a literal
    whitelist (`@stdgate_table`); unknown names raise
    `Qx.QasmUnsupportedError`. Per Iron Law 1, never converts caller input
    to atoms.
  * **Decomposition** — for `tdg`, `sx`, `u1`, `u2`, expands to one or more
    Qx instruction tuples. `id` is dropped.
  * **Parameter evaluation** — calls `Qx.Export.OpenQASM.Expr.eval/2` to
    fold numeric expressions to floats.
  * **Validation** — qubit references must point at the declared register
    and stay in bounds; classical bits likewise.
  """

  alias Qx.Export.OpenQASM.Expr
  alias Qx.QuantumCircuit

  # Direct mappings: QASM gate name → Qx instruction atom + arity check.
  # Using a literal map ensures user-supplied strings never reach
  # String.to_atom/1 (Iron Law 1).
  @stdgate_table %{
    # Single-qubit, no params
    "h" => {:h, 1, 0},
    "x" => {:x, 1, 0},
    "y" => {:y, 1, 0},
    "z" => {:z, 1, 0},
    "s" => {:s, 1, 0},
    "sdg" => {:sdg, 1, 0},
    "t" => {:t, 1, 0},
    # Parametric single-qubit
    "rx" => {:rx, 1, 1},
    "ry" => {:ry, 1, 1},
    "rz" => {:rz, 1, 1},
    "p" => {:phase, 1, 1},
    "phase" => {:phase, 1, 1},
    "u" => {:u, 1, 3},
    "u3" => {:u, 1, 3},
    # Two-qubit
    "cx" => {:cx, 2, 0},
    "CX" => {:cx, 2, 0},
    "cz" => {:cz, 2, 0},
    "swap" => {:swap, 2, 0},
    "iswap" => {:iswap, 2, 0},
    "cp" => {:cp, 2, 1},
    "cphase" => {:cp, 2, 1},
    # Three-qubit
    "ccx" => {:ccx, 3, 0},
    "cswap" => {:cswap, 3, 0}
  }

  # Gate names from stdgates.inc that Qx cannot represent today.
  @unsupported_stdgates MapSet.new(~w(cy ch crx cry crz cu rxx ryy rzz rzx))

  @doc """
  Lowers a parsed AST into a `%QuantumCircuit{}`.

  Returns `{:ok, circuit}` or `{:error, exception}` where exception is one
  of `Qx.QasmParseError`, `Qx.QasmUnsupportedError`, `Qx.QubitIndexError`,
  `Qx.ClassicalBitError`.
  """
  @spec lower({:program, list()}) ::
          {:ok, QuantumCircuit.t()} | {:error, Exception.t()}
  def lower({:program, statements}) do
    initial_state = %{
      qreg_name: nil,
      qreg_size: 0,
      creg_name: nil,
      creg_size: 0,
      instructions: [],
      measurements: [],
      measured_qubits: MapSet.new()
    }

    statements
    |> Enum.reduce_while({:ok, initial_state}, fn stmt, {:ok, state} ->
      case lower_stmt(stmt, state) do
        {:ok, new_state} -> {:cont, {:ok, new_state}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, %{qreg_name: nil}} ->
        {:error,
         Qx.QasmParseError.exception(
           reason: "no qubit register declared (expected `qubit[N] q;` or `qreg q[N];`)"
         )}

      {:ok, state} ->
        {:ok, build_circuit(state)}

      {:error, _} = err ->
        err
    end
  end

  defp build_circuit(state) do
    qubits = max(state.qreg_size, 1)
    cbits = state.creg_size

    # `QuantumCircuit.new/2` already builds the |0…0⟩ state vector via the
    # canonical Nx primitives, avoiding a host-side 2^n list allocation.
    %{
      QuantumCircuit.new(qubits, cbits)
      | instructions: Enum.reverse(state.instructions),
        measurements: Enum.reverse(state.measurements),
        measured_qubits: state.measured_qubits
    }
  end

  # --- Statement handlers ----------------------------------------------

  defp lower_stmt({:openqasm_version, _v, _meta}, state), do: {:ok, state}
  defp lower_stmt({:include, _path, _meta}, state), do: {:ok, state}
  # Gate definitions are routed through `from_qasm_function/1`; they are
  # silently ignored when reached from `from_qasm/1`.
  defp lower_stmt({:gate_def, _name, _params, _qubits, _body, _meta}, state), do: {:ok, state}

  defp lower_stmt({:qreg_decl, name, size, meta}, state) do
    case state.qreg_name do
      nil ->
        {:ok, %{state | qreg_name: name, qreg_size: size}}

      _existing ->
        {:error,
         Qx.QasmUnsupportedError.exception(
           feature: "multiple qubit registers (Qx supports a single register)",
           line: Keyword.get(meta, :line),
           hint: "Combine your registers into one before importing"
         )}
    end
  end

  defp lower_stmt({:creg_decl, name, size, meta}, state) do
    case state.creg_name do
      nil ->
        {:ok, %{state | creg_name: name, creg_size: size}}

      _existing ->
        {:error,
         Qx.QasmUnsupportedError.exception(
           feature: "multiple classical registers (Qx supports a single register)",
           line: Keyword.get(meta, :line)
         )}
    end
  end

  defp lower_stmt({:gate_call, name, params, qubits, meta}, state) do
    line = Keyword.get(meta, :line)

    with {:ok, target} <- lookup_gate(name, line),
         {:ok, qubit_indices} <- resolve_qubits(qubits, state, line),
         {:ok, param_values} <- evaluate_params(params, %{}),
         {:ok, instructions} <- expand_gate(target, qubit_indices, param_values, name, line) do
      {:ok, %{state | instructions: prepend(instructions, state.instructions)}}
    end
  end

  defp lower_stmt({:measure, qubit_ref, cbit_ref, meta}, state) do
    line = Keyword.get(meta, :line)

    with {:ok, [qi]} <- resolve_qubits([qubit_ref], state, line),
         {:ok, ci} <- resolve_cbit(cbit_ref, state, line) do
      measurement = {qi, ci}
      instr = {:measure, [qi, ci], []}

      {:ok,
       %{
         state
         | measurements: [measurement | state.measurements],
           measured_qubits: MapSet.put(state.measured_qubits, qi),
           instructions: [instr | state.instructions]
       }}
    end
  end

  defp lower_stmt({:barrier, {:all, reg_name}, meta}, state) do
    line = Keyword.get(meta, :line)

    if reg_name == state.qreg_name do
      qubit_indices = Enum.to_list(0..(state.qreg_size - 1))
      {:ok, %{state | instructions: [{:barrier, qubit_indices, []} | state.instructions]}}
    else
      {:error,
       Qx.QasmUnsupportedError.exception(
         feature: "barrier on undeclared register `#{reg_name}`",
         line: line
       )}
    end
  end

  defp lower_stmt({:barrier, qubit_refs, meta}, state) do
    line = Keyword.get(meta, :line)

    with {:ok, indices} <- resolve_qubits(qubit_refs, state, line) do
      {:ok, %{state | instructions: [{:barrier, indices, []} | state.instructions]}}
    end
  end

  defp lower_stmt({:c_if, cbit_ref, value, body, meta}, state) do
    line = Keyword.get(meta, :line)

    with {:ok, ci} <- resolve_cbit(cbit_ref, state, line),
         {:ok, body_instructions} <- lower_body(body, state) do
      {:ok,
       %{
         state
         | instructions: [{:c_if, [ci, value], body_instructions} | state.instructions]
       }}
    end
  end

  defp lower_body(stmts, state) do
    Enum.reduce_while(stmts, {:ok, []}, fn stmt, {:ok, acc_rev} ->
      case lower_stmt(stmt, %{state | instructions: []}) do
        # `new_instrs` arrives reversed (newest-first, from prepend); we keep
        # the body accumulator reversed too and reverse once at the very end.
        {:ok, %{instructions: new_instrs}} ->
          {:cont, {:ok, prepend(Enum.reverse(new_instrs), acc_rev)}}

        {:error, _} = err ->
          {:halt, err}
      end
    end)
    |> case do
      {:ok, acc_rev} -> {:ok, Enum.reverse(acc_rev)}
      err -> err
    end
  end

  # --- Gate dispatch + decomposition -----------------------------------

  @decomposable_gates ~w(tdg sx u1 u2 id)

  defp lookup_gate(name, line) do
    case Map.fetch(@stdgate_table, name) do
      {:ok, spec} ->
        {:ok, {:direct, spec}}

      :error when name in @decomposable_gates ->
        {:ok, {:decompose, name}}

      :error ->
        if MapSet.member?(@unsupported_stdgates, name) do
          {:error,
           Qx.QasmUnsupportedError.exception(
             feature: "gate `#{name}` (no Qx equivalent)",
             line: line
           )}
        else
          {:error,
           Qx.QasmUnsupportedError.exception(
             feature: "unknown gate `#{name}`",
             line: line
           )}
        end
    end
  end

  defp expand_gate({:direct, {atom, expected_q, expected_p}}, qubits, params, name, line) do
    cond do
      length(qubits) != expected_q ->
        {:error,
         Qx.QasmParseError.exception(
           reason: "gate `#{name}` expects #{expected_q} qubit(s), got #{length(qubits)}",
           line: line
         )}

      length(params) != expected_p ->
        {:error,
         Qx.QasmParseError.exception(
           reason: "gate `#{name}` expects #{expected_p} parameter(s), got #{length(params)}",
           line: line
         )}

      true ->
        {:ok, [{atom, qubits, params}]}
    end
  end

  defp expand_gate({:decompose, "tdg"}, [q], [], _name, _line),
    do: {:ok, [{:phase, [q], [-:math.pi() / 4]}]}

  defp expand_gate({:decompose, "sx"}, [q], [], _name, _line),
    do: {:ok, [{:u, [q], [:math.pi() / 2, -:math.pi() / 2, :math.pi() / 2]}]}

  defp expand_gate({:decompose, "u1"}, [q], [lambda], _name, _line),
    do: {:ok, [{:phase, [q], [lambda]}]}

  defp expand_gate({:decompose, "u2"}, [q], [phi, lambda], _name, _line),
    do: {:ok, [{:u, [q], [:math.pi() / 2, phi, lambda]}]}

  defp expand_gate({:decompose, "id"}, _qubits, _params, _name, _line), do: {:ok, []}

  defp expand_gate({:decompose, name}, _qubits, _params, _, line) do
    {:error,
     Qx.QasmParseError.exception(
       reason: "decomposition for `#{name}` requires a different arity",
       line: line
     )}
  end

  # --- Reference resolution + validation -------------------------------

  defp resolve_qubits(qubit_refs, state, line) do
    Enum.reduce_while(qubit_refs, {:ok, []}, fn {:qubit_ref, name, idx}, {:ok, acc_rev} ->
      cond do
        state.qreg_name == nil ->
          {:halt,
           {:error,
            Qx.QasmParseError.exception(
              reason: "qubit reference `#{name}[#{idx}]` before any `qubit` declaration",
              line: line
            )}}

        name != state.qreg_name ->
          {:halt,
           {:error,
            Qx.QasmUnsupportedError.exception(
              feature: "register `#{name}` not declared (only `#{state.qreg_name}` known)",
              line: line
            )}}

        idx < 0 or idx >= state.qreg_size ->
          {:halt, {:error, Qx.QubitIndexError.exception({idx, state.qreg_size})}}

        true ->
          {:cont, {:ok, [idx | acc_rev]}}
      end
    end)
    |> case do
      {:ok, acc_rev} -> {:ok, Enum.reverse(acc_rev)}
      err -> err
    end
  end

  defp resolve_cbit({:cbit_ref, name, idx}, state, line) do
    cond do
      state.creg_name == nil ->
        {:error,
         Qx.QasmParseError.exception(
           reason: "classical bit reference `#{name}[#{idx}]` before any `bit` declaration",
           line: line
         )}

      name != state.creg_name ->
        {:error,
         Qx.QasmUnsupportedError.exception(
           feature: "classical register `#{name}` not declared",
           line: line
         )}

      idx < 0 or idx >= state.creg_size ->
        {:error, Qx.ClassicalBitError.exception({idx, state.creg_size})}

      true ->
        {:ok, idx}
    end
  end

  defp evaluate_params(params, env) do
    {:ok, Enum.map(params, &Expr.eval(&1, env))}
  rescue
    e in [Qx.QasmParseError, Qx.QasmUnsupportedError] ->
      {:error, e}

    e in [ArithmeticError] ->
      {:error,
       Qx.QasmParseError.exception(
         reason: "arithmetic error evaluating parameter expression: #{Exception.message(e)}"
       )}
  end

  defp prepend([], acc), do: acc
  defp prepend([head | tail], acc), do: prepend(tail, [head | acc])
end
