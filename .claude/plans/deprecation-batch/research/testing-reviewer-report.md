# Testing Review: feat/deprecation-batch

## Summary

Three test files reviewed: two new (`quantum_circuit_state_test.exs`,
`state_table_register_deprecation_test.exs`), one modified additively
(`barrier_dispatch_test.exs`). Overall solid coverage of the new
deprecation-batch behavior (barrier ranges, Register warn-vs-tensor-silent,
doctest wiring), but one test is a **tautology with zero signal** and must
be fixed before merge.

## Iron Law Violations

None of the ExUnit iron laws (async default, sandbox, mock boundaries,
Process.sleep, verify_on_exit!) are implicated — these are pure-function
unit tests, all correctly `async: true`, no Mox/DB involved.

## Issues Found

### Critical

- [ ] **Tautological test** — `test/qx/quantum_circuit_state_test.exs:17-20`,
  `"initial_state/1 and the deprecated get_state/1 return the same value"`:
  ```elixir
  test "initial_state/1 and the deprecated get_state/1 return the same value" do
    qc = QuantumCircuit.new(2, 0)
    assert QuantumCircuit.initial_state(qc) == QuantumCircuit.get_state(qc)
  end
  ```
  `get_state/1` is defined as `def get_state(circuit), do: initial_state(circuit)`
  (`lib/qx/quantum_circuit.ex:274-276`) — this asserts `x == x`. It cannot
  fail for any implementation of `initial_state/1`, including a broken one.
  This is the exact anti-pattern flagged in
  `.claude/solutions/architecture-issues/deprecate-public-fn-rename-shim-qx-stateinit-20260627.md`
  ("delegation equivalence against a one-line delegator … assert observable
  behaviour instead").

  **Fix** — replace with an assertion against an independent reference value
  (shape + amplitudes), e.g.:
  ```elixir
  test "initial_state/1 returns the |0...0> basis vector for a fresh circuit" do
    qc = QuantumCircuit.new(2, 0)
    expected = Nx.tensor([1, 0, 0, 0], type: :c64)
    assert Nx.to_flat_list(QuantumCircuit.initial_state(qc)) ==
             Nx.to_flat_list(expected)
  end
  ```
  This keeps the deprecated-name coverage (the other test in the same file,
  line 11-15, already exercises `get_state/1` implicitly via doctest — verify)
  but makes the *new* test actually assert something that could fail.

  Optionally keep a *thin* delegation-equivalence test but demote it to a
  one-liner explicitly labelled as delegation coverage, not behavior coverage
  — per the same solution doc's guidance, prefer to drop it and assert real
  behavior once per name instead.

### Warnings

None.

### Suggestions

- [ ] `test/qx/quantum_circuit_state_test.exs:11-15` — the first test does
  assert real behavior (`qc.state` field equality + shape `{2}`), which is
  fine, but note it only covers a fresh `new(1, 0)` circuit (all-zero /
  trivial state). Consider adding a case with a non-trivial `initial_state`
  argument (e.g. `QuantumCircuit.new(1, 0, initial_state: ...)` or whatever
  the constructor's non-default path is) if one exists, to avoid the whole
  file only ever exercising the zero-state.
- [ ] Confirm `get_state/1`'s `@deprecated` call itself is exercised somewhere
  with `capture_io`/log assertion (Elixir's `@deprecated` only warns at
  *compile time* for direct static calls, so a runtime test wouldn't catch a
  regression there anyway) — no action needed, just confirming this isn't a
  gap.

## Coverage Assessment (by area)

- **`barrier/2` range support** — well covered in
  `test/qx/barrier_dispatch_test.exs:164-178`: byte-identical-to-list
  positive case, and an out-of-range `Qx.QubitIndexError` case. Good use of
  `Qx.QuantumCircuit.get_instructions/1` as an independent reference rather
  than a delegation check. No existing tests in this file were modified —
  the new `describe "barrier/2 range support"` block is purely additive
  (appended after the existing `"barrier producer-hygiene invariant"`
  block); all prior describe blocks (`run/2`, `get_state/2`, `steps/2`,
  `edge cases`) are untouched.
- **`initial_state/1`** — covered for the trivial case; the pairing test
  with `get_state/1` is the flagged tautology (see Critical above).
- **Register runtime-warn vs tensor-silent** —
  `state_table_register_deprecation_test.exs` correctly distinguishes the
  two paths: tensor input asserts `warn == ""` (silent), Register input
  asserts `warn =~ "deprecated"`. Both use `capture_io(:stderr, ...)`, which
  is correct since `IO.warn/1` (used at `lib/qx/draw/tables.ex:36`) writes to
  stderr. Both also assert the return value (`%Qx.Draw.StateTable{}`)
  in addition to the warning text — good, avoids a warn-only test that
  ignores whether rendering still works.
- **`doctest Qx.QuantumCircuit`** — newly wired at
  `quantum_circuit_state_test.exs:6`. This activates previously-dormant
  `@doc` examples (per the repo's own compounded lesson on opt-in doctests).
  Net positive; recommend confirming via `mix test` output that the doctest
  count actually increased (per the TDD Rules note in `CLAUDE.md`) since
  this review has no shell access to run it.
- **`run/2` soft-deprecation (doc-only)** — no test changes needed/expected
  since it's a documentation-only change; none found, consistent.

## Modified vs New Files

- `test/qx/barrier_dispatch_test.exs` — **modified, additive only**. New
  `describe "barrier/2 range support"` block appended; no existing test
  bodies altered.
- `test/qx/quantum_circuit_state_test.exs` — new file.
- `test/qx/draw/state_table_register_deprecation_test.exs` — new file.

No evidence of any existing test being modified in a way that would violate
the "existing tests never modified without explicit approval" TDD rule.

## Verdict

**CHANGES-REQUESTED** — one Critical (tautological test), zero Warnings,
two Suggestions.
