# Review — Typed-error sweep #3 (v0.11)

**Verdict: PASS WITH WARNINGS**
**Branch:** `fix/typed-error-sweep-3` · **Diff base:** `main` · 11 source files + 1 new test file
**Agents:** elixir-reviewer, testing-reviewer, iron-law-judge, verification-runner, requirements-verifier (5/5 completed)

## Requirements Coverage (requirements-verifier)

**19 MET · 1 PARTIAL · 0 UNMET · 0 UNCLEAR**

- All 9 mapped error sites implemented with typed `Qx.*Error` raises + matching `Qx.Validation` helpers.
- Both out-of-scope guardrails held (17 deprecated StateInit/Math fns untouched; no `basis_state` power-of-two semantic tightening).
- Both veto-point decisions match implementation (`normalize`→raise; `filter_by_probability` widens to `is_number`, integers 0/1 valid).
- CHANGELOG `Fixed`/`Changed` cover the sweep, normalize NaN fix, filter widening, rx/ry/rz/phase build-time validation.
- **PARTIAL is a false alarm**: verifier grep-counted 22 `test` blocks, but the `for op <- [:rx,:ry,:rz,:phase]` comprehension generates 4 tests from one line → ExUnit runs **25** (confirmed by the runner). Requirement is actually MET.

## Verification (verification-runner) — PASS

| Gate | Result |
|------|--------|
| `mix compile --warnings-as-errors` | clean |
| `mix format --check-formatted` | OK |
| `mix credo --strict` | no issues (920 mods/funs) |
| `mix test` | 250 doctests + 1030 tests, **0 failures** |
| `mix docs` warnings | 36 (= baseline) |

## Iron Laws (iron-law-judge) — 0 violations

All deliberately-implicated laws SATISFIED: **#7** (all misuse → typed errors, no raw leaks), **#5/#8** (normalize's single `Nx.to_number` sync confined to the public wrapper; correctly NOT compile-gated as a permanent validation; renorm hot path uses `normalize_unchecked/1` with no added sync), **#3/#4** (`normalize_unchecked/1` byte-identical to former defn; `Nx.pow` used in the host def, not the defn-only `**`; no defn calls the host def), **#6** (non-breaking — each fallback fires only on inputs that already crashed on `main`; CHANGELOG present), **#9** (no new instruction shapes; n/a). Judge traced each fallback against its guarded sibling's negated guard: no valid-today input can reach a fallback.

## Warnings (worth addressing, non-blocking)

### W1 — `new/2` (& `filter_by_probability/2`) fallback relies on emergent exhaustiveness — elixir-reviewer
`lib/qx/quantum_circuit.ex` `new/2` fallback body is two validator calls; it raises only because the two independently-guarded validators happen to complement the primary clause's guard. If a validator guard is later edited without noticing the coupling, the clause silently returns `:ok` (from `validate_num_classical_bits!`) instead of a `%QuantumCircuit{}`, violating its `@spec`. `lib/qx/simulation_result.ex` filter fallback shares the pattern (lower risk — guard is a direct copy one file away). **Correct today**; hardening = make intent explicit rather than emergent.

### W2 — Two test assertions weaker than the "byte-identical" claim — testing-reviewer
- `filter_by_probability(result, 1)` test proves only "doesn't raise" (`min_count=100`, counts 52/48 → `%{}` would also result from a broken arithmetic path); doesn't pin the additive-widening math.
- c64 `normalize` survivor asserts only `Nx.type == {:c,64}`, not amplitude values — weaker than the f32 survivor test.

### W3 — Message-regex assertions in 3 tests — testing-reviewer
`create_circuit`/`h`/`cx` tests use `~r/must be an integer/` (brittle to wording tweaks) vs. the stronger field-based checks (`e.option`, `e.reason`) elsewhere in the same file. Symmetry suggestion.

## Suggestions (optional)
- `c_if/4` value-validity clause fires before the bit-type fallback, so a simultaneously-invalid `classical_bit` + `value` raises `Qx.ConditionalError` rather than `Qx.ClassicalBitError` (elixir-reviewer). **Intentional** — a genuinely-wrong value should report the value error; something typed is always raised.
- Several type-only test assertions (negative bits, `cx`, `ghz(:x)`, `c_if`) could add field checks for symmetry.

## Bottom line
No BLOCKERs, no correctness bugs, no Iron Law violations, all requirements met, all gates green. The warnings are robustness/test-strength improvements. Safe to merge; W1 is the one worth a cheap hardening pass before merge if desired.
