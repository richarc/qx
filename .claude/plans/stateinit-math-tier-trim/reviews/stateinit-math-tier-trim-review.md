# Review: StateInit/Math tier trim (v0.11, R-07/R-08/R-13)

**Date:** 2026-07-08 · **Branch:** `feat/stateinit-math-tier-trim` (uncommitted working tree)
**Agents:** elixir-reviewer, testing-reviewer, iron-law-judge, requirements-verifier (+ context-supervisor)
**Requirements source:** Plan `.claude/plans/stateinit-math-tier-trim/plan.md`

## VERDICT: PASS WITH WARNINGS

- Requirements coverage: **7/7 MET**, 0 PARTIAL, 0 UNMET (verified against code, not checkbox ticks)
- Iron Laws: **all compliant** (#6 non-breaking confirmed; #7 no new error paths; #3/#4/#5 only attribute
  changes + one semantically-identical host-side swap; #9 n/a; #1/#2 not present)
- Blockers: **none**
- Warnings: 1 actionable (W1) + 2 plan-accepted noise notes (A1, A2)
- Quality gates: compile --warnings-as-errors ✓ · format ✓ · credo --strict ✓ ·
  250 doctests + 1005 tests, 0 failures ✓ · mix docs 36 = baseline ✓

## Requirements Coverage (Plan .claude/plans/stateinit-math-tier-trim/plan.md)

| # | Requirement | Status |
|---|-------------|--------|
| 1 | 17 functions deprecated (9 StateInit + 8 Math), messages end "Will be removed in Qx 1.0"; survivors not deprecated | MET |
| 2 | Dead converters deleted (lib + their math_test describe blocks); `complex_matrix/1` untouched `@doc false` | MET |
| 3 | Internal callers re-homed; zero lib/ deprecation warnings; `unitary?` inlines `Nx.eye` | MET |
| 4 | Behaviour `@moduledoc false` on outer module, callbacks intact, Register `@behaviour` kept; dropped from qx.ex list | MET |
| 5 | AGENTS.md Iron Law #6 list updated; CHANGELOG Deprecated/Removed/Changed present | MET |
| 6 | Deferred items untouched (no R-05 restyle, no R-06 rename, no removals) | MET |
| 7 | tier_trim_test.exs covers Phase-2 (a)/(b)/(c) | MET |

(Full evidence table: `summaries/review-consolidated.md` and `reviews/requirements.md`.)

## Findings (after anti-noise filter)

### WARNING — actionable

- **W1 · test/qx/tier_trim_test.exs — the "deprecated ⇒ still works until 1.0" guarantee is implicit**
  (testing-reviewer). Functional coverage of the 17 deprecated functions lives entirely in the untouched
  describe blocks of `math_test.exs`/`state_init_test.exs`; nothing documents that coupling, so a future
  cleanup of those tests could silently drop the guarantee this trim depends on. Cheapest fix: a comment in
  `tier_trim_test.exs` naming those files as the functional coverage (or a small
  `describe "deprecated functions still work"` block). Test-file edit → needs human approval either way.

### ACCEPTED — documented in plan, no action

- **A1 · Deprecation-warning noise in `mix test` output** (elixir-reviewer): the 17 functions' own doctests
  and the retained `math_test.exs`/`state_init_test.exs` describe blocks now emit deprecation warnings at
  test compile. Explicitly accepted as plan Risk #2 ("cosmetic; if it drowns signal, revisit … with human
  sign-off") and in Phase-2 task text ("expect deprecation warnings at test compile; non-fatal").
- **A2 · Same noise, doctest variant** — same adjudication; alternative (strip `iex>` prompts from the 17
  deprecated functions' examples) noted for the 1.0 removal sweep, when the docs die anyway.

### SUGGESTION — optional polish

- **S1 · state_init.ex `random_state/2` message** says "No replacement" though the exact recipe now exists
  inline (and in `Qubit.random/0`); message could carry the one-line recipe itself.
- **S2 · tier_trim_test.exs `is_binary/1` assertion** would accept `@deprecated ""`; `String.trim(msg) != ""`
  would also enforce non-empty messages. (Test-file edit → human approval.)
- **S3 · qubit.ex `hadamard_basis_state/1` naming nit** — builds X-eigenstates; `x_eigenstate/1` would read
  clearer. Not worth a rename alone.

## Notes

- elixir-reviewer spot-checked all 9 StateInit replacement pointers against the current public API — all
  correct, including the mid-implementation fix to `Qx.Patterns.superposition_circuit/1`.
- iron-law-judge caveat: it verified current file contents rather than parsing git diff hunks (no Bash in its
  session); requirements-verifier independently ran grep/mix against the tree, closing that gap.

**Merge gate:** PASS WITH WARNINGS — eligible to merge once W1 is either fixed (needs your approval, it's a
test file) or consciously waived. The human authorizes the merge; the agent stops here.

---

## Resolution (2026-07-08, post-review — user chose "apply everything")

- **W1 FIXED** — tier_trim_test.exs moduledoc now names `math_test.exs`/`state_init_test.exs` as the
  functional coverage for "deprecated ⇒ still works until 1.0" and forbids deleting those blocks pre-1.0.
- **S2 FIXED** — both metadata assertions now require a non-empty message
  (`is_binary(msg) and String.trim(msg) != ""`). Test edits approved by the user via the merge-gate answer.
- **S1 FIXED** — `random_state/2` deprecation message now carries the inline recipe (plain code, no
  backticked ref to the hidden Qx.Qubit module, keeping mix docs clean).
- **S3 FIXED** — `hadamard_basis_state/1` renamed to `x_eigenstate/1` (private defp + 2 call sites).
- **A1/A2** remain accepted per plan Risk #2.
- Gate re-run after fixes: compile --warnings-as-errors ✓ · format ✓ · credo --strict ✓ (exit 0) ·
  250 doctests + 1005 tests, 0 failures ✓ · mix docs 36 = baseline ✓.

**Final status: all actionable findings resolved — merge-eligible pending your authorization.**
