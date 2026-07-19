# Harden URL/host validation in `Qx.Hardware.Config`

**Slug:** `config-url-validation`
**Branch:** `fix/config-url-validation`
**ROADMAP:** qx v0.8.2 (Security & Hardening), Group A — two `security MED` items.
**Type:** Security hardening. Behaviour change (previously-accepted remote-`http`
configs now raise). No signature change, no new dependency, no version bump.

## Problem

Two related holes in `lib/qx/hardware/config.ex`:

1. **`portal_url` accepts plaintext `http` to any host.** `validate_portal_url/1`
   (config.ex:235) returns `:ok` for `scheme in ["http", "https"]`. The portal
   URL carries the portal **bearer token**, so `http://remote-host` leaks it in
   cleartext (audit: security MED).
2. **`:base_url` / `:iam_url` test hooks are unvalidated.** They default `nil`
   (config.ex:112-113) and are stored raw. `base_url: "http://attacker/api/v1"`
   routes IBM IAM token exchange to an attacker host (audit: security MED).

## Decided constraints (do not re-litigate)

- **Design = loopback allowlist.** A shared validator: parse the URI; require
  scheme `http` or `https`; if `http`, the host MUST be loopback
  (`localhost`, `127.0.0.1`, `::1`) else raise; `https` allowed for any host.
  This closes the plaintext-token-to-remote-host hole AND keeps
  `http://localhost:<port>` mock-server configs valid. (Rejected: strict
  `https`-only — it would break the Bypass-based hardware tests and real local
  dev.)
- **DO NOT break the existing tests.** They use `http://localhost:<port>` for
  all three URLs and must pass UNCHANGED:
  - `test/qx/hardware/portal_test.exs:15` (`portal_url`)
  - `test/qx/hardware/ibm_test.exs:17,23-24` (`portal_url`, `iam_url`, `base_url`)
  - `test/qx/hardware_test.exs:23,66` (`portal_url`)
- **Iron Law #7:** raise the existing typed `Qx.Hardware.ConfigError`
  (`lib/qx/errors.ex:370`, `field:` + `reason:`), never a raw error. Each
  validator returns `:ok | {:error, ConfigError.t()}` to fit the `with` chain
  in `Config.new/1` (config.ex:154-158).
- **base_url/iam_url validate only when non-nil** (they default `nil`).
- **CHANGELOG:** `### Security` note under `[Unreleased]` (behaviour change:
  remote-`http` URLs now rejected).

## Validation flow (current)

`Config.new/1` (config.ex:151) runs:
```elixir
with :ok <- check_required(attrs),
     :ok <- validate_portal_url(attrs[:portal_url]),
     :ok <- validate_optimization_level(...),
     :ok <- validate_shots(...),
     :ok <- validate_region(attrs[:ibm_region]) do
  ...
end   # {:error, error} -> raise error  (via new!/1)
```
We extend this chain with `:base_url` / `:iam_url` clauses and route all three
URL checks through one shared helper.

---

## Phase 1 — Tests first (TDD; test-guard hook needs approval)

> The PreToolUse hook blocks editing `test/qx/hardware/config_test.exs`. Surface
> the new `describe` block at `/phx:work` time, get approval, confirm RED, then
> implement.

- [x] [P1-T1] Added `describe "URL/host validation (loopback allowlist)"` to config_test.exs (10 tests). Block added to
      `test/qx/hardware/config_test.exs` covering, via `Config.new/1` (assert the
      `{:error, %ConfigError{field: ...}}` or the `new!/1` raise):
  - [ ] `portal_url` `https://remote` → ok; `http://localhost:4000` → ok;
        `http://localhost` → ok; `http://remote-host` → `{:error, field: :portal_url}`;
        `127.0.0.1`/`::1` over `http` → ok.
  - [ ] `base_url` / `iam_url`: `nil` (default) → ok; `http://localhost:p` → ok;
        `http://attacker/api/v1` → `{:error, field: :base_url}` / `:iam_url`.
  - [ ] Non-http(s) scheme (`ftp://...`, `ws://...`) → error; malformed URI → error;
        `https` with no host → error (decide: treat empty host as invalid).
  - [ ] A sanity assertion mirroring the existing `http://localhost:<port>`
        hardware-test usage still validates (guards the no-regression promise).
