# Hex Dependency Research: bell_pair/ghz circuit builders

## Conclusion

**No new hex dependency required.** `Qx.bell_pair/4` and `Qx.ghz/2` are pure
composition of existing internal primitives (`Qx.Operations.h/2-3`,
`Qx.Operations.cx/4`, `Qx.Operations.x/3`, and `Qx.Patterns.cx_chain/3`)
appending gate-instruction structs to an in-memory `Qx.QuantumCircuit`. There
is no parsing, serialization, I/O, or new numerical algorithm involved — the
existing deps already in `mix.exs` (`nx`, `complex`, `nimble_parsec`, `req`,
`jason`, `vega_lite`/`kino` optional) are either unrelated to this code path
or already cover everything the simulator needs. Per Qx's rule that "a hard
dependency must be exercised on the core path," none of the existing deps
(let alone a new one) would be touched by this feature beyond struct/list
manipulation already handled by the stdlib (`Enum`, pattern matching,
struct updates). No candidate dependency offers any benefit here; adding one
would be pure overengineering.

## No Library Needed

- Struct field updates and list appends via Elixir stdlib (`Enum`, `++`,
  struct update syntax) are sufficient to implement `bell_pair/4` and
  `ghz/2` on top of existing `Qx.Operations` and `Qx.Patterns` functions.
