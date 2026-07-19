# API cleanup — Phase A: `@doc false` sweep + docstring fixes

**Branch:** `chore/api-cleanup-phase-a`
**Source:** Elevation of Phase A from
`.claude/plans/public-api-audit/plan.md`. Covers 14 of the 23 audit
findings: A1–A7, B1 (docstring only), B2 (docstring only), B7, C1
(deprecate only), C2 (docstring only), C3, D1 (docstring), D3.
**Target version:** Ships in unreleased `0.8.0`. **Non-breaking** —
every change is either (a) `@doc false` (hides from ExDoc, function
stays callable) or (b) doc-string edit or (c) a bug fix that
*tightens* a typed-error contract (D3). No public function is
removed, renamed, or has its signature changed.

## Context

The public-API audit (`.claude/plans/public-api-audit/plan.md`)
found 23 issues. Phase A is the safe, immediately-shippable subset:
no rename, no removal, no signature change. The aim is to make
ExDoc honest — the modules labelled "Low-Level" in `mix.exs`
`groups_for_modules` should not have ExDoc-indexed individual
functions, and the documented-as-public-but-internal-only helpers
should not appear in IDE auto-complete for user-facing modules.

## Decisions resolved (from audit)

1. **`@doc false` over `Qx.Internal.*` namespace migration.** The
   namespace move is a v1.0 (breaking) decision. `@doc false`
   achieves the immediate goal — making ExDoc honest — without
   breaking any caller. Listed as "Alt" on each finding row in the
   audit; chosen path here is the non-breaking one.
2. **Tutorial impact verified.** Grepped
   `qxportal/priv/static/tutorials/*.livemd` for usage of every
   to-be-hidden function. **Zero hits.** No external code path
   that we control depends on these functions being ExDoc-indexed.
3. **Bug fix coupled in: D3** (`validate_num_qubits!` missing from
   `QuantumCircuit.new/1,2`) belongs in Phase A because it tightens
   an Iron Law #7 hole that the audit surfaced. Pure additive
   raise-on-invalid path.

## Scope summary

| Finding | File | Change | Lines |
|---|---|---|---|
| A1 | `lib/qx/quantum_circuit.ex` | `@doc false` on `add_gate/4`, `add_two_qubit_gate/5`, `add_three_qubit_gate/6`, `add_measurement/3` | ~4 |
| A2 | `lib/qx/validation.ex` | `@doc false` on the 10 `validate_*!` contracts. Keep `valid_qubit?/2` and `valid_register?/2` public (user-facing predicates). | ~10 |
| A3 | `lib/qx/gates.ex` | `@doc false` on all 20 matrix factories | ~20 |
| A4 | `lib/qx/calc.ex`, `lib/qx/calc_fast.ex` | `@doc false` on `apply_single_qubit_gate/4`, `apply_cnot/4`, `apply_toffoli/5`, `apply_cswap/5` (and the `CalcFast` arity-2 + arity-4) | ~6 |
| A5 | `lib/qx/math.ex` | `@doc false` on `complex_to_tensor/1`, `tensor_to_complex/1`, `complex_matrix/1`. Keep `complex/2`, `identity/1`, `basis_state/2`, `unitary?/1`, `probabilities/1` public. | ~3 |
| A6 | `lib/qx/format.ex` | `@doc false` on `complex/2`, `basis_state/2`, `dirac_notation/2`, `state_label/2` (the entire public surface — module stays compiled but no longer indexed). | ~4 |
| A7 | `lib/qx/result_builder.ex` | `@doc false` on `from_counts/3` | ~1 |
| B1 docstring | `lib/qx.ex` `bell_state/1`, `lib/qx/state_init.ex` `bell_state/2` | Cross-link `@doc` between the two so the reader sees the *circuit* vs *state vector* distinction up front. | ~6 |
| B2 docstring | `lib/qx.ex` `ghz_state/0`, `lib/qx/state_init.ex` `ghz_state/2` | Same cross-link treatment as B1. | ~6 |
| B7 | `lib/qx/qubit.ex` `draw_bloch/2` | Convert `def`-wrapper to `defdelegate draw_bloch(qubit, options \\ []), to: Qx.Draw, as: :bloch_sphere`. | ~3 |
| C1 deprecate | `lib/qx/math.ex` `basis_state/2` | Add `@deprecated "Use Qx.StateInit.basis_state/3"` + `@doc false`. (Function still callable; v1.0 will remove it per Phase C.) | ~2 |
| C2 docstring | `lib/qx/math.ex` `identity/1`, `lib/qx/gates.ex` `identity/0` | Cross-link `@doc` ("see also `Qx.Gates.identity/0` — the 2×2 c64 single-gate variant"). | ~4 |
| C3 | `lib/qx/format.ex` `basis_state/2` | Covered by A6 — already `@doc false`. No extra change. | — |
| D1 docstring | `lib/qx/errors.ex` `Qx.Error` | Rewrite `@moduledoc` to reflect that nothing currently raises this; it's a forward-compat placeholder, **not** a base class users can rescue to catch all qx exceptions. | ~6 |
| D3 bug fix | `lib/qx/quantum_circuit.ex` `new/1,2` | Add `Qx.Validation.validate_num_qubits!(num_qubits)` call before the guard. Closes the hole where 25-qubit circuits succeed silently from the `QuantumCircuit` path (the documented 20-qubit cap is then actually enforced). | ~2 |

