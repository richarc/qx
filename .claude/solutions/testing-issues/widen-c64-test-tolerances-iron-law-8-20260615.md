---
module: "Qx"
date: "2026-06-15"
problem_type: iron_law_violation
component: testing
symptoms:
  - "Test `@delta` set to `1.0e-12` and `@tolerance` set to `1.0e-10` against `:c64` (float32-complex) matrices and statevectors"
  - "Suite passes today — but only because every fixture's amplitudes are exactly representable in float32 (0, 1, ±i), or because both sides of each comparison run identical float32 ops yielding bit-identical results"
  - "Project audit (2026-06-14) flagged 3 sites as Iron-Law-#8 CRIT/HIGH violations gating the v0.8.2 `Qx.CalcFast` reshape+contract rewrite — any reformulation of the Nx kernel that breaks float32 bit-identity would flip these tests to red without any actual regression"
root_cause: "Test tolerances were set 'tighter is better' without checking the runtime float width — `:c64` ε ≈ 1.2e-7, so any tolerance below ~1.0e-6 is unreachable except by luck of exactly-representable amplitudes; passing-today is a pass-by-coincidence, not a pass-by-precision"
severity: high
iron_law_number: 8
tags: [c64, float32, tolerance, testing, iron-law-8, audit, regression-trap, kernel-rewrite]
related_solutions:
  - ".claude/solutions/phoenix-issues/spec-tolerance-below-float32-epsilon-qx-simulation-20260516.md"
  - ".claude/solutions/testing-issues/exact-vs-phase-tolerant-gate-matrix-equality-qx-gates-20260516.md"
---

# Widen `:c64` test tolerances to the Iron-Law-#8 floor

## Symptoms

The 2026-06-14 project health audit
(`.claude/audit/reports/test-audit.md`) flagged three test sites as
sub-`:c64`-ε tolerance violations:

| File | Value | Audit severity |
|---|---|---|
| `test/qx/cswap_iswap_matrix_test.exs:33` | `@delta 1.0e-12` | CRIT (C5) |
| `test/qx/export/openqasm/round_trip_test.exs:8` | `@tolerance 1.0e-10` | CRIT (C6) |
| `test/qx/u_gate_convention_test.exs:24` | `@delta 1.0e-6` (boundary) | HIGH |

All three passed at commit time. The trap: `:c64` is float32-complex
with ε ≈ 1.2e-7, so the first two tolerances are 5 and 3 decades
below ε respectively. They pass only because:

- **cswap/iswap**: every amplitude in a permutation/Clifford gate
  matrix is exactly representable in float32 (0, 1, ±i).
- **OpenQASM round-trip**: both sides of the comparison
  (`build_*` Elixir-side circuit vs parsed-from-`.qasm` circuit) run
  through *identical* float32 ops, so identical inputs → bit-identical
  outputs. The diff is zero, not "small".
- **U-gate convention**: the helper does only one `Complex.divide` +
  one `Complex.multiply` per entry; worst-case float32 rounding is
  ~3ε ≈ 3.6e-7, leaving ~2.8× headroom at `1.0e-6` — the boundary
  case, but still inside the floor.

The pass-by-luck mechanism is fragile in exactly one direction: **a
kernel rewrite that re-orders or re-formulates the Nx ops will break
the bit-identity** and flip these tests to red without any actual
numerical regression. The v0.8.2 `Qx.CalcFast` reshape+contract
rewrite (single biggest perf-win in the audit) is precisely such a
rewrite.

## Investigation

1. **Could the existing tolerances just be tightened across the
   suite?** No — `:c64` ε is fixed at ~1.2e-7 by the float32 component
   choice. `1.0e-6` is the tightest physically achievable bound.
2. **Are the tests passing because of careful numerical design, or by
   coincidence?** Inspection of each fixture set:
   - cswap/iswap tests reference only `Math.complex_matrix/1` of
     0/1/±i lists. All representable exactly.
   - Round-trip fixtures (`build_bell`, `build_ghz3`, `build_qft3`,
     `build_mixed_parametric`, `build_grover2`) include non-trivial
     rotations (π/2, π/3, π/4, π/5, π/7). cos/sin of these are
     irrational and NOT representable in float32 — but both sides
     run the same sequence of float32 ops, so the *diff* is zero
     even though the values aren't exact.
   - U-gate test computes the *ratio* of corresponding entries,
     which accumulates two complex multiplications per entry.
3. **Root cause found**: tolerance was set in real-arithmetic terms
   ("tighter = stricter = better") rather than against the runtime
   float width. Identical to the lesson from the sister doc
   `spec-tolerance-below-float32-epsilon-qx-simulation-20260516.md`,
   but on the test side rather than the simulation side, and the
   stake is forward-looking flake risk rather than current
   suite-breakage.

## Root Cause

A test tolerance protects against numerical regression. Two
quantities matter:
- the *worst-case rounding error* for the assertion's underlying
  arithmetic (this floors the tolerance — set tighter and the test
  flakes), and
- the *smallest real-bug delta* you want to catch (this ceilings the
  tolerance — set looser and bugs slip through).

For `:c64` matrix/state equality, the floor is ~1e-7 (float32 ε).
The ceiling is set by the failure modes the test exists to detect:

