# Test Review: test/qx/host_side_state_lists_test.exs

Read-only review. I read the test file, the diff, progress.md, the three related test files and draw_size_cap_test.exs. I ran nothing. "Inferred" means reasoned from the code and the measurements in progress.md, not executed.

## Summary
The heap-limit tests would catch a reintroduced host-side list. The limit is 131,072 words. progress.md measured 1,598 words for the fix and kill points of 22.8M and 41.5M words for the old code, so the margin on both sides is large (inferred from those numbers). I found no BLOCKER.

## Iron Law notes
- No Mox, Ecto or Process.sleep. `async: false` is justified only by a wrong reason (see S1).

## Findings

### BLOCKER
None.

### WARNING
- W1 test/qx/host_side_state_lists_test.exs:121-128, "later key in map order wins". This pins behaviour that is undefined and cannot be reached through the public API.
  - Nx documents duplicate indices in `indexed_put` as unspecified. EXLA and other backends may differ. The test passes only because BinaryBackend happens to apply updates in order.
  - It also depends on map iteration order. Maps with 32 keys or fewer iterate in sorted key order, so "01" comes before "1". That holds today but is an implementation detail.
  - Real counts keys are fixed-width, so two keys never parse to the same index.
  - Suggested fix: delete the test, or rewrite it to assert only that the result is one of the two valid values. (Verified by reading the code and diff; the Nx semantics are from memory.)
- W2 Doctest directive (item 5). `lib/qx/gates.ex` has 20 `iex>` lines, for example around line 329, and the diff touches it. I found no `doctest Qx.Gates` anywhere under test/ (grep on `doctest\s+(Gates|Qx\.Gates)` returned nothing). Those examples are never run. This is an existing gap, but it breaks the project rule for a touched module.
  - `doctest Qx.StateInit` is at state_init_test.exs:3.
  - `doctest Qx.Validation` is at validation_test.exs:3.
  - `doctest Qx.QuantumCircuit` is at quantum_circuit_state_test.exs:6.
  - `Qx.ResultBuilder` has 0 `iex>` lines, so it needs no directive.
  - Verified by grep.

### Suggestions
- S1 :2-3 The comment says `async: false` is needed so the heap tests do not share scheduler time. `max_heap_size` counts the process's own words, not wall-clock time, so scheduler contention cannot change the outcome. draw_size_cap_test.exs (the sibling using the same pattern) runs `async: true`. `async: false` is harmless but the stated reason is wrong. Either change it to `async: true` or correct the comment. Inferred.
- S2 :25-54 Spurious-failure review of the harness:
  - Cold-VM module loading: loaded code lives in the code server and the literal area, not the caller's heap, and progress.md measured on a cold VM. No risk.
  - The `{:outcome, pid, {:returned, tensor}}` message: the Nx tensor struct is small. The 8 MB (c64) and 4 MB (f32) data are off-heap refc binaries, which are not copied by `send`. Message copying is not an issue.
  - GC timing: `max_heap_size` is checked at GC and at allocation, so a 2^20 list (2M+ words) is killed deterministically.
  - Async interference: heap limits are per process, so there is none.
  - One residual weakness: `spawn_monitor` runs the `try` without `catch`, so an `exit` or `throw` would arrive as a `:DOWN` reason. The `receive` handles that and returns the reason, so the failure message is still readable.
  - There is no timeout on `receive`. A hang would be reported only by ExUnit's 60 s test timeout. Add `after 30_000 -> flunk(...)` if you want a clearer failure.
- S3 :148-151 Control validity. It is valid for the harness: it shows `:killed` is returned when a 2^20-element list is built (about 2M words, 16x the limit). It is weaker than the real regressions, which are killed at 22M or 41M words. The control does not exercise Nx. If you want it stronger, use `Nx.tensor(List.duplicate(0.0, @dimension))`. progress.md already holds the evidence from the old code, so this is optional.
- S4 :132-146 Heap tests assert only shape. If someone replaced the fix with a broken tensor of the right shape, the small value tests (:69-77, :100-105) would catch it only at size 4 or 8. Add one cheap check at 2^20, for example `Nx.to_number(Nx.sum(state))` or `state[0]` for basis_state, and `probabilities[@dimension - 1] == 1.0` for from_counts. This also covers a large and boundary index, which the suite currently pins nowhere (state_init_test uses a dimension of 8 or less). from_counts at :139 does use the last index, but never checks its value. The state array's 2^20 shape is not asserted for `result.state`.
- S5 :64-67 The c128 test checks type only. The c128 value path (`Nx.tensor([1], type: :c128)`) has no value assertion. Add `Nx.to_flat_list(StateInit.basis_state(1, 4, :c128))` and compare it to the expected Complex values.
- S6 :108-113 Empty counts covers the `[]` branch of `build_probability_tensor`. The other route into that branch is non-empty counts where all indices are >= 2^n, and it is not tested. The :115 test has one in-range key, so it never reaches `[]`. Add a case such as `%{"111" => 1}` with 2 bits.
- S7 Integer.pow sites (gates.ex swap, iswap, cswap, toffoli, controlled_gate; quantum_circuit.ex; state_init.ex) have no test aimed at the change. I judge that acceptable, because existing tests (swap_gate_test, iswap_gate_test, cswap_gate_test, controlled_gates_test, cswap_iswap_matrix_test) exercise those functions with integer qubit counts and the CHANGELOG says "values identical". Two untested behaviour edges:
  - A non-integer `num_qubits` now raises (`Integer.pow`, and `bsl` in `valid_register?`). `trunc(:math.pow(...))` accepted floats.
  - A negative `num_qubits` in the Gates functions raises `ArithmeticError`. Before the change it gave a 0-sized broadcast.
  - Neither is reachable through the validated public API. Only the negative `valid_register?` case is pinned (:154-159). I did not check whether the toffoli and set_state/reset tests exist by name (count-level grep only), so treat this as inferred.
- S8 :154-159 The `valid_register?` test uses `Nx.tensor([1.0, 0.0], type: :c64)`, size 2. With `bsl(1, -1) == 0` the sizes differ, so it returns false. It would also return false under the old code if `:math.pow(2, -1)` truncated to 0, but the old code did not raise there. Whether it fails on a regression to `Integer.pow` (which raises `ArithmeticError`) is inferred, not run. The test is meaningful.

## Tautology, ordering and float-equality check
- Float `==` comparisons (:89, :105, :112, :118, :127) use values exactly representable in f32 (0.25, 0.5, 0.75, 0.0, 1.0). They are not fragile.
- `Nx.to_flat_list` returns Complex structs. Comparing with `==` at :75 relies on the 1.0/0.0 fields. A `-0.0` would still compare equal under `==`. Fine.
- :132-137 and :139-146 are not tautological, because the `{:returned, _}` pattern fails if the process is killed.
- The only order dependence is the map-order test at :121 (W1).
