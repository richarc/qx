# Testing review — commit 0f38904 (fix/counts-contract), test/ changes only

Reviewer: testing-reviewer agent, 2026-07-04
Scope: `git show 0f38904 -- test/` — mechanical bit-list → string migration
(~30 assertions, 6 files) plus new `test/qx/simulation_result_seam_test.exs`.

## Verdict: PASS WITH WARNINGS

Two minor, non-blocking findings (W1, W2). No assertion was weakened, no
list-key usage survives in `test/`, and every statistical assertion in the
seam test is flake-proof by a wide margin.

## 1. Mechanical migration — no weakening found

Every old/new pair compared. All 30 are strict 1:1 rewrites: the operator,
the default value, the expected count, and the set membership are unchanged;
only the key literal changed, with `Enum.join/1` order preserved (bit 0
leftmost matches the old list order, e.g. `[1, 0, 1, 1, 0, 1]` → `"101101"`).

| File | Pairs | Pattern | Equivalent? |
|---|---|---|---|
| `test/qx/barrier_dispatch_test.exs` | 2 | exact map `==` | yes |
| `test/qx/conditional_operations_test.exs` | 7 | exact map `==` ×5, `Map.get(_, k, 0)` ×2 | yes |
| `test/qx/operations_basis_measurement_test.exs` | 9 | `Map.get(_, k, 0)` with same `== 100` / range bounds | yes |
| `test/qx/partial_measurement_test.exs` | 8 | `MapSet` subset/equal/disjoint + `Map.get` + `assert_in_delta` | yes |
| `test/qx_test.exs` | 7 | `counts[k]`, `Map.get`, one reduce | yes (see below) |

The one non-trivial rewrite is `test/qx_test.exs:316`:
`Enum.at(bits, 2) == 1` → `String.at(bits, 2) == "1"`. Semantically
equivalent — keys are ASCII `0`/`1` strings, `String.at/2` indexes the same
position and returns `nil` past the end exactly as `Enum.at/2` did, so the
`else` branch behaves identically. Same strictness (`total_measure_1 == 100`
still requires every shot).

The `forbidden`-outcomes disjoint check and the `count_000 + count_111 ==
shots` totality check (the strongest assertions in their files) survived the
migration intact.

## 2. Leftover list-key sweep — clean

Grepped `test/` for `counts[[`, `Map.get(counts, [`, `[[0|1], ...] =>`,
`MapSet.new([[`, and every remaining `counts` consumer by hand:

- All 60+ remaining `counts` references in `test/` use string keys or are
  key-agnostic (`is_map`, struct pattern match, comment text).
- `test/qx/result_builder_test.exs` already used string keys (hardware path
  — the pre-existing correct contract).
- `test/qx/simulation_renormalization_test.exs` builds no counts; it only
  pattern-matches `%Qx.SimulationResult{}`.

No stragglers.

## 3. Seam test quality (`test/qx/simulation_result_seam_test.exs`)

Coverage against real `Qx.run/2` output:

- **Key contract**: exact `%{"10" => 50}` on a deterministic X circuit —
  also pins bit-0-leftmost ordering. Good.
- **`most_frequent/1`**: exercised on the Bell result; `outcome in
  ["00", "11"]` is the correct flake-free form. See W1 on the count bound.
- **`outcomes/1`**: `== ["00", "11"]` is deterministic in *order* (the
  implementation `Enum.sort`s, `lib/qx/simulation_result.ex:128-132`) and in
  *content*: P(either outcome absent) = 2·2⁻¹⁰²⁴ ≈ 10⁻³⁰⁸. Flake-proof.
- **`probability/2` hit**: p("00") + p("11") sums counts to exactly
  1024/1024; division by a power of two is exact in float, so the value is
  exactly 1.0 — `assert_in_delta 1.0e-9` is belt-and-braces. Sound.
- **`probability/2` miss**: `probability(result, "01") == 0.0` — the |01⟩
  amplitude is exactly 0.0 after H+CX (never rounded into), so "01" cannot
  be sampled; `Map.get` default 0 / 1024 == 0.0 exactly. Deterministic.
- **`filter_by_probability/2` at 0.25**: requires both buckets ≥ 256 of
  1024 (`count >= threshold * shots`, simulation_result.ex:104-107). For
  Binomial(1024, 0.5), 256 is 16σ below the mean of 512; Hoeffding gives
  P(count < 256) ≤ exp(−2·256²/1024) = e⁻¹²⁸ ≈ 2.6×10⁻⁵⁶ per side.
  Assessed: no flake risk in any realistic CI lifetime.
- **c_if path**: separate deterministic test proves the conditional
  (per-shot) producer site emits the same string contract as the batch
  site — this is exactly the two-producer seam the fix touched. Good.
- **Doctests**: `doctest Qx.SimulationResult` wired here and nowhere else
  (no duplicate), covering `to_map/1` and the empty/hand-built edge cases
  the seam cannot produce.
- **Async safety**: `async: true` is safe — `Qx.run/2` is pure computation
  with per-process RNG, no named processes, no shared state; matches every
  sibling file in the migration set (all `async: true`).

### W1 (minor, tightening opportunity)
`assert count > 0` for `most_frequent/1` is weaker than the circuit
guarantees: with ≤ 2 outcomes summing to 1024 shots, the max bucket is
deterministically ≥ 512. `assert count >= 512` would cost nothing and catch
a most_frequent that returned the *wrong* tuple element or a min-by
regression. Not a defect — `outcome in ["00", "11"]` already guards the key.

### W2 (minor, doc accuracy)
The moduledoc claims "every `Qx.SimulationResult` helper consumed against
real `Qx.run/2` output, never a hand-built fixture", but `to_map/1` is
exercised only by the (hand-built-fixture) doctest, not in a seam test body.
Either add a one-line `to_map` assertion on a real result or soften the
moduledoc claim. Trivial either way.

### Observation (pre-existing, out of scope)
`doctest Qx` is wired in both `test/qx_test.exs:3` and
`test/complex_support_test.exs:3`, so the `Qx` doctests run twice. Predates
this commit; noted for a future cleanup line in ROADMAP/scratchpad.

## 4. ExUnit patterns per repo standards

- `use ExUnit.Case, async: true` — consistent with the suite.
- Moduledoc records the regression origin (R-01) — matches the repo's
  compound-docs habit.
- `assert_in_delta` for the float sum, exact `==` only where exact — correct
  discipline.
- Style nit (not a finding): the seam file uses three top-level tests where
  sibling files group with `describe`; harmless at this size.
- TDD rule 2 (no test edits without human approval) — commit message records
  explicit approval 2026-07-04. Compliant.
