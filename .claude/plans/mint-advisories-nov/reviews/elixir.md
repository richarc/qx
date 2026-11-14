# Review: mint 1.9.3 -> 1.11.0 / hpax 1.0.4 -> 1.1.0

Status: Changes requested (docs text only; lockfile and runtime are fine)

## Warnings

1. **CHANGELOG.md (Security entry) and ROADMAP.md: "fixed by 1.10.2" and "pins mint below 1.10.2" are wrong.**
   Verified by reading `deps/mint/CHANGELOG.md`. It has no v1.10.2 heading (versions are 1.11.0, 1.10.1, 1.10.0).
   - CVE-2026-82728 and CVE-2026-82729: fixed in 1.10.0.
   - CVE-2026-82672: fixed in 1.10.1.
   - CVE-2026-91043, CVE-2026-92103 and CVE-2026-94194: fixed in 1.11.0. The 1.11.0 notes say "upgrade from 1.10.x ... fixes for three recently-published CVEs".
   So the minimum safe version is 1.11.0, and the advice to consumers ("pins below 1.10.2, run `mix deps.update mint`") would leave them on a vulnerable 1.10.x.
   Fix: say "all fixed by 1.11.0" and "below 1.11.0". Remove 1.10.2 unless it exists on hex.pm. I could not check hex.pm, so a 1.10.2 backport is UNVERIFIED, but the local changelog contradicts it.
2. CVE severities (HIGH/MEDIUM split) and the CVE-to-description mapping are not in the local changelog. Only the CVE ids and descriptions for 82728, 82729, 82672, 91043, 92103 and 94194 are. Severity is UNVERIFIED (not checked against the advisories). The descriptions in the entry, "unbounded HTTP/1 status-line and chunk-extension buffering" and "HTTP/2 header-size limit bypass", match the changelog.

## Lock and constraint compatibility (verified by reading)

- `mix.lock` finch 0.23.0 requires `mint ~> 1.8`, which permits 1.11.0. `deps/finch/mix.exs:36` agrees.
- `deps/req/mix.exs` requires `finch ~> 0.21`, which permits 0.23.0. Req has no direct mint constraint.
- Locked mint 1.11.0 requires `hpax ~> 1.1`, and the lock has hpax 1.1.0. `deps/mint/mix.exs:79` agrees. `deps/mint/mix.exs` is `@version "1.11.0"`, so deps are in sync with the lock.
- Nothing else in the lock depends on hpax (not exhaustively grepped; the lock lines are very long). Skim the lock for other hpax users if you want certainty.

## Behaviour-change analysis (verified by reading ibm.ex, portal.ex, http.ex, deps/req/lib/req/finch.ex and steps.ex)

- **Error shapes:** Qx matches `{:error, %{reason: reason}}` and falls back to `Exception.message/1`. Both ibm.ex (lines 68-72, 443-446) and portal.ex (130-134) do this. It never pattern-matches a specific Mint struct or reason atom. Req's `normalize_error` (`deps/req/lib/req/finch.ex:173-200`) wraps Mint errors in `Req.TransportError` or `Req.HTTPError`, both of which have `:reason`. The new rejections (content-length mismatch, invalid status line or header, oversize line, NO_ERROR reset) will surface as `{:error, {:network, reason}}`. Previously the NO_ERROR reset could be a truncated `{:ok, ...}`. The `{:network, reason}` shape is unchanged, but the reason values are new. Callers that match on specific reasons are not in this repo. Not checked outside `lib/qx/hardware/`.
- **Retry:** `retry: :safe_transient` (ibm.ex:399, portal.ex:79) retries GET/HEAD on `Req.TransportError` with `:timeout | :econnrefused | :closed` (steps.ex:2223-2227, 2345). A new Mint protocol error is `Req.HTTPError`, which is not in that list as far as I read. I did not read the full retry predicate, so treat this as partly inferred. A malformed server response now fails fast instead of being accepted, and is not retried. This is an acceptable change.
- **Timeouts:** "Don't close the connection on a receive timeout" only affects pooled connection reuse inside Finch. Qx sets `receive_timeout` per request (10s, 30s or 60s) and has no logic that assumes the connection is closed afterwards. Whether Finch discards the connection after a timeout is inferred, not verified. No Qx change is needed.
- **Response handling:** Qx only reads status, body and the `retry-after` header (`http.ex:45`). Stricter header validation (invalid header fields rejected, obsolete line folding unfolded) cannot affect those unless the IBM or Portal servers send non-compliant headers, which is an unlikely but untestable runtime risk. The hardware code is exercised by tests, probably with `Req.Test` stubs that bypass Mint, so tests will not cover these paths. This is inferred.

## Suggestions

1. After fixing the text, run `scripts/audit_shipped.sh` and `mix test`. I cannot run them (no Bash).
