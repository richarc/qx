# Iron Law Review: host-side-state-lists

Checked 9 project laws (AGENTS.md "IRON LAWS"): 0 violations introduced by the diff. 2 low-severity behaviour notes (Law 6/7 edges). Pre-existing items listed separately. Web/Phoenix laws ignored.

## Per-law verdicts

1. Atoms: DOES NOT APPLY (no atom creation in diff).
2. Processes: DOES NOT APPLY.
3. Nx gather vs reshape: DOES NOT APPLY. The law targets `defn` kernels in `lib/qx/calc*.ex`. The changed functions (`state_init.ex:73-80`, `result_builder.ex:48-70`) are plain host functions, not `defn`. `Nx.indexed_put` here is a scatter of a constant index onto a zero tensor, not the gather/mask pattern. No change to `calc*.ex`.
4. BinaryBackend correctness: APPLIES, COMPLIANT. `Nx.indexed_put` has a BinaryBackend implementation (`deps/nx/lib/nx/binary_backend.ex:1721-1726`, `indexed_op` at 1728). Duplicate indices resolve via `Enum.at(upds, -1)`, so the "later wins" comment at `result_builder.ex:44-47` matches the code. Nothing EXLA-only.
5. No host-side loops over 2^n: APPLIES, COMPLIANT.
   - `basis_state/3` (`state_init.ex:77-79`): `Nx.tensor(0)` -> `Nx.broadcast({dimension})` -> `Nx.indexed_put` with one index. No list or loop; host work is O(1).
   - `build_probability_tensor/2` (`result_builder.ex:48-70`): `Nx.broadcast` of zeros, then `Enum.filter`, `Enum.unzip` and `Nx.tensor(Enum.map(indices, ...))`. Host work is O(k), where k is the number of distinct outcomes (at most min(shots, 2^n)), not O(2^n). Acceptable.
   - BinaryBackend `indexed_op` groups and sorts k offsets, then slices the target binary. That is O(k) host work plus one O(2^n) binary copy. It is not a host loop over amplitudes, and a dense 2^n buffer is unavoidable on BinaryBackend.
   - Remaining O(shots) work is `from_counts` `classical_bits` (`result_builder.ex:26-29`, `List.duplicate` per shot). It is proportional to shots, not 2^n, and not in this diff.
6. Public API breaking changes: APPLIES to `Qx.StateInit.basis_state/3` (tier 2) and, via `valid_register?/2` (`validation.ex:65`) and the `Qx.Gates` `Integer.pow` changes, to a few edge inputs. No breaking change for valid inputs, so COMPLIANT.
   - `basis_state/3` with c64/c128: same values, same shape and type. Real and integer types change from crash to success, which is non-breaking. The CHANGELOG "Fixed" entry (lines 26-29) is accurate.
   - `build_probability_tensor` is internal (`@moduledoc false`). Result is still f32 (`Nx.tensor(list)` defaulted to f32 on main) with later-wins semantics preserved.
   - `valid_register?`: `Bitwise.bsl(1, n)` gives 0 for negative n, matching main's `trunc(0.5) == 0`, so it still returns false. The comment at `validation.ex:66-67` is accurate. Edge: a float `num_qubits` (for example `2.0`) worked on main via `:math.pow` and now raises ArithmeticError. This is unrealistic (the register builds an integer) but it is a real difference. LOW.
   - `Qx.Gates.controlled_gate/swap/iswap/cswap/toffoli` (`gates.ex:332,407,454,500,541`): `Integer.pow(2, n)` raises ArithmeticError for negative n and FunctionClauseError for a float, where main did `trunc(:math.pow(...))` and failed later or differently. Valid inputs are unchanged. The CHANGELOG line "The values are identical" (lines 21-22) is true for non-negative integers only. It is slightly overstated for invalid input, but invalid input was never supported. LOW.
   - No version bump or CHANGELOG-breaking section needed.
7. Typed `Qx.*Error`: APPLIES. No new raw-exception path for valid use.
   - `basis_state/3`: bad index or dimension still hits the typed `Qx.BasisError` fallback (`state_init.ex:85-98`). An invalid `type` raises Nx `ArgumentError`. Pre-existing on main (`Nx.tensor(list, type: bad)`).
   - `from_counts` (internal): `String.to_integer(outcome, 2)` raises ArgumentError on a non-binary key (pre-existing, line 19). A negative num_bits raises ArithmeticError from `Integer.pow` (pre-existing, already on main at line 49). A negative index from an outcome such as "-1" passes `index < size`. On main it wrapped via `List.replace_at(-1)`. Now it goes to `indexed_put` with a negative index, so behaviour is undefined or raw. Edge only, internal, input is hardware bit strings. LOW, introduced by the diff.
   - Newly introduced: Gates (ArithmeticError/FunctionClauseError for non-natural `num_qubits`, see Law 6) and `valid_register?` (ArithmeticError for float `num_qubits`). Both are invalid-input edges. `Qx.Gates` has no guard or validation on `num_qubits` (pre-existing gap). Suggest routing via `Qx.Validation` if cheap.
8. Dispatch completeness: DOES NOT APPLY.
9. Feasible float tolerances: DOES NOT APPLY.

## Violations introduced by the diff
None at BLOCKER or HIGH level. Two LOW notes (above): negative-index handling in `build_probability_tensor`, and invalid-`num_qubits` error class changes in Gates and `valid_register?`.

## Pre-existing (not in this diff)
- `state_init.ex` `superposition_state` (~217), `random_state` (~250), `ghz_state_vector` (~389) and `w_state` (~425) still build 2^n host lists (Law 5). The first, second and fourth are `@deprecated`. `ghz_state_vector` is not marked deprecated.
- `result_builder.ex:19` `String.to_integer` raw ArgumentError on malformed outcome (Law 7).
- `Qx.Gates` multi-qubit constructors have no `num_qubits` validation (Law 7).
- `result_builder.ex:33` zero-vector placeholder is a broadcast (fine) but the state is an f32 real tensor rather than c64 (not a law issue).
