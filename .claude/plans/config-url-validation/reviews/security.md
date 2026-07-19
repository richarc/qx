# Security Review: Config URL validation (loopback allowlist)

## Verdict: PASS — no allowlist bypass found

The fix correctly closes both v0.8.2 MED findings. `validate_url/2`
(`lib/qx/hardware/config.ex:256-288`) is applied to `portal_url` always
and to `base_url`/`iam_url` when non-nil, all inside `new/1`'s `with`
chain (lines 159-167), before `struct!/2`. The allowlist is **exact
string match** (`host in @loopback_hosts`, line 276) — the conservative,
correct design. It fails closed.

## Allowlist bypass analysis (the core question)

Every smuggling vector is rejected. `URI.new/1` parses `host` per
RFC 3986, and the check is exact-equality against
`~w(localhost 127.0.0.1 ::1)`:

| Input | `URI` host | Result | Why safe |
|---|---|---|---|
| `http://localhost.attacker.com` | `localhost.attacker.com` | REJECT | not equal |
| `http://localhost@evil.com` | `evil.com` (userinfo stripped) | REJECT | host is the real authority |
| `http://127.0.0.1.attacker.com` | `127.0.0.1.attacker.com` | REJECT | not equal |
| `http://2130706433` / `0x7f.0.0.1` / `0177.0.0.1` | literal string | REJECT | not equal (fail-closed; SSRF-safe here) |
| `http://[::ffff:127.0.0.1]` | `::ffff:127.0.0.1` | REJECT | not equal |
| `http://localhost.` (trailing dot) | `localhost.` | REJECT | not equal |
| `//evil.com` (scheme-relative) | scheme `nil` | REJECT | scheme guard (line 258) |
| `file://x`, `data:…`, `ws://`, `ftp://`, `gopher://` | — | REJECT | scheme not in `["http","https"]` |
| `http://` / `https://` (empty host) | `""`/`nil` | REJECT | host guard (line 269) |
| `http://[::1]:8080`, `http://localhost:4000`, `http://127.0.0.1` | loopback | ACCEPT | intended |

No decimal/octal/hex/IPv6-mapped encoding can equal a literal allowlist
string, so the conservative match is *stronger* than a parse-and-compare
IP approach for this use case. Tests at `config_test.exs:91-180` cover
the remote-http reject, loopback accept, non-http(s) reject, and
empty-host cases.

## SUGGESTIONS (non-blocking)

1. **Host case-sensitivity (correctness, fail-closed).** `URI.new/1`
   downcases the *scheme* but not the *host*, so `http://LOCALHOST` →
   host `"LOCALHOST"` → REJECT. This is safe (fails closed) but a minor
   correctness gap for a mock author who upper-cases. If you want to
   accept it, downcase host before the membership test
   (`String.downcase(host) in @loopback_hosts`). Optional — current
   behaviour is secure.

2. **Post-construction mutation bypass (informational).** Validation
   runs only in `new/1`. A caller doing `%{config | portal_url:
   "http://evil"}` or `%{config | base_url: ...}` sidesteps it
   (`ibm.ex:31,350` and `portal.ex:65,82` read these fields directly).
   This is in-app code, not external input, and the redaction test
   already relies on struct-update for `:access_token`, so it is an
   accepted internal pattern — not a vulnerability. Worth a one-line doc
   note that URL fields must only be set via `new/1`.

## Confirmed clean

- **Typed error**: raises/returns `Qx.Hardware.ConfigError` (defexception
  at `errors.ex:370-394`), never a raw `ArgumentError` — satisfies Iron
  Law #7.
- **No secret leakage in reasons**: `url_error/2` reason strings are
  static; they do not echo the URL or any token. Region/level/shots
  errors `inspect` only the offending non-secret value. Credential
  fields stay redacted via `@derive {Inspect, except: [...]}`
  (`config.ex:103`).
- **End-to-end token protection**: `portal_url` (carries portal bearer
  token, `portal.ex:65,82`) and `iam_url`/`base_url` (route IBM IAM
  exchange, `ibm.ex:31,350`) are all consumed from the validated struct;
  no construction path reaches the HTTP clients without passing `new/1`.

Checked: SQL injection, atom exhaustion, XSS, raw deserialization — N/A
to this diff (pure library, no Ecto/HTML/binary_to_term).

## Tools to run manually (no Bash in this agent)
- `mix sobelow --exit medium` (if applicable)
- `mix deps.audit` / `mix hex.audit`
