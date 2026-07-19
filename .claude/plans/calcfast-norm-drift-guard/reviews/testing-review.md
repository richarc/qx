# Test Review: test/qx/simulation_renormalization_test.exs

## Summary

Nine tests covering the renormalization feature. `async: true` is correct (pure BinaryBackend, no
global state). All Iron Laws satisfied for a pure-library ExUnit suite. The suite is sound overall
with three issues worth fixing and one structural fragility to document.

---

## Iron Law Violations

None.

---

## Issues Found

### Critical

None.

---

### Warnings

**W1 — P4-T1 "assert_raise as relative proof" is fragile under backend / compiler change**
File: `simulation_renormalization_test.exs`, lines 43–52.

The test asserts that `renormalize: false` on a 100-gate `drift_circuit` raises
`Qx.StateNormalizationError`. This works because `@assert_norm` is compiled `true` in `:test`
and the BinaryBackend produces deterministic float32 drift of ~1.07e-6 > 1.0e-6. The guard fires
at gate 61 or 62 (wherever the cumulative drift first crosses the threshold) — not at gate 100.
That is fine in isolation, but the comment at line 44–48 describes it as proving "renorm strictly
reduces drift below tolerance for a circuit that otherwise **breaches** it". That claim is
correct today, but it is one implementation detail away from silently becoming a vacuous
tautology:

- If `@norm_tolerance` is tightened (e.g. to `5.0e-7`), the renorm path itself may trip the
  guard intermittently on EXLA, falsely failing the P4-T1 success case.
- If `@norm_tolerance` is loosened to `2.0e-6`, the no-renorm path would no longer raise, and
  this test would fail without any test-coverage regression being apparent.

Fix: pin the relative guarantee explicitly instead of relying on the guard as a proxy:

```elixir
test "renorm reduces drift by at least 5x versus no-renorm (relative guarantee)" do
  # Run without renorm to confirm drift is measurable (bypassing the guard)
  # by disabling assert_norm at the call site is not possible directly, but
  # we can measure drift on a shorter circuit that stays below the guard threshold.
  short = drift_circuit(60)  # ~7e-7, below guard threshold
  result_off  = Simulation.run(short, renormalize: false, shots: 1)
  result_renorm = Simulation.run(short, renormalize: 10, shots: 1)
  assert dev(result_renorm) < dev(result_off) / 5
end
```

The existing `assert_raise` test for the 100-gate case can be kept as-is but should be
re-scoped: it is testing that the *guard fires* on a known-bad circuit, not that renorm reduces
drift. Separating the two concerns removes the ambiguity.

---

**W2 — P4-T5 asserts `result.state` after a multi-shot conditional run; that state is
non-representative (last shot only)**
File: `simulation_renormalization_test.exs`, lines 101–116.

`run_with_conditionals/3` (simulation.ex, lines 137–164) sets `final_state = List.last(results)`
— the last shot's post-collapse state. With `shots: 16` and a `measure(0, 0)` + `c_if` branch,
the final state is a collapsed single-qubit-measured state, not a full superposition. Calling
`dev/1` on a collapsed state almost always returns a value well under 1.0e-6 (collapsed states
are trivially normalized by construction in `collapse_to_measurement/4`). The assertion
`dev(result.state) <= 1.0e-6` therefore passes vacuously — it is not testing that renorm
*reduces* drift in the `execute_single_shot/2` path, it is testing that a post-collapse state
is normalized, which is always true regardless of the `:renormalize` option.

To genuinely exercise renorm in the conditional path, the assertion should target the
intermediate gate-application states via a side effect (e.g. a custom assert_norm hook), or
alternatively: build a conditional circuit where no measurement follows the drift-inducing gates
and use `renormalize: false` to confirm the guard fires, then `renormalize: N` to confirm it
does not. As written the test gives false confidence.

Fix options (pick one):
1. Drop `shots: 16` to `shots: 1`, remove the `c_if`, and assert the final state dev — this
   converts it into a straightforward non-conditional test already covered by P4-T3, so it may
   not add value.
2. Keep the conditional structure but assert via the guard: run the same circuit without renorm
   and assert the guard fires (analogous to P4-T1), confirming the `execute_single_shot/2`
   gate loop *does* accumulate drift. Then assert with renorm it does not. This requires enough
   gates before the first measure to accumulate > 1.0e-6 drift before collapse.

---

### Suggestions

**S1 — `validate_renormalize!` raise doctests do not match on message pattern**
File: `lib/qx/validation.ex`, lines 323–326.

The raise doctests use the full expected message:

```elixir
** (Qx.OptionError) Invalid value for option :renormalize: -1. Expected false, true, or a positive integer.
```

This is correct ExDoc/doctest syntax for raise assertions. However, ExUnit doctests match the
message as a substring prefix (everything after the exception module name must be an exact
prefix match of the actual message). If `Qx.OptionError`'s `message/1` implementation formats
the value differently for certain inputs (e.g. adds inspect wrapping, changes punctuation), the
doctest will silently pass with an incorrect message. Confirm that `Qx.OptionError`'s
`exception/1` produces exactly the string shown, including the trailing period and spacing. This
is a verification note, not a defect — but worth a quick `mix test --only doctest` cross-check.

**S2 — `drift_circuit/1` qubit indices for `cx` are always `rem(i, 3)` and `rem(i+1, 3)`,
which can be equal when `i mod 3 == 2` and `(i+1) mod 3 == 0`**
File: `simulation_renormalization_test.exs`, lines 25–35.

When `i = 3, 6, 9, …` (`rem(i, 3) == 0`) the `cx(acc, 0, 0)` case is dead (the `h` branch is
taken). When `rem(i, 3) == 2`, `cx(acc, 2, 0)` — control=2, target=0 — which is valid (they
differ). So there is no same-qubit-cx bug. This is a false alarm; the note is included only
because the pattern looks suspicious on first reading and the comment at line 24 is the right
place to add a one-line note confirming it was checked, to prevent future maintainers from
re-investigating.

**S3 — `dev/1` helper is the right metric, but should guard against empty/wrong-shaped state**
File: `simulation_renormalization_test.exs`, line 18.

Minor: `dev/1` calls `Math.probabilities` then `Nx.sum`. If `result.state` is ever the wrong
shape (e.g. simulation path change returns a matrix), `Nx.sum` returns a scalar sum over all
elements rather than raising. This would make a shape regression invisible. Not a problem for
the current codebase, but a `Nx.shape(state)` assertion before `dev/1` in each test that uses
it would catch future regressions immediately.
