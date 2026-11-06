# Bench comparison — calcfast-reshape-kernels

BinaryBackend (no EXLA), Elixir 1.20.2 / OTP 29, Nx 0.13.0, same machine.
**Before** = commit `c8bf90e` (gather/select kernels + 2^n×2^n matrices for
CP/CY/CRx/CRy/CRz/SWAP/iSWAP). **After** = rank-n axis-slicing kernels with all
two-qubit gates routed through `Qx.CalcFast`. Raw Benchee output is in
`baseline/` and `after/`. Kernel scenarios are one-gate circuits through
`Qx.get_state/1`. "capped" = the old matrix path at that n needs a
2^n×2^n c64 matrix (34 GB at n=16), so it wasn't run.

## Headline

- QFT n=10: **82.4 s → 24.6 ms (≈3350×)**. n=8: 1.73 s → 5.7 ms.
- GHZ n=20: 18.3 s → 5.2 s (3.5×). n=14: 167 → 28 ms (6×).
- Single-qubit gates (n=16): ≈190–222 ms → 46–63 ms (3.3–4.1×).
- CX / CCX / CSWAP (n=16): 41 / 44 / 53 ms → 2.5 / 4.1 / 3.3 ms (11–17×).
- CP / CRY / SWAP / iSWAP now run at n=16 (31 / 37 / 7 / 17 ms); before they were 44–55 ms at **n=8** and infeasible past n≈12.
- Renormalization suite: short 309 → 132 µs, long(100) 7.56 → 3.27 ms (2.3×).

## Why slicing, not dense contraction

See `../scratchpad.md` (P1 spike table): a dense 2^k×2^k `Nx.dot` contraction
beat the old kernels for single-qubit gates, but it regressed CX 4–7× and CCX ~8×,
because it multiplies through mostly-zero blocks. Slicing beat both on every gate.

## ghz

| Scenario | Before | After | Speed-up |
|---|---:|---:|---:|
| GHZ n=2 | 99.2 µs | 42.8 µs | 2.3× |
| GHZ n=4 | 178.0 µs | 69.0 µs | 2.6× |
| GHZ n=6 | 400.0 µs | 133.0 µs | 3.0× |
| GHZ n=8 | 1.29 ms | 360.0 µs | 3.6× |
| GHZ n=10 | 5.19 ms | 1.43 ms | 3.6× |
| GHZ n=12 | 23.31 ms | 5.93 ms | 3.9× |
| GHZ n=14 | 167.25 ms | 28.04 ms | 6.0× |
| GHZ n=16 | 724.52 ms | 159.46 ms | 4.5× |
| GHZ n=18 | 3.61 s | 895.20 ms | 4.0× |
| GHZ n=20 | 18.31 s | 5.21 s | 3.5× |

## qft

| Scenario | Before | After | Speed-up |
|---|---:|---:|---:|
| QFT n=2 | 187.0 µs | 113.0 µs | 1.7× |
| QFT n=3 | 440.0 µs | 250.0 µs | 1.8× |
| QFT n=4 | 1.49 ms | 490.0 µs | 3.0× |
| QFT n=5 | 5.80 ms | 890.0 µs | 6.5× |
| QFT n=6 | 28.24 ms | 1.61 ms | 17.5× |
| QFT n=7 | 141.93 ms | 2.98 ms | 47.6× |
| QFT n=8 | 1.73 s | 5.70 ms | 304.0× |
| QFT n=9 | 9.70 s | 11.72 ms | 828.0× |
| QFT n=10 | 82.36 s | 24.61 ms | 3346.6× |

## kernels

