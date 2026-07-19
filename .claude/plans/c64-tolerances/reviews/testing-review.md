# Test Review: fix/c64-tolerances tolerance widening

## Summary

All three files are correct. The tolerance widening is sound, the rationale comments are accurate, and no regression coverage is lost at the new bounds.

## Iron Law Violations

None.

## Issues Found

### Critical

None.

### Warnings

None.

### Suggestions

- `round_trip_test.exs:33` — `states_equal?/2` uses `max(abs(a - b)) < @tolerance` (strict less-than). For a circuit whose statevector amplitude lands within `[1.0e-6, 2.0e-6)` of the reference — possible for deeply composed parametric circuits — the test would spuriously fail even though the state is distinguishable. Consider `<=` instead of `<`. Low risk at current fixture complexity; flag if circuit depth grows.

## Per-file analysis

### `cswap_iswap_matrix_test.exs` (C5: 1.0e-12 → 1.0e-6)

PASS. Every non-trivial entry in CSWAP and iSWAP is exactly 0, 1, or ±i. A control-qubit swap error moves an entire row/column of ±1 entries to the wrong position — error magnitude O(1), not O(ε). A −i vs +i sign error produces imag difference of 2.0. Both failure modes are O(1) away from the 1.0e-6 threshold. The widening does not reduce detection sensitivity.

### `round_trip_test.exs` (C6: 1.0e-10 → 1.0e-6)

PASS. The round-trip comparison is between two independent simulation runs of the same logical circuit, not between the original and a slightly-degraded version. Any genuine export/import error (dropped gate, wrong angle, wrong qubit mapping) will produce amplitude differences of O(0.1)–O(1), not O(ε). The 1.0e-6 threshold has ~7 decades of headroom above any genuine bug. The QFT3 and mixed-parametric fixtures involve irrational angles whose float32 accumulation error is bounded well below 1.0e-6 when both sides run the same gate sequence.

### `u_gate_convention_test.exs` (stays 1.0e-6, comment added)

PASS. `assert_unitary_equal_up_to_phase` divides by the reference entry to extract the global phase, then checks each entry against `ratio * b`. The phase extraction itself is a single Complex.divide (one float32 op, rounding ~ε). The subsequent per-entry comparison does one Complex.multiply + subtract. Worst-case cumulative float32 error for these two ops on `:c64` is ~3ε ≈ 3.6e-7, leaving ~2.8× headroom before the 1.0e-6 threshold. The rationale comment ("float32 error can reach ~5e-7") is consistent with this bound. The parametric angles {0.7, 1.1, 0.3}, {π/3, π/5, −π/4}, {2.0, 0.0, 1.0} are all irrational in float32; any convention swap (e.g. RZ(λ)·RY(θ)·RZ(φ) vs RZ(φ)·RY(θ)·RZ(λ)) produces off-diagonal amplitude differences of O(sin(|λ−φ|)), far above threshold.
