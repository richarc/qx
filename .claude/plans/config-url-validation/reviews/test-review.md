# Test Review: test/qx/hardware/config_test.exs — describe "URL/host validation (loopback allowlist)"

## Summary

10 new tests in the `describe "URL/host validation (loopback allowlist)"` block. Structure,
async-safety, and field-tag specificity are solid. Two security-relevant edge cases are not
pinned. One regex assertion is looser than necessary. One duplication creates a future drift
risk. No iron law violations.

## Iron Law Violations

None.

## Issues Found

### Critical

None.

### Warnings

- [ ] **Line 123 — Broad regex on rejection reason** (`reason =~ ~r/http|loopback|localhost|secure/i`).
  The actual error message is `"plaintext http is only allowed for a loopback host (localhost); use
  https for remote hosts"`. The regex passes with any one of four alternatives — a future message
  rewrite could still satisfy the regex while no longer expressing the loopback contract. A literal
  substring check such as `reason =~ "loopback"` or `reason =~ "plaintext http"` pins the intent
  more precisely without being brittle. The `base_url` and `iam_url` rejection tests (lines 140–148)
  omit a `reason` assertion entirely; adding one (even just a substring) would give the same
  protection.

- [ ] **Lines 92–99 — `@url_attrs` duplicates `@valid_attrs` verbatim**. Module attributes in
  ExUnit are module-wide; there is no scope shadowing here (the names differ, so the `"new/1"`
  describe's `@valid_attrs` is unaffected). The duplication risk is forward-only: if `@valid_attrs`
  is updated (e.g. a new required field added), `@url_attrs` must be updated in lockstep or tests
  silently diverge. Prefer referencing `@valid_attrs` directly inside the new describe block, or
  define a single shared module attribute.

### Suggestions

- [ ] **Missing edge case — userinfo/`@`-host bypass** (`http://localhost@evil.com`). Elixir's
  `URI.new/1` correctly parses this as `host: "evil.com"`, `userinfo: "localhost"`, so the
  implementation already rejects it. There is no test that pins this behaviour. Add one test case
  asserting `{:error, %ConfigError{field: :portal_url}}` for this URL to make the security
  contract explicit and regression-proof.

- [ ] **Missing edge case — `localhost` subdomain trick** (`http://localhost.attacker.com`). The
  implementation rejects it correctly (`host: "localhost.attacker.com"` is not in
  `@loopback_hosts`). Pin it with an explicit test asserting rejection on all three URL fields for
  the same reason as above.

- [ ] **IPv6 bracket stripping — verify behaviour under Elixir 1.18**. The test at line 110
  passes `"http://[::1]:8080"` and expects acceptance. `@loopback_hosts` contains `"::1"` (no
  brackets). Elixir 1.18's `URI.new/1` strips brackets from IPv6 hosts (storing `"::1"`), so the
  test should pass. Confirm with `mix test test/qx/hardware/config_test.exs:105` if the green
  suite count of 926 has not yet been verified against the actual test runner.

## Async / Flakiness

`async: true` retained at line 2, no global state, no `Process.sleep`, no Mox — clean.

## Coverage vs Contract

| Contract clause | Covered |
|---|---|
| https to remote host accepted | Yes (line 101) |
| http to `localhost` accepted | Yes (line 107–108) |
| http to `127.0.0.1` accepted | Yes (line 109) |
| http to `[::1]` accepted | Yes (line 110) |
| http to remote host rejected (portal_url) | Yes (line 117) |
| http to remote host rejected (base_url) | Yes (line 140) |
| http to remote host rejected (iam_url) | Yes (line 145) |
| nil base_url / iam_url skipped | Yes (line 127) |
| loopback loopback for base_url / iam_url | Yes (line 131) |
| Non-http(s) scheme on all three fields | Yes (line 159) |
| Empty / malformed host | Yes (line 170) |
| userinfo `@`-host bypass | **Missing** (Suggestion) |
| `localhost.*` subdomain trick | **Missing** (Suggestion) |

The existing `portal_test.exs` (line 15) and `ibm_test.exs` (lines 17, 23–24) using
`http://localhost` serve as the live-integration no-regression guard for the loopback allowlist;
no additional cross-file test is needed.
