# Merge-Gate Re-Review (Round 2) — feat/calcfast-norm-drift-guard

Date: 2026-05-16 · Post-triage-fix diff vs `main` · Agents:
elixir-reviewer, testing-reviewer, iron-law-judge,
requirements-verifier (all 4 completed)

## Verdict: **PASS** (3 optional SUGGESTIONs, no blockers/warnings)

All round-1 findings (1 BLOCKER, 4 WARNINGS, 3 SUGGESTIONS)
independently confirmed **RESOLVED**. The W1 behaviour change (the
only runtime-affecting fix) verified correct by all relevant agents.
No new blockers or warnings. 3 minor polish suggestions only.

---

## Round-1 finding resolutions (confirmed)

| ID | Round-1 | Round-2 status |
|----|---------|----------------|
| B1 | mix.exs docs group | RESOLVED (elixir-v2) |
| W1 | c_if sub-gates bypass renorm/guard | RESOLVED — `apply_gate_step/5` shared 1-based counter; counter semantics proven equivalent to old path (no off-by-one); measurement doesn't advance counter; c_if firing/non-firing branches thread count correctly (elixir-v2, iron-v2) |
| W2 | vacuous P4-T5 | RESOLVED — 2 substantive guard-based conditional tests; W1 determinism verified (X(0)+measure ⇒ bit 0 = 1 with certainty under MSB convention, c_if always fires) (testing-v2, reqs-v2) |
| W3 | indirect AC#3 proof | RESOLVED — direct 60-gate `renormed < off` sub-threshold comparison (~5× margin, deterministic) + re-scoped guard test (testing-v2, reqs-v2) |
| W4 | narrow @spec | RESOLVED (`term()`) (elixir-v2) |
| S1/S2/S3 | minor | RESOLVED (`:ok =` pin; `to_renorm/1` heads; `dev/1` shape guard) |

## Requirements (round 2)
**10 MET · 0 PARTIAL · 0 UNMET · 1 UNCLEAR.** AC#3 now STRONGLY MET
(direct numeric comparison, non-vacuous). DC6/W1 genuinely MET (real
fix + in-c_if-block regression test). AC#4 UNCLEAR only because a
benchmark is not an ExUnit assertion — substantively satisfied: the
`:off` path is a structural zero-cost catch-all AND `mix bench` was
run with results recorded in `scratchpad.md` (short `false` ≡
baseline, +0.03%, within noise). Per verdict-fold rules, lone UNCLEAR
does not downgrade the verdict.

## Iron Laws (round 2)
**PASS — 0 violations, all prior verdicts unchanged.** Law #7: `to_renorm/1`
only ever called post-validation (no FunctionClauseError leak).
Nx#5: `assert_norm/1` per-gate (incl. c_if sub-gates) still
compile-gated dead code in `:prod`. Laws #1/#2/#6/Nx#3/Nx#4 COMPLIANT.

---

## NEW — SUGGESTIONs only (optional, non-blocking)

- **N1** `test` `apply_drift/2` uses `rem(i, 3)` as both branch
  selector and qubit index — safe for the current 3-qubit circuits,
  would misbehave if reused with a 2-qubit circuit. Add a one-line
  comment pinning the 3-qubit assumption. No test broken.
- **N2** `test` line ~82: the `renormed < off` margin (≈1.19e-7 vs
  ≈5.96e-7) is deterministic but the probe values aren't noted at the
  assertion — add an inline comment so the 60-gate choice isn't opaque
  to future maintainers.
- **N3** `test` conditional tests: `assert is_map(result)` could be
  `assert %Qx.SimulationResult{} = result` for clearer intent (also
  weakly strengthens the assertion). Non-tautological as-is (reaching
  it proves the guard didn't raise).

## Recommendation
Merge-gate condition satisfied (PASS; all round-1 findings resolved).
N1–N3 are trivial maintainability polish — apply-then-merge or merge
as-is, user's call. Hard stop for human merge authorization (P7-T3).
