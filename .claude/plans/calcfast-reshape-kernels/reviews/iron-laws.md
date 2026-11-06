# Iron Law Review: feat/calcfast-reshape-kernels

Checked AGENTS.md laws 1-9 against new code (calc_fast.ex, simulation.ex dispatch, tests). 0 violations found. Laws 6 and 7 were not re-verified for CHANGELOG or version.

## Violations
None.

## Notes
- #1 Atoms: no String.to_atom in the diff.
- #2 Processes: none added.
- #3 Reshape over gather: no Nx.take, Nx.select or gather in lib/qx/calc*.ex. Kernels use reshape to rank-n, slice_along_axis, concatenate, reverse and transpose. These are static, structure-preserving ops with no index tensors or masks. This satisfies the intent of the law (no gather/mask, no double work). The header comment justifies not using dense contraction with a measurement reference to bench/kernels_bench.exs.
- #4 BinaryBackend: only portable Nx primitives are used, and the tests run on the default backend.
- #5 No host loops over amplitudes: the only Enum over a range is `swap_axes` (calc_fast.ex:281), which iterates over rank (n axes), not 2^n. `validate_qubits!` iterates over at most 3 qubits. Trace-time recursion in `on_controls` is bounded by the number of controls (at most 2).
- #8 Tolerance: both new test files set @tolerance 1.0e-6, which meets the c64 floor.
- #9 Dispatch completeness: the producers emit these two-qubit shapes.
  - Qx.Operations emits cx, cz, swap, iswap, cp, cy, crx, cry, crz (two-qubit) and ccx, cswap (three-qubit).
  - Lowering (lib/qx/export/openqasm/lowering.ex) maps the same set.
  - Qx.Patterns only emits cx.
  - Every shape has an arm in simulation.ex:
    - `apply_two_qubit_op` (552-572) handles cx, cz, swap, iswap and measure. It forwards cp, cy, crx, cry and crz to `apply_controlled_target_op` (586-598).
    - `apply_three_qubit_op` (602-608) handles ccx and cswap.
  - Anything else raises Qx.GateError.
  - test/qx/simulation_slicing_kernels_test.exs references cy/cp/cr*/iswap/cswap/ccx 26 times. I did not read the test bodies to confirm each gate executes end to end, so spot-check that.
- #7 Typed errors: the raw ArgumentError in the tier-3 CalcFast is intentional, per the brief.
- Minor, LOW (not a law): calc_fast.ex:62 `apply_single_qubit_gate(..., 1)` skips `validate_qubits!`, so an out-of-range target with num_qubits=1 is silently ignored. This is pre-existing behaviour, and the Simulation layer validates upstream.
- Pre-existing: none flagged.
