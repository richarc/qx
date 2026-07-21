---
module: "Qx.Validation"
date: "2026-07-19"
problem_type: build_error
component: configuration
symptoms:
  - "mix dialyzer: 'Function valid?/1 has no local return.' on Qx.Register.valid?/1, a one-line function whose only statement is a delegate call"
  - "mix dialyzer: 'The @spec for the function does not match the success typing of the function... Success typing: (_) :: none()'"
  - "mix dialyzer: 'Qx.Validation.valid_register?(_register :: %Qx.Register{}) will never return since the 1st arguments differ from the success typing arguments' followed by a printed map type with no :__struct__ key"
  - "the doctest at the call site (Qx.Register.valid?(reg) returns true) passes at runtime — only Dialyzer's static analysis disagrees"
root_cause: "the callee's @spec used an anonymous bare map shape (%{state: Nx.Tensor.t(), num_qubits: integer()}) derived from a bare-map function-head pattern; Dialyzer infers this as a CLOSED map type (exactly these keys, nothing else), which structurally excludes any real struct value (every struct carries an extra :__struct__ key), so a genuine %Qx.Register{} argument looks impossible even though the runtime pattern match %{state: state, num_qubits: num_qubits} matches any struct with those keys fine"
severity: "medium"
tags: [dialyzer, dialyxir, typespec, map-type, struct, closed-map, false-positive]
elixir_version: "1.20.2"
---

# Anonymous map @spec on a struct-accepting function reads as closed to Dialyzer, excluding the struct it's meant to accept

## Symptoms

After fixing the larger `Nx.Type.t()`-shorthand cascade (see related solution doc), 9 dialyzer warnings remained. Three of them were on `Qx.Register.valid?/1` — a trivial one-line wrapper:

```elixir
@spec valid?(t()) :: boolean()
def valid?(%__MODULE__{} = register) do
  Qx.Validation.valid_register?(register)
end
```

```
lib/qx/register.ex:795:invalid_contract
Success typing: (_) :: none()
But the spec is: (t()) :: boolean()

lib/qx/register.ex:797:35:call
Qx.Validation.valid_register?(_register :: %Qx.Register{})
will never return since the 1st arguments differ
from the success typing arguments:
(%{
  :num_qubits => integer(),
  :state => %Nx.Tensor{...}
})
```

Note the printed success-typing map has no `:__struct__` key at all.

## Investigation

1. **Hypothesis: `Register.new/1` still produces a malformed struct** — already ruled out; `Register.new/1`'s own warnings were resolved by the earlier `Nx.Type.short_t()` fix, and no warning remained on `new/1` itself.
2. **Hypothesis: `Qx.Math.probabilities/1` or another callee inside `valid_register?/2`'s body has a broken spec** — checked `lib/qx/math.ex`, `@spec probabilities(Nx.Tensor.t()) :: Nx.Tensor.t()` is unremarkable, no atom-shorthand issue there.
3. **Root cause found**: the callee's own `@spec`:
   ```elixir
   @spec valid_register?(%{state: Nx.Tensor.t(), num_qubits: integer()}, float()) :: boolean()
   def valid_register?(%{state: state, num_qubits: num_qubits}, tolerance \\ 1.0e-6) do
   ```
   The parameter type is an *anonymous* map shape (not a struct type, not `map()`). Elixir's `%{key: val}` pattern in a function head matches any map with at least those keys — structurally open at runtime. But Dialyzer's inferred/declared type for that same syntax in a `@spec` is treated as a **closed** map (exactly those two keys) unless written some other way. A real `%Qx.Register{}` struct always carries an extra `:__struct__` key, so it structurally fails to match a closed 2-key map type, even though every value the code actually needs (`:state`, `:num_qubits`) is present.

## Root Cause

```elixir
# The problematic spec — reads as CLOSED to Dialyzer
@spec valid_register?(%{state: Nx.Tensor.t(), num_qubits: integer()}, float()) :: boolean()
```

vs. the actual runtime caller:

```elixir
# lib/qx/register.ex:797 — a real struct, with an extra :__struct__ key
Qx.Validation.valid_register?(%Qx.Register{num_qubits: n, state: s})
```

## Solution

Widen the spec to the fully open `map()` type — confirmed the ONLY thing that works. Tried a "keyed but supposedly open" alternative first (`%{required(:state) => Nx.Tensor.t(), required(:num_qubits) => integer()}`) expecting `required()` to signal openness; it did not — Dialyzer still treated it as closed and reproduced the exact same 3-warning cascade. `map()` alone resolved it:

```elixir
# Accepts anything struct-or-map shaped with :state/:num_qubits (in
# practice a %Qx.Register{}). Spec is intentionally bare map() rather than
# a keyed shape: Dialyzer treats any keyed map/struct-pattern spec here as
# closed, which then excludes %Qx.Register{}'s extra :__struct__ key and
# reintroduces the false "no local return" this widening fixed.
@spec valid_register?(map(), float()) :: boolean()
def valid_register?(%{state: state, num_qubits: num_qubits}, tolerance \\ 1.0e-6) do
```

The runtime pattern match (`%{state: state, num_qubits: num_qubits}`) is unaffected and still enforces the actual required keys at the function-head level — only the *declared spec* needed loosening, because that's what Dialyzer's caller-side check uses.

### Files Changed

- `lib/qx/validation.ex:50-56` — `valid_register?/2` spec widened to `map()`, comment added explaining why

## Prevention

- [ ] Add to Iron Laws? Not foundational, but worth a callout in typespec guidance.
- [x] Add to agent checks — `elixir-reviewer`/`iron-law-judge` could flag an anonymous `%{key: type, ...}` `@spec` on a function whose head pattern is later called with a real struct anywhere in the codebase (grep for `%ModuleName{...}` at any call site of the function).
- Specific guidance: **never use a bare anonymous map shape (`%{key: type}`) in a `@spec` for a function meant to accept a struct.** Dialyzer treats that shape as closed and will reject the struct's extra `:__struct__` key even though the runtime pattern match succeeds fine. Either spec the real struct type (`Qx.Register.t()`) if the function is genuinely struct-only, or use `map()` if it's intentionally duck-typed to accept struct-or-plain-map — and leave a comment, since `map()` alone doesn't document which keys are required. `required(:key) => type` inside a `%{}` spec does **not** make it open — verified this empirically, it still collapses to closed and reproduces the same false positive.

## Related

- `.claude/solutions/build-issues/nx-type-atom-shorthand-spec-cascade-qx-state-init-20260719.md` — the other, larger dialyzer false-positive found in the same `dialyxir` install session, different root cause
