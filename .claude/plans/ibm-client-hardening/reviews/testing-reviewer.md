# Test Review: ibm-client-hardening (Group B)

## Summary

Two new `describe "HTTP error hardening"` blocks, one updated existing assertion, and a `config/test.exs` addition. The overall approach is sound: Bypass is used correctly, `:counters` sidesteps Iron Law #2, 400 vs 503 status choice is well-reasoned, and `async: true` is preserved throughout. One BLOCKER exists in the paired implementation change that the `test.exs` addition depends on.

---

## Issues Found

### BLOCKER

**`Application.compile_env/2` without a default will raise in `:dev`/`:prod`**

`lib/qx/hardware/ibm.ex` line 11:

```elixir
@ibm_retry_delay Application.compile_env(:qx, :ibm_retry_delay)
```

`:ibm_retry_delay` is only configured in `config/test.exs`. There is no `config :qx, ibm_retry_delay: nil` fallback in `config/config.exs`. The 2-arity `compile_env/2` raises `ArgumentError` at compile time when the key is absent — so the module fails to compile outside `:test`.

The `test.exs` addition is the trigger: it introduced the config key, but the implementation assumed a 3-arity form (with `nil` default) or a base config line. Neither exists.

Fix (either option):
- `Application.compile_env(:qx, :ibm_retry_delay, nil)` in `ibm.ex`, OR
- Add `config :qx, ibm_retry_delay: nil` to `config/config.exs`.

This is a BLOCKER because `mix compile` in `:dev` will fail without it, which blocks the verify gate.

---

### Warnings

**No positive assertion on redacted body content — both hardening tests**

`ibm_test.exs` lines 461–463 and `portal_test.exs` lines 204–206 assert only that the body does not contain "SECRET" and is short. Neither test asserts what `body` actually IS.

- IBM test: the map contains `"errorMessage" => "boom"`, so `body` should be `"boom"` (known-key extraction path). A regression where `body` becomes `nil` still passes both assertions (`inspect(nil)` is 3 bytes, does not contain "SECRET").
- Portal test: the map has no known error key, so `body` should be `"(response body redacted: 1 field(s))"` (generic-marker path). Same nil-regression concern.

Adding `assert is_binary(body)` (minimum) or `assert body == "boom"` / `assert body =~ "redacted"` would pin the branch taken and catch silent nil-returns.

**Byte-size bound is loose relative to `@max_body_preview`**

Both hardening tests assert `byte_size(inspect(body)) <= 300`, but `Http` truncates at 256 bytes with a 14-byte "… (truncated)" suffix, giving a maximum of 270. The 300 bound passes current behaviour but would not catch a future increase of `@max_body_preview` to, say, 290. Consider `<= 270` or a comment explaining the 300 figure.

---

### Suggestions

**Binary body redaction path is untested**

`Http.redact_body/1` has a `when is_binary(body)` clause (plain truncation, no key extraction). No test sends a raw binary 400 body containing "SECRET". The generic-marker path (map with no known key) is implicitly covered by the portal hardening test, but the binary truncation path has zero coverage.

**`nil` body path untested**

`redact_body(nil)` returns `nil`. Low risk, but the clause is entirely without a test case. A single unit test in a `describe "Http.redact_body/1"` block would close this.

**503 empty-body response in retry test could use a comment**

`ibm_test.exs` line 474: `Plug.Conn.resp(conn, 503, "")` sends an empty body with no content-type. The retry logic does not inspect the body on transient failures, so this is correct, but a one-line comment — `# body irrelevant; :safe_transient retries on status alone` — would explain the asymmetry with the 200 branch that calls `json_resp`.

---

## Existing-Test Modification Assessment

`portal_test.exs` "other status falls through" changed from asserting the raw map `%{"error" => "teapot"}` to asserting the redacted string `"teapot"`. This change is justified and correct: the hardening work routed all fallthrough responses through `Http.http_error/2`, which extracts the known `"error"` key and returns the string value. The old assertion reflected a pre-hardening behaviour that no longer exists. The inline comment clarifies the intent.

---

## Bypass Usage

- `expect_once` used for non-retried paths (400, 418, 401) — correct.
- `expect` (unlimited) used for the retry path (503 → 200) — correct; `expect_once` would fail on the first Bypass hit.
- Both modules keep `async: true` with per-test Bypass instances, giving full parallel isolation.
