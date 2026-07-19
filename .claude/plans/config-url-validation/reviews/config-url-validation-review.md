# Review — config-url-validation

**Verdict: PASS WITH WARNINGS → ALL FINDINGS RESOLVED**

> Post-review fixes applied (re-verified green: format/compile/credo clean,
> 242 doctests + 928 tests, 0 failures; the `http://localhost` hardware tests
> still pass):
> - **F1** — error reason now lists all three loopback hosts
>   (`localhost, 127.0.0.1, ::1`).
> - **F4** — `validate_url_host/3` `http` path is a guard clause
>   (`when host in @loopback_hosts`), no inner `if`.
> - **F5** — host matching is case-insensitive via a nil-safe `normalize_host/1`
>   (`String.downcase`); `http://LOCALHOST` is now accepted (pinned by a test).
> - **F2** — test assertion tightened to `=~ "loopback"`; the `base_url`/`iam_url`
>   rejection tests now assert the reason too.
> - **F3** — dropped the duplicate `@url_attrs`; the block reuses `@valid_attrs`.
> - **F6** — added tests pinning the rejected look-alikes (`localhost@evil.com`,
>   `localhost.attacker.com`, `127.0.0.1.attacker.com`, `notlocalhost`).
>
> F7 (build-time-only doc note) and the patch-vs-minor version call left as
> noted (informational / tag-time).

**Verdict: PASS WITH WARNINGS** (no blockers; the security core is solid)

Diff: 4 files (`lib/qx/hardware/config.ex`, `test/qx/hardware/config_test.exs`,
`CHANGELOG.md`, `ROADMAP.md`). Security hardening, behaviour change, no bump.

## Requirements Coverage (source: plan.md)

**26 MET · 0 PARTIAL · 0 UNMET.** Every planned case + the implementation
shape + CHANGELOG/ROADMAP present. Scope discipline holds (no other v0.8.2
groups touched; hardware test files untouched). Suite 916→926 (+10), 0 failures.

## Security (the headline)

**PASS — no allowlist bypass.** Exact string match (`host in @loopback_hosts`)
inside `new/1` before `struct!`, fail-closed. All smuggling vectors rejected:
`localhost@evil.com` (userinfo stripped → host `evil.com`), `localhost.attacker.com`,
`127.0.0.1.attacker.com`, octal/hex/decimal IP encodings, `[::ffff:127.0.0.1]`,
`file://`/`data://`/`//evil.com`, empty/nil host. URLs are consumed only from the
validated struct (portal.ex, ibm.ex), so the bearer token + IAM exchange are
protected end-to-end. Typed `ConfigError`, no secret echoed in reasons.

## Iron Laws

Clean. #7 (typed errors): every path returns `ConfigError.exception`, `URI`
parse errors converted before the boundary. #1 (no `String.to_atom`): field
atoms are compile-time literals. Signatures additive. #6: behaviour change
correctly noted under CHANGELOG `### Security`; patch-vs-minor is a tag-time
call (v0.8.2 patch defensible for a tightening security fix).

## Findings (all non-blocking)

### Worth fixing (accuracy + quality)

- **F1 (WARNING, elixir) — misleading error reason.** "plaintext http is only
  allowed for a loopback host (localhost)" understates the set: `127.0.0.1` and
  `::1` are also allowed. A caller passing `http://127.0.0.1` sees a reason that
  only mentions `localhost`. List all three (or drop the parenthetical).
- **F2 (WARNING, test) — over-broad assertion.** `reason =~ ~r/http|loopback|localhost|secure/i`
  passes on any of four alternatives; pin it to `=~ "loopback"` (or
  `"plaintext http"`). The `base_url`/`iam_url` rejection tests assert only the
  `field:` tag, no reason at all — add a reason check.
- **F3 (WARNING, test) — `@url_attrs` duplicates `@valid_attrs` verbatim.** No
  shadowing (different names, module-wide attrs), but forward-drift risk if a
  required field is added. Reference `@valid_attrs` and drop `@url_attrs`.
- **F4 (SUGGESTION, elixir) — guard over `if`.** `validate_url_host/3`'s `http`
  clause uses an inner `if host in @loopback_hosts`; the module's idiom is a
  guard clause (`when host in @loopback_hosts -> :ok` + catch-all). `@loopback_hosts`
  is a compile-time binary list, valid in an `in` guard.
- **F5 (SUGGESTION, security) — case-insensitive host.** `http://LOCALHOST`
  fails closed (rejected). Hostnames are case-insensitive (RFC), so
  `String.downcase(host)` before the loopback check is the more-correct form.
  Secure either way; this is a robustness nicety.
- **F6 (SUGGESTION, test) — pin the bypass edge cases.** Add tests for
  `http://localhost@evil.com` and `http://localhost.attacker.com` (both already
  rejected by the impl). These document the security contract explicitly.

### Informational (no change needed)

- **F7 (security) — build-time-only validation.** Mutating a struct after
  `new/1` (`%{config | portal_url: ...}`) bypasses validation. In-app only, not
  external input; accepted pattern. A one-line doc note could help.
- **Version bump** is a tag-time decision (patch vs minor for the behaviour
  change); not actionable now.

## Bottom line

The security objective is fully met and bypass-proof. The findings are a
misleading error string (F1), a couple of test-quality tightenings (F2/F3), an
idiom nudge (F4), and two nice-to-haves (F5 case-insensitive, F6 pin the
bypasses). All small and confined to the two touched files.
