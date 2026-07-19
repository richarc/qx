# Scratchpad — config-url-validation

## Decisions

- **Loopback allowlist** (not strict https-only). Allow `http` only for
  `localhost`/`127.0.0.1`/`::1`; require `https` for any remote host. Chosen
  because the suite uses `http://localhost:<port>` Bypass mocks for all three
  URLs, and local dev does too. Strict https-only would break them.
- **Apply to all three URLs** via one shared `validate_url/2` helper:
  `portal_url` (always), `base_url`/`iam_url` (only when non-nil; default nil).
- **Typed errors only** (Iron Law #7): `Qx.Hardware.ConfigError` with `field:`.
  Validators return `:ok | {:error, ConfigError}` to fit the `Config.new/1`
  `with` chain (config.ex:154-158).
- **Behaviour change, no bump.** Remote-`http` configs now raise. CHANGELOG
  `### Security` note. v0.8.2 is the security/hardening patch.

## Verified facts

- `validate_portal_url/1` at config.ex:235 currently accepts both http+https.
- `base_url`/`iam_url`: unvalidated raw strings, default nil (112-113), typed
  `String.t() | nil` (129-130).
- `ConfigError` is `lib/qx/errors.ex:370` (`field:` + `reason:`).
- `config_test.exs`: `async: true`, `doctest`, describe "new/1"/"new!/1"/inspect.
- Tests using `http://localhost` that MUST stay green: portal_test.exs:15,
  ibm_test.exs:17/23-24, hardware_test.exs:23,66.

## Open questions (resolve at /phx:work)

- `*.localhost` allowed? reject userinfo? empty host invalid? (lean yes/yes/yes)

## Dead ends

- Strict https-only — rejected (breaks the Bypass mock tests + local dev).
