---
module: "Qx.Gates"
date: "2026-05-16"
problem_type: test_failure
component: testing
symptoms:
  - "A wrong control qubit or a +i↔−i sign error in CSWAP/iSWAP would still PASS an `assert_unitary_equal_up_to_phase/3` matrix-equality test"
  - "Prior solution doc advises 'use the phase-tolerant helper for ANY gate matrix, reuse for qx-uos' — applying it to CSWAP/iSWAP defeats the test's whole purpose"
  - "Two sibling matrix builders represent the SAME concept differently: `Gates.iswap/3` returns `:c64 {2ⁿ,2ⁿ}` but `Gates.cswap/4` returned a real `{2ⁿ,2ⁿ,2}` split tensor, so no single equality helper worked for both"
root_cause: logic_error
severity: medium
tags: [quantum, nx, complex, global-phase, testing, gates, permutation, cswap, iswap]
related_solutions:
  - ".claude/solutions/testing-issues/unitary-equality-up-to-global-phase-qx-gates-20260516.md"
---

# Exact vs up-to-global-phase: choosing the right gate-matrix equality test

## Symptoms

While adding matrix-equality tests for `Gates.cswap/4` / `Gates.iswap/3`
(ROADMAP qx-uos), the prior solution doc
(`unitary-equality-up-to-global-phase-qx-gates-20260516.md`) said, in its
Prevention section:

> use `assert_unitary_equal_up_to_phase/3` for **any** gate/operator
> matrix equality, never raw entrywise `assert_in_delta` on complex
> matrices … Reuse this helper for sibling ROADMAP item **qx-uos**.

Following that literally would have made the qx-uos tests **worthless**:
the entire point of qx-uos is to catch a wrong control qubit or a
`−i` instead of `+i` phase. A global-phase-tolerant comparison divides
out a unit-modulus scalar `r` before comparing — and `−i = e^{−iπ}·(+i)`,
so a sign-flipped iSWAP is "equal up to phase" to the correct one. The
phase-tolerant helper would *absorb the exact bug the test exists to
detect.*

A second obstacle: `Gates.iswap/3` returned a `:c64 {2ⁿ,2ⁿ}` tensor but
`Gates.cswap/4` returned a real `{2ⁿ,2ⁿ,2}` real/imag-split tensor — the
same mathematical object in two incompatible Nx representations, so one
equality helper could not serve both.

## Investigation

1. **Hypothesis: reuse the phase-tolerant helper as the prior doc says**
   — Rejected. CSWAP and iSWAP are *fixed canonical* matrices (a real
   0/1 permutation, and a permutation with a hard-coded `+i`). They have
   **no free global phase** to quotient out: the convention pins every
   entry's value *and sign* exactly. Phase-tolerance here is not
   leniency, it is blindness to the failure mode under test.
2. **Hypothesis: keep cswap's `{2ⁿ,2ⁿ,2}` repr, write a split-tensor
   comparator** — Rejected as accidental complexity. `Gates.cswap/4`'s
   only consumer was its own doctest (simulation routes `:cswap`
   through `Qx.CalcFast.apply_cswap`, a `defn` kernel, not the matrix
   builder), so normalizing the representation was low blast-radius.
3. **Resolution**: normalize `cswap/4` to `:c64 {2ⁿ,2ⁿ}` (mirror the
   existing `iswap/3`), then assert **exact** entrywise equality with a
   tight delta (`1.0e-12`) against an independently hand-built
   reference.

## Root Cause

The reusable knowledge is a **decision rule**, not a bug:

> The global-phase-tolerant comparator and exact entrywise comparison
> are not "loose vs strict" versions of one check — they test different
> properties. Pick by whether the gate has a **free global phase**.

- **Free global phase exists** (e.g. a decomposition identity like
  `U(θ,φ,λ) = RZ(φ)·RY(θ)·RZ(λ)`, which is correct only up to
  `e^{i(φ+λ)/2}`): a global phase is physically unobservable, so an
  exact entrywise check yields *false failures*. Use
  `assert_unitary_equal_up_to_phase/3`.
- **No free global phase** (a fixed canonical matrix fully pinned by a
  named convention: permutation/Clifford gates — X, CNOT, SWAP, CSWAP,
  iSWAP, …): the convention fixes every entry's sign. A phase-tolerant
  check yields *false passes*, silently absorbing sign / control-qubit
  errors. Use exact entrywise equality.

The prior doc's "use it for **any** gate matrix" over-generalized from
a free-phase case to all cases.

## Solution

Normalize the representation, then compare exactly.

```elixir
# lib/qx/gates.ex — cswap/4 now mirrors iswap/3's :c64 {2ⁿ,2ⁿ} repr
for i <- 0..(state_size - 1), reduce: Nx.eye(state_size, type: :c64) do
  acc ->
    # ... MSB bit math unchanged ...
    if control_bit == 1 and ta_bit != tb_bit do
      acc
      |> Nx.put_slice([i, i], Nx.tensor([[0]], type: :c64))
      |> Nx.put_slice([i, j], Nx.tensor([[1]], type: :c64))
    else
      acc  # non-swap rows keep the identity seed
    end
end
```

