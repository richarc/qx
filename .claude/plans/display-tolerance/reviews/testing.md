# Test Review: display-tolerance (feat/display-tolerance vs main)

Read-only review; nothing was run. Everything below comes from reading the diff, test/qx/format_tolerance_test.exs, lib/qx/format.ex, lib/qx/step.ex, lib/qx/draw/tables.ex and test/qx/step_test.exs.

## Summary
The new tests are sound and mostly mutation-resistant. No BLOCKER. One WARNING (regex narrowness), one WARNING (prints? boundary untested), and a few suggestions. The existing-file edits match the approved decisions, with one cosmetic deviation.

## 1. Existing-file edits vs D1 to D3
- test/qx/format_test.exs: the diff removes exactly one test, "respects custom threshold" (old lines 145-159), and nothing else. Matches D1.
- test/qx/step_test.exs: the hunk (new lines 172-178) changes only the describe title and the comment block. Every assertion (new lines 192-195) is untouched in the diff. Matches D3 on assertions.
- Deviation (SUGGESTION): the `test` name also changed, from "renders the largest terms instead of a misleading 0.000 term" to "renders its terms instead of a misleading 0.000 term" (step_test.exs:173). D3 allowed only describe and comments. Harmless and the old name would now be false, but the owner should know.
- The comment was reworded correctly. The "Dirac strings truncate to the first 4 terms" comment in lib/qx/step.ex is fine.

## 2. "One definition" test (format_tolerance_test.exs:216-225)
The path is right: `Path.expand("../../" <> file, __DIR__)` from test/qx resolves to the repo root. Against the old code it WOULD fail: tables.ex had `prob > 1.0e-10` (matches `prob\w* > 1\.0e-\d+`) and step.ex had `@prob_threshold` and `threshold: 0.0`. So it catches an exact revert. But it is narrow, a literal-text check of three shapes. WARNING.
- Missed: `prob >= 1.0e-10`; `1.0e-6 < prob`; `prob > @eps` or any other attribute name (`@min_prob`, `@noise`); `p > 1.0e-6` or `amp_prob > ...` where the variable does not start with "prob"... (`amp_prob` does not match `prob\w*` as a word start only if preceded differently; `\w*` is after "prob", so `amp_prob > 1.0e-6` does match, but `p`, `pr`, `weight` do not); `> 0.000001`; `abs(amp) > 1.0e-6`; `Enum.filter(... > 1.0e-6)` on a non-"prob" name.
- Too broad: it also fires on comments or docs containing those strings. Neither file has any today (checked by grep: no float literals of that form in lib/qx/step.ex or lib/qx/draw/tables.ex), so no false positive now.
- Suggested fix (WARNING): refute any small float literal, `~r/\d\.\d+e-\d+/`, in those two files, with a message pointing at `Format.negligible?/1`. The grep shows no such literals in either file today. Keep `@prob_threshold` or `threshold:` as extra alternatives. It remains a text check, so a behavioural test is the stronger guard. The "three surfaces agree" tests already give that (see below).
- Related, outside the scope of the test (SUGGESTION): lib/qx/qubit.ex:722 still has `prob > 1.0e-6` in `print_probabilities` (IO output) and lib/qx/register.ex:774 goes through `dirac_notation`. qubit.ex is not scanned by the test, so a different display threshold survives. Confirm this is intentionally out of scope.

## 3. Characterization tests (format_tolerance_test.exs:39-68)
- Circuit inversion is correct on reading: forward layer is ry then rz per qubit, then an ascending cx chain. The inverse is a descending cx chain (cx is self-inverse), then per qubit rz(-b) then ry(-a), layers reversed. Per-layer qubit order does not matter, since the single-qubit gates are independent. For n=2 the ranges `0..0//1` and `0..0//-1` are fine.
- Non-vacuous: a sign error or an ordering error leaves residue of order 0.1 to 1, which fails `< 1.0e-11`. So the test does check that U then U⁻¹ returns to |0..0⟩ and that the simulator's residue is tiny.
- Feasible: float32 eps is 6e-8, so amplitude residue of about 1e-7 gives probability about 1e-14. The 1.0e-11 bound allows amplitudes up to 3e-6, so it is feasible with 3 orders of margin at 100 and 600 gates. I cannot confirm the observed value without running.
- Meaningfulness: weaker than the "14 qubits / 1,740 gates" claim in the source comment. 2 and 6 qubits at 10 layers are a regression canary for the simulator, not evidence for the floor. The comment in the test (lines 34-38) is honest about this. SUGGESTION: say in the test name or comment that the 14-qubit evidence lives in the scratchpad, not here.
- The test pins only the lower bound of the floor (floor >= 1e-11, via `Enum.all?(residue, &Format.negligible?/1)`). The upper bound comes from the 2^-20 test (line 70-72). Together they bracket the constant. Good. Note `Enum.max(residue) < 1.0e-11` is stronger than the `negligible?` assertion that follows it, which is implied, so the second assert is redundant (harmless; it is the link to the function under test).
- Minor: the `for ... do test "..."` with `unquote` creates tests with identical-looking names that differ by number. OK.

