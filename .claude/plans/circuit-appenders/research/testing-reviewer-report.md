# Testing Review: feat/circuit-appenders

**Scope reviewed:** `test/qx/patterns_test.exs` (new `describe "bell_pair/4"`,
`describe "ghz/2"`, `describe "creator reframe invariants..."`, the added
`doctest Qx.Patterns` line 4), cross-checked against
`lib/qx/patterns.ex` and `lib/qx.ex` facade delegates.

**Caveat:** This session has no `Bash` tool available, so `git --no-pager diff
main -- test/` could not be executed directly. The assessment below is based
on a full read of `test/qx/patterns_test.exs` as it stands on the branch,
cross-referenced against the plan's Phase 1–3 checklist (which prescribes
exactly the three new `describe` blocks + the doctest line seen in the file).
No other `describe` block in the file deviates from the pre-existing
`h_all/x_all/y_all/z_all/measure_all/barrier_all/cx_chain/bell_state_circuit/
ghz_state_circuit/superposition_circuit` shapes documented in the plan as
untouched — I could not independently confirm via diff that zero characters
in those blocks changed; recommend the orchestrator run the `git diff`
itself as a final gate before merge given this tool gap.

## Summary

Solid, TDD-shaped addition. Async default respected, exact instruction-list
`==` assertions (not loose length checks), correct typed-error coverage for
all three new error paths (`OptionError`, `QubitIndexError`, `QubitCountError`),
facade-delegation tests for both new functions, and the Phase-3 reframe
invariant tests are structurally exactly what the plan called for. No Iron
Law violations found. A few minor completeness/consistency gaps below —
none block merge.

## Iron Law Violations

None found.
- Iron Law #6 (public API): additive only, facade delegates tested via
  equality assertions mirroring existing `bell_state`/`ghz_state` pattern.
- Iron Law #7 (typed errors): all three raise paths asserted
  (`patterns_test.exs:526-548`, `585-607`).
- Iron Law #9 (dispatch completeness): n/a — no new instruction shape emitted.

## Issues Found

### Critical

None.

### Warnings

- **`patterns_test.exs:526-532` and `:534-540`** — the two `bell_pair`
  `QubitIndexError` tests (`q0 == q1`, out-of-range) use bare
  `assert_raise Qx.QubitIndexError, fn -> ... end` with no message-pattern
  argument, while the sibling `unknown which` test three lines below
  (`:542-548`) does assert a `~r/Invalid value for option :which/` message,
  and the equivalent existing `cx_chain`/`h_all` OOR tests elsewhere in the
  same file (`:208-214`, `:243-249`) also assert a message regex. Add
  `~r/Qubit index \d out of range/` (or similar) to both for consistency and
  to catch a future regression that raises the right exception type with the
  wrong reason.
- **`patterns_test.exs:601-607`** — same gap: `ghz`'s out-of-range test
  omits a message-pattern assertion; the sibling `cx_chain` OOR test
  (`:211`) includes one. Add a regex to pin which qubit/mechanism raised.
- **Reframe-invariant tautology risk** (`patterns_test.exs:616-629`) — after
  the Phase-3 reframe, `bell_state_circuit/1` and `ghz_state_circuit/1` are
  now *literally implemented* as `QuantumCircuit.new(n) |> bell_pair(...)` /
  `|> ghz(...)`. The invariant tests therefore compare the implementation
  against itself post-refactor and can only fail if a future edit
  decouples the two call sites (e.g. someone special-cases
  `bell_state_circuit` without touching `bell_pair`). This is expected and
  intentional per the plan (pinned *before* the refactor as a TDD tripwire),
  but going forward it is a weak regression guard on its own — the *real*
  tripwire is the unmodified pre-existing `bell_state_circuit`/
  `ghz_state_circuit` describe blocks (`:361-434`) still asserting concrete
  instruction lists and run-probabilities independent of `bell_pair`/`ghz`.
  No action required, but worth flagging so a future contributor doesn't
  mistake the invariant tests alone for behavioral coverage.