```elixir
# test — EXACT, shape-checked first; reference built independently
# of Qx.Gates so the test is not a tautology.
#
# NOTE (2026-06-15 revision): the original commit used `@delta 1.0e-12`
# which was an Iron-Law-#8 violation — :c64 is float32-complex with
# ε ≈ 1.2e-7, so 1e-12 is 5 decades below the floor. It passed only
# because every entry of the cswap/iswap permutation matrix is
# exactly representable in float32 (0, 1, ±i). Widened to 1.0e-6 in
# `fix/c64-tolerances` (commit 4080e1c). Detection sensitivity is
# unchanged: wrong-control-qubit / ±i sign-flip bugs produce O(1)
# deltas, ~6 decades above the new threshold. See:
# .claude/solutions/testing-issues/widen-c64-test-tolerances-iron-law-8-20260615.md
@delta 1.0e-6

defp assert_complex_matrix_equal(actual, expected, message) do
  assert Nx.shape(actual) == Nx.shape(expected),
         "#{message}: shape #{inspect(Nx.shape(actual))} != #{inspect(Nx.shape(expected))}"

  a = actual |> Nx.to_list() |> List.flatten()
  e = expected |> Nx.to_list() |> List.flatten()

  Enum.zip(a, e)
  |> Enum.with_index()
  |> Enum.each(fn {{av, ev}, idx} ->
    assert_in_delta Complex.real(av), Complex.real(ev), @delta,
                    "#{message}: real mismatch at flat index #{idx}"
    assert_in_delta Complex.imag(av), Complex.imag(ev), @delta,
                    "#{message}: imag mismatch at flat index #{idx}"
  end)
end
```

Key facts:

- For a permutation/Clifford gate, also add a **dedicated sign guard**
  (`assert_in_delta Complex.imag(e12), 1.0, @delta` for iSWAP's `+i`)
  and a **wrong-control guard** (a permuted-qubit case whose reference
  permutation differs, e.g. `cswap(2,0,1,3)` swaps rows 3↔5, distinct
  from `cswap(0,1,2,3)`'s 5↔6). Exact full-matrix equality alone is
  enough, but these make the targeted failure mode explicit.
- Build the reference *independently* of the module under test
  (`identity_with_rows_swapped/3` + `Qx.Math.complex_matrix/1`), or the
  test is a tautology.
- Shape-check before the entrywise zip, so a representation regression
  (the `{2ⁿ,2ⁿ,2}` → `{2ⁿ,2ⁿ}` kind) fails loudly instead of comparing
  garbage.

### Files Changed

- `lib/qx/gates.ex` — `cswap/4` normalized to `:c64 {2ⁿ,2ⁿ}`; doctest
  `{8,8,2}`→`{8,8}`; OpenQASM 3.0 / Qiskit convention added to `cswap/4`
  & `iswap/3` `@doc`.
- `test/qx/cswap_iswap_matrix_test.exs` — new: exact matrix-equality +
  `+i` sign guard + wrong-control guard + negative-control sanity.
- Shipped in squash commit `6236959` on `main` (verified: 229 doctests,
  708 tests, 0 failures).

## Prevention

- [ ] Not an Iron Law (domain-specific test-selection judgment).
- [x] Add to test patterns — **before** choosing a gate-matrix equality
      assertion, ask: *does this gate have a free global phase?* Free
      phase ⇒ `assert_unitary_equal_up_to_phase/3`. Fixed canonical
      (permutation/Clifford, convention-pinned) ⇒ exact
      `assert_complex_matrix_equal/3`. Never default to phase-tolerant
      for a permutation gate — it hides sign/control errors.
- [x] Representation hygiene — keep sibling matrix builders in **one**
      Nx representation (`:c64 {2ⁿ,2ⁿ}`); a real/imag-split `{n,n,2}`
      tensor blocks a shared exact comparator and the `:c64` doctest.
- Specific guidance: a "reuse this helper everywhere" prevention bullet
  is itself a smell — comparison strategy depends on the gate's phase
  freedom, not on it being "a gate matrix".

## Related

- `.claude/solutions/testing-issues/widen-c64-test-tolerances-iron-law-8-20260615.md`
  — supersedes the `@delta 1.0e-12` choice shown above. That value
  was an Iron-Law-#8 violation; the floor on `:c64` is `1.0e-6`. The
  *decision rule* in this doc (phase-tolerant vs exact) is unchanged.
- `.claude/solutions/testing-issues/unitary-equality-up-to-global-phase-qx-gates-20260516.md`
  — the complementary (free-global-phase) case. Its Prevention section
  was corrected to scope its advice to free-phase decompositions and to
  cross-reference this doc, instead of "use it for any gate matrix /
  reuse for qx-uos".
- Convention: OpenQASM 3.0 `cswap` / `iswap`; Qiskit `CSwapGate` /
  `iSwapGate` (cited by name in `gates.ex` `@doc` + the test `@moduledoc`).
- Out of scope (logged, not addressed here): `Qx.CalcFast.apply_cswap`
  (the real simulation path) has no matrix-level test; `Gates.toffoli/4`
  uses an LSB bit convention inconsistent with cswap/iswap's MSB.
