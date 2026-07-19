# Scratchpad — ibm-client-hardening

## Decisions

- **Scope = LEAN** (user): timeout(60s /results) + retry(:safe_transient GETs) +
  error-body redaction. **Streaming DEFERRED** to a roadmap follow-up (marginal
  benefit — result JSON-parsed to a map anyway; IBM is trusted-ish; high effort).
- **Retry** = re-enable Req's default `:safe_transient` (code currently sets
  `retry: false`). Never retries POST/DELETE → IAM POST + job submit unaffected.
- **Timeout** = parametrize `authed_request/4` (default 30s); `fetch_results`
  passes 60s. Not a blanket bump.
- **Redaction** = one shared bounded `redact_body/1` (recommend new
  `Qx.Hardware.Http` @moduledoc false) applied at all 3 `{:http, status, body}`
  sites; keep a ~256-char debuggable preview.

## Verified facts

- Req 0.5. `:safe_transient` is the DEFAULT retry mode (retries safe GET/HEAD on
  transient errors); `:transient` retries all methods. We want `:safe_transient`.
- NOTHING pattern-matches the `{:http, _, body}` body except the 3 emission
  sites (ibm.ex:62, ibm.ex:422, portal.ex:125) → redaction is non-breaking.
- `/results` = `fetch_results/2` → `authed_request(:get, cfg, "/jobs/<id>/results", nil)`
  → shared `receive_timeout: 30_000, retry: false` (ibm.ex:388-390).
- IAM POST (ibm.ex:41-52) has its own Req.new (10s, retry:false) — leave retry
  (POST); redact its error body (ibm.ex:62).
- Existing Bypass tests (ibm_test/portal_test) use http://localhost — must stay
  green.

## Open questions (resolve at /phx:work)

- Redaction fields/cap (recommend map→known-error-field else bounded inspect;
  binary→slice 256). Shared helper module vs per-module dup (recommend shared).
  Portal GET retry too (recommend yes).
- Retry test: injecting a fast retry_delay for a 503→200 Bypass test, or assert
  the always-503 path returns typed error after retrying (bounded runtime).

## Dead ends

- True streaming of /results — descoped; benefit marginal (JSON→map), source
  trusted. The meaningful version (stream + size cap) is a separate follow-up.
