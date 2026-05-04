defmodule Qx.Export.OpenQASM.Parser do
  @moduledoc """
  nimble_parsec grammar for the OpenQASM 3.0 subset Qx supports.

  See `Qx.Export.OpenQASM.AST` for the shape of the produced AST nodes.

  Whitespace and comments (`//` line and `/* … */` block, including nested
  blocks) are skipped between every grammar production via the `optional_ws`
  combinator — nimble_parsec has no built-in whitespace handling.
  """

  import NimbleParsec

  # ---------------------------------------------------------------------
  # Whitespace + comments
  # ---------------------------------------------------------------------

  line_comment =
    string("//")
    |> repeat(utf8_char(not: ?\n))

  # C-style block comment (does NOT nest, matching C/C++/QASM3 behaviour).
  block_comment =
    string("/*")
    |> repeat(lookahead_not(string("*/")) |> utf8_char([]))
    |> string("*/")

  ws_unit =
    choice([
      ascii_string([?\s, ?\t, ?\r, ?\n], min: 1),
      line_comment,
      block_comment
    ])
    |> ignore()

  optional_ws = repeat(ws_unit)

  # ---------------------------------------------------------------------
  # Lexical tokens
  # ---------------------------------------------------------------------

  # SECURITY: This rule is the primary enforcement of the identifier
  # charset. `Qx.Export.OpenQASM.Codegen.validate_identifier/1` re-validates
  # the same shape as defence-in-depth before interpolating identifiers
  # into a `def …` source string fed to `Code.compile_string/1`. Widening
  # this rule (e.g. to allow primes or unicode) without updating the
  # codegen regex would silently break the codegen safety contract.
  identifier =
    ascii_char([?a..?z, ?A..?Z, ?_])
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 0)
    |> reduce({List, :to_string, []})

  unsigned_integer =
    ascii_string([?0..?9], min: 1)
    |> map({String, :to_integer, []})

  # Numeric literal: integer or decimal with optional scientific exponent.
  # Returns a number (integer or float).
  numeric_literal =
    ascii_string([?0..?9], min: 1)
    |> optional(string(".") |> ascii_string([?0..?9], min: 1))
    |> optional(
      choice([string("e"), string("E")])
      |> optional(choice([string("+"), string("-")]))
      |> ascii_string([?0..?9], min: 1)
    )
    |> reduce(:to_number)

  string_literal =
    ignore(ascii_char([?"]))
    |> ascii_string([not: ?"], min: 0)
    |> ignore(ascii_char([?"]))

  # ---------------------------------------------------------------------
  # Statements
  # ---------------------------------------------------------------------

  version_literal =
    unsigned_integer
    |> ignore(string("."))
    |> concat(unsigned_integer)
    |> reduce(:join_version)

  openqasm_stmt =
    string("OPENQASM")
    |> ignore()
    |> ignore(ascii_string([?\s, ?\t], min: 1))
    |> concat(version_literal)
    |> concat(optional_ws)
    |> ignore(string(";"))
    |> post_traverse(:tag_openqasm)

  include_stmt =
    string("include")
    |> ignore()
    |> ignore(ascii_string([?\s, ?\t], min: 1))
    |> concat(string_literal)
    |> concat(optional_ws)
    |> ignore(string(";"))
    |> post_traverse(:tag_include)

  modern_qreg_stmt =
    string("qubit")
    |> ignore()
    |> concat(optional_ws)
    |> ignore(string("["))
    |> concat(optional_ws)
    |> concat(unsigned_integer)
    |> concat(optional_ws)
    |> ignore(string("]"))
    |> concat(optional_ws)
    |> concat(identifier)
    |> concat(optional_ws)
    |> ignore(string(";"))
    |> post_traverse(:tag_qreg)

  legacy_qreg_stmt =
    string("qreg")
    |> ignore()
    |> ignore(ascii_string([?\s, ?\t], min: 1))
    |> concat(optional_ws)
    |> concat(identifier)
    |> concat(optional_ws)
    |> ignore(string("["))
    |> concat(optional_ws)
    |> concat(unsigned_integer)
    |> concat(optional_ws)
    |> ignore(string("]"))
    |> concat(optional_ws)
    |> ignore(string(";"))
    |> post_traverse(:tag_legacy_qreg)

  modern_creg_stmt =
    string("bit")
    |> ignore()
    |> concat(optional_ws)
    |> ignore(string("["))
    |> concat(optional_ws)
    |> concat(unsigned_integer)
    |> concat(optional_ws)
    |> ignore(string("]"))
    |> concat(optional_ws)
    |> concat(identifier)
    |> concat(optional_ws)
    |> ignore(string(";"))
    |> post_traverse(:tag_creg)

  legacy_creg_stmt =
    string("creg")
    |> ignore()
    |> ignore(ascii_string([?\s, ?\t], min: 1))
    |> concat(optional_ws)
    |> concat(identifier)
    |> concat(optional_ws)
    |> ignore(string("["))
    |> concat(optional_ws)
    |> concat(unsigned_integer)
    |> concat(optional_ws)
    |> ignore(string("]"))
    |> concat(optional_ws)
    |> ignore(string(";"))
    |> post_traverse(:tag_legacy_creg)

  # ---------------------------------------------------------------------
  # Expression grammar (built bottom-up via parsec recursion)
  # ---------------------------------------------------------------------

  # Function name: literal identifier limited to whitelisted scalar funcs.
  fun_name =
    choice([
      string("sin"),
      string("cos"),
      string("tan"),
      string("exp"),
      string("ln"),
      string("sqrt")
    ])

  # Reference to a forward-declared `expression` parsec for recursion.
  expr_ref = parsec(:expression)

  primary =
    choice([
      # Parenthesised expression
      ignore(string("("))
      |> concat(optional_ws)
      |> concat(expr_ref)
      |> concat(optional_ws)
      |> ignore(string(")")),
      # Function call: name '(' expr ')'
      fun_name
      |> concat(optional_ws)
      |> ignore(string("("))
      |> concat(optional_ws)
      |> concat(expr_ref)
      |> concat(optional_ws)
      |> ignore(string(")"))
      |> reduce(:to_call_expr),
      # Constant: pi
      string("pi") |> replace({:expr, :pi}),
      # Numeric literal
      numeric_literal |> reduce(:to_number_expr),
      # Bare identifier (gate-def parameter reference). Must come last so
      # `pi`, function names, etc. take precedence.
      identifier |> reduce(:to_ident_expr)
    ])

  unary =
    choice([
      ignore(string("-"))
      |> concat(optional_ws)
      |> concat(primary)
      |> reduce(:to_neg_expr),
      primary
    ])

  # Multiplicative: unary (('*' | '/') unary)*
  mul_op = choice([string("*") |> replace(:mul), string("/") |> replace(:div)])

  multiplicative =
    unary
    |> repeat(
      optional_ws
      |> concat(mul_op)
      |> concat(optional_ws)
      |> concat(unary)
    )
    |> reduce(:fold_left_expr)

  # Additive: multiplicative (('+' | '-') multiplicative)*
  add_op = choice([string("+") |> replace(:add), string("-") |> replace(:sub)])

  additive =
    multiplicative
    |> repeat(
      optional_ws
      |> concat(add_op)
      |> concat(optional_ws)
      |> concat(multiplicative)
    )
    |> reduce(:fold_left_expr)

  defparsec(:expression, additive)

  # ---------------------------------------------------------------------
  # Qubit/cbit references
  # ---------------------------------------------------------------------

  qubit_ref =
    identifier
    |> concat(optional_ws)
    |> ignore(string("["))
    |> concat(optional_ws)
    |> concat(unsigned_integer)
    |> concat(optional_ws)
    |> ignore(string("]"))
    |> reduce(:to_qubit_ref)

  cbit_ref =
    identifier
    |> concat(optional_ws)
    |> ignore(string("["))
    |> concat(optional_ws)
    |> concat(unsigned_integer)
    |> concat(optional_ws)
    |> ignore(string("]"))
    |> reduce(:to_cbit_ref)

  # ---------------------------------------------------------------------
  # Gate calls
  # ---------------------------------------------------------------------

  param_list =
    ignore(string("("))
    |> concat(optional_ws)
    |> concat(parsec(:expression))
    |> repeat(
      optional_ws
      |> ignore(string(","))
      |> concat(optional_ws)
      |> concat(parsec(:expression))
    )
    |> concat(optional_ws)
    |> ignore(string(")"))
    |> reduce(:wrap_params)

  qubit_list =
    qubit_ref
    |> repeat(
      optional_ws
      |> ignore(string(","))
      |> concat(optional_ws)
      |> concat(qubit_ref)
    )
    |> reduce(:wrap_qubits)

  # Gate-call identifier: any identifier that is NOT a reserved keyword.
  # We rely on grammar order (other statement productions tried first) to
  # disambiguate; identifier alone is sufficient here.
  gate_call_stmt =
    identifier
    |> concat(optional_ws)
    |> optional(param_list)
    |> concat(optional_ws)
    |> concat(qubit_list)
    |> concat(optional_ws)
    |> ignore(string(";"))
    |> post_traverse(:tag_gate_call)

  # ---------------------------------------------------------------------
  # Measurement
  # ---------------------------------------------------------------------

  measure_modern_stmt =
    cbit_ref
    |> concat(optional_ws)
    |> ignore(string("="))
    |> concat(optional_ws)
    |> ignore(string("measure"))
    |> ignore(ascii_string([?\s, ?\t], min: 1))
    |> concat(optional_ws)
    |> concat(qubit_ref)
    |> concat(optional_ws)
    |> ignore(string(";"))
    |> post_traverse(:tag_measure_modern)

  measure_legacy_stmt =
    ignore(string("measure"))
    |> ignore(ascii_string([?\s, ?\t], min: 1))
    |> concat(optional_ws)
    |> concat(qubit_ref)
    |> concat(optional_ws)
    |> ignore(string("->"))
    |> concat(optional_ws)
    |> concat(cbit_ref)
    |> concat(optional_ws)
    |> ignore(string(";"))
    |> post_traverse(:tag_measure_legacy)

  # Catches `measure q[j];` (no target). Always fails — Qx requires a
  # classical bit target for every measurement.
  measure_discarded_stmt =
    string("measure")
    |> concat(ascii_string([?\s, ?\t], min: 1))
    |> concat(qubit_ref)
    |> concat(optional_ws)
    |> string(";")
    |> post_traverse(:reject_discarded_measure)

  # ---------------------------------------------------------------------
  # Barrier
  # ---------------------------------------------------------------------

  barrier_explicit_stmt =
    ignore(string("barrier"))
    |> ignore(ascii_string([?\s, ?\t], min: 1))
    |> concat(optional_ws)
    |> concat(qubit_list)
    |> concat(optional_ws)
    |> ignore(string(";"))
    |> post_traverse(:tag_barrier_explicit)

  barrier_register_stmt =
    ignore(string("barrier"))
    |> ignore(ascii_string([?\s, ?\t], min: 1))
    |> concat(optional_ws)
    |> concat(identifier)
    |> concat(optional_ws)
    |> ignore(string(";"))
    |> post_traverse(:tag_barrier_register)

  # ---------------------------------------------------------------------
  # Conditionals — `if (c[i] == N) <body>` (no else)
  # ---------------------------------------------------------------------

  # An "inner statement" is anything that may legally appear inside an
  # `if` body. Conditionals do NOT nest in v1.
  inner_statement =
    choice([
      measure_modern_stmt,
      measure_legacy_stmt,
      measure_discarded_stmt,
      barrier_explicit_stmt,
      barrier_register_stmt,
      gate_call_stmt
    ])

  if_braced_body =
    ignore(string("{"))
    |> concat(optional_ws)
    |> repeat(concat(inner_statement, optional_ws))
    |> ignore(string("}"))
    |> reduce(:wrap_body)

  if_unbraced_body =
    inner_statement
    |> reduce(:wrap_body)

  # Reject complex boolean operators in the condition.
  complex_cond_check =
    choice([string("&&"), string("||"), string("!")])
    |> post_traverse(:reject_complex_cond)

  if_condition =
    ignore(string("if"))
    |> concat(optional_ws)
    |> ignore(string("("))
    |> concat(optional_ws)
    |> concat(cbit_ref)
    |> concat(optional_ws)
    |> ignore(string("=="))
    |> concat(optional_ws)
    |> concat(unsigned_integer)
    |> concat(optional_ws)
    |> ignore(string(")"))

  if_stmt =
    if_condition
    |> concat(optional_ws)
    |> concat(choice([if_braced_body, if_unbraced_body]))
    |> post_traverse(:tag_if_check_else)

  # ---------------------------------------------------------------------
  # Gate definitions: `gate name(p1, p2) a, b { body }`
  # ---------------------------------------------------------------------

  param_decl_list =
    ignore(string("("))
    |> concat(optional_ws)
    |> concat(identifier)
    |> repeat(
      optional_ws
      |> ignore(string(","))
      |> concat(optional_ws)
      |> concat(identifier)
    )
    |> concat(optional_ws)
    |> ignore(string(")"))
    |> reduce(:wrap_param_names)

  qubit_decl_list =
    identifier
    |> repeat(
      optional_ws
      |> ignore(string(","))
      |> concat(optional_ws)
      |> concat(identifier)
    )
    |> reduce(:wrap_qubit_names)

  # Detect gate modifiers (`inv @`, `pow(N) @`, `ctrl @`, `negctrl @`)
  # at the start of a gate-body statement; reject with an unsupported
  # error rather than a generic parse error.
  modifier_check =
    choice([
      string("inv"),
      string("pow"),
      string("ctrl"),
      string("negctrl")
    ])
    |> concat(optional_ws)
    |> string("@")
    |> post_traverse(:reject_modifier)

  # Inside a `gate` body, qubit args are *bare identifiers* (declared
  # parameters of the gate), not `name[index]` references.
  bare_qubit_ref = identifier |> reduce(:to_bare_qubit_ref)

  bare_qubit_list =
    bare_qubit_ref
    |> repeat(
      optional_ws
      |> ignore(string(","))
      |> concat(optional_ws)
      |> concat(bare_qubit_ref)
    )
    |> reduce(:wrap_qubits)

  # Gate-body inner statement: only stdgate-style calls in v1 (no measure,
  # no barrier, no if). Qubit args are bare identifiers; param expressions
  # may reference declared gate parameters (handled at codegen time).
  gate_body_inner =
    identifier
    |> concat(optional_ws)
    |> optional(param_list)
    |> concat(optional_ws)
    |> concat(bare_qubit_list)
    |> concat(optional_ws)
    |> ignore(string(";"))
    |> post_traverse(:tag_gate_call)

  gate_def_stmt =
    ignore(string("gate"))
    |> ignore(ascii_string([?\s, ?\t], min: 1))
    |> concat(optional_ws)
    |> concat(identifier)
    |> concat(optional_ws)
    |> optional(param_decl_list)
    |> concat(optional_ws)
    |> concat(qubit_decl_list)
    |> concat(optional_ws)
    |> ignore(string("{"))
    |> concat(optional_ws)
    |> repeat(concat(choice([modifier_check, gate_body_inner]), optional_ws))
    |> ignore(string("}"))
    |> post_traverse(:tag_gate_def)

  body_statement =
    choice([
      include_stmt,
      gate_def_stmt,
      modern_qreg_stmt,
      legacy_qreg_stmt,
      modern_creg_stmt,
      legacy_creg_stmt,
      if_stmt,
      complex_cond_check,
      measure_modern_stmt,
      measure_legacy_stmt,
      measure_discarded_stmt,
      barrier_explicit_stmt,
      barrier_register_stmt,
      gate_call_stmt
    ])

  program_combinator =
    optional_ws
    |> concat(openqasm_stmt)
    |> concat(optional_ws)
    |> repeat(concat(body_statement, optional_ws))
    |> eos()

  defparsec(:program, program_combinator)

  # ---------------------------------------------------------------------
  # Post-traverse helpers (require defp definitions; available at runtime)
  # ---------------------------------------------------------------------

  defp join_version([major, minor]), do: "#{major}.#{minor}"

  defp tag_openqasm(rest, [version], context, {line, _col}, _offset) do
    {rest, [{:openqasm_version, version, line: line}], context}
  end

  defp tag_include(rest, [path], context, {line, _col}, _offset) do
    {rest, [{:include, path, line: line}], context}
  end

  defp tag_qreg(rest, [name, size], context, {line, _col}, _offset) do
    {rest, [{:qreg_decl, name, size, line: line}], context}
  end

  defp tag_legacy_qreg(rest, [size, name], context, {line, _col}, _offset) do
    {rest, [{:qreg_decl, name, size, line: line}], context}
  end

  defp tag_creg(rest, [name, size], context, {line, _col}, _offset) do
    {rest, [{:creg_decl, name, size, line: line}], context}
  end

  defp tag_legacy_creg(rest, [size, name], context, {line, _col}, _offset) do
    {rest, [{:creg_decl, name, size, line: line}], context}
  end

  defp to_number([int_part]), do: String.to_integer(int_part)

  defp to_number(parts) when is_list(parts) do
    parts |> Enum.join("") |> String.to_float()
  end

  defp to_number_expr([n]) when is_integer(n), do: {:expr, n}
  defp to_number_expr([n]) when is_float(n), do: {:expr, n}

  defp to_ident_expr([name]), do: {:expr, :ident, name}

  defp to_neg_expr([inner]), do: {:expr, :neg, [inner]}

  defp to_call_expr([name, arg_expr]), do: {:expr, :call, [name, [arg_expr]]}

  # Left-associative fold over a list of [first, op, b, op, c, ...] tokens.
  defp fold_left_expr([first | rest]), do: do_fold(first, rest)
  defp do_fold(acc, []), do: acc
  defp do_fold(acc, [op, rhs | rest]), do: do_fold({:expr, op, [acc, rhs]}, rest)

  defp to_qubit_ref([name, index]), do: {:qubit_ref, name, index}
  defp to_cbit_ref([name, index]), do: {:cbit_ref, name, index}
  # Bare identifier inside a gate body — index is a placeholder symbol.
  defp to_bare_qubit_ref([name]), do: {:qubit_ref, name, 0}

  defp wrap_params(args), do: {:params, args}
  defp wrap_qubits(args), do: {:qubits, args}

  defp tag_gate_call(rest, args, context, {line, _col}, _offset) do
    # args were pushed in reverse order by nimble_parsec; the first element
    # in `args` is the most-recently parsed (the qubits list), then params
    # (optional), then the gate name. Pull them back out.
    {qubits, params, name} =
      case args do
        [{:qubits, qs}, {:params, ps}, name] -> {qs, ps, name}
        [{:qubits, qs}, name] -> {qs, [], name}
      end

    {rest, [{:gate_call, name, params, qubits, line: line}], context}
  end

  defp tag_measure_modern(rest, [qubit_ref, cbit_ref], context, {line, _col}, _offset) do
    {rest, [{:measure, qubit_ref, cbit_ref, line: line}], context}
  end

  defp tag_measure_legacy(rest, [cbit_ref, qubit_ref], context, {line, _col}, _offset) do
    {rest, [{:measure, qubit_ref, cbit_ref, line: line}], context}
  end

  defp tag_barrier_explicit(rest, [{:qubits, qs}], context, {line, _col}, _offset) do
    {rest, [{:barrier, qs, line: line}], context}
  end

  defp tag_barrier_register(rest, [name], context, {line, _col}, _offset) do
    {rest, [{:barrier, {:all, name}, line: line}], context}
  end

  defp reject_discarded_measure(_rest, _args, _context, _line_col, _offset) do
    {:error,
     "discarded `measure q[i];` not supported — Qx requires a classical bit target (`c[j] = measure q[i];`)"}
  end

  defp tag_if_check_else(rest, args, context, {line, col}, offset) do
    case skip_ws_for_else(rest) do
      {:else, _new_rest} ->
        {:error,
         "`else` branches not supported — refactor as two `if` statements: `if (c == N) { ... }; if (c != N) { ... }`"}

      :no_else ->
        tag_if(rest, args, context, {line, col}, offset)
    end
  end

  defp tag_if(rest, args, context, {line, _col}, _offset) do
    [{:body, body_stmts}, value, cbit] = args
    {rest, [{:c_if, cbit, value, body_stmts, line: line}], context}
  end

  defp skip_ws_for_else(<<c, rest::binary>>) when c in [?\s, ?\t, ?\r, ?\n],
    do: skip_ws_for_else(rest)

  defp skip_ws_for_else(<<"//", rest::binary>>) do
    rest
    |> skip_to_newline()
    |> skip_ws_for_else()
  end

  defp skip_ws_for_else(<<"/*", rest::binary>>) do
    case skip_to_block_close(rest) do
      :error -> :no_else
      after_block -> skip_ws_for_else(after_block)
    end
  end

  defp skip_ws_for_else(<<"else", rest::binary>>), do: {:else, rest}
  defp skip_ws_for_else(_), do: :no_else

  defp skip_to_newline(<<>>), do: ""
  defp skip_to_newline(<<"\n", rest::binary>>), do: rest
  defp skip_to_newline(<<_, rest::binary>>), do: skip_to_newline(rest)

  defp skip_to_block_close(<<>>), do: :error
  defp skip_to_block_close(<<"*/", rest::binary>>), do: rest
  defp skip_to_block_close(<<_, rest::binary>>), do: skip_to_block_close(rest)

  defp reject_complex_cond(_rest, _args, _context, _line_col, _offset) do
    {:error,
     "complex boolean conditions (&&, ||, !) are not supported — only `if (c[i] == N)` is allowed"}
  end

  defp reject_modifier(_rest, _args, _context, _line_col, _offset) do
    {:error, "gate modifiers (inv, pow, ctrl, negctrl) are not supported in v1"}
  end

  defp wrap_body(args), do: {:body, args}

  defp wrap_param_names(args), do: {:param_names, args}
  defp wrap_qubit_names(args), do: {:qubit_names, args}

  defp tag_gate_def(rest, args, context, {line, _col}, _offset) do
    # args reverse order: [body_stmt_n, ..., body_stmt_1, qubit_names_token,
    #                      maybe_param_names_token, name]
    {body_rev, rest_args} =
      Enum.split_while(args, fn
        {:gate_call, _, _, _, _} -> true
        _ -> false
      end)

    body = Enum.reverse(body_rev)

    {qubit_names, param_names, name} =
      case rest_args do
        [{:qubit_names, qns}, {:param_names, pns}, name] -> {qns, pns, name}
        [{:qubit_names, qns}, name] -> {qns, [], name}
      end

    {rest, [{:gate_def, name, param_names, qubit_names, body, line: line}], context}
  end

  # ---------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------

  @doc """
  Parses an OpenQASM 3.0 source string into a `{:program, [statement]}` AST.

  Returns `{:ok, ast}` on success or `{:error, %Qx.QasmParseError{}}` on
  failure.
  """
  @spec parse(String.t()) :: {:ok, tuple()} | {:error, Exception.t()}
  def parse(source) when is_binary(source) do
    case program(source) do
      {:ok, statements, "", _ctx, _line_col, _offset} ->
        {:ok, {:program, statements}}

      {:ok, _statements, rest, _ctx, {line, col}, _offset} ->
        snippet = take_snippet(rest)

        {:error,
         Qx.QasmParseError.exception(
           line: line,
           column: col,
           snippet: snippet,
           reason: "unexpected input"
         )}

      {:error, reason, rest, _ctx, {line, col}, _offset} ->
        snippet = take_snippet(rest)

        {:error,
         Qx.QasmParseError.exception(
           line: line,
           column: col,
           snippet: snippet,
           reason: reason
         )}
    end
  end

  defp take_snippet(rest) do
    case String.split(rest, "\n", parts: 2) do
      [first | _] -> String.slice(first, 0, 80)
      [] -> ""
    end
  end
end
