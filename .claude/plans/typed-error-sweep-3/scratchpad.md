# Scratchpad — typed-error-sweep-3

## Open decisions / VETO POINTS (made by default while user AFK)

1. **normalize(zero-vector) → raise `Qx.StateNormalizationError`**
   (alternatives rejected: ok/error tuples = breaking pipeline shape on a
   survivor fn; doc-the-NaN = leaves R-09 open). User was AFK at the
   AskUserQuestion — confirm at plan review.
2. **normalize defn→def wrapper** (private `defn normalize_unchecked`):
   observable to anyone composing normalize inside their own defn.
   Judged acceptable (tutorials teach host-side use only).
3. **filter_by_probability widens to `is_number`** — integer 0/1 become
   VALID (additive) rather than raising; only out-of-range/non-number
   raise. Rationale: 1 is a legitimate probability; raising on it would
   be pedantry.

## Facts verified 2026-07-08 (supersede the ROADMAP line where they differ)

- `create_circuit` OOR-integer already raises `Qx.QubitCountError`
  (sweep #2); the remaining raw path is NON-INTEGER args, and the
  `## Raises` blocks in lib/qx.ex (96–99, 118–121, ~141) honestly
  advertise FunctionClauseError — docs fix + fallback clause both needed.
- "seven StateInit constructors" in ROADMAP are deprecated since the
  tier trim (61bd8af) — sweep covers `basis_state/2,3` ONLY (per
  tier-trim scratchpad "do not add validation to them").
- `add_gate/3,4` (quantum_circuit.ex:93, guard `is_atom(gate_name) and
  is_integer(qubit)`) is the single choke point for the single-qubit
  wrapper family — h(qc, "0") falls through there, NOT in operations.ex.
  Two-/three-qubit builders need the same treatment (verify in P1).
- `c_if/4` already raises typed ClassicalBitError/ConditionalError for
  3 misuse shapes (operations.ex:759–771); the remaining hole is
  NON-INTEGER classical_bit falling through all four clauses.
- `validate_parameter!/1` exists (validation.ex:142–146, raises
  `Qx.ParameterError`); u/5 (operations.ex:292–296) + cp/crx/cry/crz
  already call it; rx/ry/rz/phase (operations.ex:190,210,230,250) do not.
- `filter_by_probability` guard `is_float(threshold)` (simulation_result
  .ex:102) — integer 1 FCEs today.
- normalize callers in lib/: simulation.ex:438,445 (renorm hot path —
  must go through the unchecked internal), qubit.ex:89,94,~160 (random
  paths, never zero-norm by construction), state_init.ex:231 (deprecated
  random_state). Tutorial (qxportal quantum_state_and_qubit.livemd)
  teaches direct Math.normalize — the public wrapper is the user path.
- ZERO `assert_raise FunctionClauseError` in test/ — Phase 2 is purely
  additive (one new hook-guarded test file), no existing-test edits.
- Sweep #1/#2 precedents: reuse existing error types with new reason
  variants (e.g. QubitIndexError {:duplicate, …}); wholesale grep as
  completion proof; misuse-raise changes ship non-breaking in a minor.

## Baselines (Phase 1 — recorded 2026-07-10)

### Per-site current-error probe (all confirm findings; probe.exs in session scratchpad)

| Site | Current behaviour |
|---|---|
| `create_circuit("2")` | FCE `QuantumCircuit.new/1` |
| `create_circuit(2, "0")` | FCE `QuantumCircuit.new/2` |
| `create_circuit(2, -1)` | FCE `QuantumCircuit.new/2` |
| `bell_state_circuit(:bogus)` | FCE `Patterns.bell_state_circuit/1` |
| `ghz_state_circuit(1)` / `(:x)` | FCE `Patterns.ghz_state_circuit/1` |
| `h(qc, "0")` | FCE `QuantumCircuit.add_gate/4` |
| `cx(qc, "0", 1)` | FCE `QuantumCircuit.add_two_qubit_gate/5` |
| `c_if(qc, "0", 0, fun)` | FCE `Operations.c_if/4` |
| `basis_state("0", 2)` / `(-1, 2)` / `(5, 2)` | FCE `StateInit.basis_state/3` |
| `filter_by_probability(result, 1)` / `(result, 2)` | FCE `filter_by_probability/2` |
| `Math.normalize(zero)` | **NO RAISE → `[NaN, NaN]`** (silent bug R-09) |
| `rx(qc, 0, "pi")` | **NO RAISE** → stores `{:rx, [0], ["pi"]}`, detonates later |

### Grep baseline
- `FunctionClauseError` in lib/: qx.ex:99,121 (IN SCOPE), gates.ex:404,451
  (`@moduledoc false` — exempt), state_init.ex:326 (deprecated
  `ghz_state_vector` — out of scope), quantum_circuit.ex:53 & codegen.ex:226
  (code comments — leave).
- ZERO `assert_raise FunctionClauseError` in test/. All test-file FCE mentions
  are explanatory comments ("now raises typed, not FCE"). No tripwires.

### Baselines
- `mix docs` warning count: **36** (confirmed; Phase 6 gate: ≤ 36 after)
- bench baseline: session `scratchpad/bench_baseline.txt` (renormalization_bench)

## Exception-shape decisions (Phase 1 task 2)

New reason variants to ADD (each placed BEFORE the existing catch-all clause):
- `Qx.QubitCountError.exception({:not_an_integer, value})` → "Number of qubits
  must be an integer, got: …" (for non-integer num_qubits & ghz non-integer)
- `Qx.QubitIndexError.exception({:not_an_integer, value})` → "Qubit index must
  be an integer, got: …" (single/two-qubit non-integer; three-qubit already
  raises a binary "must be integers" — leave, already typed)
