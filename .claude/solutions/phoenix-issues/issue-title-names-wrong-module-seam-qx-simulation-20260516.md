---
module: "Qx.Simulation"
date: "2026-05-16"
problem_type: architecture_scoping
component: configuration
symptoms:
  - "ROADMAP/issue qx-53v title: 'Add norm-drift guard and configurable renormalization in CalcFast'"
  - "Qx.CalcFast has no run loop, no run/2, no options — nowhere to plumb a :renormalize opt or a per-N-gates cadence"
  - "Forcing the logic into the named module would have required inventing state/opts in a stateless defn module"
root_cause: "feature placement was driven by the issue/ROADMAP title's named module (CalcFast) rather than the module that actually owns the run-loop + options seam (Qx.Simulation)"
severity: medium
tags: [scoping, architecture, planning, calcfast, simulation, renormalization, qx-53v]
---

# Issue title named CalcFast, but the seam was Qx.Simulation

## Symptoms

qx-53v was titled "Add norm-drift guard and configurable
renormalization **in CalcFast**". Taking the title literally fails:

- `Qx.CalcFast` is a set of **stateless per-gate `defn` kernels**. It
  has no gate loop, no `run/2`, and no options keyword.
- The renormalization *cadence* ("every N gates"), the `:renormalize`
  option, and measurement-time renorm all need a place that owns the
  gate-application loop and the public `run/2` opts.

## Investigation

1. **Hypothesis: add a renorm step to CalcFast kernels** — no seam:
   kernels are single-gate, stateless, backend-portable `defn`; adding
   a loop/opt there would break their contract and duplicate the
   engine.
2. **Trace `run/2`** — `Qx.Simulation.run/2` owns the options keyword
   and the `Enum.reduce` gate loop (`execute_circuit`, the
   conditional `execute_single_shot` timeline). That is the only place
   a per-N-gates cadence and an opt can live.
3. **Root cause found**: the title described the *symptom domain*
   ("float drift in fast calc"), not the *architectural seam*.

## Root Cause

Issue/ROADMAP titles name the area where the problem is *felt*, not
the module that *owns the extension point*. Renormalization needs:
(a) the public option surface — `Qx.Simulation.run/2` / `Qx.run/2`;
(b) the gate-iteration loop — `Qx.Simulation.execute_circuit/2` and
`execute_single_shot/2`. `Qx.CalcFast` has neither. The correct seam
was `Qx.Simulation` (loop + opts) reusing `Qx.Math` (renorm) and
`Qx.Validation` (guard) — and `Qx.CalcFast` stays untouched.

## Solution

Place all logic in `Qx.Simulation`; do not modify `Qx.CalcFast`.
Document the scoping correction in the plan + scratchpad so reviewers
(esp. requirements-verifier / iron-law-judge) don't "fix" it by
forcing logic back into the titled module.

### Files Changed

- `lib/qx/simulation.ex` — `:renormalize` opt, `resolve_renormalize/1`,
  `apply_gate_step/5`, guard; `Qx.CalcFast` NOT in the diff.

## Prevention

- Before placing a feature, find the module that owns the **run loop +
  public options**, not the module named in the issue title.
- Capture the scoping correction explicitly in `scratchpad.md` ("issue
  says X, seam is Y — do not move logic into X") so it survives review.
- [ ] Add to agent checks? requirements-verifier should treat a
  documented, justified scoping correction as expected, not a finding.

## Related

- `.claude/solutions/phoenix-issues/spec-tolerance-below-float32-epsilon-qx-simulation-20260516.md`
  — the numeric-feasibility correction from the same work