## 4. `term/3` fixtures
Probability re^2 + im^2, checked against what each test claims:
- 1.0e-7 -> 1e-14, negligible (lines 93, 138). Correct.
- 4.0e-4 -> 1.6e-7. Amplitude below the half unit 5e-4, so it does not print at precision 3 (lines 98, 117). Correct.
- 6.0e-4 -> 3.6e-7 (comment at 205 says 3.6e-7). Correct.
- (4.0e-4, 4.0e-4) -> 3.2e-7; |amp| 5.66e-4, comment "5.7e-4". Correct.
- 9.0e-4 -> 8.1e-7. Matches the comment at 124. Correct. In `step/1` the probability comes from `Qx.Math.probabilities`, not `term/3`, and c64 holds these values fine.
- `step/1` states in lines 192 and 207 are unnormalized (norm 1 + 1e-14 and 1 + 3.6e-7; the second two-amplitude state is 1-qubit). Assuming `Step.show`, `inspect` and `draw_state` do not validate normalization (not verified by running), this is fine. If any of them validated, the failure would be loud, not silent.
No fixture disagrees with its claim.

## 5. Boundary coverage
- `negligible?/1` at exactly 1.0e-10: `assert Format.negligible?(1.0e-10)` (line 80) with `refute 1.1e-10` (line 84). `<=` to `<` is caught. Good.
- `prints?` at exactly half a unit: NOT tested. Tests use 4.0e-4 (line 98, 112, 117) and 6.0e-4 (line 103, 108); 5.0e-4 appears only at line 172, in a `dirac_notation` call whose first term (re = 1.0) prints anyway, so `prints?` is not exercised there. A mutation `>=` to `>` in `prints?` (format.ex:122) survives. WARNING (low-moderate): add `term("|1⟩", 5.0e-4)` to `significant_terms` and assert it is kept (the double 5.0e-4 equals `0.5 * :math.pow(10, -3)`; `float_to_binary(5.0e-4, decimals: 3)` should round up to "0.001" since the double is just above 5e-4, but that is the one thing worth verifying by running). Also a `precision: 0` or large precision case is untested; not needed.
- `format_term` real/complex switch at 1.0e-5: tested at 5.0e-6 (below) and 5.0e-4 (above), not at the exact value. SUGGESTION only.
- The "a real imaginary part is printed" test (line 172) depends on the formatting of an amplitude at exactly the half unit; `complex/2` formatting is not read here. It could be fragile to a future rounding change. SUGGESTION: use 6.0e-4 there.

## 6. "has no :threshold option" (line 175-178)
It would fail on revert: with `threshold: 0.01` the old code dropped |1⟩ (probability 0.002), so the two calls would differ. As a pin of removal it is acceptable, since `Keyword.get` ignores unknown keys anyway and an absence cannot be asserted directly. Two weaknesses (SUGGESTION): it compares two calls, so it passes if both are wrong; and a re-added option with a different default would pass. Assert the literal result as well: `== "0.999|0⟩ + 0.045|1⟩"`. 0.045 prints as 0.045, so both terms stay.

## 7. Coverage lost with the Step top-k fallback
- The fallback logic moved to `Format.significant_terms/2` (`largest/2`), covered at format_tolerance_test.exs:131-143 (max infinity, 5 present, 4 kept, cut flag true, index order).
- Not covered: the `min(max, @fallback_terms)` branch of `largest/2` (format.ex:138) with an explicit `:max` below or above 4 and all terms below the print level. Step passes `max: 4`, so this is the real Step path, and it has no test. WARNING-level only if you want mutation parity; SUGGESTION in practice: call `significant_terms(terms, max: 2)` on the all-zero-print list and assert 2 kept, true.
- Not covered: Step's `" + …"` suffix when `cut?` comes from the fallback branch; step_test.exs:150-169 covers it only for the `limit` path (8 equal terms).
- `dirac_notation` of an all-negligible or zero vector: the old "0.000#{basis}" branch is gone; the first term is now printed via `format_term`, giving the same "0.000|0⟩". No `dirac_notation`-level test pins this (only `significant_terms` returns the first term). SUGGESTION: add `assert Format.dirac_notation([term("|0⟩", 0.0)]) == "0.000|0⟩"`.
- The `{[], _}` edge: `dirac_notation([])` would now return "" instead of raising on `List.first(nil)`; unreachable and untested.
- Reachability note: below 20 qubits (2^-20 amplitude 9.8e-4 prints as 0.001), the "every term prints as zero" fallback is reachable only for a zero vector. Its tests are therefore synthetic, which is fine.

## Iron Laws
- Async: `async: true` with pure functions only. OK.
- No Process.sleep, no Mox. OK.

## Findings by rank
BLOCKER: none.
WARNING:
- format_tolerance_test.exs:221, regex too narrow (see 2).
- format_tolerance_test.exs:98-121 / format.ex:122, the `>=` at exactly 5.0e-4 is unpinned (see 5).
SUGGESTION:
- step_test.exs:173 test name was changed (not approved scope; harmless).
- format_tolerance_test.exs:175-178, add the literal expected string.
- format_tolerance_test.exs:172, use 6.0e-4 to avoid dependence on exact-half rounding.
- Add a `max:` below 4 with fallback test, and a `dirac_notation` zero-vector test.
- lib/qx/qubit.ex:722 still has `prob > 1.0e-6`; confirm out of scope.
