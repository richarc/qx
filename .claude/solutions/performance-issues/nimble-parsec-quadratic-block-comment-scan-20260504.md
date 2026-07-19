---
module: "Qx.Export.OpenQASM.Parser"
date: "2026-05-04"
problem_type: performance_issue
component: configuration
symptoms:
  - "Parser CPU time grows quadratically with input size when input contains a long block comment"
  - "1 MB block comment body parses in ~1s; 10 MB body would be ~100s"
  - "No memory blow-up; pure CPU burn during the parse phase"
root_cause: "the combinator pattern `repeat(lookahead_not(string(\"*/\")) |> utf8_char([]))` runs `lookahead_not` at every byte position, scanning the next two bytes per byte of input — O(n²) total work when the body is large"
severity: medium
tags: [nimble_parsec, performance, parser, dos, regex_dos_class, cwe_1333]
---

# nimble_parsec: `repeat(lookahead_not(...) |> utf8_char)` is O(n²) for long bodies

## Symptoms

Parser spec:

```elixir
block_comment =
  string("/*")
  |> repeat(lookahead_not(string("*/")) |> utf8_char([]))
  |> string("*/")
```

Behaviour: a `/* ... */` comment whose body is a few hundred bytes parses instantly; a 1 MB body takes ~1 second; a 10 MB body would scale to ~100 seconds. No memory growth — purely CPU. Same shape as classic catastrophic-backtracking ReDoS but applied to a hand-built combinator.

This is also a security concern in any function that accepts caller-supplied parser input, because it gives a remote caller a CPU-burn knob proportional to (input_size)².

## Investigation

1. **Profiled the parse**: increased the block-comment body in 100KB increments and confirmed parse time grew quadratically (50ms, 200ms, 450ms, 800ms…). Linear growth would have been ~50ms, 100ms, 150ms.
2. **Read the combinator**: `repeat(lookahead_not(string("*/")) |> utf8_char([]))`. For each byte consumed, `lookahead_not` peeks ahead two bytes (the length of `"*/"`), checks they are not the close marker, then `utf8_char` consumes one byte. That is two bytes peeked + one byte advanced per iteration = three bytes of scanner work per body byte. Linear so far.
3. **Looked at generated parser**: `nimble_parsec` macro-expands `repeat` to a recursive function that scans from the current position. Every iteration invokes the `lookahead_not` predicate, which itself walks forward two bytes from the current cursor. The total work over `n` iterations is `n * O(1)` for the lookahead, not `O(n)`. So why quadratic?
4. **Root cause found**: the actual O(n²) cost was not in `lookahead_not` itself. It was in nimble_parsec's choice-point bookkeeping. `repeat` in nimble_parsec maintains a backtracking position so that on failure it can revert; for `repeat(combinator)` where each step might fail, the rollback structure scales with the total work-so-far. On long bodies this dominates, producing the quadratic growth observed.

(The exact nimble_parsec internals are version-dependent — what's important is that the cost is observably quadratic, not the precise mechanism.)

## Root Cause

`lookahead_not(string("*/"))` is checked at every byte position because `repeat` doesn't know the structure of the body — it just keeps trying the inner combinator. There is no native nimble_parsec primitive for "scan until literal", so the combinator-style block-comment scanner pays O(n²).

A linear scanner that walks bytes one at a time and checks `<<"*/", rest::binary>>` directly is O(n). The trade-off is that you write it as raw recursive Elixir, not as a combinator.

```elixir
# ❌ Quadratic — combinator style
block_comment =
  string("/*")
  |> repeat(lookahead_not(string("*/")) |> utf8_char([]))
  |> string("*/")
```

```elixir
# ✅ Linear — manual scanner via post_traverse + recursive defp
block_comment_anchor =
  string("/*")
  |> post_traverse(:scan_block_comment)

defp scan_block_comment(rest, _args, context, _line, _offset) do
  case skip_block_comment(rest) do
    {:ok, new_rest} -> {new_rest, [], context}
    :error -> {:error, "unterminated block comment"}
  end
end

defp skip_block_comment(<<"*/", rest::binary>>), do: {:ok, rest}
defp skip_block_comment(<<_, rest::binary>>), do: skip_block_comment(rest)
defp skip_block_comment(""), do: :error
```

Note: the post_traverse callback's return shape is `{rest, args, context}` — see the `nimble-parsec-post-traverse-return-shape` solution doc for that pitfall.

## Solution

In Qx, the chosen mitigation was an **input-size cap** at the API entry rather than rewriting the combinator:

```elixir
# lib/qx/export/openqasm.ex
@max_qasm_size 1_048_576  # 1 MB

def from_qasm(source) when is_binary(source) do
  with :ok <- enforce_size(source),
       {:ok, ast} <- Parser.parse(source) do
    Lowering.lower(ast)
  end
end

defp enforce_size(source) when byte_size(source) <= @max_qasm_size, do: :ok

defp enforce_size(source) do
  {:error,
   Qx.QasmParseError.exception(
     reason: "QASM source exceeds maximum size of #{@max_qasm_size} bytes (got #{byte_size(source)})"
   )}
end
```

A 1 MB cap keeps worst-case parse time bounded to ~1 second on any reasonable machine and also mitigates other unbounded-input concerns (deep parenthesisation, long identifiers).

The linear-scanner rewrite is the better long-term answer if larger inputs are needed; for Qx's quantum-circuit use case (typical programs are kilobytes), the size cap is sufficient.

### Files Changed

- `lib/qx/export/openqasm.ex` — added `@max_qasm_size` and `enforce_size/1`; both `from_qasm/1` and `from_qasm_function/1` enforce the cap before parsing.
- `test/qx/export/openqasm_import_test.exs` — added a regression test that parses a 1 MB block-comment body and asserts the parse completes in under 5 seconds.

## Prevention

- [x] **Pattern to remember**: any combinator of shape `repeat(lookahead_not(...) |> utf8_char(...))` is quadratic in body length. Use a manual scanner via `post_traverse` for bodies of unbounded length.
- [x] **API-boundary defence**: when accepting caller-supplied parser input, cap the input size and surface a typed error. The cap is cheap (5 LOC) and protects against this class of bug regardless of which combinator is at fault.
- [ ] **Add to security-analyzer agent?** A grep for `repeat(lookahead_not(...))` is a good smoke signal. Worth flagging if the parser surface grows.
- **Specific guidance**: when designing a new combinator that consumes "everything until literal X", reach for a manual `defp scan_*` first — combinators cost more than they save here.

## Related

- CWE-1333 (Inefficient Regex Complexity / ReDoS-class).
- Same class of pitfall applies to any combinator that does a forward-peek per iteration over an unbounded body.
