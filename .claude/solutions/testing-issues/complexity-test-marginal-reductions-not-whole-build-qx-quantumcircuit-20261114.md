---
module: "Qx.QuantumCircuit"
date: "2026-11-14"
problem_type: performance_issue
component: testing
symptoms:
  - "Need a regression test proving an O(n²) list append (`list ++ [x]`) became O(1), without a wall-clock threshold"
  - "Whole-build reductions for 20,000 gates: 8.82M (`++`) vs about 0.21M (prepend) — only 42× apart, so no threshold sits 10× from both"
  - "Whole-build reductions at 100,000 gates: about 100× apart, borderline, and the red run takes 19 s"
  - "Reductions per gate with `++` grow sublinearly with n (197 at 5k, 368 at 10k, 644 at 50k, 1,150 at 100k), so early gates dilute a whole-build average"
root_cause: "A whole-build count averages the cheap early appends (short list) with the dear late ones, and adds the fixed per-call cost of the public API (10.5 reductions for `Qx.h/2`) to both sides; that compresses the old/new ratio. The quadratic term only dominates in the marginal cost of adding to an already-long list"
severity: medium
tags: [reductions, complexity-test, quadratic-append, prepend-reverse, exunit, performance-regression, deterministic-metric]
related_solutions:
  - ".claude/solutions/testing-issues/retained-tensor-memory-test-via-refc-binary-peak-qx-simulation-20261113.md"
  - ".claude/solutions/performance-issues/nimble-parsec-quadratic-block-comment-scan-20260504.md"
---

# Test an O(n²) → O(1) append with marginal reductions, not a whole-build count

## Symptoms

`Qx.QuantumCircuit` appended each instruction with `instructions ++ [new]`.
The fix (prepend to `reversed_instructions`, reverse on read) needed a test
that fails on the old code and cannot flake. The plan's first choice was
process reductions for a 20,000-gate build. Measured (OTP 29, three fresh
VMs, spread under 0.1%):

| n | `++` reductions (per gate) | prepend proxy | `Qx.h/2`, result discarded |
|---|---|---|---|
| 20,000 | 8.82M (441) | 0.12M (5.9) | 0.21M (10.5) |
| 50,000 | 32.2M (644) | 0.27M (5.3) | 0.53M (10.5) |
| 100,000 | 115M (1,150) | | 1.05M (10.5) |

No whole-build size up to 100,000 gives a threshold 10× from both sides.

## Root cause

The whole build sums short-list appends (cheap) with long-list appends
(dear), and both old and new pay the same fixed per-call cost. The ratio
that matters is the cost of one more gate on a list that is already long.

## Solution

Build the first half untimed, then count reductions for the second half
only:

```elixir
{spent, depth} =
  Task.async(fn ->
    add_gate = fn i, circuit -> Qx.h(circuit, rem(i, 4)) end
    long_circuit = Enum.reduce(1..50_000, Qx.create_circuit(4), add_gate)

    before = reductions()
    longer = Enum.reduce(1..50_000, long_circuit, add_gate)
    {reductions() - before, QuantumCircuit.depth(longer)}
  end)
  |> Task.await(:infinity)

assert spent / 50_000 < 140
```

Gates 50,001–100,000: 1,654 reductions per gate with `++`, 8.64 with
prepend (191× apart). Limit 140 is 11.8× under the old figure and 16.2×
over the new one. The test runs in 0.1 s on the fixed code.

Details that mattered:

- Run the build in a fresh process (`Task.async`) so the count is its own,
  and return the numbers: assert in the test process, not inside the task.
- `Process.info(self(), :reductions)` is deterministic enough for
  `async: true`; other tests do not affect it.
- Estimate the new side before the fix exists with two proxies: the public
  call with its result discarded (per-call floor) and a hand-written
  prepend loop (list + GC cost). The real figure landed below their sum.
- The red run builds 100,000 gates on the old code (19 s). Set
  `@tag timeout:` above that so a regression fails on the assertion, not
  the ExUnit timeout.
- Measure with the cheapest public producer. A mix of `h`/`cx`/`ccx`/
  `barrier` costs 19.5 reductions per gate on the fixed code, which cuts
  the margin under the limit to 7.2×.

Rejected: a late/early ratio (self-calibrating, but it separates old from
new by less than the absolute limit); wall-clock (4.8 s vs 3 ms at 50,000
gates is a wide gap, but load-sensitive, and not needed).

## Prevention

- For a complexity regression test, measure the marginal cost at large n,
  not the total from zero.
- Take the old-code number, the per-call floor, and a proxy for the new
  code before choosing a limit; write all three next to the limit.
- Known limit: the old-side figure depends on how ERTS charges reductions
  inside the `++` BIF (measured on OTP 29 only). Re-measure if an OTP
  upgrade moves the fixed-code figure.
- Do not use `list ++ [x]` in a builder that is called once per element;
  prepend and reverse on read (`usage_rules:elixir`).
