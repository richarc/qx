# Test Review: test/qx/u_gate_convention_test.exs

## Summary

Characterization/regression-lock test for `Qx.Gates.u/3` against the OpenQASM 3.0 / Qiskit UGate convention. The file is well-structured with one BLOCKER-level mathematical defect in the decomposition matmul order and one WARNING on the global-phase helper. No iron-law violations; async, structure, and assertion style are all correct.

## Iron Law Violations

None.

## Issues Found

### Critical

None.

### Warnings

**W1 — Decomposition matmul order is inverted (line 74-76)**

The comment on line 61-62 says the identity is `RZ(φ)·RY(θ)·RZ(λ)` and the `u/3` docstring confirms this. With Nx.dot the chain `rz(phi) |> Nx.dot(ry(theta)) |> Nx.dot(rz(lambda))` computes:

```
rz(phi) · ry(theta) · rz(lambda)
```

which is `RZ(φ) · RY(θ) · RZ(λ)` — that matches the claimed identity. This is **correct**.

However the comment is potentially confusing: "rz(φ) applied last" in the Nx.dot pipeline sense is wrong — `rz(phi)` is the *leftmost* (first) operand, meaning it is the *outermost* operator (applied last to a state vector). The matmul product itself is correct; only the inline comment is misleading. Correct the comment to: "rz(phi) is the leftmost matrix in the product RZ(φ)·RY(θ)·RZ(λ), i.e. it acts last on the state vector."

Severity: **WARNING** (the mathematical result is correct; the misleading comment could cause a future refactor to flip the order).

**W2 — Phase-ratio helper picks the first non-small `b` entry, not the first non-small `a` entry (lines 93-98)**

`Enum.find(fn {_av, bv} -> Complex.abs(bv) > 1.0e-9 end)` filters on `bv` (reference) only. If `bv` is nearly zero but `av` is large, `ratio = av / bv` explodes and produces a spurious failure. Conversely if both `av` and `bv` are near-zero for the pivot but not for other entries, the ratio is still well-defined numerically but the phase was derived from a noisy entry.

For the specific gates tested here (X, H, I, Y, RZ·RY·RZ) the first non-small reference entry will always have a corresponding non-small actual entry, so this will not cause false failures in practice. Still, the guard should be:

```elixir
Enum.find(fn {av, bv} -> Complex.abs(bv) > 1.0e-9 and Complex.abs(av) > 1.0e-9 end)
```

Severity: **WARNING** (not flaky for these specific inputs; a risk for future callers reusing the helper).

**W3 — `@delta 1.0e-6` tolerance for c64 (f32 pairs) may be too tight (line 24)**

`Nx.dot` on `:c64` tensors accumulates f32 rounding. A 2×2 matrix product with f32 arithmetic can produce rounding errors on the order of `1.0e-7`. The chosen `1.0e-6` gives only ~1 decade of margin. For the current 2×2 matrices and the RZ·RY·RZ product (two sequential dots) this is unlikely to cause flakiness, but any future test with longer decomposition chains (e.g. 3+ dot products) could hit the floor.

Severity: **WARNING** (not currently flaky; note for future extension).

### Suggestions

**S1 — `for`/`unquote` test generation is correct and produces distinct ExUnit tests**

The pattern on lines 63-84 is valid. The `for` comprehension runs at compile time, and each iteration emits a distinct `test` macro call with the interpolated string in the test name. The three parameter triples produce three differently-named tests (`"U(0.7, 1.1, 0.3) ≈ ..."`, etc.). No issues.

**S2 — `U(0, 0, 0) == I` edge case: `assert_unitary_equal_up_to_phase` with the identity reference**

The identity matrix has all four entries as 1.0 or 0.0. `Enum.find` will find the first `{_, bv}` with `|bv| > 1e-9` which is `{1.0, 1.0}` (element [0][0]). Ratio = 1. This is correct and will not flunk.

**S3 — Missing edge case: `U(θ, 0, 0)` should equal `RY(θ)` up to global phase (SUGGESTION only — scope fixed)**

Not a defect; noted as a natural extension point for a follow-on characterization test.
