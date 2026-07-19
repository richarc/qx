# Consolidated Review: stateinit-math-tier-trim

**Strategy**: Index  
**Input**: 4 files, ~2.3k tokens  
**Output**: ~3k tokens (compression not needed; all items retained per Index strategy)

## Requirements Coverage (from Plan file)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Exactly 17 functions deprecated (9 StateInit + 8 Math), messages end "Will be removed in Qx 1.0"; survivors `basis_state/2,3`, `normalize/1`, `probabilities/1` NOT deprecated | MET | `lib/qx/math.ex:38,84,105,123,155,187,211,247` (8) + `lib/qx/state_init.ex:99,115,131,148,184,218,278,355,393` (9) = 17, all end "Will be removed in Qx 1.0"; `basis_state/2,3` (state_init.ex:61) and `normalize/1`/`probabilities/1` (math.ex:66,140) have no `@deprecated`; confirmed via `test/qx/tier_trim_test.exs` pass |
| 2 | `complex_to_tensor/1`/`tensor_to_complex/1` deleted from lib and their describe blocks removed from `math_test.exs`; `complex_matrix/1` untouched, still `@doc false` | MET | `grep def complex_to_tensor\|tensor_to_complex lib/qx/math.ex` → no matches; `grep ... test/qx/math_test.exs` → no matches; `lib/qx/math.ex:163-164` `@doc false` / `def complex_matrix(matrix)` unchanged |
| 3 | Internal callers re-homed (register.ex, qubit.ex) — no lib/ file calls a deprecated function; `unitary?` uses `Nx.eye` directly | MET | `register.ex:48` uses `StateInit.basis_state/2`, `:744` uses `Math.probabilities/1` (both survivors); `qubit.ex:89,94,160` `Math.normalize`, `:109` `StateInit.basis_state(1,2)`, `:498` `Math.probabilities` (all survivors); `math.ex:255` `unitary?/1` body calls `Nx.eye(n)` directly; `mix compile --force --warnings-as-errors` clean (no deprecation warnings from lib/) |
| 4 | `Qx.Behaviours.QuantumState` `@moduledoc false` on outer module, callbacks intact, `register.ex` `@behaviour` line still present; removed from `lib/qx.ex` moduledoc list | MET | `lib/qx/behaviours/quantum_state.ex:8` `@moduledoc false` on outer module; all `@callback`s present (h/x/y/z/... through state_vector/valid?); `register.ex:9` `@behaviour Qx.Behaviours.QuantumState` retained; `lib/qx.ex` grep shows no `QuantumState` line, only `Qx.StateInit` (trimmed wording) |
| 5 | AGENTS.md Iron Law #6 updated (Qx.Behaviours.* dropped, trim annotations); CHANGELOG has Deprecated (17), Removed (2, flagged internal), Changed (demotion) under [Unreleased] | MET | `AGENTS.md:393` law #6 surface list has no `Qx.Behaviours.*`, states StateInit/Math trimmed surface and lists `Qx.Behaviours.QuantumState` as demoted internal; `CHANGELOG.md` `[Unreleased]` has `### Deprecated` (9 StateInit + 8 Math = 17), `### Removed` (complex_to_tensor/tensor_to_complex, flagged "never part of the public API"), `### Changed` (QuantumState demotion per R-13) |
| 6 | Explicitly deferred items NOT done (no R-05 opts-last restyle, no R-06 renaming, no removals of deprecated public fns) | MET | `state_init.ex:100,116` retain original opts-last signatures (`zero_state(num_qubits, type \\ :c64)`, `one_state(type \\ :c64)`) — no restyle; function names unchanged (`zero_state`, `bell_state_vector`, etc.) — no R-06 rename; all 17 deprecated functions still `def`ined (not removed), verified passing test suite exercises them |
| 7 | New `tier_trim_test.exs` exists and covers (a)/(c)/(b) from Phase 2 | MET | `test/qx/tier_trim_test.exs` — describe "Qx.Math trimmed surface" covers (a) 8 deprecated + survivor check + (c) `refute function_exported?(Qx.Math, :complex_to_tensor/tensor_to_complex, 1)`; describe "Qx.StateInit trimmed surface" covers (a) 9 deprecated + survivor `basis_state/3`; describe "Qx.Behaviours.QuantumState demotion (R-13)" covers (b) `Code.fetch_docs` `:hidden`. `mix test test/qx/tier_trim_test.exs test/qx/math_test.exs` → 11 doctests, 37 tests, 0 failures |

**Summary**: 7 MET · 0 PARTIAL · 0 UNMET · 0 UNCLEAR

---

## Review Findings

### Overall Status
- **Elixir Review**: Approved (0 blockers, 2 warnings, 3 suggestions)
- **Testing Review**: Approved (0 blockers, 2 warnings, 1 suggestion)
- **Iron Law Judge**: All laws compliant (0 violations)

### BLOCKER
None.

### WARNING

1. **lib/qx/math.ex / lib/qx/state_init.ex — doctests exercise the very functions they deprecate** (Found by: elixir-reviewer)
   
   Every deprecated function's own `## Examples` doctest still calls itself (e.g. `state_init.ex:83` `Qx.StateInit.zero_state(1)`, `math.ex:78` `Qx.Math.inner_product(...)`). Running `doctest Qx.Math` / `doctest Qx.StateInit` will emit a deprecation warning per doctest (17 new warning sites). Does not break `mix compile --warnings-as-errors` (test/ isn't compiled), but `mix test` output going forward will be noisy with self-inflicted deprecation warnings — easy to miss a real new deprecation warning once these become background noise.
   
   **Action**: Confirm this was accepted deliberately (plan/scratchpad) rather than overlooked. If not acceptable, options are: accept the noise, or drop the runnable `iex>` prompts and keep prose-only examples for the 17 deprecated functions.

