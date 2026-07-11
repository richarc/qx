defmodule Qx.Export.OpenQASM do
  @moduledoc """
  Utility module: reached from `Qx.*` in normal use — export/import is the
  documented tier-2 escape hatch for OpenQASM interop.

  Export Qx quantum circuits to OpenQASM format **and import** OpenQASM 3.0
  source back into a `Qx.QuantumCircuit`.

  ## Return shapes

  Export and import deliberately report failure differently:

  - `to_qasm/2` returns a `String.t()` and **raises** on failure
    (`Qx.GateError`, `Qx.ConditionalError`, or `Qx.OptionError`). Its failure
    modes are all caller-controlled (an unsupported gate in the circuit you
    built, or a bad `:version` option) and are known before the call, so there
    is no `{:ok, _}` variant to handle.
  - `from_qasm/1` returns `{:ok, circuit} | {:error, reason}`, because it parses
    external source whose validity cannot be guaranteed; a parse failure is an
    expected, recoverable outcome. Use `from_qasm!/1` when you already trust the
    source and want it to raise instead.

  ## Importing OpenQASM (since v0.6.0)

  `from_qasm/1` parses OpenQASM 3 source produced by Qx, by Qiskit, or by
  IBM Quantum into a circuit:

      {:ok, circuit} = Qx.Export.OpenQASM.from_qasm(qasm_source)

  Round-trips with `to_qasm/1` — any program emitted by `to_qasm/1` parses
  back to a circuit with a matching state vector.

  `from_qasm_function/1` parses a `gate name(p) a, b { … }` definition and
  returns Elixir source for an equivalent function:

      {:ok, %{name: "bell", arity: 3, module: module, source: source}} =
        Qx.Export.OpenQASM.from_qasm_function(qasm_with_gate)

  `source` is a self-contained `defmodule Qx.Generated.<Name>_<hash> do … end`
  wrapping a `def name(circuit, params…, qubits…)` that composes `Qx.h/2`,
  `Qx.cx/3`, etc. via the `|>` pipeline. `Code.compile_string/1`-ing it defines
  that isolated module (named by `module`), so the helper can never be injected
  into the caller's own module.

  To *call* the generated function, compile `source` and use the module atom
  that `Code.compile_string/1` hands back:

      [{mod, _bin}] = Code.compile_string(source)
      circuit = mod.bell(Qx.create_circuit(2), 0, 1)

  `module` in the result map is that module's name as a **string** — for display
  or storage. Do **not** convert it to an atom yourself (e.g. `String.to_atom/1`
  or `Module.concat/1`) for untrusted input: compiling `source` interns the atom
  safely and only when the module actually loads, whereas eagerly interning one
  atom per distinct incoming program risks atom-table exhaustion.

  ### Supported gate set on import

  Direct mappings: `h, x, y, z, s, sdg, t, tdg, rx, ry, rz, p, phase, u,
  u3, cx, CX, cz, swap, iswap, cp, cphase, ccx, cswap`.

  Decompositions: `sx → u(π/2, -π/2, π/2)`, `u1(λ) → phase(λ)`,
  `u2(φ, λ) → u(π/2, φ, λ)`. `id` is dropped.

  ### Not supported (raises `Qx.QasmUnsupportedError`)

  Multi-register programs, gate modifiers (`inv`/`pow`/`ctrl`/`negctrl`),
  `else` branches, complex boolean conditions, classical types beyond
  `bit`, `def`, `for`, `while`, `switch`, `defcal`, `let`, `pragma`,
  `extern`, `box`, `delay`, `reset`, the stdgates `ch/cu/rxx/ryy/rzz/rzx`,
  and the Qiskit extensions `rxx/ryy/rzz/rzx`.

  ## Exporting

  This module provides functionality to convert Qx quantum circuits into OpenQASM
  code that can be executed on real quantum hardware platforms including:

  - IBM Quantum (IBM Q)
  - AWS Braket
  - Google Cirq (via OpenQASM import)
  - Rigetti (via AWS Braket)
  - IonQ (via AWS Braket or Azure Quantum)

  Supports both OpenQASM 2.0 and 3.0 specifications.

  ## OpenQASM Versions

  - **OpenQASM 2.0**: Legacy version, widely supported, no conditional operations
  - **OpenQASM 3.0**: Modern version with conditionals, mid-circuit measurements, and control flow

  ## Supported Features

  - Single-qubit gates (H, X, Y, Z, S, T, RX, RY, RZ, Phase)
  - Multi-qubit gates (CNOT/CX, CZ, Toffoli/CCX)
  - Measurements and classical bits
  - Conditional operations (OpenQASM 3.0 only)
  - Barriers for visualization organization

  ## Examples

      # Export a Bell state circuit to OpenQASM 3.0
      circuit = Qx.create_circuit(2)
        |> Qx.h(0)
        |> Qx.cx(0, 1)
        |> Qx.measure(0, 0)
        |> Qx.measure(1, 1)

      qasm = Qx.Export.OpenQASM.to_qasm(circuit)
      File.write!("bell_state.qasm", qasm)

      # Export to OpenQASM 2.0 (no conditionals)
      qasm2 = Qx.Export.OpenQASM.to_qasm(circuit, version: 2)

      # Export with custom options
      qasm = Qx.Export.OpenQASM.to_qasm(circuit,
        version: 3,
        include_comments: true,
        gate_style: :verbose
      )

  ## Platform Compatibility

  | Platform | Version | Mid-circuit Measurement | Conditionals |
  |----------|---------|------------------------|--------------|
  | IBM Quantum | 2.0, 3.0 | 3.0 only | 3.0 only |
  | AWS Braket | 3.0 | Yes | Yes |
  | Google Cirq | 2.0 | No | No |
  | Rigetti | 2.0, 3.0 | 3.0 only | 3.0 only |

  ## Limitations

  - Circuits with conditionals cannot be exported to OpenQASM 2.0
  - Custom gate definitions are expanded to standard gates
  - Qubit ordering follows MSB convention (qubit 0 is leftmost)
  """

  alias Qx.Export.OpenQASM.Codegen
  alias Qx.Export.OpenQASM.Lowering
  alias Qx.Export.OpenQASM.Parser
  alias Qx.QuantumCircuit

  # Hard ceiling on accepted QASM source length. The nimble_parsec
  # block-comment scanner is O(n²) on body length; capping the whole
  # source at 1 MB keeps worst-case parse time bounded and also
  # mitigates other unbounded-input concerns (deep parenthesisation,
  # very long identifiers).
  @max_qasm_size 1_048_576

  # Hard ceiling on parenthesis nesting depth. The expression grammar recurses
  # one parser frame per `(`, so within the 1 MB size cap a `((((…))))` chain
  # could still nest ~500K deep and exhaust the stack (:enomem) before the
  # parser errors. No legitimate gate-parameter expression nests this deep.
  @max_paren_depth 64

  @doc """
  Converts a Qx quantum circuit to OpenQASM format.

  ## Parameters

    * `circuit` - A `Qx.QuantumCircuit` struct
    * `options` - Keyword list of options (default: [])

  ## Options

    * `:version` - OpenQASM version (2 or 3, default: 3)
    * `:include_comments` - Add descriptive comments (default: false)
    * `:gate_style` - Gate naming style (`:standard` or `:verbose`, default: `:standard`)

  ## Returns

  A string containing the OpenQASM program.

  ## Raises

    * `Qx.GateError` - If circuit contains unsupported gates
    * `Qx.ConditionalError` - If circuit has conditionals but version is 2
    * `Qx.OptionError` - If the `:version` option is not 2 or 3

  ## Examples

      circuit = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
      qasm = Qx.Export.OpenQASM.to_qasm(circuit)

      # Output:
      # OPENQASM 3.0;
      # include "stdgates.inc";
      #
      # qubit[2] q;
      # bit[2] c;
      #
      # h q[0];
      # cx q[0], q[1];
  """
  @spec to_qasm(QuantumCircuit.t(), keyword()) :: String.t()
  def to_qasm(%QuantumCircuit{} = circuit, options \\ []) do
    version = Keyword.get(options, :version, 3)
    include_comments = Keyword.get(options, :include_comments, false)

    validate_version!(version)
    validate_circuit_for_version!(circuit, version)

    header = generate_header(version, circuit, include_comments)
    declarations = generate_declarations(circuit, version)
    instructions = generate_instructions(circuit, options)

    [header, declarations, instructions]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  # Private functions

  defp validate_version!(version) when version in [2, 3], do: :ok

  defp validate_version!(version) do
    raise Qx.OptionError, {:version, version, "Must be 2 or 3."}
  end

  defp validate_circuit_for_version!(%QuantumCircuit{instructions: instructions}, 2) do
    # Check for conditional operations which are not supported in OpenQASM 2.0
    has_conditionals? =
      Enum.any?(instructions, fn
        {:c_if, _qubits, _params} -> true
        _ -> false
      end)

    if has_conditionals? do
      raise Qx.ConditionalError,
            "Circuit contains conditional operations which are not supported in OpenQASM 2.0. Use version: 3."
    end

    :ok
  end

  defp validate_circuit_for_version!(_circuit, _version), do: :ok

  defp generate_header(version, _circuit, include_comments) do
    version_str = "#{version}.0"
    header = "OPENQASM #{version_str};"

    if include_comments do
      """
      #{header}
      // Generated by Qx - Quantum computing simulator for Elixir
      // https://github.com/your-repo/qx
      """
    else
      header
    end
  end

  defp generate_declarations(
         %QuantumCircuit{num_qubits: num_qubits, num_classical_bits: num_cbits},
         version
       ) do
    case version do
      3 ->
        """
        include "stdgates.inc";

        qubit[#{num_qubits}] q;
        bit[#{num_cbits}] c;
        """

      2 ->
        """
        include "qelib1.inc";

        qreg q[#{num_qubits}];
        creg c[#{num_cbits}];
        """
    end
  end

  defp generate_instructions(%QuantumCircuit{instructions: instructions}, options) do
    Enum.map_join(instructions, "\n", &instruction_to_qasm(&1, options))
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp instruction_to_qasm(instruction, _options) do
    case instruction do
      {:h, qubits, params} ->
        single_qubit_gate_to_qasm("h", qubits, params)

      {:x, qubits, params} ->
        single_qubit_gate_to_qasm("x", qubits, params)

      {:y, qubits, params} ->
        single_qubit_gate_to_qasm("y", qubits, params)

      {:z, qubits, params} ->
        single_qubit_gate_to_qasm("z", qubits, params)

      {:s, qubits, params} ->
        single_qubit_gate_to_qasm("s", qubits, params)

      {:sdg, qubits, params} ->
        single_qubit_gate_to_qasm("sdg", qubits, params)

      {:t, qubits, params} ->
        single_qubit_gate_to_qasm("t", qubits, params)

      {:tdg, qubits, params} ->
        single_qubit_gate_to_qasm("tdg", qubits, params)

      {:rx, qubits, params} ->
        parametric_gate_to_qasm("rx", qubits, params)

      {:ry, qubits, params} ->
        parametric_gate_to_qasm("ry", qubits, params)

      {:rz, qubits, params} ->
        parametric_gate_to_qasm("rz", qubits, params)

      {:phase, qubits, params} ->
        parametric_gate_to_qasm("p", qubits, params)

      {:u, [qubit], [theta, phi, lambda]} ->
        "u(#{theta}, #{phi}, #{lambda}) q[#{qubit}];"

      {:cx, qubits, params} ->
        two_qubit_gate_to_qasm("cx", qubits, params)

      {:cz, qubits, params} ->
        two_qubit_gate_to_qasm("cz", qubits, params)

      {:swap, qubits, params} ->
        two_qubit_gate_to_qasm("swap", qubits, params)

      {:iswap, qubits, params} ->
        two_qubit_gate_to_qasm("iswap", qubits, params)

      {:cp, [c, t], [theta]} ->
        "cp(#{theta}) q[#{c}], q[#{t}];"

      {:cy, [c, t], []} ->
        "cy q[#{c}], q[#{t}];"

      {:crx, [c, t], [theta]} ->
        "crx(#{theta}) q[#{c}], q[#{t}];"

      {:cry, [c, t], [theta]} ->
        "cry(#{theta}) q[#{c}], q[#{t}];"

      {:crz, [c, t], [theta]} ->
        "crz(#{theta}) q[#{c}], q[#{t}];"

      {:ccx, [c1, c2, target], []} ->
        "ccx q[#{c1}], q[#{c2}], q[#{target}];"

      {:cswap, [c, ta, tb], []} ->
        "cswap q[#{c}], q[#{ta}], q[#{tb}];"

      {:measure, [qubit, cbit], []} ->
        "c[#{cbit}] = measure q[#{qubit}];"

      {:barrier, qubits, []} ->
        barrier_to_qasm(qubits)

      {:c_if, [cbit, value], conditional_instructions} ->
        conditional_to_qasm(cbit, value, conditional_instructions)

      unsupported ->
        raise Qx.GateError, {:unsupported_gate, unsupported}
    end
  end

  defp single_qubit_gate_to_qasm(gate_name, [qubit], []) do
    "#{gate_name} q[#{qubit}];"
  end

  defp parametric_gate_to_qasm(gate_name, [qubit], [theta]) do
    "#{gate_name}(#{format_param(theta)}) q[#{qubit}];"
  end

  defp two_qubit_gate_to_qasm(gate_name, [control, target], []) do
    "#{gate_name} q[#{control}], q[#{target}];"
  end

  defp barrier_to_qasm(qubits) do
    qubit_list = Enum.map_join(qubits, ", ", &"q[#{&1}]")
    "barrier #{qubit_list};"
  end

  defp conditional_to_qasm(cbit, value, conditional_instructions) do
    conditional_qasm =
      Enum.map_join(
        conditional_instructions,
        "; ",
        &(&1 |> instruction_to_qasm([]) |> String.trim_trailing(";"))
      )

    "if (c[#{cbit}] == #{value}) { #{conditional_qasm}; }"
  end

  defp format_param(param) when is_float(param) do
    # Format with sufficient precision, avoid scientific notation for readability
    :erlang.float_to_binary(param, decimals: 10)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end

  defp format_param(param) when is_integer(param), do: "#{param}.0"
  defp format_param(param), do: "#{param}"

  # ---------------------------------------------------------------------
  # Importing — OpenQASM 3.0 → Qx.QuantumCircuit
  # ---------------------------------------------------------------------

  @doc """
  Parses OpenQASM 3.0 source and returns a `Qx.QuantumCircuit`.

  Round-trips with `to_qasm/1`: any program produced by `to_qasm/1` parses
  back to a circuit that simulates to the same state vector.

  ## Returns

    * `{:ok, %Qx.QuantumCircuit{}}` on success
    * `{:error, %Qx.QasmParseError{}}` on grammar/syntax failures
    * `{:error, %Qx.QasmUnsupportedError{}}` for valid QASM that uses
      features Qx does not yet support (multi-register programs, gate
      modifiers, `else` branches, classical types beyond `bit`, …)
    * `{:error, %Qx.QubitIndexError{}}` / `{:error, %Qx.ClassicalBitError{}}`
      for index validation failures

  ## Examples

      iex> qasm = ~s\"\"\"
      ...> OPENQASM 3.0;
      ...> include "stdgates.inc";
      ...> qubit[2] q;
      ...> bit[2] c;
      ...> h q[0];
      ...> cx q[0], q[1];
      ...> c[0] = measure q[0];
      ...> c[1] = measure q[1];
      ...> \"\"\"
      iex> {:ok, circuit} = Qx.Export.OpenQASM.from_qasm(qasm)
      iex> circuit.num_qubits
      2

  ## Supported features

  See the module doc for the supported gate set, decompositions, and the
  list of QASM 3 features deliberately excluded from v1 (each raises a
  typed `Qx.QasmUnsupportedError`).
  """
  @spec from_qasm(String.t()) ::
          {:ok, QuantumCircuit.t()} | {:error, Exception.t()}
  def from_qasm(source) when is_binary(source) do
    with :ok <- enforce_size(source),
         :ok <- enforce_paren_depth(source),
         {:ok, ast} <- Parser.parse(source) do
      Lowering.lower(ast)
    end
  end

  @doc """
  Like `from_qasm/1` but raises on error.
  """
  @spec from_qasm!(String.t()) :: QuantumCircuit.t()
  def from_qasm!(source) when is_binary(source) do
    case from_qasm(source) do
      {:ok, circuit} -> circuit
      {:error, exception} -> raise exception
    end
  end

  @doc """
  Parses an OpenQASM 3.0 program containing a `gate` definition and
  returns Elixir source code for an equivalent function.

  The result map is
  `%{name: String.t(), arity: pos_integer(), module: String.t(), source: String.t()}`
  where `source` is a self-contained `defmodule #{"Qx.Generated.<Name>_<hash>"} do … end`
  (named by `module`) that can be compiled via `Code.compile_string/1` (or
  stored verbatim by callers like `qxportal`). The wrapping module means the
  generated helper is never injected into the caller's own module. The function
  takes `(circuit, params..., qubits...)` and returns the new circuit.

  When the source contains multiple gate definitions, the **last** is
  treated as the "main" function — earlier ones are usually helpers
  which the main one references. Since user-defined gate references
  inside a gate body are rejected (`Qx.QasmUnsupportedError`), helpers
  themselves cannot be code-generated through this entry point.

  If no gate definition is present, returns `{:error, %Qx.QasmParseError{}}`.

  ## Example

      iex> qasm = ~s\"\"\"
      ...> OPENQASM 3.0;
      ...> include "stdgates.inc";
      ...> gate bell a, b {
      ...>   h a;
      ...>   cx a, b;
      ...> }
      ...> \"\"\"
      iex> {:ok, %{name: "bell", arity: 3, source: source}} =
      ...>   Qx.Export.OpenQASM.from_qasm_function(qasm)
      iex> source =~ "defmodule Qx.Generated.Bell" and source =~ "def bell(circuit, a, b)"
      true
  """
  @spec from_qasm_function(String.t()) :: {:ok, map()} | {:error, Exception.t()}
  def from_qasm_function(source) when is_binary(source) do
    with :ok <- enforce_size(source),
         :ok <- enforce_paren_depth(source),
         {:ok, {:program, statements}} <-
           source |> Parser.parse() |> reclassify_unsupported(),
         {:ok, gate_def} <- find_main_gate_def(statements) do
      Codegen.generate(gate_def)
    end
  end

  defp enforce_size(source) when byte_size(source) <= @max_qasm_size, do: :ok

  defp enforce_size(source) do
    {:error,
     Qx.QasmParseError.exception(
       reason:
         "QASM source exceeds maximum size of #{@max_qasm_size} bytes (got #{byte_size(source)})"
     )}
  end

  # Reject pathological parenthesis nesting before the recursive-descent
  # expression parser is reached (it recurses one frame per `(`). Tail-recursive
  # byte scan with early exit the moment depth exceeds the cap, so a paren bomb
  # is rejected after ~65 bytes. Counts every `(`, including inside comments and
  # string literals: a deliberate fail-closed tradeoff, since no legitimate
  # source nests 64 parentheses deep anywhere.
  defp enforce_paren_depth(source), do: scan_paren_depth(source, 0)

  defp scan_paren_depth(<<>>, _depth), do: :ok

  defp scan_paren_depth(<<?(, _rest::binary>>, depth) when depth + 1 > @max_paren_depth do
    {:error,
     Qx.QasmParseError.exception(
       reason: "expression nesting too deep (max #{@max_paren_depth} parentheses)"
     )}
  end

  defp scan_paren_depth(<<?(, rest::binary>>, depth), do: scan_paren_depth(rest, depth + 1)

  defp scan_paren_depth(<<?), rest::binary>>, depth),
    do: scan_paren_depth(rest, max(depth - 1, 0))

  defp scan_paren_depth(<<_, rest::binary>>, depth), do: scan_paren_depth(rest, depth)

  # Parser-level rejections that semantically mean "feature unsupported"
  # rather than "syntax error" surface as the typed unsupported exception.
  defp reclassify_unsupported({:ok, _} = ok), do: ok

  defp reclassify_unsupported({:error, %Qx.QasmParseError{reason: reason} = err}) do
    cond do
      is_binary(reason) and String.starts_with?(reason, "gate modifiers") ->
        {:error,
         Qx.QasmUnsupportedError.exception(
           feature: reason,
           line: err.line,
           hint: "Expand the modifier in source before importing"
         )}

      is_binary(reason) and String.starts_with?(reason, "complex boolean") ->
        {:error, Qx.QasmUnsupportedError.exception(feature: reason, line: err.line)}

      is_binary(reason) and String.starts_with?(reason, "`else`") ->
        {:error, Qx.QasmUnsupportedError.exception(feature: reason, line: err.line)}

      true ->
        {:error, err}
    end
  end

  @doc """
  Like `from_qasm_function/1` but raises on error.
  """
  @spec from_qasm_function!(String.t()) :: map()
  def from_qasm_function!(source) when is_binary(source) do
    case from_qasm_function(source) do
      {:ok, result} -> result
      {:error, exception} -> raise exception
    end
  end

  # When the source contains multiple gate definitions, the *last* is
  # treated as the "main" function — earlier ones are usually helpers
  # which the main one references. Codegen rejects user-defined gate
  # references, so the helpers themselves can't be code-generated.
  defp find_main_gate_def(statements) do
    case statements
         |> Enum.filter(&match?({:gate_def, _, _, _, _, _}, &1))
         |> List.last() do
      nil ->
        {:error, Qx.QasmParseError.exception(reason: "no `gate` definition found in QASM source")}

      gate_def ->
        {:ok, gate_def}
    end
  end
end
