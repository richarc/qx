# Iron Law Violations Report

## Summary

- Files scanned: 5 (lib/qx/hardware/http.ex, lib/qx/hardware/ibm.ex, lib/qx/hardware/portal.ex, config/test.exs, test/qx/hardware/ibm_test.exs)
- Iron Laws checked: 22 of 22 (applicable subset: qx laws #1, #2, #6, #7, #10, #13, #15; plugin laws for security, Ecto, Oban, LiveView all N/A — pure library, no Phoenix/Ecto/Oban)
- Violations found: 0 (0 critical, 0 high, 0 medium)

## Key Findings

No violations found. Specific answers to the key questions raised in the prompt:

**Law #1 — No String.to_atom on caller input: CLEAN.**
`portal.ex` atomize path uses a compile-time allowlist map (`@known_keys_map`) and `Map.get/3` with a string fallback — never calls `String.to_atom/1`. IBM side keeps all job statuses as binaries throughout (`parse_job_response` preserves the string; unknown statuses surface as `{:error, {:unknown_status, status}}` with the raw binary). The test at line 281 explicitly asserts this property.

**Law #2 — No unsupervised process without runtime reason: CLEAN.**
No `GenServer`, `Agent`, or `Task` spawning in any changed file. The `:counters` usage in the test (line 468) is an Erlang atomic counter primitive, not a process.

**Law #6 — Breaking change classification: CLEAN.**
`Qx.Hardware.Ibm`, `Qx.Hardware.Portal`, and `Qx.Hardware.Http` are all `@moduledoc false` — confirmed internal, not on the declared-public surface. The error-body shape change (`{:error, {:http, status, bounded_string}}` replacing raw body) is an internal-to-internal contract change. v0.9 minor versioning is correct; no major bump required.

**Law #7 — No raw errors across the PUBLIC boundary: CLEAN.**
These internal HTTP clients return `{:error, term()}` tuples to their callers (also internal). The public surface module (`Qx.Hardware`) feeds downstream — not in scope of these changed files. Internally, error tuples are correctly typed and bounded.

**Law #10 — No String.to_atom with user input: CLEAN.** (See Law #1 above.)

**Law #15 — @external_resource for compile-time files: CLEAN.**
No `File.read!` or `File.stream!` at module level in any changed file. `Application.compile_env/3` is used correctly (not a file read).

**Law #13 — No process without runtime reason: CLEAN.**
No processes started.

**Versioning:** The `[Unreleased]` section correctly sits above `[0.8.1]`. The behaviour changes (retry strategy, error body redaction) are internal-module changes; a minor bump to 0.9.0 at release time is appropriate and sufficient.

**`config/test.exs`:** The `ibm_retry_delay: 0` compile-env override is the correct pattern to avoid Req's exponential backoff in the transient-retry test. No issue.
