# Bench comparison — vectorise-measurement

BinaryBackend, Apple Silicon. Baseline: `research/baseline/measurement.txt`
(lib @ 2bf4b78). After: `research/after/*.txt` (working tree on
feat/vectorise-measurement).

## Measurement suite (averages)

| Scenario | Before | After | Speed-up |
|---|---:|---:|---:|
| sample n=8 shots=1024 | 2.58 ms | 2.47 ms | 1.0× |
| sample n=8 shots=100000 | 108 ms | 60 ms | 1.8× |
| sample n=12 shots=1024 | 38.8 ms | 32.0 ms | 1.2× |
| sample n=12 shots=100000 | 937 ms | 141 ms | 6.6× |
| sample n=16 shots=1024 | 1152 ms | 1005 ms | 1.15× |
| sample n=16 shots=100000 | 14 087 ms | 1 207 ms | **11.7×** |
| c_if n=4 shots=256 | 69.4 ms | 71.6 ms | ~1.0× (noise) |
| c_if n=8 shots=256 | 724 ms | 645 ms | 1.12× |
| c_if n=12 shots=256 | 18 755 ms | 15 852 ms | 1.18× |
| steps n=12 (2 measurements) | 34.9 ms | 26.7 ms | 1.3× |
| steps n=14 (2 measurements) | 154 ms | 118 ms | 1.3× |

What the remaining time is:
- **sample, 1024 shots.** It is dominated by executing the n Hadamards (about
  50–60 ms each at n=16). Sampling is no longer the cost: the
  1024 → 100k shots delta at n=16 fell from 12.9 s to 0.2 s.
- **c_if.** It re-runs the whole circuit for every shot (n H gates × 256 shots).
  Measurement is a small fraction. That re-run is the separate ROADMAP item
  (cap retained state / don't re-run per shot), not this plan.

## One mid-circuit measurement, isolated

From `research/after/single-measurement-isolated.txt`: the old host loop
(re-implemented in a script) against `Calc.qubit_probabilities/3` +
`Calc.collapse/5`, on an H^⊗n state, qubit n/2, median of 5 runs.

| n | old | new |
|---:|---:|---:|
| 4 | 20 µs | 31 µs |
| 8 | 278 µs | 162 µs |
| 12 | 4.4 ms | 2.0 ms |
| 14 | 21.2 ms | 8.7 ms |

- On BinaryBackend `Nx.to_number(state[i])` is cheap, so the win is 2.2–2.4×,
  not orders of magnitude. With a device backend (EXLA/GPU) each of the old
  3·2^n syncs is a device→host transfer. The new path makes exactly one.
- R3 (small-n overhead): at n=4 the result is +11 µs, well under the 0.1 ms bound.

## Regression check (ghz / kernels suites)

These are unchanged within noise against
`.claude/plans/calcfast-reshape-kernels/research/after/`. For example, GHZ n=16
is 159.4 ms in both runs, and GHZ n=20 went from 5.21 s to 5.36 s (single
sample). H q_last n=16 went from 62.5 ms to 63.0 ms, and CX n=16 from 2.46 ms
to 2.61 ms. Neither suite touches the measurement code (`Qx.run(c, 1)` with no
measurements / `get_state`).
