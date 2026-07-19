# /phx:review — `fix/c64-tolerances`

**Verdict: PASS**

Three specialist agents ran in parallel against the diff (`git diff main`).
All returned PASS. No blockers, no warnings. Three non-blocking
suggestions across the trio, all about pre-existing code or style.

## Diff under review

| File | Change |
|---|---|
| `test/qx/cswap_iswap_matrix_test.exs` | `@delta 1.0e-12` → `1.0e-6` + moduledoc text refreshed + inline Iron-Law-#8 rationale |
| `test/qx/export/openqasm/round_trip_test.exs` | `@tolerance 1.0e-10` → `1.0e-6` + inline Iron-Law-#8 rationale |
| `test/qx/u_gate_convention_test.exs` | `@delta` unchanged at `1.0e-6` + new "do NOT tighten" boundary comment |

3 files, +23 / −6.

## Requirements Coverage

NOT AVAILABLE — no plan file, Linear issue, or GitHub issue detected
for this branch (work was started in `/phx:quick` style). ROADMAP
item is `v0.8.1` "Widen `:c64` sub-ε test tolerances and add
non-integer fixtures"; non-integer fixture coverage is already
satisfied by existing `build_qft3`, `build_mixed_parametric`, and the
U-gate parametric cases per the testing reviewer's confirmation.

## Per-agent findings

### elixir-reviewer — PASS

- `@delta` / `@tolerance` constants are scoped per module; no
  collision or shadowing.
- Moduledoc revision in `cswap_iswap_matrix_test.exs` accurately
  reflects the new tolerance.
- Inline rationale comments are load-bearing, not cluttering.
- (SUGGEST, non-blocking) The "why the old tolerance was wrong"
  prose is mildly duplicated across the cswap/iswap moduledoc and
  the round-trip module comment. Acceptable — separate files read in
  isolation.

### testing-reviewer — PASS

Per-file headroom confirmed:
- `cswap_iswap_matrix_test.exs` — wrong-control-qubit and ±i sign
  errors produce O(1)/O(2) deltas, not O(ε). Seven decades of
  headroom above `1.0e-6`. Detection sensitivity unchanged.
- `round_trip_test.exs` — any real export/import bug produces
  O(0.1)–O(1) statevector differences; float32 accumulation for
  QFT3/mixed-parametric stays well below `1.0e-6` on both sides.
  No false-negative risk.
- `u_gate_convention_test.exs` — `assert_unitary_equal_up_to_phase`
  worst-case float32 rounding (one `Complex.divide` + one
  `Complex.multiply`) is ~3ε ≈ 3.6e-7, leaving ~2.8× headroom.
  Convention swaps would produce O(sin(angle-diff)) ≈ O(0.1) errors.
- (SUGGEST, non-blocking) `states_equal?/2` uses strict `<` rather
  than `<=` against `@tolerance`. Pre-existing, harmless at current
  fixture depth. Worth noting for future deep circuits.

### iron-law-judge — PASS

- Iron Law #8 compliance: **YES.** All three files use `1.0e-6` for
  every actual assertion (`assert_in_delta`, `diff < @tolerance`).
  The retired `1.0e-12` and `1.0e-10` are gone.
- Potential false-alarm to be aware of: `u_gate_convention_test.exs:104`
  contains `1.0e-9` but it is a pivot-magnitude filter (guards against
  dividing by ~zero when extracting the phase ratio), not a tolerance
  passed to `assert_in_delta`. Does not violate Iron Law #8.
- No other Iron Laws triggered — diff is comment + constant changes
  in pure library test files.
- Inline justifications accurate: all three `# Iron Law #8:` comments
  correctly identify `:c64` ε ≈ 1.2e-7, name `1.0e-6` as the floor,
  and give sound reasoning (headroom above float32 ε; cumulative
  trig-product error for parametric tests).

## Merge-gate status

**PASS — branch may merge to `main`** per the qx workflow step 7. No
findings require triage. The three SUGGEST items are pre-existing
and out-of-scope for this branch's "widen tolerances" change.