**Net change budget:** ~75 lines, all in `lib/`. No new tests
required for `@doc false` (the functions are still callable; every
existing test still passes). D3 needs one new test (a 25-qubit
`QuantumCircuit.new/1` call now raises `Qx.QubitCountError`).

## Phases

### Phase 1 — `@doc false` sweep (A1–A7)

- [x] `lib/qx/quantum_circuit.ex` — tag `add_gate/4`,
      `add_two_qubit_gate/5`, `add_three_qubit_gate/6`,
      `add_measurement/3` with `@doc false`.
- [x] `lib/qx/validation.ex` — tag the 10 `validate_*!` functions
      with `@doc false`. Keep `valid_qubit?/2` and
      `valid_register?/2` public.
- [x] `lib/qx/gates.ex` — tag all 20 matrix factories with
      `@doc false`.
- [x] `lib/qx/calc.ex` and `lib/qx/calc_fast.ex` — tag all public
      functions with `@doc false`.
- [x] `lib/qx/math.ex` — tag the three internal converters with
      `@doc false`.
- [x] `lib/qx/format.ex` — tag all 4 public functions with
      `@doc false`.
- [x] `lib/qx/result_builder.ex` — tag `from_counts/3` with
      `@doc false`.
- [x] `mix compile --warnings-as-errors && mix test` — should
      still be **264 doctests + 818 tests / 0 failures** (the
      `@doc false` tag removes doctest extraction from those
      docstrings; if any of them had doctests, those vanish from
      the test count. Audit-time grep showed only a small number
      did — adjust expectations accordingly).

### Phase 2 — Docstring fixes (B1, B2, C2, D1)

- [x] `lib/qx.ex` `bell_state/1` — add a "See also" block:
      *"For a state-vector form (not a circuit recipe), see
      `Qx.StateInit.bell_state/2`."*
- [x] `lib/qx/state_init.ex` `bell_state/2` — add the mirror block:
      *"For a circuit recipe (returns `%Qx.QuantumCircuit{}`), see
      `Qx.bell_state/1`."*
- [x] Same treatment on `ghz_state/0` ↔ `ghz_state/2`.
- [x] `lib/qx/math.ex` `identity/1` — add: *"For the 2×2 c64
      single-qubit identity gate matrix, see `Qx.Gates.identity/0`."*
- [x] `lib/qx/gates.ex` `identity/0` — add the mirror block.
      *(Even though `Qx.Gates.identity/0` is being hidden via A3,
      the cross-link is still useful for the user reading the
      `Qx.Math.identity/1` page and curious about gate-shaped
      identities.)*
- [x] `lib/qx/errors.ex` `Qx.Error` `@moduledoc` — rewrite. Honest
      text: *"Placeholder base exception. **Not currently raised by
      any qx function.** Reserved for future use. Users wanting to
      rescue any qx-raised error must list each typed exception
      explicitly (`rescue [Qx.QubitIndexError, Qx.GateError, ...]`);
      Elixir exceptions do not inherit, so `rescue Qx.Error` catches
      nothing today."*

### Phase 3 — `defdelegate` cleanup (B7)

- [x] `lib/qx/qubit.ex` `draw_bloch/2` — replace the `def`-wrapper
      body with `defdelegate draw_bloch(qubit, options \\ []),
      to: Qx.Draw, as: :bloch_sphere`. Keep the `@doc` intact.

### Phase 4 — Deprecation tag (C1)

- [x] `lib/qx/math.ex` `basis_state/2` — add
      `@deprecated "Use Qx.StateInit.basis_state/3"` directly above
      the `def`. Also tag with `@doc false`.
- [x] Audit-time grep confirms `Qx.Math.basis_state/2` is **only
      called from within `lib/qx/math.ex` itself and from its own
      doctest**. The deprecation will not noise any caller.

### Phase 5 — Bug fix (D3)

- [x] `lib/qx/quantum_circuit.ex` `new/1` and `new/2` — call
      `Qx.Validation.validate_num_qubits!(num_qubits)` **before**
      the existing `when num_qubits > 0` guard. This raises
      `Qx.QubitCountError` for the 21..∞ range instead of
      silently succeeding.
- [x] Add a test in `test/qx/quantum_circuit_typed_errors_test.exs`
      (or its closest existing equivalent) asserting:
      - `QuantumCircuit.new(25)` raises `Qx.QubitCountError` with
        the documented `{actual, min, max} = {25, 1, 20}` shape.
      - `QuantumCircuit.new(25, 25)` raises the same.
      - `QuantumCircuit.new(20)` still succeeds (boundary).
      - `QuantumCircuit.new(0)` still raises (the existing path —
        confirm the typed error wins over the existing guard).

