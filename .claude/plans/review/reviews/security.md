# Security Audit: Qx.Hardware.Ibm — `:delete` dead-branch removal

## Executive Summary

**Verdict: PASS. No security implication.** The diff removes an
unreachable `:delete -> Req.delete(request)` clause from the private
`authed_request/5` dispatch. This is confirmed pure dead-code removal:
it strips no capability, defense, or audit path that any caller relied
on. Surrounding auth logic is sound. Not a full audit of the module.

## The Change — Confirmed Safe

- `git grep authed_request` (repeated here via Grep) shows every one of
  the 6 call sites passes only `:get` or `:post`:
  - `:get` — list_backends, fetch_backend_configuration, poll_job, fetch_results
  - `:post` — submit_sampler (`/jobs`), cancel_job (`/jobs/{id}/cancel`)
- **Job cancellation is unaffected**: `cancel_job/2` (line 230) uses
  `POST /jobs/{id}/cancel`, IBM's documented cancel endpoint — it never
  used the HTTP `DELETE` verb. Removing the `:delete` clause removes no
  cleanup/cancellation capability.
- The `case method` at lines 413-416 is now exhaustive over the only
  values ever passed. An unsupported atom would raise `CaseClauseError`
  (fail-closed) exactly as before — the `:delete` arm was never reached,
  so behaviour is identical.
- No audit/logging was attached to the removed branch; nothing observes
  it. Dialyzer's dead-code flag was correct.

## Surrounding Auth Logic — Sanity Pass (all clean)

- **Bearer token handling**: token injected via header only
  (line 386), not interpolated into URLs or logged. Fine.
- **IAM re-auth on 401**: `with_iam_refresh/2` retries exactly once
  after a fresh `iam_exchange`, then propagates — no infinite loop, no
  credential caching leak. Correct.
- **Retry policy**: `retry: :safe_transient` (line 399) retries only
  idempotent GET/HEAD; POSTs (IAM exchange, job submission, cancel) are
  never auto-replayed — correctly prevents duplicate job creation.
- **Secrets**: API key comes from `Config` (runtime), none hardcoded.

## Pre-existing Notes (not in this diff — one line each, not deep-dived)

- Line 386: `"Bearer " <> (config.access_token || "")` sends an empty
  bearer when token is nil; benign (server returns 401) but slightly
  masks a missing-token bug — low.
- Config struct holds `ibm_api_key`/`access_token` in plaintext; as a
  pure library this is expected, but downstream consumers should avoid
  logging/inspecting `Config` structs — informational.

## Recommendations

None blocking. Merge the dead-code removal as-is.

## Tools to Recommend (agent has no Bash)

- `mix dialyzer` (confirms the false-positive is resolved)
- `mix sobelow --exit medium` (repo-wide, optional)
- `mix deps.audit` / `mix hex.audit`
