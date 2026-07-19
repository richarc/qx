# Triage — calcfast-norm-drift-guard (2026-05-16)

Source review: `calcfast-norm-drift-guard-review.md`
(verdict REQUIRES CHANGES). User triaged all 8 findings → **fix all**.
No Iron Law violations (none to auto-include). 0 skipped, 0 deferred.

## Fix Queue (all approved) — ALL RESOLVED 2026-05-16

- [x] **B1 [BLOCKER]** `mix.exs:93` — added `Qx.OptionError,` to the
      `"Error Handling"` `groups_for_modules` group.
- [x] **W1 [WARNING] — fixed in code** `simulation.ex` — replaced
      timeline-index counting with a shared 1-based gate counter
      threaded via new `apply_gate_step/5`; `execute_circuit/2`,
      `process_timeline_item/6`, and `process_conditional/8` all use
      it, so c_if sub-gates now honour `renormalize: N` AND the
      norm guard. `maybe_gate_renorm/3` now 1-based ordinal
      (`rem(ordinal, n) == 0`). No CHANGELOG change needed (the
      unreleased feature is now simply correct on the c_if path).
- [x] **W2 [WARNING]** test — replaced the vacuous P4-T5 with two
      guard-based conditional tests: drift-before-measure (timeline
      path) and drift-inside-c_if-block (process_conditional / W1
      regression). Both: no-renorm ⇒ `assert_raise`; `renormalize: 10`
      ⇒ completes.
- [x] **W3 [WARNING]** test — added a 60-gate sub-threshold direct
      comparison (`renormed < off`, both ≤1e-6, neither raises); the
      100-gate `assert_raise` test renamed/re-scoped as an explicit
      guard-behaviour test.
- [x] **W4 [WARNING]** `validation.ex` — `@spec
      validate_renormalize!(term()) :: false | true | pos_integer()`.
- [x] **S1 [SUGGESTION]** `assert_norm/1` — pinned `:ok =
      Validation.validate_normalized!(...)`.
- [x] **S2 [SUGGESTION]** `resolve_renormalize/1` → pipe into private
      `to_renorm/1` function heads.
- [x] **S3 [SUGGESTION]** `dev/1` — asserts rank-1 statevector shape
      before computing the deviation.

**Verification after fixes:** `mix compile --warnings-as-errors`
clean, `mix format --check-formatted` clean, `mix credo --strict`
0 issues, `mix test` = 234 doctests + 719 tests, 0 failures. The W1
regression test ("drift inside a c_if block") confirms c_if sub-gates
are now guarded+renormed (would not raise pre-fix).

## Skipped
(none)

## Deferred
(none)

## Notes
- W2/W3 edit the new (this-session, human-approved) test file; the
  test-file PreToolUse hook will still prompt — the triage selection
  is the TDD-rule sign-off for these specific changes.
- W1 is the only behaviour-affecting fix (conditional path); it
  needs its own verification (full suite + the new W2 test) and may
  warrant a CHANGELOG clarification of the `c_if` cadence.
- After fixes: re-run full gate (compile/format/credo/test) +
  re-`/phx:review` (merge gate must reach PASS before merge).
