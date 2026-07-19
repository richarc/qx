---
module: "Qx.Hardware.Config"
date: "2026-06-30"
problem_type: security_issue
component: configuration
symptoms:
  - "`Qx.Hardware.Config` accepted plaintext `http://` to ANY host for `portal_url` — `validate_portal_url/1` returned `:ok` for `scheme in [\"http\", \"https\"]`, so the portal bearer token would be sent in cleartext to a remote host"
  - "`:base_url` / `:iam_url` test-hook overrides were stored raw with NO validation; `base_url: \"http://attacker/api/v1\"` would route IBM IAM token exchange to an attacker host"
  - "A naive fix (require `https` everywhere) broke the suite: the hardware tests use `http://localhost:<port>` Bypass mock servers for all three URLs"
root_cause: "URL fields that carry credentials (a bearer token, an IAM token-exchange endpoint) were validated only for scheme membership, not for the insecure scheme + remote host COMBINATION. Plaintext http is only safe to a loopback host; to any other host it leaks the secret. The validator must distinguish loopback from remote rather than blanket-allow or blanket-require-https."
severity: high
iron_law_number: 7
tags: [security, url-validation, loopback-allowlist, ssrf, bearer-token, https, uri-parsing, config-validation, fail-closed]
related_solutions: []
---

# Loopback-allowlist URL validation (secure-by-default, mock-friendly)

## Symptoms

- `Qx.Hardware.Config.new/1` accepted `portal_url: "http://anything"` — the
  portal bearer token would travel in cleartext to a remote host.
- `:base_url` / `:iam_url` (IBM IAM + API endpoint overrides) were unvalidated,
  so a remote `http` value could redirect token exchange to an attacker.
- Blanket "require `https`" was a non-starter: `test/qx/hardware/{portal,ibm}_test.exs`
  and `hardware_test.exs` legitimately use `http://localhost:<port>` Bypass mocks
  (and so does local dev).

## Investigation

1. **Blanket https-only** — rejected. It would break ~77 hardware tests and
   real local-mock workflows.
2. **Blanket http+https (status quo)** — that *is* the hole.
3. **Root cause** — the risk is `http` to a NON-loopback host. `http` to
   `localhost`/`127.0.0.1`/`::1` is fine (the traffic never leaves the box).
   So validate the scheme+host *combination*, not the scheme alone.

## Root Cause

Credential-bearing URLs were validated for scheme membership only. Plaintext
`http` is safe to loopback but leaks secrets to any remote host. The fix is a
**loopback allowlist**: allow `http` only when the host is loopback, require
`https` otherwise.

## Solution

One shared validator, applied to every credential URL, returning the typed
`Qx.Hardware.ConfigError` (Iron Law #7) so it slots into the `Config.new/1`
`with` chain. Match the host **case-insensitively** (hostnames are
case-insensitive, RFC 3986 §6.2.2.1) and **exactly** against the allowlist
(string equality is fail-closed: octal/hex/decimal IP encodings, `localhost@evil.com`
userinfo tricks, `localhost.attacker.com` suffixes all fail to match and are rejected).

```elixir
@loopback_hosts ~w(localhost 127.0.0.1 ::1)

defp validate_portal_url(url), do: validate_url(:portal_url, url)

defp validate_optional_url(_field, nil), do: :ok
defp validate_optional_url(field, url), do: validate_url(field, url)

defp validate_url(field, url) do
  case URI.new(url) do
    {:ok, %URI{scheme: scheme, host: host}} when scheme in ["http", "https"] ->
      validate_url_host(field, scheme, normalize_host(host))

    {:ok, %URI{}} -> url_error(field, ~s(scheme must be "http" or "https"))
    {:error, _}   -> url_error(field, "is not a valid URI")
  end
end

# hostnames are case-insensitive; nil-safe so the empty/nil-host clause handles it
defp normalize_host(host) when is_binary(host), do: String.downcase(host)
defp normalize_host(host), do: host

defp validate_url_host(field, _scheme, host) when host in [nil, ""],
  do: url_error(field, "must include a host")

defp validate_url_host(_field, "https", _host), do: :ok
defp validate_url_host(_field, "http", host) when host in @loopback_hosts, do: :ok

defp validate_url_host(field, "http", _host),
  do: url_error(field, "plaintext http is only allowed for a loopback host (localhost, 127.0.0.1, ::1); use https for remote hosts")

defp url_error(field, reason),
  do: {:error, ConfigError.exception(field: field, reason: reason)}
```

Wire into the `with` chain (optional fields validate only when non-nil):

```elixir
with :ok <- check_required(attrs),
     :ok <- validate_portal_url(attrs[:portal_url]),
     :ok <- validate_optional_url(:base_url, attrs[:base_url]),
     :ok <- validate_optional_url(:iam_url, attrs[:iam_url]),
     ... do
```

### Why fail-closed exact match beats parse-and-compare

`http://2130706433` / `http://0177.0.0.1` / `http://localhost@evil.com` /
`http://127.0.0.1.attacker.com` are NOT string-equal to any allowlist entry, so
they are rejected. A "smart" parser that canonicalises IPs would have to get
*every* SSRF encoding right; exact match on the (downcased) host is conservative
and safe. The only legitimate `http` use is a loopback mock, which matches.

### Files Changed

- `lib/qx/hardware/config.ex` — shared `validate_url/2` + loopback allowlist; `portal_url` delegates; `base_url`/`iam_url` wired into `new/1`
- `test/qx/hardware/config_test.exs` — `describe "URL/host validation (loopback allowlist)"`, incl. pinned bypass look-alikes
- `CHANGELOG.md` — `### Security` (behaviour change: remote-`http` now raises)

## Prevention

- [ ] Iron Law? No — too specific. But the principle (validate scheme+host
      combination for credential URLs) is worth remembering.
- [x] Test pattern: pin the rejected look-alikes (`localhost@evil.com`,
      `localhost.attacker.com`, IP encodings) so the contract is explicit.
- Specific guidance:
  - **Any config URL that carries a secret** (token, key, token-exchange
    endpoint) must reject plaintext `http` to remote hosts. Use a loopback
    allowlist, not blanket https-only (keeps local mocks working) and not
    blanket http+https (the hole).
  - Match the host **case-insensitively** (`String.downcase`) and **exactly**
    (`host in @loopback_hosts`) — exact match is fail-closed against SSRF-style
    encodings.
  - Validate at construction time, route through the typed error, and remember
    `URI.new/1` strips userinfo (`a@b` → host `b`) and IPv6 brackets (`[::1]` →
    `::1`).

## Related

- Iron Law #7: public functions raise typed `Qx.*Error` — `ConfigError` here.
- ROADMAP v0.8.2 (Security & Hardening), plan: config-url-validation.
