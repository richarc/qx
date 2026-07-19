---
module: "Qx.Step"
date: "2026-07-03"
problem_type: logic_error
component: inspect_impl
symptoms:
  - "`inspect(%Qx.Step{})` for a wide uniform superposition renders `0.000|00…0⟩` — a misleading 'zero state' line for a perfectly valid normalized state"
  - "At n=20 qubits a uniform superposition gives every basis state probability 1/2^20 ≈ 9.5e-7, below the fixed 1.0e-6 display threshold, so the 'significant terms' filter returns [] and the fallback fires"
  - "Caught by elixir-reviewer during /phx:review of the circuit-stepper branch; no test covered the all-sub-threshold regime"
root_cause: "An absolute per-item display threshold (probability > 1.0e-6) was applied to a quantity whose per-item magnitude shrinks with problem size: uniform-superposition probabilities scale as 1/2^n, so ANY fixed epsilon is crossed at some n within the library's supported range (n ≤ 20 ⇒ 9.5e-7 < 1.0e-6). The empty-filter fallback then displayed the first term at 3-decimal precision, i.e. '0.000'."
severity: medium
tags: [inspect, display-threshold, float32, uniform-superposition, scale-dependent, fallback, dirac-notation]
related_solutions: ["spec-tolerance-below-float32-epsilon-qx-simulation-20260516"]
---

# Absolute display threshold fails at the library's own scale ceiling

## Symptoms

`Qx.Step`'s `Inspect` impl filters Dirac terms by
`probability > 1.0e-6` and shows the first 4. For a 20-qubit uniform
superposition every term is ≈9.5e-7, the filter returns nothing, and
the fallback printed `0.000|00…0⟩` — a valid state rendered as if it
were zero.

## Investigation

1. **Hypothesis: the fallback prints the full untruncated term list**
   — refuted by reading `Qx.Format.dirac_notation/2`: it re-filters
   with the same threshold and prints a single `0.000|…⟩` term. Wrong
   failure mode, still a real display bug.
2. **Root cause found**: fixed epsilon vs. a 1/2^n quantity. The
   supported qubit range (≤20) guarantees the threshold is crossed.

## Root Cause

Display thresholds and numeric-noise thresholds are different things.
1.0e-6 is right for *noise* (it tracks `:c64` float32 epsilon, Iron
Law #8) but wrong as a *relevance* cutoff, because relevance is
relative: in a uniform superposition every term is equally relevant no
matter how small 1/2^n gets.

```elixir
# Problematic: all terms below the absolute threshold → misleading fallback
significant = Enum.filter(terms, fn {_b, _a, prob} -> prob > 1.0e-6 end)
case Enum.split(significant, 4) do
  {[], _} -> Format.dirac_notation(terms)   # re-filters → "0.000|00…0⟩"
  ...
end
```

## Solution

When the absolute filter yields nothing, fall back to the top-k terms
*by probability*, rendered with the threshold disabled:

```elixir
{[], _} -> terms |> top_terms() |> truncated_dirac(terms)

defp top_terms(terms) do
  terms |> Enum.sort_by(fn {_b, _a, prob} -> -prob end) |> Enum.take(@max_dirac_terms)
end

defp truncated_dirac(shown, all_terms) do
  rendered = Format.dirac_notation(shown, threshold: 0.0)
  if length(all_terms) > length(shown), do: rendered <> " + …", else: rendered
end
```

Test trick: no need for a slow 2^20 fixture. Miniaturise the regime
with a small unnormalized state whose probabilities sit below the
threshold while the amplitudes still render non-zero at 3 decimals
(amplitude 9.0e-4 ⇒ probability 8.1e-7 < 1.0e-6, renders "0.001").
First fixture attempt used 1.0e-4, whose amplitude ALSO renders
"0.000" — pick fixture values against the display precision, not just
the threshold.

### Files Changed

- `lib/qx/step.ex` — `dirac/1` fallback, `top_terms/1`, `truncated_dirac/2`
- `test/qx/step_test.exs` — "Inspect fallback below the probability threshold"

## Prevention

- [ ] Add to agent checks? elixir-reviewer already caught it; a grep
      for fixed thresholds near `2^n`-scaling quantities is a plausible
      iron-law-judge heuristic
- Specific guidance: "Any absolute epsilon applied per-element to a
  quantity that scales as 1/2^n WILL be crossed inside Qx's supported
  n ≤ 20 range. Compute the n at which it crosses; if that n is
  supported, use a relative cutoff or a top-k fallback."

## Related

- `.claude/solutions/phoenix-issues/spec-tolerance-below-float32-epsilon-qx-simulation-20260516.md`
  — the sibling failure in the opposite direction (tolerance below
  what float32 can deliver); together: check every fixed epsilon
  against BOTH the float width and the problem-size scaling
- Iron Law #8: tolerance targets must be feasible at runtime float width
