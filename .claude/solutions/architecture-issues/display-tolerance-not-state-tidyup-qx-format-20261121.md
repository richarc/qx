---
module: "Qx.Format"
date: "2026-11-21"
problem_type: architecture_decision
component: numerics
symptoms:
  - "Question raised: should Qx have an internal tidyup() like QuTiP's, zeroing small elements of a state?"
  - "Four display sites each answered 'is this amplitude zero?' with their own cut-off: 1.0e-6, 1.0e-6 and 1.0e-10 on probability, 1.0e-6 on an imaginary part"
  - "A 1.0e-6 probability cut-off hid every term of a 20-qubit uniform state (9.5e-7 each)"
root_cause: "Two different questions were being answered with ad hoc constants: 'is this value rounding residue?' (absolute, set by the float width) and 'is this term worth printing?' (depends on the precision shown). QuTiP's tidyup answers neither for Qx: it exists to keep SPARSE matrices sparse by dropping stored entries, at a float64 cut-off of 1e-14. Qx states are dense float32, so zeroing gains no storage, the cut-off would have to be eight orders coarser, and zeroing breaks the norm."
severity: low
iron_law_number: 8
tags: [tidyup, qutip, display-threshold, float32, noise-floor, measurement, dense-state, decision-record]
related_solutions:
  - ".claude/solutions/phoenix-issues/absolute-display-threshold-fails-at-scale-qx-step-20260703.md"
  - ".claude/solutions/phoenix-issues/fix-in-one-caller-leaves-sibling-callers-broken-qx-step-show-20261121.md"
  - ".claude/solutions/phoenix-issues/acos-amplifies-float32-rounding-near-pole-use-atan2-qx-draw-bloch-20261120.md"
---

# Clean numerical residue at the display boundary, never in the state

## Decision (user, 2026-11-21)

- No QuTiP-style `tidyup` that changes or returns cleaned state values.
- `Qx.get_state/1` returns raw amplitudes.
- No opt-in cleaning helper until a user asks for one.
- One definition of "zero for display" in `Qx.Format`, used by the state
  table, `Qx.Step` and Dirac notation.

Do not re-propose a state-mutating tidy step without new evidence.

## Why QuTiP's tidyup does not transfer

| | QuTiP | Qx |
|---|---|---|
| Storage | sparse (CSR, Dia) | dense `:c64` tensor |
| What tidyup buys | fewer stored entries (`nnz`) | nothing: every amplitude is stored anyway |
| Float width | float64, cut-off 1e-14 | float32, residue about 1e-7 |
| Cost of zeroing | none structurally | the state is no longer normalised |

QuTiP's own maintainers describe it as sparse hygiene, and its automatic
form is contested there: qutip issue #1349 (open) proposes removing or
disabling it because it turns "numerical imprecision into a feature";
#2744 and #1831 report real values silently becoming zero when units made
them small.

## How the floor was chosen: measure the gap

Do not pick a noise threshold by taste. Measure both sides of it.

1. **Residue.** Build U then U⁻¹, so the exact result is |0…0⟩, and read
   the largest probability on any other basis state.

   ```elixir
   # forward: ry and rz on each qubit plus a CX chain, `depth` layers;
   # then the same layers inverted, in reverse order
   [_p0 | residue] = circuit |> Qx.get_probabilities() |> Nx.to_flat_list()
   Enum.max(residue)
   ```

   2 to 14 qubits, 100 to 1,740 gates: at most **2.3e-13** (amplitude
   4.8e-7). It fell slightly with size. Not measured from 15 to 20 qubits.
2. **Smallest real value at the size limit.** A uniform state on 20 qubits
   has probability **9.5e-7** per basis state.
3. **Put the floor inside the gap.** `1.0e-10` on probability (amplitude
   `1.0e-5`): 400 times above the residue, 10,000 times below the smallest
   uniform probability.

`1.0e-6` was on the wrong side of the gap, which is the July bug.

The probability floor is on a squared quantity: an amplitude error `e` on
an empty basis state leaves `e²`. Keep the amplitude floor as its square
root (Iron Law #8, derived tolerances).

## The two questions, kept apart

```elixir
# 1. Is it residue? Absolute.
Qx.Format.negligible?(probability)          # probability <= 1.0e-10

# 2. Is it worth printing in a one-line summary? Depends on precision.
Qx.Format.significant_terms(terms, precision: 3, max: 4)
# drops residue, drops terms whose amplitude prints as all zeros, keeps the
# largest when every term would; returns {terms, cut?}
```

A relative threshold (against the largest probability) was considered and
rejected for question 1: the gap makes it unnecessary, and it would hide
real terms a million times smaller than the largest.

## Prevention

- A new display path calls `Qx.Format.negligible?/1` or
  `significant_terms/2`. `test/qx/format_tolerance_test.exs` fails if
  `step.ex` or `tables.ex` gains a small float literal of its own.
- A characterisation test keeps the residue evidence under test. It is
  short on purpose: in the test environment a circuit of about 1,000 gates
  trips the simulator's norm-drift assertion (total probability reached
  1.000005 after 1,740 gates). Norm drift is `renormalize:`'s job and is
  separate from residue.
- Before borrowing a numerical routine from another library, ask what
  storage and float width it was written for.
- A state holding NaN or infinity cannot be displayed by any surface; that
  predates this work and is not addressed by it.
