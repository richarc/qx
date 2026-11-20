# Test review of fix commit f0c1dec (tests only)

All findings are by reading; nothing was run. "Verified" means checked against the source or the error message text.

## T1 to T5 status

| # | Status | Notes |
|---|--------|-------|
| T1 | Fixed | `circuit_style_test.exs:~728-732` sets `num_qubits: 21` on a 1-qubit struct, so `Qx.create_circuit(21)` no longer raises inside the closure. The guard is `lib/qx/draw/svg/circuit.ex:149` and its message is "Invalid qubit count: 21 (must be between 1 and 20)" (verified, errors.ex:535), so `~r/21/` is meaningful. Would fail if the guard were removed. |
| T2 | Fixed for the connector, not for the tip test | `circuit_test.exs:112` now `== base_y + 1.0` and `< tip_y`. The offsets are still asserted to be exactly `[-1.5, 1.5]`, so the list cannot be empty. The tip test at `circuit_test.exs:28-52` (the review named lines 26-50) is untouched: it still compares the tip against the lower register line. See W3. |
| T3 | Mostly fixed | New loop at `circuit_style_test.exs:~750` runs over `GateCatalogue.circuits()` in mono. See W1 and S1. |
| T4 | Fixed | Every listed branch has a test. See the notes below. |
| T5 | Fixed | The table has 28 rows and 24 distinct atoms (counted from `lowering.ex:12-42`, verified). The path comes from `__DIR__` and `@external_resource` is set. The regex tolerates whitespace. A new `stale/0` check was added. |

T4 details:
- The nested `c_if` and the measurement in a block raise `Qx.ConditionalError`.
- `c_if` with a bad bit, `:measure` with a bad bit, and `:measure` with a bad qubit are each tested.
- The one-qubit aria label is tested.
- `cx`, `ccx` and `iswap` with qubits in reverse order are tested.
- The Bloch tests cover the above-1 amplitude, the `2.00` readout, global phase and size 240.
- The `Qx.StateShapeError` message `~r/expected 2, got 4/` matches `errors.ex:306` (verified).

## Pre-existing files: intent kept

- `circuit_test.exs`, `iswap_svg_test.exs`, `u_svg_test.exs`: the `labels` refactor to `Qx.Test.SVGText.labels/1` uses a byte-identical regex and strip (verified from the diff). The assertions are unchanged. No test got weaker.
- `circuit_test.exs` connector test: strictly stronger.
- `chart_style_test.exs` "counts order": the `Enum.shuffle |> Map.new` was a no-op, because a map has no insertion order. Replacing it with `refute Map.keys(counts) == Enum.sort(...)` is an honest precondition and is an improvement (see S5).

## BLOCKER

None.

## WARNING

- W1 `circuit_style_test.exs:~750`: the T3 loop allows `@ink2`, `@muted`, `@paper` and `"none"`. The review's evidence was that those gates use only ink, paper and none. A mono gate that leaked Ink 2 or Muted would pass. Either narrow the allowed set for gate elements, or assert the exact set per gate family. No guard checks that `GateCatalogue.circuits()` is non-empty, so a broken catalogue would pass vacuously. Add `assert circuits != []`.
- W2 `bloch_style_test.exs` (global phase test, `assert part(svg(phased), "vector") == part(svg(general()), "vector")`): the tensors are c64 (float32). Two differently rounded float32 inputs are compared by exact string equality of coordinates printed to 2 decimals. It is deterministic, but it breaks if a value lands on a rounding boundary after any change to the geometry. Prefer parsed numbers with `assert_in_delta`. I did not check that `general()` is θ=0.65π, φ=0.45π; if it is not, the test fails rather than passes falsely.
- W3 `circuit_test.exs:50`: T2 also said the tip test is now weaker (compares to the lower register line only). The fix did not touch it, so that part of T2 is open.
- W4 `bloch_style_test.exs` scaling test at size 240, `assert_in_delta small, 0.8 * normal, 0.0051`: widths are printed to 2 decimals. If a base width has more than 2 significant decimals, the worst-case rounding error is about 0.009, which exceeds 0.0051. It is fine for widths like 1, 1.5 or 0.75, so this is latent brittleness.
- W5 `bloch_style_test.exs` (test "an amplitude a rounding step above 1..."): the production clamp was removed by the atan2 change, so the test no longer covers the "acos clamp" T4 named. It is still a good regression test of the behaviour (θ = 0, exact `{0.0, 0.0, 1.0, 0.0}`). Rename it if the clamp no longer exists.
- W6 `bloch_style_test.exs:~686` and `chart_style_test.exs:~856`: the literal `[1, 2]` is not passed through `untyped/1`, while the `"Zero"` and `"Bell"` cases are. The type checker may warn on the unhidden calls, which is inconsistent. Not verified, because compiling was not possible.

## SUGGESTION

- S1 Add a pole-near-zero test for the `@pole_epsilon` boundary (for example sinθ just above 1e-5). Both noisy-pole tests sit far inside the new threshold, so the boundary is unpinned. The tests do fail if the fix is reverted: `acos(0.99999994)` gives θ≈7e-4 and sinθ above the old epsilon of 1e-6 (verified by arithmetic).
- S2 `untyped/1` is acceptable as a way to hide types. It is duplicated in two files and should move to `test/support`. `apply(Qx.Draw, :bloch, [state, "Zero"])` is simpler and hides the types as well. The `term_to_binary` round trip is unusual but harmless for strings and atoms.
- S3 `markup_test.exs`: no cases for U+FFFE/U+FFFF, lone surrogates, or DEL (0x7F, allowed by the regex). The new `pi_fraction(abs > 7)` branch has no direct `Markup.angle(1.0e300)` test (only the integer-angle `GateError` path is tested). The empty-counts default title "No Measurements" is not asserted; only the custom title is.
- S4 The malformed-instruction list (`circuit_style_test.exs:~915-930`) asserts `Qx.GateError` with no message. All the gates in it are known gates, so each raise must come from the shape check, and a revert would produce a `FunctionClauseError` (verified by reading the guards). Acceptable. A `~r/Malformed/` on the shape cases would pin it.
- S5 `circuit_style_test.exs` reverse-order tests hardcode pixel coordinates ("26", "74", "122"). This matches the existing style and is only brittle to a geometry change. `chart_style_test.exs` `refute Map.keys == Enum.sort` relies on the BEAM's >32-key map ordering, which is an implementation detail but stable.
- S6 `defp hand_built` is declared inside a `describe` block (`circuit_style_test.exs:~905`). It works, since defp is module-level, but it should move up with the other helpers.
- S7 `GateCatalogue.stale/0` checks the function name at any arity, so it does not detect an arity change. Fine for its purpose.
- S8 `qasm_atoms` (via `qasm_table`) still reads the source by regex. The exact `== 28` / `== 24` makes a format change fail loudly, which is the intended fix. The magic numbers need updating when the table changes, and the comment says so.

## Would revert pass?

- T1 revert: the test would fail on the wrong error, or on the old double-raise. Correct.
- Empty-counts title, unknown option, empty barrier, `size: 10_001`, mono-catalogue colours, and the noisy-pole tests: each depends on a changed behaviour, so they would fail if the fix were reverted (read, not run).
- No test passes for the wrong reason that I could find, apart from W1's permissive palette.
