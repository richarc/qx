---
module: "Qx.Simulation.run/2"
date: "2026-11-08"
problem_type: iron_law_violation
component: validation
symptoms:
  - "On main, Qx.run(qc, shots: 0) silently returned 2 samples and shots: -1 returned 3 (wrong counts, no error)"
  - "After the sampler rewrite, the same calls raised a raw FunctionClauseError from Qx.Simulation.Sampler.sample/2 — a non-typed error at the public boundary (Iron Law #7)"
root_cause: "the :shots option was never validated; `for _ <- 1..shots` iterates a descending range for shots < 1, and a new internal function with a `shots > 0` guard turned that silent wrong answer into a raw clause error"
severity: medium
tags: [iron-law-7, typed-errors, option-validation, descending-range, guard-clause, review-finding]
related_solutions:
  - ".claude/solutions/architecture-issues/route-validation-raises-to-typed-errors-iron-law-7-20260624.md"
  - ".claude/solutions/architecture-issues/sweep-typed-errors-public-surface-iron-law-7-20260624.md"
---

# A tighter internal guard exposed an unvalidated public option

## Root cause

`1..0` is the descending range `[1, 0]`, so an unvalidated `shots` value below 1
produced extra samples instead of an error. When I gave the new internal
`Sampler.sample/2` a `shots > 0` guard, the failure moved from a silent wrong
answer to a raw `FunctionClauseError`. The input validation was missing all
along; the guard only exposed it.

## Solution

```elixir
# lib/qx/validation.ex
def validate_shots!(shots) when is_integer(shots) and shots > 0, do: shots
def validate_shots!(value),
  do: raise(Qx.OptionError, {:shots, value, "Expected a positive integer."})

# Qx.Simulation.run/2: validate once, so both run paths are covered
shots = options |> Keyword.get(:shots, 1024) |> Validation.validate_shots!()
```

Tests cover `0`, `-1`, `1.5` and `:many` on both the sampling path and the
`c_if` path, plus the `Qx.run(qc, 0)` integer facade form and `shots: 1`. The
docs for both `run/2` functions now state the rule, and the CHANGELOG has a
"Fixed" entry.

## Prevention

- When you add a guard to an internal function, trace each argument back to the
  public API. If nothing validates it upstream, add `Qx.Validation` at the
  boundary rather than relaxing the guard.
- Any `1..n` built from caller input is a descending-range hazard when `n < 1`.
  Use `1..n//1` or validate first.
- In review, compare `main` against the branch on invalid inputs. A behaviour
  change on bad input can hide a missing validation.
