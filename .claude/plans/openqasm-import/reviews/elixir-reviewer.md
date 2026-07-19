# Elixir Reviewer — OpenQASM Import

⚠️ Captured from agent chat output — agent's Write was denied by hook.

**Status**: Changes Requested
**Findings**: 9 (0 BLOCKER, 4 WARNING, 5 SUGGESTION)

## Warnings

### W1. `lib/qx/export/openqasm/lowering.ex:101-105` — `rescue` for own-code control flow
`lower/1` wraps `reduce_while` in a `rescue Qx.QasmParseError`/`Qx.QasmUnsupportedError`/`Qx.QubitIndexError`/`Qx.ClassicalBitError`. `expand_gate/5` is Qx code that deliberately raises so the rescue can convert exceptions back to `{:error, e}`. This is the "rescue for control flow" anti-pattern.

**Fix**: make `expand_gate` return `{:ok, instrs} | {:error, e}` and thread it through `with` inside `lower_stmt/2`, removing the rescue entirely.

### W2. `lib/qx/export/openqasm.ex:484-494` — name/doc/code mismatch in `find_first_gate_def/1`
Function is named `find_first_gate_def` and `@doc` says "Only the *first* gate definition... is converted", but the implementation calls `List.last/1`. Reader-confusion bug; the scratchpad documents last-wins intent but readers won't check the scratchpad.

**Fix**: rename to `find_primary_gate_def/1` (or `find_main_gate_def/1`) and update the `@doc` to match.

### W3. `lib/qx/export/openqasm/codegen.ex:190-192` — `expr_to_source/2` raises and leaks past API boundary
`expr_to_source/2` raises `Qx.QasmParseError` for unknown identifiers. Called from `emit_stdgate` inside `emit_body`'s `reduce_while` inside `generate/1`. `generate/1` has NO `rescue`, so the public `from_qasm_function/1` can leak a raw exception instead of returning `{:error, _}`.

**Fix**: add a `rescue` in `generate/1` (mirroring `Lowering.lower/1`) OR convert `expr_to_source` to return `{:ok, src} | {:error, e}`.

### W4. `lib/qx/export/openqasm/lowering.ex:245` — O(n²) `acc ++ ...` inside `reduce_while`
`lower_body/2` builds its accumulator with `acc ++ Enum.reverse(new_instrs)`. `++` is O(length(acc)) per iteration → overall O(n²) for bodies with many statements.

**Fix**: prepend and reverse once at the end (consistent with the outer `lower/1` loop).

## Suggestions

### S1. `lib/qx/export/openqasm/lowering.ex:256-276` — `cond` with `Map.has_key?`; prefer `case Map.fetch`
```elixir
defp lookup_gate(name, line) do
  case Map.fetch(@stdgate_table, name) do
    {:ok, spec} -> {:ok, {:direct, spec}}
    :error when name in ~w(tdg sx u1 u2 id) -> {:ok, {:decompose, name}}
    :error -> handle_unknown_or_unsupported(name, line)
  end
end
```

### S2. `lib/qx/export/openqasm/codegen.ex:57` — `validate_each/2` adapter exists only to fit `reduce_while`
Replace with `Enum.find_value/3`:
```elixir
:ok <- validate_all_identifiers(param_names ++ qubit_names),

defp validate_all_identifiers(names) do
  Enum.find_value(names, :ok, fn name ->
    case validate_identifier(name) do
      :ok -> nil
      error -> error
    end
  end)
end
```

### S3. `lib/qx/export/openqasm/parser.ex:739-746` — `|> case do` idiom in `take_snippet/1`
Piping into `case do` is unusual. Cleaner:
```elixir
defp take_snippet(rest) do
  case String.split(rest, "\n", parts: 2) do
    [first | _] -> String.slice(first, 0, 80)
    [] -> ""
  end
end
```

### S4. `lib/qx/export/openqasm/expr.ex:29` — `n / 1` opaque integer→float coercion
`n / 1` works but obscures intent. Use `n * 1.0`.

### S5. `lib/qx/export/openqasm/lowering.ex:122-130` — host-side 2^n list in `initial_state_vector/1`
Builds `1..2^n |> Enum.map(Complex.new...)` on the host before passing to Nx. At 20+ qubits this allocates ~1M structs. Check whether `Qx.QuantumCircuit.new/1` already exposes a shared init helper and reuse it, or use `Nx.broadcast`/`Nx.put_slice` to construct |0…0⟩ tensor-side.

## Pre-existing (one-line)
- `lib/qx/export/openqasm.ex:175-186` — `has_conditionals?` could be guarded function head
- `lib/qx/export/openqasm.ex:233` — credo disable on `instruction_to_qasm/2`
