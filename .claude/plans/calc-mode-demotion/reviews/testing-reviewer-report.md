# Test Review: test/qx/calc_mode_internal_test.exs

## Summary

Small, focused test file verifying the calc-mode demotion's non-breaking
guarantee: hidden docs + continued functional correctness for
`Qx.Qubit`/`Qx.Register`. Structure and async usage are fine. The main gap
is that the "still fully functional" tests only cover `new/1` + `h/1|2` +
one probability read each — they don't exercise the rest of the demoted
surface (x/y/z/rx/ry/rz/phase/measure_x/measure_y/show_state/tap_state,
`Qubit.wrap`/`extract_state` private helpers, `Register.from_basis_states`,
etc.), and rely on the untouched `register_test.exs`/`qubit_test.exs` +
doctests to cover that ground. Given those suites are confirmed still green
(244 doctests + 1000 tests, 0 failures) and function bodies are literally
untouched, that reliance is reasonable rather than a gap this PR needs to
close itself.

## Iron Law Violations

None. `async: true` is correct (pure functions, no global state, no Mox).
No Process.sleep, no mocking, no factories in scope.

## Issues Found

### Critical

None.

### Warnings

- **test/qx/calc_mode_internal_test.exs:9,13 — `Code.fetch_docs` pattern
  is fragile against doc_content format changes.** The match
  `{:docs_v1, _, :elixir, _, :hidden, _, _}` pins the 7-tuple shape and
  `:hidden` at position 5, which is correct for today's `ex_doc`/compiler
  contract, but if the Elixir doc format version changes the arity, this
  will fail with a MatchError rather than a clear "docs not hidden"
  assertion failure. Low risk (stdlib-controlled format), but consider
  binding the moduledoc field and asserting `:hidden ==` explicitly for a
  clearer failure message, e.g.:
  `{:docs_v1, _, :elixir, _, moduledoc, _, _} = Code.fetch_docs(Qx.Register); assert moduledoc == :hidden`.
  Cosmetic — not blocking.

- **Coverage gap: only `h/1` (Qubit) and `h/2` (Register) are exercised
  by the new test.** The "non-breaking guarantee" claim in the file's
  comment (line 4-5) is broader than what's asserted — it implies "both
  modules still work," but only one gate on each module is smoke-tested
  here. This is *not* a blocking gap because (a) function bodies are
  provably untouched per the task description, and (b) the full
  `register_test.exs`/`qubit_test.exs` suites plus doctests already cover
  the rest of the API and are confirmed green. But if this file is meant
  to be the durable regression guard for "calc mode still works" going
  forward (as opposed to a one-time demotion-day check), it under-covers
  that promise. Consider a short comment noting that the broader
  guarantee is carried by `register_test.exs`/`qubit_test.exs`, so a
  future reader doesn't assume this file alone protects the guarantee.

### Suggestions

- **test/qx/calc_mode_internal_test.exs:23-24,32-33 — tolerance choice
  (`1.0e-6`) is correct and at the Iron Law #8 floor**, appropriate for
  `:c64` (float32, ε≈1.2e-7) states from `Register.get_probabilities`/
  `Qubit.measure_probabilities`. No change needed — flagging only to
  confirm it was checked, since tighter tolerances (e.g. `1.0e-9`) would
  have been a violation.
- Consider one `describe` block per module ("Qx.Register" / "Qx.Qubit")
  instead of grouping by concern ("hidden from documentation" /
  "still fully functional") — either grouping is defensible; current
  choice mirrors the PR's two guarantees (hidden + functional), which is
  arguably clearer for this specific test's purpose. No action required.

## Other Observations (non-blocking)

- `lib/qx.ex` doctest rewrites for `draw_bloch`/`draw_state` from
  Qubit/Register pipelines to circuit-mode pipelines were not reviewed in
  depth here (out of this file's scope per the task), but are consistent
  with the stated demotion direction — public-surface doctests should not
  exercise internal (`@moduledoc false`) modules going forward.
- `lib/qx/qubit.ex` and `lib/qx/register.ex` still carry extensive
  `@doc` blocks with runnable `iex>` doctests despite `@moduledoc false`.
  Function-level `@doc`/doctests on a hidden-moduledoc module are still
  compiled and run (doctests aren't gated by moduledoc visibility), which
  is why the 244 doctests count is unaffected — this is expected and
  correct, not a defect, but worth confirming ExDoc doesn't also render
  per-function `@doc` publicly. Not a testing-review concern; flagging
  for the elixir-reviewer/iron-law-judge lane if not already covered.
