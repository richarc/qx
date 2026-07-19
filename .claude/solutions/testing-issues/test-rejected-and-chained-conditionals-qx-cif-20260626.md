---
module: "Qx.Operations.c_if"
date: "2026-06-26"
problem_type: test_characterization
component: testing
symptoms:
  - "Chained / nested c_if conditionals had only single-block and structural coverage; no test pinned multi-block execution semantics or the nested-rejection contract"
  - "Nested c_if raises `** (Qx.ConditionalError) Nested conditional operations are not supported` — at circuit-build time, before any run/2"
  - "A multi-gate conditional block was tested only for capture (instruction shape), never executed end-to-end"
root_cause: "c_if executes shot-by-shot and nesting is rejected by design in validate_conditional_block/1; neither contract was pinned, leaving the v0.8.2 simulation refactor unprotected"
severity: medium
tags: [c-if, conditional, characterization-test, deterministic-counts, build-time-rejection, simulation, shot-by-shot]
related_solutions:
  - ".claude/solutions/testing-issues/characterize-unvalidated-nx-kernels-regression-net-calcfast-20260626.md"
---

# Testing a rejected feature (nested c_if) and chained conditional execution

## Symptoms

`Qx.c_if/4` (classical-bit-conditioned gate application) was covered only
by single-block execution tests and structural "instruction was captured"
tests. Two contracts had no regression net before the v0.8.2 simulation
refactor:

- **Chained** conditionals — several `c_if` blocks in one circuit,
  executed shot-by-shot. No test pinned same-classical-bit chains,
  deterministic mixed fire/skip ordering, ≥3-conditional chains, or a
  multi-gate block actually *running* (the existing multi-gate test only
  asserted the captured instruction shape).
- **Nested** conditionals — a `c_if` inside a `c_if`. This is
  **unsupported by design**: it raises
  `** (Qx.ConditionalError) Nested conditional operations are not supported`
  at *construction* time, before any `run/2`.

## Investigation

1. **Does "nested c_if" mean nested execution or rejection?** —
   `validate_conditional_block/1` (`lib/qx/operations.ex`) does an
   `Enum.each` over the captured block and
   `raise Qx.ConditionalError, :nested_conditionals` on any inner
   `{:c_if, _, _}`. So nesting is rejected at build time. "Nested tests"
   are therefore *rejection / characterization* tests — testing that the
   feature is correctly refused, not that it works.
2. **How do chained conditionals execute?** — shot-by-shot via
   `run_with_conditionals/3` → `execute_single_shot/2`, with
   `process_conditional/8` firing a block iff
   `Enum.at(cbits, cbit) == value`. Deterministic circuits (fixed measured
   outcomes) therefore yield a single `result.counts` key with all shots.
3. **Confirm before asserting.** — Probed every deterministic circuit in
   `mix run` and read back `result.counts` *before* writing the assertion,
   rather than predicting amplitudes by hand.

## Root Cause

Two distinct contracts were implicit. (a) Conditional execution is a
shot-by-shot reduction threading `{state, cbits, count}`; chained blocks
and the no-op (skip) branch are ordinary reducer steps, so their
correctness is observable only through measured `counts`. (b) Nesting is
deliberately refused at the API boundary — a typed `Qx.ConditionalError`
raised while building the circuit. Neither was pinned, so a refactor
could silently change firing order, drop a skipped block's state
threading, or start *accepting* nested blocks without a test failing.

## Solution

A new `test/qx/conditional_operations_test.exs` (`async: true`) driving
the public `Qx.c_if/4` + `Qx.run/2`. Two reusable techniques:

**1. Deterministic conditional circuits → assert exact `counts`.** Force
known measured bits with `Qx.x` + `Qx.measure`, then assert the whole map:

```elixir
test "mixed chain: one block fires, the next is skipped (deterministic)" do
  # c0 = 1 (fires X q2), c1 = 0 (skips) → q2 ends |1⟩.
  qc =
    Qx.create_circuit(3, 3)
    |> Qx.x(0)
    |> Qx.measure(0, 0)
    |> Qx.measure(1, 1)
    |> Qx.c_if(0, 1, fn c -> Qx.x(c, 2) end)
    |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)
    |> Qx.measure(2, 2)

  assert Qx.run(qc, 100).counts == %{[1, 0, 1] => 100}
end
```

Test BOTH orderings (fire→skip and skip→fire) so the no-op branch is
exercised as both the first and the second reducer step. For a multi-gate
block, choose an outcome that only the full block produces (`[1,1,1]`,
where a single gate would leave `[1,1,0]` or `[1,0,1]`).

**2. Characterize a rejected feature at build time** — assert the raise
fires inside the `c_if` call, with no `run/2`, and tighten the message:

```elixir
test "a bare c_if inside a c_if block raises at build time (no run needed)", %{qc: qc} do
  assert_raise Qx.ConditionalError, ~r/Nested conditional operations/, fn ->
    Qx.c_if(qc, 0, 1, fn c ->
      Qx.c_if(c, 1, 1, fn inner -> Qx.x(inner, 2) end)
    end)
  end
end
```

Cover nesting that is *not* the first gate in the block (pins the
`Enum.each`-over-all-instructions, not just the head) and triple nesting.

**For probabilistic chains**, assert the *structural* invariant, not the
distribution: `count_000 + count_111 == shots` (perfect correlation —
no partial outcome) plus `count > 0` on each bucket (both branches occur;
empty-bucket probability ≈ 0.5^shots). Do NOT re-assert the H gate's
uniformity with a tight `assert_in_delta` — that tests the wrong unit and
risks flakiness.

### Files Changed

- `test/qx/conditional_operations_test.exs` — new file, 9 tests (commit `ce21337`)
- `ROADMAP.md` — ticked qx-sso under v0.8.1

## Prevention

- [x] Add to test patterns — recipe captured here.
- Specific guidance:
  - When a feature is *rejected by design*, write the regression net as
    build-time `assert_raise` on the typed error, and say so in the test
    name. If a later refactor adds the feature, the test SHOULD break and
    force a review — that is the contract.
  - For shot-by-shot stochastic engines, force determinism (known measured
    bits) and assert the whole `counts` map; reserve statistics for genuine
    superposition and assert structural invariants there, not tight bands.
  - Probe the real output in `mix run` and read it back before asserting —
    don't hand-predict (same discipline as the CalcFast net).
  - Cover both orderings of an asymmetric branch (fire→skip and
    skip→fire); one ordering leaves a reducer branch untested.

## Related

- `.claude/solutions/testing-issues/characterize-unvalidated-nx-kernels-regression-net-calcfast-20260626.md` — sibling pre-v0.8.2 characterization net (CalcFast kernels); same "probe then pin" discipline
- ROADMAP v0.8.1 qx-sso
