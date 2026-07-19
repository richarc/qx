---
module: "Qx"
date: "2026-07-11"
problem_type: documentation_issue
component: api_design
symptoms:
  - "A docs-sweep plan enumerated `quantum_circuit`, `simulation_result`, and `step` among '9 tier-2 moduledocs' and prescribed the §3 tier-2 opener (\"Utility module: reached from `Qx.*` in normal use\") for all nine"
  - "Applying that literal instruction would have stamped a 'utility module' label onto the three structs that `Qx` hands back — which `spec/api-design-principles.md §3` explicitly classifies as **Tier 1** (the taught surface)"
  - "Nothing at compile/credo/test/`mix docs` time flags a wrong-but-well-formed tier label — it is prose; only a human reading §3 catches it"
root_cause: "`spec/api-design-principles.md §3` defines three tiers and gives the 'Utility module: reached from `Qx.*` in normal use' opener as the marker for **Tier 2 only**. Tier 1 is `Qx` plus the structs it returns — `QuantumCircuit`, `SimulationResult`, `Step`. A plan (even a reviewed one) can loosely lump every non-facade public module under 'tier 2', but three of them are tier-1 taught types. Labeling a tier-1 struct as a tier-2 utility in published HexDocs is a documentation defect the toolchain cannot detect. The authoritative tier source is §3, not the plan's shorthand."
severity: medium
tags:
  [
    api-design-principles,
    tier-annotation,
    moduledoc,
    tier-1,
    tier-2,
    plan-vs-spec,
    docs-sweep,
    public-surface,
  ]
related_solutions:
  [
    "docs-warning-stash-diff-catches-phantom-pointer-qx-stateinit-20260708",
  ]
---

# Tier-1 structs are NOT tier-2 utilities — the §3 moduledoc opener does not apply to `QuantumCircuit`/`SimulationResult`/`Step`

## Problem

The docs-sweep (v0.11) plan listed nine modules for a "§3 tier-2 opener"
and included the three struct modules. `§3` classifies those structs as
**Tier 1**. Following the plan verbatim would have published a wrong tier
label; nothing but reading §3 catches it.

## Investigation

`spec/api-design-principles.md §3` ("Three tiers, and the word 'public'
is banned"):

- **Tier 1, taught:** `Qx` plus the structs it hands back —
  `QuantumCircuit`, `SimulationResult`, `Step`.
- **Tier 2, documented utilities:** `StateInit`, `Math`, `Patterns`,
  `Draw`, `Export.OpenQASM`, `Hardware.*`. §3 says these "**open with**
  'Utility module: reached from `Qx.*` in normal use'."
- **Tier 3, internal:** `@moduledoc false`.

`Qx.Draw` already carried the tier-2 opener, which reads as "all
tier-2 modules should," but the opener text is a *tier-2* marker, not a
generic "documented module" marker.

## Resolution

Split the nine by their real §3 tier:

- **Tier-2 opener** applied to the genuine utilities: `Operations`,
  `Patterns`, `Simulation`, `Export.OpenQASM`, `Hardware` (`Draw` already
  had it).
- **Tier-1 opener** for the structs — a distinct line, e.g.:

  ```
  @moduledoc """
  Tier 1: a core Qx type. Circuits are created and threaded by the `Qx.*`
  facade (`Qx.create_circuit/2`, the gate builders, `Qx.run/2`); direct
  use of this module is rarely needed.
  ...
  """
  ```

Also note the CHANGELOG trap: "**Every** tier-2 module now opens with the
§3 marker" over-claims — `Math` and `StateInit` are §3 tier-2 too but
keep their own trimmed-surface framing from the v0.11 tier trim. Name the
exceptions or the claim is false.

## Prevention

- When a plan says "tier-2" for a batch of modules, **re-derive each
  module's tier from `spec/api-design-principles.md §3`** before applying
  a tier-specific opener. The plan's grouping is shorthand, not the tier
  authority.
- The "Utility module: reached from `Qx.*` in normal use" line is a
  **Tier-2-only** marker. Never put it on `Qx`, `QuantumCircuit`,
  `SimulationResult`, or `Step`.
- Wrong tier labels are invisible to compile/credo/test/`mix docs` — a
  §3 read is the only gate. The upcoming v0.11 "Principles-doc
  post-review edits" item (replace Iron Law #6's flat surface list with
  §3 tier annotations) will hit this same fork.
