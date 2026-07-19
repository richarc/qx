# Iron Law Review v2 — calcfast-norm-drift-guard (Round 2)

Branch: `feat/calcfast-norm-drift-guard`  
Repo: `/Users/richarc/Development/qxquantum/qx`  
Reviewer: iron-law-judge (automated)  
Date: 2026-05-16

## Summary

- Files scanned: `lib/qx/simulation.ex`, `lib/qx/validation.ex`, `lib/qx/errors.ex`, `mix.exs`, `CHANGELOG.md`
- Iron Laws checked: all 7 applicable Qx laws (#1, #2, Nx #3, Nx #4, Nx #5, #6, #7)
- Violations found: **0** (0 critical, 0 high, 0 medium)

Round 1 PASS verdict **unchanged**. The W1 refactor introduced no new violations.

---

## Per-Law Verdicts

### Law #1 — No `String.to_atom/1` on user input
**COMPLIANT.** `Grep` finds no `String.to_atom(` in `lib/`. No change from W1.

### Law #2 — No process without runtime reason
**COMPLIANT.** Pure library; no GenServer/Agent/Task. No change from W1.

### Law Nx #3 — Prefer reshape/contraction over gather/mask
**COMPLIANT.** `apply_gate_step/5` delegates to `Calc.apply_single_qubit_gate` / `Calc.apply_cnot` / `Nx.dot` — same Calc kernel paths as before. W1 only restructured the counter threading; it did not touch `Calc.*` internals.

### Law Nx #4 — `defn` correct on `Nx.BinaryBackend`
**COMPLIANT.** No new `defn` functions introduced. `Calc.*` kernels are unchanged.

### Law Nx #5 — No host-side loops over 2^n amplitudes; `assert_norm/1` host-sync
**COMPLIANT — EXCEPTION-JUSTIFIED (unchanged from Round 1).**

`assert_norm/1` (simulation.ex:310–313) still calls `Validation.validate_normalized!/2`,
which calls `Nx.to_number` (a host sync). This is now invoked per gate in
`apply_gate_step/5` — including c_if sub-gates — rather than per timeline item.

Critical verification: `@assert_norm` is set via `Application.compile_env(:qx, :assert_norm, false)`.
- `config/config.exs` (default/prod): `false` → the `if @assert_norm` branch is a compile-time
  constant `false`; the entire body including `Validation.validate_normalized!/2` is dead code
  in `:prod`. Zero cost, zero host sync. The Beam compiler elides dead `if false` branches.
- `config/test.exs`: `true` → host sync is active per gate. This is intentional test overhead,
  acceptable for a test-only guard.

The EXCEPTION-JUSTIFIED verdict from Round 1 still applies. The W1 refactor that moved
`assert_norm/1` into `apply_gate_step/5` does not change the prod-dead-code guarantee —
it only changes when the guard fires in `:test` (now per-gate including c_if sub-gates, which
is the correct and more thorough guard behaviour).

Note on `if false, do: ...` cost in `:prod`: Elixir compiles `@assert_norm` (a module attribute
with a compile-time constant value) such that `if false, do: expr` is optimized away by the
compiler. There is no per-gate branch evaluation cost in prod.

### Law #6 — Breaking changes require CHANGELOG + major-version bump
**COMPLIANT.** `mix.exs` version remains `"0.7.1"` (unchanged). `CHANGELOG.md` has an
`[Unreleased]` section documenting the renormalization feature as additive and non-breaking.
The `Qx.OptionError` addition is additive (new typed error, not replacing an existing one).
No public API removed or altered. No version bump required; none present.

### Law #7 — Typed `Qx.*Error` via `Qx.Validation`; no raw `FunctionClauseError` across API boundary
**COMPLIANT.** This is the key law to re-examine for the W1 refactor.

Trace: `run/2` → `resolve_renormalize/1` → `Validation.validate_renormalize!/1` → `to_renorm/1`

`validate_renormalize!/1` (validation.ex:329–336) has explicit heads for `false`, `true`,
positive integer, and a catch-all that raises `Qx.OptionError`. It returns only those three
values. Therefore `to_renorm/1` (simulation.ex:111–113) receives only `false | true | pos_integer`
— values it has explicit heads for. The catch-all-less `to_renorm/1` **cannot** raise
`FunctionClauseError` on user input because invalid input is rejected upstream by
`validate_renormalize!/1` before `to_renorm/1` is ever called.

`apply_gate_step/5` receives circuit instructions from `QuantumCircuit.get_instructions/1` —
internal, already-validated data structures, not raw user input. The `apply_instruction/3`
match-errors would be `FunctionClauseError` / `raise "Unsupported..."` but these are internal
engine invariants, not user-facing API misuse paths. This is acceptable: Law #7 concerns
the public API boundary (`Qx.*` public functions), not internal private helpers.

---

## Conclusion

**Verdict: PASS (no violations). Round 1 verdict confirmed for Round 2.**

The W1 refactor (shared 1-based gate counter via `apply_gate_step/5`; `execute_circuit/2`
as `{state, count}` reduce; `process_conditional/8` threading the counter) is structurally
sound and introduces no Iron Law violations. All prior COMPLIANT/EXCEPTION-JUSTIFIED verdicts
hold without change.
