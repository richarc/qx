# Elixir Review: feat/circuit-appenders

## Summary
- **Status**: Approved (minor doc-polish suggestions only)
- **Issues Found**: 2 (0 critical, 0 warnings, 2 suggestions)

Reviewed `lib/qx/patterns.ex` (`bell_pair/4`, `ghz/2`, reframed
`bell_state_circuit/1` / `ghz_state_circuit/1`) and `lib/qx.ex`
(`Qx.bell_pair/4`, `Qx.ghz/2` facade delegates) against `main`, cross-checked
against the plan (`plan.md`) and scratchpad decisions.

## Critical Issues
None.

## Warnings
None.

## Suggestions

1. **`lib/qx/patterns.ex:74` (`bell_pair`/`ghz` short-list error message is
   misleading), severity: suggestion**

   `ghz(c, [])` / `ghz(c, [0])` raise `Qx.QubitCountError, {len, 2, 20}`,
   which renders as `"Invalid qubit count: 0 (must be between 2 and 20)"`.
   `ghz/2` has no upper bound of 20 anywhere in its own logic — 20 is
   `QuantumCircuit.new/1`'s circuit-size ceiling, unrelated to the length of
   the `qubits` list `ghz/2` is appending over (a caller could legitimately
   pass a 30-element list onto an existing 30-qubit circuit and it would
   work fine). The message implies a constraint that doesn't exist for this
   call site.

   This was a deliberate, documented scratchpad trade-off (reusing the
   existing `{count, min, max}` `QubitCountError` shape rather than adding a
   new exception variant), so not a blocker — but worth a one-line note
   or a dedicated message via the `is_binary(message)` `exception/1` clause
   so future readers of the error text aren't misled:

   ```elixir
   # Current
   raise Qx.QubitCountError, {0, 2, 20}

   # Clearer (bypasses the borrowed min/max wording)
   raise Qx.QubitCountError, "GHZ needs at least 2 qubits, got #{length}"
   ```

2. **`lib/qx/patterns.ex:63-69` (`@typedoc qubits/0` usage list is now
   stale), severity: suggestion**

   The moduledoc for `@type qubits` enumerates its callers: `h_all`,
   `x_all`, `y_all`, `z_all`, `measure_all`, `barrier_all`. `ghz/2` (added
   this branch) also takes `qubits()` as its second argument but isn't
   listed, so a reader skimming the typedoc won't discover `ghz/2` uses the
   same type.

   ```elixir
   # Current
   Used as the second argument to the `/2` form of `h_all`, `x_all`, `y_all`,
   `z_all`, `measure_all`, and `barrier_all` to select a sub-register.

   # Suggested
   Used as the second argument to the `/2` form of `h_all`, `x_all`, `y_all`,
   `z_all`, `measure_all`, `barrier_all`, and `ghz` to select a sub-register
   (or, for `ghz`, the ordered qubit sequence).
   ```

## Verification of key claims

- **Byte-identical reframe**: confirmed. `bell_state_circuit/1` collapsed to
  a single-clause delegate to `bell_pair/4` (patterns.ex:434-437);
  `ghz_state_circuit/1` keeps its own `n >= 2` guard clause and both
  `QubitCountError` fallback clauses unchanged (patterns.ex:443-457), only
  the happy-path body now calls `ghz/2`. The pre-existing
  `bell_state_circuit/1`/`ghz_state_circuit/1` describe blocks in
  `test/qx/patterns_test.exs:361-434` are untouched (verified against
  current file — no edits to existing assertions), and new invariant tests
  (`patterns_test.exs:617-627`) pin `bell_state_circuit(w) ==
  bell_pair(new(2), 0, 1, w)` and `ghz_state_circuit(n) == ghz(new(n),
  0..(n-1))` for all variants/n — this is exactly the tripwire the plan
  calls for.
- **Pattern-matching/function-head style**: consistent with the rest of the
  module — `bell_pair/4` uses the same "bare default-arg head, then guarded
  clauses" idiom as `ghz_state_circuit/1` and `h_all/1,2`; the final
  catch-all `bell_pair(%QuantumCircuit{}, _q0, _q1, which)` clause correctly
  still pattern-matches the struct (doesn't silently accept non-circuit
  input).
- **@spec/@doc completeness**: both new public functions (`Patterns.bell_pair/4`,
  `Patterns.ghz/2`) and both facade delegates (`Qx.bell_pair/4`, `Qx.ghz/2`)
  have `@spec` + `## Parameters`/`## Returns`/`## Raises` + a doctest,
  matching the house style and the target signatures in the plan.
- **Typed-error contract**: `Qx.OptionError` and `Qx.QubitCountError`
  `exception/1` clauses (`lib/qx/errors.ex:158-179`, `453-479`) match the
  tuple shapes used (`{:which, which, hint}`, `{count, min, max}`,
  `{:not_an_integer, value}`) — no raw exception leaks across the boundary.
- **CHANGELOG**: `[Unreleased]` **Added** entry present and accurate
  (no version bump, matches non-breaking/additive framing).

No correctness bugs found in the appended gate sequences (verified against
the table in the plan: `:phi_plus`→`h,cx`; `:phi_minus`→`x,h,cx`;
`:psi_plus`→`x(q1),h,cx`; `:psi_minus`→`x(q0),x(q1),h,cx`; `ghz`→`h(first) |>
cx_chain`).
