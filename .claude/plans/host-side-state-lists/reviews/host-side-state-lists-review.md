# Review: host-side-state-lists

**Date:** 2026-11-14
**Branch:** `fix/host-side-state-lists` vs `main` (uncommitted)
**Verdict:** REQUIRES CHANGES

Three small regressions for inputs that worked on `main`, each a few lines to
fix. No blocker, no Iron Law violation for valid input. The reviewers ran
nothing; the "Checked" column is what I ran afterwards on both the new code
and `main` (`scratchpad/edges.exs`).

## Requirements Coverage

Source: `.claude/plans/host-side-state-lists/plan.md`. 25 MET, 0 PARTIAL,
0 UNMET, 2 UNCLEAR. The two UNCLEAR rows are tasks 3.3 and 4.2: the verifier
did not re-run the full suite or the gates. They were run during the work
phase (compile, format, credo --strict clean; 1586 tests passed). ROADMAP
lines 33 and 38 are still unticked, as planned, until the merge commit.

## Findings to fix

| # | Where | Finding | Checked |
|---|---|---|---|
| F1 | `lib/qx/state_init.ex:77` | `basis_state(1, 4, nil)` returned c64 on `main` and returns s32 now. `Nx.tensor(list, type: nil)` inferred the type from the complex list; `Nx.tensor(0, type: nil)` infers an integer. Tier 2, a changed result for an input that worked. | Run: confirmed |
| F2 | `lib/qx/result_builder.ex:52` | Two outcomes with the same index rely on `Nx.indexed_put/4` keeping the last one. Nx documents repeated indices as non-deterministic (`deps/nx/lib/nx.ex:8176`). BinaryBackend does keep the last today, so the test passes, but plan decision D4 ("stays last-write-wins") is only true on that backend. Fix: collapse duplicates on the host before the scatter. | Nx doc read |
| F3 | `lib/qx/validation.ex:68` | `valid_register?/2` with a float `num_qubits` (1.0) returned `true` on `main` and raises `ArithmeticError` now. The code comment says the predicate "returns false instead of raising"; that holds for negative integers only. Tier 3, not reachable from the public API. | Run: confirmed |

## Findings to fix in text only

| # | Where | Finding |
|---|---|---|
| T1 | `CHANGELOG.md` | "`Integer.pow(2, n)` (14 sites)": 13 are `Integer.pow`, one is `Bitwise.bsl`. "The values are identical" is true for the non-negative integers every caller passes; say that. |
| T2 | `test/qx/host_side_state_lists_test.exs:2` | The `async: false` comment gives a wrong reason: a heap limit is per process and scheduler time does not affect it. |

## Reviewer claims that did not hold

- **Negative outcome key (`"-1"`) is a behaviour change** (Elixir W1,
  Iron Laws). `from_counts/3` raised `ArgumentError` for that key on `main`
  too (the classical-bits step cannot parse `"-"`), and raises
  `ArgumentError` now. No change at the function boundary. Filtering
  `index >= 0` is still a one-line hardening; optional.
- **`ghz_state_vector` is not deprecated** (Iron Laws). It is
  (`lib/qx/state_init.ex:385`).
- **`Qx.Gates` builders changed behaviour for float or negative
  `num_qubits`** (Elixir W3). They raised a raw error before and raise a
  different raw error now. Tier 3, no working input changed.

## Suggestions (optional)

- Tests: assert a value, not only the shape, in the two 2^20 tests; check
  `:c128` values; cover the all-out-of-range path to the empty branch; add an
  `after` timeout to the harness `receive`.
- Index tensor is s32. An index of 2^31 or more would not fit, which a
  20-qubit cap never reaches.

## Pre-existing (not from this diff)

- `lib/qx/gates.ex` has `iex>` examples and no `doctest Qx.Gates` directive
  anywhere under `test/` (project TDD rule 4).
- `basis_state/3` with an invalid `type` leaks a raw Nx `ArgumentError`.
- `from_counts/3` leaks raw errors for a malformed outcome key or a negative
  `num_bits`.
- The deprecated `StateInit` functions still build 2^n host lists.

## Agent reports

`elixir.md`, `testing.md`, `iron-laws.md`, `requirements.md` in this
directory; consolidated in `../summaries/review-consolidated.md`.

## Resolution (2026-11-14, after the user chose "fix directly")

**Status: all findings resolved. Verdict after fixes: PASS, pending the human's merge authorization.**
The fixes were not re-reviewed by the agents; they are covered by new tests and the full gates.

- F1 fixed: `basis_state/3` treats a nil type as c64. Test added (red before the fix).
- F2 fixed: duplicate and negative indices are removed on the host (`Map.new/1`, last wins) before `Nx.indexed_put/3`.
- F3 changed, not restored: `valid_register?/2` returns `false` for a non-integer `num_qubits`. On `main` a float such as 1.0 returned `true`; it raised after the first implementation. Test added (red before the fix).
- T1, T2 fixed. The test file is now `async: true`.
- Suggestions taken: value checks in the 2^20 tests, `:c128` values, the all-out-of-range case, a `receive` timeout.
- Not done: s64 index tensor (unreachable under the 20-qubit cap).

Gates: compile (warnings as errors), format, credo --strict clean; `mix test` 1590 passed (330 doctests, 1260 tests). New test file run 3 more times: 18 passed each time.
