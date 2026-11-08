# Test Review: vectorise-measurement (3 new test files)

Static review only. I had no Bash tool, so I did not run the tests or probe several `--seed` values.

## Summary
The tests are well structured and mostly deterministic. All three files are `async: true`, tolerances are 1.0e-6, and the process `:rand` is seeded only inside test processes. The risk is concentrated in the unseeded statistical tests in `simulation_measurement_test.exs`.

## BLOCKER
None.

## WARNING
- [ ] `simulation_measurement_test.exs` lines 128-177: the `run/2` tests are unseeded and make 7 independent 4σ assertions: 3 on the sampling path and 4 prefixes on the teleportation path. Two-sided 4σ is about 6.3e-5 per assertion, so about 4e-4 per full run (roughly 1 in 2,500 CI runs).
  - Sampling path: seed the process `:rand` (`:rand.seed(:exsss, n)`) at the top of each test. `Sampler` uses the process `:rand`, so those three tests become deterministic.
  - Per-shot `c_if` path: this cannot be seeded from the test, because `run` calls `seed_rand(nil)` per shot. Either widen to 5σ (the normal approximation is poor at p=0.25, n=2000 in the tails anyway) or accept the roughly 2e-4 residual and document it.
  - The 4 teleportation prefixes are mutually dependent, so the effective false-failure rate is slightly lower than the sum.
- [ ] `simulation_measurement_test.exs` lines 60-75, trajectory reference: it is only partly independent.
  - The decision `uniform < p0` compares an f64 host p0 (summed from f32 amplitudes) against the implementation's value (probably an Nx f32 reduction).
  - If a seeded uniform lands within about 1e-7 of p0, the outcome flips. This is deterministic per seed, so it cannot flake. It could still break if the kernels change. Currently seeds 1, 2, 3, 42 and 1234 are fixed, so this is acceptable.
  - The weakness is that `pre` is taken from the implementation's previous step, so errors in gate application are invisible here. That is acceptable because other suites cover gates, but the header comment should say so.
  - The `%Step{state: state}` fallthrough clause silently accepts any other step shape (for example, a changed `:measurement` operation tuple). The final `== 3` and `== 2` count assertions do catch this.
- [ ] Teleportation seeds (lines 110-119): qubit 2 is measured last and its outcome is deterministic (p0 = 0 or 1). That one measurement therefore does not exercise the `uniform < p0` branch.

## Sampler equality and the ulp question (sampler test, lines 48-67)
- Equality will not spuriously fail from ulp differences.
  - `Nx.to_flat_list` on f32 yields exact f64 values.
  - On `Nx.BinaryBackend` (the test config) `cumulative_sum` is a sequential f64 add, identical to `Enum.scan` (addition is commutative, so `elem + acc` vs `acc + elem` gives the same result).
  - Even if the sums differed by 1 ulp, a mismatch requires a draw within about 1e-16 of a boundary, which is a probability of about 1e-12.
  - Under EXLA the scan order could differ, but the test config pins `BinaryBackend`.
- The real divergence risk is the D3 fallback: `reference_samples` falls back to index 0 above the total, while the sampler clamps.
  - Normalised f32 sums can be below 1 by about 6e-8, so over 16 tests x 2000 draws roughly 1e-3 of the seeds could hit it.
  - This is deterministic per seed, since the seeds are fixed, so it cannot flake. If a future seed or `shots` change hits it, the failure will look like a bug. Add a comment, or skip draws above the total in the equality test.
- The RNG pin (`:rand.export_seed()` equality) is sound.
  - exsss state advances by exactly one step per `:rand.uniform/0`.
  - `Nx` does not touch the process RNG.
  - `min/2` consumes no draw.
  - It does couple the test to "one uniform/0 per shot", which is the intent.

## SUGGESTION
- [ ] Missing edge cases for `Sampler`: `shots: 1`, and the guard clause (`shots: 0` and the empty tuple raise `FunctionClauseError`). Add `assert_raise FunctionClauseError`.
- [ ] Missing edge cases for the kernels:
  - A `collapse` zero-probability branch (norm_factor 1.0 as in the oracle).
  - `qubit_probabilities` on a non-normalised state.
  - A `:c64` state with `num_qubits` mismatched to the tensor size.
  - The `collapse` raises tests only check `ArgumentError`. Add a message regex per the `assert_raise` convention.
- [ ] `calc_fast_measurement_test.exs` line 63: `== {0.0, 1.0}` is an exact float comparison. It is OK for basis states, but use `assert_in_delta` if the kernel ever uses a different reduction.
- [ ] Line 110 of the collapse test: `assert after_amp == Complex.new(0.0, 0.0)` can fail on `-0.0` vs `0.0` if a kernel changes to a multiply-by-mask. Compare with `Complex.abs(after_amp) == 0.0`.
- [ ] `simulation_measurement_test.exs` line 183: the static guard uses the relative path `lib/qx/simulation.ex`, which depends on the cwd. Use `Path.expand("../../lib/qx/simulation.ex", __DIR__)`. The guard is a brittle string-match regression net, but it is acceptable for a plan requirement.
- [ ] `@shots 10_000` is declared inside a `describe` but is a module attribute, so it is global. It is harmless, but rename it or move it to the top.
- [ ] Sampler distribution test (lines 99-102): `old_index == 0` also holds for a legitimate draw 0.0 (probability 2^-53). Ignore it.
- [ ] Generated tests via `for` + `@attr` are idiomatic. The test names include the parameters, which is good.
- [ ] No pre-existing issues were noted in these files.
