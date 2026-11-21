# Review: display-tolerance (feat/display-tolerance vs main)

Status: approved with warnings. Read only; nothing was run.

## BLOCKER
None.

## WARNING

1. lib/qx/step.ex:89 (`show/1`) calls `Format.dirac_notation(terms)` with no `:max`.
   A 20-qubit uniform state now has about 1M printable terms (probability 9.5e-7, amplitude 9.8e-4, prints as 0.001). `show/1` therefore builds a one-line string of roughly 25 MB or more. Before the change this case collapsed to `0.000|0…0⟩`, which was the bug. The cost is linear and `show/1` already builds 2^20 `Format.complex` strings in `:amplitudes`, so it is not a new complexity class. It is, however, a new, very large `:state` string. Decide whether `show/1` should cap or elide (`max:` plus " + …"), or accept it and say so in the CHANGELOG or `show/1` docs.

## Verified by reading (no problem)

- **`significant_terms/2` branches** (format.ex:61-70):
  - Printable terms present: `limit/2`, in index order.
  - None printable but some present: `largest/2`.
  - Nothing present (all negligible, or the list is empty): `{Enum.take(terms, 1), false}`.
  - `dirac_notation([])` now returns `""`. Before, `List.first([])` returned nil and the match raised `MatchError`. `Step.show/1` cannot reach it: `basis_terms` always has at least 1 term, since the state size is a power of two and at least 1.
  - A zero vector prints its first term as `0.000|0⟩`, the same as before.
- **`largest/2`**: the `{-probability, index}` sort key is a deterministic tie-break. It re-sorts by index, so the result is in index order. Before, the Step fallback was in probability order, so the order differs but index order is better.
- **`cut?` flag**: it is true iff the non-negligible terms exceed those kept. Terms dropped as unprintable or negligible do not count as cut. That is consistent between the printable and fallback paths.
- **Idempotence of the re-run in step.ex:157** (`dirac_notation(shown)` at precision 3, the same default `significant_terms` was called with):
  - Printable case: every kept term is non-negligible and printable, so all are kept.
  - Fallback case: the kept terms are all non-negligible and non-printable, at most 4 of them. `printable == []`, then `largest(present, :infinity)` takes `@fallback_terms` = 4 and keeps all of them.
  - Zero-vector case: the single kept term is negligible, so `present == []`, and `Enum.take(terms, 1)` returns the same term.
  - It cannot drop a term. This depends on `@max_dirac_terms` being at most `@fallback_terms` (4 and 4). If someone raises `@max_dirac_terms` above 4 the fallback re-run would silently truncate (see Suggestion 1).
- **Step inspect versus before**: for ordinary states it is identical. The first 4 printable terms appear in index order, with " + …" iff more than 4 printable terms exist. Anything that printed before (probability above 1e-6, amplitude above 1e-3) is still printable at precision 3, so no term disappears. The differences are the ones the CHANGELOG states: terms with amplitude from 5e-4 to 1e-3 now count towards the 4-term cap and the "…", and the fallback order changed from probability order to index order.
- **`prints?/2`**:
  - Precision 0: half_unit is 0.5. Fine.
  - Negative precision: half_unit is large. `float_to_binary` would raise in `format_term` anyway, and the option is undocumented.
  - Integer amplitude: `parts/1` handles it, and `abs(int) >= float` is valid.
  - `half_unit` for precision 3 equals the float literal 0.0005, so the boundary is consistent with `float_to_binary` rounding.
- **Callers**: `grep threshold:` in lib/ finds none. register.ex:774 `show_state/1` passes no option. Only the new test passes `threshold:`, intentionally, to assert it is ignored. step.ex and tables.ex hold no private threshold.
- **Host-side cost at 2^20**:
  - `significant_terms` does two O(n) passes (`Enum.reject`, `Enum.filter`).
  - `limit/2` is `Enum.split(max)`, O(max).
  - `largest/2` is O(n log n) once, only in the fallback, plus one O(n) `length`.
  - Nothing is quadratic.
  - In the Inspect path the dominant cost is `basis_terms`, which already existed.

## SUGGESTION

1. lib/qx/format.ex:137-138: `largest/2` caps at `@fallback_terms` independently of the caller's `:max`, and step.ex re-runs `significant_terms` on the result. The idempotence above relies on both constants being 4. Either derive one from the other, or have step.ex render the kept terms without re-filtering. `dirac_notation` could take a pre-filtered list through a private `render/2`.
2. lib/qx/format.ex:232: `abs(im) < @noise_floor_amplitude` (1e-5) is a fixed constant, while `prints?/2` depends on precision. An imaginary part from 1e-5 to 5e-4 on a printing real part renders as `(1.000+0.000i)`. That was already true with the old 1e-6 cut. Tying the suppression to precision would be tidier. The CHANGELOG also does not mention that an imaginary part from 1e-6 to 1e-5 is now dropped.
3. lib/qx/format.ex:236: `:erlang.float_to_binary/2` raises on an integer amplitude (this predates the change), although `parts/1` and `prints?/2` now advertise plain-number support. Use `abs_val * 1.0`, or drop the claim.
4. lib/qx/format.ex:61: `max: 0`, or a negative `:max`, yields `[]` and so `dirac_notation` returns `""`. Edge case only; consider a guard.
5. Missing tests: `dirac_notation([])`, `significant_terms([])`, and a `max` below 4 in the fallback branch.
6. Tests: the "one definition" source-grep test in format_tolerance_test.exs:513 is brittle (regex on source text). It is acceptable as a guard, but note that it would not catch a differently spelled threshold.
