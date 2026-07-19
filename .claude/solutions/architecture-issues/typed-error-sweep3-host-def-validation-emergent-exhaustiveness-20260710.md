---
module: "Qx.Math / Qx.QuantumCircuit / Qx.Operations / Qx.SimulationResult / Qx.StateInit / Qx.Patterns"
date: "2026-07-10"
problem_type: iron_law_violation
component: architecture
symptoms:
  - "`Qx.Math.normalize/1` returned a silent `[NaN, NaN]` tensor on an all-zero input instead of raising — a `defn` divided by a zero norm with no guard (finding R-09)"
  - "`Qx.create_circuit/1,2`, the single/two-qubit gate builders (`h`/`cx`/…), `bell_state(:bogus)`, `ghz_state(1)`, `c_if` non-integer bit, `StateInit.basis_state/2,3`, `filter_by_probability(result, 1)`, and `rx/ry/rz/phase` non-numeric angle all leaked a raw `FunctionClauseError` on already-invalid input"
  - "review flagged the `new/2` and `filter_by_probability/2` fallback clauses as relying on *emergent* validator exhaustiveness: they could silently return `:ok` (violating the `@spec`) if a validator guard were later edited"
root_cause: "Third Iron Law #7 sweep. The remaining tier-1/2 raw-`FunctionClauseError` escapes were guard-only clauses with no typed fallback. The `normalize` NaN was a missing zero-norm check on a pure `defn`; fixing it correctly required moving the check to a host `def` WITHOUT adding host sync to the simulation renorm hot path (Iron Laws #5/#8)."
severity: medium
iron_law_number: 7
tags: [iron-law-7, iron-law-5, iron-law-8, typed-errors, functionclauseerror, defn-to-def, host-sync, guard-relaxation, emergent-exhaustiveness, additive-widening, defexception, nx]
related_solutions: ["sweep-typed-errors-public-surface-iron-law-7-20260624", "route-validation-raises-to-typed-errors-iron-law-7-20260624", "characterize-unvalidated-nx-kernels-regression-net-calcfast-20260626"]
---

# Typed-error sweep #3: host-`def` validation on a `defn`, and the emergent-exhaustiveness fallback trap

## Symptoms

The third Iron Law #7 pass (after [[route-validation-raises-to-typed-errors-iron-law-7-20260624]]
and [[sweep-typed-errors-public-surface-iron-law-7-20260624]]). It closed the last
tier-1/2 `FunctionClauseError` escapes, fixed the `normalize` zero-vector NaN, and
added build-time parameter validation. Every fixed input **already crashed** — the
change is non-breaking; only the exception type improves.

| Site | Old | New |
|---|---|---|
| `create_circuit/1,2` non-integer / negative bits | FCE | `QubitCountError` / `ClassicalBitError` (`{:not_an_integer,…}` / `{:invalid_count,…}`) |
| `h`/`x`/…/`cx` non-integer qubit | FCE | `QubitIndexError {:not_an_integer,…}` (choke point) |
| `bell_state(:bogus)` / `ghz_state(1 or :x)` | FCE | `OptionError {:which,…}` / `QubitCountError` |
| `c_if` non-integer classical bit | FCE | `ClassicalBitError {:not_an_integer,…}` |
| `basis_state/2,3` bad index/dimension | FCE | `BasisError` (`:reason` + `:dimension`) |
| `filter_by_probability(result, 1)` | FCE | **returns** (integer widening); out-of-range → `OptionError {:threshold,…}` |
| `Math.normalize(zero)` | silent `NaN` | `StateNormalizationError` |
| `rx/ry/rz/phase` non-number angle | stored, detonated later | `ParameterError` at build time |

## Root Cause

Iron Law #7 debt: guard-only clauses (`when is_integer(...)`) with no fallback, so
invalid input fell through to `FunctionClauseError`. The `normalize` NaN was a
separate class — a pure `defn` (`state / norm`) with no zero-norm guard.

## Solution — the non-obvious parts

### 1. Add a host-side validation to a public `defn` WITHOUT slowing the hot path

