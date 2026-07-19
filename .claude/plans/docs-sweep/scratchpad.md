# Scratchpad — docs-sweep

## Decisions (user-confirmed 2026-07-11)

1. **Deprecated functions EXEMPT** — worklist is the 47 supported fns missing
   `@spec`, not all 82. The 17 deprecated + 24 `@doc false` are skipped.
2. **Specs/docs only — NO doctests** this sweep (deferred).

## Grounded inventory (fresh `api_inventory.exs`, 2026-07-11)

Totals: 192 tier-1/2 functions · missing @doc: 0 · @doc false: 24 · missing
@spec: **82** · deprecated: 17.

**47 SUPPORTED missing @spec** (the worklist), by module:
- `Qx.Operations` — 29 (gate builders; angle params → `number()`)
- `Qx.QuantumCircuit` — 8
- `Qx.Draw` — 6
- `Qx.Math` — 2 (supported trio: `normalize`/`probabilities`)
- `Qx.StateInit` — 1 (`basis_state`)
- `Qx.Export.OpenQASM` — 1
(other 35 missing-spec rows are deprecated/@doc-false → skip)

Fully-specced already (skip): facade `Qx` (61), `Simulation`, `Patterns`,
`SimulationResult`, `Step`.

## Concrete sites gathered at plan time

- **Angle-type `float()` specs to widen → `number()`**: lib/qx.ex:512 (rx),
  534 (ry), 556 (rz), 578 (phase). Verify `u`/`cp`/`crx`/`cry`/`crz` too.
