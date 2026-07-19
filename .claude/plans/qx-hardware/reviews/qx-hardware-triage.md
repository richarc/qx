# Triage Summary: qx-hardware

**Date**: 2026-05-14
**Source review**: `.claude/plans/qx-hardware/reviews/qx-hardware-review.md`
**Decision**: Fix all 8 findings before commit.

## Fix Queue (8 items)

### BLOCKERs

- [x] **B1** — `Qx.Hardware.run!/3` raises raw `RuntimeError` for `{stage, reason}` tuples (Iron Law #7).
  - File: `lib/qx/hardware.ex:140-147`
  - **Done**: Added `Qx.Hardware.ExecutionError` (stage/reason/message fields) in `lib/qx/errors.ex`. `run!/3` now uses `is_exception/1` guard and raises `ExecutionError.exception(reason)` for tuple errors.

- [x] **B2** — `timeout_ms: 0` test is non-deterministic.
  - File: `test/qx/hardware_test.exs:225`
  - **Done**: Changed to `timeout_ms: -1` with explanatory comment about the `>` guard race.

### WARNINGs

- [x] **W1** — `ensure_connected/4` third clause uses `if`; prefer guard heads with `when backend in backends`.
  - File: `lib/qx/hardware.ex:273-286`
  - **Outcome**: Reviewer's suggestion does not compile — `in` in guards requires a compile-time list/range, not a runtime variable. Reverted to the original `if` form with an explanatory comment. The `if` is the correct Elixir pattern here.

- [x] **W2** — `submit_sampler/3` convenience overload has no `@spec` / `@doc`.
  - File: `lib/qx/hardware/ibm.ex:218-220`
  - **Done**: Confirmed dead (orchestrator always passes shots). Deleted the arity-3 head + matching test.

- [x] **W3** — `config_test.exs` `from_env` tests share `async: true` with env mutation.
  - File: `test/qx/hardware/config_test.exs`, new `test/qx/hardware/config_from_env_test.exs`
  - **Done**: Moved the three `from_env*` tests into `Qx.Hardware.ConfigFromEnvTest` (`async: false`). `ConfigTest` stays async-safe.

- [x] **W4** — Lazy-connect test silently overrides `iam_exchange` script.
  - File: `test/qx/hardware_test.exs:343-367`
  - **Done**: `script_happy_path/2` now accepts `:skip_iam_exchange`; both lazy-connect tests pass it. Added a comment in the helper.

### SUGGESTIONs

- [x] **S1** — `Qx.Hardware.Portal.atomize/1` does O(n) `Enum.find` per map key.
  - File: `lib/qx/hardware/portal.ex:191-195`
  - **Done**: Added compile-time `@known_keys_map`; `to_known_atom/1` uses `Map.get/3` for O(1) lookup.

- [x] **S2** — `handle_poll_status/3` `cond` could bind `success?`/`failure?` first.
  - File: `lib/qx/hardware.ex:399-413`
  - **Done**: Bound `success?`/`failure?` before the `cond`.

## Skipped

None.

## Deferred

None — the bd issue for coverage was already filed in Phase 9.
