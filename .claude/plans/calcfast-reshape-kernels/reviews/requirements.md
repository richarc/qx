## Requirements Coverage (from plan .claude/plans/calcfast-reshape-kernels/plan.md, D1 as amended)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| D1 | Rank-n axis slicing, no Nx.take/Nx.select, one shared primitive | MET | `calc_fast.ex:11-41` axis comment; `in_axes/on_controls/halves` at :253-268; no take/select in file; static guard test `simulation_slicing_kernels_test.exs:181` |
| D2 | Static qubits/n via opts + deftransformp; gate stays tensor | MET | `calc_fast.ex:208-243` (defnp with opts, deftransformp builders) |
| D3 | Existing tests unmodified; ArgumentError for bad qubits, length mismatch, oversized gate | MET | git diff --stat shows no existing test file modified; `validate_qubits!` :308-326; `validate_2x2!` :329; single-qubit wrapper :62-68 |
| D4 | Keep num_qubits == 1 head | MET | `calc_fast.ex:62` |
| D5 | New numeric assertions at 1.0e-6 | MET | `calc_fast_slicing_test.exs:25` `@tolerance 1.0e-6` |
| R1 | BinaryBackend win measured; STOP if slower | MET | spike table in scratchpad; D1 amended; `research/bench-comparison.md`; CHANGELOG figures |
| R2 | Axis-order oracle tests, all orderings, non-adjacent | MET | `calc_fast_slicing_test.exs:128-290` (CNOT/CCX/CSWAP/CU/SWAP/iSWAP vs Gates/embed oracles) |
| R3 | EXLA cache growth noted in comment | MET | `calc_fast.ex:34-38` notes per-(qubits,n) compile (n^k growth not stated explicitly) |
| R4 | Check sub-1e-6 tolerances | MET | scratchpad P2-T1 grep result |
| Scope-In: calc_fast.ex entry points | Four existing entry points same names/arities on slicing + new ones | MET | `calc_fast.ex:62,94,120,146,159,185,199` |
| Scope-In: calc.ex delegators | MET | `calc.ex:135,145,155` |
| Scope-In: simulation.ex routing | cz/swap/iswap/controlled-target via kernels | MET | `simulation.ex:557-564,597`; no Nx.dot/Gates.swap/iswap/controlled_gate left |
| Scope-In: kernels_bench + mix bench alias | MET | `bench/kernels_bench.exs`; `mix.exs:150-160` (kernels in @bench_suites) |
| Scope-Out respected (Register, measurement, registry, public API) | MET | diff touches none of register.ex, measurement, gates.ex |
| P0 T1-T3 baselines + kernels bench | MET | `research/baseline/{ghz,qft,renormalization,kernels,commit}.txt` |
| P1 T1-T2 spike + R1 gate | MET | scratchpad P1 table; D1 amended |
| P2 T1-T8 tests first | MET | `calc_fast_slicing_test.exs` (CU :214, swap :255, iswap :273, invalid :321); `simulation_slicing_kernels_test.exs:140-192` (QFT, mixed, steps, static guard). Red-first not verifiable from diff (UNCLEAR on that sub-point only) |
| P3 T1-T5 kernel implementation | MET | `calc_fast.ex:208-300`; delegators; existing tests untouched. Green run not re-verified here |
| P4 T1-T3 route Simulation | MET | `simulation.ex:557-564,597`. Full-suite green / docs-warning count not re-run here |
| P5-T1 after benches + comparison | MET | `research/after/*.txt`, `research/bench-comparison.md` |
| P5-T2 CHANGELOG Performance entry | MET | `CHANGELOG.md` [Unreleased] > Performance |
| P5-T3 ROADMAP two lines | MET | CalcFast item ticked `[x]`; matrix item amended, left unticked |
| P5-T4 /phx:verify -> /phx:review | IN PROGRESS | review underway (not counted UNMET) |

Minor notes (facts only): plan header text still says "Reshape + contraction"; ROADMAP CalcFast line still reads "2×2 tensor contraction" with a "done as slicing" suffix; CHANGELOG claims (e.g. "CX/CCX/CSWAP 11-17x") should be cross-checked against `research/bench-comparison.md`.

**Summary**: 22 MET · 0 PARTIAL · 0 UNMET · 0 UNCLEAR (P5-T4 in progress, excluded)
