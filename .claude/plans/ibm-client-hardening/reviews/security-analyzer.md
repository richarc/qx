# Security Audit: Qx — ibm-client-hardening

## Executive Summary

This change is itself a defence-in-depth hardening: `redact_body/1` bounds
leaked HTTP error bodies, and `:safe_transient` retry + a longer `/results`
timeout are added to the IBM/portal clients. The control meets its stated goal
(stop full-body / echoed-request-context leakage). No BLOCKERs. One low-severity
residual leak surface (binary error bodies) noted as SUGGESTION. Auth POSTs are
correctly excluded from retry, and the test-only retry-delay knob does not reach
prod.

## Findings

### 1. redact_body/1 — residual leak on the binary path (SUGGESTION, Low)

- **Location**: `lib/qx/hardware/http.ex:34,45-46`
- **Assessment**: The map path is strong — only a recognised `@known_error_keys`
  value survives (truncated to 256 B via `to_preview` → `truncate`); any other
  map collapses to `"(response body redacted: N field(s))"`, exposing only
  `map_size`. That fully blocks the multi-field / echoed-request-context leak
  this control targets.
- **Residual**: `redact_body(body) when is_binary(body)` keeps the *first* 256
  bytes. If a raw (non-JSON) error body leads with sensitive content, up to 256
  bytes leak into the `{:error, {:http, status, preview}}` tuple a caller may log.
  In practice IBM/portal errors are JSON and decode to maps (`decode/1`,
  ibm.ex:449) → map path, so the binary path only triggers on a Jason failure
  (proxy/HTML/plain-text error). Bounded and low-likelihood, but not zero.
- **Options**: (a) accept as defence-in-depth (bounded 256 B is a large
  improvement over full-body); or (b) treat unstructured binaries like unknown
  maps — emit `"(response body redacted: N bytes)"` instead of the leading
  slice. (b) is stricter and cheap; recommended if the preview's debug value on
  non-JSON bodies is judged low.
- **Known-field value**: even if a value is a nested map/list, `to_preview`
  inspects then `truncate`s to 256 B — bounded. Injected/attacker-controlled
  content is length-capped; acceptable. The generic `map_size` marker leaks
  nothing sensitive.

### 2. Retry does NOT replay auth/mutating POSTs (CONFIRMED — clean)

- IAM token exchange (`iam_exchange`, ibm.ex:53) sets `retry: false` explicitly.
- `authed_request` uses `retry: :safe_transient` for all verbs, but Req's
  `:safe_transient` only retries safe/idempotent methods (GET/HEAD) on transient
  errors — POST (`submit_sampler` `/jobs`, `cancel_job` `/cancel`) is never
  auto-replayed, so no double-submit / double-charge risk. Portal `post/3`
  (transpile) also pins `retry: false`. Comments at ibm.ex:392-393 and
  portal.ex:77-78 document the intent correctly.

### 3. `/results` 60s timeout + retry-delay knob (CONFIRMED — no prod risk)

- `@ibm_retry_delay = Application.compile_env(:qx, :ibm_retry_delay)`
  (ibm.ex:11). Grep confirms the key is set only in `config/test.exs:15`
  (`ibm_retry_delay: 0`). `config/config.exs` does not set it and imports
  `test.exs` only when `config_env() == :test`. There is no `dev.exs`/`prod.exs`/
  `runtime.exs`, so in prod/dev the value is `nil` → `maybe_put_retry_delay/1`
  leaves `:retry_delay` unset → Req's default exponential backoff. The `0`-delay
  cannot leak to prod. (Library note: `compile_env` resolves when the qx dep is
  compiled; a downstream app could set the key in its own config, but that is an
  intentional knob, not a leak.)
- The 60 s `receive_timeout` on `/results` (ibm.ex:281) applies to a single
  authenticated GET; combined with `:safe_transient` it could extend total wall
  time on repeated transient failures, but bounded by Req's default max retries.
  No DoS-amplification or resource-exhaustion concern for a client library.

## Other checks

Bearer token / `service-crn` headers are not included in any error tuple — only
the response body is previewed, so credentials are not echoed. No
`String.to_atom`, `raw/1`, SQL, or unsafe deserialization introduced; `portal.ex`
retains its atom-exhaustion-safe `@known_keys_map` allow-list. Secrets remain in
`Config` (caller-supplied), none hardcoded.

## Verdict

PASS. No BLOCKER/WARNING. One SUGGESTION (finding 1) — optionally drop the
leading-slice preview for non-JSON binary error bodies. The redaction achieves
its objective of stopping full-body/echoed-context leakage.

## Tools to run manually (no Bash access here)

- `mix sobelow --exit medium`
- `mix deps.audit` / `mix hex.audit`
