---
module: "Qx.CalcFast"
date: "2026-06-26"
problem_type: test_characterization
component: testing
symptoms:
  - "Internal Nx.Defn kernel covered only indirectly through Qx.Calc / Qx.Simulation, with no direct behavioural net before a planned rewrite"
  - "Out-of-range / negative qubit raises raw `** (ArgumentError) cannot right shift by -1`, not a typed Qx.*Error"
  - "A non-2x2 gate does NOT raise — it returns a defined, physically meaningless result"
root_cause: "perf-critical defn kernels are unvalidated by design; validation lives upstream in the public API, so the kernel layer leaks raw Nx errors and silently tolerates malformed shapes"
severity: medium
tags: [calcfast, characterization-test, nx-defn, regression-net, msb-convention, unvalidated-kernel, pre-rewrite]
related_solutions:
  - ".claude/solutions/testing-issues/widen-c64-test-tolerances-iron-law-8-20260615.md"
---

# Characterizing an unvalidated Nx kernel as a pre-rewrite regression net

## Symptoms

`Qx.CalcFast` (the `@moduledoc false` direct-statevector kernels —
single-qubit gate, CNOT, CSWAP, Toffoli) had no test file of its own. It
was exercised only indirectly through `Qx.Calc` and `Qx.Simulation`. The
v0.8.2 roadmap rewrites these kernels (gather `Nx.take` + `Nx.select`
mask → reshape + 2×2 tensor contraction), and nothing pinned the
kernels' own observable behaviour to catch a regression.

Probing the unvalidated boundary surfaced two distinct raw behaviours:

- Out-of-range qubit (`target == num_qubits`, so `bit_pos = -1`) and
  out-of-range CNOT/Toffoli controls raise `** (ArgumentError) cannot
  right shift by -1`. Negative qubit and state-length mismatch raise
  `** (ArgumentError) index N is out of bounds for axis 0 in shape {…}`.
- A non-2×2 gate matrix does **not** raise. The compiled head reads only
  `gate[0][0]`, `gate[0][1]`, `gate[1][0]`, `gate[1][1]`, so a 3×3 matrix
  yields a defined (meaningless) result instead of a shape error.

## Investigation

1. **Should invalid inputs assert typed `Qx.*Error`?** — No. `Qx.CalcFast`
   performs zero validation by design; typed errors (`Qx.QubitIndexError`
   etc.) live upstream in `Qx.Validation` / `Qx.Operations`, reached only
   through the public API. Asserting typed errors here would be testing a
   layer that does not exist (plan decision D2).
2. **What does a non-2×2 gate actually do?** — Ran a probe: a 3×3 gate
   whose top-left 2×2 block is Pauli-X applied to `|00⟩` returned `|10⟩`
   (index 2). The kernel silently uses the top-left 2×2 block and ignores
   the rest. So the plan's "assert it raises" expectation was wrong; the
   measured behaviour is no-raise.
3. **What is most fragile under the rewrite?** — The MSB qubit convention
   (`bit_pos = num_qubits - 1 - qubit`, qubit 0 = most-significant bit).
   A reshape rewrite can silently flip it.

## Root Cause

These are deliberately unvalidated `defn` hot-path kernels. Invalid
qubit indices flow straight into bit-shift math (`Nx.right_shift` by a
negative amount raises; an inflated XOR mask drives `Nx.take` out of
bounds); a wrong-shaped gate flows into scalar indexing that happens to
succeed. There is no error boundary at this layer — that is the public
API's job — so the correct test strategy is **characterization**: pin
the actual raw behaviour, not a wished-for typed error.

## Solution

A new `test/qx/calc_fast_test.exs` (`async: true`) that calls the kernels
directly. Three reusable techniques:

**1. Pin the raw error class, not a typed error:**

```elixir
test "apply_single_qubit_gate/4 raises on out-of-range target (target == num_qubits)" do
  # bit_pos = num_qubits - 1 - target = -1 → "cannot right shift by -1".
  assert_raise ArgumentError, fn ->
    CalcFast.apply_single_qubit_gate(basis_state(0, 2), Gates.pauli_x(), 2, 2)
  end
end
```

**2. Pin the actual no-raise behaviour with an observable result** (not a
vacuous `assert %Nx.Tensor{} = result`, which a silent NOP would pass):

```elixir
test "apply_single_qubit_gate/4 silently uses the top-left 2×2 block of an oversized gate" do
  # 3×3 gate with a Pauli-X top-left block acts as X on qubit 0: |00⟩ → |10⟩.
  z = C.new(0.0, 0.0)
  o = C.new(1.0, 0.0)
  gate_3x3 = Nx.tensor([[z, o, z], [o, z, z], [z, z, o]], type: :c64)
  result = CalcFast.apply_single_qubit_gate(basis_state(0, 2), gate_3x3, 0, 2)
  assert state_approx_equal?(result, basis_state(2, 2))
end
```

**3. Pin the MSB convention with full 8-state truth tables** so a silent
flip fails loudly — include the controls-off pass-through states, which a
cherry-picked subset would miss:

```elixir
# CNOT control 0 / target 2 in a 3-qubit system: flip q2 iff q0 = 1.
expected = %{0 => 0, 1 => 1, 2 => 2, 3 => 3, 4 => 5, 5 => 4, 6 => 7, 7 => 6}

Enum.each(expected, fn {input, output} ->
  result = CalcFast.apply_cnot(basis_state(input, 3), 0, 2, 3)
  assert state_approx_equal?(result, basis_state(output, 3)), "CNOT(0,2) |#{input}⟩"
end)
```

Tolerance `1.0e-6` (the `:c64` float32 floor, Iron Law #8 — do not go
lower). Coverage of `lib/qx/calc_fast.ex` went indirect-only → **100.0%**
(59/59 lines).

### Files Changed

- `test/qx/calc_fast_test.exs` — new file, 23 tests (commit `c863900`)
- `ROADMAP.md` — ticked qx-eb1 under v0.8.1

## Prevention

- [x] Add to test patterns — characterization recipe captured here.
- Specific guidance:
  - When an internal `defn` kernel is unvalidated by design, do **not**
    assert typed `Qx.*Error` at that layer — assert the raw `ArgumentError`
    / defined result, and say so in the file's moduledoc.
  - Before a kernel rewrite, give the kernel a **direct** test file even
    if it is `@moduledoc false` — indirect coverage through a wrapper does
    not pin the rewrite target.
  - Probe the real failure mode before writing the assertion. The plan
    said "non-2×2 → raises"; reality was "no raise, uses top-left block".
    Pin reality, not the plan's guess (plan decision D2).
  - For MSB-convention kernels, use exhaustive 2^n basis-state truth
    tables including the no-op pass-through states.

## Related

- `.claude/solutions/testing-issues/widen-c64-test-tolerances-iron-law-8-20260615.md` — the `1.0e-6` `:c64` tolerance floor this suite reuses
- Iron Law #3 (reshape over gather) and #8 (`:c64` ε floor) — this suite is the net protecting the Iron-Law-#3 rewrite

## Follow-ups discovered (deferred, touch `lib/` — recorded in plan scratchpad)

- `lib/qx/calc_fast.ex:145` — `@doc` above `apply_cswap/5` wrongly reads
  "Applies a Toffoli (CCX) gate" (copy-paste from `apply_toffoli`).
- `test/qx/calc_test.exs` — still synchronous; belongs to the existing
  "flip 16 pure-compute test files to `async: true`" roadmap item.