- [x] [P1-T2] `mix test test/qx/hardware/config_test.exs` — RED confirmed: 5
      failures (remote-http portal_url, base_url/iam_url plaintext-http +
      unvalidated scheme, `http://` empty-host). Accept-cases already green.

## Phase 2 — Implement the shared validator (`lib/qx/hardware/config.ex`)

- [x] [P2-T1] Add a private `validate_url(field, url)` helper (loopback allowlist):
      `URI.new(url)` → require `scheme in ["http","https"]`; if `http`, require
      `host in @loopback_hosts` (`~w(localhost 127.0.0.1 ::1)`, module attr);
      else `{:error, ConfigError.exception(field: field, reason: "...")}`. Return
      `:ok | {:error, ConfigError.t()}`. Distinct `reason:` strings for
      bad-scheme, insecure-remote-http, and malformed-URI (keep them short and
      technical). Consider `*.localhost` and reject empty/`nil`-host on `http`.
- [x] [P2-T2] Rewrite `validate_portal_url/1` to delegate to
      `validate_url(:portal_url, url)` (drops the "accept any http" branch).
- [x] [P2-T3] Add `validate_optional_url(field, url)` (or inline `nil` guard):
      `nil -> :ok`; else `validate_url(field, url)`. Wire `:base_url` and
      `:iam_url` into the `Config.new/1` `with` chain (after `validate_portal_url`).
- [x] [P2-T4] Update the `## Options` doc for `:base_url` / `:iam_url` (and
      `portal_url`) to state the loopback-allowlist rule. Add/adjust any doctest
      to match (the moduledoc already shows a `ConfigError` doctest at ~line 58).
- [x] [P2-T5] `mix test test/qx/hardware/config_test.exs` — confirm GREEN.

## Phase 3 — CHANGELOG + ROADMAP

- [x] [P3-T1] `CHANGELOG.md` `[Unreleased]` → `### Security`: `Qx.Hardware.Config`
      now rejects plaintext `http://` URLs to non-loopback hosts for `portal_url`,
      `base_url`, and `iam_url` (these carry bearer tokens / route token exchange).
      `http://localhost` stays valid for local mocks. Behaviour change: a config
      with a remote `http` URL now raises `Qx.Hardware.ConfigError`.
- [x] [P3-T2] Tick the two v0.8.2 ROADMAP items (reject plaintext `http` for
      `QX_PORTAL_URL`; validate `:base_url`/`:iam_url` test-hook overrides).

## Verification (mandatory gate)

- [x] `mix compile --warnings-as-errors` — clean.
- [x] `mix format --check-formatted` — clean.
- [x] `mix credo --strict` — 0 issues.
- [x] `mix test` — full suite green at the unchanged counts (**242 doctests +
      916 tests**, plus the new config cases). The existing `http://localhost`
      hardware tests (`portal_test`, `ibm_test`, `hardware_test`) MUST pass
      unchanged — they are the no-regression guard.

## Out of scope

- The other v0.8.2 groups (IBM client hardening, OpenQASM hardening, deps).
- Any change to how the URLs are *used* (only validation at config-build time).

## Open decision (resolve at /phx:work)

- **Loopback allowlist vs strict https-only** — recommended: loopback allowlist
  (keeps tests + local dev working). Confirm before implementing.
- Edge cases: allow `*.localhost`? reject userinfo (`http://user:pass@...`)?
  treat empty host as invalid? (Lean yes / yes / yes.)

## Done = merge-ready

All phases checked, verification green, `/phx:review` PASS (or findings
triaged). Squash-merge, tick the two ROADMAP items, push `main`.
