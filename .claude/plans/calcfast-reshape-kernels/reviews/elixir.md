# Elixir Review: feat/calcfast-reshape-kernels

Status: Approved with warnings. No BLOCKERs.

## WARNING

1. lib/qx/calc_fast.ex:62-65 - the `num_qubits == 1` clause of `apply_single_qubit_gate` skips `validate_qubits!`.
   - `target_qubit` is ignored, so `apply_single_qubit_gate(s, g, 5, 1)` silently succeeds.
   - The gate shape is not checked, and the state length is not validated.
   - The docs promise ArgumentError for an out-of-range target, and the "only the top-left 2x2 is read" note is false on this path (`Nx.dot` uses the whole matrix).
   - Fix: run `validate_qubits!([target_qubit], 1)` (and `validate_2x2!`) in this clause too. Better, drop the special case if the kernel handles n=1. `Tuple.duplicate(2, 1)` gives `{2}`, which should work.
2. lib/qx/calc_fast.ex:62-75 - `apply_single_qubit_gate` does not call `validate_2x2!` on the n>1 path, but `apply_controlled_gate` does.
   - A 4x4 gate is silently truncated to its top-left block. The moduledoc/doc says "only top-left read", so this is documented but inconsistent.
3. bench/kernels_bench.exs:9-13 and :25-37 - stale after this branch.
   - The header says "once those gates are routed through the contraction kernel".
   - The `matrix?` flag and the `QX_BENCH_MAX_MATRIX_N` cap are now obsolete, because CP/CRY/SWAP/iSWAP no longer build a 2^n x 2^n matrix.
   - The cap needlessly limits the benchmark to n<=10 for the gates this branch exists to speed up. Remove the cap and the header text.

## SUGGESTION

1. lib/qx/calc_fast.ex:208-245 - the defnp -> deftransformp -> defp-closure pattern is sound under both Nx.Defn.Evaluator and EXLA.
   - The closures run entirely at trace time on Expr tensors, and `opts` lists are static compile-time data.
   - I did not run it under EXLA (UNVERIFIED), because EXLA is not a dependency.
   - `gate[0][0]` on an Expr goes through Access and is fine.
   - Consider a short test that calls the kernels inside `Nx.Defn.jit/2` with `compiler: Nx.Defn.Evaluator`. This guards against regressions if someone passes a tensor as a "static" qubit.
2. lib/qx/calc_fast.ex:293 - `Complex.new(0.0, 1.0)` is fine, but `Nx.tensor(Complex.new(0, 1), type: Nx.type(tensor))` would pin the dtype if a c128 state is ever used.
   - Today the dtype follows Nx type merging, so it is correct.
3. lib/qx/calc_fast.ex:308-327 - the validation logic is correct. It checks range, integer type, and distinctness, and the fallback clause covers a bad `num_qubits`.
   - With `num_qubits == 1` and two qubits, the error reads "out of range" rather than a clearer message. This is minor.
   - The `Enum.find` predicate `not (is_integer and ...)` is a little dense. A small `valid_qubit?/2` helper would read better.
4. lib/qx/simulation.ex:550-598 - the dispatch is complete.
   - `cx`, `cz`, `swap`, `iswap`, `measure`, and `cp/cy/crx/cry/crz` all have arms. Anything else raises `Qx.GateError`.
   - `hd(params)` crashes with ArgumentError if params is empty. This is pre-existing style and callers presumably validate.
   - The `case` inside `apply_controlled_target_op` is fine.
5. lib/qx/calc.ex:105-157 - the delegators and specs match CalcFast, with no drift.
   - The `apply_cswap` and `apply_controlled_gate` specs are accurate.
   - The Calc docs do not mention that ArgumentError is raised, which is minor.
6. mix.exs:148-162 - `Mix.Task.rerun("run", [...])` is correct. `rerun` re-enables the task, so each suite runs.
   - The alias ignores `args`. Naming the parameter `_args` is fine.
   - `@bench_suites` is defined after `aliases/0` but is only used in `run_benches`, which is OK.
   - Consider moving the module attribute above its first use for readability.
7. lib/qx/calc_fast.ex:280-286 - `swap_axes` uses pinned patterns in an anonymous multi-clause fn. This is idiomatic and correct (a != b is guaranteed by the validation).

## Pre-existing

- lib/qx/simulation.ex:502 - the credo CyclomaticComplexity disable is retained.
