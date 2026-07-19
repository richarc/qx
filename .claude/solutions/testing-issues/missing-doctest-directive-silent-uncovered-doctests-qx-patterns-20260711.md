---
module: "Qx.Patterns"
date: "2026-07-11"
problem_type: test_coverage_gap
component: testing
symptoms:
  - "`mix test test/qx/patterns_test.exs` reported 0 doctests for Qx.Patterns while lib/qx/patterns.ex defined ~20 `iex>` examples"
  - "New doctests added to a public function passed `mix test` without ever executing — a false green (the example could be wrong and nothing would fail)"
  - "`mix docs` rendered the doctests correctly, masking that ExUnit never ran them"
  - "`grep -rn 'doctest Qx.Patterns' test/` returned nothing even though the module was heavily documented with examples"
root_cause: "the ExUnit test module for Qx.Patterns had no `doctest Qx.Patterns` directive, so ExUnit never generated test cases from the module's `@doc`/`@moduledoc` examples — the doctests existed as documentation but were never verified"
severity: medium
tags: [doctest, exunit, test-coverage, silent-gap, false-green, verification, public-api]
related_solutions:
  - ".claude/solutions/architecture-issues/docs-warning-stash-diff-catches-phantom-pointer-qx-stateinit-20260708.md"
---

# Missing `doctest Module` directive leaves a module's doctests silently unrun

## Symptoms

- The module `Qx.Patterns` had ~20 `iex>` examples across its `@moduledoc`
  and `@doc` blocks (`h_all`, `x_all`, `measure_all`, `cx_chain`, …), yet
  `mix test test/qx/patterns_test.exs` printed a doctest count of **0** for
  that module.
- While adding `bell_pair/4` and `ghz/2`, the new `@doc` doctests were
  written and `mix test` went green — but the doctests were **never actually
  executed**. A wrong expected value in an example would not have failed the
  suite.
- `mix docs` rendered every example fine (autolinking, formatting), so the
  gap was invisible from the docs side.

## Investigation

1. **Hypothesis: the doctests run under some umbrella test** — searched
   `grep -rn "doctest" test/`. Found `doctest Qx`, `doctest Qx.Math`,
   `doctest Qx.StateInit`, etc., but **no `doctest Qx.Patterns` anywhere**.
2. **Hypothesis: maybe the facade `doctest Qx` covers them** — no. `doctest Qx`
   only extracts examples from the `Qx` module's own `@doc`s (the facade
   delegate docs), not from `Qx.Patterns`. Delegated functions do not
   inherit the target module's doctests.
3. **Root cause found**: ExUnit only generates doctest cases for modules
   named in an explicit `doctest ModuleName` call inside a test module. With
   no such call for `Qx.Patterns`, its examples were pure documentation —
   compiled, rendered, but never asserted.

## Root Cause

`doctest` in ExUnit is **opt-in per module**. `@doc` examples are just
strings until a test module invokes `doctest Some.Module`, which macro-expands
them into runnable test cases at compile time. There is no global "run all
doctests" — a module with rich `iex>` examples but no corresponding `doctest`
directive contributes **zero** verification. The examples *look* like
coverage (they read as tested behaviour) while silently being unchecked.

```elixir
# test/qx/patterns_test.exs — BEFORE
defmodule Qx.PatternsTest do
  use ExUnit.Case, async: true

  alias Qx.{Patterns, QuantumCircuit}
  # ... 60 hand-written tests, but NO `doctest Qx.Patterns` ...
  # => every `iex>` in lib/qx/patterns.ex is never executed
end
```

## Solution

Add the one-line `doctest` directive to the module's test file. All of the
module's `@doc`/`@moduledoc` examples immediately become runnable tests.

```elixir
# test/qx/patterns_test.exs — AFTER
defmodule Qx.PatternsTest do
  use ExUnit.Case, async: true

  doctest Qx.Patterns          # <-- the missing line

  alias Qx.{Patterns, QuantumCircuit}
  # ...
end
```

Result: `mix test test/qx/patterns_test.exs` went from `0 doctests` to
`24 doctests` for the module, all passing — confirming both the pre-existing
examples and the newly added `bell_pair/4` / `ghz/2` ones are correct.

### Files Changed

- `test/qx/patterns_test.exs:4` — added `doctest Qx.Patterns`

## Prevention

- [x] Add to reviewer / testing-reviewer checks: for any module with `iex>`
      examples in its `@doc`/`@moduledoc`, confirm a `doctest <Module>`
      directive exists in a test module. Absence = silent coverage gap.
- [ ] Not an Iron Law (not a correctness/API-surface invariant), but a
      standing review heuristic.
- Specific guidance:
  - When adding a doctest to a function, **verify it actually runs**: check
    the doctest count in `mix test <file>` output moves, don't trust green.
  - `defdelegate` does **not** carry the target module's doctests — each
    module that owns `@doc` examples needs its own `doctest` directive in a
    test module.
  - Quick audit across a project:
    ```bash
    # modules that define iex> examples
    comm -23 \
      <(grep -rl 'iex>' lib/ | xargs -I{} basename {} .ex | sort -u) \
      <(grep -rho 'doctest [A-Za-z0-9_.]*' test/ | awk '{print $2}' | sort -u)
    ```
    (heuristic — refine module-name mapping per project layout.)

## Related

- `.claude/solutions/architecture-issues/docs-warning-stash-diff-catches-phantom-pointer-qx-stateinit-20260708.md`
  — related "docs look fine but a check is silently absent" class of bug:
  there, `mix docs` autolinker was the only tool catching phantom doc
  pointers; here, the missing `doctest` directive is the only reason
  example correctness went unverified. Both are "green ≠ covered" traps.
