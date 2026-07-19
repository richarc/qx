# Plan: counts-contract — counts keys become the documented strings

**Slug:** counts-contract
**Branch:** `fix/counts-contract` (created from `main`)
**Status:** REVIEW PASS — awaiting human squash-merge
**Origin:** api-consistency-review finding R-01 (critical) + R-14
**Complexity:** bug fix vs documented contract (score 2: 3 files core
+ test updates, follows existing pattern). Direction decided by Craig
2026-07-04: **strings**, matching the documented contract, Qiskit
convention, and the Hardware path (QPU counts are already
string-keyed — the simulator is the outlier).
**Test-change approval:** granted by Craig 2026-07-04 ("approval to
change tests") — the ~28 list-key assertions are being migrated to the
new contract, not weakened. TDD rule 2 satisfied.

## Contract

`SimulationResult.counts` keys are binary strings, classical bit 0
leftmost (`Enum.join(bits)` — identical to the labels `draw_counts`
already renders, so charts don't change). `classical_bits` stays a
list of bit-lists, as its type honestly declares.

## Phase 1: tests first (fail before fix)

- [x] Migrate list-key assertions to string keys (~28 sites):
      `test/qx_test.exs`, `conditional_operations_test.exs`,
      `partial_measurement_test.exs`, `barrier_dispatch_test.exs`,
      `result_builder_test.exs`, `simulation_renormalization_test.exs`,
      `validation_test.exs`, `operations_basis_measurement_test.exs`,
      `simulation_steps_test.exs` (+ any found by grep)
- [x] New seam test: real `Qx.run/2` output fed to every
      `SimulationResult` helper (`most_frequent`, `outcomes`,
      `probability` with a string arg, `filter_by_probability`) — the
      producer-derived-fixture lesson from R-01
- [x] Wire `doctest Qx.SimulationResult` (+ `Qx.Simulation`, `Qx.Step`
      if example-stable); fix the stochastic moduledoc example in
      SimulationResult to assert a stable property
- [x] Confirm: suite FAILS on the migrated assertions + doctests
      (proves the fix is observable)

## Phase 2: the fix

- [x] `lib/qx/simulation.ex`: both producer sites
      (`perform_measurements` ~:627, `run_with_conditionals` ~:180)
      → `Enum.frequencies_by(classical_bits, &Enum.join/1)`
- [x] `@typep counts` → `%{optional(String.t()) => pos_integer()}`
- [x] Check `lib/qx/result_builder.ex` for a counts path; align if any
- [x] Delete the now-dead `is_list` heads of `counts_key_to_label` in
      `lib/qx/draw/vega_lite.ex` AND `lib/qx/draw/svg/charts.ex`
      (Iron Law #9 hygiene: no unproducible special-case arms)
- [x] Full suite green

## Phase 3: docs + changelog

- [x] Verify `Qx.run/2` + `Qx.Simulation.run/2` `## Returns` wording
      now true; `SimulationResult` docs/doctests true by execution
- [x] CHANGELOG `[Unreleased]` **loud** entry: behaviour change for
      anyone pattern-matching list keys; docs always promised strings;
      hardware results already used strings
- [x] Cross-repo note: kino_qx renders via `Qx.Draw.plot_counts` only
      (no key matching — verified by grep 2026-07-04); qxportal
      tutorials print counts raw in 2 cells, output cosmetically
      improves. No downstream code change.

## Phase 4: verify + merge gate

- [x] `mix compile --warnings-as-errors && mix format --check-formatted
      && mix credo --strict && mix test`
- [x] Review (elixir-reviewer + testing-reviewer + iron-law-judge):
      PASS / PASS-with-warnings x2, all warnings fixed in-branch
      (examples migration, measurement-order rewording, seam-test
      tightening). Human authorizes squash-merge
- [x] ROADMAP: release-blocking item added to the v0.10 section
      (tick it in the squash-merge commit); ships **in** the v0.10
      release
