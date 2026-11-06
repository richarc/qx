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
`lib/qx/calc_fast.ex` with **rank-n axis-slicing kernels** (D1, amended
2026-11-06 after the P1 spike): reshape the `{2^n}` state to rank-n
`{2,…,2}` (axis q ↔ qubit q, MSB), take static `Nx.slice_along_axis`
halves on control/target axes, apply the sub-op to the control=1 slice
(2×2 elementwise combine / `Nx.reverse` / `Nx.transpose`), `Nx.concatenate`
back, reshape to `{2^n}`. Route the single-qubit, CNOT, CSWAP, Toffoli
kernels **and** CP / CY / CRx / CRy / CRz / CZ / SWAP / iSWAP in
`Qx.Simulation` through them, eliminating every `Nx.dot(<2^n×2^n matrix>, state)`
from the simulation hot path.

## Scope

**In:**
- `lib/qx/calc_fast.ex` — one slicing primitive (`on_controls` + per-op
  slice ops; static qubits/n via `opts`), the four existing public entry
  points re-expressed on top of it (same names + arities, same results).
- Controlled-U = 2×2 combine on the target axis of the control=1 slice;
  CX/CCX = `Nx.reverse` of the target axis on the control slice(s);
  SWAP/CSWAP = axis transpose (on the control slice for CSWAP); iSWAP =
  swap of the a≠b blocks with an `i` phase; CZ/CP via controlled-U.
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

