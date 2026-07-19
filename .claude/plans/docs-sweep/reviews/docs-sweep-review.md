# Merge-gate review — docs-sweep (v0.11)

**Verdict: PASS WITH WARNINGS**
Branch: `feat/docs-sweep` · 13 files (12 `lib/` + CHANGELOG) · non-breaking docs/spec sweep
5 specialist agents, run parallel. **0 BLOCKERs.**

## Requirements Coverage (requirements-verifier vs plan)

**14 MET · 0 PARTIAL · 0 UNMET · 2 UNCLEAR (both resolved MET by verification-runner).**

- 47 `@spec` additions verified directly in source (Operations 29, QuantumCircuit 8,
  Draw 6, Math 2, StateInit `basis_state/3`, OpenQASM `to_qasm/2`).
- `rx/ry/rz/phase` facade specs confirmed `number()`.
- 61 `## Returns` blocks; 18 grounded `## Raises` — spot-checked to real raise sites.
- tap warning copied to `tap_state`/`tap_probabilities`; `tap_circuit` got the lighter note.
- OpenQASM doc-rot fully fixed — zero `Qx.circuit(`/`Qx.cnot(` remain.
- CHANGELOG has both the angle-widening **Changed** entry and the **Documentation** section.
- Tier openers on all 9 modules → **MET-with-deviation** (tier-1 structs got a tier-1
  opener, not the tier-2 "utility module" line; needs merge-gate sign-off).
- The 2 UNCLEAR (full gate, `mix docs` count) were independently re-run by
  verification-runner: all PASS, docs = 36 = baseline.

## Verification gate (verification-runner) — ✅ PASS

compile `--warnings-as-errors` ✓ · format ✓ · credo `--strict` (0 issues) ✓ ·
test (1030 tests + 250 doctests, 0 failures) ✓ · `mix docs` = **36 = baseline** (no
new autolink warnings from the added spec type refs / cross-ref edits).

## Elixir review (elixir-reviewer) — Approved · 0 BLOCKER / 1 WARNING / 2 SUGGESTION

- Every one of the 47 `@spec`s cross-checked against its body/delegate — **all
  type-accurate**. `number()` widening consistent with `Validation.validate_parameter!/1`.
  All 18 `## Raises` claims trace to real raise sites.
- **WARNING (pre-existing wording):** `Qx.StateInit` moduledoc says the supported
  surface is `basis_state/3`, but CLAUDE.md/CHANGELOG describe it as `basis_state/2,3`.
  Minor drift, non-blocking.
- 2 SUGGESTIONs on pre-existing (unchanged) code — out of this diff's scope.

## Iron Law judge — 0 BLOCKER / 0 WARNING / 1 SUGGESTION

- **#6 non-breaking:** verified — no spec narrowed, no signature/return changed;
  `float()→number()` widening complete and consistent; CHANGELOG accurate, correctly
  no version bump.
- **#7 typed raises:** the 18 new `## Raises` cross-checked against `errors.ex` +
  callers — accurate. `Qx.superposition/1` correctly has **no** `## Raises` (deferred).
- **SUGGESTION:** `Qx.Math` and `Qx.StateInit` are *also* §3 tier-2 modules but did
  **not** get the "Utility module" opener (they keep their prior trimmed-surface
  framing). The CHANGELOG's "**Every** tier-2 module moduledoc now opens with the §3
  tier marker" therefore over-claims. Fix: add the marker to those two, **or** soften
  the CHANGELOG wording.

## Testing review — clean · 0 findings

No test files changed; the spec widening is a static annotation (no runtime effect),
so no new tests needed. Doctest deferral respected. Doc-rot replacement names
(`Qx.create_circuit/1,2`, `Qx.cx/3`) confirmed real.

---

## Post-review fixes applied (2026-07-11)

1. ✅ **CHANGELOG over-claim fixed** — "Every tier-2 module…" reworded to name the
   6 modules that got the opener and to call out that `Math`/`StateInit` keep their
   v0.11-trim framing.
2. ✅ **StateInit moduledoc fixed** — `basis_state/3` → `basis_state/2,3`.
3. ✅ **Tier-1 struct opener** — user confirmed the §3-correct choice stands
   (`QuantumCircuit`/`SimulationResult`/`Step` keep the tier-1 opener).

Re-verified after fixes: compile `--warnings-as-errors` ✓, format ✓, credo `--strict`
(0 issues) ✓, `mix docs` = 36 = baseline ✓. (No test re-run — both edits are
doc/markdown-only; the 1030-test + 250-doctest suite already passed pre-fix.)

**Status: PASS — cleared for merge, awaiting human authorization.**
