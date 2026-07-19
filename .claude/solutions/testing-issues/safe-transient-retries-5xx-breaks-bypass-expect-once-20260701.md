---
module: "Qx.Hardware.Ibm"
date: "2026-07-01"
problem_type: testing_issue
component: hardware-http-client
symptoms:
  - "After enabling `retry: :safe_transient` on GET requests, a `Bypass.expect_once` stub returning a 5xx status is hit MORE than once, so the test fails with a Bypass 'expected 1 request' error"
  - "A redaction/error-mapping test that used status 500 (or 503) suddenly sees the endpoint called 3-4 times once retry is on"
root_cause: "Req's `:safe_transient` retry mode retries idempotent methods (GET/HEAD) on TRANSIENT failures — connection errors plus statuses 408, 429, 500, 502, 503, 504. A test that asserts an unmapped-status error path by returning one of those statuses now triggers Req's retry loop, so the Bypass handler is invoked once per attempt. `Bypass.expect_once` expects exactly one call and fails."
severity: medium
iron_law_number: null
tags: [testing, bypass, req, retry, safe-transient, http-client, expect-once, transient-status]
related_solutions: []
---

# `:safe_transient` retries 5xx — pick a non-transient status for error-path tests

## Symptoms

- Turning on `retry: :safe_transient` for GETs made an existing error-mapping
  test flaky/failing: `Bypass.expect_once(api, "GET", "/backends", …)` with a
  `500` body now reports the handler was called multiple times.
- A new redaction test (assert the `{:http, status, body}` body is bounded)
  written against a `500` response retried 3× before returning the error.

## Investigation

1. New retry behaviour: `authed_request` changed `retry: false` → `:safe_transient`.
2. Req's `:safe_transient` retries safe methods (GET/HEAD) on transient failures:
   connection errors + statuses **408, 429, 500, 502, 503, 504**.
3. A `500`/`503` GET in a test therefore drives the retry loop → the Bypass stub
   fires once per attempt → `expect_once` (exactly-one) fails.

## Root Cause

The status chosen to exercise the `{:http, status, body}` fallthrough was itself
a *transient* status, so the newly-enabled retry replayed it. The test's intent
(hit the error path once) collides with retry semantics.

## Solution

For error-path tests that must fire exactly once, return a status that is
**both unmapped AND non-transient** — e.g. **400** (client error, never
retried). Reserve the transient statuses (503) for the test that actually
asserts retry.

```elixir
# redaction / error-mapping test — 400 is unmapped AND not transient,
# so it hits the {:http, _, _} fallthrough without being retried.
Bypass.expect_once(api, "GET", "/backends", fn conn ->
  json_resp(conn, 400, %{"errorMessage" => "boom", "leaked" => leak})
end)
assert {:error, {:http, 400, body}} = Ibm.list_backends(config)

# retry test — 503 IS transient, so :safe_transient retries it. Use
# Bypass.expect (any count) + a :counters counter: 503 once, then 200.
counter = :counters.new(1, [])
Bypass.expect(api, "GET", "/backends", fn conn ->
  :counters.add(counter, 1, 1)
  if :counters.get(counter, 1) == 1,
    do: Plug.Conn.resp(conn, 503, ""),
    else: json_resp(conn, 200, %{"devices" => []})
end)
assert {:ok, []} = Ibm.list_backends(config)
assert :counters.get(counter, 1) == 2
```

Two more details that matter:

- **Counter without a process**: use `:counters` (an Erlang atomic), not
  `Agent.start_link` — the latter trips the "no unsupervised process" iron law
  and needs cleanup.
- **Fast retry test**: Req's default backoff makes a real retry wait ~1 s. Gate
  a test-only zero delay through `Application.compile_env` (see the compile-env
  solution) so the retry test is instant.

## Prevention

- [ ] Iron Law? No — test-design guidance.
- Specific guidance:
  - When a client enables `:safe_transient` (or `:transient`), audit existing
    HTTP tests: any `expect_once` returning **408/429/500/502/503/504** will now
    be retried. Switch those to a non-transient status (400/403/404/422) unless
    the test is specifically about retry.
  - Use `Bypass.expect` (not `expect_once`) + a `:counters` call-counter for the
    retry assertion; assert the counter reached the expected attempt count.

## Related

- ROADMAP v0.9 (Security & Hardening), plan: ibm-client-hardening.
- Pairs with the test-only `retry_delay` compile_env knob (same plan).
