# Qx Security Audit

Scope: `lib/qx/hardware/**`, `lib/qx/export/openqasm/**`, `lib/qx/errors.ex`,
`lib/qx/validation.ex`, `config/**`, plus a global grep for atom-table and
file-I/O traps. Manual review (no `sobelow`).

Date: 2026-06-14.

---

## Findings

### 1. (MED) Plaintext-HTTP portal URL accepted
- File: `lib/qx/hardware/config.ex:237`
- Exploit: a misconfigured `QX_PORTAL_URL=http://...` (or compromised env)
  sends the bearer portal token over cleartext, allowing on-path
  capture and reuse against qxportal.
- Fix: tighten `validate_portal_url/1` to require `scheme == "https"`
  (or gate `http://` behind an explicit `allow_insecure: true` opt
  used only in dev/test).

### 2. (MED) `:base_url` / `:iam_url` test-hook overrides accept any scheme
- File: `lib/qx/hardware/config.ex:42, 112-113`
- Exploit: although intended as test hooks, both fields are accepted by
  `Config.new/1` from any caller with no validation; setting
  `base_url: "http://attacker/api/v1"` would route the Bearer IAM token
  to an attacker host.
- Fix: validate both URLs with the same scheme/`https`-only check, or
  gate them behind a `Mix.env() == :test` guard / private constructor.

### 3. (MED) Untyped `ArgumentError` leaks from QASM float parsing
- File: `lib/qx/export/openqasm/parser.ex:568`
  (`parts |> Enum.join("") |> String.to_float()`)
- Exploit: a hostile QASM literal such as `1e9999` raises a raw
  `ArgumentError` from the parser layer instead of the typed
  `Qx.QasmParseError`, breaking the documented API contract (Iron Law
  #7) and surfacing internal stack frames to the caller.
- Fix: wrap with `case Float.parse/1` (or rescue `ArgumentError` →
  `Qx.QasmParseError.exception(reason: "invalid numeric literal …")`).

### 4. (MED) Parser expression recursion is unbounded within 1 MB cap
- File: `lib/qx/export/openqasm/parser.ex:180-243`
  (`expr_ref = parsec(:expression)` recursion through `primary` /
  parenthesised expressions)
- Exploit: a 1 MB blob of `((((((…))))))` walks roughly 0.5 M nested
  parser frames; while nimble_parsec is largely tail-recursive, deeply
  nested `parsec/1` calls grow the BEAM call stack and can `:enomem` or
  crash the calling process before hitting a parse error.
- Fix: add an explicit depth counter to the parser context (or cap
  open-paren count via a pre-scan pass) and reject beyond e.g. 256
  levels with a typed `Qx.QasmParseError`.

### 5. (LOW) HTTP error tuples surface raw response bodies
- Files: `lib/qx/hardware/ibm.ex:104-105, 464-465`,
  `lib/qx/hardware/portal.ex:163-164`
- Exploit: `{:error, {:http, status, body}}` includes the decoded
  response body verbatim; if a caller logs the error tuple, any field
  the upstream echoes back (e.g. provider-side debug headers, request
  context) lands in logs. The body itself never contains the IBM key
  / portal token (they go via headers / form body), so the impact is
  caller-controlled rather than a guaranteed leak — but the surface is
  unbounded and grows with future IBM API changes.
- Fix: redact body to a short snippet (`String.slice/3 0..512`) or
  drop it entirely in error tuples; let detailed bodies live in
  `Logger.debug` instead.

### 6. (LOW) IAM request body carries unredacted apikey
- File: `lib/qx/hardware/ibm.ex:76-93`
- Exploit: the form body sent to `iam.cloud.ibm.com/identity/token`
  contains the raw `apikey=<plaintext>`. `Req` does not log request
  bodies by default, so this is latent — but if a user globally
  enables Req tracing / `Req.Steps.put_default_options/1`, the
  unredacted body becomes visible.
- Fix: document a "do not enable Req debug logging on this client"
  invariant, or pass a `:redactor` step that masks `apikey=` for the
  IAM client.

### 7. (LOW) `portal_url` host not allowlisted — open-egress at construction
- File: `lib/qx/hardware/portal.ex:104-105, 121-122`
  (`String.trim_trailing(base_url, "/") <> path`)
- Exploit: any caller that lets a user-controllable string reach
  `Config.new(portal_url: …)` can point Qx at a host of their
  choosing; the token then leaks to that host. The library is intended
  for trusted use, so this is a defence-in-depth note rather than a
  direct hole.
- Fix: validate `portal_url` host against an allowlist (qxquantum.com,
  localhost for dev) or require `host =~ ~r/\.qxquantum\.com\z/`.

### 8. (LOW) `from_qasm_function/1` produces source for `Code.compile_string/1`
- File: `lib/qx/export/openqasm/codegen.ex:54-74` &
  `lib/qx/export/openqasm.ex:432`
- Exploit: codegen output is documented as `Code.compile_string/1`
  input. Identifier shape is enforced by both the parser charset
  (`[A-Za-z_][A-Za-z0-9_]*`) and `validate_identifier/1` — currently
  safe. The risk is *downstream*: any future caller (qxportal,
  livebook integration) that compiles the source without isolation
  (sandbox / restricted module) lets a malicious QASM author run
  arbitrary helper-named functions in the host. The grammar is tight
  today; the contract that downstreams must compile in a fresh
  isolated module is not enforced here.
- Fix: in `from_qasm_function/1`, wrap the emitted `def …` in a
  `defmodule Qx.Generated.<random> do … end` envelope before returning
  it, so callers cannot accidentally inject the bare `def` into an
  existing module (defence-in-depth).

### 9. (INFO) Atom-table exhaustion — no findings
- `String.to_atom/1` is not used anywhere in `lib/`; references are
  documentation only (`lib/qx/hardware/ibm.ex:37`,
  `lib/qx/export/openqasm/expr.ex:14,50`,
  `lib/qx/export/openqasm/lowering.ex:28`). Status atoms,
  gate-name dispatch, and Portal field allow-listing all use literal
  maps. **Pass.**

### 10. (INFO) File-system safety — no findings
- File I/O in `lib/` is doc-example `File.write!` calls only
  (`lib/qx.ex:52`, `lib/qx/draw.ex:53,280`,
  `lib/qx/draw/svg/circuit.ex:94`, `lib/qx/export/openqasm.ex:77`).
  None take a user-supplied path; none call `File.read*` or
  `Path.expand` on caller input. **Pass.**

### 11. (INFO) Secret redaction in `Inspect`
- File: `lib/qx/hardware/config.ex:98`
- `@derive {Inspect, except: [:portal_token, :ibm_api_key, :ibm_crn,
  :access_token]}` correctly redacts the four sensitive fields from
  any `inspect/1`, `Logger`, or struct print. Note that
  `:token_expires_at`, `:iam_url`, `:base_url` are *not* redacted —
  that's appropriate. **Pass.**

### 12. (INFO) Hex audit / hardcoded secrets
- `mix hex.audit` → "No retired packages found".
- No `.env*` files in the repo; `.gitignore` excludes `/_build`,
  `/deps`, archives, package tarballs.
- `rg` for `ibm.*token|api.*key|secret|bearer` finds only
  documentation, struct field names, and the literal `Bearer ` prefix
  on the `authorization` header. No hardcoded credentials.
- `mix.lock` versions (req 0.5.18, jason 1.4.5, nimble_parsec 1.4.2,
  nx 0.10.0, complex 0.6.0): no known CVEs at audit cutoff.

### 13. (INFO) Req TLS posture
- No `verify: :verify_none`, no `transport_opts` overrides anywhere in
  `lib/`. Req's defaults (`:public_key.cacerts_get/0`,
  `verify: :verify_peer`, OTP 26+ defaults) apply. Both clients use
  `retry: false` (no silent retries that would amplify timing leaks)
  and explicit `receive_timeout` (10s IAM / portal-GET, 30s portal-POST
  / IBM-API). **Pass.**

