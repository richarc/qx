# Build-layer report — Qx.QuantumCircuit, Qx.Operations, Qx.Patterns

Phase 2 scoring against `spec/api-design-principles.md` §2, §3, §5, §6, §7, §8.
Sources read in full: `lib/qx/quantum_circuit.ex`, `lib/qx/operations.ex`,
`lib/qx/patterns.ex`, plus `lib/qx.ex` delegations and `lib/qx/simulation.ex`
lines 344/394/669 (initial-state reads).

## Layering verdict (§2) — mostly clean

- `Qx.Operations` aliases `Qx.Simulation` but uses it only inside
  `tap_state/2`, `tap_probabilities/2`, and their shared `final_step/2`
  helper (operations.ex:870–960). That is the sanctioned §2 exception, and
  both docs carry the "executes all instructions so far" warning plus the
  typed `Qx.MeasurementError` raise contract. No other upward reach.
- `Qx.QuantumCircuit` and `Qx.Patterns` never touch Simulation or Draw.
- `Qx.Patterns` emits zero raw instruction tuples; everything goes through
  `Operations.*` or `QuantumCircuit.add_measurement` (see B-11).
- The one structural §2 problem is the `state` field itself (B-02).

## Findings

### B-01 — `QuantumCircuit.get_state/1`: same name, different meaning
- **Function(s):** `Qx.QuantumCircuit.get_state/1` vs `Qx.get_state/2` /
  `Qx.Simulation.get_state/2`
- **Rule:** §6 naming families (`get_*` = pure read), §7 error-message test;
  past v0.10 tap-bug precedent
- **Severity:** high
- **Evidence:** Still exported and documented. quantum_circuit.ex:188–200 —
  doc reads "Gets the **current** quantum state of the circuit" but the body
  is `circuit.state`, the *stored initial-state field*, never advanced by any
  instruction. `Qx.get_state/2` (→ `Simulation.get_state/2`) simulates the
  circuit and returns the final state. Identical name, opposite semantics,
  one module apart; this exact confusion produced the v0.10 tap bug.
- **Fix:** Rename to `initial_state/1` (deprecate `get_state/1` with a doc
  pointing at `Qx.get_state/2`), and correct the doc to say "initial state"
  in the first sentence immediately (non-breaking part now).
- **Triage:** deprecate-next-minor (doc correction: non-breaking-now)

