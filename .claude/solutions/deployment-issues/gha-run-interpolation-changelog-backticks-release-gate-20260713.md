---
module: "Release workflow (release.yml)"
date: "2026-07-13"
problem_type: deployment_issue
component: deployment
symptoms:
  - "Tag-triggered v0.11.0 release run died in 14s at 'Verify CHANGELOG entry exists' with exit 127"
  - "Log full of `Math: command not found`, `Qx: command not found`, `StateInit: command not found` — CHANGELOG words executed as shell commands"
  - "v0.10.1 had released green through the same step nine days earlier"
root_cause: "the step used `${{ steps.changelog.outputs.changes }}` inside `run:`, which splices the raw multi-line CHANGELOG section into the bash script before execution — every backtick pair becomes command substitution and every line after the first becomes a bare command; the big backtick-rich v0.11.0 section triggered it, the small v0.10.1 section had merely gotten lucky"
severity: high
tags: [github-actions, shell-injection, run-interpolation, changelog, release-gate, backticks, env-var-passing]
related_solutions:
  - ".claude/solutions/deployment-issues/hex-audit-advisory-test-only-dep-release-gate-20260703.md"
---

# `${{ }}` inside `run:` executes your CHANGELOG — pass step outputs via env

## Symptoms

First v0.11.0 tag push: release run failed in 14s, exit 127, at
"Verify CHANGELOG entry exists". The log showed CHANGELOG prose being
*executed*: `Math: command not found`, `Qx.Patterns.ghz_state_circuit/1:
No such file or directory`, dozens more — one error per backticked term
or continuation line in the section body.

## Investigation

1. The failing step read:
   ```yaml
   run: |
     if [ -z "${{ steps.changelog.outputs.changes }}" ]; then
   ```
   GitHub Actions expands `${{ }}` **textually, before bash parses the
   script**. The whole multi-line section body landed inside the script:
   backticks → command substitution; newlines → new script lines.
2. Why did v0.10.1 pass? Its section was a short Fixed-only block; the
   v0.11.0 section is ~100 lines dense with `` ` ``-quoted identifiers.
   Same bug, different payload — the gate was a time bomb, not newly
   broken.
3. The other use of the output (`body:` of `softprops/action-gh-release`)
   is a YAML action input, not shell — safe, no change needed.

## Root Cause

`${{ }}` interpolation in `run:` is template substitution into source
code. Any step output containing shell metacharacters (backticks, `$(`,
quotes, newlines) is executed, not compared. This is the documented
GitHub Actions script-injection class; it bites honest data (a CHANGELOG)
exactly like malicious input.

## Solution

Pass the output through `env:` — Actions sets environment variables
directly, with no shell parsing of the value:

```yaml
- name: Verify CHANGELOG entry exists
  env:
    CHANGES: ${{ steps.changelog.outputs.changes }}
  run: |
    if [ -z "$CHANGES" ]; then
```

Recovery mechanics that mattered: **tag-triggered runs execute the
workflow definition at the tag's commit**, so pushing the fix to main is
not enough — the tag had to be deleted and recreated on the fix commit
(`git tag -d v0.11.0 && git push origin :refs/tags/v0.11.0 && git tag
v0.11.0 && git push origin v0.11.0`). Second run published clean.

Bonus fix in the same pass: the GitHub Release notes template said
`{:qx_sim, "~> X.Y.Z"}` — a non-working dep line (package `qx_sim`, app
`:qx`); corrected to `{:qx, "~> X.Y.Z", hex: :qx_sim}`.

### Files Changed

- `.github/workflows/release.yml` — env-var passing + install-snippet fix

## Prevention

- **Never put `${{ }}` step outputs, PR titles, branch names, or any
  non-literal inside `run:`.** Route through `env:` and reference the
  shell variable. Grep check: `grep -n '\${{' .github/workflows/*.yml`
  and audit every hit that sits inside a `run:` block.
- Small-payload success is not evidence of safety — the step passes until
  the interpolated text happens to contain a metacharacter.
- Same audit applies to `qxportal` and `kino_qx` workflows when they grow
  release automation.
- Remember the tag-recreation recovery: workflow fixes don't apply to an
  already-pushed tag.

## Related

- `.claude/solutions/deployment-issues/hex-audit-advisory-test-only-dep-release-gate-20260703.md`
  — the previous release-gate incident; this release also tripped its
  scoped-audit gate correctly (mint/hpax HIGH CVEs in the SHIPPED tree,
  fixed by `mix deps.update mint hpax` — both had patched upstream
  releases, verified via OSV before bumping).
