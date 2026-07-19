# Iron Law Review — cswap-iswap-matrix-tests

**Files reviewed:**
- `lib/qx/gates.ex` (diff scope: `cswap/4` rewrite; `@doc` edits for `cswap/4` and `iswap/3`; one doctest line)
- `test/qx/cswap_iswap_matrix_test.exs` (new file)

---

## Law-by-Law Verdicts

### Law 1 — No `String.to_atom/1` on caller-supplied strings
**COMPLIANT.** No `String.to_atom/1` call anywhere in either file.

### Law 2 — No process without a runtime reason
**COMPLIANT.** Neither file starts a GenServer, Agent, or supervised Task. No process spawning of any kind.

### Law 3 — Prefer reshape + tensor contraction over gather/mask (Nx kernels)
**N/A.** `cswap/4` is a plain `def`, not a `defn`. No Nx gather/select/take patterns were introduced. Existing `Nx.put_slice` calls in the matrix builder are unchanged in structure from the sibling `iswap/3` pattern.

### Law 4 — `defn` must be correct on `Nx.BinaryBackend`
**N/A.** No `defn` functions in scope. The changed code is plain `def`.

### Law 5 — No host-side loops over 2ⁿ amplitudes; vectorise
**NOTED / ACCEPTED.** `cswap/4` uses `for i <- 0..(state_size - 1), reduce:` — a host-side loop over 2ⁿ basis states. This is the identical pattern used by the pre-existing `iswap/3`, `swap/2`, `controlled_gate/4`, and `toffoli/4` in the same file. These are matrix *builders* called at circuit-construction time, not simulation kernels on the hot path (simulation uses `Qx.CalcFast.apply_cswap`). The loop is an accepted convention for this file and was not introduced by this change. No new violation beyond the pre-existing pattern.

### Law 6 — Breaking public API changes require CHANGELOG + major-version bump
**COMPLIANT / N/A.** `Qx.Gates` is not in the protected API surface (`Qx`, `Qx.QuantumCircuit`, `Qx.Operations`, `Qx.Simulation`, `Qx.SimulationResult`, `Qx.Behaviours.*`). The `cswap/4` function signature is unchanged. Its only consuming callsite is its own doctest; simulation uses `CalcFast.apply_cswap` directly. No CHANGELOG entry is required.

### Law 7 — Public functions raise typed `Qx.*Error` on misuse
**COMPLIANT (no new divergence).** The rewritten `cswap/4` introduces no new `raise` path of any kind — it contains no guard, no validation, and no explicit error handling, matching the identical structure of `iswap/3` and `swap/2`. Any unvalidated-input concern pre-dates this change and is not a regression introduced here. The prompt scopes this law to *new* divergence only; none exists.

---

## Summary

- Files scanned: 2
- Iron Laws checked: 7 of 7 applicable Qx-tailored laws
- Violations found: **0** (0 critical, 0 high, 0 medium)

All laws either COMPLIANT or N/A for this focused change.
