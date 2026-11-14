# Review: docs-consistency

**Date:** 2026-11-14
**Branch:** `fix/docs-consistency` vs `main` (uncommitted)
**Verdict:** PASS after fixes, pending the human's merge authorization.
One open decision for the human (O1) is outside this diff.

Documentation and doctest change; no runtime code. Three agents ran
(elixir, testing, iron-laws); none ran code. The testing agent did not
write its report file; its findings are taken from its returned message.

## Findings and resolution

| # | Source | Finding | Outcome |
|---|---|---|---|
| 1 | elixir | New CONTRIBUTING text said "`~> 0.11` excludes 0.12.0". False. Checked: `Version.match?("0.12.0", "~> 0.11")` is `true`; only `~> 0.11.0` excludes it. | Fixed: the claim is removed. See O1. |
| 2 | elixir | ROADMAP v0.12 intro said "three breaking changes"; CHANGELOG has four **Breaking** entries (the `c_if` and OpenQASM-import rejections are separate entries). | Fixed: "four breaking changes in three areas". |
| 3 | testing, iron-laws | `Qx.Calc` doctests had no expected value. | Fixed: they assert the resulting state. |
| 4 | elixir | CHANGELOG entry named four of the six modules; `phase(:math.pi/4)` spacing; CONTRIBUTING dropped `Qx.Behaviours.*` without stating its tier. | Fixed. |
| 5 | testing | Some examples stay weak: `is_map(result)` in `Qx.Simulation.run/2`, the `or` in `Qx.Draw.Image`, shape-and-type only in `Qx.Gates`. | Not changed. They now run, which they did not before. |

## Open decision (not in this diff)

**O1.** `AGENTS.md` Iron Law #6 says "`~> 0.10` pins `< 0.11.0`". It does
not: a two-segment requirement allows every later 0.x. The README install
snippets and `kino_qx/mix.exs` use `{:qx, "~> 0.11", hex: :qx_sim}`, so
they accept 0.12.0 and its four breaking changes without an edit.

## Confirmed by the agents (read, not run)

- No existing test file is touched.
- All 19 modules under `lib/` with `iex>` examples now have a `doctest`
  directive.
- README error names, the `c_if` sentence, the OpenQASM bullet, the
  CHANGELOG link references and the tier openers match the code.

## Pre-existing

- `Qx` is doctested in both `test/qx_test.exs` and
  `test/complex_support_test.exs`, so its doctests run twice.
