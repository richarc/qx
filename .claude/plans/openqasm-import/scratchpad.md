# Scratchpad — OpenQASM Import

## Decisions (locked)

- **Scope**: round-trip + IBM stdgates (user-confirmed)
- **Function form**: generate Elixir source string (user-confirmed)
- **Parser**: nimble_parsec ~> 1.4 (user-confirmed)
- **Single-register only** in v1; multi-register raises with line of second decl
- **No else** in v1 conditionals; reject with refactor hint
- **No gate modifiers** (`inv`, `pow`, `ctrl`, `negctrl`) in v1 even though spec allows them in `gate` bodies
- **`reset`, `delay`, `box`** rejected in v1 even though `reset` is borderline simple — defer until a real use case arrives
- **`measure q[j];` (discarded)** rejected — Qx requires a target classical bit
- **Codegen function signature**: `def name(circuit, param1, param2, qubit_a, qubit_b)` — circuit first, then params, then qubits, in declaration order
- **Decompositions live in lowering.ex** (not a separate "decomp" module) — small lookup table returning `[instruction]`
- **Whitelist gate-name lookup** with literal map, never `String.to_atom`

## Dead ends explored

- **Auto-skipping whitespace via nimble_parsec config**: not supported. Standard idiom is `optional_ws` combinator threaded through productions. Documented in research report.
- **Reusing yecc/leex**: rejected — generates Erlang code, awkward to integrate with Elixir AST construction
- **Calling Python `openqasm3` reference parser via Port**: rejected — Hex packages should not require Python runtime

## Open questions (deferred)

- **Should we accept `iswap` even though it's not in standard stdgates.inc?** Qx supports it natively. **Decision: yes, accept** — Qx exports it via `to_qasm`, so round-trip requires accepting it on import. Document as a Qx extension.
- **Multi-register support** — significant `QuantumCircuit` redesign. File as bd issue if needed post-launch.
- **`else` branch support** — needs `:c_if_else` instruction or `:c_if` with optional else field. Follow-up bd issue.
- **Custom `include` files beyond `stdgates.inc`** — currently treat all includes as no-op. Real programs sometimes include `qelib1.inc` (QASM 2 lib) or custom. **Decision for v1**: accept any `include "X";` as no-op; trust caller that referenced gates are stdgate names. If we encounter an unknown gate name during lowering, the unsupported-gate error still fires.

## Patterns to study while implementing

- **Makeup lexers** for the nimble_parsec structure on C-like syntax
- **ex_cldr format-string parsers** for `label/3` discipline and error formatting
- **Existing `Qx.Export.OpenQASM.to_qasm/1`** for the symmetric instruction tuple format

## Things NOT to do

- Don't introduce a GenServer or Agent for parser state (Iron Law 2)
- Don't `String.to_atom` any user-derived strings (Iron Law 1)
- Don't break `to_qasm/1`'s existing API (no breaking change in 0.6.0)
- Don't reach into the portal's domain — Qx exposes pure functions; portal handles storage
