# Test Review: test/qx/draw_size_cap_test.exs

## Summary
Solid suite. Guard removal, guard-after-build and the 4096/8192 boundaries are caught.
No Iron Law violations (async: true, no sleeps, no mocks). No BLOCKERs.
Issues: one cross-test stderr isolation risk, a heap-harness asymmetry, and a few boundary gaps.

## Iron Law Violations
None. The harness waits on messages and monitors, not Process.sleep.

## BLOCKER
None.

## WARNING

- test/qx/draw_size_cap_test.exs:247,259 vs test/qx/draw/state_table_register_deprecation_test.exs:9-11
  `capture_io(:stderr)` hooks a process-global device. The existing test asserts `warn == ""`.
  The new Register tests call `IO.warn` (tables.ex:46) concurrently, because both modules are `async: true`.
  I could not confirm how ExUnit routes the output of non-capturing processes. If the capture is
  not strictly per-process, the existing test can see "deprecated" and fail intermittently.
  The new file's own `=~ "deprecated"` assertion is safe. At line 259 the new file discards the
  capture, so it is a no-op there.
  Fix: put both Register tests in one `async: false` module, or move the existing silent-tensor test.
  Alternatively, drop the `warn == ""` assertion.

- test/qx/draw_size_cap_test.exs:210-217 (harness asymmetry)
  The 2^20 tensor is built inside the heap-limited child (`draw/3` calls `probabilities/1` and
  `state/1` in the fun). The scratchpad measurements (Task 1.4) built it in the parent.
  The control test (line 221) builds it in the parent, so the two paths are inconsistent.
  A heap-hungry `Nx.broadcast` inside the child would be reported as `:killed`, a false FAIL
  with a confusing `{:raised, error} = :killed` match error. It cannot produce a false pass.
  It passed 25 runs on OTP 29 / Nx 0.13.0, so it is only a latent coupling to Nx internals.
  The child also uses the application-level default backend rather than the parent's.
  Fix: build the input in the test process and pass it into `run_with_heap_limit`, as the control test does.
  The same applies to `result(...)`, which allocates `probabilities(2)` first.

- test/qx/draw_size_cap_test.exs:123-130,140-145 (boundary gaps)
  The 4097 case is tested only for `counts`. The tensor functions are tested at 8192 and 8193 (histogram only).
  Mutations such as `bsr(size - 2, n)` or a call-site off-by-one in plot/histogram/state_table
  survive, because 4097 is never hit for them.
  Fix: make the over-cap tests iterate `[4097, 8192]` for `@tensor_functions`.

## SUGGESTION

- Harness soundness (lines 79-109) otherwise holds.
  - The `{:outcome, ...}` send precedes the DOWN signal from the same process, so it is received first.
  - `Process.demonitor(ref, [:flush])` is correct.
  - `kill: true` gives the exit reason `:killed`.
  - `max_heap_size` is counted in words and is deterministic, so it does not depend on load or timing.
  - Refc binaries (4 MiB tensor data) are off-heap and not counted.
  - The 2^17 margin (31x on a cold call, per the scratchpad) covers code loading, which also runs in the caller.
  - `rescue` does not catch exits or throws; those surface as a DOWN reason that fails the match legibly.
  - The `receive` has no `after`. A hang would be bounded by the 60 s ExUnit timeout.
  Add `after 10_000 -> flunk(...)` for a clearer failure.
  The semantics of `max_heap_size` and what it counts can differ across OTP versions.
  The comment pins OTP 29. The margins make it robust, but note that the numbers are specific to BinaryBackend.
- Missing paths:
  - Empty input: size 0 (an empty tensor or `%{}` counts) must pass. `bsr(-1, n)` is -1, so the code is fine but untested.
    `draw_test.exs:124` covers empty counts without the cap.
  - Non-power-of-two sizes below the cap (4095, 3 with `max_qubits: 2`) are never tested as passing.
  - `max_qubits: nil` and `true` are not in the invalid-value list (lines 194-205).
  - Validation is tested via `Qx.Draw` only, not via the facade. That is acceptable because they are delegates.
  - `Qx.DrawSizeError.exception/1`: the binary-message clause (errors.ex:407) is untested.
    A bad tuple gives FunctionClauseError.
  - The `validate_draw_size!` and `validate_max_qubits!` unit paths are covered only indirectly. That is fine.
  - Guard placement for `counts` is not distinguishable. Its heap harness is absent,
    but its input is a bounded map, so that is acceptable.
- Generated tests (lines 112, 155, 194, 209, 228): no name collisions.
  The describe prefix disambiguates, and `inspect(value)` makes the validation names unique.
  `"Qx facade for ..."` repeats the describe name.
  `#{1 <<< 17}` in a test name works only because Bitwise is imported at module level.
  Line 196 (`value = unquote(value)`) is slightly odd but fine.
- Doctest directive (AGENTS rule 4): no new `iex>` examples were added in the diff.
  The `Qx.draw(result, max_qubits: 14)` snippets in the Draw moduledoc and the doc option blocks are indented code, not doctests.
  No directive is needed.
- `vega_lite` is `optional: true` (mix.exs:62). Every draw test needs it in the test env. That is existing practice.
- `assert_raise` calls without a message at lines 148 and 190 are acceptable because the other tests assert the message.

## Existing tests that overlap (one line each, not analyzed in depth)
- test/qx/draw_test.exs:119-130,140 — small-input smoke tests for plot, counts, histogram and draw_state; not contradicted. Still valid under the default cap.
- test/qx/draw_contracts_test.exs — draw contract tests; not checked against the new option.
- test/qx/draw/state_table_register_deprecation_test.exs:9-23 — the Register deprecation warning is covered here for 1 qubit. See the stderr isolation WARNING above.
- test/qx/draw_test.exs:106 — Register escape hatch at small size; unaffected.
- test/qx_manual_test.livemd — draw usage (32 matches); not run by ExUnit.
