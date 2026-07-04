# Phase 2 report — run/inspect + state utilities

Scope: `Qx.Simulation`, `Qx.SimulationResult`, `Qx.Step`, `Qx.StateInit`,
`Qx.Math`, `Qx.Behaviours.QuantumState`, plus the `Qx` facade wrappers for
`run` / `get_state` / `get_probabilities` / `steps`. Scored against
spec/api-design-principles.md §2, §3, §5, §6, §7. Every claim below was
verified against source or by running the code (`mix run` probes, 2026-07-04).

## What's clean (no findings)

- **§2 layering:** `Qx.Simulation` aliases only `Calc, Gates, Math,
  QuantumCircuit, SimulationResult, Step, Validation` (lib/qx/simulation.ex:10)
  — all same-layer or below. `Qx.Step` uses `Format` and `Math` only. Neither
  reaches up into Draw. No new cycle found in this scope.
- **§5 facade coverage:** all four `Qx.Simulation` functions (`run`,
  `get_state`, `get_probabilities`, `steps`) are fronted by `Qx`. Simulation
  exposes nothing the facade hides.
- **§5 option orthogonality:** no option in this scope changes the return
  kind. `:shots`, `:backend`, `:renormalize`, `:seed` all preserve shape.
- `get_state`/`get_probabilities` raise typed `Qx.MeasurementError` with a
  message that names the fix ("Use run/2 instead") — passes §7's
  error-message test.
- `Qx.Step.show/1` documents its map shape explicitly
  (`%{state:, amplitudes:, probabilities:}`) — lib/qx/step.ex:62-90.

## Findings

### R-01 — `SimulationResult.counts` / outcome keys are lists at runtime, strings in every doc, type, and doctest

- **Functions:** `Qx.Simulation.run/2` (perform_measurements,
  run_with_conditionals), `Qx.SimulationResult` (`t()`, `most_frequent/1`,
  `outcomes/1`, `probability/2`, `filter_by_probability/2`), `Qx.run/2` docs
- **Rule:** §6 return shapes + docs contract
- **Severity:** critical
- **Evidence:**
  - Runtime (verified): `Qx.run(bell |> measured)` gives
    `Map.keys(r.counts) == [[0, 0], [1, 1]]`, `most_frequent(r) == {[1, 1], 27}`,
    `outcomes(r) == [[0, 0], [1, 1]]`.
  - `Qx.Simulation`'s own internal type admits it:
    `@typep counts :: %{optional([bit()]) => pos_integer()}`
    (lib/qx/simulation.ex:23). `counts = Enum.frequencies(classical_bits)`
    where each element is a list of bits (simulation.ex:627, :180).
  - `Qx.SimulationResult.t()` claims `counts: %{String.t() => non_neg_integer()}`
    (lib/qx/simulation_result.ex:36). Every doctest in the module hand-builds
    structs with `%{"00" => 52, ...}` — so they pass while documenting a shape
    the engine never produces.
  - `Qx.run/2` docs: "`:counts` - frequency map of outcome strings to counts
    (keys are binary strings like `\"01\"`)" (lib/qx.ex:906-907). False.
  - `probability(result, "0")` on a real result silently returns `0.0`
    (verified) — the documented call can never succeed.
  - Downstream already papers over it: `Qx.Draw` has
    `defp counts_key_to_label(key) when is_list(key), do: Enum.join(key, "")`
    next to a `is_binary` head (lib/qx/draw/vega_lite.ex:71-72) — the mismatch
    is known and absorbed instead of fixed.
- **Suggested fix:** convert at the engine boundary — `Enum.join(bits, "")`
  when building `counts` (and decide `classical_bits` stays as bit lists,
  which its type honestly declares). Update `Simulation`'s `@typep counts`,
  delete the now-dead list head in Draw, add `doctest Qx.SimulationResult`
  (see R-14) so the contract is executed.
- **Triage:** non-breaking-now as a bug fix against the documented contract —
  but it changes observed behaviour for anyone pattern-matching list keys, so
  it needs a loud CHANGELOG entry. If instead the docs are changed to match
  the lists, that's breaking-1.0.

