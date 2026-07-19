---
module: "Qx.StateInit"
date: "2026-06-27"
problem_type: api_deprecation
component: public_api
symptoms:
  - "`Qx.StateInit.bell_state/2` and `ghz_state/2` return state vectors (`Nx.Tensor`), but `Qx.bell_state/1` and `Qx.ghz_state/0` return circuits (`%Qx.QuantumCircuit{}`) — same verb, opposite return type (public-api audit S1 CRIT foot-gun)"
  - "Needed to rename the state-vector returners to `*_vector` WITHOUT breaking existing callers or forcing a major-version bump"
  - "Discovered mid-work: `Nx.tensor(_, type: :c32)` raises `** (ArgumentError) invalid numerical type: :c32 (see Nx.Type docs for all supported types)` — an inherited docstring claimed `:c64 or :c32`"
root_cause: "Renaming a public function is a breaking change unless the old name is kept as a working alias. The repo's established remedy is a deprecation shim: ship the new canonical name carrying the full `@doc`, and collapse the old name to a thin `@deprecated` + `@doc false` delegator. Additive + deprecation only → no major bump. Separately, Nx has no `:c32` complex type (only `:c64` = 2×float32 and `:c128` = 2×float64); the lowest-precision complex width IS `:c64`."
severity: medium
tags: [deprecation, deprecated-shim, public-api, rename, api-naming, warnings-as-errors, nx-complex-types, c32, c64, c128, tdd]
related_solutions: ["sweep-typed-errors-public-surface-iron-law-7-20260624"]
---

# Renaming a public function via a deprecation shim (and the `:c32` Nx gotcha)

## Symptoms

- `Qx.StateInit.bell_state/2` / `ghz_state/2` return **state vectors**, while
  the similarly-named `Qx.bell_state/1` / `Qx.ghz_state/0` return **circuits**.
  Same verb, opposite return type — flagged **S1 CRIT** by the public-api audit.
- The rename to `bell_state_vector/2` / `ghz_state_vector/2` had to keep ~20
  existing callers (tests, tutorials) compiling and must NOT be a breaking
  change (no major bump available in the 0.8.x line).
- Mid-implementation, a `:c32` type-parameter test failed:
  `** (ArgumentError) invalid numerical type: :c32`. The docstring being moved
  claimed the function accepted "`:c64` or `:c32`".

## Investigation

1. **Hypothesis: just rename and update all callers** — rejected. That's a
   breaking change (callers outside the repo would break), and the test-guard
   hook blocks editing `*_test.exs` anyway. Wrong shape for a 0.8.x minor.
2. **Found the established pattern**: two shims already in the tree —
   `Qx.histogram/2`→`draw_histogram/2` (`lib/qx.ex`) and the
   `Qx.Math.basis_state/2` deprecation (`lib/qx/math.ex:220-228`). Mirror them.
3. **Will `@deprecated` break `mix compile --warnings-as-errors`?** Empirically
   **no** — a `@deprecated` call site prints a deprecation warning but the build
   exits 0. So existing callers can stay on the old names and double as live
   delegation coverage. (Verified before relying on it.)
4. **`:c32` probe** — `Nx.tensor([Complex.new(1.0,0.0)], type: :c32)` raises;
   `:c64` yields `{:c, 64}`. Nx supports only `:c64` and `:c128` for complex.
   The docstring was simply wrong; `:c64` is already the lowest complex width.

## Root Cause

Renaming a public function breaks callers unless the old name survives as a
working alias. The fix is a **deprecation shim**, not a rename:

```elixir
# OLD: multi-clause function returning a state vector
def bell_state(:phi_plus, type), do: Nx.tensor([...], type: type)
def bell_state(:phi_minus, type), do: ...
```

The `:c32` failure was an independent latent doc bug: **Nx has no `:c32`**.
Complex tensors are `:c64` (float32 components) or `:c128` (float64); there is
nothing narrower than `:c64`.

## Solution

New canonical name owns the full `@doc` + `@spec` + `@type`; old name becomes a
thin `@deprecated`, `@doc false` delegator:

