# Review: draw-state-size-cap

**Date:** 2026-11-14
**Branch:** `fix/draw-state-size-cap` (uncommitted working tree, base `main` @ 966fcb0)
**Verdict: PASS WITH WARNINGS**

No blockers. Three warnings, all in the new test file. No Iron Law
violations. No unmet requirements.

Panel: elixir-reviewer, testing-reviewer, iron-law-judge,
requirements-verifier. verification-runner was skipped because `/phx:work`
had just run the full gate (1550 tests passed; compile, format, credo
clean). Consolidated agent output:
`.claude/plans/draw-state-size-cap/summaries/review-consolidated.md`.

## Requirements Coverage

Source: Plan `.claude/plans/draw-state-size-cap/plan.md`.
**24 MET, 3 PARTIAL, 0 UNMET, 2 UNCLEAR.** The PARTIALs downgrade PASS to
PASS WITH WARNINGS.

- **MET:** D1–D9, tasks 1.1–1.5, 2.1, 2.5, 2.6, 3.2, 3.3, 3.5, 3.6, the
  Scope "Out" list (nothing there was changed), and "no existing test
  modified".
- **PARTIAL (recorded deviations; the verifier judged the intent met):**
  - 2.2: the size test is `Bitwise.bsr(size - 1, max_qubits) > 0`, not
    `size > bsl(1, max_qubits)`. Same result; a huge `max_qubits` builds no
    bignum.
  - 2.3 and 2.4: the default 12 is a module attribute in `Qx.Validation`
    (`validation.ex:6`), not in `Qx.Draw`, so `Qx.Draw.Tables` gets it
    without a new `tables → draw` edge. The literal is not repeated.
- **UNCLEAR:** 1.6 (the red run) and 3.1/3.4 (the `mix docs` baseline and
  diff). Both are scratchpad records that cannot be checked from the final
  code. They were run in the work session: red was 20/59 passing, 39
  failing; the docs warning lists were identical.

## Warnings

All three are in `test/qx/draw_size_cap_test.exs`. None is a defect in
`lib/`.

1. **Possible flake in an existing test (lines 247, 259).** The two Register
   tests emit the deprecation `IO.warn` inside `capture_io(:stderr)` in an
   `async: true` module. `test/qx/draw/state_table_register_deprecation_test.exs:9-11`
   is also async and asserts its captured stderr `== ""`. If ExUnit delivers
   stderr from other processes to every active capture, that existing test
   can intermittently see "deprecated". Not confirmed: the reviewer could
   not run code, and two full-suite runs passed. Options: move the two
   Register tests into an `async: false` module, or leave them out of this
   file and rely on the existing deprecation test plus a tensor-only cap
   test.
2. **Heap-limit harness differs from the measurement (lines 210–217).** The
   tests build the 2^20 tensor inside the heap-limited child. The control
   test (line 221) and the scratchpad measurements build it in the parent.
   If `Nx.broadcast` ever used process heap, the child would be killed and
   the test would fail with a confusing `:killed` match. This can only be a
   false fail, not a false pass. Fix: build the input before
   `run_with_heap_limit/1`.
3. **Boundary gap (lines 113–130, 140–145).** 4097 is tested only for
   `counts`. The tensor functions are tested at 8192 (and 8193 for
   `histogram`). An off-by-one at a tensor call site, or `bsr(size - 2, n)`,
   would pass. Fix: also test 4097 elements for `plot`, `histogram` and
   `state_table`.

## Suggestions

- **Message wording.** `Qx.DrawSizeError` always says "Cannot draw N
  states". For `counts/2` N is distinct outcomes. The plan (D4) fixed one
  message shape, so this is a plan-level choice. Changing it means updating
  the verbatim assertion at `draw_size_cap_test.exs:135`.
- **Test comments.** The test moduledoc names the plan slug and the
  `@guard_heap_words` comment carries a measurement date. Existing test
  files in this repo do name plan slugs; the date could go.
- **Harness.** Add an `after` clause to the `receive` in
  `run_with_heap_limit/1` for a clearer failure than an ExUnit timeout.
- **Untested paths.** Size-0 input (empty counts map), sub-cap
  non-power-of-two sizes, `max_qubits: nil` / `true`, the binary clause of
  `Qx.DrawSizeError.exception/1`.
- **CHANGELOG order.** "Changed" and "Added" sit above "Performance" and
  "Fixed". Section order only.

Filtered out as noise: missing fallback clauses in
`Qx.DrawSizeError.exception/1` and `validate_draw_size!/2` (callers pass
only integers; iron-law-judge found no reachable clause miss); facade test
names repeating the describe name.

## Iron Laws

0 violations. #1, #2, #5, #6, #7, #8 PASS; #3, #4, #9 not applicable.

- #6: CHANGELOG has a **Breaking** entry under Unreleased naming every
  affected function; `Qx.DrawSizeError` has a moduledoc and is in the
  `Qx.Error` list and the docs group. The minor version bump is left to the
  release step, as planned.
- #7: a bad `:max_qubits` raises `Qx.OptionError`; no new raw-error path.
  A malformed, non-`SimulationResult` argument now fails at the size check
  instead of slightly later, with the same error class.

## Checked by reading or running

- `bsr(size - 1, n) > 0` is equivalent to `size > 2^n`; 4096 passes and
  4097 raises (elixir-reviewer, by reading).
- The guard precedes every host-side build: `draw.ex` plot, counts,
  histogram; `tables.ex` before `build_table_data/3` (three agents, by
  reading; the three heap-limit tests, by running).
- `Bitwise.bsr` in a guard compiles: the elixir-reviewer could not confirm
  it; `mix compile --warnings-as-errors` passed in the work session.
- The requirements-verifier re-ran the new test file: 59 passed.

## Pre-existing (not in this diff)

- `lib/qx/draw/tables.ex:82` — `trunc(:math.log2(...))` and `:math.pow` per
  amplitude (separate ROADMAP item).
- `lib/qx/draw/tables.ex:88` — `1.0e-10` display threshold for `hide_zeros`.
- `lib/qx/draw.ex:183-192`, `lib/qx/draw/tables.ex:78-96` — host-side loops
  over the input, now bounded by the cap.
- `lib/qx.ex:1651` — `draw_state/2` `@spec` takes only `Nx.Tensor.t()` while
  a Register is still accepted (deprecated).
- A non-keyword `options` argument raises a raw error from `Keyword.get/3`.
- `lib/qx/step.ex:100-101` — `Qx.Step.show/1` has the same uncapped 2^n host
  build (out of scope in the plan; candidate ROADMAP line).

Full list: `summaries/review-consolidated.md`.

## Still open for the human

- **D5:** `Qx.draw_counts/2` is capped at 4096 distinct outcomes. The plan
  flagged this for confirmation. No reviewer objected.
- Downstream repos (`kino_qx`, `qxportal`) were not tested.
- Nothing is committed. The ROADMAP tick and the v0.12 intro amendment
  belong in the squash-merge commit.
