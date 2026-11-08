# Plan: Vectorise measurement probability/collapse and sample generation

**Branch:** `feat/vectorise-measurement`
**ROADMAP:** v0.12 — "Vectorise measurement probability and state collapse"
(audit perf CRIT C3, Iron Law #5) + "Vectorise sample generation" (audit perf HIGH).
**Depth:** standard
**Complexity:** 4 (+3 crosses Calc/Simulation, +3 CalcFast kernels, −2 follows the
slicing pattern from calcfast-reshape-kernels) → `/phx:plan`

## Goal

1. **Mid-circuit measurement** (`c_if` circuits in `run/2`, and every `steps/2`
   measurement) computes `{p0, p1}` for one qubit with Nx and **one** host sync,
   and collapses with static slices. Today it does ~3·2^n `Nx.to_number(state[i])`
   syncs plus a host-list rebuild per measurement per shot
   (`lib/qx/simulation.ex:728–790`).
2. **Shot sampling** in `run/2` (no conditionals) does O(2^n + shots·n) work:
   a cumulative sum computed once, one host sync, then a binary search per shot.
   Today it is O(shots × 2^n): a linear `Enum.find_index` per shot (`:639–650`).

## Scope

**In:**
- `lib/qx/calc_fast.ex`: `qubit_probabilities/3` (→ `{p0, p1}` floats, f64
  accumulation, one sync) and `collapse/5` (zero one slice of the qubit axis, scale
  the other; reuses `in_axes`/`halves`). Add `Qx.Calc` delegators if Simulation goes
  through Calc (keep the existing layering).
- New tier-3 `Qx.Simulation.Sampler` (`@moduledoc false`): build a cumulative tuple
  from a probability tensor; `sample/2` binary-searches with **process `:rand`**
  (same draw source as today).
- `lib/qx/simulation.ex`: `perform_single_measurement/4` and `perform_measurements/3`
  call the new code. Delete `calculate_measurement_probability/4`,
  `collapse_to_measurement/4` and the linear `generate_samples/2`.
- `bench/kernels_bench.exs` (or a new `bench/measurement_bench.exs` + alias entry):
  `run/2` with `measure_all`, n = 8, 12, 16, shots = 1024 and 100k; a `c_if` circuit
  at n = 4, 8, 12, shots = 256; `steps/2` with mid-circuit measurement at n = 12, 14.

**Out (scratchpad / ROADMAP):**
- `seed:` option on `run/2` (user decision 2026-11-08: no public API change).
- "Cap retained state in `run_with_conditionals`" (a separate ROADMAP item).
- Re-running the whole circuit per shot in `run_with_conditionals` (same item / a later plan).
- `Qx.ResultBuilder` / `Qx.StateInit` host-list items (a separate ROADMAP item).

## Decisions

- **D1 — host binary search over a cumulative tuple, process `:rand`** (user, 2026-11-08).
  - Nx 0.13 has no searchsorted, and `Nx.Random.choice` is O(shots × 2^n) in memory
    and time (16 s for 20k shots at n=10).
  - `Nx.Random.uniform` alone is 8× slower than the whole host search.
  - The per-shot `classical_bits` output is a shots-long host list regardless.
- **D2 — same draws ⇒ same samples.**
  - Binary search returns the first index `i` with `draw <= cum[i]`, exactly as
    `Enum.find_index` does.
  - The cumulative sum is computed in Nx as **f64** (`Nx.as_type(:f64)` →
    `Nx.cumulative_sum`), so there is no host loop over 2^n (Iron Law #5).
  - Its values may differ from today's host `Enum.scan` by ulps. A difference could
    flip a sample only for a draw within ~1e-16 of a boundary.
  - Verified by a test that compares against a test-local copy of the old linear
    algorithm under a fixed `:rand` seed.
- **D3 — fallback fix (behaviour change, bug).**
  - Today a draw above the f32-derived cumulative total falls back to index **0**,
    which may be a zero-probability outcome.
  - New: fall back to the **last index with p > 0**.
  - Covered by a crafted-distribution test.
  - CHANGELOG "Fixed" entry.
- **D4 — measurement `{p0, p1}` accumulates in f64.**
  - |amp|² is computed as f64 and summed with `Nx.sum(axes: other_axes)` (or slice + sum).
  - The `uniform < p0` decision then matches today's host-f64 sum to ~1e-16, so seeded
    `steps/2` trajectories (tests, manual Livebook `seed: 1`/`seed: 2`) are unchanged.
- **D5 — collapse via static slices, not a host list.**
  - Concatenate `zeros_like(off_slice)` with `on_slice × (1/√p)`.
  - The norm factor is a host scalar from the already-synced `p`, so no extra sync.
  - Output type stays `:c64`.
  - Keep today's `p > 0` guard (`norm_factor = 1.0` otherwise).
- **D6 — no public API change.** All touched modules are tier 3 or private functions
  in `Qx.Simulation`.

## Risks

- **R1 — RNG-sequence drift.** Any extra or missing `:rand` call changes every later
  sample. Keep exactly one `:rand.uniform()` per shot (run path) and one
  `:rand.uniform_s/1` per measurement (steps/c_if path). Tests pin this (P1-T3, P1-T4).
- **R2 — f32 probability near 0 or 1.** If p0 ≈ 1 − 6e-8 and the draw is above it, the
  state collapses onto a near-zero branch and renormalises noise. This is pre-existing;
  record it, don't change it here unless a test shows it occurs.
- **R3 — BinaryBackend Nx overhead at small n** may exceed the host loop at n ≤ 3
  (fixed tensor-op cost). Accept if the absolute cost stays under ~0.1 ms. The bench
  reports it.
- **R4 — Iron Law #8.** New numeric assertions at 1e-6 (c64). The f64 sum is internal
  and not asserted below the floor.

## Phase 0 — Baseline

- [x] [P0-T1] Add measurement scenarios to the bench (see Scope); wire them into `mix bench` — `bench/measurement_bench.exs` (sample n=8/12/16 × 1024/100k, c_if n=4/8/12 × 256, steps n=12/14); added to `@bench_suites`
- [x] [P0-T2] Run on unmodified lib → `research/baseline/measurement.txt` (+ commit hash); commit — commit 2bf4b78; sample n=16×100k 14.1 s, c_if n=12 18.8 s, steps n=14 154 ms (committed 564b3a0)

## Phase 1 — Tests first (must fail before Phase 2)

- [x] [P1-T1] `test/qx/calc_fast_measurement_test.exs`: `qubit_probabilities/3` vs a test-local
      oracle (sum |amp|² over basis indices by bit) for every qubit, n = 1, 3, 5, random states, 1e-6;
      `collapse/5` → the other half is exactly 0, kept amplitudes are scaled by 1/√p, the result is
      normalised, type is c64; invalid qubit → ArgumentError — `test/qx/calc_fast_measurement_test.exs`; also covers value ∉ {0,1} → ArgumentError and exact basis-state {1,0}
- [x] [P1-T2] `test/qx/simulation_sampler_test.exs`: `Sampler.sample/2` equals a test-local copy of
      the old linear `find_index` algorithm on the same `:rand.seed(:exsss, s)` for several random
      distributions (n = 1..8, shots 2000); exactly one `:rand.uniform` per shot (the RNG state after
      matches the reference); D3 fallback never returns a zero-probability index (crafted probs whose
      sum is < 1 + forced high draws) — `test/qx/simulation_sampler_test.exs` (16 distributions, ~1/3 zero outcomes; `export_seed` equality pins 1 draw/shot)
- [x] [P1-T3] Seeded `steps/2` trajectory equals a test-local reference: p0 from the oracle, the
      decision from `:rand.uniform_s` on `:rand.seed_s(:exsss, seed)`, collapse by the oracle. Cover
      teleportation plus a GHZ-n=5 circuit with two mid-circuit measurements, for several seeds — `test/qx/simulation_measurement_test.exs`, seeds 1, 2, 3, 42, 1234
- [x] [P1-T4] `run/2` statistical check (Bell, GHZ-4, and an unequal RY state; 10k shots, counts within
      a 4σ binomial bound; impossible outcomes have count 0) plus a `c_if` teleportation run (Iron Law #9
      execution path) — same file; 4σ binomial; teleportation c_if 2000 shots
- [x] [P1-T5] Static guard: `lib/qx/simulation.ex` code lines contain no `Nx.to_number(state[` and no
      `Enum.find_index(cumulative` — same file; comment lines stripped
- [x] [P1-T6] Run → confirm red for the right reasons (undefined functions + static guard; reference
      and statistical tests are expected GREEN against today's code, which validates the oracles) — red: undefined CalcFast/Sampler functions + static guard; reference/statistical tests green on old code

## Phase 2 — CalcFast measurement kernels

- [x] [P2-T1] `qubit_probabilities/3`: validate the qubit (reuse `validate_qubits!/2`), defnp:
      `abs(state)² → :f64 → reshape {2^q, 2, 2^(n-q-1)} → sum(axes: [0, 2])`, then one
      `Nx.to_flat_list` → `{p0, p1}` — `Nx.abs |> as_type(:f64)`, squared, reshape `{2^q,2,2^(n-q-1)}`, `sum(axes: [0,2])`; spike showed the reduction form does not matter (the |amp|² pass dominates)
- [x] [P2-T2] `collapse/5` (state, qubit, value, norm_factor, num_qubits): defnp on the
      `in_axes`/`halves` primitive; keeps c64 — rescales the kept half in c128 → c64; exact zeros via broadcast; norm factor passed as an f64 tensor (no EXLA recompiles)
- [x] [P2-T3] `Qx.Calc` delegators; P1-T1 green; existing CalcFast tests untouched and green — `Qx.Calc.qubit_probabilities/3`, `Qx.Calc.collapse/5`; 80 CalcFast/Calc tests green

## Phase 3 — Sampler + Simulation routing

- [x] [P3-T1] `Qx.Simulation.Sampler` (`lib/qx/simulation/sampler.ex`, `@moduledoc false`):
      `cumulative(probabilities_tensor)` → tuple via Nx f64 `cumulative_sum` + one sync;
      `sample(cumulative, shots)` → binary search with the D3 fallback — `lib/qx/simulation/sampler.ex`; D3 as `min(draw, total)` clamp (the first index reaching the total has p > 0)
- [x] [P3-T2] `perform_measurements/3` → Sampler; delete `generate_samples/2` — `perform_measurements/3` now takes the probability tensor (no double `Math.probabilities`)
- [x] [P3-T3] `perform_single_measurement/4` → `Calc.qubit_probabilities` + `Calc.collapse`; delete
      `calculate_measurement_probability/4` and `collapse_to_measurement/4` — p0/p1 from one sync; norm guard kept
- [x] [P3-T4] Full `mix test` green (existing tests UNMODIFIED); compile/format/credo; `mix docs`
      warnings ≤ baseline — 1479 passed (328 doctests); credo clean; `mix docs` warning list identical (12 lines, no diff)

## Phase 4 — Measure & document

- [x] [P4-T1] Re-run the measurement bench (+ the ghz/kernels suites to catch regressions) →
      `research/after/`; write `research/bench-comparison.md` — `research/after/{measurement,ghz,kernels}.txt` + isolated single-measurement timing; `research/bench-comparison.md`
- [x] [P4-T2] CHANGELOG `[Unreleased]`: Performance entry + "Fixed" entry for D3
- [x] [P4-T3] ROADMAP: tick both v0.12 items (plan: vectorise-measurement)
- [x] [P4-T4] `/phx:review` (merge gate — stop for human authorization) — REQUIRES CHANGES → W1 (`:shots` validation) + W3 (seed/5σ) fixed → PASS; awaiting human merge authorization

## Verification

`mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test`
after each phase; `mix bench` (measurement suite) after Phases 2 and 3.