- **`tap_*` warning**: lives in `Qx.Operations` docs (tier 2) + qubit.ex; the
  facade `Qx.tap_circuit`/`tap_state`/`tap_probabilities` (qx.ex ~1380–1420)
  need the loud debugging-only warning copied up (tension #4).
- **Doc-rot cross-refs**:
  - `lib/qx/export/openqasm.ex:87,89,166` — `Qx.circuit(2)` → `Qx.create_circuit(2)`;
    `Qx.cnot(0,1)` → `Qx.cx(0,1)` (stale/non-existent facade names).
  - `lib/qx/draw.ex:15` table lists `histogram/2`; qx.ex:1089,1120 reference
    `draw_histogram/2`. Verify which name is correct and that the cross-ref
    resolves (grep the def FIRST).
- **Tier-annotation openers**: ZERO tier-2 moduledocs use the tier convention
  today (all 9 need the §3 opener). StateInit/Math trim used
  "supported surface"/"deprecated" prose, not the literal `spec §3` opener —
  read `spec/api-design-principles.md §3` for the exact wording before applying.

## Baselines (Phase 1 recorded 2026-07-11)

**Re-run api_inventory.exs:** 192 rows; missing @spec 82; @doc false 24;
deprecated 17. SUPPORTED-missing-@spec worklist = 47, matches plan:
- Qx.Operations 29: barrier/2 c_if/4 ccx/4 cp/4 crx/4 cry/4 crz/4 cswap/4
  cx/3 cy/3 cz/3 h/2 iswap/3 measure/3 measure_x/3 measure_y/3 measure_z/3
  phase/3 rx/3 ry/3 rz/3 s/2 sdg/2 swap/3 t/2 u/5 x/2 y/2 z/2
- Qx.QuantumCircuit 8: depth/1 get_instructions/1 get_measurements/1
  get_state/1 new/1 new/2 reset/1 set_state/2
- Qx.Draw 6: bloch/2 circuit/2 counts/2 histogram/2 plot/2 state_table/2
- Qx.Math 2: normalize/1 probabilities/1
- Qx.StateInit 1: **basis_state/3 only** (drift: plan said /2,3 — /2 already
  has @spec; only /3 missing)
- Qx.Export.OpenQASM 1: to_qasm/2

**mix docs warning count baseline: 36** (confirmed). Sorted list for Phase-5
stash-diff gate:
```
   2 references function "Qx.Patterns.bell_state_circuit/1" but it is hidden
   2 references function "Qx.Patterns.ghz_state_circuit/1" but it is hidden
   2 references module "Qx.Hardware.Ibm" but it is hidden        (col-aligned A)
   2 references module "Qx.Hardware.Portal" but it is hidden      (col-aligned A)
   6 references type "Qx.Hardware.ConfigError.t()" undefined/private
   2 references type "Qx.Hardware.NoMeasurementsError.t()" undefined/private
   2 Illegal attributes ["1", "[0],", "rz,"] ignored in IAL
   2 references function "Qx.Hardware.Ibm.iam_exchange/1" but it is hidden
   6 references module "Qx.Hardware.Ibm" but it is hidden         (col-aligned B)
   4 references module "Qx.Hardware.Portal" but it is hidden      (col-aligned B)
   2 references file "LICENSE" but it does not exist
   2 references file "RELEASE.md" but it does not exist
   2 references file "ROADMAP.md" but it does not exist
```

**Facade `## Returns` inventory (Phase 3 worklist): 55 blocks missing** (plan
said ~50). Existing `## Returns` sit AFTER `## Parameters`/`## Options`,
BEFORE `## Examples`. The 6 already-present: run/2 (914), + 5 more at
1104/1137/1205/1248/1284. The 55 missing (by first head line): create_circuit
102/123, h 145, x 167, y 189, z 211, cx 234, cz 254, swap 277, iswap 302,
cp 328, cy 344, crx 361, cry 378, crz 395, ccx 415, cswap 441, s 457, sdg 475,
t 491, rx 513, ry 535, rz 557, phase 579, u 614, measure 636, measure_z 649,
measure_x 666, measure_y 683, h_all 699/712, x_all 724/731, y_all 743/750,
z_all 762/769, measure_all 788/800, barrier 819, barrier_all 831/838,
cx_chain 857, c_if 895, get_state 981, get_probabilities 1011, steps 1079,
draw_histogram 1184, bell_state 1331, ghz_state 1356, superposition 1373,
version 1385, tap_circuit 1409, tap_state 1426, tap_probabilities 1443.

**§3 tier-2 opener:** confirmed 0 tier-2 moduledocs use it today; all 9 need
it. Wording from api-design-principles.md §3: tier-2 modules open with
*"Utility module: reached from `Qx.*` in normal use"*.

## Discovered during Phase 3 (out of scope — record & defer)

- **`Qx.superposition/1` leaks `FunctionClauseError`** (Iron Law #7 violation).
  `Qx.Patterns.superposition_circuit/1` has a single guarded clause
  (`when is_integer(num_qubits) and num_qubits >= 1`) with **no typed fallback**,
  so `Qx.superposition(0)` / `Qx.superposition(:x)` raise a raw
  `FunctionClauseError` instead of `Qx.QubitCountError`. Its siblings
  `ghz_state_circuit` (raises `QubitCountError`) and `bell_state_circuit`
  (raises `OptionError`) both have typed fallbacks — superposition is the
  odd one out. Fix = add a fallback clause routing to `Qx.QubitCountError`
  (mirrors ghz). Deliberately NOT documented as a `## Raises` in this sweep
  (would be documenting a raw error). → **new `fix/superposition-typed-error`
  candidate**; added to ROADMAP v0.11 typed-error follow-ons if not already.

## Phase 3/4 note
- `Qx.Draw` moduledoc **already carries** the §3 tier-2 opener
  ("Utility module: reached from `Qx.*` in normal use") — so Phase-1's
  "0 tier-2 openers" was slightly off. Phase 4 must grep each of the 9 and
  only add the opener where missing (Draw is done).

## DECISION for merge-gate review — Phase 4 tier openers (user was AFK)

Plan Phase-4 T1 said "9 tier-2 moduledocs" and listed `quantum_circuit`,
`simulation_result`, `step` among them. But `spec/api-design-principles.md §3`
classifies those three as **Tier 1** ("`Qx` plus the structs it hands back —
`QuantumCircuit`, `SimulationResult`, `Step`"). The §3 opener wording
"Utility module: reached from `Qx.*` in normal use" is explicitly a **Tier-2**
marker. Labelling a taught struct as a tier-2 utility in HexDocs would be wrong.

I asked via AskUserQuestion; no response in 60s (AFK). Proceeded with the
**spec-correct** reading (Option 1):
- **Tier-2 opener** ("Utility module: reached from `Qx.*` in normal use — …")
  applied to the 5 genuine tier-2 modules: `operations`, `patterns`,
  `simulation`, `export/openqasm`, `hardware`. (`draw` already had it → 6/6.)
- **Tier-1 opener** ("Tier 1: a core Qx type …") applied to `quantum_circuit`,
  `simulation_result`, `step` — NOT the tier-2 utility line.

If the human prefers the plan's literal "tier-2 line on all 9", the three
struct openers are the only thing to change (one line each). Flagged here +
in the completion summary.

Also: `export/openqasm` and `hardware` have no `Qx.*` facade delegate yet (the
QASM/Hardware facade is the separate v0.11 additive package), so their opener
tails are phrased as "documented tier-2 surface/escape hatch" rather than
naming a facade fn.

## Phase 5 completion proof (2026-07-11)

- `api_inventory.exs`: missing @spec **82 → 35** (35 = 17 deprecated + 18
  @doc-false). **SUPPORTED functions missing @spec = 0** ✓ (worklist cleared).
- `mix docs` warning count: **36 → 36** — no movement, so no stash-diff needed.
  New @spec type refs (`Nx.Type.t()`, `VegaLite.t()`, `Image.t()`,
  `StateTable.t()`, exception refs in `## Raises`) and the openqasm cross-ref
  fixes all autolinked cleanly.
- Full gate: compile --warnings-as-errors ✓, format --check ✓, credo --strict
  (see below), test (see below).

## Post-review fixes (2026-07-11, merge gate PASS)

Review: 5 agents, 0 BLOCKERs, PASS WITH WARNINGS → fixes applied → PASS.
- CHANGELOG "every tier-2 module" over-claim → reworded (names the 6 modules;
  Math/StateInit keep trim framing).
- StateInit moduledoc `basis_state/3` → `basis_state/2,3`.
- Tier-1 struct opener deviation: **user confirmed §3-correct choice stands**
  (QuantumCircuit/SimulationResult/Step keep tier-1 opener).
Re-verified: compile/format/credo(0)/docs=36 all ✓. Awaiting merge authorization.

## For later cycles
- **Doctest gaps** (deferred from this sweep): the finding notes doctest gaps on
  Operations/QuantumCircuit/Draw — the modules where the @spec counts hid. Track
  as a follow-up (own plan) since doctests are test authoring (TDD hook) not
  mechanical doc edits.
