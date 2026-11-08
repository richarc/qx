# Consolidated Summary

**Strategy**: Index (total input under 8k tokens; structured by priority)
**Input**: 4 files (elixir.md, testing.md, iron-laws.md, requirements.md), ~3k tokens. `.requirements-input.md` ignored as instructed.
**Output**: ~1.5k tokens (~50% reduction)

Verified in-session (orchestrator): `mix test` 1479 passing, credo clean, `mix docs` warnings unchanged. This resolves the 2 UNCLEAR items in requirements.md (P1-T6, P3-T4).

Deconfliction applied: iron-law-judge (iron-laws.md) finding kept over elixir-reviewer where both flag the same code (calc_fast.ex ArgumentError path). Elixir's WARNING #2 is superseded by iron-law's #7 finding.

## BLOCKERs

None (elixir.md, testing.md, iron-laws.md all report 0 blockers).

## WARNINGs

**W1. Shots not validated at the public boundary (Iron Law #7 boundary)** [elixir.md WARNING 1; orchestrator-verified]
- `lib/qx/simulation/sampler.ex:38-40` guards `is_integer(shots) and shots > 0`. `Simulation.run/2` (`lib/qx/simulation.ex:108`) and `Qx.run` never validate `:shots`.
- Behaviour: `Qx.run(qc, shots: 0)` returns 2 samples and `shots: -1` returns 3 on main (silent wrong answers from the descending range `for _ <- 1..shots`). On this branch both raise a raw `FunctionClauseError` from the `@moduledoc false` Sampler.
- Pre-existing: missing validation predates this diff. This diff changes how it fails (silent wrong answer becomes raw internal crash).
- Fix: validate `:shots` in `Validation` (e.g. `validate_shots!`) and raise a typed error at the boundary. Add a test for `shots: 0`, `-1`, and non-integer.

**W2. Out-of-range qubit / length mismatch may leak ArgumentError** [elixir.md WARNING 2, superseded by iron-laws.md #7; LOW/REVIEW]
- `lib/qx/calc_fast.ex:216-224, 237, 248, 394-418`: `qubit_probabilities/3`, `collapse/5`, `validate_qubits!`, `validate_2x2!` raise `ArgumentError`. `Nx.reshape` raises on state/num_qubits length mismatch.
- Iron-law judge: not reachable through `Qx.run`/`Qx.steps`, because `Simulation` passes `circuit.num_qubits` and builder-validated qubits (`simulation.ex:718, 726`). Typed `Qx.QubitIndexError` runs first. These are tier-3 defence-in-depth.
- Open item: `Operations.measure` and `c_if` range validation was not traced. Add a `run/2` test on a hand-built `%QuantumCircuit{}` with an out-of-range measurement. If an ArgumentError escapes, that path is pre-existing.

**W3. Unseeded statistical tests can flake** [testing.md WARNING 1]
- `test/.../simulation_measurement_test.exs:128-177`: `run/2` tests make 7 independent 4-sigma assertions (3 sampling, 4 teleportation prefixes). Two-sided 4-sigma is about 6.3e-5 each, roughly 4e-4 per run (about 1 in 2,500 CI runs). The 4 prefixes are dependent, so the true rate is slightly lower.
- Sampling path: seed process `:rand` (`:rand.seed(:exsss, n)`) at the top of each test. Sampler uses process `:rand`, so these become deterministic.
- Per-shot `c_if` path cannot be seeded from the test, because `run` calls `seed_rand(nil)` per shot. Either widen to 5-sigma or accept a residual of about 2e-4 and document it.

**W4. Trajectory reference only partly independent** [testing.md WARNING 2]
- `simulation_measurement_test.exs:60-75`: decision `uniform < p0` compares f64 host p0 (summed from f32 amplitudes) with the implementation's value. A seeded uniform within about 1e-7 of p0 would flip the outcome. Deterministic per seed, so no flake, but fragile to kernel changes. Seeds 1, 2, 3, 42, 1234 are fixed.
- `pre` is taken from the implementation's previous step, so gate-application errors are invisible here (covered by other suites). Header comment should say so.
- The `%Step{state: state}` fallthrough silently accepts other step shapes. The final `== 3` and `== 2` count assertions catch this.

**W5. Teleportation qubit 2 does not exercise the probabilistic branch** [testing.md WARNING 3]
- `simulation_measurement_test.exs:110-119`: qubit 2 is measured last with deterministic p0 (0 or 1), so `uniform < p0` is not exercised for it.

**W6. Equality test can diverge from the D3 fallback** [testing.md, sampler equality section; requirements.md D3]
- `simulation_sampler_test.exs:48-67`: `reference_samples` falls back to index 0 above the total, while the sampler clamps (`sampler.ex:44`). Normalised f32 sums can sit about 6e-8 below 1, so roughly 1e-3 of seeds across 16 tests x 2000 draws may hit it.
- Deterministic (fixed seeds), so no flake. A future seed or `shots` change would look like a bug. Add a comment, or skip draws above the total in the equality test.

**W7. Collapse to all-zero state when `p1 == 0`** [elixir.md SUGGESTION 6; orchestrator: PRE-EXISTING]
- `lib/qx/simulation.ex:722-726`: if `uniform >= prob_0` and `prob_1 == 0` (f32 rounding), outcome 1 is chosen with `norm_factor = 1.0` and the state collapses to all-zero. Same logic in the old code, recorded as plan risk R2.
- Pre-existing, not introduced by this diff. Possible one-line fix: `if uniform < prob_0 or prob_1 <= 0`. Track separately.

## SUGGESTIONs (grouped)

**S-A. Edge-case tests missing**
- Sampler: `shots: 1`; `assert_raise FunctionClauseError` for `shots: 0` and empty tuple (`simulation_sampler_test.exs`). Ties to W1.
- Kernels: `collapse` zero-probability branch; `qubit_probabilities` on non-normalised state; `:c64` state with mismatched `num_qubits`.
- `collapse` raises tests check only `ArgumentError`. Add message regexes.

**S-B. Float-equality brittleness**
- `calc_fast_measurement_test.exs:63`: `== {0.0, 1.0}` exact comparison. OK for basis states; use `assert_in_delta` if the reduction changes.
- Collapse test line 110: `after_amp == Complex.new(0.0, 0.0)` can fail on `-0.0`. Use `Complex.abs(after_amp) == 0.0`.

**S-C. Sampler zero-draw and NaN edge cases (low priority, benign)**
- `sampler.ex:45`: `:rand.uniform/0` can return `0.0` (about 2^-53). Index 0 is returned even if `p[0] == 0`. Matches old `find_index` behaviour. Leave it and document in the comment. Testing's distribution test (lines 99-102) and requirements D3 residual say the same. Ignore.
- `sampler.ex:27-31`: NaN probabilities yield `:nan` atoms and silent garbage (no crash). Upstream corruption is the real issue.

**S-D. Test hygiene and portability**
- `simulation_measurement_test.exs:183`: static guard uses relative `lib/qx/simulation.ex`. Use `Path.expand("../../lib/qx/simulation.ex", __DIR__)`.
- `@shots 10_000` declared inside `describe` is module-global. Rename or move to top.

**S-E. Code clarity (non-blocking)**
- `calc_fast.ex:240`: `Nx.tensor(norm_factor, type: :f64)` built per measurement outside defn. Fine. Add `is_number(norm_factor)` guard for a cleaner error.
- `calc_fast.ex:315-330`: zero-fill plus concatenate is Iron Law #3 compliant.

**S-F. Scale note (INFO)**
- `Sampler.cumulative/1` (`sampler.ex:27-32`): the 2^n host tuple is memory-bound at large n. Iron Law #5 is satisfied (Nx cumsum plus one sync). Revisit with an on-device searchsorted only if large n is exposed.

## Positive / Verified OK (1-2 lines)
- Nx slicing kernels, f64 accumulation, tuple binary search, and clamp logic are correct. n=1 terminates. Monotone cumsum satisfies the search precondition. `extract_classical_bits` semantics unchanged.
- Iron-law judge: 0 critical / 0 high / 0 medium. #1, #2, #3, #4, #6, #8, #9 pass. No `String.to_atom`, no new processes, no gather ops, no public API change, CHANGELOG and version appropriate.
- Requirements: 29 MET, 0 PARTIAL, 0 UNMET. 2 UNCLEAR resolved by orchestrator. P4-T4 (`/phx:review`) open as expected.

## Coverage

| File | Represented | Key Items |
|---|---|---|
| elixir.md | Yes | 2 WARNING (1 kept as W1, 1 superseded by W2), 6 SUGGESTION (grouped S-B to S-F, W7) |
| testing.md | Yes | 3 WARNING (W3, W4, W5), W6, S-A, S-B, S-D |
| iron-laws.md | Yes | 0 violations; 3 advisory (W2, S-F, verified list) |
| requirements.md | Yes | 29 MET, 2 UNCLEAR resolved, 1 open |

## Coverage Gaps

- None. All 4 input files represented. `.requirements-input.md` excluded by instruction.
