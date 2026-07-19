# Review: feat/u-gate-convention

**Verdict: PASS WITH WARNINGS**

- Requirements coverage: **9/9 MET** (no escalation)
- Iron Laws: **0 violations** (Law #6 correctly does not trigger — doc-only, `@spec` unchanged)
- Code quality: PASS — 0 BLOCKER, 4 WARNING, suggestions filtered as noise
- All warnings are confined to the **new test file**; zero findings on changed
  docstring/production code. Full suite is green and deterministic
  (229 doctests, 703 tests, 0 failures).

---

## Requirements Coverage (Plan .claude/plans/u-gate-convention/plan.md)

All 9 criteria MET (full table in `reviews/requirements.md`). Highlights:
convention cited by name (no URLs) and consistent across all three
docstrings; `U(π,0,π)/U(π/2,0,π)/U(0,0,0)` tests present with a
global-phase-tolerant helper; `@spec` order unchanged; existing
`u_gate_test.exs` has zero diff.

---

## Warnings (all in `test/qx/u_gate_convention_test.exs`, none affect correctness)

**W-A — Unevaluated AST in generated test name** (elixir-reviewer)
The `for` list literal `{:math.pi()/3, :math.pi()/5, -:math.pi()/4}` is
bound as AST, so that test is named literally `U(:math.pi() / 3, ...)`.
Ugly, not broken. Fix: hoist `@pi :math.pi()` module attribute (evaluated
at compile time) and use `@pi / 3` etc.

**W-B — Misleading inline comment on matmul order** (testing-reviewer W1)
The math `rz(phi) |> Nx.dot(ry(theta)) |> Nx.dot(rz(lambda))` correctly
computes `RZ(φ)·RY(θ)·RZ(λ)` and matches the docstring identity. The
comment "rz(φ) applied last" is backwards in the pipeline sense and could
mislead a future refactor into flipping the order. One-line comment fix.

**W-C — Phase-ratio helper pivot guard** (testing-reviewer W2)
`assert_unitary_equal_up_to_phase/3` picks the first entry with
`|b_ij| > 1e-9` but does not also guard `|a_ij|`. Not flaky for the gates
tested here; a robustness gap for future reuse — and the scratchpad
explicitly earmarks this helper for reuse by sibling ROADMAP item qx-uos
(CSWAP/iSWAP matrix tests). Fix: `and Complex.abs(av) > 1.0e-9`.

**W-D — `@delta 1.0e-6` margin on c64/f32** (testing-reviewer W3)
~1 decade of margin over f32 rounding for chained `Nx.dot`. Not currently
flaky (max 2 sequential dots, 2×2). Optional: relax decomposition test to
`1.0e-5`, or leave as-is and note for longer future chains.

## Suggestions (filtered as noise / out of scope)

- `|> case do` on `Enum.find` — idiomatic and correct as-is. Dismissed.
- `@moduledoc` on the test module — *kept deliberately*: it documents WHY
  this is a characterization lock not red→green TDD. Valuable, not noise.
- S3 "add `U(θ,0,0) ≈ RY(θ)`" — out of plan scope; note for a follow-on.

## Pre-existing (NOT this diff — discovered work)

`lib/qx/gates.ex:197,221` — `ry/0`/`rz/0` doc examples use `math.pi/2`
(missing `:` prefix). Did not fail our run (not executed as `iex>`
doctests), unchanged by this branch. Logged to scratchpad as discovered
work for a separate fix.
