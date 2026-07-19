# Test Review: test/qx/cswap_iswap_matrix_test.exs

## Summary

The new test file is well-structured and genuinely catches the targeted failure modes. All five tests are mathematically correct. Reference matrices are built independently of `Qx.Gates` (via `Qx.Math.complex_matrix/1` + `identity_with_rows_swapped/3`), so tests are not tautological. No iron law violations found.

## Iron Law Violations

None.

## Issues Found

### Critical

None.

### Warnings

- [ ] **`List.flatten/1` on complex tensor rows may be fragile** — `test/qx/cswap_iswap_matrix_test.exs:42–43`. `Nx.to_list()` on a `:c64` `{8,8}` tensor returns a list of lists of `%Complex{}` structs. `List.flatten/1` works here (Complex structs are not lists, so they are leaf nodes), but the intent is a flat sequence of 64 entries. If the tensor representation ever changes (e.g. a `{2, n, n}` real/imag split), `flatten` will silently produce garbage. Consider `for row <- Nx.to_list(actual), entry <- row, do: entry` (two-level explicit unzip) to make the structure intent clear and fail loudly on shape change.

- [ ] **"Negative-control" test operates only on `cswap(0,1,2,3)`** — `test/qx/cswap_iswap_matrix_test.exs:99`. The test is correct for what it asserts, but it only validates the control-off subspace for the default qubit ordering. The `cswap(2,0,1,3)` configuration also has a control-off subspace (indices where bit0=0), and a wrong-control bug could pass the negative-control test while still failing in the full matrix test. This is a minor coverage gap — the full matrix test at line 87 already covers the `(2,0,1,3)` case completely, so this is low risk. Noting for awareness, not as a required fix.

### Suggestions

- [ ] **`assert_complex_matrix_equal/3` index reporting could include row/col** — `test/qx/cswap_iswap_matrix_test.exs:50–56`. On failure the message reports `flat index #{idx}`. For an 8x8 matrix, flat index 45 is less diagnostic than `row 5, col 5`. Consider `row = div(idx, n); col = rem(idx, n)` where `n = elem(Nx.shape(actual), 0)`. This requires threading `n` through but makes failure messages immediately actionable.

- [ ] **Doctest in `lib/qx/gates.ex:495–496`** confirms only shape `{8,8}` for `cswap`. This is a meaningful sanity check (rules out the old `{8,8,2}` representation regression). It does not and need not assert matrix content — the new test file owns that. No change needed; confirming this is intentional and sufficient.

## Permutation Verification (by-hand)

**`cswap(0,1,2,3)` → rows 5↔6**: With `num_qubits=3`, control=q0 → bit_pos=2, ta=q1 → bit_pos=1, tb=q2 → bit_pos=0. Index 5 (101b): control=1, ta=0, tb=1 → swap → j = 5 XOR 2 XOR 1 = 6. Index 6 (110b): control=1, ta=1, tb=0 → swap → j = 5. Confirmed correct.

**`cswap(2,0,1,3)` → rows 3↔5**: control=q2 → bit_pos=0, ta=q0 → bit_pos=2, tb=q1 → bit_pos=1. Index 3 (011b): control=1, ta=0, tb=1 → swap → j = 3 XOR 4 XOR 2 = 5. Index 5 (101b): control=1, ta=1, tb=0 → swap → j = 3. Confirmed correct.

**`iswap(0,1,2)` → `[[1,0,0,0],[0,0,i,0],[0,i,0,0],[0,0,0,1]]` with +i**: bit_a=1, bit_b=0. Index 1 (01b): a=0, b=1 → a≠b → j = 1 XOR 2 XOR 1 = 2. Row 1 col 2 gets +i. Index 2 (10b): a=1, b=0 → j = 2 XOR 2 XOR 1 = 1. Row 2 col 1 gets +i. Both entries are +i (imag +1.0), not −i. Confirmed correct.

## Independence Check

`identity_with_rows_swapped/3` is a pure Elixir list builder with no import of `Qx.Gates`. `Math.complex_matrix/1` converts plain number/Complex lists to an Nx tensor. Neither calls any function from `Qx.Gates`. Reference matrices are genuine — not tautological.