- `Qx.ClassicalBitError.exception({:not_an_integer, value})` → "Classical bit
  index must be an integer, got: …"; `{:invalid_count, value}` → "Number of
  classical bits must be a non-negative integer, got: …"
- `Qx.BasisError` — add `:reason`/`:dimension` fields + tuple clauses
  (`{:not_an_integer, v}`, `{:negative, v}`, `{:out_of_range, index, dim}`,
  `{:invalid_dimension, v}`); KEEP the final `exception(value)` catch-all
  (existing "Basis must be 0 or 1" tests depend on it — tuple clauses first).
- `Qx.OptionError.exception({option, value, hint})` already exists → reuse for
  `{:which, :bogus, hint}` (bell) and `{:threshold, value, hint}` (filter).

New `Qx.Validation` helpers:
- `validate_num_qubits!/1` non-integer fallback → QubitCountError `{:not_an_integer,…}`
- `validate_qubit_index!/2` non-integer fallback → QubitIndexError `{:not_an_integer,…}`
- `validate_num_classical_bits!/1` → ClassicalBitError (non-integer/negative)
- `validate_probability!/1` → OptionError `{:threshold,…}` for filter threshold
- basis: validate inline in `StateInit.basis_state` fallback (no shared helper needed)

## Phase 6 completion proof — probe re-run (2026-07-10, post-implementation)

Every mapped site now raises its typed error; `filter(result, 1)` returns `%{}`:

| Site | After |
|---|---|
| `create_circuit("2")` | `Qx.QubitCountError` "must be an integer" |
| `create_circuit(2, "0")` / `(2, -1)` | `Qx.ClassicalBitError` "non-negative integer" |
| `bell_state_circuit(:bogus)` | `Qx.OptionError` `:which` |
| `ghz_state_circuit(1)` | `Qx.QubitCountError` "between 2 and 20" |
| `ghz_state_circuit(:x)` | `Qx.QubitCountError` "must be an integer" |
| `h(qc, "0")` / `cx(qc, "0", 1)` | `Qx.QubitIndexError` "must be an integer" |
| `c_if(qc, "0", 0, fun)` | `Qx.ClassicalBitError` "must be an integer" |
| `basis_state("0", 2)` | `Qx.BasisError` `:not_an_integer` |
| `basis_state(-1, 2)` | `Qx.BasisError` `:negative` |
| `basis_state(5, 2)` | `Qx.BasisError` `:out_of_range` |
| `filter_by_probability(result, 1)` | **RETURNS `%{}`** (widening) |
| `filter_by_probability(result, 2)` | `Qx.OptionError` `:threshold` |
| `Math.normalize(zero)` | `Qx.StateNormalizationError` |
| `rx(qc, 0, "pi")` | `Qx.ParameterError` (build time) |

## Post-review fixes (2026-07-10, /phx:review = PASS WITH WARNINGS → all warnings addressed)

Review: 5 agents, 0 Iron Law violations, 0 UNMET requirements, all gates PASS.
Three non-blocking warnings, all fixed:

- **W1** — `QuantumCircuit.new/1,2` and `SimulationResult.filter_by_probability/2`
  fallbacks relied on emergent validator exhaustiveness (could return `:ok`,
  violating `@spec`, if a validator guard were later edited). **Fix:** collapsed
  each into a SINGLE unguarded clause that validates up front
  (`validate_num_qubits!` + `validate_num_classical_bits!`; `validate_probability!`)
  then does the work — no guard/fallback coupling. `validate_probability!/1` is
  now the single source of truth for the threshold. (credo mods/funs 920→917.)
- **W2** — strengthened two weak tests: filter integer-1 now also asserts a
  certain outcome (count==shots) is kept (pins `min_count = 1*shots`, not just
  no-raise); c64 normalize survivor now asserts 1/√2 real parts + ~0 imag, not
  just the `{:c,64}` type.
- **W3** — `create_circuit`/`h`/`cx` tests swapped `~r/must be an integer/`
  message-regex for field checks (`e.count`/`e.qubit == "..."`).

Re-verified: compile/format/credo clean, new file 25 tests 0 fail, full suite
250 doctests + 1030 tests 0 fail. Merge-ready.

## For later cycles

- If a `basis_state` power-of-two dimension check is ever wanted, it is
  a SEMANTIC change (valid-today input starts raising) — 1.0 material,
  not this sweep.
