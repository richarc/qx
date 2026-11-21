# Scratchpad: display-tolerance

## 2026-11-21 Origin

User asked whether a QuTiP-style `tidyup()` is worth implementing. Research
(this session): QuTiP's tidyup exists to keep sparse matrices sparse
(maintainer, qutip issue #1349: "keeping `nnz` low"); it zeroes real and
imaginary parts separately below 1e-14 (float64); auto-tidyup is contested in
QuTiP itself (#1349 open, #2744, #1831 report real values silently zeroed).
Qx states are dense float32, so there is no sparsity to protect.

DECISION (user, 2026-11-21): no state-mutating tidyup, no cleaning helper,
`get_state/1` stays raw. Do the display-only consolidation (this plan).

Not verified in that research: how Qiskit handles it (docs 404); which
QuTiP 5 operations trigger auto-tidyup.

## 2026-11-21 Measurements

Script: U then U^-1 (ry, rz per qubit and a CX chain per layer, then the
inverse), so the exact result is |0...0>.

    n  depth gates  max_residue_prob  max_residue_amp  p0
     2    10   100  4.81e-14  2.19e-7  1.00000072
     2   100  1000  2.28e-13  4.78e-7  1.00000167
     6    10   340  1.02e-14  1.01e-7  1.00000072
     6    50  1700  6.16e-14  2.48e-7  1.00000429
    10    10   580  5.51e-15  7.42e-8  1.00000095
    10    30  1740  1.00e-14  1.00e-7  1.00000501
    14    10   820  4.91e-15  7.01e-8  1.00000286

Uniform states: probability per basis state, amplitude, printed at 3 decimals

    10  9.77e-4  3.13e-2  0.031
    16  1.53e-5  3.91e-3  0.004
    18  3.81e-6  1.95e-3  0.002
    19  1.91e-6  1.38e-3  0.001
    20  9.54e-7  9.77e-4  0.001

Qubit limit is 20 (`Qx.QubitCountError` outside 1..20, quantum_circuit.ex:71).

Note p0 drifts above 1 (1.000005 after 1,740 gates): norm drift, a separate
matter handled by `renormalize:`.

## Dead ends / rejected

- One shared 1.0e-6 on probability: hides every row of a 20-qubit uniform
  state under `hide_zeros` (9.5e-7 < 1.0e-6).
- A relative threshold against the largest probability: not needed for the
  zero question, given the six-order gap; it would also hide real terms a
  million times smaller than the largest.

## Open

- D1, D2, D3 in plan.md await the user.

## 2026-11-21 Decisions (user)

- D1: leave out Dirac terms that print as 0.000 at the requested precision,
  keeping the largest when every term would.
- D2 + D3: remove the `:threshold` option of `Format.dirac_notation/2` and the
  test "respects custom threshold" (`format_test.exs:145`); reword the
  describe and comments of the Step fallback test (`step_test.exs:172`)
  without changing its assertions. No other existing test is edited.
- Start work in this session.

## 2026-11-21 Work log

- P0-T2 baseline: format_test + step_test + draw_test + draw_contracts_test
  = 89 passed (11 doctests, 78 tests).
- Design detail settled while writing tests: `significant_terms/2` returns
  `{terms, truncated?}` and takes `:max`. "Prints as zero" is judged per
  part: both |re| and |im| under half a unit of the last decimal. When every
  non-negligible term prints as zero, the (up to 4) largest are kept, in
  index order. When every term is negligible (a zero vector), the first term
  alone is kept: this preserves the existing test that expects "0.000|0⟩".

## 2026-11-21 Merge-gate review

elixir-reviewer, testing-reviewer, iron-law-judge: no blocker. None ran code.
Acted on:
- `negligible?/1` and the print check accept non-finite values (atoms from
  Nx). Checked on main: a state holding NaN already could not be displayed
  (`inspect` gave an Inspect.Error; `show/1` and the state table raised
  `ArgumentError`). This change does not make that work; it only avoids
  adding a `FunctionClauseError` ahead of it.
- `Qx.Step.show/1` doc says its Dirac string has no term limit (about a
  million terms for a 20-qubit uniform state). Not capped: `show/1` is the
  full-detail call and already returns every amplitude.
- CHANGELOG: the imaginary-part cut moved from 1.0e-6 to 1.0e-5.
- Tests: exact half-unit boundary, fallback with `:max` under four, empty
  list, zero vector through `dirac_notation/2`, a wider "no threshold of its
  own" check. The Step test's name is restored (only its describe and
  comments were approved for rewording).

Left alone, noted:
- `lib/qx/qubit.ex:722` `print_probabilities` still filters at 1.0e-6. It is
  the deprecated calc engine; switching it would print more rows there.
- Residue was measured to 14 qubits only.
- A non-finite state cannot be displayed by any surface (pre-existing).
