# Test Review: qx-hardware test suite (4 new files)

## Summary

The suite is well-structured with good async discipline, solid Bypass usage, and strong coverage of error routing and stage sequencing. Five issues found ranging from a semantic test error to async-safety risk.

---

## Iron Law Violations

None. `async: true` is set on all four files. No Mox (not in deps). No `String.to_atom` in production or test code. Typed errors verified at boundary.

---

## Issues Found

### BLOCKER

**B1 — `timeout_ms: 0` does NOT exercise deadline code path**
`test/qx/hardware_test.exs:220–228`

`do_poll/1` checks `System.monotonic_time(:millisecond) > state.deadline` _before_ the first poll call. The deadline is `monotonic_now + 0`. On a fast machine `monotonic_now` at the check is still equal to `state.deadline`, so `>` is false and the loop enters `poll_once/1` — meaning the test may accidentally succeed without ever triggering the timeout branch. Use `timeout_ms: -1` (or `-1000`) to guarantee the deadline is already in the past when `do_poll/1` runs for the first time. This is the correct way to force the `>` guard to be true unconditionally.

---

### WARNING

**W1 — `async: true` with `System.put_env` in `config_test.exs` is a race condition**
`test/qx/hardware/config_test.exs:161–180`

`with_env/2` uses `System.put_env` / `System.delete_env` inside an async test. ExUnit runs async tests concurrently in the same OS process; any other test that reads the same `QX_*` env vars during the window between `put_env` and the `after` restore can see poisoned values. The `with_env` helper correctly restores state but **does not prevent the race** during execution of `fun.()`. Fix: remove `async: true` for the three `from_env` tests (or move them to a separate `describe`-block module with `async: false`). The `new/1` and `new!/1` tests do not touch env and can remain async.

**W2 — Lazy-connect test over-scripts with `script_happy_path` after scripting connect-phase calls**
`test/qx/hardware_test.exs:343–367` ("succeeds when identity + backends_list absent")

The test calls `Recorder.set` for `portal_me`, `iam_exchange`, and `list_backends`, then calls `script_happy_path/1` which also sets `iam_exchange` (overwriting the earlier value). The `Recorder.set` implementation replaces the entire response list (`List.wrap/1`), so the second `iam_exchange` script wins. The happy-path `iam_exchange` response re-attaches `__recorder__`, which is correct — but this is fragile: the order of `Recorder.set` calls matters and it's not obvious the overwrite is intentional. Add a comment explaining the override, or restructure `script_happy_path` to accept a `:skip_iam_exchange` option so the lazy-connect tests don't need to rely on call-order overwrite semantics.

**W3 — `fetch_backend_configuration failure → {:error, {:ibm_auth, _}}` — misleading test name / wrong stage tag**
`test/qx/hardware_test.exs:191–201`

The test name says `ibm_auth` for a `fetch_backend_configuration` failure. Looking at `hardware.ex`, `ibm_fetch_backend/3` wraps with `stage(:ibm_auth, ...)` so the tag is technically correct per current impl. However, the test name reads as if authentication itself failed, not backend lookup. Rename to `"fetch_backend_configuration failure → {:error, {:ibm_auth, :not_found}}"` or, better, consider whether the stage tag `:ibm_auth` is the right choice for backend-config failures (it conflates two distinct failure modes for callers).

**W4 — `cancel/3` test does not pass `recorder` in config — stub will raise**
`test/qx/hardware_test.exs:402–426`

`Hardware.cancel("job_xyz", ctx.config, ibm: StubIbm.Ibm)` — `ctx.config` already has `__recorder__: recorder` from setup, so this works. But the cancel test does not call `script_happy_path`; it only scripts `:iam_exchange` and `:cancel_job`. `iam_exchange` in the stub calls `Recorder.call(pid, :iam_exchange, ...)`, which pops the scripted response. The `ibm_authenticate` path in `hardware.ex` short-circuits when `access_token` is already a binary — but `ctx.config.access_token` is nil (not set in the shared setup). Verify that the Recorder responds correctly here; if `ibm_authenticate` falls through to `iam_exchange`, the scripted response in `cancel/happy path` sets `iam_exchange` to `{:ok, Map.put(ctx.config, :access_token, "t")}`. This response does not include `__recorder__`, so any subsequent stub call on the returned config (e.g., `cancel_job`) would crash with a `FunctionClauseError` because `StubIbm.Ibm.cancel_job/2` pattern-matches on `%{__recorder__: pid}`. The `cancel_job` response is scripted on `ctx.recorder` but the config returned from `iam_exchange` lacks `__recorder__`. Ensure the `iam_exchange` return value in these tests includes `__recorder__: recorder` (as the happy-path helper does via `Map.put(..., :__recorder__, recorder)`).

---

### SUGGESTION

**S1 — "unknown status" Iron Law test is sound but could be more explicit**
`test/qx/hardware/ibm_test.exs:292–299`

The test correctly verifies `{:error, {:unknown_status, "WatNewState"}}` is returned rather than an atom. Good. To make the intent clearer (drift from allowlist surfaces loudly, no `String.to_atom`), add a one-line comment: `# Iron Law: unknown statuses return tagged errors, never converted to atoms`.

**S2 — `Recorder.call/3` appends with `&1 ++ [{key, args}]` — O(n) on every call**
`test/support/stub_ibm.ex:29`

Minor: appending to a list is O(n). For test sizes this is harmless, but prepending and reversing in `calls/1` is idiomatic Elixir. Not a correctness issue.

**S3 — `base_url_for/1` tests are pure-function tests using Bypass setup overhead**
`test/qx/hardware/ibm_test.exs:441–456`

These tests don't need or use the `api`/`iam`/`config` from setup. They work correctly as-is, but adding `@tag :skip_bypass` or moving them to a separate `describe` block without relying on the shared setup would make intent clearer.
