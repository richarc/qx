---
module: "Qx.CalcFast"
date: "2026-11-06"
problem_type: performance_issue
component: nx_defn_kernel
symptoms:
  - "Planned reshape + dense 2^k×2^k Nx.dot contraction made CX 4–7× and CCX ~8× SLOWER than the old Nx.take/Nx.select gather kernels on Nx.BinaryBackend (n=16: CX 33→223 ms, CCX 44→364 ms)"
  - "Dense contraction only won for single-qubit gates (n=16 H 190→135 ms), so a 'one general kernel' plan looked fine on the 1q benchmark alone"
  - "SWAP / iSWAP / CP / CRY via materialised 2^n×2^n matrices: 44–55 ms at n=8, OOM past n≈12; QFT n=10 took 82 s"
root_cause: "a 2^k×2^k controlled or permutation gate is mostly zeros; contracting it multiplies every amplitude by 2^k entries (4 for CX, 8 for CCX) plus a full-state transpose, while BinaryBackend runs dot/transpose as pure-Elixir loops with no BLAS — so the extra arithmetic dominates"
severity: high
tags: [nx, defn, deftransform, binary-backend, statevector, slice_along_axis, iron-law-3, benchmark, spike-before-commit]
related_solutions:
  - ".claude/solutions/testing-issues/characterize-unvalidated-nx-kernels-regression-net-calcfast-20260626.md"
---

# Dense 2^k×2^k contraction is slower than rank-n axis slicing for controlled/permutation gates

## Symptoms

The roadmap item (and plan decision D1) said to replace the gather/mask kernels
with "reshape + tensor contraction": reshape `{2^n}` → `{2,…,2}`, `Nx.dot` the
gate reshaped to rank 2k along the k target axes, transpose back. A throwaway
spike (`mix run` scratch file, measured before any `lib/` change) showed the
regression in the table above. Correctness was fine for all orderings; speed was not.

## Root cause

Dense contraction does work proportional to `2^n · 2^k` regardless of structure.
For CX/CCX/CSWAP/SWAP the gate is a permutation, and for controlled-U only the
control=1 half changes. A multiply-by-zero is still a multiply on BinaryBackend.

## Solution — rank-n axis slicing (shipped in `lib/qx/calc_fast.ex`)

Reshape to rank-n (axis q = qubit q, MSB). Then apply only what the gate needs on
static slices:

```elixir
defp on_controls(t, [], op), do: op.(t)
defp on_controls(t, [c | rest], op) do
  {off, on} = {Nx.slice_along_axis(t, 0, 1, axis: c), Nx.slice_along_axis(t, 1, 1, axis: c)}
  Nx.concatenate([off, on_controls(on, rest, op)], axis: c)
end
# 1q U:  split target axis, [u00·a0+u01·a1, u10·a0+u11·a1], concat (no transpose)
# CX/CCX: Nx.reverse(t, axes: [target]) on the control slice
# SWAP/CSWAP: Nx.transpose swapping two axes (on the control slice)
```

Static qubit indices must reach shapes, so `defnp kernel(state, gate, opts)` takes
them via `keyword!` opts and calls a `deftransformp` whose body is plain Elixir
calling `defp` helpers (closures OK, trace time) that emit Nx ops. Keep sliced axes
at size 1 (don't squeeze) so axis numbers stay valid through nesting.

Results (BinaryBackend, n=16): H 46–63 ms, CX 2.5 ms, CCX 4 ms, CSWAP 3.3 ms,
CP 31 ms, CRY 37 ms, SWAP 7 ms. QFT n=10: 82 s → 24.6 ms. Full data:
`.claude/plans/calcfast-reshape-kernels/research/bench-comparison.md`.

## Prevention

- Before committing to a kernel strategy, spike it **per gate class** (1q,
  controlled, permutation, k=3), not just on the 1q case. Measure on BinaryBackend,
  which is what ships by default.
- "Prefer reshape + contraction" (Iron Law #3) means *avoid gather/mask*. Static
  slice / concatenate / reverse / transpose satisfies it and is usually cheaper than
  a dense contraction for structured gates.
- If a measured result contradicts an approved plan decision, surface the data and
  get the decision amended. Don't implement to the broken spec.
