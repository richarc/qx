# Plan — CalcFast error-path & edge-case tests (qx-eb1)

**Branch:** `feat/calcfast-error-path-tests`
**Roadmap:** v0.8.1 "Test Coverage & Quality" — *Add error path tests
for CalcFast edge cases and invalid inputs (qx-eb1)*
**Type:** Pure test additions. No public API, no `lib/` changes.

## Goal

Pin the behaviour of the `Qx.CalcFast` kernels — single-qubit gate,
CNOT, CSWAP, Toffoli — with direct, isolated tests covering edge cases
(dispatch paths, boundary qubit indices, MSB convention) and invalid
inputs (out-of-range/negative qubits, malformed state/gate shapes).
The suite is a **regression net for the v0.8.2 CalcFast kernel
rewrite** (gather/`select` → reshape + 2×2 contraction), which is
otherwise unprotected because CalcFast is currently tested only
indirectly through `Qx.Calc` and `Qx.Simulation`.

## Context (verified)

- `Qx.CalcFast` is `@moduledoc false`, internal. Public surface:
  `apply_single_qubit_gate/4` (two heads: `num_qubits == 1` →
  `Nx.dot`; else compiled `defn`), `apply_cnot/4`, `apply_cswap/5`,
  `apply_toffoli/5`.
- **No validation in this layer** — typed `Qx.*Error`s live upstream
  in `Qx.Validation`/`Qx.Operations`. See scratchpad **D2**: invalid
  inputs get *characterization* tests, not typed-error assertions.
- No `test/qx/calc_fast_test.exs` exists today. Convention to mirror
  from `test/qx/calc_test.exs`: `alias Complex, as: C`, `:c64`
  tensors, local `complex_approx_equal?`/`state_approx_equal?`
  tolerance helpers. New file is `async: true` (scratchpad **D3**).
- MSB convention everywhere: `bit_pos = num_qubits - 1 - qubit`,
  qubit 0 = most-significant bit. Most rewrite-fragile invariant
  (scratchpad **D4**).

## Iron Law notes

- Test-only change; no `lib/` edits → Iron Law #7 (typed errors) is
  **not** triggered here. Do NOT add validation to the `defn` kernels.
- Verification gate (compile `--warnings-as-errors`, format, full
  test, cover) is mandatory — Phase 6.

---

## Phase 1 — Test scaffold

- [x] Create `test/qx/calc_fast_test.exs` with
      `use ExUnit.Case, async: true`, `alias Complex, as: C`,
      `alias Qx.{CalcFast, Gates}`.
- [x] Port local `complex_approx_equal?/3` and
      `state_approx_equal?/2,3` helpers (tolerance `1.0e-6`) from
      `calc_test.exs`.
- [x] Moduledoc-comment stating CalcFast is unvalidated by design and
      this file pins kernel behaviour as a v0.8.2-rewrite regression
      net (scratchpad **D2**).

## Phase 2 — `apply_single_qubit_gate/4` edge cases

- [x] **Single-qubit `Nx.dot` head** (`num_qubits == 1`): X, H, and
      identity on `|0⟩` and `|1⟩`; check exact amplitudes.
- [x] **Multi-qubit compiled head**: X on qubit 0 (MSB) of a 2-qubit
      `|00⟩` → `|10⟩`; X on qubit 1 (LSB) of `|00⟩` → `|01⟩` — proves
      MSB indexing.
- [x] X on a middle qubit in a 3-qubit system (qubit 1 of 3) —
      explicit basis-state check.
- [x] Identity gate leaves a non-trivial 3-qubit superposition
      unchanged (pairing-bug guard).
- [x] H on qubit 0 of a 2-qubit `|00⟩` → `(|00⟩+|10⟩)/√2`
      (amplitude correctness on the compiled path).

## Phase 3 — `apply_cnot/4` edge cases

- [x] Full 2-qubit truth table, control=0/target=1: `|00⟩→|00⟩`,
      `|01⟩→|01⟩`, `|10⟩→|11⟩`, `|11⟩→|10⟩`.
- [x] Reversed ordering control=1/target=0 on the same basis states
      (MSB both directions).
- [x] Non-adjacent control/target in a 3-qubit system (control 0,
      target 2).
- [x] Superposition: H(q0) then CNOT(0,1) on `|00⟩` →
      Bell `(|00⟩+|11⟩)/√2` (characterization through both kernels).

## Phase 4 — `apply_cswap/5` and `apply_toffoli/5` edge cases

- [x] CSWAP control=0 → no swap; control=1 with equal targets →
      no swap; control=1 with differing targets → swap. 3-qubit
      basis-state checks.
- [x] CSWAP with boundary target indices (0 and n-1).
- [x] Toffoli full 3-qubit truth table over all 8 basis states: flip
      target iff both controls = 1.
- [x] Toffoli with boundary control/target indices (0 and n-1).

## Phase 5 — Invalid-input / boundary characterization

> Scratchpad **D2**: assert the *actual* raw behaviour (raises an
> Nx/Erlang error, or a defined result). Do **not** assert
> `Qx.*Error`; do **not** add validation to `lib/`.

- [x] Out-of-range `target_qubit` (== `num_qubits`, so bit_pos < 0)
      for `apply_single_qubit_gate/4` — assert it raises (capture the
      actual error type/message and pin it).
- [x] Negative qubit index — assert raises.
- [x] State length ≠ `2^num_qubits` mismatch — assert the pinned
      behaviour (raise or defined-wrong result; document which).
- [x] Non-2×2 gate matrix — assert raises.
- [x] One invalid-input case each for `apply_cnot/4` /
      `apply_toffoli/5` (out-of-range qubit) so every kernel has at
      least one error-path test.

## Phase 6 — Verify (mandatory gate)

- [x] `mix compile --warnings-as-errors` clean.
- [x] `mix format` clean.
- [x] `mix test test/qx/calc_fast_test.exs` green.
- [x] `mix test` (full suite) green — no regressions.
- [x] `mix test --cover` — confirm `Qx.CalcFast` line coverage rises
      (currently covered only indirectly); note the new % in the
      commit / scratchpad.
- [x] `mix credo --strict` clean on the new file.

---

## Risks / self-check

- **What could make this wasted effort?** If the v0.8.2 rewrite
  changes the kernels' *public arities or contracts* (not just
  internals), some tests need updating. Mitigated: tests target the
  arity-4/5 public heads and observable amplitudes, which the rewrite
  intends to preserve — that's the whole point of the net.
- **Hidden coupling?** None — test-only, `async: true`, no shared
  state, no `lib/` edits.
- **Convention trap?** The MSB indexing (`num_qubits - 1 - qubit`).
  Phase 2/3 pin it with explicit basis states so a silent flip in the
  rewrite fails loudly.

## Out of scope (explicit)

- Adding validation / typed errors to CalcFast (perf-critical `defn`;
  separate concern — see scratchpad **D2**).
- `@spec` on CalcFast `defp`s (qx-atv) and WHY comments (qx-8gf) —
  deferred until *after* the v0.8.2 rewrite to avoid rework.
- Touching `Qx.Calc` / `Qx.Simulation` tests.
