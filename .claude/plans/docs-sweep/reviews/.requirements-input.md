# Docs sweep (v0.11, findings B-08/B-15/R-12/R-15/T1-11/15/16)

**Branch:** `feat/docs-sweep`
**ROADMAP:** v0.11 "Docs sweep"
**Depth:** standard · **Complexity:** 4 (many public modules +3, declared-public
surface docs/@specs +3, mechanical/follows the typed-error-sweep pattern −2)
**Research:** none spawned — findings §6 ARE the research (plan Iron Law #7).
Worklist grounded in a fresh `api_inventory.exs` run 2026-07-11 (see scratchpad).

## Decision

One mechanical, **non-breaking** doc sweep over the declared tier-1/2 surface:
add the missing `@spec`s, `## Returns`/`## Raises`, §3 tier-annotation moduledoc
openers, copy the `tap_*` debugging warning up to the facade, unify gate-family
angle types to `number()`, and fix the doc-rot cross-refs. No behaviour change.

**Scope decisions (user-confirmed 2026-07-11):**
- **Deprecated functions exempt.** The 17 `@deprecated` StateInit/Math orphans
  (removed at 1.0, already carry deprecation notices) get NO new `@spec`/Returns.
  Worklist = the **47 supported** functions missing `@spec`, not all 82.
- **Specs/docs only — no doctests.** Doctest gaps are tracked as a separate
  follow-up (see scratchpad "For later cycles"); this sweep stays mechanical
  and TDD-hook-free.

### Grounded worklist (fresh `api_inventory.exs`, 2026-07-11)

47 SUPPORTED functions missing `@spec`, by module:

| Module | count | notes |
|---|---|---|
| `Qx.Operations` | 29 | gate builders — the bulk; angle params → `number()` |
| `Qx.QuantumCircuit` | 8 | |
| `Qx.Draw` | 6 | |
| `Qx.Math` | 2 | supported trio only (`normalize`/`probabilities`) |
| `Qx.StateInit` | 1 | `basis_state` |
| `Qx.Export.OpenQASM` | 1 | |

The facade `Qx` (61 fns) and `Simulation`/`Patterns`/`SimulationResult`/`Step`
are already fully specced (the "standard is achievable" proof modules).

### Explicitly out of scope
- The 17 deprecated StateInit/Math functions + 24 `@doc false` internals.
- Doctests (deferred).
- Any behaviour change; new public API (that's the separate "Additive surface"
  v0.11 package: `bell_pair`/`ghz` appenders, `tdg/2`, QASM facade delegates).

---

## Phase 1 — Inventory & baseline (no product code)

- [x] [P1-T1] Re-run `api_inventory.exs`; confirmed the 47-supported-`@spec`
      worklist (extracted per-module list into scratchpad). no_spec total = 82
      (47 supported + 17 deprecated + 18 @doc-false). Drift found:
      `StateInit.basis_state/2` already specced — only `/3` missing.
- [x] [P1-T2] Inventoried tier-1 facade `## Returns` gaps: **55 blocks** missing
      (plan est. ~50); full list + line numbers in scratchpad.
- [x] [P1-T3] Recorded baselines in scratchpad: `mix docs` warning count = 36
      (confirmed) + sorted warning list for the Phase-5 stash-diff gate.
      Confirmed 0 tier-2 moduledocs use the §3 opener today — all 9 need it.

## Phase 2 — `@spec` sweep (47 supported functions)

- [x] [P2-T1] `Qx.Operations` (29): added `@spec` to all gate builders — angle/
      phase → `number()`, qubit indices `non_neg_integer()`, circuit
      `QuantumCircuit.t()`. `tap_*` already specced (skipped).
- [x] [P2-T2] `Qx.QuantumCircuit` (8, bare `t()` style) + `Qx.Draw` (6:
      VegaLite.t()/Image.t()/StateTable.t() returns) + `Qx.Export.OpenQASM` (1:
      to_qasm → String.t()): `@spec` added.
- [x] [P2-T3] `Qx.Math` (normalize/1, probabilities/1 → Nx.Tensor.t()) +
      `Qx.StateInit` (basis_state → Nx.Type.t() dim/index; only /3 was the
      distinct doc entry): `@spec` added.
- [x] [P2-T4] Angle-type unification: widened `rx`/`ry`/`rz`/`phase` facade
      specs `float()` → `number()`. `u`/`cp`/`crx`/`cry`/`crz` already
      `number()` (verified consistent). Compile clean.

## Phase 3 — `## Returns` / `## Raises` on the tier-1 facade

- [x] [P3-T1] Added `## Returns` to all 55 facade blocks lacking it (script,
      doc-block aware: after Parameters/Options, before Examples; prose-only
      `_all/2` variants insert before closing). One-line return descriptions
      (circuit / Nx.Tensor / Enumerable / VegaLite / String). 61 total now.
- [x] [P3-T2] Added grounded `## Raises` to 18 facade fns that provably raise
      typed errors but lacked it (cz/ccx/s/sdg/t/measure_z/barrier/c_if/
      draw_histogram/tap_state/tap_probabilities/`_all/2`×4/barrier_all/2/
      bell_state/ghz_state). Cross-checked each against the delegate's raise
      site (Operations/Patterns). `_all/1`, tap_circuit, draw_bloch/state/circuit,
      version raise nothing (skipped). `superposition` leaks a raw
      FunctionClauseError → deferred (scratchpad), NOT documented as a raise.

## Phase 4 — Moduledocs & doc-rot

- [x] [P4-T1] Tier openers applied. **Deviation from plan's literal "9 tier-2"
      (§3-correct, user AFK — see scratchpad DECISION):** tier-2 opener on the 5
      genuine tier-2 modules (operations/patterns/simulation/export.openqasm/
      hardware; draw already had it); the 3 §3 **tier-1 structs**
      (quantum_circuit/simulation_result/step) got a tier-1 opener instead of
      the "utility module" line. Flagged for merge-gate review.
- [x] [P4-T2] Copied the tier-2 "executes all instructions — use sparingly"
      warning up to facade `tap_state`/`tap_probabilities`. `tap_circuit` (no
      circuit execution → the perf warning would be false) got an accurate
      lighter "debugging aid, no simulation cost" note instead.
- [x] [P4-T3] Fixed openqasm doc-rot: `Qx.circuit(` → `Qx.create_circuit(`,
      `Qx.cnot(` → `Qx.cx(` (3 sites: moduledoc + to_qasm example). Verified
      `draw.ex:15` `histogram/2` resolves to `Qx.Draw.histogram/2` (module's own
      fn) — correct, no fix needed.

## Phase 5 — CHANGELOG & proof

- [x] [P5-T1] CHANGELOG `[Unreleased]`: **Changed** — angle-family `@spec`s
      widened `float()` → `number()`; new **Documentation** section for the
      `@spec`/`## Returns`/`## Raises`/tier-opener/tap-warning/doc-rot sweep.
      Non-breaking, no version bump.
- [x] [P5-T2] Full gate: compile --warnings-as-errors ✓, format --check ✓,
      credo --strict ✓ (no issues), `mix test` ✓ (250 doctests, 1030 tests,
      0 failures).
- [x] [P5-T3] `mix docs` warning count = **36 = baseline** (no movement → no
      stash-diff needed). New `@spec` type refs + openqasm cross-ref fixes all
      autolinked cleanly.
- [x] [P5-T4] Re-ran `api_inventory.exs`: missing @spec 82 → 35 (all 35 are
      deprecated/@doc-false); **0 SUPPORTED functions missing `@spec`**.
      Totals in scratchpad.

## Iron Laws check

- #6: spec widening `float()`→`number()` is additive (non-breaking); CHANGELOG
  entry; no major/minor bump needed (docs + additive spec, release tag-gated).
  No behaviour change anywhere.
- Docs-warning discipline (the real risk): new `@spec`s and cross-ref fixes feed
  ex_doc's autolinker. Gate on `mix docs` warning count ≤ 36; stash-diff the
  lists when it moves. Grep any doc-prose function reference's definition FIRST.
- #7/#9: n/a (no raises added beyond documenting existing ones; no instruction
  shapes touched).

## Risks

1. **Autolink warnings** from new `@spec` type refs / cross-ref edits — the
   `mix docs` stash-diff gate (Phase 5) is the tripwire; counts gate, diffs
   diagnose.
2. **`## Raises` accuracy** — must match actual raise sites; grep the delegate
   targets, don't infer. An over-claimed raise is doc rot the sweep is meant to
   remove.
3. **Scope size** (47 specs + ~50 Returns + 9 openers) — mechanical but large;
   grouped per-module tasks keep it to ~15 tasks. If context pressure appears,
   Phase 2/3 split cleanly by module for `--from` resume.
