# Review: mint-advisories-nov

**Date:** 2026-11-14
**Branch:** `fix/mint-advisories-nov` vs `main` (uncommitted)
**Verdict:** PASS, pending the human's merge authorization

Lockfile-only change: mint 1.9.3 → 1.11.0, hpax 1.0.4 → 1.1.0, plus
CHANGELOG and ROADMAP text. Three agents ran (elixir, testing,
iron-laws); none ran code.

## Findings and resolution

| # | Source | Finding | Outcome |
|---|---|---|---|
| 1 | elixir (warning) | "All six fixed by 1.10.2" doubted: mint's own changelog has no 1.10.2 and puts three fixes in 1.11.0. | Checked. hex.pm lists 1.10.2 (2026-09-29, one day after 1.11.0: a backport) and the OSV records give `fixed: 1.10.2` for those three. Wording changed to cite the advisories and say 1.11.0 has the fixes too. |
| 2 | elixir (inferred) | Tests probably stub with `Req.Test` and bypass mint. | Refuted by the testing agent, which read the tests: `ibm_test.exs` and `portal_test.exs` use Bypass, a real localhost listener, so requests go through Req → Finch → mint. |
| 3 | testing | The suite exercises mint over cleartext HTTP/1.1 only. TLS, HTTP/2 and hpax are not covered; nor are receive timeouts or truncated bodies. | Checked TLS by hand: `Req.get!` to an https URL returned 200 with mint 1.11.0 / hpax 1.1.0 loaded. Finch's default pool is HTTP/1 only and Qx sets no `protocols`, so Qx does not use HTTP/2 or hpax at run time. Not tested: a real IBM or portal call. |

## Confirmed by the agents (read, not run)

- Only the `mint` and `hpax` lock entries changed; both are hex packages
  with checksums. `mix.exs` needs no change (`finch` requires `mint ~> 1.8`).
- Qx matches errors only as `{:error, %{reason: r}}`, never on mint
  structs, so the stricter response validation in mint 1.10/1.11 arrives
  as a network error with a new reason value.
- No Iron Law applies; no code changed.

## Checked by me

- `scripts/audit_shipped.sh`: exit 0, shipped tree clean. Remaining
  advisories are in dev/test-only packages.
- Package diffs for both upgrades scanned for shell, eval, network and
  file-write calls in added lines: none.
- compile (warnings as errors), format, credo --strict clean; `mix test`
  1633 passed.