`Qx.Math.normalize/1` was a `defn`. Adding a zero-norm check needs a host-side
`Nx.to_number/1` sync — but `normalize` is also called in the simulation renorm
hot path, where a per-step sync is forbidden (Iron Law #5: no host loops over
amplitudes; #8: dev/test syncs must be compile-gated out of `:prod`).

The resolution is a **host `def` wrapper + private `defn` kernel**:

```elixir
def normalize(state) do
  norm = Nx.abs(state) |> Nx.pow(2) |> Nx.sum() |> Nx.sqrt() |> Nx.to_number()
  if norm == 0.0 do
    raise Qx.StateNormalizationError, "Cannot normalize a zero-norm state vector ..."
  end
  normalize_unchecked(state)
end

@doc false
defn normalize_unchecked(state) do        # byte-identical to the former defn
  norm = Nx.sqrt(Nx.sum(Nx.abs(state) ** 2))
  state / norm
end
```

Then the renorm hot path (`simulation.ex` `maybe_measurement_renorm`/`maybe_gate_renorm`)
calls `normalize_unchecked/1`: post-gate states are unit-norm by construction, so
they never need the check, and the pure `defn` adds **zero** host sync.

Key judgement — **the public check is NOT compile-gated.** Contrast with the same
file's `assert_norm` (a dev/test drift guard wrapped in `if @assert_norm`, compiled
`false` in `:prod`). Gating the zero-norm check out of `:prod` would resurrect the
exact silent-NaN bug being fixed. Rule: a **permanent input validation** stays live
in prod; only a **dev/test assertion** is compile-gated. The `mix bench` renorm suite
is the proof the hot path didn't regress (it didn't — same kernel).

### 2. `**` is `defn`-only; use `Nx.pow/2` in a plain `def`