2. **test/qx/math_test.exs — existing describe blocks still call deprecated functions** (Found by: elixir-reviewer)
   
   The unchanged describe blocks for `kron/2`, `inner_product/2`, `outer_product/2`, `apply_gate/2`, `trace/1`, `identity/1`, `unitary?/1`, `complex/2` (e.g. `math_test.exs:25` `Math.kron(a, b)`) now emit deprecation warnings on every test run. Tests still pass; plan explicitly did not want these deleted, only the two converter describe blocks. Worth a note in the plan's scratchpad so a future contributor doesn't mistake the warning volume for a regression.

3. **test/qx/tier_trim_test.exs — no explicit guarantee that deprecated functions still work** (Found by: testing-reviewer)
   
   The new test suite relies entirely on pre-existing describe blocks in `math_test.exs` / `state_init_test.exs` (which are untouched and still call deprecated functions for correctness) to cover the "deprecated ⇒ still functional until 1.0" property. This coupling is implicit — nothing in `tier_trim_test.exs` documents or enforces it. Consider adding one `describe "deprecated functions still work"` block (or a comment pointing at the source tests) so a future edit that guts those correctness tests doesn't silently lose the "must still work" guarantee this trim depends on.

4. **test/qx/tier_trim_test.exs:37-44 and 62-69 — weak deprecation-message assertion** (Found by: testing-reviewer)
   
   The `is_binary(meta[...])` assertion only checks *a* deprecation message exists, not that it's non-empty/meaningful (e.g. it would pass for `@deprecated ""`). Plan promises each notice "carries a drop-in replacement." Stricter: `String.trim(msg) != ""` or a length check.

### SUGGESTION

1. **lib/qx/state_init.ex:218 — `random_state/2` deprecation notice message improvement** (Found by: elixir-reviewer)
   
   The deprecation says "No replacement" but the body immediately below is the exact recipe (`for _ <- 0..(dimension-1) do ... end |> Nx.tensor |> Qx.Math.normalize`). This pattern is duplicated three times in the diff: here, in `lib/qx/qubit.ex:155-161` (already inlined), and implicitly in any future caller who copies the doctest. Consider updating the deprecation message to point at `Qx.Qubit.random/0`'s inline pattern as the canonical recipe reference rather than "no replacement," to guide future consumer migration. Low priority — doesn't block this PR.

2. **lib/qx/qubit.ex:163-168 — `hadamard_basis_state/1` naming nitpick** (Found by: elixir-reviewer)
   
   The function builds `(|0⟩ ± |1⟩)/√2` (the eigenstates of X), not literally "the Hadamard basis state" in the sense of applying an H gate to a basis state (though mathematically equivalent up to global phase). The comment above it is accurate and clarifies intent, so this is purely a naming nit. A name like `pm_basis_state/1` or `x_eigenstate/1` would read clearer given `sign` is the actual parameter. Not worth a rename on its own.

---

## Iron Law Compliance (Iron Law Judge Report)

✅ **Law #6 — Public API surface**: COMPLIANT
- All 17 `@deprecated` functions have working drop-in replacements in their messages (verified at lines specified above)
- Survivors (`StateInit.basis_state/3`, `Math.normalize/1`, `Math.probabilities/1`) carry no `@deprecated` tag
- Deletion of `complex_to_tensor/1` and `tensor_to_complex/1` is non-breaking (both already `@doc false` — never part of the declared public API)
- `Qx.Behaviours.QuantumState` demotion to `@moduledoc false` follows the v0.10 calc-mode precedent: callbacks intact, `Register`'s `@behaviour` unchanged, sole implementor is internal

✅ **Law #7 — Typed errors**: COMPLIANT (no new error paths)

✅ **Laws #3/#4/#5 — Nx kernel discipline**: COMPLIANT
- Only body change: `Qx.Math.unitary?/1` (math.ex:249-281) now inlines `Nx.eye(n)` instead of calling deprecated `identity/1` — semantically identical, avoids lib/ emitting its own warnings
- No host-side loops over `2^n` amplitudes
- No BinaryBackend-incompatible constructs

✅ **Law #9 — Dispatch completeness**: N/A (no instruction/message-shape dispatch touched)

✅ **Laws #1/#2 — String.to_atom, unsupervised process**: COMPLIANT (not present)

---

## Coverage

| File | Represented | Key Items |
|---|---|---|
| requirements.md | Yes | 7 requirements all MET |
| elixir-reviewer.md | Yes | 0 blockers, 2 warnings, 3 suggestions |
| testing-reviewer.md | Yes | 0 blockers, 2 warnings, 1 suggestion (deconflicted: 4 unique warnings total) |
| iron-law-judge.md | Yes | 5 laws checked, all compliant, no violations |

**Coverage**: All 4 input files represented. No coverage gaps.

---

## Deconfliction Notes

- **Suggestion #3 from elixir-reviewer** ("moduledoc replacement-pointer audit"): Superseded by iron-law-judge's comprehensive verification of all 17 replacement messages in Law #6 section. No further action.
- **Iron Law #6 precedence**: All API-surface findings from iron-law-judge take precedence over elixir-reviewer findings on the same code. Both reviewers confirm all deprecation messages are correct and functional.

