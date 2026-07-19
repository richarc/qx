# Code Review: feat/qasm-facade-tdg

## Summary
- **Status**: ⚠️ Changes Requested
- **Issues Found**: 3 (0 critical, 1 warning, 2 suggestions)

## Warnings

1. **`lib/qx/export/openqasm.ex:45-51`** — Stale `@moduledoc` now contradicts the code.
   The "Supported gate set on import" section still lists `tdg` under
   *Decompositions* (`tdg → phase(-π/4)`) and omits it from *Direct mappings*,
   but `lib/qx/export/openqasm/lowering.ex` moved `"tdg" => {:tdg, 1, 0}`
   into `@stdgate_table` (native direct mapping) and removed it from
   `@decomposable_gates`. The CHANGELOG correctly documents this as a
   "Changed" entry, but the module doc that `from_qasm/1`'s `@doc` explicitly
   points readers to (`"See the module doc for the supported gate set,
   decompositions, …"`) was not updated, so it now actively misleads anyone
   reading it about round-trip behavior for `tdg`.
   ```elixir
   # Current (lib/qx/export/openqasm.ex:47-51)
   Direct mappings: `h, x, y, z, s, sdg, t, rx, ry, rz, p, phase, u, u3,
   cx, CX, cz, swap, iswap, cp, cphase, ccx, cswap`.

   Decompositions: `tdg → phase(-π/4)`, `sx → u(π/2, -π/2, π/2)`,
   `u1(λ) → phase(λ)`, `u2(φ, λ) → u(π/2, φ, λ)`. `id` is dropped.

   # Suggested
   Direct mappings: `h, x, y, z, s, sdg, t, tdg, rx, ry, rz, p, phase, u, u3,
   cx, CX, cz, swap, iswap, cp, cphase, ccx, cswap`.

   Decompositions: `sx → u(π/2, -π/2, π/2)`, `u1(λ) → phase(λ)`,
   `u2(φ, λ) → u(π/2, φ, λ)`. `id` is dropped.
   ```

## Suggestions

1. **`lib/qx.ex:594-613` (`Qx.tdg/2`)** — Every sibling gate facade delegate
   (`h`, `x`, `y`, `z`, `s`, `sdg`, `t`) documents a `## Parameters` section
   before `## Returns`; `tdg`'s `@doc` omits it, jumping straight from the
   one-line summary to `## Returns`. Minor doc-consistency gap, easy fix:
   add the standard
   ```elixir
   ## Parameters
     * `circuit` - Quantum circuit
     * `qubit` - Target qubit index
   ```
   block matching `t/2` immediately above it.

2. **`lib/qx/simulation.ex:503` / `lib/qx/export/openqasm.ex:267`** —
   The two new `credo:disable-for-next-line
   Credo.Check.Refactor.CyclomaticComplexity` comments are a reasonable,
   precedented stopgap (matches the existing `instruction_to_qasm`
   pattern), but both dispatch cases are pure `atom → 0-arg gate matrix`
   lookups with no branching logic — a genuine candidate for a
   compile-time map (`%{h: &Gates.hadamard/0, x: &Gates.pauli_x/0, …}`)
   that replaces the `case` entirely instead of accumulating more
   disable-comments each time a no-param single-qubit gate is added.
   Not a blocker for this PR (consistent with existing precedent), but
   worth a scratchpad/ROADMAP note as tech debt since the same
   Cyclomatic Complexity work-around will recur for the next gate
   (already now at 10/10 threshold in both spots).

## Verified Correct (no bug found)

- `Qx.Gates.t_dagger/0` matrix (`e^(-iπ/4)` on |1⟩) is the correct adjoint
  of `t_gate/0`; `gates_test.exs` asserts both the matrix elements and
  `T · T† = I`.
- `Qx.Simulation.apply_single_qubit_op/5` dispatches `:tdg` to
  `Gates.t_dagger()` — present, and covered by an *execution*-path test
  (`operations_test.exs` "tdg execution (Iron Law #9 …)"), not just
  construction/export, satisfying the dispatch-completeness Iron Law.
  `steps/2` dispatch is exercised too.
- OpenQASM round-trip is genuinely correct: `to_qasm` emits `tdg q[N];`
  directly (`single_qubit_gate_to_qasm("tdg", …)`), and `lowering.ex`'s
  `@stdgate_table` maps it straight back to `{:tdg, [q], []}` — no
  double-decomposition or lossy phase-gate round-trip. Tested in
  `openqasm_test.exs` and `openqasm/lowering_test.exs` (which also has an
  explicit code comment flagging the moved decomposition — the test file
  is up to date; only the moduledoc lagged).
  `Qx.Draw`'s `gate_label_and_color/2` correctly renders `"T†"` with a
  test asserting the SVG box.
- `doctest Qx.Operations` was newly wired up in this branch (previously
  absent per house style rule), and the new `tdg` doctest is not in the
  `:except` skip list — it actually executes.
- Facade delegates (`Qx.tdg/2`, `Qx.to_qasm/2`, `Qx.from_qasm/1`,
  `Qx.from_qasm!/1`) are thin one-liners with `@spec` + `@doc`, matching
  the module's established `defdelegate` idiom.
