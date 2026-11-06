# Review: calcfast-reshape-kernels

**Branch:** `feat/calcfast-reshape-kernels` vs `main` (commits `ae2aa69`, `8dc1a8b`)
**Date:** 2026-11-06
**Agents:** elixir-reviewer, testing-reviewer, iron-law-judge, requirements-verifier (+ context-supervisor)
**Raw output:** `reviews/{elixir,testing,iron-laws,requirements}.md`, `summaries/review-consolidated.md`

## Verdict: PASS WITH WARNINGS

No blockers and no Iron Law violations. Every plan requirement is met. One small
warning is on new code (the bench header and cap are stale). The other surviving
items are suggestions about how strict the tests are, or pre-existing behaviour
that this branch keeps on purpose.

## Requirements Coverage

Source: plan `.claude/plans/calcfast-reshape-kernels/plan.md` (D1 amended to
rank-n axis slicing).
**Summary: 22 MET · 0 PARTIAL · 0 UNMET · 0 UNCLEAR** (P5-T4, this review, is excluded).
Minor notes, none of them gaps:
- The ROADMAP CalcFast line keeps its original wording ("2×2 tensor contraction") with a "done as slicing" suffix.
- The R3 comment doesn't spell out the n^k EXLA-cache growth.

## Iron Laws

None violated. The judge's notes on each law:
- **#3:** no `Nx.take`/`Nx.select`, only static slice/concat/reverse/transpose. Meets the intent.
- **#4:** BinaryBackend-portable primitives only.
- **#5:** loops run only over n axes or ≤3 qubits.
- **#8:** tolerances are 1e-6.
- **#9:** every 2q/3q producer shape has an arm and an execution test.

## Findings

### WARNING (new code)

**W1. `bench/kernels_bench.exs` header and cap are stale.** The header says
"routed through the contraction kernel". The `QX_BENCH_MAX_MATRIX_N` default of
10 now hides the gates this branch speeds up (CP/CRY/SWAP/iSWAP at n=12–16).
The cap was needed to capture the baseline. Fix: correct the wording, and
either raise the default or drop the cap. *(elixir)*

### PRE-EXISTING / BY DESIGN (no action on this branch)

**P1. `apply_single_qubit_gate(_, _, _, 1)` skips validation** (`calc_fast.ex:62`).
This matches `main` byte for byte, and D4 says to keep the head; `Qx.Simulation`
validates upstream. The only problem the branch adds is in the new `@doc`, which
says "Raises ArgumentError for an out-of-range target" without noting that the
n=1 head is exempt. Fix: one line in the doc. *(elixir, iron-law LOW, testing)*

**P2. The n>1 single-qubit path reads only the top-left 2×2 and skips `validate_2x2!`.**
This is pinned by the existing characterization test `calc_fast_test.exs:258`.
D3 forbids changing it without your approval. *(elixir)*

### Filtered out (false positives)

- "`apply_single_qubit_gate` has no invalid-input tests" and "the n=1 clause is
  never exercised." Both are covered in the unmodified `calc_fast_test.exs:44`
  and `:231–293`. *(testing)*
- "Missing `doctest Qx.CalcFast`." CalcFast has no `iex>` examples. *(testing)*

### SUGGESTION

- **S1.** `assert_raise ArgumentError` calls don't match the message, so an
  ArgumentError thrown inside Nx would also pass. Add `~r/qubit index|distinct/`
  where the host validator is the intended source. *(testing)*
- **S2.** The static guard regex only catches the `Gates.name(` call form.
  Comment stripping is line-based. Acceptable as a tripwire. *(testing)*
- **S3.** `cy`, `cz`, `crx` and `crz` run only inside the mixed 17-gate circuit.
  Adding per-kind `get_state` tests would show which gate broke. Add n=2 cases
  for CX, SWAP and iSWAP. Move `defp code_lines` out of its `describe` block. *(testing)*
- **S4.** Add a smoke test of the kernels under `Nx.Defn.jit(..., compiler: Nx.Defn.Evaluator)`.
  Optionally pin the `i` scalar's dtype in `iswap_axes`. *(elixir)*

## Out of scope (already recorded)

`Qx.Register` still builds n-qubit matrices. `Qx.Gates.toffoli/4` is dead legacy
code. `:preferred_cli_env` is deprecated. See the scratchpad and ROADMAP.
