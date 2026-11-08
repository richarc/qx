# Code Review: feat/vectorise-measurement

Note: no Bash available, so I read the files directly instead of running `git diff`. Nothing was compiled or run.

## Summary
- Status: Approved with warnings
- No BLOCKERs. The Nx slicing kernels, f64 accumulation, tuple search and clamp logic look correct.

## WARNING

1. lib/qx/simulation/sampler.ex:38-40 — `Sampler.sample/2` guards `is_integer(shots) and shots > 0`. `Simulation.run/2` (simulation.ex:108) and `Qx.run` never validate `:shots`.
   `Qx.run(qc, shots: 0)`, a negative value or a non-integer on a circuit with measurements now raises a raw `FunctionClauseError` from an internal `@moduledoc false` module. This is a typed-error gap at the public boundary (Iron Law #7).
   The old `for _ <- 1..shots` silently iterated a descending range for 0 or a negative value, so the failure is new, though arguably better than the silent bug.
   Fix: validate `:shots` in `Validation` (`validate_shots!`) at the boundary, or raise a typed error. A circuit without measurements returns early and never hits the guard.

2. lib/qx/calc_fast.ex:216-224, 237 (ArgumentError leak) — `qubit_probabilities/3` and `collapse/5` raise `ArgumentError` for an out-of-range qubit, and `Nx.reshape` raises one for a state/num_qubits length mismatch.
   `Simulation` passes `circuit.num_qubits` and builder-validated qubits, so I found no reachable leak through `Qx.run` or `Qx.steps`.
   I did not verify that `Qx.Circuit.measure` rejects an out-of-range qubit. If a circuit can be built with such a measurement, the error is now `ArgumentError` where the old host loop may have behaved differently. Please confirm with a test.

## SUGGESTION

1. lib/qx/simulation/sampler.ex:45 — `:rand.uniform/0` returns `[0.0, 1.0)`, so `draw == 0.0` is possible (about 2^-53).
   `first_reaching` then returns index 0 even when `p[0] == 0`, because `cumulative[0] == 0.0 >= 0.0`. This matches the old `find_index` behaviour, so it is parity-preserving and negligible.
   If you want "never a zero-probability outcome" to hold strictly (the moduledoc claims it for the clamp case only), use `draw < cumulative[i]` with the clamp adjusted. I would leave it and note the edge case in the comment.

2. lib/qx/simulation/sampler.ex:27-31 — if probabilities contain NaN, `to_flat_list` yields `:nan` atoms.
   `min(draw, :nan)` and `draw <= :nan` follow Erlang term order, so there is no crash but the results are silent garbage. All-zero probabilities (total 0.0) map every draw to index 0, which is benign.
   Upstream state corruption is the real problem, so this is low priority.

3. lib/qx/simulation/sampler.ex:50 — `defnp` for a two-op f64 cumsum is fine. The 10x slowdown versus a host scan at n=16 is documented in your notes. The decision to follow Iron Law #5 is consistent.

4. lib/qx/calc_fast.ex:240 — `Nx.tensor(norm_factor, type: :f64)` is built per measurement outside defn. This is fine (not a host loop). Passing it as a defn arg avoids recompiling per value. A guard such as `is_number(norm_factor)` would give a cleaner error than an `Nx.tensor` failure.

5. lib/qx/calc_fast.ex:315-330 — `Nx.type(state)` inside a `deftransformp` is fine at trace time. If `state` were `:c128`, the downcast is a no-op, which is correct. The zero-fill plus concatenate pattern is Iron Law #3 compliant (static slicing).

6. lib/qx/simulation.ex:722-726 — if `uniform >= prob_0` but `prob_1 == 0` (f32 rounding makes p0 + p1 slightly below 1), the code picks outcome 1 with `norm_factor = 1.0` and collapses to an all-zero state.
   This logic looks pre-existing, so it is not new. A one-line fix is `if uniform < prob_0 or prob_1 <= 0`. Please confirm whether the old code had the same flaw.

## Verified OK
- n=1: a cumulative tuple of size 2 works. `first_reaching(_, _, i, i)` terminates, with `last = 1`.
- A boundary draw of `draw == cumulative[mid]` goes left (`<=`), which matches the first-index semantics of `find_index`.
- Monotonicity holds: an f64 cumsum of non-negative values is non-decreasing, so the binary search precondition is satisfied.
- Clamp: `min(draw, total)` guarantees a hit at `hi`.
- `extract_classical_bits` is unchanged in semantics.
