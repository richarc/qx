# Code Review: calcfast-simulation-specs

## Summary
- **Status**: Changes Requested
- **Issues Found**: 4 (0 BLOCKER, 2 WARNING, 2 SUGGESTION)

---

## Warnings

### W1 — `@typep cbits :: [non_neg_integer()]` is too loose (`simulation.ex` line 22)

The type admits any non-negative integer, but every write path produces only `0` or `1`:

- Initial value: `List.duplicate(0, ...)` — all zeros
- Only mutation: `List.replace_at(cbits, cbit, measured_value)` where `measured_value` comes from `perform_single_measurement/3`, which returns `{state(), bit()}` (literal `0` or `1` via `if :rand.uniform() < prob_0, do: 0, else: 1`)

The correct type is `[bit()]`. Using `[non_neg_integer()]` here misleads callers and obscures the quantum-circuit contract that classical registers hold only single-bit values. Dialyzer would flag nothing because the current type compiles, but it defeats the purpose of the `@typep bit :: 0 | 1` alias defined three lines above.

### W2 — `@doc` on `apply_cswap` describes a Toffoli gate (`calc_fast.ex` lines 173–179)

The doc block that precedes `apply_cswap` reads: "Applies a Toffoli (CCX) gate directly to a statevector." The function is a CSWAP (Fredkin), not a Toffoli. Parameters are `control`, `target_a`, `target_b` — the doc even describes them as "first control qubit", "second control qubit", "target qubit" which is the Toffoli signature. This is a copy-paste of the preceding `apply_toffoli` doc. Not a type-spec error, but a doc accuracy error in a module that has no other docs (flagged here because it was specifically introduced in this diff as part of the `@spec` annotation pass).

---

## Suggestions

### S1 — `timeline_item` conditional `value` could be `bit()`, not `non_neg_integer()` (`simulation.ex` lines 24–27)

```elixir
@typep timeline_item ::
         {:instruction, instruction()}
         | {:measurement, measurement()}
         | {:conditional, {non_neg_integer(), non_neg_integer(), [instruction()]}}
         #                                   ^^^^^^^^^^^^^^^^
         #                    This is `value` — compared against a cbits element
```

`process_conditional/8` evaluates `Enum.at(cbits, cbit) == value`. If `cbits :: [bit()]` (see W1), then any `value > 1` makes the conditional branch permanently dead — it can never fire. If the intent is that `value` is always `0` or `1` (the only meaningful comparison against a classical bit), the type should be `bit()`. If multi-bit classical registers are a future goal, that is fine but should be noted in a comment explaining the looseness intentionally.

As written, both the `cbits` type (W1) and this `non_neg_integer()` value leave open an implied promise (multi-bit comparisons) that the current implementation cannot fulfill.

### S2 — `@typep counts :: %{optional([non_neg_integer()]) => pos_integer()}` key type (`simulation.ex` line 23)

Keys are produced by `Enum.frequencies(classical_bits)` where `classical_bits :: [[bit()]]`, so keys are always `[bit()]`. Using `[non_neg_integer()]` is a supertype and not wrong, but it is less precise than the `bit()` alias already defined. If W1 is fixed, tightening this to `%{optional([bit()]) => pos_integer()}` would follow naturally.

---

## Spec-accuracy sign-off for remaining items

All other specs verified correct against the implementation:

- `@typep renorm` — three-variant union matches all `to_renorm/1` clauses and the output of `validate_renormalize!/1`.
- `@spec to_renorm(boolean() | pos_integer())` — `boolean()` = `true | false`; exactly matches `validate_renormalize!/1` return (`false | true | pos_integer()`). All three clauses covered.
- `@spec perform_measurements/3 :: {[[bit()]], counts()}` — empty branch returns `{[], %{}}` (valid since `[]` satisfies `[[bit()]]`); non-empty branch produces `[[bit()]]` via `Bitwise.band(..., 1)` (confirmed 0|1). Correct.
- `@spec calculate_measurement_probability/4 :: float()` — `for reduce: 0.0` accumulating float additions; confirmed float return. Correct.
- `@spec apply_gate_step/5 :: {state(), non_neg_integer()}` — `next = count + 1` where count starts at 0; return is `{new_state, next}`. Type is `non_neg_integer()` which is correct (next ≥ 1 is a subtype). Acceptable.
- `@spec process_timeline_item/6 :: {state(), cbits(), non_neg_integer()}` and `@spec process_conditional/8 :: {state(), cbits(), non_neg_integer()}` — all three branches return correctly shaped 3-tuples with the gate count threaded unchanged on measurement/conditional-skip paths. Correct.
- `calc_fast.ex` `defn`/`defnp` specs — placing `@spec` on `defn`/`defnp` is sound (defn compiles to a normal function). `non_neg_integer()` for qubit indices (≥ 0) and `pos_integer()` for `num_qubits` (matched against literal `1`, so ≥ 1) are the right choices throughout. `Nx.Tensor.t()` for all tensor args is appropriate. No index/count type errors found.