| Test family | Smallest real-bug delta | Headroom at `1.0e-6` |
|---|---|---|
| Permutation/Clifford matrix equality (cswap, iswap) | O(1) — wrong control qubit, ±i sign flip | 6 decades |
| Statevector equality across round-trip | O(0.1)–O(1) — dropped gate, wrong angle, wrong qubit | 5–6 decades |
| Unitary-up-to-phase decomposition identities | O(sin(angle-diff)) ≈ O(0.1) for the chosen angles | 5 decades |

`1.0e-6` is at the floor but still leaves 5+ decades of bug-detection
sensitivity. Tightening past `1.0e-6` does not improve sensitivity —
it just makes the test fragile to harmless reformulations.

## Solution

Widen each tolerance to the Iron-Law-#8 floor and inline-comment the
choice so a future reader cannot accidentally tighten it back.

```elixir
# test/qx/cswap_iswap_matrix_test.exs
# Iron Law #8: :c64 ε ≈ 1.2e-7; 1.0e-6 is the tightest sound bound
# for entrywise equality of float32-complex tensors.
@delta 1.0e-6
```

```elixir
# test/qx/export/openqasm/round_trip_test.exs
# Iron Law #8: :c64 ε ≈ 1.2e-7. Comparison is `max(abs(a - b)) <
# @tolerance`, so 1.0e-6 leaves ~one decade of head-room above ε.
# The previous 1.0e-10 passed only because both sides ran the same
# float32 ops, yielding bit-identical results — a property the
# v0.8.2 kernel rewrite will break.
@tolerance 1.0e-6
```

```elixir
# test/qx/u_gate_convention_test.exs
# Iron Law #8 boundary: :c64 ε ≈ 1.2e-7. 1.0e-6 sits right at the
# tightest sound bound for float32-complex; do NOT tighten further
# — the parametric tests below compute cumulative products of
# cos/sin/multiply on irrational angles, where float32 error can
# reach ~5e-7 before falling below this threshold. Loosening it
# would defeat the convention-lock purpose of this file.
@delta 1.0e-6
```

Also update the moduledoc text in `cswap_iswap_matrix_test.exs` to
match the new tolerance value (the prior text claimed `1.0e-12`).

### Files Changed

- `test/qx/cswap_iswap_matrix_test.exs` — `@delta` widened, moduledoc
  refreshed, inline rationale added.
- `test/qx/export/openqasm/round_trip_test.exs` — `@tolerance`
  widened, inline rationale added.
- `test/qx/u_gate_convention_test.exs` — `@delta` left at the floor,
  "do NOT tighten further" boundary comment added.
- `ROADMAP.md` — ticked v0.8.1 tolerance-widening item.
- Shipped on `main` in squash commit `4080e1c` after `/phx:review`
  PASS from all three mandatory reviewers (elixir, testing,
  iron-law-judge). 854 tests + 243 doctests, 0 failures.

## Prevention

- [x] **Already an Iron Law** — Iron Law #8 in the Qx
  `AGENTS.md` / `CLAUDE.md` plugin block already names `~1.0e-6` as
  the floor and forbids sub-ε tolerances. This solution doc is the
  applied-on-tests companion.
- [x] **Detectable by reviewer** — the `iron-law-judge` agent now
  catches this; the review on `fix/c64-tolerances` ran clean.
- **Specific guidance for new tests**: when you reach for
  `assert_in_delta` / `< @tolerance` against a `:c64` or `:f32`
  tensor, the only sound choices are `1.0e-6` (tight bound),
  `1.0e-5` (one decade looser, for cumulative multi-op products),
  or a *relative* guarantee. Never `1.0e-7` or tighter. If you
  think you need tighter, the type should be `:c128` / `:f64` and
  the runtime allocation should reflect that — surface it before
  picking a number.
- **Specific guidance for fixtures**: a tolerance test that passes
  because the fixture's amplitudes are exactly representable in
  float32 is *not* testing the tolerance — it's testing arithmetic
  determinism. To prove the test is sound, the fixture must also
  exercise an angle where the comparison runs into actual float32
  rounding. Existing coverage that does this in this repo:
  `build_qft3`, `build_mixed_parametric` (round-trip), and the
  parametric (θ,φ,λ) cases (u-gate). No new fixtures needed.

## Related

- `.claude/solutions/phoenix-issues/spec-tolerance-below-float32-epsilon-qx-simulation-20260516.md`
  — sister lesson on the *simulation* side (norm-tolerance for
  `Qx.Simulation`'s `validate_normalized!/2`). Same Iron Law #8
  root cause, different surface (production assertion vs test
  assertion).
- `.claude/solutions/testing-issues/exact-vs-phase-tolerant-gate-matrix-equality-qx-gates-20260516.md`
  — companion test-side doc whose `1.0e-12` example value was
  widened by this work; that doc's *primary* lesson (decision rule
  for phase-tolerant vs exact equality on gate matrices) is
  unchanged, but the example value was a hidden Iron-Law-#8
  violation. Cross-linked from there to here.
- Iron Law #8: precision/tolerance feasibility against `:c64` ε
  (Qx `AGENTS.md` plugin block).
- Audit report: `.claude/audit/reports/test-audit.md` (CRIT C5, C6)
  and consolidated synthesis `.claude/audit/summaries/project-health-2026-06-14.md`.
