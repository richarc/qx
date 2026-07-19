# Scratchpad: calcfast-norm-drift-guard (qx-53v)

## Confirmed decisions (user, 2026-05-16)

1. Trigger: configurable — `renormalize: N` ⇒ every-N gates + at
   measurement; `true` ⇒ measurement-time only; `false` (default) off.
2. Default: `false` (opt-in) — zero behaviour/perf change when off.
3. Norm assertion: compile-time `Application.compile_env(:qx,
   :assert_norm, false)` → module attr → `if @assert_norm`; compiled
   out in prod. `config/test.exs` sets true.
4. Scope: both non-conditional (`execute_circuit`) and conditional
   (`execute_single_shot` timeline) paths.
5. No new hex dep (hex-library-researcher: pure Nx + ExUnit correct).

## Key reuse (minimal new code)

- Renorm = `Qx.Math.normalize/1` (already a `defn`, `math.ex:61`).
- Guard = `Qx.Validation.validate_normalized!/2` (already raises
  `Qx.StateNormalizationError`, `validation.ex:102`) with tol `1.0e-10`.
- It checks total prob `p=Σ|a|²`, not ‖ψ‖. Near 1, `|p−1|≤1e-10 ⟹
  |‖ψ‖−1|≤~5e-11` — equivalent & stricter. Do NOT write a norm-form
  assertion; reuse the existing one.

## Scoping correction (most important)

Issue/ROADMAP title: "...in CalcFast". WRONG home. `Qx.CalcFast` =
stateless per-gate `defn` kernels, no loop/opts. The seam is
`Qx.Simulation` (`run/2` opts + `execute_circuit/1` reduce, line 221) +
`Qx.Math` + `Qx.Validation`. **CalcFast is NOT modified.** Reviewers
must not "fix" this by forcing logic into CalcFast.

## Open decisions / dead-ends

- `Qx.OptionError` (new, per-concern style) vs reuse generic
  `Qx.Error` for invalid `:renormalize`. Leaning new `Qx.OptionError`;
  decide in P1-T1. (Not a dead-end — just an open call.)

- **[2026-05-16 DEAD-END / BLOCKER] `1.0e-10` tolerance is infeasible
  in `:c64` (float32, ε≈1.19e-7).** Empirically measured on
  `Nx.BinaryBackend` (the `:test` backend):
  - single Hadamard → |Σ|a|²−1| = **5.96e-8**
  - 5 gates → 5.96e-8
  - 100 gates, no renorm → 1.07e-6
  - 100 gates, **after `Math.normalize/1`** → **1.19e-7**
  Consequences:
  1. P3 guard `validate_normalized!(state, 1.0e-10)` active in `:test`
     raises after the FIRST Hadamard → breaks the whole existing suite
     (violates Phase 1 "suite must pass unchanged").
  2. AC #3 / P4-T1 ("norm within 1e-10 after 100 gates") and P4-T3
     ("`true` ⇒ norm within 1e-10") are unreachable in float32 even
     immediately post-`normalize` (~1.2e-7 floor). Renorm DOES help
     (1.07e-6 → 1.19e-7, ~9×) — the feature is sound; only the
     numeric target is wrong.
  The scratchpad's "stricter than norm-form" note is true in ℝ but
  ignores machine ε. Resolution requires a user decision (changes AC
  #3 wording + P3 tolerance + P4 assertions). Asked user 2026-05-16.
  - **RESOLVED 2026-05-16 (user):** Option A — guard + AC use
    `@norm_tolerance 1.0e-6` (a named module attr in `Qx.Simulation`),
    NOT 1.0e-10. Rationale: 1e-6 leaves normal small test circuits
    green (worst ≈1.2e-7) yet still trips on gross drift (100 un-
    renormed gates ≈1.07e-6). AC #3 reworded to a **relative**
    guarantee: a 100-gate circuit with `renormalize: 10` must (a) stay
    within 1e-6 AND (b) have strictly lower drift than the same circuit
    with `renormalize: false` (renorm demonstrably helps, ~9×). P4-T1
    asserts both; P4-T3 (`true`) asserts < 1e-6. Document the float32
    floor in the `@doc` so users don't expect 1e-10.

## Perf evidence (P5-T2, `mix run bench/renormalization_bench.exs`, 2026-05-16, :dev)

AC #4 — no regression on the default `:off` path:

| scenario | average |
|---|---|
| short baseline (no opt) | 293.79 μs |
| short `renormalize: false` | 293.69 μs (≡ baseline, +0.1 μs / 0.03% — within ±7.6% noise) |
| short `renormalize: true` | 300.56 μs (+6.87 μs ≈ 2.3%, opt-in only) |
| long(100) `renormalize: false` | 6844.98 μs |
| long(100) `renormalize: 10` | 6854.16 μs (+9.2 μs ≈ 0.13%, negligible) |

Conclusion: the `:off` path (default + explicit `false`) is
indistinguishable from the pre-feature baseline; per-gate renorm cost
is dominated by gate application. AC #4 ✅.

## Out-of-scope / discovered work

- `collapse_to_measurement` (`simulation.ex:468`) already renormalizes
  post-collapse — intentionally left as-is; do not double-normalize.
- Whether `Qx.Math.probabilities/1` should itself renorm defensively —
  out of scope; renorm is opt-in by design.
- (carried from prior session) `Qx.CalcFast.apply_cswap` has no
  matrix-level correctness test; `Gates.toffoli/4` LSB/MSB bug. Both
  separate ROADMAP/`fix/` items, not pulled here.
