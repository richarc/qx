---
module: "Qx.Step"
date: "2026-11-21"
problem_type: logic_error
component: display
symptoms:
  - "`Qx.Step.show/1` returned `0.000|00…0⟩` as the Dirac string of a valid, normalised uniform state on 20 qubits"
  - "`inspect(step)` for the same state was correct: it printed the largest terms"
  - "`Qx.Register.show_state/1` had the same wrong output; three callers of one function, one of them fixed"
  - "The bug had been 'fixed' four months earlier and had a passing regression test"
root_cause: "The July fix for the all-terms-below-threshold case was written in ONE caller (the Inspect impl of Qx.Step: a top-k fallback wrapped round the call) instead of in the shared function all callers use (Qx.Format.dirac_notation/2). The regression test exercised only the fixed caller, so the suite was green while the two sibling callers kept the original behaviour. Nothing in the fix or the test asked 'who else calls this'."
severity: medium
tags: [shared-function, caller-vs-callee, regression-test-scope, dirac-notation, display-threshold, sibling-callers]
related_solutions:
  - ".claude/solutions/phoenix-issues/absolute-display-threshold-fails-at-scale-qx-step-20260703.md"
  - ".claude/solutions/architecture-issues/display-tolerance-not-state-tidyup-qx-format-20261121.md"
---

# A fix placed in one caller leaves the sibling callers broken

## Symptoms

```elixir
step = ...  # uniform state, every probability 9.5e-7 (20 qubits)
inspect(step)              # "… 0.001|0…00⟩ + 0.001|0…01⟩ + …"   correct
Qx.Step.show(step).state   # "0.000|00…0⟩"                       wrong
```

Found while consolidating display thresholds, not from a bug report.

## Investigation

1. Listed every place that decides "zero for display": four sites, three
   different cut-offs.
2. Grepped the callers of `Qx.Format.dirac_notation/2`: `Qx.Step.show/1`,
   the `Qx.Step` Inspect impl, `Qx.Register.show_state/1`.
3. Only the Inspect impl wrapped the call in the July fallback. The other
   two called it bare.
4. Wrote the failing test for `show/1` with the miniature fixture from the
   July doc (amplitude 9.0e-4 on four basis states). It failed on `main`.

## Root cause

The July change looked like this, inside the Inspect impl:

```elixir
significant = Enum.filter(terms, fn {_b, _a, prob} -> prob > @prob_threshold end)

case Enum.split(significant, @max_dirac_terms) do
  {[], _} -> terms |> top_terms() |> truncated_dirac(terms)   # the fix
  ...
end
```

The defect was in `dirac_notation/2` (its filter and its `0.000` fallback),
but the repair was wrapped round one call to it. The test added with the
fix called `inspect/1`.

## Solution

Move the behaviour into the function that had the defect, so every caller
gets it, and delete the wrapper:

```elixir
# lib/qx/format.ex
def significant_terms(terms, opts \\ [])   # noise, "prints as zero", largest-terms fallback
def dirac_notation(terms, opts \\ []) do
  {terms, _cut?} = significant_terms(terms, precision: precision)
  ...
end

# lib/qx/step.ex, Inspect impl
{shown, cut?} = Format.significant_terms(terms, max: @max_dirac_terms)
```

Tests now cover the shared function directly and each surface: `show/1`,
`inspect/1` and the state table are asserted to agree on one state.

## Prevention

- When a fix wraps a call to a shared function, stop and ask whether the
  defect is in the callee. If it is, fix the callee. `grep` the callee's
  callers before choosing where the fix goes.
- A regression test should enter through the function that had the defect,
  and then once through each public surface that reaches it. A test that
  enters only through the caller you fixed proves that caller only.
- Review check: a fix whose diff touches a caller but not the function
  whose output was wrong is a finding until the other callers are shown to
  be unaffected.
- "Three surfaces agree" tests are cheap: render one awkward state through
  every display path and assert they tell the same story.
