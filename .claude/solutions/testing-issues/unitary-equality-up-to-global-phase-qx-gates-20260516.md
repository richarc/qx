---
module: "Qx.Gates"
date: "2026-05-16"
problem_type: test_failure
component: testing
symptoms:
  - "A correctly-implemented quantum gate matrix appears unequal to its reference (X/H/I/Y or a decomposition) under entrywise assert_in_delta"
  - "Statevector spot-checks via Complex.real/1 pass but give no real matrix-level guarantee of gate correctness"
  - "U(θ,φ,λ) = RZ(φ)·RY(θ)·RZ(λ) fails a naive entrywise comparison even though the gate is correct"
root_cause: logic_error
severity: medium
tags: [quantum, nx, complex, global-phase, testing, gates]
---

# Asserting quantum unitaries are equal up to a global phase

## Symptoms

When characterizing/regression-testing quantum gates in Qx, a *correct*
gate matrix fails a direct comparison against its reference:

- `Qx.Gates.u(π, π/2, π/2)` is mathematically Pauli-Y but differs from
  `Qx.Gates.pauli_y()` by an overall complex factor.
- The decomposition identity `U(θ,φ,λ) = RZ(φ)·RY(θ)·RZ(λ)` holds only
  *up to the global phase* `e^{i(φ+λ)/2}`, so an entrywise
  `assert_in_delta` on real+imag parts reports a false failure.
- Pre-existing `u_gate_test.exs` only checked `Complex.real/1` of a few
  statevector amplitudes — no matrix-level correctness guarantee.

## Investigation

1. **Hypothesis: gate is wrong** — Hand-derived `U(θ,φ,λ)` against the
   OpenQASM 3.0 / Qiskit `UGate` convention; all special cases
   (X/H/I/Y) and the RZ·RY·RZ identity are exact. Implementation is
   correct → the test method, not the gate, is the problem.
2. **Hypothesis: tolerance too tight** — Loosening `@delta` does not
   help; the discrepancy is a *rotation in the complex plane* (a phase
   factor of modulus 1), not rounding noise.
3. **Root cause found**: a global phase `e^{iα}` multiplying an entire
   state/operator is physically unobservable (it cancels in every
   measurement probability `|⟨ψ|φ⟩|²`). Two unitaries that differ only
   by such a scalar are physically identical, but **not** entrywise
   equal. Equality tests must quotient out that scalar.

## Root Cause

A global phase is an equivalence, not an error. For unitaries `A` and
`B` representing the same physical gate there exists a scalar `r` with
`|r| = 1` such that `A = r · B` entrywise. Naive comparison asserts
`A == B` (i.e. `r == 1`), which is false for any non-trivial phase.

```elixir
# False failure: correct gate, but r = e^{iπ/2} ≠ 1
assert_in_delta Complex.real(a_ij), Complex.real(b_ij), 1.0e-6
```

## Solution

Extract the phase from one well-conditioned pivot entry, then assert
every entry matches *after* dividing it out. Pick the pivot where
**both** matrices are non-negligible (guarding only the reference entry
makes the ratio blow up if the actual entry is ~0).

```elixir
@delta 1.0e-6

defp assert_unitary_equal_up_to_phase(actual, reference, message) do
  a = actual |> Nx.to_list() |> List.flatten()
  b = reference |> Nx.to_list() |> List.flatten()

  {a_ref, b_ref} =
    Enum.zip(a, b)
    |> Enum.find(fn {av, bv} ->
      Complex.abs(bv) > 1.0e-9 and Complex.abs(av) > 1.0e-9
    end)
    |> case do
      nil -> flunk("#{message}: reference matrix is all-zero")
      pair -> pair
    end

  ratio = Complex.divide(a_ref, b_ref)
  assert_in_delta Complex.abs(ratio), 1.0, @delta

  Enum.each(Enum.zip(a, b), fn {av, bv} ->
    expected = Complex.multiply(ratio, bv)
    assert_in_delta Complex.real(av), Complex.real(expected), @delta
    assert_in_delta Complex.imag(av), Complex.imag(expected), @delta
  end)
end
```

Key facts that make this work:

- `Nx.to_list/1` on a `:c64` tensor yields nested `%Complex{}` structs;
  `Complex.abs/divide/multiply/real/imag` operate on them directly.
- The decomposition matmul order: `rz(phi) |> Nx.dot(ry(theta)) |>
  Nx.dot(rz(lambda))` builds `RZ(φ)·RY(θ)·RZ(λ)` (left operand =
  leftmost/outermost operator, acts last on the state).
- `@delta 1.0e-6` is ~1 decade over f32 (`:c64`) rounding for short
  `Nx.dot` chains (≤2 sequential dots, 2×2). Relax toward `1.0e-5` for
  longer decompositions.

### Files Changed

- `test/qx/u_gate_convention_test.exs` — new characterization test:
  helper above + `U==X/H/I/Y` and RZ·RY·RZ decomposition locks.
- `lib/qx/gates.ex`, `lib/qx/operations.ex`, `lib/qx.ex` — docstrings
  now state the convention + decomposition explicitly.

## Prevention

- [x] Add to test patterns — use `assert_unitary_equal_up_to_phase/3`
      **only for gates with a free global phase** (decomposition
      identities like `U(θ,φ,λ) = RZ·RY·RZ`, parametric rotations). It
      is the right tool when an exact entrywise check yields false
      *failures*.
- [ ] Not an Iron Law (domain-specific, not a hard rule).
- Specific guidance: when testing quantum gates, compare **matrices**,
  not a handful of `Complex.real/1` amplitude spot-checks. But choose
  the comparator by the gate's phase freedom: free phase ⇒ this
  phase-tolerant helper; fixed canonical (permutation/Clifford —
  CSWAP, iSWAP, …) ⇒ **exact** entrywise equality, because
  phase-tolerance there yields false *passes* that hide sign /
  control-qubit errors. **Correction:** the earlier advice to "reuse
  this helper for qx-uos" was wrong — qx-uos (CSWAP/iSWAP) needs the
  exact comparator; see the related doc below.

## Related

- `.claude/solutions/testing-issues/exact-vs-phase-tolerant-gate-matrix-equality-qx-gates-20260516.md`
  — the complementary (no-free-phase) case: when this helper is the
  WRONG tool and exact entrywise equality is required (qx-uos outcome).
- ROADMAP v0.8 `qx-xt2` (this work); `qx-uos` was completed with the
  **exact** comparator, not this helper.
- Convention: OpenQASM 3.0 built-in `U` gate / Qiskit
  `qiskit.circuit.library.UGate` (cited by name in the three docstrings).
