# Review: host-side-state-lists (fix/host-side-state-lists vs main)

Status: Changes requested (no blockers; two behaviour regressions to decide on)

## BLOCKER
None.

## WARNING

1. lib/qx/result_builder.ex:52-63 — negative index behaviour changed. VERIFIED by reading source.
   `String.to_integer("-1", 2)` returns -1, which passes `index < size`. Old code: `List.replace_at(acc, -1, p)` wrote the LAST element. New code: `Nx.indexed_put` with index -1 raises `ArgumentError "index -1 is out of bounds"` (deps/nx/lib/nx/binary_backend.ex:1979, `index_to_binary_offset`). D2 says "out-of-range indices still dropped", but negative indices are not dropped. Only reachable with malformed outcome keys such as "-1" or "-01". Fix: filter `index >= 0 and index < size` (drop, matching D2), or document it as intentional.

2. lib/qx/validation.ex:68 — `Bitwise.bsl(1, num_qubits)` is not equivalent for non-integer num_qubits. VERIFIED that bsl needs integers (Erlang `bsl` raises ArithmeticError for floats); INFERRED for exact error class. Old `trunc(:math.pow(2, 2.0))` = 4 worked, so `valid_register?(%{num_qubits: 2.0, ...})` returned a boolean. New code raises. The comment says the point is "predicate returns false instead of raising", but it now raises for float input. Also bsl with a huge positive num_qubits allocates a bignum, where old `:math.pow` raised past 1023. Both are very low-reachability (Qx.Register always carries an integer), so the comment is accurate for negatives only. Consider `is_integer(num_qubits) and num_qubits >= 0` guard.

3. CHANGELOG.md (the "Internal:" bullet) — "14 sites" is wrong. The diff shows 13 `trunc(:math.pow(2, n))` to `Integer.pow(2, n)` replacements: gates.ex 5, quantum_circuit.ex 3, state_init.ex 5. validation.ex uses `bsl`, not `Integer.pow`. "The values are identical" is also not strictly true for non-validated sites (see Integer.pow table below). Fix count, soften wording.

## Integer.pow site audit (n validated before the call?)

| Site | n validated? | Old vs new for bad n |
|---|---|---|
| state_init.ex zero_state/superposition_state/random_state (131, 217, 250) | guard `is_integer and > 0` | no difference |
| state_init.ex ghz_state_vector/w_state (389, 425) | guard `is_integer and >= 2` | no difference |
| quantum_circuit.ex:79 `new/2` | `validate_num_qubits!` first (integer, 1..20) | no difference |
| quantum_circuit.ex:320 `set_state`, :443 `reset` | n comes from the struct (validated at `new`) | no difference unless struct hand-built |
| gates.ex:332, 407, 454, 500, 541 (controlled_gate, swap, iswap, cswap, toffoli) | NO guard, no validation | Float n (2.0): old gave 4, new raises FunctionClauseError. Negative n: old gave `trunc(0.5)` = 0, new raises ArithmeticError (INFERRED: Elixir's Integer.pow/2 source is not in the repo; I did not read it). Zero n: both give 1. |
| result_builder.ex:32, 49 (unchanged lines) | `is_integer(num_bits)` guard only | pre-existing; negative num_bits raises |

   In gates.ex the "refactor, values identical" claim holds for all valid inputs. For float/negative input it is a (benign, arguably better) behaviour change, so the CHANGELOG wording "identical" is slightly overstated. SUGGESTION-level unless these gates take float qubit counts anywhere.

## SUGGESTION

1. lib/qx/state_init.ex:79 and result_builder.ex:62 — index tensor is always s32. VERIFIED: `Nx.Type.infer(int)` is `{:s, 32}` (deps/nx/lib/nx/type.ex:173), so `Nx.tensor([[index]])` is s32 regardless of magnitude. An index >= 2^31 would be truncated by the 32-bit write (INFERRED, I did not trace the Nx.tensor range handling). Practically unreachable: the target would need >= 16 GiB (and `Qx.QuantumCircuit.new` caps qubits at 20). `from_counts/3` with num_bits > 31 would be the only route, and the old code would OOM there. Cheap hardening: `Nx.tensor(..., type: :s64)`.

2. lib/qx/state_init.ex:77 — `type: nil`. VERIFIED nx.ex:822 uses `opts[:type] || infer_type(arg)`. Old: `basis_state(i, d, nil)` inferred c64 from Complex elements. New: infers s32 from the integer 0 and returns an s32 tensor. Only matters if a caller passes `nil` explicitly; the default is `:c64`. Very low.

3. lib/qx/state_init.ex:77-79 — fine on duplicates/types (VERIFIED: with c64/c128/{:c,64} the update `Nx.tensor([1], type: type)` and zero target share a type, so `binary_type` merge keeps it). `:bogus` still raises ArgumentError from `Nx.tensor(0, type: :bogus)`, matching the test. D5 claim (real type now works) holds. I did not verify the old crash claim for :f32 by running it, only by reasoning (Complex struct in an f32 `Nx.tensor`).

4. lib/qx/result_builder.ex:52-65 — logic otherwise correct. Duplicate indices last-write-wins: VERIFIED at binary_backend.ex:1722 (`resolve_updates = Enum.at(upds, -1)`) combined with `Enum.group_by` at :1759, which preserves input order within a group. Same as old `replace_at` reduction over `Enum.map(counts)` order. Output f32: VERIFIED (target f32, updates f32). Empty pairs give f32 zeros of `{size}`: matches D3. The `[]` branch comment is right: Nx.Shape.indexed requires leading-axis match and an empty tensor does not fit the rank-1 shortcut. Minor idiom: could use `{indices, probs} = pairs |> Enum.map(fn {i, p} -> {[i], p} end) |> Enum.unzip()` to avoid the second `Enum.map(indices, &[&1])` pass; optional. `Nx.tensor(probs, type: :f32)` is correct.

5. Comments: "Iron Law #5" matches CLAUDE.md:396 ("NO host-side loops over 2^n amplitudes"), fine. The test header measurements (1,598 / 22,820,312 / 41,523,437 words) and CHANGELOG timings and "227 ms to 4.7 ms" cannot be verified from code; I did not re-measure. The CHANGELOG says "over 41 million words to under 1,600", consistent with the test comment. CHANGELOG says "Results are unchanged" for basis_state: true for valid c64/c128 input; the type: nil case above is the only exception found.

6. test/qx/host_side_state_lists_test.exs — no test for negative index (finding W1), float/negative num_qubits (W2), or large index. The duplicate-index test relies on small-map key ordering ("01" < "1"), which is stable for maps of <= 32 keys but is an implementation detail; acceptable. Test at :108 `from_counts(%{}, 0, 2)` fine.

## Pre-existing (unchanged lines)
- lib/qx/result_builder.ex:19 — `String.to_integer(outcome, 2)` accepts "-", "+", underscores in keys; no validation of outcome format.
- lib/qx/result_builder.ex:27-28 — `List.duplicate(bits, count)` for classical_bits builds a shots-sized host list (not 2^n, so out of this change's scope).
- lib/qx/state_init.ex:214-260, 385-440 — superposition/random/ghz/w states still build 2^n host lists (deprecated functions, per the plan's scope).
