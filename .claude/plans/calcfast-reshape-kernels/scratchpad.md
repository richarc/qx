# Scratchpad: calcfast-reshape-kernels

## Decisions

- **D1 one general k-qubit kernel.** User asked (2026-11-06) to include
  controlled-U. A generic "contract 2^k×2^k gate on k static axes" covers
  1q gates, controlled-U (4×4 block), SWAP/iSWAP/CZ (4×4), CCX/CSWAP (8×8)
  with a single MSB-axis mapping. Cost per gate O(2^n · 2^k) — k ≤ 3 so fine.
- **D2 static opts.** Researcher (research/hex-library-researcher-report.md):
  positional ints in defn are tensors → can't drive reshape; use
  `opts \\ []` + `keyword!` and `deftransformp` for perm/shape math.
  Current code passes target/num_qubits positionally (tensors) — the
  bit-twiddling worked only because it never needed static shapes.
- **D3 existing characterization tests stay untouched.** `calc_fast_test.exs:231–293`
  pin ArgumentError for bad qubits / wrong state length and "oversized gate uses
  top-left 2×2". Preserve via explicit ArgumentError in the transform + slice.
- **Inverse permutation:** `Nx.dot(g, [k..2k-1], s, targets)` output axes =
  gate output axes (k) ++ state non-target axes in order. perm[a] = index of a
  in targets if target, else k + rank of a among non-targets. Order of
  `targets` matters (gate input axis j ↔ targets[j]).

## Out of scope / discovered

- `Qx.Register` still builds 2^n×2^n matrices for swap/iswap/controlled
  (register.ex:620,643,708). Tier-3, removed at 1.0 — leave.
- `mix bench` alias uses `run --no-halt` for 3 files — the first never exits,
  so the alias only ever runs ghz. Baseline captured with `mix run` per file.
  Fix the alias in P0-T2 (drop `--no-halt`).
- Dev deps were stale vs mix.lock (nx 0.13 / mint 1.9.3 / credo / dialyxir
  never fetched in dev); `mix deps.get` fixed it, lock unchanged.
- `Qx.Gates.toffoli/4` is dead legacy code: returns a `{2^n, 2^n, 2}` real/imag
  triple tensor, uses LSB bit positions (`bsr(i, control1)`), and has no callers.
  Can't be an oracle — tests build the CCX oracle by permuting `Nx.eye`. Delete or
  fix in a separate cleanup (tier 3, `@moduledoc false`).
- `mix bench` alias: listing `run` 4× only ever runs the first (Mix skips an
  already-run task). Replaced with a `&run_benches/1` function using
  `Mix.Task.rerun/2` (P0-T2).
- `mix.exs` warns: `:preferred_cli_env` deprecated → move to `def cli` (Elixir 1.20). Tech debt.

## Baseline (P0-T1, commit c8bf90e, BinaryBackend, Qx.run shots=1)

| Suite | n | avg |
|---|---|---|
| GHZ | 10 / 14 / 16 / 18 / 20 | 5.19 ms / 167 ms / 725 ms / 3.61 s / 18.3 s |
| QFT (CP + SWAP via 2^n×2^n matrices) | 6 / 8 / 9 / 10 | 28.2 ms / 1.73 s / 9.70 s / **82.4 s** |
| renormalization | short / long(100) | ~0.31 ms / ~7.6 ms |

QFT n=10 at 82 s vs GHZ n=10 at 5 ms shows the matrix-materialisation cost
directly — biggest expected win is Phase 4 (CP/SWAP routing).

## P2-T1 — tolerance grep (R4)

No gate-RESULT assertion below 1e-6. The sub-1e-6 deltas in the suite are all
host-side f64 parameter / OpenQASM expr checks (cp_gate_test:11, u_gate_test,
operations_controlled_rotations_test:61, export/openqasm/*), a counts-based
probability (simulation_result_seam_test:42), or a nonzero threshold
(u_gate_convention_test:104). Permutation gates via contraction multiply by
exact 0/1, so exact-zero assertions (`probability("01") == 0.0`) stay exact.

## P1 spike — R1 gate data (BinaryBackend, c64, ms/op, 2026-11-06)

Correctness: dense k-qubit contraction matches old kernels / `Qx.Gates` oracles
for k=1,2,3, every ordering, n=3..6 (atol 1e-6). Slice variants match at n=5.

"dense" = plan D1 (reshape → `Nx.dot` 2^k×2^k gate on k axes → transpose).
"slice" = reshape rank-n → `Nx.slice_along_axis` on control/target axes →
op on the slice (reverse / 2×2 elementwise combine / transpose) →
`Nx.concatenate`. Neither uses `Nx.take`/`Nx.select`.

| op | n | old | dense | slice |
|---|---|---|---|---|
| H (q0/mid/last) | 8 | 0.51–0.53 | 0.25–0.28 | 0.18–0.22 |
| H | 12 | 8.1–8.2 | 4.4 | 2.1–2.7 |
| H | 14 | 46 | 21–22 | 11–14.5 |
| H | 16 | 188–191 | 134–135 | 50–63 |
| CX (0,last) | 8 / 12 / 14 / 16 | 0.10 / 1.5 / 7.7 / 33 | 0.43 / 7.3 / 37 / **223** | 0.015 / 0.12 / 0.42 / 2.4 (c=last,t=0: 9.2) |
| CCX | 8 / 12 / 14 / 16 | 0.15 / 2.0 / 10 / 44 | 0.74 / 12 / 62 / **364** | 0.03 / 0.21 / 0.76 / 3.6 |
| CP / CU(RY) | 16 | 2^n×2^n matrix (55 ms @ n=8) | 223 | CU 47; diagonal-mask CP 36 |
| SWAP | 16 | matrix (44 ms @ n=8) | — | transpose 5.8 |

**R1 verdict:** dense contraction wins for 1q (1.4–2×) but REGRESSES CX 4–7×
and CCX ~8× vs today's gather kernels. D1 as written is infeasible for
"same or better" on BinaryBackend. Slice approach beats old AND dense
everywhere. → Surfaced to user for D1 amendment (memory: spec-infeasibility).

## Dead-ends

- **Dense 2^k×2^k contraction for permutation / controlled gates** (D1 as
  planned): multiplies by mostly-zero blocks; 4×4 CX is 5–7× slower and 8×8
  CCX ~8× slower than the old gather kernels on BinaryBackend (table above).

(none yet)
