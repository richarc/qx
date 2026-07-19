# Iron Law Judge Report — `docs/principles-post-review` (Iron Law #6 rewrite)

**Tooling note:** this agent has no Bash access, so `git --no-pager diff main`
could not be executed directly. Verification below was performed by reading
the current (post-change) state of `AGENTS.md`/`CLAUDE.md` (symlinked),
`spec/api-design-principles.md`, and the five edited moduledocs, then
cross-checking every substance item the task listed against that text, and
grepping `lib/` for the tier-annotation openers to confirm coverage. This is
equivalent in outcome to a diff review for items 1–4 (which all concern
*current-state* presence/consistency), but a literal old-vs-new line diff was
not produced.

## Summary

- Checks requested: 4
- Violations found: 0
- Verdict: **PASS**

## Check 1 — Substance preservation

All four required elements are present, verbatim-equivalent, in the
rewritten Iron Law #6 (`AGENTS.md`/`CLAUDE.md`, "Public API surface" §, law 6):

- **SemVer rule** — present: "major version once ≥ 1.0.0; while < 1.0.0 the
  minor version plays that role, per Hex `~>` semantics (`~> 0.10` pins
  `< 0.11.0` — the v0.10.0 calc-mode demotion shipped correctly as a minor
  bump). Patch releases (0.x.PATCH) must never break." — confidence: DEFINITE.
- **StateInit/Math trimmed-surface details** — present: "the supported
  surface is `StateInit.basis_state/2,3` and `Math.normalize/1` +
  `Math.probabilities/1`; every other function in those two modules is
  `@deprecated` and will be removed at 1.0 (still working until then —
  removing one earlier is a breaking change)." Matches the moduledocs
  (`lib/qx/state_init.ex:8`, `lib/qx/math.ex:9`). — DEFINITE.
- **Tier-3 examples** — present: "`Qx.Validation`, `Qx.Qubit` and
  `Qx.Register` … `Qx.Behaviours.QuantumState` (demoted v0.11 per finding
  R-13), the `Qx.Draw.SVG.*` and `Qx.Export.OpenQASM.*` sub-modules, and
  `Qx.Hardware.Ibm` / `Qx.Hardware.Portal`." Cross-checked against
  `@moduledoc false` grep — all listed modules do carry `@moduledoc false`
  (`lib/qx/validation.ex:2`, `lib/qx/qubit.ex:7`, `lib/qx/register.ex:7`,
  `lib/qx/behaviours/quantum_state.ex:8`, `lib/qx/draw/svg/circuit.ex:2,6`,
  `lib/qx/draw/svg/bloch.ex:2`, `lib/qx/export/openqasm/{ast,codegen,lowering,
  parser,expr}.ex:2`, `lib/qx/hardware/ibm.ex:2`, `lib/qx/hardware/portal.ex:2`).
  — DEFINITE.
- **Typed `Qx.*Error` public note** — present: "The typed `Qx.*Error`
  exceptions are part of the public contract even though `Qx.Validation`
  (which raises them) is not." — DEFINITE.

**Status: PASS** — no substance lost.

## Check 2 — No coverage gap (old flat list vs. new tier-annotation definition)

Old flat list (15 entries incl. `Qx`): `Qx`, `Qx.QuantumCircuit`,
`Qx.Operations`, `Qx.Simulation`, `Qx.SimulationResult`, `Qx.Step`,
`Qx.StateInit`, `Qx.Patterns`, `Qx.Math`, `Qx.Hardware`, `Qx.Hardware.Config`,
`Qx.Export.OpenQASM`, `Qx.Draw`, `Qx.Draw.Image`, `Qx.Draw.StateTable`.

Grepped `lib/` for the two tier openers (`"Tier 1: a core Qx type"` /
`"Utility module:"`); every non-facade module in the old list resolves to
exactly one hit:

