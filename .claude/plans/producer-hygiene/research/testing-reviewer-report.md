# Testing Review: feat/producer-hygiene

## Scope / method note

No `Bash` tool is available in this agent session, so `git --no-pager diff main -- test/`
could not be executed directly. Assessment is based on reading the current contents of
the three touched test files plus the corresponding `lib/` producer code
(`lib/qx/quantum_circuit.ex`, `lib/qx/operations.ex`). All three new blocks appear as a
single `describe` block cleanly appended at the very end of each file (see line numbers
below), consistent with the orchestrator's additive-only claim; nothing above those blocks
reads as altered (assertions, `describe` titles, and existing test bodies match what a
byte-identical refactor would leave untouched). **This is corroborating evidence, not a
literal diff** — recommend a human/CI run of `git diff main -- test/` to confirm zero lines
changed above each new `describe` block before merge.

## Summary

The three new invariant tests genuinely pin observable, byte-identical behavior of the
public producer functions (`Qx.barrier/2`, `Qx.c_if/4`, `Patterns.measure_all/1`) against
either (a) a manually-composed equivalent using existing public primitives, or (b) a direct
literal instruction-tuple assertion. Both forms will fail if the refactor changes output
shape, so they are effective tripwires for "did the internal restructuring change the
producer surface." Testing the new `@doc false` `QuantumCircuit.add_barrier/2` and
`add_conditional/4` directly is appropriate here — the plan explicitly designates them as
the new single producer surface (see the "Instruction producer surface (internal)" comment
block in `lib/qx/quantum_circuit.ex:98-108`), and Iron Law #9 requires every instruction
shape be traceable to its producer; a direct unit test of that producer is the correct way
to pin the shape it emits, distinct from testing it as a private implementation detail of
unrelated behavior.

## Iron Law Violations

None found. Iron Law #9 (dispatch completeness) is actually reinforced by these tests:
`add_barrier/2` and `add_conditional/4` are the single producer surface per the code
comment, and the new unit tests confirm the shapes they emit match what
`barrier_dispatch_test.exs` / `conditional_operations_test.exs` already exercise through
`run/2` and `steps/2`.

## Issues Found

### Critical

None.

### Warnings

- [ ] **Confirm zero modification to existing tests via literal diff before merge.**
  This review could not execute `git diff main -- test/` (no Bash access in this
  agent). The structural read (new `describe` blocks appended at file end) is strong
  evidence but not proof. Have the orchestrator or a CI step run the diff and confirm
  only additions, or route this specific check back through an agent/tool with git access.

- [ ] **`measure_all/1` invariant only covers the full-circuit form, not `measure_all/2`
  (list/range).** `patterns_test.exs` "measure_all producer-hygiene invariant" (lines
  640-656) composes `Operations.measure/3` against `Patterns.measure_all/1` only. Given
  `measure_all/2` (list/range overload, tested functionally at lines 298-329) presumably
  also routes through the same refactored internals, a byte-identical invariant for the
  `/2` overload (e.g. `measure_all(qc, [0,2]) == qc |> measure(0,0) |> measure(2,2)`, note:
  order matters, would need care with the list form) would close the gap symmetrically
  with the `/1` case. Not blocking — `measure_all/2` delegates to `/1`-style construction
  internally per existing tests, but an explicit invariant would remove reliance on that
  assumption.

- [ ] **No invariant test for `Patterns.barrier_all/1` or `barrier_all/2`.**
  `barrier_dispatch_test.exs` pins `Qx.barrier/2` (single barrier call) and the new
  `add_barrier/2` unit, but `Patterns.barrier_all/1` (tested functionally in
  `patterns_test.exs` lines 133-157) is a second call site of the same refactored
  `add_barrier/2` path and has no producer-hygiene invariant of its own (e.g.
  `barrier_all(qc) == barrier(qc, Enum.to_list(0..(n-1)))`). Given the refactor's stated
  tripwire is the *unmodified* existing suite passing, this is arguably covered
  transitively by the existing `barrier_all` functional tests — but an explicit invariant
  would make the byte-identical claim symmetric across both barrier producer call sites
  (`Qx.barrier/2` directly and via `Patterns.barrier_all`).

- [ ] **No chained/nested `c_if` invariant against the new `add_conditional/4`.**
  The new `conditional_operations_test.exs` invariant (lines 157-179) covers a single
  `c_if` call producing one `{:c_if, ...}` tuple. The file's pre-existing "chained
  conditionals" describe block (lines 20-121) already runs multiple `c_if` calls through
  `run/2` and asserts on `result.counts` (execution-level, not construction-level). Given
  the stated tripwire is "unmodified suite passes," this is likely sufficient — but there
  is no direct construction-level assertion that two chained `c_if` calls each still
  independently produce byte-identical `{:c_if, [cb, val], instrs}` tuples via
  `add_conditional/4` (as opposed to only observing correct execution counts). Low
  priority given the existing chained-execution coverage is strong.

### Suggestions

- [ ] Consider naming the new `describe` blocks more consistently — two of the three use
  the phrase "producer-hygiene invariant" (`barrier_dispatch_test.exs:152`,
  `conditional_operations_test.exs:157`, `patterns_test.exs:640`) which is good and
  matches naming conventions elsewhere in the file (e.g. `patterns_test.exs:625`
  "creator reframe invariants (byte-identical to the appenders)"). No action needed —
  flagging only that a shared helper/macro (e.g. `assert_byte_identical(a, b)`) could
  reduce duplication if more producer-hygiene invariants are added in future refactors.

- [ ] All three test files correctly use `async: true` (pure in-memory `Nx`/struct
  operations, no shared/global state, no Sandbox needed) — consistent with Iron Law #1.
  No Mox usage present or needed (no external boundary involved). `assert_raise` with a
  message-pattern regex is used consistently for error-path tests
  (e.g. `patterns_test.exs:121`, `:211`, `:246`). No `Process.sleep`, no factories
  involved (pure-Elixir library, no Ecto). No ExUnit idiom violations found in the new
  code.

## Confirmation checklist against the review brief

- **Genuinely pin byte-identical output pre/post-refactor?** Yes for `Qx.barrier/2` and
  `c_if/4` (literal tuple equality against hardcoded expected instruction shapes) and for
  `measure_all/1` (equality against a hand-composed `Operations.measure/3` chain). These
  will fail identically whether run against the pre-refactor or post-refactor code, as
  long as the *public* output tuple shape is unchanged — which is exactly the tripwire
  wanted.
- **Testing `@doc false` internal helpers directly appropriate?** Yes — `add_barrier/2`
  and `add_conditional/4` are explicitly documented in `quantum_circuit.ex` as "the SINGLE
  place every instruction tuple is built and appended," i.e. the new producer surface
  this refactor introduces. Testing them directly is the correct granularity for pinning
  the producer contract itself, separate from testing it indirectly through every caller.
- **Missing invariants?** See Warnings above: `measure_all/2`, `barrier_all/1|2`, and
  chained `c_if` construction-level invariants are the gaps; none are blocking given the
  existing (unmodified) functional suite already exercises those paths end-to-end.
- **No existing test modified?** Structural read supports this (new blocks cleanly
  appended at file end in all three files) but could not be confirmed via literal `git
  diff` due to lack of Bash access in this session — flagged as a Warning to close out
  before merge.
