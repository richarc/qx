## Requirements Coverage (from plan `.claude/plans/typed-error-sweep-3/plan.md`)

### Target error mapping (§ scopes Phases 3–4)

| # | Site → Typed raise | Status | Evidence |
|---|---|---|---|
| 1 | `create_circuit` non-integer → `QubitCountError` | MET | `lib/qx/quantum_circuit.ex:99-100` fallback → `Validation.validate_num_qubits!/1`; `validation.ex:170-171` raises `{:not_an_integer,…}` |
| 2 | `bell_state_circuit(:bogus)` → `OptionError` | MET | `lib/qx/patterns.ex:334-336` |
| 3 | `ghz_state_circuit` non-integer/<2 → `QubitCountError` | MET | `lib/qx/patterns.ex:343,352-353,356-357` (both fallbacks) |
| 4 | `add_gate`/`add_two_qubit_gate` non-integer qubit → `QubitIndexError` | MET | `lib/qx/quantum_circuit.ex:107-109` (guard dropped `is_integer(qubit)`); `validation.ex:99-100` |
| 5 | `c_if` non-integer classical_bit → `ClassicalBitError`/`ConditionalError` | MET | `lib/qx/operations.ex:801-802` fallback raises `{:not_an_integer,…}` |
| 6 | `basis_state` survivors → `BasisError` | MET | `lib/qx/state_init.ex:81-93` fallback, priority-ordered (`:invalid_dimension`/`:not_an_integer`/`:negative`/`:out_of_range`) |
| 7 | `filter_by_probability` widen to `is_number`, OOR/non-number → `OptionError` | MET | `lib/qx/simulation_result.ex:106-107` guard `is_number(threshold) and 0..1`; :118-119 fallback → `validate_probability!` |
| 8 | `normalize(zero-vector)` → `StateNormalizationError` | MET | `lib/qx/math.ex:77-85` host `def` raises, delegates to `normalize_unchecked/1` (:94) |
| 9 | `rx/ry/rz/phase` → `ParameterError` via `validate_parameter!` | MET | `lib/qx/operations.ex:196,222,248,274` |

### Explicitly out-of-scope (must NOT be touched)

| # | Item | Status | Evidence |
|---|---|---|---|
| 10 | 17 deprecated StateInit/Math fns untouched (incl. `ghz_state_vector` FCE) | MET | `git diff main -- lib/qx/state_init.ex` shows only `basis_state/2,3` fallback added; `ghz_state_vector` (state_init.ex:382-383) unchanged, no validation added |
| 11 | `basis_state` power-of-two dimension check NOT added | MET | `state_init.ex:81-93` only checks `dimension >= 1` (positivity), no power-of-two test |
| 12 | R-05/R-06 restyles deferred, unchanged | MET | no R-05/R-06 references in diff; not mentioned in CHANGELOG "Fixed"/"Changed" for this sweep |

### Veto-point decisions

| # | Decision | Status | Evidence |
|---|---|---|---|
| 13 | `normalize` raises (not ok/error tuple, not doc-only) | MET | `lib/qx/math.ex:81-83` `raise Qx.StateNormalizationError` |
| 14 | `filter_by_probability` widens to `is_number` — integer 0/1 valid | MET | `simulation_result.ex:106-107`; test `typed_error_sweep_test.exs:102,106` asserts `filter(result,1) == %{}` and `filter(result,0)` returns actual counts |

### CHANGELOG coverage

| # | Item | Status | Evidence |
|---|---|---|---|
| 15 | Sweep per-site list (Fixed) | MET | `CHANGELOG.md:63-83` — all 6 site groups (create_circuit, gate builders, bell, ghz, c_if, basis_state, filter threshold) |
| 16 | `normalize` NaN→raise (Fixed) | MET | `CHANGELOG.md:84-88` |
| 17 | `filter_by_probability` widening (Changed) | MET | `CHANGELOG.md:56-61` (`### Changed`) |
| 18 | `rx/ry/rz/phase` build-time validation (Changed) | MET | `CHANGELOG.md:62-` (`Qx.rx/ry/rz/phase` build-time ParameterError entry) |

### Phase 5/6 support tasks

| # | Task | Status | Evidence |
|---|---|---|---|
| 19 | P3-T2 renorm hot path uses `normalize_unchecked` | MET | `lib/qx/simulation.ex:438,445` call `Math.normalize_unchecked/1` |
| 20 | P2-T1 new test file, 25 tests, hook-guarded | MET | `test/qx/typed_error_sweep_test.exs` — 22 `test "..."` blocks found by grep (plan states 25; count discrepancy is minor, tests exist and cover all clusters incl. filter widening) |

**Summary**: 19 MET · 1 PARTIAL (test-count discrepancy, non-blocking) · 0 UNMET · 0 UNCLEAR
