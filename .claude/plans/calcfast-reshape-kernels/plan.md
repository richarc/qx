# Plan: CalcFast reshape + contraction kernels (incl. controlled-U)

**Branch:** `feat/calcfast-reshape-kernels`
**ROADMAP:** v0.12 — "Reshape `Qx.CalcFast` kernels…" (audit perf CRIT C1/C2, Iron Law #3).
Partially also closes v0.12 "Replace `2^n × 2^n` matrix materialisation in
SWAP / iSWAP / CP / CY / CRx / CRy / CRz" for the **`Qx.Simulation`** path
(see Scope — the `Qx.Register` calc-engine path is deliberately left alone).
**Depth:** standard
**Complexity:** 6 (+3 defn/Nx kernels, +3 crosses Calc/Simulation boundary, +2 two–three files, −2 follows existing kernel pattern) → `/phx:plan`

## Goal

Replace the `Nx.take` gather + `Nx.select` mask kernels in
`lib/qx/calc_fast.ex` with a single **general k-qubit contraction kernel**:
reshape the `{2^n}` state to rank-n `{2,…,2}`, contract a `2^k×2^k` gate
(reshaped to `{2,…,2}` of rank 2k) along the k target axes with `Nx.dot/4`,
transpose back, reshape to `{2^n}`. Route the single-qubit, CNOT, CSWAP,
Toffoli kernels **and** CP / CY / CRx / CRy / CRz / CZ / SWAP / iSWAP in
`Qx.Simulation` through it, eliminating every `Nx.dot(<2^n×2^n matrix>, state)`
from the simulation hot path.

## Scope

**In:**
- `lib/qx/calc_fast.ex` — new `apply_gate/4`-style contraction kernel (static
  qubits/n via `opts`), the four existing public entry points re-expressed
  on top of it (same names + arities, same results).
- Controlled-U as a 4×4 block matrix `|0⟩⟨0|⊗I + |1⟩⟨1|⊗U` contracted on
  `[c, t]`; SWAP / iSWAP / CZ as fixed 4×4; CCX / CSWAP as fixed 8×8.
- `lib/qx/calc.ex` — thin delegators for the new two-qubit entry points
  (keeps the Calc→CalcFast layering; qx-rut merge is a separate item).
- `lib/qx/simulation.ex` `apply_two_qubit_op/5` + `apply_controlled_target_op/6`
  call the kernel instead of `Gates.swap/iswap/controlled_gate`.
- New `bench/kernels_bench.exs` (per-gate, per-n micro-bench) + `mix bench` alias entry.

**Out (record in scratchpad / ROADMAP, don't do here):**
- `Qx.Register` (`lib/qx/register.ex:620,643,708`) still uses
  `Gates.swap/iswap/controlled_gate` — tier-3 calc engine slated for 1.0
  removal; not optimising code being removed. `Qx.Gates` n-qubit matrix
  builders therefore stay (and keep their tests).
- Measurement probability/collapse host loops (separate v0.12 item, C3).
- Gate-registry / multi-clause dispatch refactors (qx-agu, qx-dn2), Calc/CalcFast merge (qx-rut).
- Any public API change — none planned (all touched modules are `@moduledoc false`, tier 3).

## Decisions (see scratchpad for rationale)

- **D1 — one general kernel, not per-gate kernels.** Single code path ⇒ the MSB
  convention lives in one place; controlled-U is just a 4×4 matrix.
- **D2 — static qubits/n via `opts` keyword + `deftransformp`** for shape &
  permutation math (Nx: positional ints become tensors; `Enum`/`Kernel` not
  allowed in defn). Gate matrix stays a tensor ⇒ parameter changes never
  recompile; EXLA compiles once per distinct (qubits, n).
- **D3 — preserve every existing test unmodified** (TDD rule #2). The
  invalid-input characterization tests in `test/qx/calc_fast_test.exs:231–293`
  are honoured by: an explicit host-side `ArgumentError` for out-of-range /
  negative static qubit indices (in the deftransform), `Nx.reshape`'s own
  `ArgumentError` for state-length ≠ 2^n, and `Nx.slice(gate, [0,0], [2,2])`
  in the single-qubit wrapper to keep the "top-left 2×2 of an oversized gate"
  behaviour. If any of these can't be preserved, STOP and ask before touching the test.
- **D4 — keep the `num_qubits == 1` `Nx.dot` head** (trivial; already contraction).
- **D5 — Iron Law #8:** all new numerical assertions at `1.0e-6` (`:c64` floor).

## Risks

- **R1 — BinaryBackend may not win.** Qx ships without EXLA; BinaryBackend
  runs dot/transpose as Elixir loops over binaries (dot ≈ 1 ms n=10, 21 ms n=14
  per researcher). Old kernel ≈ 16 elementwise passes; new ≈ 1 dot + 1 transpose.
  Expected win, but **Phase 1 spike measures before committing**. If the new
  single-qubit kernel is slower on BinaryBackend at any n ≥ 8, STOP and surface
  data (memory: spec-infeasibility rule) — options: keep gather path for k=1 on
  BinaryBackend, or accept with justification.
- **R2 — axis-order bug flips MSB convention silently.** Mitigated by the
  existing truth-table tests + new reversed/non-adjacent qubit-order tests for
  every controlled-U and 3-qubit gate, checked against `Qx.Gates` full matrices
  (the old path) as an oracle.
- **R3 — EXLA cache growth** ~n^k executables per gate. Acceptable to n≈20;
  note in moduledoc comment. Not testable here (EXLA not a dep).
- **R4 — float reordering** breaks bit-identical comparisons; tolerances
  already widened to 1e-6 (c64-tolerances plan), so only tests below the floor
  would flip — grep for any `< 1.0e-6` deltas in Phase 2 before implementing.

## Phase 0 — Baseline (before ANY lib change)

- [x] [P0-T1] Existing `mix bench` suites (ghz, qft, renormalization) captured to
      `research/baseline/*.txt` at commit in `research/baseline/commit.txt`
      (run via `mix run bench/<x>_bench.exs` — the alias uses `--no-halt`)
- [x] [P0-T2] Write `bench/kernels_bench.exs`: per-kernel micro-bench (H on q0/q_mid/q_last,
      CX, CCX, CSWAP, CP, CRY, SWAP, iSWAP) at n = 4, 8, 12, 14, 16 on BinaryBackend
      calling `Qx.Calc` / the current Simulation paths; add to `mix bench` alias
      — one-gate circuits via `Qx.get_state/1`; matrix gates capped by
      `QX_BENCH_MAX_MATRIX_N` (default 10); alias now `&run_benches/1` w/ `Mix.Task.rerun`
- [x] [P0-T3] Run it on unmodified lib → `research/baseline/kernels.txt`; commit bench file + baselines
      — n=16: H ≈190–222 ms, CX 41 ms, CCX 44 ms, CSWAP 53 ms; n=8: CP 55 ms, SWAP 44 ms

## Phase 1 — Spike: contraction kernel feasibility (throwaway, outside lib/)

- [ ] [P1-T1] Scratch `.exs` (run with `mix run`) implementing the general k-qubit
      contraction defn; verify against old kernels on random states for k=1,2,3,
      all qubit orderings, n=3..6
- [ ] [P1-T2] Time new vs old single-qubit + CX + CP at n = 8, 12, 14, 16 on BinaryBackend;
      record in scratchpad. **Gate:** R1 decision before Phase 2

## Phase 2 — Tests first (must fail before Phase 3)

- [ ] [P2-T1] Grep test suite for tolerances < 1.0e-6 touching gate results (R4); report, don't edit
- [ ] [P2-T2] New `test/qx/calc_fast_contraction_test.exs`: general kernel vs
      `Qx.Gates` full-matrix oracle for k=1,2,3, every qubit permutation at n=3 and
      a non-adjacent sample at n=5, random normalised states, 1e-6
- [ ] [P2-T3] Controlled-U entry point: CP/CY/CRx/CRy/CRz/CZ with control>target and
      control<target, non-adjacent, vs `Gates.controlled_gate` oracle
- [ ] [P2-T4] SWAP / iSWAP entry points vs `Gates.swap` / `Gates.iswap` oracle, both orderings
- [ ] [P2-T5] Invalid-input characterization for the new entry points (ArgumentError class only, D3)
- [ ] [P2-T6] Simulation-level: QFT n=4 and a CRY/CSWAP mixed circuit — `Qx.get_state`
      matches pre-change values (computed in test via `Gates` matrices); run_steps too (Iron Law #9 execution test)
- [ ] [P2-T7] Static source check test: `lib/qx/calc_fast.ex` contains no `Nx.take` / `Nx.select`
      and `lib/qx/simulation.ex` no `Gates.swap|iswap|controlled_gate` (Iron Law #3 guard)
- [ ] [P2-T8] Run — confirm new tests fail for the right reason

## Phase 3 — Implement kernel

- [ ] [P3-T1] `deftransformp` helpers: validate static qubits (raise ArgumentError, D3),
      compute rank-n shape and inverse transpose perm
- [ ] [P3-T2] `defn apply_gate(state, gate, opts)` — reshape / `Nx.dot/4` / transpose / reshape;
      comment block documenting axis ↔ qubit mapping (MSB) replacing the XOR-trick comment
- [ ] [P3-T3] Re-express `apply_single_qubit_gate/4` (keep 1-qubit head, slice gate D3),
      `apply_cnot/4`, `apply_toffoli/5`, `apply_cswap/5` on `apply_gate`; delete gather code
- [ ] [P3-T4] Add `apply_controlled_gate/5` (builds 4×4 block from 2×2 U in-defn),
      `apply_swap/4`, `apply_iswap/4`; Calc delegators
- [ ] [P3-T5] `mix test test/qx/calc_fast_test.exs test/qx/calc_test.exs test/qx/calc_fast_contraction_test.exs` green
      (existing tests UNMODIFIED); verify gate (compile/format/credo)

## Phase 4 — Route Simulation through the kernel

- [ ] [P4-T1] `apply_two_qubit_op/5`: `:swap`, `:iswap` → kernel; `:cz` → controlled-Z
      (single contraction, replaces H·CX·H)
- [ ] [P4-T2] `apply_controlled_target_op/6` → `Calc.apply_controlled_gate/5`
- [ ] [P4-T3] Full `mix test` green; verify gate; `mix docs` warning count ≤ baseline

## Phase 5 — Measure & document

- [ ] [P5-T1] Re-run all four bench suites → `research/after/*.txt`; write
      `research/bench-comparison.md` (per-n speed-up table, BinaryBackend)
- [ ] [P5-T2] CHANGELOG `[Unreleased]` — Performance entry (internal, non-breaking)
- [ ] [P5-T3] Update the two ROADMAP v0.12 lines: tick the CalcFast item; amend the
      matrix-materialisation item to note the Simulation path is done and only the
      Register/`Qx.Gates` builders remain (or tick if user agrees they're out of scope pending 1.0)
- [ ] [P5-T4] `/phx:verify` → `/phx:review` (merge gate — stop for human authorization)

## Verification

`mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test`
after each phase; `mix bench` (kernels suite) after Phase 3 and 4.
