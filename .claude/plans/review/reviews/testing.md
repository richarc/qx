# Test Review: test/qx/cswap_iswap_matrix_test.exs (refactor 41496d5 → 8cc8bdc)

## Summary

Note: no `Bash`/git tool was available in this session, so the diff itself
could not be executed; this review verifies the refactor by reading the
current file (`/home/richarc/qxquantum/qx/test/qx/cswap_iswap_matrix_test.exs`)
and reasoning about the extracted helpers algebraically against the
moduledoc's stated intent. The orchestrator/human should confirm the actual
diff matches this description if that matters.

The credo-motivated extraction (`identity_with_rows_swapped/3` →
`swapped_index/3` + `identity_row/2`, lines 69-85) is **behavior-preserving**.
The decomposition is a straightforward, correct factoring of a row-swap
permutation-matrix builder:

- `swapped_index(i, r1, r2)` returns the column index for row `i`: `r2` when
  `i == r1`, `r1` when `i == r2`, else `i` — this is exactly the transposition
  `(r1 r2)` applied to the row index, matching "identity with rows r1/r2
  exchanged."
- `identity_row(n, src)` builds a length-`n` one-hot row with `1` at `src`,
  `0` elsewhere — a correct one-hot/identity-row primitive with no off-by-one
  (range `0..(n-1)` matches `identity_with_rows_swapped`'s own range).
- Composing them (`identity_row(n, swapped_index(i, r1, r2))` for each `i`)
  reproduces the original nested `for`+`cond` semantics exactly: row `i`'s
  single `1` sits at column `swapped_index(i, r1, r2)`.

Verified against both call sites: `identity_with_rows_swapped(8, 5, 6)` for
`cswap(0,1,2,3)` and `identity_with_rows_swapped(8, 3, 5)` for
`cswap(2,0,1,3)` — both produce the intended symmetric transposition
permutation matrix (self-inverse, matching CSWAP's real-permutation,
Hermitian-unitary nature described in the moduledoc).

## Iron Law Violations

None. `async: true` is set (line 32), no DB/Mox/sleep/process concerns apply
to this pure-computation test file.

## Issues Found

### Critical

None.

### Warnings

None.

### Suggestions

- `swapped_index/3` and `identity_row/2` are private helpers only exercised
  indirectly (via `identity_with_rows_swapped/3` from two describe-block
  tests with different `r1`/`r2` pairs). This is adequate coverage for the
  refactor's purpose (silencing credo nesting-depth) — no direct unit test
  of the helpers is needed since they're not part of the public test-file
  contract. No action required.
- The degenerate case `r1 == r2` (identity_with_rows_swapped would be a
  no-op identity matrix) is untested, but it's never called that way in this
  file and isn't part of the file's stated scope (catching CSWAP/iSWAP
  convention errors) — not a gap worth adding for this narrow file.
- Everything else in the file (assertion helper `assert_complex_matrix_equal/3`,
  the negative-control sanity test, the iSWAP sign-guard test) is unchanged
  by this refactor and remains sound: shape-checked before entrywise
  comparison, tight `1.0e-6` delta matching `:c64` epsilon, descriptive test
  names, `describe` blocks grouping CSWAP vs iSWAP.
