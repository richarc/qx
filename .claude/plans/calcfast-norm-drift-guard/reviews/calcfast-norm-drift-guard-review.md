# Merge-Gate Review — feat/calcfast-norm-drift-guard (qx-53v)

Date: 2026-05-16 · Scope: diff vs `main` · Agents: elixir-reviewer,
testing-reviewer, iron-law-judge, requirements-verifier (all 4 completed)

## Verdict: **REQUIRES CHANGES**

1 BLOCKER + 4 WARNINGS + 3 SUGGESTIONS. Requirements 11/11 MET, Iron
Laws PASS — but a public-API docs defect (BLOCKER) and a vacuous
conditional-path test + an undocumented renorm-cadence gap in `c_if`
blocks should be resolved before this enters `main` (the merge gate is
the quality boundary that replaces PR review).

---

## Requirements Coverage (Plan calcfast-norm-drift-guard / qx-53v)

**11 MET · 0 PARTIAL · 0 UNMET.** All ACs (incl. amended AC #3) and
all 7 design constraints verified against code + tests. Caveat: the
tests *backing* AC #3 (P4-T1) and DC6/conditional-path (P4-T5) are
weak (see W2/W3) — the *implementation* meets the requirements; the
*proof* is thin. CalcFast confirmed absent from the diff; no new hex
dep; no version bump; CHANGELOG `[Unreleased]` present and accurate.

## Iron Laws

**PASS — 0 violations.** Laws #1, #2, Nx#3, Nx#4, #6, #7 COMPLIANT.
Nx#5 (host sync `Nx.to_number` in `assert_norm/1`) = EXCEPTION-
JUSTIFIED: compile-time gated (`@assert_norm` false in prod/dev,
true in test), documented inline, never executed in prod.

---

## BLOCKER

### B1 — `mix.exs:91` `Qx.OptionError` missing from "Error Handling" ExDoc group
All 12 sibling `Qx.*Error` modules are listed in `groups_for_modules`'s
`"Error Handling"` group; the new public `Qx.OptionError` (raised at
the `run/2` API boundary, referenced in its `@doc`) is not. ExDoc will
not generate a navigable page for it — public API discoverability
defect. Fix: add `Qx.OptionError,` to the group (alphabetically after
`Qx.Error`). One line.

---

## WARNINGS

### W1 — `process_conditional/6` (simulation.ex): `c_if` sub-gates bypass the `{:every, n}` counter
`execute_single_shot/2` applies `maybe_gate_renorm(renorm, idx)` per
*timeline item*, but a `{:conditional, …}` item delegates to
`process_conditional/6`, which runs sub-instructions through a bare
`Enum.reduce` with no renorm and invisible to the outer `idx`. With
`renormalize: N`, gates inside a `c_if` block get no per-gate renorm
and the effective interval can exceed `N` by the block's gate count.
The documented "every N gates" semantics is violated inside
conditional blocks. Not a wrong-result bug (collapse renormalizes the
measurement path; blocks are usually small) but an undocumented
cadence gap. Decision needed: fix (thread/continue the counter into
`process_conditional`) or document the limitation in `run/2` `@doc`.

### W2 — P4-T5 conditional test is vacuous (most actionable)
`simulation_renormalization_test.exs` P4-T5 asserts
`dev(result.state) <= 1.0e-6`, but `run_with_conditionals/3` sets
`result.state = List.last(results)` — the last shot's *post-collapse*
state, which is trivially normalized by `collapse_to_measurement/4`
regardless of `:renormalize`. The assertion passes vacuously: it
confirms the `c_if` path executes (forces `execute_single_shot/2`) but
proves nothing about renorm there — exactly the DC6 coverage it is
meant to provide. Fix: assert via the guard (no-renorm variant with
enough pre-measure drift → `assert_raise`; renorm variant → passes),
analogous to P4-T1; this also exercises W1.

### W3 — P4-T1 proves amended AC #3 only indirectly (via the guard)
P4-T1 establishes the relative guarantee by `assert_raise
Qx.StateNormalizationError` on the no-renorm 100-gate circuit.
Deterministic today (no randomness on BinaryBackend), but it conflates
"guard fires on a known-bad circuit" with "renorm reduces drift" — and
silently breaks if `@norm_tolerance` shifts (tighten → renorm path may
trip; loosen → no-renorm no longer raises). Add a *direct* numeric
comparison on a sub-threshold (~60-gate) circuit where both paths run
without tripping the guard: `assert dev(renorm) < dev(off)`. Keep the
`assert_raise` test, re-scoped as a guard-behaviour test.

### W4 — `validation.ex` `@spec validate_renormalize!/1` is semantically wrong
`@spec validate_renormalize!(false | true | pos_integer()) :: …` — but
the function's *purpose* is to validate arbitrary input and raise
`Qx.OptionError` on bad values; its own catch-all clause and its
caller (`resolve_renormalize/1` passes raw `Keyword.get/3` output,
typed `term()`) contradict the narrow input type. Should be
`@spec validate_renormalize!(term()) :: false | true | pos_integer()`.

---

## SUGGESTIONS

- **S1** `simulation.ex` `assert_norm/1`: pin the discarded result —
  `if @assert_norm, do: :ok = Validation.validate_normalized!(...)` —
  makes the side-effect/return split explicit. (Demoted from a
  WARNING: speculative Dialyzer; dialyzer is not in the verify gate;
  credo --strict is clean.)
- **S2** `resolve_renormalize/1`: replace the 3-clause `case` with
  private `to_renorm/1` function heads (idiomatic; style only).
- **S3** test `dev/1`: add an `Nx.shape(state)` assertion so a future
  shape regression can't make the metric silently lenient.

## Dropped as noise (anti-filter)
- testing S1 (doctest exact-match): already verified — `mix test
  --only doctest` = 234 doctests, 0 failures.
- testing S2 (`drift_circuit` cx indices): self-confirmed false alarm.
- elixir-reviewer pre-existing one-liners (`apply_instruction/3`,
  `valid_register?/2`, raw `ArgumentError` in `validate_*`): out of
  diff scope; noted, not actioned here.

## Recommended fix order
1. B1 (1 line, mix.exs).
2. W2 + W1 together (a real P4-T5 also surfaces the `c_if` cadence
   gap — decide fix-vs-document for W1 while fixing W2).
3. W4 (1 line spec).
4. W3 (add the direct sub-threshold comparison test).
5. S1–S3 optional.
