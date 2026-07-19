# Test Review: feat/docs-sweep (Qx)

## Summary
Mechanical doc/spec sweep across lib/qx.ex, operations.ex, quantum_circuit.ex, draw.ex, math.ex,
state_init.ex, export/openqasm.ex, patterns.ex, simulation.ex, simulation_result.ex, step.ex.
No test files touched; confirmed no runtime-behavior change requiring new tests.

## Iron Law Violations
None.

## Issues Found

### Critical
None.

### Warnings
None. The `float()` -> `number()` @spec widening (operations.ex rx/ry/rz/phase/u/cp/crx/cry/crz,
qx.ex facades, math.ex) is a static-type annotation only — Dialyzer/spec metadata, not enforced at
runtime — and does not change dispatch, pattern matches, or guards. Confirmed no corresponding
`is_float` guards or float-only clauses were altered in these functions. No test required.

### Suggestions
- None beyond the already-decided deferral of doctests for the newly added `## Returns`/`## Raises`
  prose (out of scope per plan decision — not re-raising here).

## Verification Notes
1. No test files in the changed-file list; grep of the diff surface shows only lib/ files touched.
2. Spot-checked `iex>` doctest examples added/touched in lib/qx.ex (create_circuit, cx, h, measure,
   get_state, etc.) and lib/qx/export/openqasm.ex (from_qasm, module-generation example) — these
   already exist and pass per the reported suite run (250 doctests / 1030 tests / 0 failures); no
   new `iex>` examples were introduced by this sweep that would be unaccounted for.
3. Doc-rot fix in lib/qx/export/openqasm.ex (plain indented, non-executing examples, not `iex>`):
   replaced `Qx.circuit`/`Qx.cnot` with `Qx.create_circuit`/`Qx.cx`. Verified both are real facade
   functions: `Qx.create_circuit/1` and `/2` are `defdelegate ... to: QuantumCircuit, as: :new`
   (lib/qx.ex lines 106, 131), and `Qx.cx/3` is `defdelegate cx(circuit, control_qubit,
   target_qubit), to: Operations` (lib/qx.ex line 262). The replacement names are correct.
4. No changed line alters guards, pattern matches, function clauses, or control flow — confirmed
   these are additive (@spec, @moduledoc, doc sections) or type-only (float->number) edits.

## Verdict
No BLOCKERs. No new tests required for this sweep. Doctest deferral decision is respected.
