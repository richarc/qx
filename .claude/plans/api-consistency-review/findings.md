# API consistency review — consolidated findings

Phase 1 + 2 of the review defined in `spec/api-design-principles.md` §10,
run 2026-07-04 on branch `feat/api-consistency-review`.

- Inventory: 192 functions on the declared tier 1/2 surface
  (`research/inventory.md`) — 60 on the `Qx` facade, 132 in tier 2.
  83 missing `@spec`, 25 `@doc false` inside declared-public modules.
- Scoring: 4 parallel reviewers, one per layer group. Full evidence in
  `research/tier1-facade-report.md` (T1-01..18),
  `research/build-layer-report.md` (B-01..15),
  `research/run-state-layer-report.md` (R-01..15),
  `research/io-layer-report.md` (D-01..15).
- **63 findings: 1 critical, 8 high, ~24 medium, rest low/info.**

The gate set itself scored clean: all 24 plain gates, the measure
shape, `steps` laziness, `c_if`, and the layering of Simulation/Step.
The debt concentrates in four places: the Draw layer, error contracts,
tier hygiene, and one genuine correctness bug the review flushed out.

## The critical finding

**R-01 — `counts` keys are bit-lists at runtime; every type, doc, and
doctest promises strings.** `Qx.run` on a measured Bell pair returns
`%{[0, 0] => n, [1, 1] => m}` while `SimulationResult.t()`, the `Qx.run`
docs, and every doctest say `%{"00" => n}`. `probability(result, "0")`
can never match; Draw silently absorbs both shapes with a dual-head
helper. This is a live released-API bug, and its doctests pass only
because they hand-build the struct. Fix at the engine boundary
(join bits to strings when building `counts`), update the internal
type, delete Draw's dead list head, and add the missing `doctest`
lines (R-14) so the contract executes. Loud CHANGELOG entry. **Do this
before the v0.10 release ships** — the release republishes the false
docs otherwise.

## Cross-cutting themes

### 1. The Draw layer carries three return contracts (T1-01/02, D-01..)

VegaLite struct, SVG string, and Kino-or-string across six entry
points; `state_table` is environment-dependent on TWO paths (`:auto`
and explicit `:markdown`); Kino is invoked via `apply/3` without being
a dependency at all; zero `Kino.Render` impls exist; `vega_lite` is a
hard dep the core path never touches; the facade and `Qx.Draw` use
five different name pairs for the same six functions
(`plot`↔`draw`, ...); `Draw.circuit` has no facade delegate, which
forces tier 2 into the README; and `Qx.draw_state`'s `@spec` is
factually wrong. One coherent rework: static return types per
function, `Kino.Render` behind an optional `kino` dep, a
`draw_circuit/2` delegate, one naming scheme, and a decision on
`vega_lite` (optional dep vs plain-data chart specs).

### 2. Error contracts leak raw crashes (B-09, T1-10, R-04/09/10, B-14)

Raw `FunctionClauseError` escapes tier 1 for `create_circuit` (the
docs advertise it), `bell_state(:bogus)`, `ghz_state(1)`,
`h(qc, "0")`, `c_if` type slips, and seven `StateInit` constructors;
`rx/ry/rz/phase` skip the parameter validation their `u/cp/cr*`
siblings perform, so `Qx.rx(qc, 0, "pi")` detonates later inside the
simulator. The fix is a third typed-error sweep in the pattern of the
two v0.8.1 sweeps, routed through `Qx.Validation`. All non-breaking
(better errors for input that already crashed).

### 3. Tier hygiene: orphans and grey zones (R-07/13, B-01..07, T1-14)

