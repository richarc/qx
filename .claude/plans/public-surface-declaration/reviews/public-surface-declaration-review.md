# Review — public-surface-declaration

**Verdict: REQUIRES CHANGES → ALL FINDINGS RESOLVED**

> Post-review fixes applied (re-verified green: format/compile/credo clean,
> 242 doctests + 916 tests, 0 failures):
> - **C1** — `lib/qx/draw/svg/circuit.ex` outer module now `@moduledoc false`
>   (the pre-existing one was on the nested `CircuitDiagram`). #24 now fully
>   closed; CHANGELOG claim now accurate.
> - **W1** — CHANGELOG typed-errors bullet reattributed
>   `Qx.Draw.SVG.Circuit.render/1` → the public `Qx.Draw.circuit/2`.
> - **S1** — `lib/qx.ex` `## Modules` now lists `Qx.SimulationResult` and
>   `Qx.Behaviours.QuantumState`.
> - **S2** — `Qx.Export.OpenQASM.AST` node-type taxonomy preserved as a `#`
>   maintainer comment block (the module is doc-only; taxonomy was its content).
> - **S3** — `Qx.Hardware.Config` one-liner → "… (IBM Quantum via qxportal)".

**Original verdict: REQUIRES CHANGES** (1 real defect; rest is quality polish)

Diff: 15 files (uncommitted on `feat/public-surface-declaration`), −282/+30 lines.
Docs/governance only — no code signatures changed.

## Requirements Coverage (source: plan.md)

Most requirements MET; **one UNMET**:

- **P2-T3 UNMET** — `lib/qx/draw/svg/circuit.ex`: the plan assumed
  `Qx.Draw.SVG.Circuit` "already had `@moduledoc false`". It does **not** — the
  outer module (line 1) still carries a 26-line prose `@moduledoc """…"""`
  (lines 2–27). The `@moduledoc false` at line 31 is on the *nested*
  `CircuitDiagram` module. ExDoc will still publish a `Qx.Draw.SVG.Circuit`
  page, so ROADMAP #24 is only partially closed and the CHANGELOG claim that
  "the `Qx.Draw.SVG.*` sub-modules are now `@moduledoc false`" is factually
  wrong. (Caught independently by requirements-verifier, elixir-reviewer, and
  iron-law-judge.)

The 6 UNCLEAR items are the compile/test gate claims (verifier can't run them);
they were confirmed green this session: 242 doctests + 916 tests, 0 failures.

## Iron Laws

- **Coherence checks pass.** Iron Law #6 (reworded) and #7 are not
  contradictory — an internal `Qx.Validation` raising public `Qx.*Error` types
  is fine. The complexity-score table row matches the #6 surface list exactly.
- The 11 modules that *did* receive `@moduledoc false` are all legitimately
  internal; no public function or doctest was lost (testing-reviewer confirmed
  the 245→242 delta is fully the 3 Validation moduledoc doctests).

## Findings

### Must fix

- **C1 (BLOCKER) — `Qx.Draw.SVG.Circuit` outer moduledoc not hidden**
  (`lib/qx/draw/svg/circuit.ex:2-27`). Replace the outer module's
  `@moduledoc """…"""` with `@moduledoc false` (leave the nested
  `CircuitDiagram` one alone). This is the P2-T3 gap above.

### Should fix (quality)

- **W1 (WARNING) — CHANGELOG attributes `render/1` to an internal module.** The
  pre-existing typed-errors `### Changed` bullet lists
  `Qx.Draw.SVG.Circuit.render/1` (5 sites) as a retyped surface. Now that the
  module is declared internal, pin the observable behaviour to the public entry
  point (`Qx.Draw.circuit/2`) instead of the internal function. Minor /
  pre-existing text.
- **S1 (SUGGESTION) — `lib/qx.ex` `## Modules` list still omits
  `Qx.SimulationResult` and `Qx.Behaviours.*`.** Both are in the Iron Law #6
  declared surface; the diff was already editing this list, so it's the natural
  moment to add them. (iron-law-judge)
- **S2 (SUGGESTION) — `Qx.Export.OpenQASM.AST` lost its node-type taxonomy**
  (`ast.ex`, −47 lines). The deleted prose described the AST node shapes —
  structural contracts hard to reconstruct from codegen/lowering. Consider
  preserving the taxonomy as `#` comments or `@type` declarations inside the
  module. (elixir-reviewer)
- **S3 (SUGGESTION) — `Qx.Hardware.Config` one-liner undersells specificity.**
  "Hardware backend configuration" reads generic; the module is IBM-Quantum-
  via-qxportal specific. Suggest "Hardware backend configuration (IBM Quantum
  via qxportal)". (elixir-reviewer)

## Bottom line

The governance edits (AGENTS.md Iron Laws, complexity table, CHANGELOG) and 11
of 12 `@moduledoc false` substitutions are correct and coherent. One mechanical
step was skipped — the `Qx.Draw.SVG.Circuit` outer moduledoc — which makes #24
incomplete and the CHANGELOG inaccurate; that must be fixed before merge. W1/S1–S3
are small, in-scope polish.