### R-02 — `Qx.run(circuit, 2048)` integer overload: two spellings for shots, facade diverges from `Simulation.run/2`

- **Functions:** `Qx.run/2` (lib/qx.ex:926-935)
- **Rule:** §4 one obvious way; §6 arg order (options are a trailing keyword list)
- **Severity:** minor
- **Evidence:** `def run(circuit, shots) when is_integer(shots)` exists only
  on the facade, labeled "backward compatibility"; `Qx.Simulation.run/2`
  accepts keyword only. Same task, two spellings, and the tier 1/tier 2 pair
  the spec asks to compare ("Simulation.run vs Qx.run — identical?") is not
  identical in accepted arguments (return shape is identical).
- **Suggested fix:** deprecate the integer clause (`@deprecated "use shots: n"`),
  remove at 1.0.
- **Triage:** deprecate-next-minor

### R-03 — Conditional-circuit `run`: `state`/`probabilities` are one sampled trajectory, documented as "final statevector"

- **Functions:** `Qx.Simulation.run/2` (run_with_conditionals), `Qx.run/2` docs
- **Rule:** §6 return shapes (shape honesty); §6 docs ("Where behaviour
  differs, the doc says so in the first paragraph")
- **Severity:** major
- **Evidence:** lib/qx/simulation.ex:183-186 — "For conditional circuits, we
  can't provide a single final state. We'll use the last shot's state as
  representative" — a code comment only. `Qx.run/2` docs say unqualified
  "`:state` - final statevector" and "`:probabilities` - real probability
  tensor |ψ|² over all 2^n basis states" (lib/qx.ex:900-904). For a `c_if`
  circuit, `probabilities` is one random shot's collapsed distribution, not
  the ensemble — a user summing it against `counts` will find they disagree.
  Same fields are also last-trajectory for measured-but-unconditional
  circuits' `state`? No — that path keeps the pre-measurement pure state
  (run_without_conditionals), which is a *different* meaning for the same
  field. Two meanings, zero doc.
- **Suggested fix:** document both regimes in `run/2` (`Qx` and
  `Qx.Simulation`) under `## Returns`; longer term decide whether conditional
  runs should report ensemble-averaged probabilities (breaking) or the field
  should be explicitly trajectory-flagged.
- **Triage:** non-breaking-now (doc fix); ensemble semantics change goes on
  the breaking-1.0 list.

### R-04 — `StateInit`: raw `FunctionClauseError` / Nx `ArgumentError` escape a tier 2 module

- **Functions:** `basis_state/3`, `zero_state/2`, `ghz_state_vector/2`,
  `w_state/2`, `bell_state_vector/2`, `superposition_state/2`, `random_state/2`
- **Rule:** §6 error contract; §7 error-message test
- **Severity:** major
- **Evidence (all verified by running):**
  - `basis_state(4, 4)` → `FunctionClauseError` (guard `index < dimension`)
  - `basis_state(0, 2, :banana)` → Nx `ArgumentError` "invalid numerical type"
  - `zero_state(0)`, `ghz_state_vector(1)`, `bell_state_vector(:bogus)` →
    `FunctionClauseError`
  - `ghz_state_vector/2` even *documents* "Smaller values raise
    `FunctionClauseError`" (lib/qx/state_init.ex:320-321) — documenting the
    raw error doesn't satisfy §6, which calls any escaping
    `FunctionClauseError` from tier 2 a finding.
- **Suggested fix:** validate and raise typed `Qx.*Error` (route through
  `Qx.Validation` per Iron Law #7). Moot for any function R-07 removes.
- **Triage:** non-breaking-now (raising a better error for input that already
  raised)

### R-05 — `StateInit` trailing `type \\ :c64` positional argument on all ten functions

- **Functions:** every public `StateInit` function; worst is
  `bell_state_vector(which \\ :phi_plus, type \\ :c64)` — two optional
  positionals
- **Rule:** §6 arg order — "then a keyword list of options"
- **Severity:** minor
- **Evidence:** inventory rows 148-157; source throughout state_init.ex. On
  the subject-first rule: these functions *create* the subject, so having no
  leading subject is fine (they're the `create_*` shape); the violation is
  the bare-atom optional where the contract says options ride in a trailing
  keyword list. `basis_state(index, dimension, type)` reads as three
  positionals with no signal which are required.
- **Suggested fix:** `opts \\ []` with a `:type` key at 1.0 (keep the
  positional accepted-but-deprecated for one minor). Decision depends on
  R-07 — don't restyle functions slated for removal.
- **Triage:** breaking-1.0

### R-06 — `*_state` vs `*_state_vector` naming split inside `StateInit`

- **Functions:** `bell_state_vector/2`, `ghz_state_vector/2` vs `zero_state/2`,
  `one_state/1`, `plus_state/1`, `minus_state/1`, `superposition_state/2`,
  `random_state/2`, `w_state/2`, `basis_state/3`
- **Rule:** §6 naming families (same family, same name shape)
- **Severity:** minor
- **Evidence:** all ten return the same kind of thing (an Nx state vector).
  Only the two whose names would collide with the `Qx.bell_state`/
  `Qx.ghz_state` circuit creators carry `_vector`; `w_state` — which has no
  circuit twin — doesn't, so the suffix encodes an accident of the facade,
  not a meaning. Inside a module named `StateInit` both suffixes are
  redundant.
- **Suggested fix:** one convention at 1.0, chosen together with the R-07
  tier decision (if the module goes tier 3, naming ceases to be a public
  concern).
- **Triage:** breaking-1.0

### R-07 — Tension #3 evidence: `StateInit` and `Math` are mostly orphans; tier 2 placement no longer justified

- **Functions/modules:** `Qx.StateInit`, `Qx.Math`
- **Rule:** §3 — "A tier 2 module that tier 1 never delegates to should
  justify its existence"
- **Severity:** major (this is the adjudication evidence the spec asks for)
- **Evidence (full grep of lib/, plus guides/livebooks — no hits outside lib):**
  - StateInit called by tier 1/2 code: **`basis_state/2` only** —
    `Qx.QuantumCircuit.new/reset` via `complex_basis_state/2`
    (lib/qx/quantum_circuit.ex:325).
  - StateInit called by tier 3 only: `one_state`, `plus_state`,
    `minus_state`, `random_state` (lib/qx/qubit.ex:115-162), `zero_state`
    (lib/qx/register.ex:48) — both callers are the `@moduledoc false` calc
    engine demoted in v0.10, removal deferred to 1.0.
  - StateInit called by **nothing** in lib/: `superposition_state/2`,
    `w_state/2`, `bell_state_vector/2`, `ghz_state_vector/2` (the two
    `_vector` functions appear only in "See Also" doc prose, lib/qx.ex:1246,
    :1270).
  - Math called by tier 1/2 code: **`probabilities/1` and `normalize/1`
    only** (Simulation, Step, StateInit; plus tier 3 Validation, Qubit,
    Register). `complex_matrix/1` is `@doc false` and feeds `Qx.Gates`.
  - Math public functions with **zero** callers in lib/: `kron/2`,
    `inner_product/2`, `outer_product/2`, `apply_gate/2`, `trace/1`,
    `identity/1` (used only inside `unitary?/1`), `unitary?/1`, `complex/2`.
  - Dead hidden code: `complex_to_tensor/1` / `tensor_to_complex/1` have no
    callers anywhere; the comment "used by gate-matrix builders"
    (lib/qx/math.ex:151-164) is stale — gates.ex uses `complex_matrix/1`.
  - The v0.8.1 "declared PUBLIC" rationale (tutorial usage) is gone: no
    guide, livebook, or notebook in the repo references either module.
- **Suggested fix:** the evidence supports demotion. Keep the load-bearing
  trio (`basis_state`, `normalize`, `probabilities`) available (either
  tier 2 in a slimmed module or internal), deprecate the orphans, delete the
  dead converters now. `unitary?`/`kron`/`inner_product` are defensible
  escape hatches *if* Craig wants a "quantum linear algebra" story — but
  today nothing motivates them (§7 README test fails: the README doesn't
  need them).
- **Triage:** deprecate-next-minor (demotion/deprecations), non-breaking-now
  for deleting the two dead `@doc false` converters.

### R-08 — `Math` wrappers duplicating builtins one-for-one

- **Functions:** `apply_gate/2` (= `Nx.dot/2`), `identity/1` (= `Nx.eye/1`),
  `complex/2` (= `Complex.new/2`)
- **Rule:** §5 orthogonality / §4 prefer composition ("if the pipeline is
  clear, ship the pipeline as a doc example")
- **Severity:** minor
- **Evidence:** lib/qx/math.ex:116-118, :216-218, :147-149 — each body is a
  single delegating expression adding no contract, no validation, no quantum
  semantics. (`kron`, `inner_product`, `outer_product`, `probabilities`,
  `normalize`, `trace` do encode real conventions — conjugation, |ψ|² — and
  are not part of this finding; their problem is R-07's orphan status.)
- **Suggested fix:** deprecate all three; docs point at the builtin.
- **Triage:** deprecate-next-minor

### R-09 — `Math` edge-case behaviour: silent NaN and raw `MatchError`

- **Functions:** `normalize/1`, `unitary?/1`
- **Rule:** §6 error contract
- **Severity:** minor
- **Evidence (verified):** `normalize(Nx.tensor([0.0, 0.0]))` returns
  `[NaN, NaN]` with no error — a zero vector is not a quantum state and the
  NaN propagates silently into downstream probabilities.
  `unitary?(Nx.tensor([1.0, 0.0]))` raises `MatchError` (the
  `{n, m} = Nx.shape(matrix)` destructure, lib/qx/math.ex:235) instead of
  returning false or raising typed.
- **Suggested fix:** `normalize` raises typed on zero norm (or documents the
  NaN loudly); `unitary?` returns `false` for non-2-D input (it's a
  predicate — it should never raise on the wrong shape).
- **Triage:** non-breaking-now

### R-10 — `filter_by_probability/2` rejects integer thresholds

- **Functions:** `Qx.SimulationResult.filter_by_probability/2`
- **Rule:** §6 error contract (raw `FunctionClauseError` from tier 2)
- **Severity:** minor
- **Evidence (verified):** `filter_by_probability(result, 1)` →
  `FunctionClauseError`; the guard is `is_float(threshold)`
  (lib/qx/simulation_result.ex:102). `0` and `1` are the natural endpoint
  spellings and both are integers.
- **Suggested fix:** `is_number/1` guard; typed error for out-of-range.
- **Triage:** non-breaking-now

### R-11 — `most_frequent/1` fabricates a `{"", 0}` outcome for empty counts

- **Functions:** `Qx.SimulationResult.most_frequent/1`
- **Rule:** §6 return shapes (shape honesty)
- **Severity:** minor
- **Evidence:** lib/qx/simulation_result.ex:68-70. A measurement-free run has
  `counts == %{}` (verified), and `most_frequent` answers with a sentinel
  that looks like a real outcome ("the empty bitstring occurred 0 times").
  Doubly odd today because real outcomes are lists (R-01), so the sentinel's
  type doesn't even match real returns.
- **Suggested fix:** return `nil` (documented) at 1.0; meanwhile document the
  sentinel.
- **Triage:** breaking-1.0

### R-12 — Missing `@spec` across `StateInit` and `Math`

- **Functions:** StateInit 8 of 10 (`basis_state`, `zero_state`, `one_state`,
  `plus_state`, `minus_state`, `superposition_state`, `random_state`,
  `w_state` — only the two `_vector` functions have specs); Math all 9
  documented functions except `unitary?/1`
- **Rule:** §6 docs — "Every tier 1 and 2 function carries `@spec`"
- **Severity:** minor
- **Evidence:** inventory rows 148-177 (Spec column NONE), confirmed in
  source. Both modules also lack `## Returns`/`## Raises` sections
  throughout. Simulation, SimulationResult, and Step are fully spec'd —
  the gap is exactly the two tension-#3 modules.
- **Suggested fix:** add specs to whatever survives R-07; don't spec
  functions being deprecated.
- **Triage:** non-breaking-now

### R-13 — `Qx.Behaviours.QuantumState`: public behaviour, zero public implementors

- **Functions/module:** `Qx.Behaviours.QuantumState`
  (lib/qx/behaviours/quantum_state.ex)
- **Rule:** §3 tiering (a tier 2 module tier 1 never touches should justify
  itself)
- **Severity:** major
- **Evidence:** sole implementor is `Qx.Register` (lib/qx/register.ex:9),
  which is `@moduledoc false`, demoted in v0.10, removal deferred to 1.0 —
  and it carries zero `@impl` annotations. The behaviour's own moduledoc
  concedes `Qx.QuantumCircuit` only "follows the same shape by convention"
  (it can't implement: circuit gate functions live on `Qx.Operations`, not
  the circuit module). So the module exists to constrain one internal module
  slated for removal, while Iron Law #6 grants it a public stability
  promise. Nothing external can usefully implement it either — the simulator
  dispatches on instruction tuples, not on this behaviour.
- **Suggested fix:** demote to tier 3 (`@moduledoc false`) next minor and
  drop it from the Iron Law #6 list (tension #7); delete or redesign at 1.0
  when Register goes.
- **Triage:** deprecate-next-minor

### R-14 — No `doctest` for `Qx.Simulation`, `Qx.SimulationResult`, `Qx.Step`; SimulationResult's moduledoc example cannot pass

- **Functions/modules:** the three modules' doc examples
- **Rule:** §6 docs ("doctest when output is stable")
- **Severity:** minor (but it is the enabler of R-01 going unnoticed)
- **Evidence:** `grep -rn doctest test/` shows lines for Qx, Qubit, Math,
  Format, Register, Validation, Hardware.Config, OpenQASM, StateInit — none
  for Simulation, SimulationResult, or Step. SimulationResult's moduledoc
  example asserts `most_frequent(result) == {"00", 503}` from a real 1000-shot
  run — stochastic exact count *and* string keys (R-01): it would fail two
  ways if ever executed.
- **Suggested fix:** add the three `doctest` lines after fixing R-01; rewrite
  the stochastic example to assert a stable property.
- **Triage:** non-breaking-now

### R-15 — `Qx.Step.t()` declares every field nilable; `@enforce_keys []` is dead code

- **Functions/module:** `Qx.Step` struct definition (lib/qx/step.ex:45-60)
- **Rule:** §6 return shapes (shape honesty)
- **Severity:** minor
- **Evidence:** `steps/2` always populates `kind`, `index`, `state`,
  `probabilities` (lib/qx/simulation.ex:377-389), yet the type says each is
  `| nil`, so a dialyzer-honest consumer must nil-check fields that are
  never nil. Only `operation` and `condition` are legitimately nilable
  (not-taken conditionals). `@enforce_keys []` enforces nothing.
- **Suggested fix:** tighten the type to nilable-only-where-true; delete the
  empty `@enforce_keys`.
- **Triage:** non-breaking-now

## Summary

15 findings. One critical: the `counts`/outcome-key contract is a lie — the
engine emits bit-lists where the type, docs, doctests, and `Qx.run` docs all
promise strings, `probability/2` can never match its documented call, and
Draw already quietly absorbs both shapes (R-01). Tension #3 is decided by the
call graph: tier 1/2 code touches only `StateInit.basis_state`,
`Math.probabilities`, and `Math.normalize`; the other 16 public functions in
those modules are orphans, so demotion/trim is supported (R-07), taking the
naming, arg-order, spec, and error-contract findings (R-04/05/06/12) with it.
`Behaviours.QuantumState` has zero public implementors and should drop a tier
(R-13). Layering is clean and every Simulation function is properly fronted
by the facade.
