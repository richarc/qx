# Review: v012-closeout

**Date:** 2026-11-14
**Branch:** `fix/v012-closeout` vs `main` (uncommitted)
**Verdict:** PASS, pending the human's merge authorization

No plan file: the change was routed as a bug fix (complexity 0–2), so there
is no requirements-coverage section. Three agents ran (elixir, testing,
iron-laws); none ran code. "Checked" is what I ran afterwards.

## Findings and resolution

| # | Source | Finding | Outcome |
|---|---|---|---|
| 1 | iron-laws (warning) | The two CHANGELOG entries for the new rejection sit under "Fixed" without a **Breaking** marker; `Qx.c_if/4` is tier 1 and `from_qasm/1` tier 2 (Iron Law #6). | Fixed: both entries marked **Breaking**. |
| 2 | testing (warning) | The remaining two-qubit `:measure -> state` arm (`lib/qx/simulation.ex`) looks unreachable. | Refuted. Checked: with the arm removed, `Qx.run/2` on `x(0) |> measure(0, 0)` raises in `apply_controlled_target_op`. The iron-laws agent traced the same path. Arm kept, comment added saying why. |
| 3 | testing | Loose message regex; QASM `line` assertion could not tell the `if` line from the measure line; no `hint` assertion; no `Qx.steps/2` case; only "gate then measure" covered. | Fixed: exact message, multi-line source (`if` on 7, measure on 9), hint asserted, steps test, measure-only body. |
| 4 | elixir (suggestion) | No test for an unbraced `if` body or the arrow form `measure q -> c`. | Fixed: both added, both pass. |
| 5 | elixir (suggestion) | `reject_measurement_in_body/1` matches the measure tuple twice. | Not changed (cosmetic). |

Tests added after the review cover behaviour that was already implemented,
so they were not red first. The original seven were written before the fix
and six of them failed.

## Confirmed by the agents (read, not run)

- No producer can still put a measurement inside a `c_if` body:
  `Qx.Operations` measurement functions all emit `{:measure, [q, c], []}`,
  `Qx.Patterns` emits no `c_if`, and the OpenQASM parser's `if` body allows
  only measure, barrier and gate statements. The internal
  `QuantumCircuit.put_instructions/2` and `add_conditional/4` bypass the
  check; they are `@doc false`.
- No existing test used `Qx.Gates.toffoli/4`, a measurement in a `c_if`
  block, or a one-qubit `:measure`.

## Pre-existing (not from this diff)

- `lib/qx/quantum_circuit.ex:229`: `circuit.measurements ++ [measurement]`
  is a quadratic append.

## Gates

compile (warnings as errors), format, credo --strict clean; `mix test`
1602 passed. `mix docs` warning count 29 before and after.