### B-02 — build struct carries an eagerly computed state tensor
- **Function(s):** `QuantumCircuit.new/1,2` (struct `state` field)
- **Rule:** §2 "build never simulates" / layer map ("build circuits — pure
  data, no math")
- **Severity:** medium (architectural)
- **Evidence:** quantum_circuit.ex:56–68 — `new/2` allocates a 2^n `:c64`
  tensor via `Qx.StateInit.basis_state/2` at build time (8 MB at the
  20-qubit cap, before a single gate exists). The simulator reads it as the
  initial state (simulation.ex:344, 394, 669), so build data and simulation
  input are fused in one struct — the root cause of B-01's ambiguity.
- **Fix:** For 1.0, drop the `state` field; pass custom initial states as a
  `run/steps/get_state` option (`initial_state:`). Build layer becomes pure
  instructions + shape.
- **Triage:** breaking-1.0

### B-03 — `set_state/2`: a real feature with no tier-1 spelling
- **Function(s):** `Qx.QuantumCircuit.set_state/2`
- **Rule:** §3 (tier 2 functions tier 1 never delegates to must justify
  themselves), §5
- **Severity:** medium
- **Evidence:** Not delegated from `Qx`. It is the *only* way to start a
  simulation from a custom state (Simulation honours `circuit.state`), yet
  it lives undocumented-at-tier-1 in a utility module; only its own error
  tests call it (`test/qx/quantum_circuit_typed_errors_test.exs:82,91`).
  Either it is a supported feature (then the facade or a `run` option should
  own it) or it is internal.
- **Fix:** Fold into B-02's `initial_state:` option; deprecate `set_state/2`
  alongside.
- **Triage:** breaking-1.0 (tied to B-02)

### B-04 — hidden `add_*` builders in a declared-public module
- **Function(s):** `QuantumCircuit.add_gate/4`, `add_two_qubit_gate/5`,
  `add_three_qubit_gate/6`, `add_measurement/3`
- **Rule:** §3 tiering (grey zone: `@doc false` inside the Iron Law #6
  declared-public surface), §5 (second spelling for "add a gate")
- **Severity:** medium
- **Evidence:** quantum_circuit.ex:92–186. All four are exported from a
  module the Iron Law #6 list declares public, but carry `@doc false`:
  neither documented nor internal, no stability status. They are also a
  parallel spelling for every gate (`add_gate(qc, :h, 0)` ≡
  `Operations.h(qc, 0)`) with *no gate-name validation* — `add_gate(qc,
  :bogus, 0)` appends an instruction the simulator will only reject at run
  time, which is exactly the §8 "no library-emitted tuple the timeline has
  never heard of" hole (Iron Law #9 precedent).
- **Fix:** Move them to an internal builder module (`@moduledoc false`) that
  `Operations`/`Patterns` call, or validate `gate_name` against the known
  set and document them as the sanctioned extension point. §8 says blocks
  compose Operations, so internalising is the consistent answer.
- **Triage:** non-breaking-now (annotate/validate); relocation is
  breaking-1.0

### B-05 — non-delegated documented utilities with no callers
- **Function(s):** `QuantumCircuit.reset/1`, `depth/1` (also weakly
  `get_measurements/1`)
- **Rule:** §3 ("a tier 2 module that tier 1 never delegates to should
  justify its existence"), §4 ("a variant nobody's notebook calls gets
  deprecated")
- **Severity:** medium
- **Evidence:** None of `reset/1`, `depth/1`, `set_state/2`,
  `get_state/1`, `get_instructions/1`, `get_measurements/1`, `measured?/2`
  is delegated from `Qx`. Grep across `lib/`, `test/`, guides: `reset/1`
  has zero callers anywhere; `depth/1` appears once, inside a
  `tap_circuit` doc example. `get_instructions/1` and `measured?/2` earn
  their keep (doctests and Draw/export inspection use the instruction
  list); `reset/1` and `depth/1` do not.
- **Fix:** Deprecate `reset/1` (a fresh `create_circuit` is the two-line
  pipeline §4 prefers) and `depth/1` (see B-06).
- **Triage:** deprecate-next-minor

### B-06 — `depth/1` is instruction count, not depth
- **Function(s):** `Qx.QuantumCircuit.depth/1`
- **Rule:** §6 naming, §7 (honest docs)
- **Severity:** medium
- **Evidence:** quantum_circuit.ex:280–291 — body is
  `length(circuit.instructions)`. Its own doctest shows `h(0) |> x(1)`
  returning 2, but those gates are parallel: true circuit depth (the
  standard QC meaning, "instruction layers", which the doc itself claims)
  is 1. Anyone comparing against Qiskit's `depth()` gets the wrong number.
- **Fix:** Rename to `instruction_count/1` (or implement real layered
  depth); deprecate `depth/1`.
- **Triage:** deprecate-next-minor

### B-07 — `reset/1` name collides with the quantum reset op
- **Function(s):** `Qx.QuantumCircuit.reset/1`
- **Rule:** §6 naming
- **Severity:** low
- **Evidence:** quantum_circuit.ex:293–321 — the doc already self-flags:
  "this function may be renamed to `clear/1`" when mid-circuit qubit reset
  lands. In every mainstream QC API `reset` means the single-qubit
  operation.
- **Fix:** Fold into B-05's deprecation (deprecate now, don't wait for the
  collision to ship).
- **Triage:** deprecate-next-minor

### B-08 — missing `@spec` across the build layer
- **Function(s):** all of `QuantumCircuit` except `measured?/2` (10 fns);
  all of `Operations` except `tap_*` (29 fns)
- **Rule:** §6 docs ("every tier 1 and 2 function carries `@spec`")
- **Severity:** low (mechanical)
- **Evidence:** Inventory `Spec` column: 39 `NONE` rows across the two
  modules. `Patterns` is fully specced — proof the standard is achievable
  here.
- **Fix:** Add `@spec` sweep; `Patterns` is the template.
- **Triage:** non-breaking-now

### B-09 — raw `FunctionClauseError` escaping tier 1 and 2 entry points
- **Function(s):** `Qx.bell_state/1`, `Qx.ghz_state/1`,
  `Qx.superposition/1`, `Qx.h/2` (and every gate, via `add_gate` guards),
  `QuantumCircuit.new/2`, `Operations.c_if/4`, `Patterns.*_all/2`,
  `Patterns.cx_chain/2`
- **Rule:** §6 error contract ("raw ArgumentError or FunctionClauseError
  escaping a tier 1 or 2 function is a finding"), §7 error-message test
- **Severity:** high (tier-1 reachable)
- **Evidence:**
  - `Qx.bell_state(:bogus)` → no matching clause in
    `Patterns.bell_state_circuit/1` (patterns.ex:304–330).
  - `Qx.ghz_state(1)` → guard `num_qubits >= 2` (patterns.ex:334) —
    FunctionClauseError, no typed error, no hint that 2 is the minimum.
  - `Qx.superposition(0)` → same pattern (patterns.ex:356).
  - `Qx.h(qc, "0")` → FunctionClauseError raised in
    `Qx.QuantumCircuit.add_gate/4` (quantum_circuit.ex:93–94), leaking an
    internal helper name across the tier-1 boundary.
  - `QuantumCircuit.new(2, -1)` / `new(2.5, 0)` → guard falls through
    (quantum_circuit.ex:49–50); the v-prior fix only added the typed error
    for the qubit lower bound, not classical bits or non-integers.
  - `Operations.c_if(qc, "0", 1, fun)` → no clause matches (clauses at
    operations.ex:736–772 cover bad range, bad value, bad fun — but not a
    non-integer bit with otherwise-valid args).
  - `Patterns.h_all(qc, 5)` (bare integer) → `qubits_to_list/1` has only
    list and Range clauses (patterns.ex:369–370).
- **Fix:** Route each through `Qx.Validation` typed errors
  (`Qx.ParameterError` / `Qx.QubitIndexError` / a `Qx.PatternError` for the
  creator selectors), with fix-naming messages per §7.
- **Triage:** non-breaking-now (raising typed errors instead of crashes is
  an error-quality improvement, not a contract break)

### B-10 — tension #8 adjudicated: partially confirmed, partially refuted
- **Function(s):** `Patterns.bell_state_circuit/1`, `ghz_state_circuit/1`,
  `superposition_circuit/1`
- **Rule:** §8 "appenders by default, creators as facades"
- **Severity:** medium (design decision, pre-v0.13)
- **Evidence:** The spec's claim "creators have no appender underneath" is
  **refuted for `superposition_circuit/1`** — it is already exactly the
  prescribed shape: `QuantumCircuit.new(n) |> h_all()` (patterns.ex:356–360),
  a thin wrapper over the `h_all` appender. **Partially true for
  `ghz_state_circuit/1`** — it composes the `cx_chain` appender but the
  `h(0) |> cx_chain` motif as a whole has no `(circuit, qubits)` appender
  form (patterns.ex:334–338). **Fully confirmed for `bell_state_circuit/1`**
  — all four clauses inline `x/h/cx` onto a fresh hard-coded 2-qubit circuit
  (patterns.ex:304–330); there is no `bell_pair(circuit, q0, q1)`, so a Bell
  pair cannot be prepared on qubits 3 and 4 of a larger register without
  hand-writing the gates.
- **Fix:** Add `bell_pair(circuit, q0, q1, which \\ :phi_plus)` and
  `ghz(circuit, qubits)` appenders; rewrite the creators as one-line
  wrappers (the `superposition_circuit` pattern). Purely additive.
- **Triage:** non-breaking-now

### B-11 — `measure_all` bypasses Operations for a hidden internal
- **Function(s):** `Patterns.measure_all/2`
- **Rule:** §8 ("blocks compose tier 1 and 2 functions and nothing else")
- **Severity:** low
- **Evidence:** patterns.ex:219–223 calls
  `QuantumCircuit.add_measurement/3` (a `@doc false` internal) while every
  sibling `*_all` composes `Operations.*`. Behaviourally identical today
  (`Operations.measure/3` is a one-line delegate), but it is the only
  Patterns function coupling to the hidden layer.
- **Fix:** Call `Operations.measure/3`.
- **Triage:** non-breaking-now

### B-12 — `barrier/2` and `c_if/4` build instruction tuples inline
- **Function(s):** `Operations.barrier/2`, `Operations.c_if/4`
- **Rule:** §8 spirit / Iron Law #9 hygiene (single producer path per
  instruction shape)
- **Severity:** low
- **Evidence:** operations.ex:598–603 and 753–756 construct
  `{:barrier, qubits, []}` / `{:c_if, [bit, value], instrs}` and splice
  `circuit.instructions` directly, bypassing the `QuantumCircuit.add_*`
  helpers every other operation uses. Two places own instruction-shape
  invariants — the 2026-07-03 barrier dispatch bug is the precedent for why
  scattered producers hurt.
- **Fix:** Add `QuantumCircuit` (or internal builder) append helpers for
  barrier/c_if so instruction shapes have one producer.
- **Triage:** non-breaking-now (internal refactor)

### B-13 — `measure_z/3` is a documented alias of `measure/3`
- **Function(s):** `Operations.measure_z/3` (and `Qx.measure_z/3`)
- **Rule:** §4 (two names for one concept)
- **Severity:** info
- **Evidence:** operations.ex:625–640 — body is identical to `measure/3`;
  the doc declares it "an alias ... for symmetry with `measure_x/3` and
  `measure_y/3`" and the QAAL `Mz` mapping. Deliberate, family-consistent.
- **Fix:** Record as a documented exception in
  `spec/api-design-principles.md` §4 rather than change code.
- **Triage:** non-breaking-now (spec edit)

### B-14 — inconsistent parameter validation across the gate family
- **Function(s):** `Operations.rx/3`, `ry/3`, `rz/3`, `phase/3` (missing)
  vs `u/5`, `cp/4`, `crx/4`, `cry/4`, `crz/4` (validating)
- **Rule:** §6 ("same family, same shape" — and same contract)
- **Severity:** medium
- **Evidence:** `u/cp/crx/cry/crz` call
  `Validation.validate_parameter!(theta)` before appending
  (operations.ex:294–296, 454, 512, 542, 576); `rx/ry/rz/phase` append
  unchecked (operations.ex:190–252). `Qx.rx(qc, 0, "pi")` builds fine and
  only detonates later inside the simulator, far from the call site, with a
  non-Qx error — while `Qx.crx(qc, 0, 1, "pi")` raises `Qx.ParameterError`
  immediately.
- **Fix:** Add `validate_parameter!` to `rx/ry/rz/phase`.
- **Triage:** non-breaking-now

### B-15 — no tier annotation in the three moduledocs
- **Function(s):** module docs of `QuantumCircuit`, `Operations`, `Patterns`
- **Rule:** §3 ("every module belongs to exactly one tier, recorded in its
  moduledoc; tier 2 modules open with 'Utility module: reached from `Qx.*`
  in normal use'")
- **Severity:** low
- **Evidence:** None of the three moduledocs carries the tier opener;
  `QuantumCircuit`'s doc in particular reads as a primary API ("provides
  the core structure...") and its doctests invite direct use, blurring the
  tier-1/tier-2 line the facade delegation is supposed to draw.
- **Fix:** Add the §3 opener line to all three moduledocs.
- **Triage:** non-breaking-now

## Summary

The build layer's gate surface is in good shape — arg order, controls-before-targets, angles-last, and the tap_* exception all check out — but the `QuantumCircuit` struct is the trouble spot: an eagerly computed `state` field gives `get_state/1` the opposite meaning of `Qx.get_state/2` (the v0.10 bug's root), and `set_state/reset/depth` are undelegated utilities with near-zero callers and misleading names. Error contracts leak: `Qx.bell_state(:bogus)`, `Qx.ghz_state(1)`, `Qx.h(qc, "0")`, and `c_if` type slips all escape as raw FunctionClauseError, and `rx/ry/rz/phase` skip the parameter validation their `u/cp/cr*` siblings perform. Tension #8 resolves to "add appenders": `superposition` already wraps `h_all` (refuting the blanket claim), `ghz` half-composes `cx_chain`, and only `bell` truly has no appender underneath. Fifteen findings: 2 high (get_state semantics, raw-error escapes), 6 medium, 7 low/info; 9 fixable non-breaking now, 4 deprecations next minor, 2 for the 1.0 breaking list (state-field removal and its `set_state` companion).
