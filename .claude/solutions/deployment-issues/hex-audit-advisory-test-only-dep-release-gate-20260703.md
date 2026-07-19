---
module: "Release workflow (ci.yml / release.yml)"
date: "2026-07-03"
problem_type: deployment_issue
component: deployment
symptoms:
  - "release.yml aborts at the 'Security audit' step: `mix hex.audit` exits non-zero with `cowlib 2.18.0 - EEF-CVE-2026-43966 (MEDIUM)` and `EEF-CVE-2026-43969 (LOW)`"
  - "v0.9.0 tagged and CHANGELOG-finalized on main, but nothing published to Hex; release held for 2 days"
  - "CI on main red at the audit step with no code change in the repo"
root_cause: "mix hex.audit checks every package in mix.lock with no environment scoping, so an unpatched upstream advisory in a test-only transitive dep (bypass -> cowboy -> cowlib, only: :test) fails the gate even though the flagged package never enters the published qx_sim artifact"
severity: high
tags: [hex-audit, security-advisory, test-only-deps, release-gate, cowlib, deps-tree, unpatched-upstream, ci]
---

# hex.audit release gate blocked by an unpatched advisory in a test-only dep

## Symptoms

The v0.9.0 tag-triggered release run aborted at `mix hex.audit`:

```
Advisories:
  cowlib 2.18.0 - EEF-CVE-2026-43966 (MEDIUM)
    HTTP Response Splitting via Non-VCHAR Bytes in cow_http_struct_hd:escape_string/2
  cowlib 2.18.0 - EEF-CVE-2026-43969 (LOW)
    Cookie Request Header Injection via Unvalidated Encoder in cow_cookie:cookie/1
Found packages with security advisories
```

Same failure on `main` CI. The package was fully release-ready
(version bumped, CHANGELOG finalized, tag pushed); the hold lasted
2 days with nothing on Hex.

## Investigation

1. **Bump cowlib to the latest (2.16.1 -> 2.18.0)**: audit still
   fails. Both CVEs flag 2.18.0 too.
2. **Downgrade instead?** No. The OSV advisory range is
   `introduced: 2.9.0` with **no `fixed` event**, so every cowlib
   since April 2020 is affected and no patched version exists.
   Cowboy 2.15 needs `cowlib >= 2.16.0`, so escaping the range means
   a 2019-era cowboy in the test stack. Checked via:

   ```bash
   curl -s https://api.osv.dev/v1/vulns/EEF-CVE-2026-43966
   ```

3. **Scope check**: `mix deps.tree --only prod` shows 14 shipped
   packages; cowlib is absent. It arrives only through
   `bypass -> cowboy -> cowlib`, `only: :test`. Consumers of the
   published package can never load the vulnerable code.
4. **Root cause found**: `mix hex.audit` has no env scoping (no
   `--only` flag; it reads the whole lock). Confirmed with
   `mix help hex.audit`. A test-only advisory is indistinguishable
   from a shipped one at the gate.

## Root Cause

`mix hex.audit` audits `mix.lock`, which pins deps for every
environment. A library's *published* dependency surface is only the
prod tree (the `deps` entries without `only:`, plus their transitive
closure). When an advisory lands in a dev/test-only dep and upstream
has no fixed release, a bare `mix hex.audit` gate wedges the release
pipeline indefinitely with no dependency-level way out: upgrade,
downgrade, and waiting are all dead ends.

## Solution

Wrap the gate in a script that fails only when a flagged package is
in the shipped tree: `scripts/audit_shipped.sh`.

```bash
audit_out=$(mix hex.audit 2>&1)
audit_status=$?
echo "$audit_out"
[ "$audit_status" -eq 0 ] && exit 0

# advisory lines and retired-table rows both start "name version"
flagged=$(echo "$audit_out" \
  | grep -oE '^ *[a-z][a-z0-9_]* +[0-9]+\.[0-9]+' \
  | awk '{print $1}' | sort -u)
[ -z "$flagged" ] && exit 1   # unparseable: fail closed

shipped=$(mix deps.tree --only prod --format plain \
  | sed -n 's/^[|` -]*-- \([a-z0-9_]*\) .*/\1/p' | sort -u)

overlap=$(comm -12 <(echo "$flagged") <(echo "$shipped"))
[ -n "$overlap" ] && { echo "shipped deps flagged: $overlap"; exit 1; }
echo "advisories confined to dev/test-only deps"; exit 0
```

Both workflows call the script in place of bare `mix hex.audit`.
Verified the fail path too: a simulated advisory against `req`
(shipped) is caught by the overlap check.

Release recovery: the tag-triggered run had already consumed the
`v0.9.0` tag push, so the re-run used the workflow's
`workflow_dispatch` path on `main` with `version=0.9.0` (checkout
lands on `main`, which had the new gate and the right `mix.exs`
version). Published cleanly.

### Files Changed

- `scripts/audit_shipped.sh` — new, the scoped gate
- `.github/workflows/ci.yml` — audit step calls the script
- `.github/workflows/release.yml` — same
- `ROADMAP.md` — hold note flipped to RELEASED with the resolution

## Prevention

- The gate stays strict where it matters: shipped-dep advisories
  still fail, and unparseable audit output fails closed.
- When an advisory appears, check scope *first*:
  `mix deps.tree --only prod | grep <pkg>`. If it's not there, the
  release is not actually at risk.
- Check whether a fix exists before bumping:
  `curl -s https://api.osv.dev/v1/vulns/<ID>` and look for a `fixed`
  event in the ranges. No fixed event means no version shuffle helps.
- The cowlib advisory is still open upstream; the gate warns on every
  run. When upstream ships a fix, `mix deps.update cowlib` clears it.
- Same pattern applies to `qxportal` and `kino_qx` if their gates use
  bare `mix hex.audit`; port the script when it first bites.

## Related

- `.claude/solutions/testing-issues/safe-transient-retries-5xx-breaks-bypass-expect-once-20260701.md`
  — same bypass/cowboy test stack, different problem
