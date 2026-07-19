# Harden the IBM Quantum HTTP client (timeouts, retry, error redaction)

**Slug:** `ibm-client-hardening`
**Branch:** `fix/ibm-client-hardening`
**ROADMAP:** qx v0.9 (Security & Hardening), Group B — perf HIGH + security LOW.
**Type:** Robustness + security hardening. Behaviour changes: GETs now retry
transient failures; `{:http, _, body}` errors carry a bounded/redacted body.
Typed errors preserved, no new dep, no signature change.

## Problem

`lib/qx/hardware/ibm.ex` (and `portal.ex`):

1. **No retry on transient failures.** `authed_request/4` sets `retry: false`
   (ibm.ex:390), so a transient 503 / connection blip on a GET fails hard.
   Req's default `:safe_transient` (retries only safe GET/HEAD on transient
   errors) is exactly what's wanted (perf HIGH).
2. **Short `/results` timeout.** `/jobs/<id>/results` (fetch_results → `authed_request(:get, …)`)
   uses the shared `receive_timeout: 30_000`; multi-MB Sampler V2 results can
   take longer. Bump to 60 s for that call.
3. **Full response body leaked in errors.** `{:error, {:http, status, body}}` at
   ibm.ex:62 (IAM), ibm.ex:422 (authed_request), portal.ex:125 propagates the
   entire decoded body; a downstream that logs errors verbatim leaks response
   content / echoed request context (security LOW).

## Decided constraints (do not re-litigate)

- **Scope = LEAN** (user): timeout + retry + redaction now. **Streaming the
  result body is DEFERRED** to a new roadmap follow-up (marginal benefit — the
  result is still JSON-parsed to an in-memory map; trusted source (IBM); high
  complexity). Record it, don't build it.
- **Retry:** `retry: :safe_transient` (Req default) on `authed_request/4`.
  `:safe_transient` never retries POST/DELETE, so the IAM POST and job
  submission are unaffected. Confirmed nothing depends on `retry: false`.
- **Timeout:** parametrize `authed_request/4` with a `receive_timeout` option
  (default 30 s); `fetch_results/2` passes `60_000`. Don't blanket-raise all
  requests to 60 s.
- **Redaction:** a single shared helper produces the error tuple with a
  **bounded** body (nothing consumes the body today, so this is safe). Keep a
  short debuggable preview, not the full body.
- **Typed errors** unchanged in shape (`{:error, {:http, status, <bounded>}}`).

## Open decisions (resolve at /phx:work)

- **Redaction policy** — recommend: if the body is a map, extract a known error
  field (`"errors"`/`"message"`/`"error"`/`"detail"`/`"title"`) else a bounded
  `inspect`; if binary, `String.slice(0, 256)`; cap the whole thing at ~256
  chars with a `…`/`(truncated)` marker. Confirm the cap + fields.
- **Shared helper location** — recommend a tiny internal `Qx.Hardware.Http`
  (`@moduledoc false`) with `http_error(status, body)` so ibm.ex + portal.ex
  redact identically (a security control should be consistent). Alternative:
  duplicate a private `redact_http_body/1` in each (rejected: drift risk).
- **Portal GET retry** — `portal.ex` GETs also set `retry: false`; enabling
  `:safe_transient` there too is low-risk and consistent. Recommend yes (note
  it; the named finding is ibm.ex, but portal is the same pattern).

---

## Phase 1 — Tests first (TDD; test-guard hook needs approval)

> `ibm_test.exs` / `portal_test.exs` use Bypass mocks. Surface test additions at
> `/phx:work`, get approval, confirm RED.

- [x] [P1-T1] **Redaction** (`ibm_test.exs` + `portal_test.exs`): a 500 (or other
      unmapped status) response with a large/echoed body → the returned
      `{:error, {:http, status, body}}` `body` is BOUNDED (`byte_size <= ~300`)
      and does NOT contain the full original body (assert a sentinel from the
      big body is absent; assert a short preview/message is present).
