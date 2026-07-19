# Deprecate `Qx.StateInit.bell_state` / `ghz_state` → `*_vector`

**Slug:** `stateinit-vector-deprecation`
**Branch:** `feat/stateinit-vector-deprecation`
**ROADMAP:** qx v0.8.1, line 34 (audit: public-api **S1 CRIT**)
**Type:** Additive + deprecation. **Not** a breaking change → no major bump.

## Problem

`Qx.StateInit.bell_state/2` and `Qx.StateInit.ghz_state/2` return **state
vectors** (`Nx.Tensor`). But `Qx.bell_state/1` and `Qx.ghz_state/0` return
**circuits** (`%Qx.QuantumCircuit{}`). Same verb, opposite return type — the
audit flagged this as a CRIT readability/foot-gun. The fix: give the
state-vector returners a `_vector` suffix so the name signals the return
type, and deprecate the old names through the 0.8.x window.

## Approach

Mirror the two deprecation shims already in the tree:

- `Qx.histogram/2` → `Qx.draw_histogram/2` (`lib/qx.ex:1058-1065`)
- `Qx.Math.basis_state/2` (`lib/qx/math.ex:220-228`)

Pattern: new canonical function carries the full `@doc`; old name becomes
`@deprecated "Use …"` + `@doc false`, delegating to the new one with
identical behaviour.

## Decided constraints (do not re-litigate)

- **Tests stay on the old names.** The ~20 calls in
  `test/qx/state_init_test.exs` are left UNCHANGED — verified empirically
  that `mix compile --warnings-as-errors` does **not** promote `@deprecated`
  warnings to errors (a deprecation warning prints, exit 0). Those existing
  calls double as live coverage that the deprecated aliases still delegate.
- **New tests are additive.** Coverage for the `_vector` names goes in a
  **new** file, `test/qx/state_init_vector_test.exs`. ⚠️ The PreToolUse
  test-guard hook blocks `Write` to any `*_test.exs` path — so creating this
  file needs explicit human approval at `/phx:work` time. Surface the file
  content, get approval, write it, confirm it fails, then implement (TDD).
- **No breaking change / no major bump.** Old names keep working. Their
  removal is already a separate v0.9 ROADMAP item (line 94) — out of scope.
