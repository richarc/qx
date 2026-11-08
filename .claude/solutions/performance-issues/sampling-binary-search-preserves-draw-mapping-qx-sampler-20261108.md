---
module: "Qx.Simulation.Sampler / Qx.CalcFast"
date: "2026-11-08"
problem_type: performance_issue
component: nx_defn_kernel
symptoms:
  - "Qx.run/2 with measure_all at n=16 and 100k shots took 14.1 s: a linear Enum.find_index over a 2^n cumulative list for every shot (O(shots × 2^n))"
  - "Every mid-circuit measurement (c_if in run/2, every steps/2 measure) made ~3·2^n Nx.to_number(state[i]) host syncs and rebuilt the state from a host list"
  - "Draws above the f32 cumulative total fell back to outcome 0, which could have probability 0"
root_cause: "sampling searched the cumulative distribution linearly once per shot, and measurement read amplitudes one at a time to the host; Nx 0.13 has no searchsorted/categorical sampler, and Nx.Random.choice builds a {shots, 2^n} matrix (16 s at 20k × 1024), so the vectorised-looking option is worse"
severity: high
tags: [nx, sampling, binary-search, cumulative-sum, rand, reproducibility, measurement, collapse, slice_along_axis, iron-law-5, binary-backend]
related_solutions:
  - ".claude/solutions/performance-issues/dense-contraction-slower-than-axis-slicing-qx-calcfast-20261106.md"
  - ".claude/solutions/architecture-issues/seeded-lazy-stream-explicit-rand-threading-qx-simulation-20260703.md"
---

# Shot sampling by binary search over an Nx cumulative sum, with the draw→outcome mapping unchanged

## Solution

**Sampling** (`lib/qx/simulation/sampler.ex`):

1. Compute `Nx.as_type(:f64) |> Nx.cumulative_sum` once in a `defnp`.
2. Sync it to the host once (`to_flat_list |> List.to_tuple`).
3. For each shot, make one `:rand.uniform/0` draw and binary-search for the
   **first `i` with `draw <= cum[i]`**, which is exactly `Enum.find_index`'s
   predicate. The same draws therefore give the same samples.
4. Clamp with `draw = min(draw, total)`. The first index that reaches the total
   always has p > 0, so the old index-0 fallback is gone. This needs no host
   loop and no extra sync.

Results:

| Scenario | Before | After |
|---|---:|---:|
| n=16, 100k shots | 14.1 s | 1.2 s |
| n=12, 100k shots | 0.94 s | 0.14 s |

**Measurement** (`Qx.CalcFast.qubit_probabilities/3`, `collapse/5`):

- `{p0, p1}`:
  1. `abs → f64 → square`.
  2. Reshape to `{2^q, 2, 2^(n-q-1)}`.
  3. `sum(axes: [0, 2])`, then one sync.
- Collapse:
  1. Reshape to rank n.
  2. Split the qubit axis into its two halves.
  3. Rescale the kept half in c128 and cast back to c64.
  4. Concatenate with an `Nx.broadcast` of zeros.

## Rejected alternatives (measured)

- **Scaling the draw by `cum[-1]` and searching `cum > r`.** It changes which
  outcome a given draw maps to, so seeded results change.
- **`Nx.Random.choice`.** It is O(shots × 2^n) in memory and time.
- **`Nx.Random.uniform` for the draws.** It is 8× slower than the whole host
  search.
- **A different reduction for `{p0, p1}`** (slice + sum, total − half, two-step
  sum). All cost the same, about 30 ms at n=16: the |amp|² pass dominates, not
  the reduction.
- **A host `Enum.scan` for the cumulative sum** would be 10× faster than
  `Nx.cumulative_sum` on BinaryBackend (4 ms vs 39 ms at n=16). It was kept in
  Nx per Iron Law #5 because it runs once per run.

## Prevention / reuse

- When vectorising a randomized algorithm, pin **"same draws ⇒ same output"**
  with a test-local copy of the old algorithm under `:rand.seed`. Also assert
  `:rand.export_seed()` equality, which pins exactly one draw per shot.
- **Speed-ups from removing host syncs are modest on BinaryBackend.** There
  `Nx.to_number` is cheap: one measurement got only 2.2–2.4× faster at n=12–14.
  The large win is on device backends, where each sync is a transfer. Report
  that honestly rather than projecting audit estimates.
- **Benchmark the whole path, not only the part you changed.** After this fix,
  1024-shot runs are dominated by gate execution and `c_if` runs by re-running
  the circuit per shot.