### 14. (INFO) Status-callback safety
- `Qx.Hardware` `:on_status` events are documented atoms with
  job-id binaries only; no token / config struct fragments. The
  doc-example `Logger.debug(inspect(event))` in
  `lib/qx/hardware.ex:33` is safe — events carry no secrets.

---

## `mix hex.audit` raw tail

```
No retired packages found
```

## Hardcoded-secret grep raw tail

(No real secrets — all hits are documentation, doctest examples, struct
field names, or the literal `"Bearer "` prefix used to build the
`Authorization` header. Full grep ran with `-g '!_build' -g '!deps' -g
'!doc' -g '!.git' -g '!coveralls.json'`; key hits below.)

```
lib/qx/hardware/ibm.ex:49:  @iam_url_default "https://iam.cloud.ibm.com/identity/token"
lib/qx/hardware/ibm.ex:79:        "apikey" => api_key,
lib/qx/hardware/ibm.ex:423:      {"authorization", "Bearer " <> (config.access_token || "")},
lib/qx/hardware/portal.ex:111:          {"authorization", "Bearer " <> token},
lib/qx/hardware/portal.ex:129:          {"authorization", "Bearer " <> token},
lib/qx/hardware/config.ex:194:      ibm_api_key: System.get_env("QX_IBM_API_KEY"),
README.md:528:export QX_IBM_API_KEY=<your IBM Cloud API key>
```

---

## Security score

| Category               | Weight | Score | Weighted |
|------------------------|--------|-------|----------|
| Secret handling        |   25   |  21   |   21     |
| HTTPS / TLS            |   15   |  11   |   11     |
| Atom-table exhaustion  |   10   |  10   |   10     |
| QASM parser robustness |   20   |  14   |   14     |
| Path / file safety     |   10   |  10   |   10     |
| Error leakage          |   10   |   8   |    8     |
| Dependency CVEs        |   10   |  10   |   10     |
| **Total**              | **100**|       | **84**   |

**Security score: 84 / 100.**

Top fixes (priority order): tighten `portal_url` to `https`-only (#1),
validate / gate the `base_url` / `iam_url` test hooks (#2), wrap QASM
float parsing in a typed error (#3), add a parenthesis-depth cap to the
expression parser (#4). Redacting / capping HTTP-error response bodies
(#5) and namespacing codegen output inside a `defmodule` shell (#8) are
defence-in-depth.
