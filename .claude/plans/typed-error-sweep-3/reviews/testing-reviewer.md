# Test Review: test/qx/typed_error_sweep_test.exs

## Summary
25 tests, `async: true`, pure-function/no-global-state — async is safe. Coverage
maps cleanly onto every fallback clause added in `Qx.Validation`, `Qx.Patterns`,
`Qx.Operations.c_if`, `Qx.StateInit.basis_state`, `Qx.SimulationResult.filter_by_probability`,
`Qx.Math.normalize`, and the rx/ry/rz/phase build-time path. No Mox/Sandbox
concerns apply (pure library). Traced each test against the corresponding
fallback clause in `lib/qx/{validation,errors,patterns,operations,state_init,
simulation_result,math}.ex` — all cited sites are exercised by exactly one test
each, matching the plan's probe table.

## Iron Law Violations
None. No mocking, no DB, no Process.sleep, no global state mutated.

## Issues Found

### Warnings
- [ ] `SimulationResult.filter_by_probability` threshold=1 test (line 101-103):
  asserts `== %{}` with comment "(additive)". Because `min_count = threshold * shots
  = 100` and no bucket count reaches 100 (52/48), this only proves the integer
  guard doesn't raise — it does NOT exercise the arithmetic path meaningfully
  (a broken `min_count` calculation could still coincidentally return `%{}`).
  Consider adding a mid-range integer-adjacent case, e.g. asserting a specific
  non-empty filtered set at a fractional threshold in the same describe block,
  to actually pin down the widened-guard arithmetic rather than just "did not raise."
- [ ] `Math.normalize` c64 survivor test (line 132-135) only asserts
  `Nx.type(...) == {:c, 64}` — it does not assert the actual normalized
  amplitude values. This does not fully prove "byte-identical" survivor
  behavior claimed in the file header comment; a numeric regression in the
  renorm path that preserves dtype would pass silently. The f32 survivor test
  (126-130) is stronger since it checks values via `assert_in_delta`.
- [ ] Message-regex coupling (`~r/must be an integer/`, lines 13, 31, 35) ties
  tests to exact wording shared by `Qx.QubitCountError`/`Qx.QubitIndexError`
  messages in `lib/qx/errors.ex`. Low risk since most other tests in the file
  correctly prefer type/field assertions (`e.option`, `e.reason`) over message
  matching, but these three are inconsistent with that stronger pattern used
  elsewhere in the same file and would break on a harmless message wording tweak.

### Suggestions
- [ ] Several exception-type-only assertions (`create_circuit` negative bits,
  `cx` non-integer qubit, `ghz_state_circuit(:x)`, `c_if` non-integer bit) could
  additionally assert the carried field (e.g. `e.count`, `e.qubit`,
  `e.bit == "0"`) for symmetry with the `basis_state`/`filter_by_probability`/
  `bell_state_circuit` tests, which already do this well.
- [ ] No test covers `Operations.c_if` with a negative/out-of-range classical_bit
  falling through the *typed-non-integer* fallback path's sibling clauses —
  fine per scope (those are pre-existing, not new fallbacks), but worth a
  one-line comment noting that distinction to avoid future confusion about why
  it's absent.

## Coverage completeness
All items in the requested checklist are present and matched to a distinct
fallback clause: create_circuit non-integer/negative bits, h/cx non-integer
qubit, bell `:bogus`, ghz `1`/`:x` (both `QubitCountError` fallback arms),
c_if non-integer bit, basis_state's 4 reason variants (all of
`:not_an_integer`/`:negative`/`:out_of_range`/`:invalid_dimension` covered),
filter_by_probability int 0/1 + 2/"x", normalize zero-raise + f32/c64
survivors, and rx/ry/rz/phase build-time via a compile-time `for` loop (valid
Elixir pattern — string interpolates the compile-time-bound atom per
iteration, not a runtime unquote issue).
