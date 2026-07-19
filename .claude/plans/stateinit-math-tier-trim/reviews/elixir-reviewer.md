# Elixir Review: stateinit-math-tier-trim

Scope: lib/qx/math.ex, lib/qx/state_init.ex, lib/qx/qubit.ex, lib/qx/register.ex,
lib/qx/behaviours/quantum_state.ex, lib/qx.ex, test/qx/tier_trim_test.exs,
test/qx/math_test.exs, AGENTS.md, CHANGELOG.md.

## Summary
- **Status**: Approved (no blockers found)
- **Issues Found**: 0 blockers, 2 warnings, 3 suggestions

## BLOCKER
None.

## WARNING

1. **lib/qx/math.ex / lib/qx/state_init.ex — doctests exercise the very functions they deprecate.**
   Every deprecated function's own `## Examples` doctest still calls itself
   (e.g. `state_init.ex:83` `Qx.StateInit.zero_state(1)`, `math.ex:78`
   `Qx.Math.inner_product(...)`). `doctest Qx.Math` / presumably `doctest
   Qx.StateInit` in the corresponding test files turn these into
   cross-module calls compiled under `mix test`, which will now emit a
   deprecation warning per doctest (17 new warning sites). This doesn't
   break the mandated `mix compile --warnings-as-errors` gate (test/ isn't
   part of `mix compile`), but it does mean `mix test` output going forward
   is noisy with self-inflicted deprecation warnings on every run — easy to
   miss a real new deprecation warning once these become background noise.
   Confirm this was accepted deliberately (plan/scratchpad) rather than
   overlooked; if not, consider trimming the doctest bodies to assertions
   that don't literally invoke the deprecated name (e.g. via `@compiler
   :nowarn_deprecated_function` equivalent isn't available at doctest
   granularity in Elixir, so the realistic options are: accept the noise,
   or drop the runnable `iex>` prompts and keep prose-only examples for the
   17 deprecated functions).

2. **test/qx/math_test.exs — existing describe blocks for `kron/2`,
   `inner_product/2`, `outer_product/2`, `apply_gate/2`, `trace/1`,
   `identity/1`, `unitary?/1`, `complex/2` still call these functions
   directly** (e.g. `math_test.exs:25` `Math.kron(a, b)`). Same
   consequence as #1 — each test run now prints a deprecation warning for
   every one of these calls. Not a correctness issue (tests still pass;
   plan explicitly did not want these tests deleted, only the two
   converter describe blocks), but worth a one-line note in the plan's
   scratchpad so a future contributor doesn't mistake the warning volume
   for a regression.

## SUGGESTION

1. **lib/qx/state_init.ex:218 — `random_state/2` deprecation notice says
   "No replacement"** but the body immediately below is the exact recipe
   (`for _ <- 0..(dimension-1) do ... end |> Nx.tensor |> Qx.Math.normalize`).
   Same pattern is now duplicated three times in the diff: here, in
   `lib/qx/qubit.ex:155-161` (`Qx.Qubit.random/0`, already inlined per this
   PR), and implicitly in any future caller who copies the doctest. Since
   two of the three copies already exist in `lib/`, consider whether the
   deprecation message for `random_state/2` should point at
   `Qx.Qubit.random/0`'s inline pattern as the canonical recipe reference
   rather than "no replacement," to avoid a fourth copy appearing during
   consumer migration. Low priority — doesn't block this PR.

2. **lib/qx/qubit.ex:163-168 — `hadamard_basis_state/1` naming.** The
   function builds `(|0⟩ ± |1⟩)/√2`, i.e. the eigenstates of X, not
   literally "the Hadamard basis state" in the sense of applying an H
   gate to a basis state (though mathematically equivalent to `H|0⟩`
   and `H|1⟩` up to global phase on the second). The comment above it is
   accurate and clarifies intent, so this is purely a naming nit — a name
   like `pm_basis_state/1` or `x_eigenstate/1` would read slightly clearer
   given `sign` is the actual parameter, not a Hadamard operation being
   applied. Not worth a rename on its own.

3. **lib/qx/state_init.ex — moduledoc replacement-pointer audit.** Spot
   checked all 9 replacement messages against the plan's "Replacement
   already corrected to `Qx.Patterns.superposition_circuit/1`" note —
   confirmed correct at line 184. All other replacement pointers
   (`Qx.bell_state/1`, `Qx.ghz_state/0`, `basis_state(...)`, inline
   recipes) read as accurate against the current `Qx`/`Qx.Patterns`
   public API. No further action; noted for completeness since this was
   explicitly called out as a prior correction in the WHY-CONTEXT.

## Notes (verified, not issues)

- `@deprecated` correctly placed on the header-only clause for multi-clause
  functions (`bell_state_vector/2` in state_init.ex:278-280,
  `ghz_state_vector/2` at :355-357), which is the right place per Elixir's
  `@deprecated`/`@doc` attribute semantics (applies once per function name/arity,
  attaches to the first clause).
- `test/qx/tier_trim_test.exs` correctly reads `Code.fetch_docs/1` metadata
  rather than grepping source, and correctly asserts against max-arity only
  (functions with default args expose one doc entry) — matches every
  function signature checked against `lib/qx/math.ex` and
  `lib/qx/state_init.ex`.
- No internal `lib/` caller invokes a newly-deprecated function outside of
  its own doctest — `Register.new/1` now calls `StateInit.basis_state/2`
  (not deprecated), `Qubit.plus/0` and `Qubit.minus/0` use the new private
  `hadamard_basis_state/1` instead of `StateInit.plus_state/minus_state`,
  and `Qubit.random/0` inlines random amplitudes + `Math.normalize/1`
  instead of `StateInit.random_state/2`. Confirmed via grep — no stray
  internal deprecated-call sites.
- `Qx.Behaviours.QuantumState` demotion to `@moduledoc false` keeps
  callbacks intact and `Register`'s `@behaviour` declaration unchanged —
  consistent with the stated "both die together at 1.0" comment.
- `Qx.ex` moduledoc's module list no longer references the behaviour and
  the `Qx.StateInit` line is tightened to "Basis-state vector constructor,"
  consistent with the trim.

## Pre-existing (ignored per instructions)

None beyond the two already-flagged IO.puts sites called out in the task
(qubit.ex show/print helpers, qx.ex tap_* doctest examples) — not re-listed.
