# Iron Law Violations Report

## Summary

- Files scanned: 5 (lib/qx/state_init.ex, lib/qx.ex, lib/qx/patterns.ex, CHANGELOG.md,
  test/qx/state_init_vector_test.exs)
- Iron Laws checked: 8 of 22 (Qx-tailored subset; LiveView / Ecto / Oban / Phoenix laws
  N/A for this pure-Elixir library diff)
- Violations found: 2 (0 critical, 0 high, 2 medium)

---

## Medium Violations

### [#7] Public functions raise typed Qx.*Error — new surface, FunctionClauseError on bad `which`

- **File**: `lib/qx/state_init.ex:274-310`
- **Code**: `def bell_state_vector(:phi_plus, type) … def bell_state_vector(:psi_minus, type)`
  (four clauses, no catch-all)
- **Confidence**: REVIEW
- **Fix**: The `@type bell_state_which` enum has four members; callers using the typespec
  won't hit this. However, a call such as `bell_state_vector(:invalid)` will surface a raw
  `FunctionClauseError` rather than a typed `Qx.*Error`. The same gap existed in the
  pre-existing `bell_state/2`, so this is inherited rather than newly introduced. The
  mitigation is to add a catch-all clause that raises `Qx.BellStateError` (or
  `Qx.ParameterError` with context), consistent with Iron Law #7 and the typed-error sweep
  already documented in the CHANGELOG. This is low urgency — the typespec guards callers —
  but should be addressed before v0.9 when the deprecated shims are removed and
  `bell_state_vector` becomes the only callable name.

### [#8] Tolerance feasibility — hand-rolled norm check at 1.0e-6 in test

- **File**: `test/qx/state_init_vector_test.exs:76`
- **Code**: `assert approx_equal?(total, 1.0, 1.0e-6)` where `total` is
  `StateInit.ghz_state_vector(5) |> Qx.Math.probabilities() |> Nx.sum() |> Nx.to_number()`
- **Confidence**: REVIEW
- **Fix**: `1.0e-6` is not sub-epsilon (float32 ε ≈ 1.2e-7), so the assertion is feasible for
  this specific case — the 5-qubit GHZ state has only two non-zero probabilities (each
  exactly 0.5 in float32), so their sum rounds to 1.0 without accumulation error. The concern
  is stylistic: the law says to use `Qx.Math.normalize/1` + `Qx.Validation.validate_normalized!/2`
  rather than hand-rolling a norm assertion. For a unit test the practical risk is very low;
  flag for alignment with the law if a norm-check helper is exposed for test use. If the qubit
  count were larger (many non-zero amplitudes accumulating float32 rounding) the 1.0e-6
  tolerance could become flaky. Document this bound explicitly if the test is kept as-is.

---

## Explicit Verdicts on Prompt-Specific Questions

**Law 5 — host-side loop over 2^n amplitudes in ghz_state_vector:**
PRE-EXISTING. The `for i <- 0..(dimension-1)` comprehension in `ghz_state_vector/2`
(lines 360–366) is moved verbatim from the old `ghz_state/2`. It is not newly introduced.
For the intended use cases (state-prep helpers, small qubit counts), this is acceptable.
`bell_state_vector` constructs its 4-element list as a literal (no loop at all). Mark
pre-existing; no action required in this change.

**Law 6 — breaking public-API change verdict:**
CLEAN. The change is correctly additive + deprecation:
- `bell_state_vector/2` and `ghz_state_vector/2` are new additions (not renames).
- `bell_state/2` and `ghz_state/2` (the old names) still work — they delegate to the
  new functions, verified in the code and the delegation-equivalence test suite.
- CHANGELOG has both `### Added` (new functions) and `### Deprecated` (old names) entries
  under `[Unreleased]`.
- No major-version bump is required (old API unchanged; callers will see `@deprecated`
  warnings, not breakage).

**Law 7 — no new raw error paths:**
PARTIAL. Deprecated shims (`bell_state/2`, `ghz_state/2`) add no new guards — they
delegate verbatim. The new `_vector` functions inherit the pre-existing `FunctionClauseError`
gap for unknown `which` atoms (see Medium violation above). No net regression.

**Law 8 — tolerances feasible at float width:**
CLEAN for the `0.01` default used throughout most tests. The single `1.0e-6` usage is
at the boundary but feasible for the specific case tested. See Medium violation above for
the nuance.

Checked 8 of 22 Iron Laws: 2 medium findings, 0 critical, 0 high.
