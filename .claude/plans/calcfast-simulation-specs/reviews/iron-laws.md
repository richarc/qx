# Iron Law Violations Report

## Summary

- Files scanned: 2 (`lib/qx/calc_fast.ex`, `lib/qx/simulation.ex`)
- Iron Laws checked: 6 of 22 (Qx-applicable subset: #5, #6, #8 Nx laws; no LiveView/Ecto/Oban/Phoenix)
- Violations introduced by this diff: **0**
- Pre-existing conditions noted: 2 (informational, not introduced here)

---

## No Violations Introduced

This diff is 100% additive: `@spec` and `@typep` declarations only. Confirmed:

- No function body in `calc_fast.ex` or `simulation.ex` was modified.
- No new logic, error paths, signatures, tolerances, or kernel bodies were changed.
- `@spec` on `defn`/`defnp` is a compile-time attribute and does not alter kernel behaviour or JIT compilation. No Nx discipline concern.

---

## Pre-existing Conditions (NOT introduced by this diff)

### [Nx #5] Host-side loops over 2^n — PRE-EXISTING, not introduced here

- **File**: `lib/qx/simulation.ex:619-631` (`calculate_measurement_probability`) and `lib/qx/simulation.ex:647-659` (`collapse_to_measurement`)
- **Code**: `for i <- 0..(state_size - 1)` with `Nx.to_number(state[i])` inside each iteration
- **Confidence**: DEFINITE — these are host-side loops iterating over all 2^n basis states with per-element host sync
- **Status**: PRE-EXISTING. This diff added `@spec` lines to these functions only. The loops were present before this branch. They are not in a `defn` block (they are regular Elixir `defp` functions used only in the conditional/shot-by-shot measurement path).
- **Note for future work**: These loops are a known scalability ceiling for the conditional measurement path. As `num_qubits` grows, each shot's measurement collapse is O(2^n) on the host. This was a pre-existing design trade-off, not a regression from this change.

### [Nx #8] Tolerance at float width — PRE-EXISTING, unchanged

- **File**: `lib/qx/simulation.ex:37` — `@norm_tolerance 1.0e-6`
- **Confidence**: DEFINITE (check passes) — `1.0e-6` is at the feasibility floor for `:c64` (complex float32, ε≈1.2e-7). The inline comment on lines 29–37 documents this explicitly. No new tolerance was introduced by this diff.

---

## Iron Law #6 — Public API: Non-breaking, no CHANGELOG/bump required

`Qx.Simulation` is on the declared-public surface. The `@spec` additions to `run/2`, `get_state/2`, and `get_probabilities/2` are purely documentary: no signature changed, no behaviour changed, no error paths added or removed. This is additive documentation, not a breaking change. No CHANGELOG entry and no version bump are required.

`Qx.CalcFast` carries `@moduledoc false` and is explicitly marked internal. Its `@spec` additions carry no public-API obligation.

---

Checked 6 of 22 Iron Laws: **0 violations found**.
