# nimble_parsec Research Summary

**Verdict: GO**

- v1.4.2, Jan 2025, Apache-2.0, maintained by José Valim / Dashbit
- Compile-time parser generation → zero runtime framework cost
- Sub-millisecond parse for ~200-line QASM (50–200 µs)
- Error tuple includes `{line, column}` and byte offset; combine with `label/3` for human messages
- No auto whitespace/comment skipping — define a reusable `optional_ws` combinator (~15 LOC) and thread it explicitly. Idiomatic and readable.
- Real-world precedent: Makeup (ExDoc lexers), ex_cldr (CLDR format strings)
- Alternatives ruled out: yecc/leex (impedance mismatch), abnf_parsec (wrong grammar dialect), neotoma (abandoned), hand-rolled (no positions/labels/composability for free)

## Required additions to mix.exs

```elixir
{:nimble_parsec, "~> 1.4"}
```

Runtime dep (not dev/test only) — generated parser is part of the library's compiled binary.
