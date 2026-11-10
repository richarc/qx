# Test Review: test/qx/simulation_conditionals_retention_test.exs

Read-only review (no Bash; nothing was executed, including mutation runs).

## Summary
The memory test is sound and unlikely to flake on the fixed code. Binary GC is allocation-driven (vheap), not time-driven, so machine speed changes sample count, not peak. Threshold 3.28 MB is 4.4x above the worst recorded fixed peak (745 KB, identical in 6/6 cold VMs). Old code peaks at 6.6 MB (2x over), live data that GC cannot free. Backend is pinned to Nx.BinaryBackend (config/test.exs:6) and simulation.ex has no Task/spawn, so the runner process owns all binaries. The main weakness is the result-field tests: none can deterministically catch a missing `Enum.reverse` (the most likely regression of this exact change).

## Iron Law Violations
None. `async: false` is justified (timing-sensitive poller; ExUnit runs sync modules after async ones finish, so the comment's "quiet scheduler" claim holds). No Process.sleep (the `receive ... after 1` is a poll interval, not a wait-for-effect). No Mox/DB.

## BLOCKER
None.

## WARNING

- [ ] **Shot order not pinned** (lines 51-73). Deterministic test has identical rows; probabilistic rows are only `[0,0]`/`[1,1]` and counts are order-independent. If `Enum.reverse` at simulation.ex:184 were dropped, only "state and probabilities are those of the last shot" (62-73) could fail, and only with ~50% probability per run (the reversed `List.last` is the first shot, which differs from the last shot half the time). A flaky-detecting test is a weak gate. Fix: repeat that test body ~20-30 times in one test (`for _ <- 1..30`), detection becomes 1-2^-30, cost is ~ms at n=2. Alternative: assert on `hd(classical_bits)` vs state is not possible without a seed (per-shot `seed_rand(nil)`), so repetition is the practical route.

- [ ] **No vacuity guard on the memory test** (lines 88-95). If the poller never sampled, `Process.info` returned nil (runner dead, returns 0), or a future change moved shots into other processes (Task.async_stream), `peak_bytes` stays 0 and the test passes on code that retains everything. Today it is not vacuous (old code measured red), but nothing preserves that. Add a floor, e.g. `assert peak_bytes > Integer.pow(2, num_qubits) * 8` (one state, 32 KB; recorded fixed peaks are 300-745 KB, so >10x headroom). Also consider asserting a sample count > some small number.

## SUGGESTION

- [ ] Missing coverage of `:renormalize` on the conditional path: simulation.ex:193 `maybe_measurement_renorm(last_state, renorm)` runs on `last_state` only. A test `Qx.run(circuit, shots: 5, renormalize: true)` asserting `Nx.sum(probabilities)` ~ 1 and result fields unchanged would pin that the reduce still feeds the renorm. (The backend option path is `with_backend` in run/2, not touched by this change; skip.)
- [ ] Tolerance `1.0e-6` (line 18) sits at the project's float32 floor; all expected values are exact 0/1, so it works, but `1.0e-5` is safer and equally strict for these assertions.
- [ ] Add `@tag timeout:` (e.g. 120_000) to the memory test, or at least be aware default 60 s applies. Old code at n=14 took 49 s, n=12 is ~4x less; fixed code ~1.5 s, so ample room, but a 10x slower runner is still inside 60 s. Low priority.
- [ ] Runtime ~1.6 s for the file: acceptable, no tag needed. Tagging `:slow`/`:memory` would only help if the suite excludes it by default; not justified at this cost.
- [ ] Residual (non-flake) risk worth a comment: `Process.info(pid, :binary)` counts uncollected dead ProcBins, so fixed-code peak depends on OTP vheap defaults (`min_bin_vheap_size`). 4.4x margin covers any plausible OTP change; if someone sets `ERL_FLAGS=+hmbs` huge, it could trip. Not worth action.

## Process hygiene (no findings)
- `spawn_link` (112): correct. If `fun` raises, the link kills the unlinked-trapping test process with the real exit reason; without the link the loop would spin (nil -> 0) until the 60 s ExUnit timeout. Keep it.
- Selective receive on `{:done, ^runner, _}`: no stray messages; runner exits normally after sending. Result message carries refc binaries by reference (no copy).
- `after 1` polling: first sample ~1 ms in, hundreds of samples over a ~1 s run; retained-code peak rises monotonically so any late sample catches it. Poller starvation on a 1-core CI only reduces sample count.
- `Process.info(pid, :binary)` may double-count a binary referenced by several ProcBins; that biases toward failing only the retained case, negligible on the fixed code.

## Result-field tests: other notes
- Deterministic test (30-41) pins length, counts, shape, type, probabilities: good against the "counts derived from bits" and last-state requirements. Bit-order within a shot (`"10"` vs `"01"`) is not pinned here (symmetric `[1,1]`), but conditional_operations_test.exs:31-93 covers asymmetric outcomes.
- No assertion is tautological. Line 58 recomputes counts from bits with the same `Enum.join` the implementation uses (mirrors rather than independent oracle) but combined with line 59 sum check it is acceptable.
- Conventions: `describe` naming matches neighbour style; helpers at module bottom, `@tolerance` at top: fine. Note comment lines 14-16 and 82-85 narrate measurement provenance; keep, they are durable facts, but the path reference `.claude/plans/.../research/` will rot once the plan dir is archived.

## Pre-existing (not this change)
- Per-shot `seed_rand(nil)` makes conditional runs non-reproducible (already in scratchpad out-of-scope), which is the root reason shot order cannot be pinned deterministically.
