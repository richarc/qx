# Scratchpad — principles-post-review (v0.11)

## Verified facts (2026-07-12)

- `spec/api-design-principles.md` is NOT an ex_doc extra (mix.exs extras =
  README + CHANGELOG only) → no autolink/docs-warning risk from editing it.
- Exception substance confirmed in code:
  - `Qx.version/0` (qx.ex:1818) — zero-arg, `Application.spec(:qx, :vsn)`.
  - `measure_z/3` — byte-identical to `measure/3` (both call `add_measurement`).
  - `Qx.get_state/2` (simulation.ex) — raises `Qx.MeasurementError` on circuits
    with measurements/conditionals ("Use run/2 instead").
- Tier annotations present: 6 tier-2 openers ("Utility module: reached from
  `Qx.*` in normal use") on Patterns/Simulation/Draw/Operations/Hardware/
  Export.OpenQASM; 3 tier-1 openers ("Tier 1: a core Qx type") on
  QuantumCircuit/SimulationResult/Step.
- **MISSING openers (Risk 2 → in-scope fixes):** StateInit, Math,
  Hardware.Config (tier 2); Draw.Image, Draw.StateTable (tier 1 — structs Qx
  hands back, per §3's own definition).
- **§3 drift found:** its tier-2 list omits `Operations` and `Simulation`,
  which carry the tier-2 opener in code and are declared public in Iron Law #6.
  Correct the §3 list.

## Iron Law #6 rewrite approach

The tier annotation becomes NORMATIVE ("the annotation IS the declaration");
the module enumeration stays as an explicitly-labelled snapshot for
greppability. Preserve verbatim-ish: SemVer minor-as-major pre-1.0 rule +
`~>` example, StateInit/Math trim details, tier-3 examples, typed-`Qx.*Error`
public-contract note. Update the STEP 2 complexity-table row too (it
duplicates the flat list — leaving it would recreate the drift).

## Merge-gate review outcome (2026-07-12)

3× PASS (elixir-reviewer 0 findings — every doc claim verified against code;
testing-reviewer — docs-only confirmed, `git diff main -- test/` empty
(hard-checked by orchestrator); iron-law-judge — substance preserved, 1:1
coverage relabeling, no gap).

Informational notes (pre-existing, out of scope, NOT fixed here):
- `Patterns.superposition_circuit/1` doc carries no deprecation notice — only
  the `Qx.superposition/1` facade is `@deprecated` (deliberate: the
  deprecation-batch self-warn mitigation keeps the impl un-deprecated).
- `Qx.Error` (lib/qx/errors.ex top-level module) has a real moduledoc but no
  tier opener — the typed-error modules sit outside the tier scheme; Iron Law
  #6 already covers them via the "typed `Qx.*Error` exceptions are part of the
  public contract" sentence. Candidate one-liner for a future docs pass.