### Phase 6 — Verification + ExDoc diff

- [x] `mix compile --warnings-as-errors` — clean.
- [x] `mix format --check-formatted` — clean.
- [x] `mix credo --strict` — 0 issues.
- [x] `mix test` — passes. **Expect doctest count to drop** from
      264 by the number of doctests inside `@doc false`-tagged
      functions. Confirm the drop is *exactly* the count of
      affected doctests (audit-time grep needed); a larger drop
      means a docstring was inadvertently hidden on a still-public
      function.
- [x] `mix docs` — generate. Diff sidebar contents vs pre-plan
      baseline. **Expect:** `Qx.Validation.validate_*!`,
      `Qx.Gates.*` functions, `Qx.Calc.*`, `Qx.CalcFast.*`,
      `Qx.Format.*`, `Qx.ResultBuilder.from_counts`,
      `Qx.QuantumCircuit.add_*` no longer appear under their
      respective module pages. The *modules themselves* still
      appear (they have `@moduledoc`).
- [x] Warning-set diff: same set as pre-plan baseline, **plus** one
      new `@deprecated` warning for `Qx.Math.basis_state/2` if
      anyone still calls it within the suite (audit said no).

## Verification gate (qx CLAUDE.md mandatory)

```
mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict
mix test
```

## Notes / Iron Law compliance

- **Iron Law #1, #2** (atom interning, processes) — N/A.
- **Iron Law #3, #4, #5, #8** (Nx kernels) — N/A.
- **Iron Law #6** (public API surface) — `@doc false` is the
  Elixir-idiomatic *non-breaking* way to make a function
  not-recommended-for-external-use. The CHANGELOG entry will note
  the change so users who *are* relying on these internals get a
  signal.
- **Iron Law #7** (typed errors) — Phase 5 (D3) tightens a hole; it
  *adds* a typed-error path, doesn't remove one. Pure improvement.

## CHANGELOG entry (planned)

Under `## [0.8.0]` `### Changed` (creating that subsection if it
doesn't exist):

> **Internal-only functions hidden from documentation.** Functions
> in `Qx.Gates`, `Qx.Calc`, `Qx.CalcFast`, `Qx.Format`,
> `Qx.Validation` (the `validate_*!` family), `Qx.ResultBuilder`,
> `Qx.QuantumCircuit` (the `add_*` family), and three converters in
> `Qx.Math` have been tagged `@doc false` — they no longer appear
> in ExDoc and IDE auto-complete, but **remain callable** for
> advanced users adding custom gates or inspecting internals. No
> existing call site breaks. The matching modules' `@moduledoc`
> remains, so users can still navigate to "low-level operations" if
> they need them.

Under `### Deprecated`:

> **`Qx.Math.basis_state/2` is deprecated** — use
> `Qx.StateInit.basis_state/3` instead. The two functions returned
> different types (`Qx.Math` was f32, `Qx.StateInit` is c64), and
> `Qx.StateInit.basis_state/3` is the canonical form. The old
> function is hidden from ExDoc and emits a compile-time
> deprecation warning; it will be removed in v1.0.

Under `### Fixed`:

> **`Qx.QuantumCircuit.new/1,2` now enforces the documented
> 20-qubit cap.** Previously, calling `new(25)` silently created
> an over-cap circuit; the validator that should have raised
> `Qx.QubitCountError` was only wired into the `Qx.Register`
> creation path. Now both paths raise consistently. Closes an
> Iron Law #7 hole surfaced by `.claude/plans/public-api-audit/plan.md`.

## Risks

1. **Doctest count drop must be *exactly* the affected count.** If
   `mix test` reports a larger drop than expected, a `@doc false`
   tag landed on a function that *did* have user-facing
   documentation. Mitigation: before tagging each function,
   `grep '@doc' …` against its docstring to confirm presence/absence
   of doctest, and tally an expected delta.
2. **`@deprecated` warnings inside the qx test suite count as
   warnings.** If `Qx.Math.basis_state/2` is still called from
   *test* code, the deprecation warning will fire during
   `mix test` and `mix compile --warnings-as-errors` will
   **error out** because of the `--warnings-as-errors` flag.
   Audit-time grep said no internal callers, but verify against
   `test/` too. If a test caller exists, update it to
   `Qx.StateInit.basis_state/3` in the same commit.
3. **`Qx.Format` going `@doc false` on all 4 functions still
   leaves the *module* in ExDoc** (it has a `@moduledoc`). If the
   intent is to hide the whole module, also tag
   `@moduledoc false`. Defer this decision: hiding the module
   entirely makes its functions un-linkable from other docstrings,
   which could break cross-references in `Qx.Draw` docstrings.

## Stop conditions

Per qx CLAUDE.md: skill stops at the merge gate after `/phx:review`
PASS. Doc-only + bug-fix change of ~75 lines + ~30 lines of new
tests; a single `elixir-reviewer` pass is sufficient (no
testing-reviewer needed beyond the D3 test, no security-analyzer).
