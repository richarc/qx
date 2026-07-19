# Iron Law Judge Report — `fix/iron-law-7-sweep`

**Branch:** `fix/iron-law-7-sweep`
**Date:** 2026-06-24
**Scope:** Iron Law #7 typed-error sweep (new `Qx.RegisterError`, `Qx.BasisError`, plus
format-option and SVG-circuit retyping). Cross-checked against all Qx-tailored Iron Laws.

---

## Summary

- Files scanned: 34 `lib/**/*.ex`
- Iron Laws checked: 7 of 8 Qx-tailored laws (Nx kernel laws #3–5, #8 are N/A — no `defn` touched)
- Violations found: **2** (0 BLOCKER, 1 SHOULD-FIX, 1 NICE-TO-HAVE)

---

## Iron Law #7 — Typed errors across the public boundary

### Verdict: PASS with one SHOULD-FIX doc residue

**No raw `raise ArgumentError`** anywhere in `lib/`. `grep -rn "raise ArgumentError" lib/` → zero matches.

**No live `FunctionClauseError` raises.** The five `FunctionClauseError` hits are all `@doc` strings or inline code comments:

| File | Line | Kind |
|------|------|------|
| `lib/qx/quantum_circuit.ex` | 53 | Code comment explaining what the old behaviour *was* |
| `lib/qx/export/openqasm/codegen.ex` | 219 | Code comment explaining why the typed raise is here |
| `lib/qx.ex` | 79 | `@doc` `## Raises` entry on `create_circuit/2` |
| `lib/qx.ex` | 100 | `@doc` `## Raises` entry on `create_circuit/1` |
| `lib/qx/gates.ex` | 404, 451 | `@doc` `## Raises` entries on internal `Gates.swap/3` and `Gates.iswap/3` |

All five are documentation artefacts, not live raise sites.

#### SHOULD-FIX — Stale `@doc` on `Qx.create_circuit/1` and `Qx.create_circuit/2`

- **Files:** `lib/qx.ex:79`, `lib/qx.ex:100`
- **Code:**
  ```
  * `FunctionClauseError` - If `num_qubits <= 0` or `num_classical_bits < 0` (guard-only; …)
  ```
- **Confidence:** DEFINITE — `Qx.QuantumCircuit.new/2` now calls `validate_num_qubits!` before the guard runs, so the actual exception raised at `num_qubits <= 0` is `Qx.QubitCountError`, not `FunctionClauseError`. The doc is factually wrong for callers on this branch.
- **Fix:** Replace the `FunctionClauseError` bullet with `Qx.QubitCountError` in both `create_circuit` `@doc` blocks. The comment on `quantum_circuit.ex:53` is accurate and explanatory — leave it.

#### NICE-TO-HAVE — `Qx.Gates` doc cites `FunctionClauseError` on internal functions

- **Files:** `lib/qx/gates.ex:404`, `lib/qx/gates.ex:451`
- **Code:** `@doc ## Raises: FunctionClauseError - If qubit indices are out of range or equal`
- **Confidence:** REVIEW — `Qx.Gates` is `@moduledoc false`; these functions are not public API. The claim is technically accurate (they do fire `FunctionClauseError` from a guard if called directly with bad args), and they are never called by external callers. No Iron Law #7 obligation to type-wrap internal gate matrix builders. Flag for future housekeeping only.
- **Fix:** Optional. Either document the expected typed path via caller validation, or add `@doc false` per-function to suppress ExDoc noise.

---

## Iron Law #6 — SemVer / breaking change

### Verdict: PASS (pre-1.0 minor — consistent precedent)

**CHANGELOG `[Unreleased]` `### Changed` entry:** Present and detailed. The sweep is documented under the `### Changed` heading (not under `### BREAKING` — see below).

**Missing `### BREAKING` sub-section for this sweep.** The 0.8.0 entry correctly used `### BREAKING` for the first typed-error wave. This sweep changes the observable exception type on further public surfaces (`Qx.Register.new/1`, `Qx.Register.from_basis_states/1`, `Qx.Qubit.from_basis/1`, `Qx.Draw.*` option paths, `Qx.Draw.Tables.render/2`, `Qx.Export.OpenQASM.to_qasm/2`, `Qx.Draw.SVG.Circuit.render/1`). These are observable breaking changes for callers who rescue `ArgumentError` or `FunctionClauseError`.

- **Confidence:** LIKELY — whether a CHANGELOG `### BREAKING` section is required is a documentation convention, not a code correctness issue.
- **Assessment:** Pre-1.0 conventions vary; the project has used `### BREAKING` in CHANGELOG 0.8.0 for the first typed-error wave and appended `(plan: iron-law-7-followon)` items in `### Changed`. Consistency with the 0.8.0 pattern would mean promoting this sweep's changed-exception-types items into a `### BREAKING` block. As a pre-1.0 patch/minor there is no SemVer *obligation* to bump the major. The two predecessors (0.7→0.8, the earlier followon) did the same — patch-level typed-error sweep under `### Changed`. **This is the correct call given the trajectory**, but a `### BREAKING` section in CHANGELOG would make migration clearer for downstream consumers.
- **Fix (NICE-TO-HAVE):** Move the "Retyped surfaces — code rescuing the old `ArgumentError` / `FunctionClauseError` must be updated" bullet into a `### BREAKING` block in `[Unreleased]` for parity with the 0.8.0 precedent.

**Version bump:** `mix.exs` still shows `"0.8.0"`. Correct — this change is staged in `[Unreleased]` pending the next release. No action required.

---

## Iron Law #1 — No `String.to_atom/1` on caller-supplied strings

### Verdict: PASS

`grep -rn "String.to_atom(" lib/` → zero matches. Confirmed.

---

## Iron Law #2 — No process without runtime reason

### Verdict: PASS

No new `GenServer`, `Agent`, or `Task` modules introduced. Qx remains a pure library.

---

## Nx Laws (#3, #4, #5, #8) — N/A

No `defn` or `lib/qx/calc*.ex` changes in this branch. Not applicable.

---

## Test coverage (typed_errors_sweep_test.exs)

The new test file covers:
- `Qx.RegisterError` — all three reason constructors (`:empty`, `{:invalid_qubit, _}`, `{:invalid_input, _}`) plus the binary passthrough.
- `Qx.BasisError` — numeric and binary values.
- `Qx.Register.from_basis_states/1` — empty and non-binary rejection.
- `Qx.Qubit.from_basis/1` — OOR basis rejection.
- `Qx.Draw.Tables.render/2` — invalid input and unsupported format.
- `Qx.Draw.plot/2`, `plot_counts/2` — unsupported format.
- `Qx.Draw.SVG.Circuit.render/1` — `QubitCountError`, `GateError`, `QubitIndexError` (gate qubit + measurement qubit), `ClassicalBitError`.

**No gaps spotted** against the CHANGELOG's stated retyped surfaces. The register two-qubit distinctness gates (`cx`, `cz`, `cy`, `ccx`, `swap`, `iswap`, `cswap`) and `Qx.Export.OpenQASM.to_qasm/2` `:version` path are not explicitly tested in this file, but were covered in prior test suites (pre-existing tests). Not a blocker.

---

## Verdict

**PASS** — no BLOCKERs. One SHOULD-FIX (stale `@doc ## Raises` on `Qx.create_circuit/1` and `/2`) and two NICE-TO-HAVEs (internal `Qx.Gates` doc, CHANGELOG `### BREAKING` consistency). Safe to merge after fixing the stale `@doc` entries.
