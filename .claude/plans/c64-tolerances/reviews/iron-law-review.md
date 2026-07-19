# Iron Law Review — fix/c64-tolerances

**Files reviewed:**
- `test/qx/cswap_iswap_matrix_test.exs`
- `test/qx/export/openqasm/round_trip_test.exs`
- `test/qx/u_gate_convention_test.exs`

**Iron Laws checked:** #8 (precision/tolerance feasibility on `:c64`). All other laws non-applicable (pure library test files; no Phoenix/Ecto/Oban/LiveView patterns).

---

## PASS

No Iron Law violations found. One item flagged for awareness (not a violation):

### Awareness only — `1.0e-9` pivot guard in `u_gate_convention_test.exs:104`

```elixir
Complex.abs(bv) > 1.0e-9 and Complex.abs(av) > 1.0e-9
```

This is a **pivot-selection filter**, not a tolerance assertion. It guards against choosing a near-zero entry as the phase reference before calling `Complex.divide/2`. It is never passed to `assert_in_delta`. All actual equality assertions in this file use `@delta` (1.0e-6). Not an Iron Law #8 violation.

---

## Checklist

| Question | Answer |
|---|---|
| Sub-ε tolerances remaining? | No. All `assert_in_delta` / `diff <` comparisons use 1.0e-6. |
| Other Iron Laws triggered by the diff? | No. Diff is comment + constant changes only. |
| Inline justifications accurate? | Yes — all three comments correctly state ε≈1.2e-7, 1.0e-6 as the floor, and give accurate reasoning for the choice. |
