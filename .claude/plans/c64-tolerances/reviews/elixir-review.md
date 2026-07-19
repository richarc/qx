# Elixir Review: fix/c64-tolerances

## Summary
- **Status**: ✅ Approved
- **Issues Found**: 2 (both SUGGEST)

---

## Suggestions

1. **SUGGEST** `cswap_iswap_matrix_test.exs:48` — `|> Nx.to_list() |> List.flatten()` is repeated in both `assert_complex_matrix_equal/3` (line 48) and identically in `u_gate_convention_test.exs:98–99`. Not new code, but the pattern is copy-pasted — minor readability duplication. No fix required now; note for a future shared test helper if a third callsite appears.

2. **SUGGEST** `cswap_iswap_matrix_test.exs:2–30` — The `@moduledoc` prose is accurate and load-bearing (explains the old tolerance, why it was wrong, and what the new value defends against). Length is borderline (~200 words), but every sentence carries a unique claim. The one sentence that could tighten is line 27–29: *"The previous `1.0e-12` tolerance passed only because… any reformulation of the kernel… would silently break that bit-identity."* This is correct and necessary, but is nearly identical to the comment at `round_trip_test.exs:10–12`. Duplication across files is fine for test files (they are read independently), so no change is required.

---

## Specific checks (all clear)

- **`@delta` / `@tolerance` names**: no collision or shadowing. `@delta` is local to `cswap_iswap_matrix_test.exs` and `u_gate_convention_test.exs`; `@tolerance` is local to `round_trip_test.exs`. All three are module attributes scoped to their own module. No cross-file interference.
- **Moduledoc accuracy** (`cswap_iswap_matrix_test.exs`): the claim *"delta `1.0e-6`"* on line 22 matches `@delta 1.0e-6` on line 39. The claim about float32 epsilon (~1.2e-7) is standard IEEE 754 single-precision. No stale claims detected.
- **`u_gate_convention_test.exs` "do NOT tighten further" comment** (lines 24–30): accurate and concise. The rationale (cumulative irrational cos/sin products reaching ~5e-7) is plausible and the instruction is actionable. Not a wall of text.
- **Pipe usage**: `round_trip_test.exs:33` pipeline (`|> Nx.subtract |> Nx.abs |> Nx.reduce_max |> Nx.to_number`) is idiomatic. No pipe anti-patterns anywhere in the diff.
- **`cond` in `identity_with_rows_swapped/3`** (lines 72–76): `cond` is the right tool here (three clauses, boolean conditions, no pattern to destructure). A multi-clause private function would also work but would not be strictly better.
- **Comment hygiene**: inline `# Guards the 'wrong control qubit' failure mode` (line 95) and `# +i ⇒ real 0, imag +1.0` (line 144) are concise and load-bearing. No clutter.
- **`# credo:disable-for-next-line`** suppression on `apply/3` calls in `round_trip_test.exs` (lines 113, 141): correctly scoped to the next line only. Pre-existing; not part of this diff's changes.
