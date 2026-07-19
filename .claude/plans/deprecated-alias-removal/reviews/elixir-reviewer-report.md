# Code Review: feat/deprecated-alias-removal

## Summary
- **Status**: ✅ Approved
- **Issues Found**: 0 critical/warning, 2 minor suggestions

## Verification performed

- Grepped the whole repo (`lib/`, `test/`, `README.md`, `CHANGELOG.md`, `ROADMAP.md`) for
  `StateInit.bell_state(`, `StateInit.ghz_state(`, `Math.basis_state(`, `Qx.histogram(` —
  zero hits. The only surviving `Qx.bell_state`/`Qx.ghz_state` calls in `lib/qx.ex` and
  `README.md` are the unaffected circuit-returning facades (`Patterns.bell_state_circuit/1`,
  `Patterns.ghz_state_circuit/1`), correctly distinguished in the CHANGELOG's "Removed" note.
- Confirmed canonical arities claimed in `CHANGELOG.md` Removed section against the actual
  implementations:
  - `Qx.StateInit.bell_state_vector/2` (`state_init.ex:274`, defaults `\\ :phi_plus, \\ :c64`)
    → callable at arity 0/1/2. Matches "use `bell_state_vector/0,1,2`".
  - `Qx.StateInit.ghz_state_vector/2` (`state_init.ex:350`, `num_qubits, type \\ :c64`)
    → callable at arity 1/2 only (no 0-arity — `num_qubits` is required). Matches
    "use `ghz_state_vector/1,2`" — correct, CHANGELOG does not overclaim a 0-arity here.
  - `Qx.StateInit.basis_state/3` (`state_init.ex:62`) exists with the required 3-arg form;
    the removed `Qx.Math.basis_state/2` f32 shim is gone from `math.ex` entirely (grep clean).
  - `Qx.draw_histogram/1,2` (`qx.ex:1145`, `defdelegate draw_histogram(probabilities, options \\ [])`)
    → callable at arity 1/2. Matches "use `Qx.draw_histogram/1,2`".
  All CHANGELOG "Removed" arity claims verified correct.
- No doctest, `@spec`, or moduledoc anywhere still names the removed functions.
- `test/qx_manual_test.livemd`: zero remaining `Qx.histogram` occurrences (grep clean).
- `test/qx/state_init_test.exs` and `state_init_vector_test.exs`: only reference
  `basis_state/3`, `bell_state_vector`, `ghz_state_vector` — no alias leftovers.

## Critical Issues

None.

## Warnings

None.

## Suggestions

1. **`test/qx/deprecated_alias_removal_test.exs:11,19,32`**: the `for arity <- 0..2 do
   refute ... end` / `for arity <- 1..2 do ... end` pattern builds and discards a list of
   `:ok`/boolean results on every iteration purely for the assertion side effect. Idiomatic
   alternative avoiding the throwaway list:
   ```elixir
   # Current
   for arity <- 0..2 do
     refute function_exported?(Qx.StateInit, :bell_state, arity)
   end

   # Suggested
   Enum.each(0..2, fn arity ->
     refute function_exported?(Qx.StateInit, :bell_state, arity)
   end)
   ```
   Either form is fine functionally (no Credo `UnusedEnumOperation` trigger here since `for`
   isn't the flagged construct), but `Enum.each/2` communicates "side effect only, no
   collection" more explicitly. Not blocking.

2. **`ROADMAP.md:92-94`**: the three removal line items this change addresses
   (`bell_state/2`+`ghz_state/1` aliases, `Math.basis_state/2`, `Qx.histogram/2`) are still
   unchecked (`- [ ]`). Per the repo's own workflow (`CLAUDE.md` "tick the matching ROADMAP
   item in [the merge] commit"), these should flip to `- [x]` at merge time — noting it here
   since this review runs pre-merge and the checkboxes aren't part of the diff being
   reviewed. Not a defect in the reviewed diff itself, just a reminder for step 8 of the
   merge sequence.

## Notes on test edits (human-approved)

Reviewed the described test surgery for correctness, not just presence:
- `state_init_test.exs` alias `describe` blocks removed — canonical `_vector` coverage
  confirmed present and equivalent in `state_init_vector_test.exs` (arity 0/1/2 bell,
  arity 1/2/with-`:c128`-type ghz).
- The 2 integration tests re-pointed at `_vector` names in `state_init_test.exs:283-284,
  303-304` produce identical values to the removed aliases (verified by reading the
  `bell_state_vector`/`ghz_state_vector` bodies — no behavior drift, pure rename).
- New TDD test (`deprecated_alias_removal_test.exs`) correctly asserts both directions:
  removed names raise `false` for `function_exported?/3`, canonical names return `true`,
  covering all four removed identifiers and their arities as claimed in the CHANGELOG.