```elixir
@type bell_state_which :: :phi_plus | :phi_minus | :psi_plus | :psi_minus

@doc """..full prose, table, doctests (updated to call bell_state_vector)..."""
@spec bell_state_vector(bell_state_which(), Nx.Type.t()) :: Nx.Tensor.t()
def bell_state_vector(which \\ :phi_plus, type \\ :c64)
def bell_state_vector(:phi_plus, type), do: Nx.tensor([...], type: type)
# ...other clauses...

# Deprecated: use `Qx.StateInit.bell_state_vector/2` — the `_vector` suffix
# names the return type, disambiguating from circuit-returning `Qx.bell_state/1`.
@deprecated "Use Qx.StateInit.bell_state_vector/2"
@doc false
def bell_state(which \\ :phi_plus, type \\ :c64) do
  bell_state_vector(which, type)
end
```

Key decisions that made it clean:

- **Collapse the shim to a single delegating clause** with default args — don't
  carry the old multi-clause body. The deprecated delegator needs no guard if
  the canonical function already guards (a guard on a pure delegator is
  redundant — matches the `math.ex` shim).
- **Leave existing callers on the old names.** They keep the suite green AND act
  as live delegation coverage. `--warnings-as-errors` does not promote
  `@deprecated` warnings.
- **New `_vector` tests go in a NEW file** (test-guard hook blocks editing the
  existing `*_test.exs`). Assert the canonical name's behaviour directly,
  including **amplitude signs** (`Nx.real`) — probability-only checks can't tell
  `:phi_plus` from `:phi_minus`. Do NOT write `bell_state(w) == bell_state_vector(w)`:
  since the shim is `do: bell_state_vector(w)`, that's `x == x`, a tautology with
  zero signal. Instead assert the deprecated name against an independent reference.
- **CHANGELOG**: add both `### Added` (the new names) and `### Deprecated` (old
  names, "kept through 0.8.x, removal in v0.9") even with no version bump.
- **`:c32` → `:c128`** in both the test and the inherited docstring.

### Files Changed

- `lib/qx/state_init.ex` — `bell_state_vector/2` + `ghz_state_vector/2` canonical;
  old `bell_state/2` + `ghz_state/2` now `@deprecated` + `@doc false` delegators;
  docstring `:c32`→`:c128`
- `lib/qx.ex`, `lib/qx/patterns.ex` — 4 `## See Also` cross-refs → `_vector` names
- `test/qx/state_init_vector_test.exs` — new; probability + sign + deprecated-path
  + type-arg coverage
- `CHANGELOG.md` — `### Added` + `### Deprecated` under `[Unreleased]`

## Prevention

- [ ] Add to Iron Laws? No — Iron Law #6 already mandates the CHANGELOG entry;
      this is the *how* for the non-breaking rename case.
- [x] Add to test patterns: a "delegation equivalence" test against a one-line
      delegator is tautological — assert observable behaviour (incl. sign) of
      each name independently instead.
- Specific guidance:
  - **To rename a public function in a minor release**: ship the new name with
    the full doc/spec, make the old name a `@deprecated` + `@doc false`
    delegator, leave existing callers, add a `### Deprecated` CHANGELOG line,
    schedule removal for the next major. `--warnings-as-errors` stays green.
  - **Nx complex types are `:c64` and `:c128` only** — there is no `:c32`.
    `:c64` is the narrowest complex width. Grep docstrings for `:c32` before
    trusting them.

## Related

- `lib/qx/math.ex:220-228` — `Qx.Math.basis_state/2` deprecation shim (template)
- `lib/qx.ex` — `Qx.histogram/2` → `Qx.draw_histogram/2` shim (template)
- Iron Law #6: breaking public-API change → CHANGELOG + major bump (this change
  is additive+deprecation, so CHANGELOG only, no bump)
- `.claude/solutions/architecture-issues/sweep-typed-errors-public-surface-iron-law-7-20260624.md`
  — sibling public-API-surface cleanup from the same audit
