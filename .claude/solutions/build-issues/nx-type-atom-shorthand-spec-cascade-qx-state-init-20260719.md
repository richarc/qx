---
module: "Qx.StateInit"
date: "2026-07-19"
problem_type: build_error
component: configuration
symptoms:
  - "mix dialyzer: 'Function basis_state/2 has no local return.'"
  - "mix dialyzer: 'The @spec for the function does not match the success typing of the function... Success typing: (_, _) :: none()'"
  - "56 of 70 total dialyzer warnings across unrelated-looking modules (Qx.Register.new/1, Qx.Qubit.new/0,1, Qx.create_circuit/1,2, Qx.Patterns.*, Qx.QuantumCircuit.new/1,2) all bottoming out at the same 3 root functions"
  - "mix test / mix compile --warnings-as-errors both pass cleanly — only dialyzer flags it"
root_cause: "@spec declared a type parameter as Nx.Type.t() (Nx's canonical tuple form only, e.g. {:c, 64}), but the function's own default argument passes the atom shorthand (:c64) that Nx.Type.t() does not include — Dialyzer sees the function's own default-arg call as violating its own declared contract, infers the function can never return, and cascades that through every caller"
severity: "medium"
tags: [dialyzer, dialyxir, typespec, nx, atom-shorthand, cascade, false-positive]
elixir_version: "1.20.2"
---

# Nx.Type.t()-only @spec rejects Qx's own :c64 atom-shorthand default arg, cascades through the whole call graph

## Symptoms

First `mix dialyzer` run after installing `dialyxir` (`{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}`) produced 70 warnings. The overwhelming majority (56) were `no_return` / `invalid_contract` errors on functions that looked completely unrelated to each other — `Qx.Register.new/1`, `Qx.Qubit.new/0`, `Qx.Qubit.one/0`, `Qx.create_circuit/1,2`, `Qx.Patterns.bell_state_circuit/1`, `Qx.QuantumCircuit.new/1,2`, `Qx.QuantumCircuit.reset/1`, etc. — with messages like:

```
lib/qx/state_init.ex:70:7:no_return
Function basis_state/2 has no local return.

lib/qx/state_init.ex:70:42:call
The function call will not succeed.

Qx.StateInit.basis_state(_1 :: any(), _2 :: any(), :c64)

breaks the contract
(non_neg_integer(), pos_integer(), Nx.Type.t()) :: Nx.Tensor.t()
```

`mix compile --warnings-as-errors` and `mix test` (1405 tests) were both green throughout — the code is runtime-correct. Only Dialyzer's static success-typing analysis flags it.

## Investigation

1. **Hypothesis: real bug in `Register.new/1`** — read the function body, looked completely fine (`Integer.pow(2, num_qubits)` passed to `StateInit.basis_state/2`). No obvious logic error.
2. **Hypothesis: something upstream is broken, and this is just where the cascade surfaces** — grepped for `Nx.Type.t()` in `lib/`, found exactly 3 occurrences: `Qx.StateInit.basis_state/3`, `bell_state_vector/2`, `ghz_state_vector/2`. All three have a default arg `type \\ :c64` — an atom literal.
3. **Root cause found**: checked `deps/nx/lib/nx/type.ex` — `Nx.Type.t()` is defined as *only* the tuple form (`{:s, 8} | {:u, 8} | ... | {:c, 64} | {:c, 128} | ...`). Nx separately defines `Nx.Type.short_t()` as the atom-shorthand union (`:s8 | :u8 | ... | :c64 | :c128 | ...`) specifically for this convenience — `Nx.Type.normalize!/1` accepts either and converts atoms to tuples at runtime. Qx's own `@spec`s used only `Nx.Type.t()`, so a function's *own default argument* (`:c64`) violated its *own declared contract*. Dialyzer's success-typing analysis is a whole-function-body property, not per-call-site — once it decides the function can never satisfy its declared spec, it propagates "no local return" through every single caller, no matter how unrelated they look.

## Root Cause

```elixir
# lib/qx/state_init.ex — before
@spec basis_state(non_neg_integer(), pos_integer(), Nx.Type.t()) :: Nx.Tensor.t()
def basis_state(index, dimension, type \\ :c64)  # :c64 doesn't satisfy Nx.Type.t()!
```

Nx itself defines the split:

```elixir
# deps/nx/lib/nx/type.ex
@type t :: {:s, 2} | ... | {:c, 64} | {:c, 128} | {:tuple, non_neg_integer}
@type short_t :: :s8 | ... | :c64 | :c128
```

## Solution

Widen the affected specs to the union Nx itself documents for exactly this convenience:

```elixir
@spec basis_state(non_neg_integer(), pos_integer(), Nx.Type.t() | Nx.Type.short_t()) ::
        Nx.Tensor.t()
def basis_state(index, dimension, type \\ :c64)
```

Applied identically to `bell_state_vector/2` and `ghz_state_vector/2`. This alone cleared 56 of the 70 original warnings — everything downstream that called these three functions (directly or via the demoted internal calc engine `Qx.Register`/`Qx.Qubit`) resolved automatically once the root contracts were satisfiable.

### Files Changed

- `lib/qx/state_init.ex:69-70` — `basis_state/3` spec widened
- `lib/qx/state_init.ex:309` — `bell_state_vector/2` spec widened
- `lib/qx/state_init.ex:386` — `ghz_state_vector/2` spec widened

## Prevention

- [ ] Add to Iron Laws? Not foundational enough on its own, but worth a note under Iron Law #8 (precision/tolerance) or a new "typespec hygiene" callout since `:c64`/`:c128` literals appear throughout Qx's public API defaults.
- [x] Add to agent checks — `iron-law-judge` or `elixir-reviewer` could flag `Nx.Type.t()` used bare in a `@spec` when the function has a `\\` default that's an atom shorthand.
- Specific guidance: whenever a Qx function's default argument (or any commonly-passed literal) is an `Nx.Type` atom shorthand (`:c64`, `:f32`, etc.), the `@spec` must use `Nx.Type.t() | Nx.Type.short_t()`, not `Nx.Type.t()` alone. When a single dialyzer warning looks like it should be impossible (a trivial function "has no local return"), suspect a self-inconsistent `@spec` before suspecting the function body — check whether a default argument or a commonly-passed literal actually satisfies the declared parameter type.

## Related

- `.claude/solutions/build-issues/dialyzer-closed-map-spec-excludes-struct-qx-validation-20260719.md` — a second, independent dialyzer false-positive found in the same install, different root cause (map type closure, not atom-shorthand typing)