- [x] [P1-T2] **Retry** (503→200 via `:counters` counter; `config/test.exs` sets `ibm_retry_delay: 0` for instant retry) **Retry** (`ibm_test.exs`): a GET that returns 503 once then 200 →
      succeeds (Req retried). Use `Bypass.expect` with a call counter; override
      `retry_delay` to near-zero in the test path so it isn't slow (confirm how
      to inject it — likely a test-config option on the Req request, or accept a
      small fixed delay). If injecting a fast delay is awkward, assert instead
      that a GET which 503s on EVERY attempt returns the typed error after
      retrying (still proves retry is enabled), keeping the test bounded.
- [x] [P1-T3] Confirmed RED (3 failures: full body leaked; GET not retried).

## Phase 2 — Implement (`lib/qx/hardware/ibm.ex`, `portal.ex`, new `http.ex`)

- [x] [P2-T1] Added `lib/qx/hardware/http.ex` (`Qx.Hardware.Http`) with `http_error/2` + `redact_body/1` (known-error-field extraction, else generic marker, ~256-char cap). Add `lib/qx/hardware/http.ex` (`Qx.Hardware.Http`, `@moduledoc false`)
      with `http_error(status, body) :: {:error, {:http, status, redacted}}` +
      the bounded `redact_body/1`. (Or per-module helper — decide per Open
      decision.)
- [x] [P2-T2] Routed all 3 sites (ibm.ex:65, ibm.ex:441, portal.ex:127) through `Http.http_error/2` (aliased per credo). `ibm.ex`: route the 3 error emissions through the helper —
      IAM (ibm.ex:62) and authed_request (ibm.ex:422). `portal.ex:125` too.
- [x] [P2-T3] `authed_request/5` now `retry: :safe_transient` + `receive_timeout` opt (default 30 s); `fetch_results/2` passes 60 s; `@ibm_retry_delay` (compile_env) wraps millis into Req's retry-count fn. `ibm.ex authed_request/4`: change `retry: false` → `retry: :safe_transient`;
      add a `receive_timeout` option (default 30_000) threaded from an opts
      param; `fetch_results/2` calls `authed_request(:get, cfg, path, nil, receive_timeout: 60_000)`.
- [x] [P2-T4] portal GET → `:safe_transient`; transpile POST stays `retry: false`. `portal.ex` GETs: `retry: false` → `:safe_transient`.
      Leave POST retries off (transpile POST is not safe to auto-retry).
- [x] [P2-T5] Hardware tests GREEN (also updated one existing portal test whose assertion expected the raw map — now `{:http, 418, "teapot"}`).

## Phase 3 — Defer streaming + CHANGELOG + ROADMAP

- [x] [P3-T1] Ticked both v0.9 Group-B items; deferred streaming → Backlog. Add a ROADMAP follow-up (v0.9 or Backlog) for the deferred
      streaming/size-cap: "Stream `/results` via Req `into:` with a body size
      cap (abort over ~50 MB) — deferred from ibm-client-hardening; marginal
      without the cap, trusted source." Tick only the timeout+retry+redaction
      parts of the two v0.9 Group-B items (or split the item's checkbox note to
      reflect timeout/retry/redaction done, streaming deferred).
- [x] [P3-T2] CHANGELOG `[Unreleased]`: `### Changed` (retry+timeout) + `### Security` (redaction). `CHANGELOG.md` `[Unreleased]` `### Security`: IBM/portal HTTP
      errors no longer echo the full response body (bounded preview); `### Fixed`
      or same block: GET requests retry transient failures (`:safe_transient`)
      and `/results` timeout raised to 60 s.

## Verification (mandatory gate) — ALL GREEN

- [x] `mix compile --warnings-as-errors` — clean.
- [x] `mix format --check-formatted` — clean.
- [x] `mix credo --strict` — 0 issues (857 mods/funs).
- [x] `mix test` — **242 doctests + 936 tests, 0 failures** (3 new cases).

## Out of scope

- **Streaming / size-cap the result body** — deferred (roadmap follow-up).
- Groups D (deps) — separate; A + C done.
- Changing the `{:http, status, _}` tuple SHAPE (only the body value is bounded).

## Done = merge-ready

All phases checked, verification green, `/phx:review` PASS (or triaged).
Squash-merge, tick/adjust the ROADMAP items, push `main`.
