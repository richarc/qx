# Typed-error sweep #3 (v0.11, findings B-09/B-14/T1-10/R-04/R-09/R-10)

**Branch:** `fix/typed-error-sweep-3`
**ROADMAP:** v0.11 "Typed-error sweep #3"
**Depth:** standard · **Complexity:** 4 (4+ files +3, public error contract +3, follows sweeps #1/#2 pattern −2)
**Research:** none spawned — planning from `api-consistency-review/findings.md` §2 + sweep #1/#2 solution docs
(`route-validation-raises-to-typed-errors…`, `sweep-typed-errors-public-surface…`, both 20260624).
Site facts re-verified against `main`/branch 2026-07-08 (see scratchpad).

## Decision

Close every raw `FunctionClauseError`/`ArgumentError` escape named in
findings §2 by adding **fallback clauses routed onto the existing
`Qx.*Error` family** (new reason shapes allowed, new exception types only
if nothing fits — sweep #1/#2 precedent). Non-breaking: every input that
gains a typed raise crashes today. Ships in the 0.11 minor.

**Scope corrections vs the ROADMAP line (both pre-adjudicated):**
- "seven StateInit constructors" → **`basis_state/2,3` only**; the named
  constructors were deprecated by the tier trim (its scratchpad: do NOT
  add validation to them).
- `create_circuit` already raises `Qx.QubitCountError` for out-of-range
  integers (sweep #2); what remains is the **non-integer path** (currently
  FunctionClauseError, honestly advertised in docs) + the stale `## Raises`.

**normalize(zero-vector) decision (default choice, user AFK — VETO POINT):**
raise `Qx.StateNormalizationError` on zero-norm input. Design that satisfies
Iron Laws #5/#8: public `Qx.Math.normalize/1` becomes a host `def` that
checks the norm (one `Nx.to_number` sync) then delegates to a private
`defn normalize_unchecked/1`; the Simulation renorm hot path
(simulation.ex:438,445) switches to the internal unchecked path so no
per-step host sync is added. The check is a permanent public-path
validation, NOT compile-gated (gating it out of :prod would resurrect the
silent NaN — the bug being fixed). Perf proof: `mix bench` after.

### Target error mapping (scopes Phases 3–4)

| Site (today: raw FCE) | Typed raise |
|---|---|
| `QuantumCircuit.new` non-integer args (→ `create_circuit/1,2`) | `Qx.QubitCountError` (new `{:not_an_integer, value}`-style reason) |
| `Patterns.bell_state_circuit(:bogus)` (no fallback clause) | `Qx.OptionError` (`{:which, value}`; precedent: `:format`/`:version`) |
| `Patterns.ghz_state_circuit(1)` / non-integer | `Qx.QubitCountError` |
| `QuantumCircuit.add_gate` non-integer qubit (→ `h/x/y/z/rx/…` family) | `Qx.QubitIndexError` (reason variant, like `{:duplicate, …}` precedent) |
| same for the two-/three-qubit `add_*` builders (`cx(qc, "0", 1)` etc.) | `Qx.QubitIndexError` |
| `Operations.c_if` non-integer classical_bit (falls through all 4 clauses) | `Qx.ClassicalBitError` or `Qx.ConditionalError` (match existing shapes) |
| `StateInit.basis_state` non-integer / negative / index ≥ dimension | `Qx.BasisError` (reason variant) — survivors only |
| `SimulationResult.filter_by_probability(result, 1)` | **widen** guard to `is_number` in 0..1 (integer 1 is a valid probability — additive); out-of-range/non-number → `Qx.OptionError` (`{:threshold, value}`) |
| `Math.normalize(zero-vector)` → NaN today | `Qx.StateNormalizationError` |
| `rx/ry/rz/phase` skip param validation (detonate later in simulator) | `Qx.ParameterError` via existing `Validation.validate_parameter!/1` (siblings `u/cp/crx/cry/crz` already do) |

### Explicitly out of scope

- The 17 tier-trim-deprecated StateInit/Math functions (incl.
  `ghz_state_vector`'s documented FCE) — they die at 1.0.
- Any semantic tightening beyond error typing (e.g. `basis_state`
  power-of-two dimension checks) — behavior changes only for inputs that
  already crash.
- R-05/R-06 restyles (deferred to 1.0, unchanged).

---

## Phase 1 — Verify inventory (no product code)

- [x] [P1-T1] Probe each mapped site — all 16 confirm findings (probe table in
      scratchpad): every mapped site FCEs today; `normalize(zero)` → silent
      `[NaN, NaN]`; `rx(qc, 0, "pi")` stores bad param, detonates later
- [x] [P1-T2] Exception shapes pinned in scratchpad: new `{:not_an_integer, v}`
      variants on QubitCountError/QubitIndexError/ClassicalBitError; BasisError
      gains `:reason`/`:dimension` + 4 tuple clauses (catch-all kept last);
      OptionError `{:which,…}`/`{:threshold,…}` reuse existing 3-tuple clause
- [x] [P1-T3] Grep baseline: in-scope FCE docs = qx.ex:99,121 only (gates.ex
      @moduledoc false, state_init:326 deprecated — exempt). ZERO
      `assert_raise FunctionClauseError` in test/. Docs baseline 36; bench baseline saved

## Phase 2 — Tests first (TDD — **hook-guarded, needs human approval**)

- [x] [P2-T1] New `test/qx/typed_error_sweep_test.exs` (25 tests, all 4 clusters
      a–d). Red baseline confirmed: **22 failures** (all new typed-error
      assertions FCE today); 3 passers are the survivor-path tests
      (valid input already works)
- [x] [P2-T2] No existing-test edits — single new file. Existing suite untouched
      (tripwire: re-run full suite in Phase 6 to confirm none break)

## Phase 3 — Validation & Math

- [x] [P3-T1] `Qx.Math.normalize/1` → host `def`: `Nx.pow` norm check (not the
      `**` defn operator), raises `Qx.StateNormalizationError` on zero norm,
      delegates to private `defn normalize_unchecked/1` (byte-identical kernel).
      `@doc`/Raises note the raise + the "don't compose in your own defn" caveat
- [x] [P3-T2] Simulation renorm (438,445) → `Math.normalize_unchecked/1` (no
      per-renorm host sync; hot path stays pure defn — Iron Laws #5/#8).
      All other lib callers (qubit.ex 89/94/160, state_init 231) are plain
      `def`s, not `defn` — host-def change safe there
- [x] [P3-T3] `StateInit.basis_state/2,3` split default into bodiless head +
      fallback clause → `Qx.BasisError` (`:invalid_dimension`/`:not_an_integer`/
      `:negative`/`:out_of_range`, checked in priority order)
- [x] [P3-T4] `Qx.Validation`: added `validate_num_qubits!/1` non-integer
      fallback, `validate_qubit_index!/2` non-integer fallback,
      `validate_num_classical_bits!/1`, `validate_probability!/1`; new
      `{:not_an_integer,…}`/`{:invalid_count,…}` reason variants on the
      QubitCount/QubitIndex/ClassicalBit errors; BasisError gained
      `:reason`/`:dimension` + 4 tuple clauses (catch-all kept last)

## Phase 4 — Build-layer wiring

- [x] [P4-T1] `QuantumCircuit.new/1,2` fallback clauses (clause-grouped
      correctly) → `validate_num_qubits!`/`validate_num_classical_bits!`, which
      raise `QubitCountError`/`ClassicalBitError`. (Stale `## Raises` in
      lib/qx.ex handled in Phase 5.)
- [x] [P4-T2] `add_gate/4` + `add_two_qubit_gate/5`: dropped `is_integer(qubit)`
      from guards so non-integer reaches `validate_qubit_index!` →
      `QubitIndexError`. Verified: `cx` uses add_two_qubit_gate;
      `ccx`/`swap`/three-qubit already raised typed (`must be integers`) —
      untouched. Whole single-qubit wrapper family fixed at the choke point
- [x] [P4-T3] `Operations.rx/ry/rz/phase`: `Validation.validate_parameter!`
      first line (mirrors `u/5`)
- [x] [P4-T4] `Patterns.bell_state_circuit/1` fallback → `OptionError` (`:which`);
      `ghz_state_circuit/1` split default head + two fallbacks (int < 2 →
      `{n,2,20}`; non-integer → `{:not_an_integer,…}`), both `QubitCountError`
- [x] [P4-T5] `Operations.c_if/4` final `%QuantumCircuit{}` fallback (non-integer
      classical_bit) → `ClassicalBitError {:not_an_integer,…}`
- [x] [P4-T6] `filter_by_probability/2`: guard widened to `is_number … 0..1`,
      `@spec` → `number()`, fallback → `validate_probability!` → `OptionError`.
      Full suite 1030 tests/250 doctests: 0 failures (no existing-test breakage)

## Phase 5 — Docs & CHANGELOG

- [x] [P5-T1] `## Raises` updated/added: facade `create_circuit/1,2` (FCE lines
      dropped → QubitCount/ClassicalBit); facade + Operations `rx/ry/rz/phase`
      gained Raises (ParameterError + QubitIndexError); `basis_state` → BasisError;
      `filter_by_probability` → OptionError + threshold param note; `normalize`
      done in P3. Zero FCE in tier-1/2 docs (gates.ex/@moduledoc-false &
      deprecated ghz_state_vector exempt). `mix docs` still 36 warnings (≤ baseline)
- [x] [P5-T2] CHANGELOG `[Unreleased]`: **Fixed** = per-site sweep list
      ("non-breaking — every input already crashed") + `normalize` NaN→raise;
      **Changed** = `filter_by_probability` integer widening (additive, spec
      float→number) + `rx/ry/rz/phase` build-time validation

## Phase 6 — Gate & proof

- [x] [P6-T1] Probe re-run: all 16 sites raise their mapped `Qx.*Error`;
      `filter(result, 1)` returns `%{}`. Full table in scratchpad
- [x] [P6-T2] `mix bench` (renormalization): renorm hot path within noise
      (renormalize:10 0.132→0.128 K; false 0.134→0.136 K; short 3.25→3.26 K).
      No regression — renorm path now calls `normalize_unchecked/1`, the same
      `defn` kernel as before; no host sync added to the hot path
- [x] [P6-T3] Full gate PASS: `compile --warnings-as-errors` clean,
      `format --check-formatted` OK, `credo --strict` no issues,
      `mix test` 250 doctests + 1030 tests 0 failures, `mix docs` 36 warnings
      (= baseline, ≤ gate)

## Iron Laws check

- #7: the point of the sweep — all misuse raises become typed
  `Qx.*Error` routed through `Qx.Validation`.
- #6: non-breaking — typed raises replace crashes on already-invalid
  input; `filter_by_probability` widening is additive; `normalize`
  valid-input behavior unchanged. CHANGELOG required (Phase 5).
- #5/#8: `normalize` host sync confined to the public wrapper; hot-path
  renorm keeps the pure defn; the zero-check is a real validation, not a
  dev/test assertion, so it is NOT compile-gated. `mix bench` gates it.
- #3/#4: `normalize_unchecked` body identical to today's defn; correct
  on BinaryBackend by construction.
- #9: n/a (no instruction shapes added; c_if instruction tuple unchanged).
- TDD: Phase 2 before 3–4; new test file gated on human approval per hook.

## Risks

1. **normalize defn→def is observable**: anyone composing
   `Qx.Math.normalize/1` inside their own `defn` would break. Judged
   acceptable: tutorials/README teach host-side usage only; note in
   CHANGELOG. (VETO POINT along with the raise-vs-NaN default decision.)
2. **Renorm hot-path perf**: mitigated by unchecked internal path;
   `mix bench` is the gate.
3. **Guard-widening blind spots**: adding fallback clauses after guarded
   clauses must not shadow valid dispatch — Phase 2's "existing tests
   untouched and green" is the tripwire.