Moving `Nx.abs(state) ** 2` out of `defn` and into the host `def` breaks: the `**`
operator on tensors is only overloaded inside `Nx.Defn`. In a plain `def`, `**` is
`Kernel.**/2` (numbers only) → it fails on a tensor. Use `Nx.pow/2`. Also verify no
`defn` calls the new host `def normalize/1` (a `defn`→host-`def` call won't compile).

### 3. Don't let a fallback's "always raises" property be emergent (review catch)

The first cut added a guarded primary clause plus a fallback:

```elixir
def new(nq, ncb) when is_integer(nq) and is_integer(ncb) and ncb >= 0, do: ...build...
def new(nq, ncb) do                     # fallback — reached only on invalid input
  Qx.Validation.validate_num_qubits!(nq)
  Qx.Validation.validate_num_classical_bits!(ncb)   # returns :ok if it doesn't raise!
end
```

This raises *today* only because the two independent validator guards happen to
exactly complement the primary clause's guard. If a validator guard is later edited,
the fallback silently returns `:ok` — a `%QuantumCircuit{}` `@spec` violation with no
compiler warning. `elixir-reviewer` flagged it; `iron-law-judge` had passed it (it
raises correctly *now*), so this is a **robustness** finding a quality reviewer
catches, not a correctness bug.

Fix — **collapse to a single unguarded clause that validates up front**, so the
raise is explicit, not emergent:

```elixir
def new(nq, ncb) do
  Qx.Validation.validate_num_qubits!(nq)          # raises: non-integer or 1..20
  Qx.Validation.validate_num_classical_bits!(ncb) # raises: non-integer or negative
  ...build...
end
def new(nq), do: new(nq, 0)
```

Same treatment for `filter_by_probability/2` (guard → up-front `validate_probability!/1`).
Bonus: it makes the validator the single source of truth (no guard/fallback to drift
apart) and removes dead clauses (credo mods/funs dropped as clauses collapsed).

### 4. Guard-relaxation at a *choke point* fixes a whole wrapper family at once

`h`/`x`/`y`/`z`/`s`/`t`/… all delegate to `QuantumCircuit.add_gate/4`; `cx`/`cz`/… to
`add_two_qubit_gate/5`. Dropping `is_integer(qubit)` from those two guards (so a
non-integer reaches `validate_qubit_index!/2`, which now has a `{:not_an_integer,…}`
fallback) fixes the **entire** single/two-qubit wrapper family at one site — no
per-wrapper edits. (Three-qubit `add_three_qubit_gate/6` already raised typed via
`validate_indices_integers!`; leave it.) This extends the predecessor's guard-vs-
validator lesson: relax at the shared delegate, not per-caller.

### 5. Not every FCE should become a raise — some inputs should become *valid*

`filter_by_probability/2` guarded `is_float(threshold)`, so integer `1` crashed. The
right fix is **additive**, not a retype: `1` is a legitimate probability. Widen to
`is_number(threshold) and threshold >= 0 and threshold <= 1` (spec `float()`→`number()`),
so integer `0`/`1` become valid; only genuinely out-of-range/non-number raises
`OptionError`. A CHANGELOG `Changed` entry, not just `Fixed`. When triaging an FCE
site, ask "is this input actually invalid?" before reaching for a typed raise.

### 6. `BasisError` extended with a `:reason`; catch-all stays LAST

`basis_state` reuses `Qx.BasisError` (built by sweep #2 for the 0/1 basis-value check)
via new tuple clauses (`{:not_an_integer,v}` / `{:negative,v}` / `{:out_of_range,i,d}`
/ `{:invalid_dimension,v}`). Because the existing `exception(value)` catch-all matches
*any* term (including tuples), the new tuple clauses MUST be placed **before** it, or
they're shadowed. Same trap on `ClassicalBitError`, whose `{bit, max}` clause is
**unguarded** and would swallow `{:not_an_integer, v}` / `{:invalid_count, v}` — the
atom-tagged clauses go first. `iron-law-judge` verified no shadowing.

## Prevention

- [x] **Already Iron Law #7** — `iron-law-judge` flags raw `FunctionClauseError` across the public boundary.
- **Permanent validation ≠ dev/test assertion.** A real input check stays live in `:prod`; only a drift/debug assertion is `Application.compile_env`-gated (Iron Law #8). Gating a real validation out of prod re-introduces the bug it fixes.
- **`defn`→host-`def` split** is the pattern for adding host-side validation to a public numeric fn without taxing hot-path callers: host `def` (validate + `Nx.to_number`) → private `defn` kernel; internal hot paths call the kernel. Prove no regression with `mix bench`.
- **`**` is `defn`-only** — use `Nx.pow/2` in plain `def`; no `defn` may call a host `def`.
- **A fallback clause must raise *explicitly*, not emergently.** If a clause's "always raises" depends on two guards complementing each other, collapse to a single clause that validates up front. Reviewers (not the iron-law-judge) catch this — it passes correctness today but is a latent `@spec` violation.
- **Relax the guard at the choke point**, not per wrapper — one delegate edit fixes the whole family.
- **Not every FCE → raise.** Ask whether the input is genuinely invalid; if it's valid (e.g. integer probability), widen the guard (additive, `Changed`) instead of typing an error.
- **Atom-tagged `exception/1` clauses before any unguarded/bare catch-all**, or they're shadowed. Add a struct-field test per reason.
- **Probe empirically as completion proof.** A `mix run` probe script that rescues each site and prints `e.__struct__` — run before (records the FCE baseline) and after (every site now typed; the one widened site *returns*). Pairs with the grep proof.

## Related

- Predecessor [[sweep-typed-errors-public-surface-iron-law-7-20260624]] (0.8.1) — built `Qx.BasisError` (0/1 value check) that this sweep extended with index/dimension reason variants; established grep-is-the-spec and guard-relaxation.
- Predecessor [[route-validation-raises-to-typed-errors-iron-law-7-20260624]] (0.8.1) — built the `Qx.Validation` bang helpers this sweep added `{:not_an_integer,…}` fallbacks to.
- [[characterize-unvalidated-nx-kernels-regression-net-calcfast-20260626]] — the "unvalidated `defn` kernel" risk class the `normalize` NaN belongs to.
- Shipped on `main` in squash commit `d2a2b65` after `/phx:review` PASS (5 agents; 3 warnings fixed pre-merge). 250 doctests + 1030 tests, 0 failures. Ticks the v0.11 "Typed-error sweep #3" ROADMAP item.
