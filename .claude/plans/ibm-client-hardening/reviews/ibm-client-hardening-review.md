# Review — ibm-client-hardening (v0.9 Security & Hardening, Group B)

**Branch:** `fix/ibm-client-hardening`
**Verdict:** ✅ **PASS WITH WARNINGS** — no real blockers.
**Agents:** elixir-reviewer, testing-reviewer, iron-law-judge, security-analyzer,
requirements-verifier (5/5 completed).

## Requirements coverage — ALL MET (5/5)

- /results timeout → 60 s (only that call; default stays 30 s) — `ibm.ex:281`.
- retry `:safe_transient` on GETs (ibm `authed_request/5` + portal GET); POSTs stay `retry: false`.
- Redaction at all 3 sites (ibm.ex:66, ibm.ex:442, portal.ex:128 → `Http.http_error/2`).
- Streaming correctly DEFERRED (no `into:` anywhere; Backlog entry present).
- CHANGELOG (`### Changed` + `### Security`) + ROADMAP (both Group-B items ticked).

## Security — PASS (no blockers)

- Retry excludes auth/mutating POSTs — CONFIRMED (IAM + transpile + job-submit pin `retry: false`; `:safe_transient` only retries idempotent methods). No double-submit.
- `@ibm_retry_delay` cannot reach prod — set only in `config/test.exs`; nil elsewhere → Req default backoff.
- Bearer token / `service-crn` never enter error tuples (only the body is previewed).
- Residual (LOW SUGGESTION): the binary-body redaction path keeps the first 256 bytes, so a raw non-JSON error body leading with a secret leaks ≤256 B. Only fires on a Jason-decode failure (proxy/HTML), not normal JSON errors.

## Iron Laws — 0 violations

No `String.to_atom` on response data (portal atomize is allowlist-only); no unsupervised process (`:counters` is an atomic, not a process); all 3 modules `@moduledoc false` → internal, error-shape change is minor-appropriate; no raw errors across the public boundary.

## FALSE POSITIVE — the flagged "BLOCKER" is not real

Both elixir-reviewer and testing-reviewer flagged `Application.compile_env(:qx, :ibm_retry_delay)` (ibm.ex:11) as raising `ArgumentError` when the key is missing in dev/prod.

**Disproven empirically:** `ibm_retry_delay` is set ONLY in `test.exs`; a forced clean recompile in `:dev` (`rm -rf _build/dev/lib/qx/ebin && mix compile --force --warnings-as-errors`) compiled cleanly. `Application.compile_env/2` returns the implicit `nil` default when the key is absent — only `compile_env!/2` raises. Both agents confused the two.

→ Not a bug. Optional: pass an explicit `, nil` third arg for self-documentation (silences the concern).

## Real WARNINGS / SUGGESTIONS worth acting on

1. **[WARNING · testing]** The two redaction tests assert only `refute =~ "SECRET"` + `byte_size <= 300`. `inspect(nil)` is `"nil"` (no SECRET, tiny) → a regression returning `nil` would pass silently. Add `assert is_binary(body)` (or assert the exact redacted value).
2. **[SUGGESTION · testing]** No test for the binary-body path or the `nil` path of `redact_body/1`; add them. Size bound `<= 300` is loose (real max ~270).
3. **[SUGGESTION · elixir]** `retry_after_seconds/1` is byte-identical in `ibm.ex` and `portal.ex` (pre-existing dup); `Qx.Hardware.Http` is now the natural shared home.
4. **[SUGGESTION · elixir]** `truncate/1` mixes a `byte_size` guard with `String.slice` (character) slicing; minor byte/char inconsistency. Kept codepoint-safe on purpose.
5. **[SUGGESTION · elixir]** `maybe_put_retry_delay/1` wraps the int in a fn; Req also accepts a plain integer, so the comment "Req expects a function" is imprecise (the wrap still works).

## Recommendation

No blocker → mergeable. Worth doing before merge: #1 (real test gap) and #3 (dedup into `Http`), both cheap. #2/#4/#5 are optional polish.

## ALL FINDINGS RESOLVED (post-review fix pass)

User chose "fix all". Applied:

- **False BLOCKER** — added explicit `Application.compile_env(:qx, :ibm_retry_delay, nil)` (#5) so the intent is unambiguous (was never a bug).
- **#1** — the two redaction tests now assert the exact redacted value (`body == "boom"` / the generic marker), not just a size bound. Closes the `nil`-passes-silently gap.
- **#2** — new `test/qx/hardware/http_test.exs`: unit tests for `redact_body/1` (map-known-field, generic-marker, binary truncation, over-long value, `nil`, short-intact), `http_error/2`, and `retry_after_seconds/1` (8 tests).
- **#3** — `retry_after_seconds/1` moved into `Qx.Hardware.Http`; both clients now delegate (dup removed).
- **#4** — `truncate/1` now byte-bounded via `binary_part` (consistent with its `byte_size` guard).
- **#5** — `maybe_put_retry_delay/1` passes Req a plain integer (verified Req accepts it); comment corrected.

**Re-verified:** compile clean · credo `--strict` 0 issues · format OK · **242 doctests + 944 tests, 0 failures**.
