# Code Review: openqasm-hardening

## Summary

- **Status**: Approved with suggestions
- **Issues Found**: 2 (both SUGGESTION severity)

---

## Suggestions

### 1. `scan_paren_depth/2` — `if` inside clause body instead of guard-split function heads

**Location**: `lib/qx/export/openqasm.ex`, `scan_paren_depth/2`, the `<<?(,...>>` clause.

The open-paren clause rebinds `depth = depth + 1` then branches with `if`. Since `@max_paren_depth` is a compile-time constant, it's valid in a guard. The idiomatic Elixir pattern is two function heads:

```elixir
# Current — rebind + if inside body
defp scan_paren_depth(<<?(, rest::binary>>, depth) do
  depth = depth + 1
  if depth > @max_paren_depth do
    {:error, Qx.QasmParseError.exception(...)}
  else
    scan_paren_depth(rest, depth)
  end
end

# Suggested — guard-split heads, no rebinding
defp scan_paren_depth(<<?(, rest::binary>>, depth) when depth + 1 > @max_paren_depth,
  do: {:error, Qx.QasmParseError.exception(reason: "expression nesting too deep (max #{@max_paren_depth} parentheses)")}

defp scan_paren_depth(<<?(, rest::binary>>, depth),
  do: scan_paren_depth(rest, depth + 1)
```

Clause ordering (empty → open-paren → close-paren → catch-all) and tail-recursion are both correct. The early-exit from the open-paren clause is clean — breaks the recursion by returning directly. The `max(depth - 1, 0)` on close-paren is intentional: this scan is a ceiling guard, not a balance validator. That design is fine.

---

### 2. `emit_body/3` — `acc ++ [line]` is O(n²) list construction

**Location**: `lib/qx/export/openqasm/codegen.ex`, `emit_body/3`.

```elixir
# Current
{:cont, {:ok, acc ++ [line]}}

# Suggested — prepend, then reverse on exit
```

The idiomatic fix is `{:cont, {:ok, [line | acc]}}` with a final `Enum.reverse/1` on the accumulated list before returning it. Gate bodies are tiny in practice (single-digit line counts), so this has zero performance impact here. It's still non-idiomatic.

---

## Informational (no action needed)

**`generated_module_name/2` — string vs atom for module name**: correct. `Module.concat` produces an atom; you need a string to embed in generated Elixir source. The string gets interpreted at `Code.compile_string/1` time. `binary_part(0, 8)` on the SHA256 Base16 output is safe — SHA256 encodes to 64 hex chars, always.

**`#{"Qx.Generated.<Name>_<hash>"}` in `@doc`/`@moduledoc`**: the interpolation trick to suppress ExDoc autolinking is reasonable and well-understood. No issue.

**Generated source indentation**: structurally valid. `codegen_test.exs:86` compiles the output via `Code.compile_string/1` and asserts the module atom matches, giving live proof.

**`@spec generate(tuple()) :: {:ok, map()} | {:error, Exception.t()}`**: `map()` is accurate for the new map shape. `tuple()` is broad but this module is `@moduledoc false`. Fine.

**No dead code**: `def_source` is used correctly in both the `generated_module_name/2` call and the wrapping `source` construction.