- **D1 (amended 2026-11-06, user decision after P1 spike) — rank-n axis slicing,
  not dense 2^k×2^k contraction.** Dense contraction regressed CX 4–7× and CCX ~8×
  vs the old gather kernels on BinaryBackend; slicing beats old AND dense on every
  gate (scratchpad P1 table). One shared primitive (reshape ↔ axes + control-slice
  recursion) keeps the MSB axis mapping in one place. No `Nx.take`/`Nx.select`
  (Iron Law #3 intent: no gather/mask); static slices/concats fuse under EXLA.
- **D2 — static qubits/n via `opts` keyword + `deftransformp`** for shape &
  permutation math (Nx: positional ints become tensors; `Enum`/`Kernel` not
  allowed in defn). Gate matrix stays a tensor ⇒ parameter changes never
  recompile; EXLA compiles once per distinct (qubits, n).
- **D3 — preserve every existing test unmodified** (TDD rule #2). The
  invalid-input characterization tests in `test/qx/calc_fast_test.exs:231–293`
  are honoured by: an explicit host-side `ArgumentError` for out-of-range /
  negative / duplicate static qubit indices (in the `def` wrapper), `Nx.reshape`'s own
  `ArgumentError` for state-length ≠ 2^n, and `Nx.slice(gate, [0,0], [2,2])`
  in the single-qubit wrapper to keep the "top-left 2×2 of an oversized gate"
  behaviour. If any of these can't be preserved, STOP and ask before touching the test.
- **D4 — keep the `num_qubits == 1` `Nx.dot` head** (trivial; already contraction).
- **D5 — Iron Law #8:** all new numerical assertions at `1.0e-6` (`:c64` floor).

## Risks

- **R1 — BinaryBackend may not win.** *(Realised for dense contraction on CX/CCX →
  D1 amended to slicing; see scratchpad P1 table.)* Qx ships without EXLA; BinaryBackend
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

- [x] [P1-T1] Scratch `.exs` (run with `mix run`) implementing the general k-qubit
      contraction defn; verify against old kernels on random states for k=1,2,3,
      all qubit orderings, n=3..6 — dense correct for k=1..3 all orderings; slice
      variants (1q, CX, CCX, CU, CP-mask, SWAP) correct at n=5 (session scratchpad, throwaway)
- [x] [P1-T2] Time new vs old single-qubit + CX + CP at n = 8, 12, 14, 16 on BinaryBackend;
      record in scratchpad. **Gate:** R1 decision before Phase 2 — dense regresses
      CX/CCX 4–8×; user chose slice kernels (D1 amended); n=16 H 190→50–63, CX 33→2.4–9 ms

## Phase 2 — Tests first (must fail before Phase 3)

- [x] [P2-T1] Grep test suite for tolerances < 1.0e-6 touching gate results (R4); report, don't edit
      — none touch gate results (all host f64 param/expr checks); see scratchpad
- [x] [P2-T2] New `test/qx/calc_fast_slicing_test.exs`: every entry point (1q, CX,
      CCX, CSWAP) vs a test-local full-matrix embedding oracle (k=1,2,3), every qubit
      permutation at n=3 and a non-adjacent sample at n=5, random normalised states, 1e-6 — `embed/3` index-arithmetic oracle + `Qx.Gates` cross-check; random states via Nx.Random
- [x] [P2-T3] Controlled-U entry point: CP/CY/CRx/CRy/CRz/CZ with control>target and
      control<target, non-adjacent, vs `Gates.controlled_gate` oracle — 6 target gates × (all n=3 pairs + 6 n=5 samples) + n=2 case
- [x] [P2-T4] SWAP / iSWAP entry points vs `Gates.swap` / `Gates.iswap` oracle, both orderings
- [x] [P2-T5] Invalid-input characterization for the new entry points (ArgumentError class only, D3) — also: repeated qubits now ArgumentError on cnot/toffoli/cswap; non-integer index
- [x] [P2-T6] Simulation-level: QFT n=4 and a CRY/CSWAP mixed circuit — `Qx.get_state`
      matches pre-change values (computed in test via `Gates` matrices); run_steps too (Iron Law #9 execution test) — `test/qx/simulation_slicing_kernels_test.exs`: QFT n=4, QFT n=5 on non-trivial input, 17-gate mixed circuit; every `steps/2` prefix
- [x] [P2-T7] Static source check test: `lib/qx/calc_fast.ex` contains no `Nx.take` / `Nx.select`
      and `lib/qx/simulation.ex` no `Gates.swap|iswap|controlled_gate` (Iron Law #3 guard) — comment lines stripped before matching
- [x] [P2-T8] Run — confirm new tests fail for the right reason — 12 red (undefined fns, static guards, repeated-qubit raise); oracle tests for existing kernels + Simulation already green (oracle validated vs old code)

## Phase 3 — Implement kernel

- [x] [P3-T1] Host `validate_qubits!/2` (ArgumentError, D3) + `deftransformp` helpers:
      rank-n shape, flatten, control-slice recursion, swap permutation — `validate_qubits!/2` (range, integer, distinct, num_qubits ≥ 1) + `validate_2x2!/1` in `def` wrappers; `deftransformp` `*_expr` builders call plain `defp` slicing primitives (`in_axes/4`, `on_controls/3`, `halves/2`)
- [x] [P3-T2] `defnp` kernels (mix / flip / swap / iswap) over the shared primitive;
      comment block documenting axis ↔ qubit mapping (MSB) replacing the XOR-trick comment — `unitary_kernel` / `flip_kernel` / `swap_kernel` / `iswap_kernel` defnp's; axis↔qubit comment block replaces XOR-trick comment
- [x] [P3-T3] Re-express `apply_single_qubit_gate/4` (keep 1-qubit head, slice gate D3),
      `apply_cnot/4`, `apply_toffoli/5`, `apply_cswap/5` on the kernels; delete gather code — public fns now `def` (were `defn`); all gather/select code deleted; 3×3-gate characterization holds (kernel reads only gate[0..1][0..1])
- [x] [P3-T4] Add `apply_controlled_gate/5` (2×2 U on the control=1 slice),
      `apply_swap/4`, `apply_iswap/4`; Calc delegators — CU = `mix_axis` on control slice; SWAP/CSWAP = transpose; iSWAP = block exchange × i
- [x] [P3-T5] `mix test test/qx/calc_fast_test.exs test/qx/calc_test.exs test/qx/calc_fast_slicing_test.exs` green
      (existing tests UNMODIFIED); verify gate (compile/format/credo) — 61 passed, existing tests untouched

## Phase 4 — Route Simulation through the kernel

- [x] [P4-T1] `apply_two_qubit_op/5`: `:swap`, `:iswap` → kernel; `:cz` → controlled-Z
      (single controlled-U kernel, replaces H·CX·H)
- [x] [P4-T2] `apply_controlled_target_op/6` → `Calc.apply_controlled_gate/5`
- [x] [P4-T3] Full `mix test` green; verify gate; `mix docs` warning count ≤ baseline — 1426 passed (328 doctests); credo clean (flattened 2 nested test helpers); docs warnings 29 → 29, identical list

## Phase 5 — Measure & document

- [x] [P5-T1] Re-run all four bench suites → `research/after/*.txt`; write
      `research/bench-comparison.md` (per-n speed-up table, BinaryBackend) — QFT n=10 82.4 s→24.6 ms; GHZ n=20 18.3→5.2 s; no regressions in any suite
- [x] [P5-T2] CHANGELOG `[Unreleased]` — Performance entry (internal, non-breaking)
- [x] [P5-T3] Update the two ROADMAP v0.12 lines: tick the CalcFast item; amend the
      matrix-materialisation item to note the Simulation path is done and only the
      Register/`Qx.Gates` builders remain (or tick if user agrees they're out of scope pending 1.0) — CalcFast item ticked; matrix-materialisation item amended (Simulation done; Register/Gates builders remain), left unticked pending user
- [ ] [P5-T4] `/phx:verify` → `/phx:review` (merge gate — stop for human authorization)

## Verification

`mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test`
after each phase; `mix bench` (kernels suite) after Phase 3 and 4.
