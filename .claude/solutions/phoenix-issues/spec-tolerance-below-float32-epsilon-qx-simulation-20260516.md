---
module: "Qx.Simulation"
date: "2026-05-16"
problem_type: numerical_precision
component: configuration
symptoms:
  - "Plan/AC specified norm tolerance 1.0e-10 after a 100-gate circuit"
  - "Single Hadamard on |0> already deviates |Σ|a|²−1| ≈ 5.96e-8 (≈600× the 1e-10 target)"
  - "Even immediately after Qx.Math.normalize/1 the deviation floor is ≈1.19e-7"
  - "A 1e-10 dev/test guard (validate_normalized!) would raise on essentially every existing simulation test"
root_cause: "spec tolerance was written in real-arithmetic terms while the engine computes in :c64 (complex float32, ε≈1.2e-7), so 1e-10 is far below machine epsilon and unreachable even right after renormalization"
severity: high
tags: [float32, c64, nx, tolerance, renormalization, precision, compile-env, qx-53v]
---

# 1e-10 norm tolerance is infeasible in :c64 (float32)

## Symptoms

qx-53v acceptance criterion #3: "norm stays within `1.0e-10` after a
100-gate circuit". Empirically on `Nx.BinaryBackend` (the `:test`
backend), all states being `:c64`:

| scenario | \|Σ\|a\|²−1\| |
|---|---|
| single Hadamard | 5.96e-8 |
| 5 gates | 5.96e-8 |
| 100 gates, no renorm | 1.07e-6 |
| 100 gates, **after `Math.normalize/1`** | **1.19e-7** |

A `validate_normalized!(state, 1.0e-10)` guard active in `:test` would
raise after the first Hadamard in nearly every test.

## Investigation

1. **Assume 1e-10 is achievable post-renorm** — probe showed the
   floor is ~1.2e-7 even immediately after `Math.normalize/1`
   (division then re-square reintroduces ~1 ULP in float32).
2. **Check the numeric type** — `Gates.*` and `real_state_to_complex`
   use `:c64` (complex *float32*, ε≈1.19e-7). 1e-10 ≈ 600× below ε.
3. **Root cause found**: the scratchpad's "|p−1|≤1e-10 ⇒ stricter
   than norm-form" note is true in ℝ but ignores machine epsilon.

## Root Cause

Spec precision targets must be sanity-checked against the runtime
float width. `:c64` = float32 components ⇒ ~1e-7 best-case total-
probability accuracy. Renormalization *bounds* drift (1.07e-6 → ~1e-7,
~9×) but cannot reach 1e-10. Tightening the guard below ε turns it
from a useful gross-drift trap into a suite-breaking false alarm.

## Solution

1. Surface the infeasibility with measured data; record a DEAD-END in
   `scratchpad.md`; get a user decision (do NOT silently pick a new
   number). Amend AC #3 → a **relative** guarantee at a realistic
   `1.0e-6`.
2. Named module attr `@norm_tolerance 1.0e-6` in `Qx.Simulation`.
3. Reuse existing primitives — no new code/dep: renorm =
   `Qx.Math.normalize/1` (`defn`); guard =
   `Qx.Validation.validate_normalized!/2`.
4. Gate the guard's host sync (`Nx.to_number`) via
   `Application.compile_env(:qx, :assert_norm, false)` — true in
   `config/test.exs`, false in `config/config.exs` (dead code in
   `:prod`/`:dev`, Iron Law Nx #5).

```elixir
@assert_norm Application.compile_env(:qx, :assert_norm, false)
@norm_tolerance 1.0e-6

defp assert_norm(state) do
  if @assert_norm, do: :ok = Validation.validate_normalized!(state, @norm_tolerance)
  state
end
```

### Files Changed

- `lib/qx/simulation.ex` — `@norm_tolerance`, `@assert_norm`, `assert_norm/1`
- `config/config.exs` / `config/test.exs` — `assert_norm` false/true
- test: relative guarantee (60-gate `dev(renorm) < dev(off)`) + a
  100-gate guard-fires test, instead of an absolute 1e-10 assertion.

## Prevention

- Before implementing a precision/perf target, check it against the
  backend float width (c64=f32 ⇒ ~1e-7; c128=f64 ⇒ ~1e-15).
- Express long-circuit norm guarantees as **relative** (renorm < no-
  renorm) or as a guard-fires test, not an absolute sub-ε number.
- Reuse `Qx.Math.normalize/1` + `Qx.Validation.validate_normalized!/2`;
  do not hand-roll a norm-form assertion.
- Compile-gate any dev/test host sync via `compile_env` so it is dead
  code in `:prod` (Iron Law Nx #5).

## Related

- `.claude/solutions/phoenix-issues/issue-title-names-wrong-module-seam-qx-simulation-20260516.md`
- Iron Law Nx #5: no host-side loops over 2^n amplitudes (host sync
  acceptable only when compile-gated out of prod)
