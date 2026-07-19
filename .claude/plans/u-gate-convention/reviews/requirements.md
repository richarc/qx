## Requirements Coverage (from Plan .claude/plans/u-gate-convention/plan.md)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | `Qx.u/5` doc cites the exact convention with a named reference | MET | `lib/qx.ex:471-474` — "Follows the **OpenQASM 3.0** specification built-in `U` gate / Qiskit `qiskit.circuit.library.UGate` convention." |
| 2 | Tests verify `U(π,0,π)==X`, `U(π/2,0,π)==H`, `U(0,0,0)==I` up to global phase | MET | `test/qx/u_gate_convention_test.exs:27-49` — all three assertions present with `assert_unitary_equal_up_to_phase/3` |
| 3 | Parameter names in `@spec`/`@doc` match documented convention (θ,φ,λ order) | MET | `lib/qx.ex:501` `@spec u(circuit(), non_neg_integer(), number(), number(), number())` + `defdelegate u(circuit, qubit, theta, phi, lambda)` — order is circuit, qubit, theta, phi, lambda; doc params updated with Greek-letter annotations at `lib/qx.ex:479-483` |
| 4 | Same convention + decomposition paragraph in ALL THREE docstrings (gates.ex u/3, operations.ex u/5, qx.ex u/5) | MET | Identical "Follows the **OpenQASM 3.0**…" + "Decomposition identity…" paragraph in `lib/qx/gates.ex:258-265`, `lib/qx/operations.ex:250-259`, `lib/qx.ex:469-476` |
| 5 | No invented URLs — citation by spec/library NAME only | MET | All three files use only "OpenQASM 3.0 specification built-in `U` gate" and "Qiskit `qiskit.circuit.library.UGate`" — no URLs present |
| 6 | `U(0,0,0)=I` special case added | MET | `lib/qx/gates.ex:282` and `lib/qx/operations.ex:273` — `- U(0, 0, 0) = I gate` added to Special cases lists |
| 7 | New test file `test/qx/u_gate_convention_test.exs` created | MET | File exists at `test/qx/u_gate_convention_test.exs` with 123 lines |
| 8 | Existing `test/qx/u_gate_test.exs` NOT modified | MET | `git diff main -- test/qx/u_gate_test.exs` produces no output |
| 9 | `@spec` at lib/qx.ex (~494) order is `circuit, qubit, theta, phi, lambda` | MET | `lib/qx.ex:501` — `@spec u(circuit(), non_neg_integer(), number(), number(), number()) :: circuit()` with `defdelegate u(circuit, qubit, theta, phi, lambda, ...)` |

**Summary**: 9 MET · 0 PARTIAL · 0 UNMET · 0 UNCLEAR

**Verdict: All criteria MET.**