The call graph decides tension #3: tier 1/2 code touches only
`StateInit.basis_state`, `Math.probabilities`, and `Math.normalize`;
the other 16 public functions in those two modules are orphans (and
two hidden Math converters are dead code). `Behaviours.QuantumState`
has one implementor, which is internal and slated for removal.
`QuantumCircuit` carries undelegated utilities with misleading names:
`get_state/1` returns the stored initial state while `Qx.get_state/2`
simulates (the v0.10 tap bug's root), `depth/1` returns instruction
count, `reset/1` collides with the quantum reset op, and the
`@doc false` `add_*` builders are neither documented nor internal and
skip gate-name validation (an Iron Law #9 hole). None of the three
build-layer moduledocs carries the §3 tier annotation.

### 4. Duplication and naming drift (T1-03/04/06/08, R-02/06, B-06)

`measure`/`measure_z` byte-identical (B-13 argues documented-exception
for QAAL symmetry; T1-03 wants one taught name — decision needed);
`barrier_all/2` vs `barrier/2` with divergent empty-input behaviour,
one of which emits the unproducible-shape ghost from the Iron Law #9
incident; `run/2`'s integer-shots overload; `superposition/1` fails
the README test; `StateInit`'s `*_state` vs `*_state_vector` split
encodes a facade accident, and its trailing `type \\ :c64` positional
violates opts-last across all ten functions.

### 5. §8 building blocks, adjudicated (B-10/11/12, T1-07)

Tension #8 resolves to "add appenders", with a correction: the spec's
blanket claim was wrong — `superposition_circuit` already wraps the
`h_all` appender, `ghz` half-composes `cx_chain`, and only `bell` has
no appender underneath. Add `bell_pair(circuit, q0, q1, which)` and
`ghz(circuit, qubits)`, reframe creators as wrappers (additive).
Hygiene follow-ons: `Patterns.measure_all` should compose
`Operations.measure/3` instead of a hidden internal, and
`barrier`/`c_if` build instruction tuples inline instead of through a
single producer path.

### 6. Docs mechanics (T1-13/15/16, R-12/14, B-08, D doc rot)

83 missing `@spec` (Patterns and Simulation prove the standard is
achievable), ~50 tier 1 functions missing `## Returns`, doctest gaps
on exactly the modules where the counts lie hid, broken cross-refs
(`histogram/2` at tier 1, `Qx.circuit`/`Qx.cnot` in QASM examples),
and inconsistent angle types (`float()` vs `number()`) across the
gate family. One mechanical sweep.

## Tension adjudications (spec §9)

1. **draw_state sniffing** — confirmed, and worse than documented (two
   env-dependent paths). Fix per the §6 sanctioned pattern.
2. **vega_lite hard dep** — confirmed non-core. Decide: optional dep
   with guards, or plain-data chart specs. Feeds the Draw rework.
3. **StateInit/Math tiers** — evidence supports demote-and-trim. Keep
   the load-bearing trio reachable; deprecate orphans; delete the two
   dead converters now.
4. **tap_\*** — sanctioned exception holds, but the loud warning lives
   only in tier 2 docs; copy it to the facade.
5. **measure_x/y mid-circuit state** — not further examined this pass;
   stays open.
6. **tdg** — add it. QASM round-tripping settles the argument
   (`tdg` is a standard OpenQASM gate).
7. **Iron Law #6 flat list** — replace with the tier annotations;
   R-13 and B-04 both show the flat list granting stability promises
   to things that shouldn't have them.
8. **Patterns shapes** — adjudicated above; spec wording corrected in
   this commit.

## Triage buckets

**Fix now (bug):** R-01 counts contract (+ R-14 doctests). Before the
v0.10 release.

**Non-breaking now (~36 findings), grouped into five work packages:**

1. Typed-error sweep #3 (B-09, B-14, T1-10, R-04, R-09, R-10).
2. Docs sweep (@spec, `## Returns`/`## Raises`, cross-refs, tier
   openers, facade tap warnings, angle types: B-08, B-15, R-12, R-15,
   T1-11/13/15/16, QASM doc rot).
3. Additive surface: `bell_pair` + `ghz` appenders, `tdg/2`,
   `to_qasm`/`from_qasm`/`from_qasm!` + `draw_circuit` facade
   delegates (T1-05/07/12, B-10, D).
4. Producer hygiene: `measure_all` via Operations, single-producer
   barrier/c_if, `add_gate` validation (B-04/11/12).
5. Spec-file updates: documented exceptions for `version/0`,
   `measure_z` (if kept), `get_state`-raises-on-measured; new §6 family
   rows for run/steps/c_if/barrier/`*_chain` (T1-09/17/18, B-13).

**Deprecate next minor:** `barrier_all/2`, `run/2` integer overload,
`superposition/1`, `QuantumCircuit.get_state/1` → `initial_state/1`,
`reset/1`, `depth/1`, StateInit/Math orphans + Math builtin wrappers,
`Behaviours.QuantumState` demotion, `draw_state`'s Register escape
hatch and return-type change.

**Breaking, the 1.0 gate list:** Draw return-contract redesign;
`QuantumCircuit` `state` field removal + `set_state` (initial state
becomes a `run`/`steps` option); `measure` vs `measure_z` final pick;
StateInit survivor naming + opts-last; `most_frequent` → `nil` on
empty; conditional-run `state`/`probabilities` ensemble semantics.

## Suggested next step

`/phx:plan` items in this order: (1) `fix/counts-contract` immediately;
(2) the five non-breaking packages as one or two v0.11 ROADMAP items;
(3) a "## v1.0 gate (breaking)" ROADMAP section holding the last
bucket, which is the surface-stability list the backlog says 1.0 waits
for. The principles doc gets its post-review edits (documented
exceptions, new family rows) once Craig signs the adjudications.

## Post-release addendum (2026-07-04, README v0.10 audit)

`from_qasm_function/1` returns `module:` as a STRING
("Qx.Generated.Bell_<hash>"), not an atom — callers can't invoke
through it without `Code.eval_string`-capture or Module.concat. Found
while fixing the README recipe (fix/readme-v010). Candidate v0.11
non-breaking fix: return the atom (the module name is qx-generated,
not user input, so `Module.concat/1` is safe). Full README audit:
research/readme-v010-audit.md.
