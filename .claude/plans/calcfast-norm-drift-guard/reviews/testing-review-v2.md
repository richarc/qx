# Test Review v2: test/qx/simulation_renormalization_test.exs
Branch: feat/calcfast-norm-drift-guard — Round-2 (post-triage re-review)

## Summary

The suite is 11 tests, `async: true` (pure Elixir, no global state — correct).
Round-1 findings W2 and W3 are **structurally resolved** but one has a
latent robustness concern. S3 is fully resolved. One new warning is raised
on a gate-index collision in `apply_drift`. No Iron Law violations.

---

## Round-1 Findings Status

### W2 — RESOLVED (with one caveat, see NEW-W1 below)

The vacuous dev(post-collapse-state) assertion is gone. Two replacement
tests exercise the conditional path correctly:

**(a) `conditional_pre_measure_drift/100`** — sound. The 100 drift gates
execute through the `execute_single_shot/2` timeline reduce *before* the
measure, so the guard fires on gate 100 (drift ~1.07e-6 > 1.0e-6). The
`renormalize: 10` branch asserts only `is_map(result)` — this is **not
tautological**: the test proves the function completed without raising,
which is the meaningful claim (the guard would have raised otherwise).
Reaching `is_map(result)` proves renorm kept drift below the guard
threshold on the conditional path. Assessment: sound.

**(b) `conditional_in_block_drift/120`** (W1 regression) — determinism
argument:

`X(0)` on a 3-qubit circuit flips qubit 0. The simulation uses the MSB
convention consistently: qubit `q` is at bit position `num_qubits - 1 - q`
(confirmed in both `extract_classical_bits` and
`calculate_measurement_probability`). For a 3-qubit system, qubit 0 is
bit position 2, so state index where qubit 0 = 1 is any index with bit 2
set (4, 5, 6, 7). After X(0)|000⟩ the state vector is |100⟩ (index 4),
amplitude 1.0. `prob_0 = 0.0`, so `rand < 0.0` is always false →
`measured_value = 1` with certainty. Cbit 0 is set to 1. `c_if(0, 1,
...)` fires deterministically. The qubit/bit convention is **consistent**;
the "always fires" claim is **correct**.

The `renormalize: 10` branch again asserts only `is_map(result)` —
adequate for the same reason as (a): reaching it proves no raise in the
block path.

### W3 — RESOLVED (with float ULP caveat, see NEW-W2 below)

Three distinct tests now in AC#3 describe block — guard test, relative
guarantee test, and renorm-over-time test — each testing a different
concern. The re-scoping is correct.

### S3 — RESOLVED

`dev/1` now opens with `assert tuple_size(Nx.shape(state)) == 1` with a
meaningful failure message. Shape regression can no longer make the metric
silently lenient.

---

## Issues Found

### Warnings

- **NEW-W1 — `apply_drift` uses `rem(i, 3)` as BOTH the branch selector and the qubit index, producing a silent no-op on gate multiples of 3** (line 33).
  When `i` is a multiple of 3, `rem(i, 3) == 0`, the branch is `Qx.h(acc, 0)` —
  that is `H` on qubit 0, which is a real gate. OK so far. But when `i mod 3 == 2`,
  the CX is `Qx.cx(acc, 2, rem(3, 3))` → `Qx.cx(acc, 2, 0)` — control and target
  determined by a fixed pattern. That is deterministic and not obviously wrong, but
  the `rem(i, 3)` reuse as qubit address means qubit 0 is used in *every* branch
  (H on qubit 0, RX on qubit 1, CX with qubit 0 as target). A future 2-qubit circuit
  passed to `apply_drift` would silently generate a CX targeting the same index as
  the 3-qubit case, potentially raising at runtime rather than producing an error in
  the test helper setup. More importantly: the current tests call `apply_drift` only
  with 3-qubit circuits built by `drift_circuit/1`, so the pattern is safe *in
  practice*. No test is currently wrong as a result. **Recommend** adding a `@moduledoc
  false` docstring note or a guard/assertion in `apply_drift` that `num_qubits >= 3`,
  or restructuring to use distinct variables for branch selector and qubit target.
  Severity: Warning (no current test broken; silent if circuit is 2-qubit).

- **NEW-W2 — `renormed < off` in the 60-gate comparison test is close to the float32 ULP floor** (line 82).
  Probe data: off ≈ 5.96e-7, renormed ≈ 1.19e-7 — a ~5× margin. On
  BinaryBackend (software float32) with a fixed circuit this is
  deterministic; there is no PRNG in a measurement-free segment, and Nx
  BinaryBackend has no FP non-determinism across runs. The margin is
  sufficient that ULP coincidence is not a practical risk. However, the
  test provides **no comment documenting the probe values** that justify
  the 60-gate count choice, making it opaque to future maintainers who
  might change gate count or backend. The comment at line 74 mentions
  ~6e-7 / ~1.19e-7 in the *describe docstring* but not inline in the
  assertion. **Recommend** adding a one-line comment at the assertion:
  `# off≈5.96e-7, renormed≈1.19e-7 on BinaryBackend — ~5× margin` so
  future changes to gate parameters are visibly risky. Severity: Warning
  (not a correctness issue; a maintainability one).

### Suggestions

- **S1 — `is_map(result)` assertions (lines 157, 170) would be marginally stronger as `assert %SimulationResult{} = result`**.
  `is_map` is true for any map, including an error struct; matching the
  concrete struct type rules out an accidental `{:error, _}` tuple. The
  current form is not wrong — `Simulation.run/2` either returns a
  `%SimulationResult{}` or raises — but the struct match is clearer
  intent and cheaper than `is_map`.

- **S2 — `conditional_pre_measure_drift` and `conditional_in_block_drift` are each called twice** (once for `assert_raise`, once for the `renormalize: 10` branch).
  The circuit is cheap to build but constructing it twice per test is
  unnecessary. Binding to a variable in a `setup` or inline `let` in each
  test would be cleaner. Minor; no correctness impact.
