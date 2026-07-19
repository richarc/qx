# Test Review: test/qx_manual_test.livemd

## Summary

This is a manual, human-eyeballed visual test suite (Livebook), not an
ExUnit suite — the standard Iron Laws (async, Sandbox, Mox, factories)
do not apply; the equivalent discipline here is: every `# Expected:`
must be specific and checkable by eye, every exact claim must be backed
by a deterministic (measurement-free or seeded) cell, and coverage
should span the tier-1 visual/interactive surface the intro (line 16)
promises: "exercises every visual and interactive surface of the tier-1
API."

The notebook is well-constructed: math in the `# Expected:` comments
was independently re-derived (Bloch positions, Bell/GHZ probabilities,
the CP(π/2) interference distribution [00]=0.625/[01,10,11]=0.125 each,
the teleportation 25/75 signature from θ=2π/3) and all check out. Section
ordering is pedagogically sound (single → two → three qubit gates →
entanglement → circuit diagrams → measurement → stepper → patterns →
QASM → bases → teleportation capstone). Determinism discipline is
consistently observed — every cell with an exact numeric/count claim is
either measurement-free or explicitly labeled "approximately" /
"stochastic," and the two seeded cells (`steps(seed: 1)`, `steps(seed:
2)`) are the only places exact per-shot/per-step output is asserted.

The main gap is coverage: several tier-1/2 visual/interactive surfaces
are entirely absent, which contradicts the notebook's own "every visual
and interactive surface" framing in the introduction.

## Issues Found

### Critical

None. No exact-output claim was found on a genuinely stochastic cell,
and no correctness bug was found in the expected-value math.

### Warnings

- [ ] **Controlled-rotation/controlled-Y gates have zero visual
  coverage**: `Qx.cy/3`, `Qx.crx/4`, `Qx.cry/4`, `Qx.crz/4` are public,
  Tier-1-adjacent gates (delegated straight through the `Qx` facade,
  `lib/qx.ex:397-460`) with no Bloch-sphere, histogram, or
  `draw_circuit` cell anywhere in the notebook. Numeric correctness may
  live in the automated suite, but *visual rendering* of these gates
  (how `draw_circuit` labels a controlled-rotation gate, what the
  post-gate histogram looks like) is only checked by a human via this
  notebook — and it isn't checked at all. Given the intro's explicit
  "every visual and interactive surface" claim, either add one cell per
  gate (a two-qubit histogram cell mirroring the CX/CZ pattern in §2 is
  enough) or soften the intro's completeness claim to name the excluded
  surface.
- [ ] **`tap_circuit/2`, `tap_state/2`, `tap_probabilities/2` are
  entirely absent** (`lib/qx.ex:1850-1904`). These are explicitly
  interactive/pipeline-debugging helpers — arguably the single feature
  most purpose-built for a Livebook manual-test context — yet no cell
  demonstrates them. Suggest adding one short cell showing
  `tap_state(fn state -> ... end)` mid-pipeline with an `# Expected:`
  describing the side-effect output alongside the returned circuit.
- [ ] **Intro overclaims completeness** (line 16): "exercises every
  visual and interactive surface of the tier-1 API" is not accurate
  given the above two gaps. Either close the gaps or rephrase to scope
  the claim (e.g., "the tier-1 visual/interactive surfaces exercised
  below" or an explicit "not covered: cy/crx/cry/crz visuals, tap_*").

### Suggestions

- [ ] `Qx.Patterns` broadcast helpers `x_all/y_all/z_all`,
  `measure_all`, `barrier_all` are untested visually; only `h_all` (two
  arities) is shown. Since these follow the identical code path as
  `h_all`, this is low-value to add — note only if reviewers want full
  enumeration for documentation purposes.
- [ ] `Qx.barrier/2` is only exercised in range form (`0..2`, `0..1`);
  the list form (`Qx.barrier([0,1,2])`) mentioned in the section-8
  prose ("appenders... at chosen qubits") is never actually shown for
  barrier itself. Minor — the range form is the v0.11 feature under
  test.
  and the section header explicitly calls out range support as the
  point of the cell.
- [ ] `Qx.draw_state/1` is only shown with `hide_zeros: true`; a single
  cell without that option (showing the full amplitude table including
  zero entries) would round out the option coverage, though this is
  cosmetic.
- [ ] The generic `Qx.draw/2` (aliased to `Draw.plot`) is never invoked
  — likely fine to omit since every specific `draw_*` variant used
  supersedes it, but worth a one-line note in the plan/scratchpad if
  `draw/2` is meant to be a distinct supported entry point.

## Determinism Discipline (detail)

Verified case-by-case — no violations found:
- All `get_probabilities()`/`get_state()` cells (no `run`/measurement)
  correctly claim exact values (Bell/GHZ/CP interference/preset states)
  — these are measurement-free and deterministic.
- All `Qx.run(shots: ...)` cells without a seed are labeled
  "approximately" / describe the stochastic nature explicitly (§6, §10
  Z-basis cell, teleportation statistical-check cell) — correct.
- `measure_x`/`measure_y` on eigenstates claim an exact "ALL 1024" —
  this is legitimate: the outcome is forced by the input being an
  eigenstate of the measurement basis, not by a seed, so an exact claim
  without `seed:` is valid physics, not a discipline violation.
- The two `steps(seed: N)` cells are the only places an exact
  measurement/step trajectory is asserted, and both are correctly
  seeded.

## Structure

- Section order (1 single-qubit → 2 two-qubit → 3 three-qubit → 4
  entanglement/presets → 5 circuit diagrams → 6 measurement/c_if → 7
  stepper → 8 patterns → 9 QASM → 10 bases → 11 teleportation capstone)
  builds concept-on-concept sensibly.
- Cross-cell bindings (`pi` from the setup cell, `theta`/`teleport`
  within §11) are scoped sanely — `pi` is workspace-global and used
  throughout (expected for a Livebook meant to run top-to-bottom);
  `theta`/`teleport` are local to the capstone section and reused only
  within that section's three cells, which is the only place a binding
  crosses cell boundaries beyond the global `pi`. This is normal
  Livebook idiom, not a smell.

## Verdict

**CHANGES-REQUESTED** — not for correctness (no bug found in any
expected value or determinism claim) but for the coverage gap against
the notebook's own stated scope: `cy`/`crx`/`cry`/`crz` and the
`tap_*` functions are tier-1/2 visual/interactive surfaces with zero
manual-suite coverage, directly contradicting the introduction's
"exercises every visual and interactive surface of the tier-1 API"
claim. Recommend either adding the missing cells (roughly 2 more cells:
one controlled-rotation histogram + one tap_* demo) or narrowing the
intro's claim to match actual scope before merge.

**Counts**: 0 Critical, 3 Warnings, 4 Suggestions.
