# Research: vectorised sampling and measurement (Nx 0.13.0, BinaryBackend)

No new dependency is justified.

## 1. Nx-native sampling
- Nx 0.13 has no searchsorted, bincount or categorical sampler. `grep` over deps/nx/lib finds only a comment, "naive implementation of jax.numpy.searchsorted", at random.ex:1008.
- `Nx.Random.choice/4` (random.ex:985) with `replace: true` builds the `{shots, 2^n}` boolean matrix `p_cumulative <= r` (random.ex:1009-1012) and then runs `argmin` over it.
- Cost is O(shots·2^n) in time and memory.
- Measured here: shots=20_000, 2^n=1024 took **16.1 s**. Extrapolating to 100_000 gives about 80 s, plus a transient of roughly 100M elements (a few hundred MB). Reject it.
- Sort-based alternatives are no better:
  - Sorting the uniforms and merging against the cumulative sum needs a scan with data-dependent control flow, which Nx cannot express without while loops.
  - Both `Nx.argsort` and `Nx.cumulative_sum` are fine at O(n log n) on their own, but the merge step has no primitive.
  - The only remaining option is `Nx.indexed_add` over indices you already have, and getting those indices is the search problem again.
- `Nx.indexed_add` (nx.ex:8165) works for counting once indices exist. On the host, `Enum.frequencies` is simpler.

## 2. Host binary search (recommended)
- Build the cumulative sum once: one `Nx.to_flat_list` call, then `Enum.scan(&+/2)`, then `List.to_tuple`. This is O(2^n).
- Per shot, run a hand-written `elem/2` binary search for the first index with `cum[i] > r`. This is O(log 2^n).
- Measured: **100_000 shots over 1024 outcomes took 42 ms**, using `:rand.uniform()` on the process state. It keeps the existing seeding and determinism.
- Neither stdlib nor Erlang has a bisect helper. `:gb_trees` and `:array` would work but are slower than a tuple.
- Precision:
  - Probabilities are c64 to f32, so the cumulative sum can end at 0.99999 or 1.00001.
  - Scale the draw: `r = :rand.uniform() * elem(cum, last)`.
  - Clamp the search to `last`, and use "first `cum[i] > r`" so zero-probability outcomes are never selected.
  - Replace the index-0 fallback with the last index that has p > 0.
  - Better still, accumulate in f64 on the host from `Nx.to_flat_list`. The list gives Elixir floats, so the scan is already f64.
  - Consider normalising by the sum first.

## 3. Per-qubit p0/p1 and collapse
- Reshape the state to `{2,...,2}` (rank n), take `Nx.abs`, then square it (or `re² + im²`), reshape to `{pre, 2, post}` and call `Nx.sum(axes: [0, 2])`. This gives a `{2}` tensor, and one `Nx.to_flat_list` call gives `[p0, p1]` with a single sync.
- Measured `Nx.sum(axes: other)` on a 10-qubit rank-10 tensor: about 0.1 ms. The result `[130816.0, 392960.0]` is correct for the iota input.
- Two `slice_along_axis` + `sum` calls give the same numbers but cost two reductions and two syncs. Prefer the single sum.
- Collapse without gather or select:
  - Build the mask as a `{2}` tensor, `Nx.tensor([1,0])` or `[0,1]` scaled by `1/sqrt(p_outcome)`.
  - Reshape it to `{1,2,1}` and multiply with the `{pre,2,post}` state. Broadcasting does the zeroing and the renormalisation in one op.
  - The mask must be c64, or the multiply promotes through `Nx.as_type`. The mask is tiny, so there is no extra cost.

## 4. Nx.Random cost
- `Nx.Random.uniform(key, shape: {100_000})` on BinaryBackend took **0.35 s**. It uses threefry via defn, which `Nx.Defn.Evaluator` interprets.
- That is about 8x slower than the 42 ms binary search over the same 100k draws, which includes the `:rand` draws themselves.
- A key-based generator would give reproducibility independent of the process. It is not needed here, so stay with `:rand`.

## Recommendation
1. Sampling: host cumulative tuple plus binary search with `:rand`.
2. Measurement: rank-n reshape, `Nx.sum(axes:)`, one `Nx.to_flat_list` call, then a broadcast mask multiply for collapse.
