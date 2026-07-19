# Review — openqasm-hardening

**Verdict: PASS WITH WARNINGS → F1–F6 RESOLVED** (V1 is a release-time call)

> Post-review fixes applied (re-verified green: compile/format/credo clean,
> 242 doctests + 933 tests, 0 failures):
> - **F1** — deep-paren tests now assert `reason =~ "nesting too deep"` (the
>   depth-cap message), not the loose `~r/nest|deep|paren/i`.
> - **F2** — added a boundary test: depth 64 parses, depth 65 rejected.
> - **F3** — `scan_paren_depth/2`'s `(` path is now two guard-head clauses
>   (`when depth + 1 > @max_paren_depth`), no inner `if`.
> - **F4** — comment documents the deliberate count-in-comments/strings
>   fail-closed choice.
> - **F5** — compile test match tightened to `[{module, _bin}]` (no tail).
> - **F6** — `on_exit` now registered immediately after the compile.
>
> F7 (pre-existing `emit_body` `++`) left as-is. **V1 (version bump) is a
> release-time decision — see below.**

**Verdict: PASS WITH WARNINGS** (no blockers; security core proven sound)

Diff: 6 files. Two v0.8.2 security findings (parser depth cap + codegen
isolation). Behaviour changes (noted in CHANGELOG `### Security`).

## Requirements Coverage (source: plan.md)

**11 MET · 0 PARTIAL · 0 UNMET · 2 UNCLEAR.** Every code/doc requirement met,
including the approved hash-naming (`Qx.Generated.<Name>_<8hex>`,
codegen.ex:71-80). The 2 UNCLEAR are process steps (RED confirmation, suite
run) with no diff artifact. Scope discipline holds (only Group C; braces
correctly out of scope).

## Security (headline) — PASS, no bypass

- **Depth cap:** early-exits on the 65th net `(` (rejects a paren bomb in ~65
  bytes, not 1 MB); net-depth is the exact metric (cap 64 ⇒ parser depth ≤64);
  UTF-8 safe (continuation bytes never collide with `(`/`)`); `(` confirmed the
  *sole* deep-recursion vector (`[` and `{` don't recurse).
- **Codegen wrap:** module name attacker-uninfluenced (`name` is `[A-Za-z_]\w*`,
  no `.` possible, can't escape `Qx.Generated.*`); body is whitelist-only
  (`@stdgate_emit` `Qx.*` + `:math.*` + literals + validated idents). Typed
  errors retained.

## Iron Laws

#1 (no `String.to_atom`) and #7 (typed `QasmParseError`) CLEAN. **#6 WARNING —
version/release decision** (see below).

## Findings

### Worth fixing (test quality + idiom)

- **F1 (WARNING, test) — loose rejection assertion.** The deep-paren test's
  `reason =~ ~r/nest|deep|paren/i` would also match a *generic* parser paren
  error, so it could green even if the depth guard were removed. Assert the
  depth-cap message specifically (e.g. `reason =~ "nesting too deep"`).
- **F2 (SUGGESTION, security+test) — pin the boundary.** Tests use depth 200 vs
  3; add `String.duplicate("(", 64)` accepted and `("(", 65)` rejected to pin
  the exact cap (and one `()`×100k depth-1 accept to prove width is fine).
- **F3 (SUGGESTION, elixir) — guard over `if`.** `scan_paren_depth/2`'s `(`
  clause rebinds `depth = depth + 1` then `if`. Split into guard-head clauses
  (`when depth + 1 > @max_paren_depth` → error; else recurse) — idiomatic, and
  matches the module's style.
- **F4 (SUGGESTION, security) — document the fail-closed choice.** A one-line
  comment that `(` inside comments/strings is counted on purpose (fail-closed;
  64-deep parens in a comment is implausible).
- **F5 (SUGGESTION, test) — tighten the compile match.** `[{module, _bin} | _]`
  → `[{module, _bin}]` so an accidental extra generated module is caught.
- **F6 (SUGGESTION, test) — `on_exit` before `Code.compile_string`** so an
  unexpected raise still purges.

### Note / out of scope

- **F7 (elixir, PRE-EXISTING) — `emit_body/3` `acc ++ [line]` is O(n²).** Not in
  this diff; gate bodies are tiny. Skip (or a separate cleanup).

### Release decision (not a code fix)

- **V1 (WARNING, Iron Law #6) — patch vs minor at tag time.** `mix.exs` is still
  `0.8.1`; these two behaviour changes (and Group A's config rejection) ship
  against the declared-public `Qx.Export.OpenQASM` / `Qx.Hardware.Config`. The
  CHANGELOG documents them, but per SemVer a behaviour change that rejects
  previously-valid input / changes output shape is **minor**-worthy. This is the
  **second** time the v0.8.2 "Security & Hardening" group has accumulated a
  behaviour change. Decide at release: tag the v0.8.2 section as **0.9.0**, or
  split the breaking parts out. Not a merge blocker (merging to `main` doesn't
  publish).

## Bottom line

Both security objectives met and proven bypass-proof. Findings are test-quality
(F1/F2/F5/F6), one idiom nudge (F3), a clarifying comment (F4) — all small,
mostly in the test files. The one strategic item is V1 (the v0.8.2-as-patch
question), which is a release-time call to make before tagging.