| Scenario | Before | After | Speed-up |
|---|---:|---:|---:|
| CCX n=4 | 50.1 µs | 11.7 µs | 4.3× |
| CCX n=8 | 190.0 µs | 23.2 µs | 8.2× |
| CCX n=12 | 2.46 ms | 199.3 µs | 12.3× |
| CCX n=14 | 8.59 ms | 842.4 µs | 10.2× |
| CCX n=16 | 44.32 ms | 4.05 ms | 10.9× |
| CP n=4 | 128.0 µs | 45.0 µs | 2.8× |
| CP n=8 | 55.46 ms | 120.8 µs | 459.2× |
| CP n=12 | — | 1.31 ms | new (was OOM / capped) |
| CP n=14 | — | 5.07 ms | new (was OOM / capped) |
| CP n=16 | — | 31.28 ms | new (was OOM / capped) |
| CRY n=4 | 177.0 µs | 46.8 µs | 3.8× |
| CRY n=8 | 48.76 ms | 168.2 µs | 289.9× |
| CRY n=12 | — | 1.56 ms | new (was OOM / capped) |
| CRY n=14 | — | 7.02 ms | new (was OOM / capped) |
| CRY n=16 | — | 36.86 ms | new (was OOM / capped) |
| CSWAP n=4 | 51.1 µs | 6.9 µs | 7.4× |
| CSWAP n=8 | 181.0 µs | 13.9 µs | 13.0× |
| CSWAP n=12 | 2.41 ms | 142.9 µs | 16.9× |
| CSWAP n=14 | 12.62 ms | 576.2 µs | 21.9× |
| CSWAP n=16 | 52.71 ms | 3.27 ms | 16.1× |
| CX n=4 | 32.5 µs | 6.6 µs | 5.0× |
| CX n=8 | 102.0 µs | 19.4 µs | 5.2× |
| CX n=12 | 1.80 ms | 110.0 µs | 16.4× |
| CX n=14 | 6.16 ms | 484.8 µs | 12.7× |
| CX n=16 | 41.32 ms | 2.46 ms | 16.8× |
| H q0 n=4 | 96.8 µs | 41.0 µs | 2.4× |
| H q0 n=8 | 520.0 µs | 162.5 µs | 3.2× |
| H q0 n=12 | 6.90 ms | 2.03 ms | 3.4× |
| H q0 n=14 | 46.86 ms | 7.98 ms | 5.9× |
| H q0 n=16 | 189.94 ms | 46.32 ms | 4.1× |
| H q_last n=4 | 98.6 µs | 43.6 µs | 2.3× |
| H q_last n=8 | 520.0 µs | 190.6 µs | 2.7× |
| H q_last n=12 | 6.93 ms | 3.06 ms | 2.3× |
| H q_last n=14 | 55.06 ms | 12.57 ms | 4.4× |
| H q_last n=16 | 222.16 ms | 62.54 ms | 3.6× |
| H q_mid n=4 | 108.0 µs | 42.9 µs | 2.5× |
| H q_mid n=8 | 530.0 µs | 179.7 µs | 2.9× |
| H q_mid n=12 | 6.91 ms | 2.84 ms | 2.4× |
| H q_mid n=14 | 46.76 ms | 12.04 ms | 3.9× |
| H q_mid n=16 | 190.45 ms | 57.87 ms | 3.3× |
| SWAP n=4 | 104.0 µs | 3.5 µs | 29.5× |
| SWAP n=8 | 44.28 ms | 14.2 µs | 3122.7× |
| SWAP n=12 | — | 266.5 µs | new (was OOM / capped) |
| SWAP n=14 | — | 1.19 ms | new (was OOM / capped) |
| SWAP n=16 | — | 7.07 ms | new (was OOM / capped) |
| empty n=4 | 0.1 µs | 0.1 µs | 1.1× |
| empty n=8 | 0.1 µs | 0.1 µs | 0.9× |
| empty n=12 | 0.1 µs | 0.1 µs | 1.0× |
| empty n=14 | 0.1 µs | 0.1 µs | 1.0× |
| empty n=16 | 0.1 µs | 0.2 µs | 0.6× |
| iSWAP n=4 | 136.0 µs | 21.8 µs | 6.2× |
| iSWAP n=8 | 43.87 ms | 69.5 µs | 631.1× |
| iSWAP n=12 | — | 936.1 µs | new (was OOM / capped) |
| iSWAP n=14 | — | 3.63 ms | new (was OOM / capped) |
| iSWAP n=16 | — | 16.65 ms | new (was OOM / capped) |

## renormalization

| Scenario | Before | After | Speed-up |
|---|---:|---:|---:|
| short renormalize: false | 308.8 µs | 132.1 µs | 2.3× |
| short baseline (no opt) | 310.0 µs | 132.2 µs | 2.3× |
| short renormalize: true | 321.8 µs | 140.5 µs | 2.3× |
| long(100) renormalize: false | 7.56 ms | 3.27 ms | 2.3× |