- **CHANGELOG entry required** (Iron Law #6 — even without a version bump).

## Iron Law check

- **#6 (public API breaking → CHANGELOG + major bump):** Additive +
  deprecation only, no signature/behaviour change to existing names → no
  major bump. CHANGELOG entry added regardless. ✅
- **#7 (typed errors):** No new error paths; existing guards/raises
  unchanged. The `_vector` functions inherit the old guards verbatim. ✅
- **#8 (tolerances):** No tolerance assertions introduced; new tests reuse
  the existing `< 0.01` / `< 1.0e-6` probability fixtures. ✅

---

## Phase 1 — New `state_init_vector_test.exs` (TDD, additive)

> Needs human approval (test-guard hook). Write first; expect failure.

- [x] Create `test/qx/state_init_vector_test.exs` with a `describe` block:
  - [x] `bell_state_vector/0,1,2` produces the four Bell vectors — mirror
        the probability assertions from `state_init_test.exs:212-275`
        (`:phi_plus` default, `:phi_minus`, `:psi_plus`, `:psi_minus`).
  - [x] `ghz_state_vector/1,2` for 2/3/4/5 qubits — mirror
        `state_init_test.exs:284-321`.
  - [x] **Delegation equivalence:** `StateInit.bell_state(w) == StateInit.bell_state_vector(w)`
        for each `w`, and `StateInit.ghz_state(n) == StateInit.ghz_state_vector(n)`
        for `n in 2..5`, asserted with `Nx.equal/2` + `Nx.all/1` (or
        `assert Nx.to_number(Nx.all(Nx.equal(a, b))) == 1`).
  - [x] `:c32` type param is honoured on both `_vector` functions
        (`Nx.type/1` check).
- [x] `mix test test/qx/state_init_vector_test.exs` — confirm RED
      (functions undefined). — 12 tests, 12 failures, all UndefinedFunctionError.

## Phase 2 — Canonical `_vector` functions + deprecate old (`lib/qx/state_init.ex`)

- [x] Add `bell_state_vector(which \\ :phi_plus, type \\ :c64)` as the new
      canonical function. Move the full `@doc` (prose + table + examples +
      the `## See Also → Qx.bell_state/1` block) from the current
      `bell_state` onto it. Update the doctests to call
      `Qx.StateInit.bell_state_vector(...)`. Add
      `@spec bell_state_vector(bell_state_which(), Nx.Type.t()) :: Nx.Tensor.t()`
      with a `@type bell_state_which :: :phi_plus | :phi_minus | :psi_plus | :psi_minus`.
      — also corrected the inherited docstring `:c32` → `:c128` (Nx has no `:c32`).
- [x] Add `ghz_state_vector(num_qubits, type \\ :c64)` as canonical; move the
      full `@doc` (prose + examples + `## See Also → Qx.ghz_state/0`) onto it,
      doctests updated to `ghz_state_vector`. Add
      `@spec ghz_state_vector(pos_integer(), Nx.Type.t()) :: Nx.Tensor.t()`.
      Keep the `when … num_qubits >= 2` guard.
- [x] Convert old `bell_state/2` → thin `@deprecated "Use Qx.StateInit.bell_state_vector/2"`
      + `@doc false` — collapsed to a single
      `def bell_state(which \\ :phi_plus, type \\ :c64), do: bell_state_vector(which, type)`.
      Added a `# Deprecated: …` comment mirroring `math.ex:220-222`.
- [x] Convert old `ghz_state/2` → `@deprecated "Use Qx.StateInit.ghz_state_vector/2"`
      + `@doc false` delegating to `ghz_state_vector`. Preserved the guard.
- [x] `mix test test/qx/state_init_vector_test.exs` — confirmed GREEN (12/12).

## Phase 3 — Cross-reference doc updates (no behaviour change)

- [x] `lib/qx.ex` — `## See Also` for `Qx.bell_state/1`: point at
      `Qx.StateInit.bell_state_vector/2` (was `bell_state/2`).
- [x] `lib/qx.ex` — `## See Also` for `Qx.ghz_state/0`: point at
      `Qx.StateInit.ghz_state_vector/2` (was `ghz_state/2`).
- [x] `lib/qx/patterns.ex` — `bell_state_circuit/1` `## See Also`:
      → `Qx.StateInit.bell_state_vector/2`.
- [x] `lib/qx/patterns.ex` — `ghz_state_circuit/1` `## See Also`:
      → `Qx.StateInit.ghz_state_vector/2`.

## Phase 4 — CHANGELOG (`CHANGELOG.md`, `[Unreleased]`)

- [x] Under `### Added`: `Qx.StateInit.bell_state_vector/2` and
      `ghz_state_vector/2`, the canonically-named state-vector constructors
      (the `_vector` suffix disambiguates from the circuit-returning
      `Qx.bell_state/1` / `Qx.ghz_state/0`).
- [x] Add a `### Deprecated` section: `Qx.StateInit.bell_state/2` and
      `ghz_state/2` are deprecated in favour of the `_vector` names; both
      keep working through 0.8.x and are scheduled for removal in v0.9.

## Verification (mandatory gate)

- [ ] `mix compile --warnings-as-errors` — clean. (Deprecation warnings from
      the existing test callers print but do **not** fail the build — verified.)
- [ ] `mix format --check-formatted` — clean.
- [ ] `mix credo --strict` — 0 issues.
- [ ] `mix test` — full suite green, including the 245 doctests (the moved
      doctests now run under the `_vector` names). Note the expected new
      deprecation-warning lines in output from the unchanged
      `state_init_test.exs` callers.

## Out of scope

- Removing the deprecated names (v0.9, ROADMAP line 94).
- Deciding `Qx.StateInit` public/internal status (ROADMAP v0.8.1 line 29) —
  separate item.
- Editing existing `state_init_test.exs` calls.

## Done = merge-ready

All four phases checked, verification green, `/phx:review` PASS (or findings
triaged). Then squash-merge, tick ROADMAP line 34, push `main`.
