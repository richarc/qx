# Test Review: calc_fast_slicing_test.exs, simulation_slicing_kernels_test.exs

## Summary
Strong, well-structured tests. Both files are async-safe (pure, no global state, no Application env, no Mox, no sleeps). Tolerance 1e-6 respects Iron Law #8. The oracle is independent of the kernel: `embed/3` uses bit arithmetic, and the Qx.Gates builders add a second cross-check. Seeds are fixed, so the random states are deterministic. Runtime was not measured (no Bash). The cost is dominated by `embed/3`, which builds 2^n x 2^n matrices from Elixir lists, with n=5 meaning 1024 entries per embed. That is only a few hundred cases in total, so expect low seconds. Worth confirming with `mix test --slowest 5`.

## Iron Law Violations
None.

## BLOCKER
None.

## WARNING
- [ ] calc_fast_slicing_test.exs: there is no test for `apply_single_qubit_gate/4` invalid input. The impl documents `ArgumentError` for an out-of-range target, a wrong state length and a non-2x2 gate (`validate_2x2!`). Add `assert_raise ArgumentError` cases for target >= n, a negative target, a 4x4 gate and a bad `num_qubits` (0, non-integer).
- [ ] calc_fast_slicing_test.exs: the `apply_single_qubit_gate(state, gate, _, 1)` special clause (calc_fast.ex:62) is never exercised. The single-qubit tests use n = 3, 4 and 5 only. Add an n = 1 case against the oracle.
- [ ] calc_fast_slicing_test.exs:321-358: every `assert_raise` omits a message match. Either of two wrong failures would still pass: the wrong validation branch firing (for example "distinct" instead of "out of range"), or an incidental ArgumentError from Nx (for example a shape mismatch in the broken-state-length case). Add a regex message, for example `assert_raise ArgumentError, ~r/distinct/, ...`. The cases to pin are the state length mismatch, the non-integer index (1.0) and the out-of-range index.
- [ ] simulation_slicing_kernels_test.exs:187-190: the Simulation static guard is brittle. The regex catches only a literal `Gates.name(` call. It misses an aliased module (`Qx.Gates.`, which would still match, but `import Gates` or `&Gates.swap/3` would not), and it would also flag a legitimate future use in a doc or string. A matching `Nx.take` or `Nx.select` could also slip in through a pipe (`|> Nx.take(`), but that case is already covered by the plain substring. Treat the guard as a tripwire only. The behavioural tests are the real protection.

## SUGGESTION
- [ ] simulation_slicing_kernels_test.exs:171-191: the stripped-comment guard only removes lines that start with `#`. Trailing comments and `@doc` heredocs that mention `Nx.take` or `Nx.select` would false-positive. calc_fast.ex has moduledoc text about the old kernels in its docs, so this is a latent hazard (this module's current docs do not trip it, but the guard is fragile to doc edits). Consider scoping the check to `Code.string_to_quoted` plus an AST walk (a remote call to `Nx.take` or `Nx.select`), which is robust to comments and docs.
- [ ] simulation_slicing_kernels_test.exs:171: `defp code_lines` is defined inside a `describe` block. This works in ExUnit but is unusual, so move it to module level.
- [ ] simulation_slicing_kernels_test.exs: `Qx.get_state` and `Qx.steps` are exercised, but there is no isolated per-kind execution test. Each routed kind (cp, cy, cz, crx, cry, crz, swap, iswap) appears only inside the `@mixed` and QFT circuits. Coverage of every kind is satisfied (all 8 are in `@mixed`; cz, cy, crx and crz appear only there). A failure in `@mixed` will not pinpoint which kind broke. Consider a small `for` loop of single-kind circuits, each after an H layer, so failures are attributable.
- [ ] simulation_slicing_kernels_test.exs: the run/2 path (shots and measurement) is not exercised for the new kinds. `steps/2` and `get_state/1` are covered. If `run/2` shares the same dispatch (likely), this is optional.
- [ ] calc_fast_slicing_test.exs:181,195: the seed formulas collide across n (the n=3 and n=5 cases for the same c and t share a seed), and some pairs also collide between different formulas. This is harmless because the sizes differ, but `{n, qubits}` hashed with `:erlang.phash2` would be cleaner.
- [ ] calc_fast_slicing_test.exs:239-252: n = 2 is tested only for the controlled gate. CX, SWAP and iSWAP at n = 2 are not tested. n = 2 is a degenerate axis layout (no spectators), so add `pair_cases` entries for n = 2.
- [ ] calc_fast_slicing_test.exs:106: the `Δ` and `≥` unicode in failure messages is fine, but the oracle only reports the max error and not the location. This is acceptable.
- [ ] The oracle is partly shared. `embed(controlled(u))` and the kernel both assume control = MSB of the gate, and the Gates.controlled_gate cross-check independently confirms this. This is good. Note that the Toffoli oracle is permutation-based in both files, with no legacy cross-check (documented as dead code), so the CCX oracles are test-local only, which is acceptable.
- [ ] Doctests: the project rule needs `doctest Qx.CalcFast` if calc_fast.ex has `iex>` examples. Neither new file has a doctest directive. The existing calc_fast_test.exs may already declare it. Verify with `grep -n doctest test/qx/calc_fast_test.exs`. I did not check.

## Pre-existing
(none observed in the new files)