| Module | File | Opener found |
|---|---|---|
| `Qx.QuantumCircuit` | `lib/qx/quantum_circuit.ex:3` | Tier 1 |
| `Qx.SimulationResult` | `lib/qx/simulation_result.ex:3` | Tier 1 |
| `Qx.Step` | `lib/qx/step.ex:3` | Tier 1 |
| `Qx.Draw.Image` | `lib/qx/draw/image.ex:3` | Tier 1 |
| `Qx.Draw.StateTable` | `lib/qx/draw/state_table.ex:3` | Tier 1 |
| `Qx.Operations` | `lib/qx/operations.ex:3` | Utility module |
| `Qx.Simulation` | `lib/qx/simulation.ex:3` | Utility module |
| `Qx.Patterns` | `lib/qx/patterns.ex:3` | Utility module |
| `Qx.StateInit` | `lib/qx/state_init.ex:3` | Utility module |
| `Qx.Math` | `lib/qx/math.ex:3` | Utility module |
| `Qx.Draw` | `lib/qx/draw.ex:5` | Utility module |
| `Qx.Hardware` | `lib/qx/hardware.ex:3` | Utility module |
| `Qx.Hardware.Config` | `lib/qx/hardware/config.ex:3` | Utility module |
| `Qx.Export.OpenQASM` | `lib/qx/export/openqasm.ex:3` | Utility module |

`Qx` itself is the facade, exempted by name in the law text ("plus the `Qx`
facade itself") — `lib/qx.ex` carries a plain `@moduledoc` (no opener
required for the facade).

14/14 non-facade modules from the old list carry a tier opener; no module is
newly uncovered.

**Status: PASS** — no coverage gap.

## Check 3 — No module gained/lost tier silently

New tier-1 ∪ tier-2 snapshot in the rewritten law = `Qx`, `Qx.QuantumCircuit`,
`Qx.SimulationResult`, `Qx.Step`, `Qx.Draw.Image`, `Qx.Draw.StateTable`
(tier 1) + `Qx.Operations`, `Qx.Simulation`, `Qx.Patterns`, `Qx.StateInit`,
`Qx.Math`, `Qx.Draw`, `Qx.Hardware`, `Qx.Hardware.Config`,
`Qx.Export.OpenQASM` (tier 2) = **15 entries**, an exact 1:1 match (by name)
with the 15-entry old flat list. `Qx.Operations`/`Qx.Simulation` "added to
tier 2" and `Qx.Draw.Image`/`Qx.Draw.StateTable` "added to tier 1" are
re-labelings of modules the old flat list already enumerated — no net
SemVer-coverage change, confirmed by the moduledoc content read directly
(`lib/qx/operations.ex:3`, `lib/qx/simulation.ex:3`, `lib/qx/draw/image.ex:3`,
`lib/qx/draw/state_table.ex:3` — all read and consistent with the
tier/snapshot text).

**Status: PASS** — §3 corrections are relabelings, not coverage changes.

## Check 4 — STEP 2 complexity table no longer carries a stale flat list

Current STEP 2 row (`AGENTS.md`/`CLAUDE.md`): "Changes public API of any
tier 1/2 module — the Iron Law #6 surface, defined by the moduledoc tier
annotations (openers `"Tier 1: a core Qx type"` / `"Utility module: …"`; see
`spec/api-design-principles.md` §3)". No flat module list appears in this
row; it defers entirely to the tier-annotation definition.

**Status: PASS**.

## Minor observation (non-blocking, informational only)

`lib/qx/errors.ex` (`Qx.Error`, the placeholder base exception) has a real
`@moduledoc` but no tier opener and no `@moduledoc false`. This predates the
diff under audit and is explicitly out of scope for it — the rewritten law
separately calls out typed `Qx.*Error` exceptions as "part of the public
contract even though `Qx.Validation` … is not," treating exceptions as a
distinct category from the tier system, not a module requiring a tier
opener. Not a finding against this branch; flagging only for awareness if a
future pass tightens "every module … a finding" language to cover exception
modules too.

## Verdict

**PASS** — the Iron Law #6 rewrite preserves all required substance,
introduces no coverage gap against the old flat list, the §3 relabelings are
coverage-neutral, and the STEP 2 table no longer duplicates a stale flat
list.
