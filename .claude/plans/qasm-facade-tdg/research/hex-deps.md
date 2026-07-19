# Hex Dependency Research: native `tdg` gate + `Qx` OpenQASM facade

## Verdict: NO NEW DEP

## Justification

Everything required already exists in-tree. (1) `Qx.Gates.t_dagger/0`
(lib/qx/gates.ex:153) already returns the correct T† matrix
(`[[1,0],[0,e^{-iπ/4}]]`) built purely from `Complex` (already a dep,
`{:complex, "~> 0.7"}`) and `Qx.Math.complex_matrix/1` — simulation dispatch
just needs a new `:tdg` clause added to whatever `case`/pattern-match already
routes `:s`/`:sdg`/`:t` to their gate matrices; no new math library needed.
(2) `Qx.Operations.t/2` and `Qx.Operations.sdg/2` (lib/qx/operations.ex:378,
398) are a two-line pattern — `QuantumCircuit.add_gate(circuit, :t, qubit)` —
that `Qx.Operations.tdg/2` trivially replicates as
`QuantumCircuit.add_gate(circuit, :tdg, qubit)`; this is struct/list
composition on the existing `QuantumCircuit` struct, no dependency involved.
(3) Drawing "T†" is a circuit-diagram label lookup, same string-formatting
mechanism already used for "S†"/other dagger gates. (4) OpenQASM round-trip:
`lib/qx/export/openqasm.ex` already parses `tdg` on import today, but only as
a *decomposition* into `phase(-π/4)` (module doc line 50: "Decompositions:
`tdg → phase(-π/4)`"); there is currently no native `{:tdg, qubits, []}` case
in `instruction_to_qasm/2` (the codegen switch at line ~268-350, alongside
`:s`/`:sdg`/`:t`) and no native-emit path. Adding one is exactly the same
`single_qubit_gate_to_qasm("tdg", qubits, params)` one-liner already used for
`:sdg`/`:t` — pure pattern-matching over strings already produced by
`nimble_parsec` (already a dep, `{:nimble_parsec, "~> 1.4"}`), which is the
parser library backing this whole module. (5) The `Qx` facade delegates
(`to_qasm/2`, `from_qasm/1`, `from_qasm!/1`) do not exist yet on `Qx` itself
(only on `Qx.Export.OpenQASM`), but are simple `defdelegate`/one-line
forwarding functions to functions that already exist — no library involved.

`mix.exs` deps (nx, complex, nimble_parsec, req, jason, vega_lite, kino, plus
dev/test-only tooling) already cover every piece of machinery this feature
touches: complex-matrix math, circuit struct manipulation, and QASM
parsing/codegen. No gap exists that a hex package would close; this is pure
struct/list/matrix composition over existing code, following the exact
`t`/`sdg` precedent already in the codebase.
