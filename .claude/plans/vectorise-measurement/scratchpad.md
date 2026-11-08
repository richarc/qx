# Scratchpad: vectorise-measurement

## Decisions

- **2026-11-08, user:** host binary search with process `:rand` (not Nx.Random).
  Scope is only the two ROADMAP items: no `seed:` on `run/2`, and no
  `run_with_conditionals` cap.
- **Research** (research/hex-library-researcher-report.md, BinaryBackend):
  - `Nx.Random.choice` builds a `{shots, 2^n}` bool matrix plus argmin: 16.1 s at
    20k shots × 1024 outcomes. Rejected.
  - No searchsorted, bincount, or categorical sampler in Nx 0.13.
  - Host tuple binary search: 42 ms for 100k shots × 1024.
  - `Nx.Random.uniform` for 100k draws: 0.35 s.
  - Per-qubit {p0, p1} via reshape {pre, 2, post} + sum(axes: [0, 2]): ~0.1 ms at n=10.
- **Researcher suggested** scaling the draw by cum[-1] and searching for the first
  `cum > r`. **Not adopted:** it changes which sample a given draw maps to, which
  breaks D2 (same draws ⇒ same samples). The D3 fallback fixes only the overflow case.

## Current code facts (2026-11-08, main @ cfee33e)

- `generate_samples/2` (simulation.ex:639): `Enum.scan` over
  `Nx.to_flat_list(probs)`, then `:rand.uniform()` (process dict) and a linear
  `find_index` per shot, with fallback `|| 0`.
- `perform_single_measurement/4` (:728):
  - `calculate_measurement_probability` loops 2^n with `Nx.to_number(state[i])`.
  - `collapse_to_measurement` calls it AGAIN (another 2^n syncs), then rebuilds
    the state from a host list. That is ~3·2^n syncs per measurement.
  - Draw: `:rand.uniform_s(rand)`; outcome 0 iff `uniform < p0`.
- `run_with_conditionals` uses `seed_rand(nil)` per shot (fresh entropy).
- `steps/2` threads `seed:` through `seed_rand/1`.
- No test calls `:rand.seed` before `run/2`, so counts are only checked
  statistically. The manual Livebook pins exact `steps(seed: 1 | 2)` trajectories.

## Out of scope / discovered

- R2 (pre-existing): an f32 p0 just below 1 combined with a draw above it collapses
  onto a ~1e-8 branch and renormalises noise. Leave as is unless a test hits it.
- `run_with_conditionals` re-runs the whole circuit per shot (separate ROADMAP item).

## Dead-ends

(none yet)

## Implementation notes (2026-11-08, /phx:work)

- **Spike, BinaryBackend:** `Nx.cumulative_sum` (f64) costs 1.9 / 2.8 / 39 ms at
  n = 8 / 12 / 16, against 0.01 / 0.2 / 4 ms for a host `Enum.scan` over the
  flat list. Kept Nx per D2 / Iron Law #5. It runs once per `run/2`, so it is
  small next to sampling. Possible follow-up if n=16 sampling at low shot
  counts matters.
- **Spike:** the cost of the per-qubit `{p0, p1}` reduction is the |amp|² pass,
  not the sum. `sum(axes: [0, 2])`, slice + sum, and total − one-half all took
  about 30 ms at n=16 and 5 ms at n=14 regardless of the qubit. Kept
  `sum(axes: [0, 2])`.
- **D3 implemented as a clamp:** `draw = min(draw, total)`. The first index
  with `cum >= total` always has p > 0, with no host loop to find "the last
  p > 0" and no extra sync. Edge case (pre-existing, measure ~2^-53): a draw
  of exactly 0.0 with p[0] = 0 still returns index 0, as before.
- **Collapse** rescales the kept half in c128 and casts back to c64 (one
  rounding, the same as the old host f64 multiply followed by `Nx.tensor(:c64)`).
- `perform_measurements/3` now takes the already-computed probability tensor,
  so `Math.probabilities/1` is no longer computed twice per `run/2`.
- **Discovered:** the `.claude/settings.local.json` test-file-guard hook points
  at `/Users/richarc/Development/qx/.claude/hooks/test-file-guard.sh`, a path
  from before the workspace move that no longer exists. The guard is therefore
  inactive; the script now lives at `.claude/hooks/test-file-guard.sh`. Only new
  test files were written this session (no existing test changed).
- **Review follow-up (pre-existing, not fixed here):** W7 / R2. If
  `uniform >= p0` while `p1 == 0`, the state collapses to all zeros
  (`simulation.ex` `perform_single_measurement`). A candidate one-line fix is
  `uniform < p0 or p1 <= 0`. It changes RNG→outcome only in that degenerate
  case. Do it as a separate fix/ branch.
- `run_with_conditionals` has the same `1..shots` descending-range hazard; it
  is now covered by `validate_shots!` in `run/2`.
