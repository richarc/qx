# Review — stateinit-vector-deprecation

**Verdict: PASS WITH WARNINGS → ALL FINDINGS RESOLVED**

> Post-review fixes applied (re-verified green: compile/format/credo clean,
> 245 doctests + 916 tests, 0 failures):
> - **T1** — replaced tautological delegation tests with "deprecated names
>   still produce correct results" (independent probability + sign references).
> - **T2** — `async: true` added.
> - **T3** — amplitude-sign assertions added to the canonical Bell tests
>   (`real_at/2` helper), distinguishing `:phi_plus`/`:phi_minus` and
>   `:psi_plus`/`:psi_minus`.
> - **C1** — `## Parameters` note on `ghz_state_vector` documents `num_qubits >= 2`.
> - **C2** — dropped the redundant guard on the `ghz_state` deprecated shim.
> - **C3** — zero-probability checks now use `approx_equal?(v, 0.0)`.
> - **C4** — `cond` → `if i == 0 or i == dimension - 1` in `ghz_state_vector`.
>
> Pre-existing Iron Law #7 gap (invalid Bell atom → `FunctionClauseError`)
> intentionally deferred to v0.9 when the deprecated shims are removed.

Diff: 5 files (uncommitted on `feat/stateinit-vector-deprecation`).
`lib/qx/state_init.ex` (main), `lib/qx.ex`, `lib/qx/patterns.ex` (doc-only),
`CHANGELOG.md`, `test/qx/state_init_vector_test.exs` (new).

Verification gate (run by implementer): compile `--warnings-as-errors` clean,
format clean, credo `--strict` 0 issues, `mix test` 245 doctests + 916 tests,
0 failures.

## Requirements Coverage (source: plan.md)

**15 MET · 0 PARTIAL · 0 UNMET · 4 UNCLEAR**

All four phases implemented with file:line evidence. The 4 UNCLEAR entries are
the verification-gate checkboxes (compile/format/credo/test) — the verifier
can't confirm them from code alone, but they were run green this session, so
they resolve to MET. The `:c32`→`:c128` deviation is self-consistent and
acceptable. **No requirements gap.**

## Iron Laws

- **#6 (breaking API → major bump): CLEAN.** Additive + deprecation; old names
  delegate and still work; CHANGELOG has `### Added` + `### Deprecated`. No
  major bump needed. ✅
- **#5 (host loop over 2^n): PRE-EXISTING.** `ghz_state_vector`'s
  `for i <- 0..(dimension-1)` is moved verbatim from old `ghz_state`;
  `bell_state_vector` uses hardcoded 4-element literals. Not newly introduced.
- **#7 (typed errors): PRE-EXISTING gap.** `bell_state_vector(:invalid_atom)`
  raises `FunctionClauseError`, not a typed `Qx.*Error` — same gap as the old
  `bell_state/2`. Low urgency (the `@type bell_state_which` documents the enum);
  worth resolving before v0.9 removal.
- **#8 (tolerances): OK.** The `1.0e-6` GHZ-5 norm check is feasible at float32
  (only 2 non-zero probabilities summing to 1.0). No sub-epsilon assertion.

## Findings

### Test quality (testing-reviewer) — fix before merge recommended

- **T1 — Tautological delegation tests** (`state_init_vector_test.exs:81-95`).
  Because the deprecated fn is literally `def bell_state(w, t), do:
  bell_state_vector(w, t)`, the assertion `bell_state(w) == bell_state_vector(w)`
  reduces to `x == x` — it can never fail and gives zero signal. Either assert
  the deprecated name against an independent reference (e.g. expected tensor /
  probability), or drop the block with a comment noting the one-line delegation
  is compiler-verified.
- **T2 — `async: true` missing** (`state_init_vector_test.exs:2`). Pure library,
  no shared state; the new file should run async like a leaf unit test.
- **T3 — No amplitude-sign coverage for the canonical name** (folds in the
  reviewer's "duplicate description" note). The `:phi_plus`/`:phi_minus` and
  `:psi_plus`/`:psi_minus` tests assert *identical* probabilities, so they can't
  distinguish the sign — `bell_state_vector(:phi_minus)` returning the
  `:phi_plus` tensor would still pass. The sign IS covered transitively via the
  unchanged `state_init_test.exs:263-279` (which now delegates), but the
  canonical function has no direct sign test. Add a `Nx.real` sign assertion
  (mirror `state_init_test.exs:263-279`).

### Code quality (elixir-reviewer + iron-law-judge)

- **C1 — `@spec ghz_state_vector(pos_integer(), …)` over-promises**
  (`state_init.ex` ghz_state_vector). `pos_integer()` admits `1`, but the guard
  rejects it (`>= 2`). Add a `## Parameters` line to the `@doc` stating
  `num_qubits >= 2` is required, matching `bell_state_vector` doc style.
  (Relates to Iron Law #7 gap above.)
- **C2 (SUGGESTION) — Redundant guard on `ghz_state` shim** (`state_init.ex`).
  The deprecated `ghz_state/2` shim keeps `when … num_qubits >= 2`; the
  `bell_state/2` shim has no guard. Both are pure delegators — the guard now
  lives on `ghz_state_vector`. Inconsistent with the `math.ex:225` shim pattern;
  could drop it (the canonical fn guards anyway).
- **C3 (SUGGESTION) — Mixed zero-prob assertion style**
  (`state_init_vector_test.exs:55,62,69`). Zero checks use exact `== 0.0` while
  non-zero use `approx_equal?/2`. Prefer `approx_equal?(v, 0.0)` for resilience.
- **C4 (SUGGESTION, PRE-EXISTING) — `cond` with two identical branches**
  (`ghz_state_vector`). `if i == 0 or i == dimension - 1` is shorter. Moved
  verbatim from the old code; lowest priority.

## Bottom line

No correctness bugs, no Iron Law violations, verification green, requirements
fully met. Findings are test-signal quality (T1–T3) and doc/consistency polish
(C1–C4). T1 is the most worth fixing — it's an actively misleading test that
can never fail. All fixes are small and confined to the new test file + two
doc/guard tweaks in `state_init.ex`.
