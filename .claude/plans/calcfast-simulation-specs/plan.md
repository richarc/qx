# Add `@spec` to CalcFast and Simulation (qx-atv)

**Slug:** `calcfast-simulation-specs`
**Branch:** `feat/calcfast-simulation-specs`
**ROADMAP:** qx v0.8.1 — qx-atv ("Add @spec to all defp functions in CalcFast
and Simulation").
**Type:** Internal typing/documentation. No behaviour change, no version bump,
no CHANGELOG entry.

## Problem

`lib/qx/simulation.ex` (28 private functions, 3 public) and
`lib/qx/calc_fast.ex` (6 functions) carry **zero** `@spec`. These are the two
simulation hot-path modules; missing specs hurt readability and tooling.

## Decided constraints (do not re-litigate)

- **Scope = FULL coverage of both files** (user): every currently-unspec'd
  function gets a `@spec`. `lib/qx/calc.ex` is already 4/4 spec'd → out.
- **No dialyzer is wired** (only credo). Specs are **not** machine-checked —
  they are documentation + tooling hints. Correctness comes from careful
  per-function reading + `mix compile --warnings-as-errors` (catches malformed
  specs, unknown types, arity/clause mismatches). Adding dialyzer is **out of
  scope** (separate heavier decision; note as possible follow-up only).
- **Multi-clause functions get ONE `@spec`** above the first clause.
- **No logic changes.** Specs only. Iron Law #5 host-loops in
  `calculate_measurement_probability`/`collapse_to_measurement` are
  pre-existing and untouched.
- **`defn`/`defnp` specs:** treat them as normal functions from the caller's
  view — tensor args are `Nx.Tensor.t()`, the index/count args are the plain
  integers they're actually called with (`non_neg_integer()`/`pos_integer()`),
  return `Nx.Tensor.t()`. `@spec` on a `defn` is a legal attribute and compiles
  fine; it documents the call contract.
- **No CHANGELOG.** Adding `@spec` to existing functions (incl. the public
  `Qx.Simulation` ones) is additive documentation, not a breaking change → no
  CHANGELOG entry, no bump (Iron Law #6: non-breaking).

## Iron Law check

- **#6:** `Qx.Simulation` is on the declared-public surface, but adding correct
  `@spec`s changes no signature/behaviour → non-breaking, no bump. ✅
- **#5/#7/#8:** No kernels rewritten, no error paths, no tolerances touched. ✅

---

## Phase 1 — Shared `@type` aliases

> Define once, reuse everywhere. Keeps the 31 Simulation specs consistent.

- [x] [P1-T1] `lib/qx/simulation.ex` — added 10 `@typep` aliases (state, renorm,
      gate_name, qubit, bit, instruction, measurement, cbits, counts,
      timeline_item); all used, compile clean. Original below:
- [x] [P1-T1-detail] `lib/qx/simulation.ex` — add module `@typep` aliases below the
      existing `@type simulation_result` (use `@typep` since they're internal;
      `simulation_result` stays `@type` as it's already public-facing):

      ```elixir
      @typep state :: Nx.Tensor.t()
      @typep renorm :: :off | :measurement | {:every, pos_integer()}
      @typep gate_name :: atom()
      @typep qubit :: non_neg_integer()
      @typep bit :: 0 | 1
      # gate instruction 3-tuple as stored on the circuit
      @typep instruction :: {gate_name(), [qubit()], [number()]}
      @typep measurement :: {qubit(), non_neg_integer()}
      @typep cbits :: [non_neg_integer()]
      @typep counts :: %{optional([non_neg_integer()]) => pos_integer()}
      @typep timeline_item ::
               {:instruction, instruction()}
               | {:measurement, measurement()}
               | {:conditional, {non_neg_integer(), non_neg_integer(), [instruction()]}}
      ```
      Verify each alias compiles (no unused-type warning — every one is used
      in Phase 3/4; if `mix compile --warnings-as-errors` flags an unused
      `@typep`, drop or use it).
- [x] [P1-T2] `lib/qx/calc_fast.ex` — no aliases needed (tensors only); skip.
- [x] [P1-T3] `mix compile --warnings-as-errors` — clean.

## Phase 2 — CalcFast specs (`lib/qx/calc_fast.ex`, 6 fns)

- [x] [P2-T1] Public `apply_single_qubit_gate/4` (2 clauses, ONE spec):
      `@spec apply_single_qubit_gate(Nx.Tensor.t(), Nx.Tensor.t(), non_neg_integer(), pos_integer()) :: Nx.Tensor.t()`
- [x] [P2-T2] `defn apply_single_qubit_gate_compiled/4` — same signature as T1.
- [x] [P2-T3] `defnp apply_single_qubit_gate_direct/4` — same signature.
- [x] [P2-T4] `defn apply_cnot/4`:
      `(Nx.Tensor.t(), non_neg_integer(), non_neg_integer(), pos_integer()) :: Nx.Tensor.t()`
- [x] [P2-T5] `defn apply_cswap/5` and `defn apply_toffoli/5`:
      `(Nx.Tensor.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), pos_integer()) :: Nx.Tensor.t()`
- [x] [P2-T6] `mix compile --warnings-as-errors` + `mix test test/qx/calc_fast_test.exs`
      (if it exists; else defer to the full-suite gate) — clean/green.

## Phase 3 — Simulation public `def` specs (3 fns)

- [x] [P3-T1] `run/2`: `@spec run(QuantumCircuit.t(), keyword()) :: simulation_result()`
- [x] [P3-T2] `get_state/2`: `@spec get_state(QuantumCircuit.t(), keyword()) :: Nx.Tensor.t()`
- [x] [P3-T3] `get_probabilities/2`: `@spec get_probabilities(QuantumCircuit.t(), keyword()) :: Nx.Tensor.t()`

## Phase 4 — Simulation `defp` specs (28 fns, batched by role)

> Each is ONE `@spec` per function (multi-clause groups noted). All use the
> Phase-1 aliases. `mix compile --warnings-as-errors` after each batch.

- [x] [P4-T1] **Renorm resolution:** `resolve_renormalize/1 :: (keyword()) :: renorm()`;
      `to_renorm/1` (3 clauses) `:: (false | true | pos_integer()) :: renorm()`.
- [x] [P4-T2] **Run orchestration:** `run_without_conditionals/3` &
      `run_with_conditionals/3` `:: (QuantumCircuit.t(), pos_integer(), renorm()) :: simulation_result()`;
      `has_measurements?/1` & `has_conditionals?/1` `:: (QuantumCircuit.t()) :: boolean()`.
- [x] [P4-T3] **Execution core:** `execute_circuit/2 :: (QuantumCircuit.t(), renorm()) :: state()`;
      `apply_gate_step/5 :: (state(), instruction(), non_neg_integer(), non_neg_integer(), renorm()) :: {state(), non_neg_integer()}`;
      `maybe_measurement_renorm/2` (2 clauses) `:: (state(), renorm()) :: state()`;
      `maybe_gate_renorm/3` (2 clauses) `:: (state(), renorm(), non_neg_integer()) :: state()`;
      `assert_norm/1 :: (state()) :: state()`;
      `real_state_to_complex/1 :: (Nx.Tensor.t()) :: state()`.
- [x] [P4-T4] **Gate dispatch:**
      `apply_instruction/3 :: (instruction(), state(), non_neg_integer()) :: state()`;
      `apply_single_qubit_op/5 :: (gate_name(), [qubit()], [number()], state(), non_neg_integer()) :: state()`;
      `apply_parameterized_single_qubit_op/5 :: (gate_name(), qubit(), [number()], state(), non_neg_integer()) :: state()`;
      `apply_two_qubit_op/5 :: (gate_name(), [qubit()], [number()], state(), non_neg_integer()) :: state()`;
      `apply_controlled_target_op/6 :: (gate_name(), qubit(), qubit(), [number()], state(), non_neg_integer()) :: state()`;
      `apply_three_qubit_op/5` (3 clauses) `:: (gate_name(), [qubit()], [number()], state(), non_neg_integer()) :: state()`.
- [x] [P4-T5] **Measurement & sampling:**
      `perform_measurements/3 :: (QuantumCircuit.t(), state(), pos_integer()) :: {[[bit()]] | [], counts()}`
      (returns `{[], %{}}` when no measurements — `[[bit()]]` covers the
      populated case; verify the empty-list union compiles cleanly, else use
      `[list(bit())]`);
      `generate_samples/2 :: ([float()], pos_integer()) :: [non_neg_integer()]`;
      `extract_classical_bits/3 :: ([non_neg_integer()], [measurement()], non_neg_integer()) :: [[bit()]]`;
      `perform_single_measurement/3 :: (state(), qubit(), non_neg_integer()) :: {state(), bit()}`;
      `calculate_measurement_probability/4 :: (state(), qubit(), bit(), non_neg_integer()) :: float()`;
      `collapse_to_measurement/4 :: (state(), qubit(), bit(), non_neg_integer()) :: state()`.
- [x] [P4-T6] **Conditional timeline:**
      `execute_single_shot/2 :: (QuantumCircuit.t(), renorm()) :: {state(), cbits()}`;
      `create_instruction_timeline/1 :: (QuantumCircuit.t()) :: [timeline_item()]`;
      `process_timeline_item/6 :: (timeline_item(), state(), cbits(), non_neg_integer(), non_neg_integer(), renorm()) :: {state(), cbits(), non_neg_integer()}`;
      `process_conditional/8 :: (cbits(), non_neg_integer(), non_neg_integer(), [instruction()], state(), non_neg_integer(), non_neg_integer(), renorm()) :: {state(), cbits(), non_neg_integer()}`.
- [x] [P4-T7] `mix compile --warnings-as-errors` — clean (all aliases now used).

## Verification (mandatory gate)

- [x] `mix compile --warnings-as-errors` — clean (PRIMARY spec correctness check).
- [x] `mix format --check-formatted` — clean.
- [x] `mix credo --strict` — 0 issues.
- [x] `mix test` — full suite green, unchanged counts (**242 doctests + 916
      tests, 0 failures**). Specs do not change behaviour.
- [x] `mix bench` — NOT needed (specs are compile-time only; no runtime effect).

## Out of scope

- Adding dialyzer / dialyxir (note as a possible future item — specs here are
  doc-only until something checks them).
- **qx-8gf** "Add WHY comments to bit-manipulation logic in CalcFast Nx.Defn
  blocks" — adjacent but separate; record in scratchpad, address on its own.
- `lib/qx/calc.ex` (already fully spec'd).

## Done = merge-ready

All phases checked, verification green at 242/916, `/phx:review` PASS (or
findings triaged). Squash-merge, tick ROADMAP qx-atv in that commit, push `main`.
