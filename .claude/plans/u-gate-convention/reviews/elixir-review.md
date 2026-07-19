# Code Review: feat/u-gate-convention

## Summary
- **Status**: ✅ Approved (with one warning to address before merge)
- **Issues Found**: 3 (0 BLOCKER, 1 WARNING, 2 SUGGESTION)

---

## Critical Issues

None.

---

## Warnings

### 1. `test/qx/u_gate_convention_test.exs:68` — Compile-time `for` loop produces unreadable test names for expression-valued tuples

**WARNING**

The `for` comprehension binds `theta`, `phi`, `lambda` at compile-time from the list literal. For the first and third tuples the values are plain floats and the names work fine. The second tuple is `{:math.pi() / 3, :math.pi() / 5, -:math.pi() / 4}` — these are unevaluated AST nodes at the point of string interpolation into the test name, so the generated test will be named something like:

```
U(:math.pi() / 3, :math.pi() / 5, -:math.pi() / 4) ≈ RZ(φ)·RY(θ)·RZ(λ)
```

This is ugly and may confuse `mix test --grep` usage. The fix is to pre-compute constants inline or use explicit `test` blocks for the expression cases:

```elixir
# Option A: pre-compute to floats in the list
@pi :math.pi()

for {theta, phi, lambda} <- [
  {0.7, 1.1, 0.3},
  {@pi / 3, @pi / 5, -@pi / 4},
  {2.0, 0.0, 1.0}
] do
  ...
end
```

Module attributes `@pi` are evaluated at compile time and the float value is what gets bound and interpolated. This gives a readable test name like `U(1.0471975511965976, 0.6283185307179586, ...)`.

Alternatively, pre-compute the floats outside and use them directly as literals.

---

## Suggestions

### 1. `test/qx/u_gate_convention_test.exs:94-99` — `|> case do` on `Enum.find` result is idiomatic but slightly non-standard

**SUGGESTION**

The pipeline-into-case pattern works correctly. Credo's `Credo.Check.Refactor.PipeChainStart` will not flag it, and the logic is clear. A minor readability alternative is pattern-matching the result directly:

```elixir
# Current (fine, works correctly)
Enum.zip(a, b)
|> Enum.find(fn {_av, bv} -> Complex.abs(bv) > 1.0e-9 end)
|> case do
  nil -> flunk(...)
  pair -> pair
end

# Alternative (avoids pipe-into-case)
case Enum.find(Enum.zip(a, b), fn {_av, bv} -> Complex.abs(bv) > 1.0e-9 end) do
  nil -> flunk(...)
  pair -> pair
end
```

Not a blocker. The current form is acceptable and common in the Elixir ecosystem.

### 2. `test/qx/u_gate_convention_test.exs` — `@moduledoc` on an `ExUnit.Case` module

**SUGGESTION**

`@moduledoc` is technically valid on test modules, but ExUnit test modules conventionally use a leading comment or omit module-level docs entirely. The `@moduledoc` here is unusually long and duplicates the convention description already in the `describe` label and the test file's commit context. This is a style preference — keep it if the team values in-module narrative, remove it if brevity is preferred. Not a correctness issue.

---

## Docstring Consistency Check (three copies)

All three copies (`lib/qx/gates.ex:257-286`, `lib/qx/operations.ex:249-285`, `lib/qx.ex:469-500`) contain the same matrix formula, OpenQASM reference sentence, decomposition identity, and special-cases list. The only intentional differences are the `## Parameters` block (gates.ex has 3 params, operations.ex and qx.ex have 5 including `circuit`/`qubit`) and minor phrasing in the special-cases sentence ("below the result is exact" vs "the result is exact"). No factual divergence detected.

## Docstring Correctness

- Matrix formula is correct per OpenQASM 3.0 / Qiskit `UGate` convention.
- Decomposition `U(θ,φ,λ) = RZ(φ)·RY(θ)·RZ(λ)` is consistent with the test's `Nx.dot` chain.
- The "up to global phase `e^{i(φ+λ)/2}`" qualifier is correct.
- Special-case annotations are consistent with what the tests assert.

## Test Patterns

- `Nx.to_list()` on `:c64` tensors returns nested lists of `%Complex{}` — `Complex.abs/real/imag/divide` calls are all valid.
- `Nx.dot/2` is correct for 2D matrix multiplication.
- `for`/`unquote` test generation is a valid ExUnit pattern for parameterized tests.
- `@delta 1.0e-6` tolerance is appropriate for `:c64` (32-bit complex float) arithmetic.
- Global-phase-tolerant comparison via ratio extraction is mathematically sound.

## Pre-existing issues noted (unchanged lines, not deep-analyzed)

- `lib/qx/gates.ex:197` — `iex> Qx.Gates.ry(math.pi/2)` doctest is missing the module prefix `:math.pi()` and would fail if run as a doctest. Pre-existing, not in this diff.
- `lib/qx/gates.ex:221` — same issue for `rz`. Pre-existing.
