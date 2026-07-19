# Scratchpad — cif-nested-chained-tests (qx-sso)

Decisions, open questions, dead-ends for the nested/chained `c_if` tests.

## Key decisions

### C1 — "Nested c_if" = rejection tests, NOT nested execution
`validate_conditional_block/1` in `lib/qx/operations.ex` does an
`Enum.each` over the captured block instructions and
`raise Qx.ConditionalError, :nested_conditionals` the moment it sees an
inner `{:c_if, _, _}`. So nesting is **unsupported by design** and the
rejection fires at *construction* time (inside the `Qx.c_if/4` call),
before any `run/2`. The qx-sso "nested" tests therefore characterize the
rejection: typed error, message, fires regardless of the inner block's
position, and at build time. If v0.8.2 ever adds nested execution, these
tests SHOULD break and force a review — that is the point of the net.

### C2 — New file, not edits to existing conditional tests
Existing conditional coverage lives in `test/qx_test.exs` ("conditional
operations") and `test/qx/operations_typed_errors_test.exs`. The TDD
hook blocks editing existing `*_test.exs`, and mixing new gap-closing
tests into those describe blocks would be churn. New dedicated file
`test/qx/conditional_operations_test.exs`, `async: true` (pure compute).

### C3 — Assert via the public `Qx.*` API
Existing nested test uses `Operations.c_if` directly. New tests drive the
public `Qx.c_if/4` (and `Qx.run/2`) so the net guards the public
contract, not an internal entry point.

## Non-overlap audit (what already exists vs. what's new)
- Exists: single-c_if true/false/value0/probabilistic; 2-chain different
  bits (teleportation, "multiple in sequence"); bare nested raises via
  `Operations.c_if`; typed-error guards (cbit/value/fn).
- New (the gap): same-cbit multi-block chains; deterministic mixed
  fire/skip chains with pinned counts; ≥3-conditional chains; a
  multi-gate conditional block that actually EXECUTES (existing
  multi-gate test only checks capture); nested rejection when inner
  `c_if` is not first / at build time / via public `Qx.c_if`.

## Open questions
- (resolved C1) Does nested mean execution or rejection? → rejection.
- None blocking.

## Implementation notes (post-work)

### Final shape — 9 tests in `test/qx/conditional_operations_test.exs`
6 chained-execution + 3 nested-rejection. All deterministic outcomes
probed and confirmed before asserting exact `result.counts`.

### Review deviations (from `/phx:review`, applied)
- **W1 (testing-reviewer):** the probabilistic-chain test originally used
  two `assert_in_delta count, 500, 150`. Those re-test the H gate's
  uniformity (not a `c_if` property) and carry a tiny false-failure risk.
  Replaced with `count_000 > 0` and `count_111 > 0` (both branches of the
  chain are exercised; empty-bucket prob ≈ 0.5^1000), keeping
  `count_000 + count_111 == shots` as the load-bearing correlation check.
  Plan §Iron-Law-notes/Phase-2/Risks still say `assert_in_delta` — the
  `count > 0` form supersedes that wording.
- **S1 (testing-reviewer):** added the complement "skip-then-fire" chain
  (`c0=0` skips, `c1=1` fires → `[0,1,1]`) to exercise the no-op branch of
  `process_conditional` as the FIRST reducer step.
- **S2 + nits:** tightened the nested-rejection regex to
  `~r/Nested conditional operations/`; added a `setup` block to the nested
  describe; renamed the triple-nesting test for naming consistency.

### Coverage
`Qx.Simulation` (93.3%) / `Qx.Operations` (84.7%) line numbers unchanged —
the conditional paths were already line-covered indirectly. This item
adds *semantic* pinning (chained execution + nested rejection), which is
its purpose; total stays 82.1%.

## Dead-ends
- (none yet)
