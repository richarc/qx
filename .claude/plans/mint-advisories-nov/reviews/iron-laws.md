# Iron Law Review: mint 1.9.3 -> 1.11.0 bump

Checked 26 laws (project AGENTS.md laws #1-#9 are the Elixir/OTP, Nx, dispatch and API ones). 0 violations.

## Iron Laws (verified by reading .diff.patch and AGENTS.md lines 384-405)
The diff touches only CHANGELOG.md, ROADMAP.md and mix.lock. No `.ex`/`.exs`/`.heex` file changed, so none of the code-level laws (atoms, processes, Nx kernels, dispatch, public API tier, typed errors, precision) can be hit. Public API law #6 needs no bump: no tier 1/2 module changed.

## CHANGELOG entry (verified by reading CHANGELOG.md 1-140)
- Placed under `## [Unreleased]` as a new `### Security` section, between `### Performance` and `### Fixed`. Existing sections are already in a non-Keep-a-Changelog order (Changed, Added, Performance, Fixed), so placement is consistent. Strict Keep a Changelog puts Security last, after Fixed. Optional nit, not a violation.
- Wording matches the prose style of neighbours (plain, names the consumer impact, "No Qx code changed", an action for downstream users).
- No earlier mint entry exists in CHANGELOG.md (grep "mint" finds only the new lines). The July 1.9.1 -> 1.9.3 bump was recorded in ROADMAP only, so there is no precedent to match. Inferring: fine to add.

## ROADMAP (verified by reading ROADMAP.md lines 32-34)
New line is `- [x]`, in the v0.12 section, directly after the earlier mint bump line. Format matches it: "Security: bump ... (branch: ...)", CVE list with severity, `scripts/audit_shipped.sh` goes 1 -> 0. It omits a `(plan: slug)` suffix and the audit record path that the July line has; AGENTS.md says only items with a plan carry a slug, so acceptable. The AGENTS.md rule is to tick the item in the merge commit to main, which this does. Ticking it does not itself trigger a release (the v0.12 section may still have unchecked items; I did not verify the whole section).

## mix.exs (verified by grep)
Only `{:req, "~> 0.6"}` (line 70). No direct mint, finch or hpax constraint, so no change is needed. Lock constraints: finch 0.23.0 requires `mint ~> 1.8`, new mint requires `hpax ~> 1.1`; both are satisfied by the new lock, so mix.exs does not need to move. Whether req's own lock entry permits finch 0.23.0 I did not read (the line was truncated); it is unchanged by this diff.

## mix.lock (verified by reading the diff)
Only two entries changed: hpax 1.0.4 -> 1.1.0 and mint 1.9.3 -> 1.11.0. Both are `{:hex, ..., "hexpm", "<checksum>"}` with an inner and outer sha256. No git or path deps introduced. `git status` shows mix.lock as the only lock change (no deps/ or other lock files).

## Not verified
I did not run `mix deps.get`, `mix test` or `scripts/audit_shipped.sh`, and the CVE ids and the "fixed by 1.10.2" claim are taken from the diff text, not checked against an advisory database.