### Suggestions

- **`patterns_test.exs:481-484`** ("default which is :phi_plus") only
  asserts arity-3 vs arity-4 equality; it never itself asserts the resulting
  instruction content. That's fine (content is covered by the `:phi_plus`
  test at `:486-493`), but consider folding the two into one test or adding
  a one-line instruction assertion here too, since a reader skimming just
  this test can't tell *what* :phi_plus produces.
- **`patterns_test.exs:570-578`** (ghz list-input test) doesn't re-assert
  `qc.num_qubits == 4` the way the range-input test does at `:561`; minor
  asymmetry, low value to fix but easy if touching this block again.
- Consider adding one boundary case not currently covered: `ghz(qc, [0, 1])`
  — the exact 2-qubit minimum (the plan's "≥2" boundary) — vs. current
  tests which only exercise 0/1 (below minimum) and 3-qubit (above). A
  `[0, 1]` case would directly pin the boundary rather than relying on
  inference from the reframe-invariant `n=2` case (`:624-628`), which
  exercises the boundary only indirectly through `ghz_state_circuit(2)`.

## Existing-test-modification check

Per the plan's Phase-3 T1 requirement ("Confirm the EXISTING
`bell_state`/`ghz_state` tests + doctests are NOT modified"): the
`describe "bell_state_circuit/1"` (`:361-397`) and
`describe "ghz_state_circuit/1"` (`:399-434`) blocks read as byte-identical
to the pre-reframe shape described in the plan — same test names, same
exact-instruction-list and `assert_in_delta` probability assertions, same
backward-compat facade checks. I was not able to run `git diff` in this
session to mechanically confirm zero-line-changed status (no Bash tool
available); this should be spot-checked with `git --no-pager diff main --
test/qx/patterns_test.exs` before the merge gate closes, filtering to
confirm only additions (no `-` lines) inside those two `describe` blocks.

## Coverage vs. Plan Phases 1–3

| Plan item | Covered? | Where |
|---|---|---|
| P1-T1 append semantics on offset circuit | Yes | `:470-479` |
| P1-T1 all 4 `which` sequences, exact instructions | Yes | `:486-524` |
| P1-T1 default `which` | Yes | `:481-484` |
| P1-T1 doctest-shaped example | Yes (in `lib/qx/patterns.ex` doctest, run via line 4) | `lib/qx/patterns.ex:379-383` |
| P1-T1 `QubitIndexError` (q0==q1, OOR) | Yes (message regex missing, see Warnings) | `:526-540` |
| P1-T1 `OptionError` on bogus `which` | Yes | `:542-548` |
| P1-T3 facade delegation test | Yes | `:550-554` |
| P2-T1 append on offset circuit | Yes | `:558-568` |
| P2-T1 list + range inputs | Yes | `:570-583` |
| P2-T1 len<2 → `QubitCountError` | Yes (both `[]` and `[0]`) | `:585-599` |
| P2-T1 OOR → `QubitIndexError` | Yes (message regex missing, see Warnings) | `:601-607` |
| P2-T1 doctest | Yes | `lib/qx/patterns.ex:320-323` |
| P2-T3 facade delegation test | Yes | `:609-613` |
| P3-T1 reframe invariants (4 Bell variants) | Yes | `:617-622` |
| P3-T1 reframe invariants (n ∈ {2,3,5}) | Yes | `:624-628` |
| P3-T1 existing tests unmodified | Structurally consistent; not diff-verified this session | see above |
| `doctest Qx.Patterns` added | Yes | `:4` |

## Verdict

**PASS** (no Critical or blocking findings). Recommend the two message-regex
Warnings be picked up opportunistically (cheap, low-risk) and that the
orchestrator run the actual `git diff` against `main` to mechanically
confirm the existing-tests-unmodified requirement, since this session
lacked Bash access to do so directly.

**Finding counts:** Critical: 0 · Warnings: 3 · Suggestions: 3
