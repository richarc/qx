# Iron Law Violations Report

## Summary

- Files scanned: 3 (`lib/qx/hardware/config.ex`, `lib/qx/errors.ex`, `CHANGELOG.md`)
- Iron Laws checked: 4 of 22 (scoped to the laws listed in the prompt)
- Violations found: 0 critical, 0 high, 1 medium (SUGGESTION)

---

## Medium Violations (SUGGESTION)

### [#6] Breaking public API — version bump assessment

- **File**: `mix.exs:7` (version `0.8.1`) + `CHANGELOG.md` (`[Unreleased]` block)
- **Confidence**: REVIEW
- **Finding**: `Qx.Hardware.Config` is on the declared public surface. The new
  loopback-allowlist validation rejects input (remote `http://` URLs) that was
  previously accepted. That is a behaviour change on a public API. A CHANGELOG
  entry under `### Security` exists and documents the change accurately. No
  version bump has been applied yet — the change is in `[Unreleased]` and
  `mix.exs` still reads `0.8.1`.

  **Is no version bump acceptable?** Pre-1.0 semantics mean there is no
  "major-version bump" in the 0.x range in the way SemVer describes for 1.x+.
  Iron Law #6 says breaking changes require "a CHANGELOG entry and a
  major-version bump (SemVer)." For a pre-1.0 library the pragmatic equivalent
  is a **minor** bump (0.8 → 0.9) for breaking changes, or at minimum a patch
  bump (0.8.1 → 0.8.2) for security hardening that is strictly tighter
  (no previously-valid *correct* usage breaks — only configs that were
  mis-configured for security). The ROADMAP schedules this as v0.8.2.

  **Recommendation:** 0.8.2 (patch) is defensible if framed as a security fix
  that tightens an overly-permissive validation. 0.9.0 (minor) would be the
  stricter SemVer reading for any public-API behaviour change. Either is
  consistent with Iron Law #6 as long as the version bump lands before the tag.
  The current state — CHANGELOG entry present, version bump deferred to
  release-time — is acceptable for an `[Unreleased]` diff.
- **Fix**: When cutting the release, bump to at minimum `0.8.2` in `mix.exs`.
  Consider `0.9.0` if you prefer the strict SemVer reading for a public-API
  behaviour change. Do not tag without the bump.

---

## Passing Checks (summary only)

Checked 4 Iron Laws: #1, #6, #7, plus signature-additivity. 1 medium
(SUGGESTION) finding on version-bump deferral. All other checks clean.

### #7 — Typed errors: CLEAN (DEFINITE)

Every error path in `validate_url/2` and all other validators returns
`{:error, ConfigError.exception(field: field, reason: reason)}`. The
`{:error, _} -> url_error(field, "is not a valid URI")` branch explicitly
catches `URI.new` parse errors and converts them — no raw `URI` error or
`ArgumentError` crosses the public boundary. `new!/1` raises the
`ConfigError` struct directly via `raise error`.

### #1 — No String.to_atom on user input: CLEAN (DEFINITE)

No `String.to_atom/1` call anywhere in `config.ex`. The field atoms
(`:portal_url`, `:ibm_region`, etc.) are compile-time literals in
`@required_string_fields` and `@loopback_hosts` module attributes; neither
the URL string nor the host value is ever converted to an atom.

### Signature additivity: CLEAN (DEFINITE)

`new/1` and `new!/1` specs are unchanged. The new URL validators are
inserted as additional `with` arms before the existing `optimize_level`,
`shots`, and `region` checks. No public function signature was altered.
