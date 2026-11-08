# Iron Law Judge: feat/vectorise-measurement (project AGENTS.md laws #1-#9)

Note: no Bash access, so I read the files directly rather than running `git diff`. Test and bench files were only grepped (tolerances, ticket tags), not read in full.

## Summary
- Violations: 0 critical, 0 high, 0 medium
- Advisory notes: 3 (all LOW or INFO)

## Judgement calls

### #5 host loops over 2^n: NOT a violation (accepted single sync)
- `Sampler.cumulative/1` (`lib/qx/simulation/sampler.ex:27-32`): the cumulative sum runs in Nx (`defnp cumulative_f64`, `Nx.cumulative_sum`). Then one `Nx.to_flat_list |> List.to_tuple` conversion moves it to the host.
- That conversion is a single sync and a data transfer. There is no per-amplitude host arithmetic, which is what #5 forbids.
- The per-shot binary search is O(n) per shot (n = qubits), not O(2^n). Total work is O(2^n + shots*n), down from O(shots * 2^n).
- LOW/INFO: the 2^n host tuple is memory-bound at large n. If a future change exposes large n, consider sampling on-device with a `searchsorted`-style kernel. No action needed now.

### #6 public API: no violation
- `Qx.Calc`, `Qx.CalcFast` and `Qx.Simulation.Sampler` are tier 3 (the Calc modules were demoted in v0.10 and `Sampler` is `@moduledoc false`).
- In `Qx.Simulation` (tier 2), only private functions changed: `perform_measurements`, `perform_single_measurement` and `extract_classical_bits`.
- `Calc.qubit_probabilities/3` and `Calc.collapse/5` keep their signatures and return shapes.
- The CHANGELOG has Performance and Fixed entries, and `mix.exs` stays at 0.11.0, which is correct for a non-breaking change.
- INFO: the sampler's behaviour change is that a draw above the cumulative total is clamped to the last non-zero outcome, where it previously fell back to a different outcome. This is a bug fix to output distribution, not an API break. The CHANGELOG "Fixed" entry covers it.

### #7 raw ArgumentError reaching Qx.run/Qx.steps: not reachable
- `CalcFast` raises `ArgumentError` from `validate_qubits!`, `validate_2x2!` and `collapse/5` (value not 0 or 1), at `calc_fast.ex:248` and `:394-418`.
- `Simulation` calls `Calc.qubit_probabilities` and `Calc.collapse` (`simulation.ex:718,726`) with the qubit and `num_qubits` taken from circuit measurements. The measured value is always the literal 0 or 1.
- The circuit builder validates qubit indices with typed `Qx.QubitIndexError` before they reach this path, so these `ArgumentError`s are defense-in-depth for the tier-3 internal API only.
- LOW/REVIEW: I did not trace the builder validation line by line. Confirm that `Operations.measure` and `c_if` validate the qubit range before `run/2`. A test that does `run/2` on a hand-built `%QuantumCircuit{}` with an out-of-range measurement would show whether an `ArgumentError` can escape. If it can, that path is pre-existing.

## Other laws
- #1 atoms: no `String.to_atom`, `Module.concat` or similar in the new code.
- #2 processes: none added. `Sampler` is a pure module and uses `:rand` in the caller's process.
- #3 and #4: `CalcFast` uses slicing and reshape kernels. I found no `Nx.take`, `Nx.select` or gather in the changed kernels.
- #8: the new test tolerances are feasible. `1.0e-12` is in `simulation_sampler_test.exs:77`; it compares exactly representable f64 cumulative sums, so it is not subject to c64 ε.
- #9: no dispatch arms were added or changed.
- Ticket tags and comment narration (#19 in the plugin list): none found by grep.

## Pre-existing
- Nothing noted beyond what is above.
