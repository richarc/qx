# Code Review v2: feat/calcfast-norm-drift-guard (re-review)

## Summary
- **Status**: ✅ Approved
- **New Issues Found**: 0
- **Prior Findings Verified**: 5/5 RESOLVED

---

## Prior Findings Status

### B1 (BLOCKER) — `Qx.OptionError` missing from docs group → RESOLVED
`mix.exs:93` lists `Qx.OptionError` in the `"Error Handling"` group alongside the other typed
error modules. Confirmed at line 93.

### W1 (WARNING) — c_if sub-gates bypassed `{:every, n}` counter → RESOLVED

**Counter equivalence verified.** Old path: `Enum.with_index` (0-based), renorm when
`rem(idx+1, n) == 0` — fires after gates n, 2n, 3n, …  New path: `count` starts at 0,
`next = count + 1`, renorm when `rem(next, n) == 0` — fires after gates n, 2n, 3n, …
Semantics are identical; no off-by-one.

**`execute_circuit/2` return value:** `{final_state, _count} = Enum.reduce(...)` correctly
discards the counter; callers (`get_state/2`, `get_probabilities/2`, `run_without_conditionals/3`)
receive the plain tensor. Correct.

**`process_timeline_item/6` measurement branch** (`{:measurement, …}`): returns
`{new_state, cbits, count}` — counter unchanged. Gate branch threads `{new_state, cbits, next}`
from `apply_gate_step`. Correct: measurements do not advance the unitary gate counter.

**`process_conditional/8` non-firing branch:** returns `{state, cbits, count}` unchanged.
Firing branch reduces sub-instructions through `apply_gate_step`, accumulating `{s, c}`, and
returns `{new_state, cbits, new_count}`. Sub-gate applications advance the shared counter and
receive per-gate renorm + `assert_norm/1`. Correct.

### W4 (WARNING) — `@spec validate_renormalize!` too narrow → RESOLVED
`validation.ex:328`: `@spec validate_renormalize!(term()) :: false | true | pos_integer()`
Now accepts `term()` input and returns the union type covering all three valid outputs.

### S1 — `assert_norm/1` discards `:ok` → RESOLVED
`simulation.ex:311`: `if @assert_norm, do: :ok = Validation.validate_normalized!(state, @norm_tolerance)`
Pattern-matches on `:ok`; a non-`:ok` return or a raised exception would propagate. The
compile-time gate (`@assert_norm false` in prod) ensures this is dead code in production.

### S2 — `resolve_renormalize/1` case → RESOLVED
`simulation.ex:104–113`: Pipes `Keyword.get` result through `Validation.validate_renormalize!`
then into private multi-clause `to_renorm/1` (`false` → `:off`, `true` → `:measurement`,
`n` → `{:every, n}`). Clean, idiomatic.

---

## New Issues

None found. The W1 refactor is behaviourally correct for all paths:
- non-conditional `execute_circuit/2`
- conditional `execute_single_shot/2` → `process_timeline_item/6`
- conditional branch `process_conditional/8`

The 3-tuple `{state, cbits, count}` threading through the reduce in `execute_single_shot/2`
is consistent; the final `{final_state, final_classical_bits, _count}` destructure at line 495
correctly discards the terminal counter.

No arity mismatches, dead clauses, or unused variables were detected. Compile passes with
`--warnings-as-errors` (confirmed by user). Credo strict clean (confirmed by user).
