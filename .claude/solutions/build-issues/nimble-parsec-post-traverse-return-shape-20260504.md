---
module: "Qx.Export.OpenQASM.Parser"
date: "2026-05-04"
problem_type: build_error
component: configuration
symptoms:
  - "** (CaseClauseError) no case clause matching: {[{:openqasm_version, \"3.0\", [line: 1]}], \"\\nqubit[2] q;\\n\", %{}}"
  - "Parser entry point function (e.g. `program/1`) crashes with CaseClauseError instead of returning a documented {:ok, ...} | {:error, ...} 6-tuple"
  - "Parsing succeeds for the first matched production then fails with a 3-tuple at the boundary"
root_cause: "post_traverse callbacks must return {rest, args, context} with rest first; if you write {args, rest, context} the wrong shape propagates as the parser's overall result and fails the case clause inside the generated dispatch"
severity: high
tags: [nimble_parsec, parser, combinator, post_traverse, callback_signature]
---

# nimble_parsec: post_traverse callback must return `{rest, args, context}` (rest first)

## Symptoms

Building a hand-written grammar with `defparsec` and one or more `post_traverse(:tag_*)` callbacks. Parsing throws:

```
** (CaseClauseError) no case clause matching:
   {[{:openqasm_version, "3.0", [line: 1]}], "\nqubit[2] q;\n", %{}}
    (qx 0.5.2) Qx.Export.OpenQASM.Parser.program__656/6
    (qx 0.5.2) lib/qx/export/openqasm/parser.ex:237: Qx.Export.OpenQASM.Parser.parse/1
```

The 3-tuple in the error is `{args_list, rest_string, context_map}` — your post_traverse return value, leaking out of the generated parser and tripping a case clause that expected the standard 6-tuple `{:ok, results, rest, context, line_col, offset}` or `{:error, ...}`.

## Investigation

1. **Hypothesis**: `defparsec` was misconfigured or the combinator chain incomplete. Inspected the parser entry — `defparsec(:program, ...)` was correct.
2. **Hypothesis**: The `case` in `parse/1` was matching the wrong shape. Counted: pattern was `{:ok, statements, "", _ctx, _, _}` and `{:error, reason, rest, _ctx, _, _}` — six elements as documented. The value being matched was three elements.
3. **Hypothesis**: One of the post_traverse callbacks was returning a malformed tuple. Re-read the nimble_parsec docs and noticed the callback contract states: *"The function should return `{rest, args, context}` or `{:error, reason}`."* The implementation had `{args, rest, context}`.
4. **Root cause found**: every `tag_*` callback (`tag_openqasm/5`, `tag_include/5`, `tag_qreg/5`, `tag_creg/5`) had the wrong return-tuple order. nimble_parsec's generated dispatch trusted the shape implicitly; the wrong shape bypassed the `:ok`/`:error` wrapping and surfaced as the parser's overall return value.

## Root Cause

`post_traverse(combinator, callback)` callbacks have a strict signature:

```elixir
@spec callback(rest :: binary, args :: [term], context :: map, line :: pos_integer, offset :: non_neg_integer) ::
        {rest, args, context} | {:error, reason :: String.t()}
```

`rest` MUST be first in the return tuple — even though it is also first in the argument list, it is easy to assume the return is "results-then-rest" because that's how most "transform" functions feel. nimble_parsec does NOT validate the shape; it splats your tuple into its internal state and fails much later, deep inside the generated parser code, with a `CaseClauseError` that does not point at your callback.

```elixir
# ❌ WRONG — args first
defp tag_openqasm(rest, [version], context, {line, _col}, _offset) do
  {[{:openqasm_version, version, line: line}], rest, context}
end
```

The compile-time generated code accepts this without complaint (it just reads three fields out of a 3-tuple), but the runtime trace ends with the original `args_list, rest_string, context_map` flowing into a six-element case clause that does not match.

## Solution

`rest` first in the return tuple:

```elixir
# ✅ CORRECT — rest first
defp tag_openqasm(rest, [version], context, {line, _col}, _offset) do
  {rest, [{:openqasm_version, version, line: line}], context}
end
```

If you do not need to modify rest or context (the common case), it is fine to thread them through unchanged. The only thing that matters is the order.

### Files Changed

- `lib/qx/export/openqasm/parser.ex` — six post_traverse callbacks (`tag_openqasm`, `tag_include`, `tag_qreg`, `tag_legacy_qreg`, `tag_creg`, `tag_legacy_creg`, plus later additions for gate calls, measurements, conditionals, gate definitions). All flipped from `{result, rest, context}` to `{rest, result, context}`.

## Prevention

- [x] **Pattern to remember**: nimble_parsec callback returns put `rest` first. Same as the argument order `(rest, args, context, line, offset)`.
- [x] **Detection**: if `defparsec`-generated code throws a `CaseClauseError` whose value is a 3-tuple, the first thing to check is every `post_traverse` and `pre_traverse` callback's return shape.
- [ ] **Add to elixir-reviewer agent?** A grep for `post_traverse` + return-tuple shape inspection would catch this. Worth flagging if grammars are touched again.
- **Specific guidance**: when adding a new `post_traverse` callback, copy an existing one from the same module rather than writing the return tuple by hand — there is no compile-time check.

## Related

- nimble_parsec docs: `NimbleParsec.post_traverse/3` — search for "should return" in the function doc; the `{rest, args, context}` shape is one line in a long doc and easy to miss.
- Same trap applies to `pre_traverse/3` (also `(rest, args, context, line, offset) → {rest, args, context}`).
