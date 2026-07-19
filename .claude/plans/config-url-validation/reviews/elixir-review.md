# Code Review: config-url-validation — Elixir Idioms

## Summary

- **Status**: ✅ Approved (with one suggestion to improve)
- **Issues Found**: 2 (both Suggestions; no Critical or Warning-level findings)

---

## Suggestions

### 1. `validate_url_host/3` "http" clause: prefer multi-clause with guard over `if`

**Location**: `lib/qx/hardware/config.ex`, lines 275–284

**Severity**: SUGGESTION

The `"http"` clause uses an `if` to branch on `host in @loopback_hosts`. The rest
of the module uses multi-clause functions with guards consistently (`validate_region`,
`validate_optimization_level`, `validate_shots`). A guard-split form is more idiomatic
and avoids branching inside the body:

```elixir
# Current
defp validate_url_host(field, "http", host) do
  if host in @loopback_hosts do
    :ok
  else
    url_error(field, "plaintext http is only allowed …")
  end
end

# Suggested — two clauses, guard replaces if
defp validate_url_host(_field, "http", host) when host in @loopback_hosts, do: :ok

defp validate_url_host(field, "http", _host) do
  url_error(field, "plaintext http is only allowed …")
end
```

`@loopback_hosts` is a compile-time list of binaries, so it is valid in a guard via
`in`. No compile-order concern — the attribute is defined at line 245, before its use.

---

### 2. Error reason string "(localhost)" understates the allowed loopback set

**Location**: `lib/qx/hardware/config.ex`, line 280

**Severity**: SUGGESTION

The message reads:

> "plaintext http is only allowed for a loopback host (localhost); use https for remote hosts"

The parenthetical `(localhost)` implies `localhost` is the sole accepted value, but
`127.0.0.1` and `::1` are also permitted by `@loopback_hosts`. A caller seeing the
error message for `http://127.0.0.1:8080` on a non-loopback interface would be confused
(the host _is_ listed in the parenthetical by string name, but isn't mentioned).

Consider:

```
"plaintext http is only allowed for loopback hosts (localhost, 127.0.0.1, ::1); use https"
```

or drop the parenthetical entirely and rely on the field name in the exception for
diagnosis.

---

## Confirmed-Clean Points

Listed here because the prompt asked about these explicitly; no action required.

- **`validate_url_host/3` clause ordering** — correct. The `host in [nil, ""]` guard
  fires first for any nil/empty host regardless of scheme. The `"https"` clause accepts
  all non-nil hosts. The `"http"` clause handles the loopback check. Caller
  (`validate_url/2`) only invokes `validate_url_host/3` when `scheme in ["http", "https"]`,
  so there is no unmatched fall-through.

- **`URI.new(nil)` not reachable** — `check_required/1` runs before
  `validate_portal_url/1` in the `with` chain and guarantees `portal_url` is a
  non-empty binary. `validate_optional_url/2`'s nil-clause guards `base_url` and
  `iam_url`. `URI.new` will never receive a non-binary value on any path.

- **`@loopback_hosts` mid-module placement** — fine. Elixir module attributes are
  sequential at compile time; the attribute is set at line 245 before every function
  that reads it. Using it inside a function body (not a guard) carries no compile-order
  restriction. The `@ibm_region_allowlist` at line 147 is used in a guard at line 310
  (a stronger requirement) and also works correctly.

- **`validate_optional_url(_field, nil)` clause** — idiomatic. Single-clause guard for
  the nil case, delegation for everything else, no duplication.

- **IPv6 `"::1"` in `@loopback_hosts`** — `URI.new("http://[::1]:8080")` sets
  `%URI{host: "::1"}` (RFC 3986 strips the brackets), matching the stored string.
  Test coverage at line 111 confirms this path.

- **No dead code** — the old `validate_portal_url/1` is now a single-line delegation
  to `validate_url/2`; no orphaned branches remain.

- **`url_error/2` return shape** — returns `{:error, ConfigError.exception(...)}`,
  which is the correct tagged-tuple shape for the `with` chain in `new/1`. Name is
  private and consistent with the rest of the module's helper naming.
