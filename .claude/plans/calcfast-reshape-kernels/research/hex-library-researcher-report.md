# Nx 0.13 reshape+dot kernels: research

Verdict: no new Hex dependency. Nx 0.13.0 (lock) and optional EXLA cover everything.
Caveat: deps/nx/CHANGELOG.md and its mix.exs still say 0.12.1, though mix loads "nx 0.13.0". Run `mix deps.get` if the on-disk docs matter.

## 1. Static options in defn
- Docs (Nx.Defn "Default arguments"): lists/keyword lists are passed as-is (not converted to tensors) and cached as a whole. Numbers passed positionally become tensors, so they are NOT static.
- Idiom: `defn f(state, gate, opts \\ [])` with `opts = keyword!(opts, [:qubits, :n])`, then `opts[:n]` (Access works in defn).
- Inside defn you cannot call Kernel/Enum/List (e.g. `hd/1` raised "undefined function hd/1" in my test). Build shapes/permutations in `deftransform`/`deftransformp` (plain Elixir, evaluated at trace time) and call them from defn.
- Passing ints and lists positionally to a `defnp` called from a `deftransform` works. The deftransform computes the statics, and the defnp receives them as plain integers/lists, usable in `Nx.reshape`/`Nx.transpose`.
- 0.13 does not change any of this. `keyword!/2` is not deprecated. Never put tensors in opts.
- Existing qx code passes target_qubit/num_qubits positionally into defn. That makes them tensors, so it cannot drive shapes. They must move to opts or a deftransform wrapper.

## 2. Nx.dot semantics
- `dot(t1, c1, t2, c2)` is `dot/6` with empty batch axes. The contracted axes are removed.
- Output axis order: t1's remaining axes (in order), then t2's remaining axes (in order). With batch axes, they come first (must be leading axes 0..b-1 of both inputs).
- For a gate reshaped to {2,..,2} (2k axes) contracted as `Nx.dot(g, [k..2k-1], s, targets)`:
  - Output = [gate out axes (k)] ++ [state's non-target axes, original order].
  - Inverse transpose: output position of state axis a is k + rank_among_non_targets(a) if a is not a target, else the index j of the target in the list order. Pass that as `Nx.transpose(r, axes: perm)`, where perm[a] is the output axis to place at position a.
  - Targets order matters (the gate's j-th input axis pairs with targets[j]).
- Verified (k=1): `Nx.dot(g, [1], s, [q])`, then perm = (1..q) ++ [0] ++ (q+1..n-1), then reshape {2^n}. X on qubit 2 of |000> gave index 1 (axis 0 = most significant qubit).

## 3. c64 on BinaryBackend
- Works (tested, Evaluator, default backend {Nx.BinaryBackend, []}).
- Timing: single-qubit c64 dot on a 2^10 state took about 1 ms, and on 2^14 about 21 ms. BinaryBackend dot is a generic pure-Elixir loop, with no BLAS or vectorization.
- Expect roughly linear in 2^n * 2^k per gate. Larger k gets slower (k=3 means 8x the multiplies per amplitude).
- Transpose and reshape also run in Elixir on binaries (the transpose copies the full state). EXLA is the performance path.

## 4. Caching
- Evaluator: no compile cache. It re-walks the expression on every call, so static opts only cost retrace time, with no bound concern.
- EXLA.jit / Nx.Defn.jit: the cache key includes shapes/types/names plus the whole opts list and any funs. Each distinct (qubits, n) combination compiles a new executable.
- Bound: the count is roughly sum over gates of n^k combos per n, which is fine for n <= ~20 but grows quickly for large circuits.
- I found no documented LRU or size cap. Treat the EXLA cache as unbounded and keep opts coarse.
- Mitigation: a gate-matrix arg is a tensor, so gate values do NOT multiply compiles. Only qubit positions and n do.
- Nx 0.12 added a warning for closure-captured tensors causing recompilation storms. Don't capture tensors.

## 5. Changelog (0.13.0)
Nothing touches transpose/reshape/dot/put_slice/complex.
- Adds `Nx.pad_outer/3`.
- Simplifies hooks, deprecating token hooks.
- Deprecates `Nx.reflect/2`.
- Bug fixes: clip grad, vectorized grad, LinAlg batched grads, Defn.Graph.
- Low risk for this rewrite. Note that qx previously went 0.12.1 to 0.13.0 with no relevant API change.
