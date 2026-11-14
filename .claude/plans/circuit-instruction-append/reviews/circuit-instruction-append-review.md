# Review: circuit-instruction-append

**Date:** 2026-11-14 · **Branch:** `fix/circuit-instruction-append` · **Cycle:** 1
**Panel:** elixir-reviewer, testing-reviewer, iron-law-judge,
requirements-verifier (reports in this directory; compressed in
`../summaries/review-consolidated.md`).

## Verdict: PASS WITH WARNINGS

No blockers. Four warnings were raised; two are fixed, two are not adopted
and are left for the user (reasons below). Verification after the fixes:
compile `--warnings-as-errors`, format, credo `--strict` clean; `mix test`
1,572 passed (330 doctests, 1,242 tests).

## Requirements Coverage

31 MET · 1 PARTIAL · 0 UNMET · 2 UNCLEAR.

- PARTIAL, D8: the complexity test uses marginal reductions for gates
  50,001–100,000, not the plan's first choice (whole build, 20,000 gates),
  which gave only 42× separation. Recorded in the scratchpad; the 10× margin
  holds on both sides (1,654 before, limit 140, 8.64 after).
- UNCLEAR, 4.1/4.3 and 4.5: the verifier did not re-run `mix docs` or the
  full gate. Both were run in the work phase and the gate again after the
  review fixes.

## Iron Laws

0 violations. #2, #5, #6, #7, #9 pass; #1, #3, #4, #8 not applicable. Note
from the judge: Unreleased now holds two breaking changes, so the release
must be 0.12.0.

## Warnings

| # | Finding | Raised by | Status |
|---|---|---|---|
| W1 | `examples/openqasm/round_trip.exs:19,29,69` and `examples/openqasm/import_gate_definition.exs:47` still read `.instructions` (`KeyError`) | all three code reviewers | **Fixed.** `round_trip.exs` runs to completion. The work-phase grep missed them because its output was cut by `head -20`. |
| W2 | Complexity test depends on how ERTS charges reductions for `++`, measured on OTP 29 only; suggests a late/early ratio under 2 | testing | **Not adopted.** A ratio was measured in task 1.5 and rejected: it separates old from new by less than the absolute limit does. The OTP-version dependence is real and is a known limit of the test. |
| W3 | `assert` inside `Task.async` | testing | **Fixed.** The task returns the numbers; assertions run in the test process. |
| W4 | Only `Qx.h/2` is measured; other producers are not | testing | **Not adopted.** A mix of `h`, `cx`, `ccx`, `barrier` costs 19.5 reductions per gate on the new code, which leaves 7.2× under the limit of 140, below the plan's 10× rule. All six producers share the same prepend expression. `add_measurement` still appends to `measurements` (plan D6, open for the user). |

## Suggestions (not acted on)

- Test file: SVG regex is brittle; QASM round-trip assertion cannot see a
  reversal on both sides; no mixed `from_qasm` source; `@tag timeout`
  larger than needed; comments carry measurement history.
- Docs: `lib/qx.ex:1885` uses `depth/1` to print a gate count;
  `lib/qx/operations.ex:909` is a long example line.

## Pre-existing

- `lib/qx/quantum_circuit.ex:231`: `measurements ++ [measurement]` (D6).
- `examples/openqasm/import_gate_definition.exs` exits 1 at line 44 on
  `main` as well: generated code resolves `Qx` as `Demo.UserGates.Qx`.
  Unrelated to this change.

## Existing tests

All eight files checked hunk by hunk by the testing reviewer and the
requirements verifier: access-path changes only, no expected value changed.
