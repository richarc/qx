# Iron Law Report: display-tolerance

Checked laws #5, #6, #7, #8 (as asked) by reading only. Nothing was run.
Result: no BLOCKER. 0 critical, 1 WARNING (#7), 2 SUGGESTIONs (#8, #6).

## #8 Tolerance feasibility and derived quantities: PASS (SUGGESTION on wording)

Verified at lib/qx/format.ex:49-63 and scratchpad "Measurements".

- The probability floor is a classifier for display, not a target Qx must reach. The law forbids asserting a norm or equality below about 1e-6 that float32 cannot hit. Here the floor sits above the float32 residue, so it is reachable.
- It is a tolerance on a derived quantity: p = |a|². For a true-zero term, the amplitude error e becomes p ≈ e², and the 2·eps·|a| cross term vanishes because a ≈ 0.
- Measured: the amplitude residue is at most 4.8e-7 (about 4 eps). Squared, that is 2.3e-13, which matches the scratchpad's 2.28e-13 maximum. So the 2.3e-13 figure is the propagated error, not luck.
- The floor of 1.0e-10 is the amplitude 1.0e-5, about 80 eps. That is a 21x margin in amplitude and 400x in probability.
- For a real term at the floor (|a| = 1e-5), the error is 2·eps·|a| ≈ 2.4e-12, far below 1e-10. The decision does not flip on propagated error.
- @noise_floor_amplitude (1.0e-5, format.ex:63) is the same floor in amplitude space, so the imaginary-part cut agrees with the probability cut.
- The upper side holds: 9.5e-7 is the smallest uniform probability at the 20-qubit limit (quantum_circuit.ex:71 limit per scratchpad), 10,000x above the floor.
- Each Step path computes probability from a float32 tensor via Math.probabilities. Values near 1e-10 are far from the f32 underflow range, so they are representable. tables.ex:79 computes in float64 from f32 amplitudes.

SUGGESTIONS:
1. The number 1.0e-10 is literally the example the law calls unreachable (AGENTS.md:397). The format.ex:49-63 comment justifies it with measurements, which the law asks for. Add one sentence saying this is a floor on a squared quantity (amplitude-equivalent 1.0e-5, about 80 eps) and not a norm or equality target. Otherwise a later reader or audit will flag it.
2. The measurements reach 14 qubits at depth. The tests (format_tolerance_test.exs:336) run only 2 and 6 qubits. Nothing was measured at 15-20 qubits. Per-term residue should not grow with n, but this is an extrapolation. Mention it in the comment or scratchpad.

## #6 Public API surface: PASS, patch-safe

- Tier 3: `Qx.Format` is @moduledoc false. Removing `:threshold` from `dirac_notation/2` (format.ex:169, 218) is not a covered break. The other callers are lib/qx/step.ex:89, step.ex:157 and lib/qx/register.ex:774 (tier 3). None passes `:threshold`; grep found no caller in lib/ or test/ that does.
- `Qx.Step.show/1` and Inspect keep their names, arities and return shapes. step.ex has no documented numeric contract on the string (no `1.0e-6` or threshold text remains in lib/qx/step.ex). This is a presentation fix. The patch-release rule (patches must never break) is not violated, because the string was never a specified format.
- CHANGELOG [Unreleased] records it:
  - `### Changed` covers amplitudes in 0.0005-0.001 now printing.
  - `### Fixed` covers the 20-qubit uniform state no longer shown as `0.000|00…0⟩`.
- Check of the claim "nothing that printed before has gone": a term with p > 1e-6 has |a| > 1e-3, so its larger part is at least 7e-4, which is at least the half unit 5e-4. It still prints at the default precision. The claim holds for Step.show and Inspect, which use the default precision.
- Unrecorded behaviour change (SUGGESTION): format_term now cuts the imaginary part at 1.0e-5 (format.ex:213, was 1.0e-6). An amplitude such as 1.0+5e-6i printed as `(1.000+0.000i)` before and prints `1.000` now (test at format_tolerance_test.exs:464 asserts it). Add a half line to `### Changed`.
- Also unrecorded: the table's `hide_zeros` cut is unchanged at 1.0e-10 in value but is now routed through `negligible?/1` (`<=` instead of `>`). No behaviour change except at exactly 1.0e-10.

## #5 Host-side passes over 2^n amplitudes: PASS (pre-existing, mild extra constant factor)

- Law #5 is written for Nx kernels (`lib/qx/calc*.ex`, `defn`). This is display code at the host boundary.
- Pre-existing:
  - step.ex:99-109 (`basis_terms/1`) did Nx.to_flat_list twice, zip, with_index and map.
  - The old Inspect dirac did Enum.filter, and its fallback `top_terms` did Enum.sort_by over all 2^n terms.
  - tables.ex:78-97 builds a term per amplitude before filtering (comment at tables.ex:62-65).
  - tables.ex is guarded by `validate_draw_size!` at tables.ex:65.
- New in the diff:
  - `significant_terms` (format.ex:100-115) is two filter passes (Enum.reject, then Enum.filter), against one before. It is O(2^n) with a small constant, not a new complexity class.
  - The sort over all present terms in `largest/2` (format.ex:137-149) runs only when printable == [] (every term prints as zero). That is the same condition as the old `{[], _}` fallback, and the old fallback sorted all terms too. It now sorts `present` (a subset of all terms), twice, still only on the uncommon path. No sort on the common path.
- Inspect calls `significant_terms` and then `dirac_notation/2`, which calls it again, but on at most 4 terms (step.ex:155-157). The second call is trivial. I traced the fallback case: the shown terms re-enter `largest` and return the same 4 in the same order, so the output is stable.

## #7 Typed error paths: WARNING, a new untyped raise on non-finite input (LIKELY)

- `negligible?/1` at format.ex:73 has `when is_number(probability)`. Nx returns NaN and Infinity to the host as the atoms `:nan`, `:infinity`, `:neg_infinity` from to_flat_list.
- Before: `prob > 1.0e-10` with an atom was true by Erlang term order (atom > number), with no raise.
- After: the call raises `FunctionClauseError` (format.ex:73) for these atoms. Call sites:
  - Inspect and `Step.show/1`, via significant_terms (format.ex:105). Probabilities come from `Nx.to_flat_list(step.probabilities)` at step.ex:101, so they can be atoms.
  - `Qx.draw_state(hide_zeros: true)` at tables.ex:88. There the probability is `:math.pow(Complex.abs(amp), 2)` (tables.ex:79), a float. For a NaN amplitude, Complex.abs on atom parts would already raise earlier (not verified, I did not read the Complex dependency), so this path is probably pre-existing.
- Is it a regression for Step/Inspect? Partly. A NaN amplitude reaching format_term would already have raised `ArgumentError` from `abs(:nan)` (old format.ex `abs(im) < 1.0e-6`). The new code raises earlier, in `negligible?/1`, and also in `prints?` (format.ex:119-123, `abs(re)`). The old code skipped a NaN-probability term only if the sort or filter excluded it, which it did not. So the old Inspect path raised on NaN as well, just from a different place. I did not run it. Treat as LIKELY, not DEFINITE.
- Law #7 says public functions raise typed `Qx.*Error` and must not leak raw Nx or Complex errors. `inspect/1` on a state containing NaN raising FunctionClauseError is a worse failure for a debugging aid. Inspect is also called from error messages and the REPL.
- Fix, either of:
  - (a) Add a clause `def negligible?(_non_finite), do: false` (a non-finite probability is not negligible, so it is shown, matching the old `>` behaviour). Then `prints?`/`parts` also need to tolerate atoms, or the term-printing must accept it.
  - (b) Validate at the boundary (Qx.Validation) and raise a typed error with a message about non-finite amplitudes.
  Option (a) keeps Inspect from crashing. Add a test with `Nx.tensor([Nx.Constants.nan(), 0.0])`-style input for Step and `draw_state(hide_zeros: true)`.

## Summary
Checked 4 of 26 Iron Laws: 1 WARNING (#7), 2 SUGGESTION-level notes (#8 wording and 15-20 qubit measurement gap, #6 unrecorded imaginary-part cut change).
