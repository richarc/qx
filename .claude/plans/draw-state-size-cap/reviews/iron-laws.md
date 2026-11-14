# Iron Law Violations Report (Qx AGENTS.md laws #1-#9)

Checked 9 of 9 applicable Qx Iron Laws: 0 violations found. Two minor notes below.

## Per-law verdict

- **#1 atoms from caller input: PASS.** New code creates no atoms. `Qx.DrawSizeError.exception/1` (errors.ex ~392-405) builds strings and integers only. `validate_max_qubits!` raises `Qx.OptionError` with the offending value held as a term (validation.ex ~456).
- **#2 processes: PASS.** No spawn/Task/Agent/GenServer in any changed lib file. The test-file processes are out of scope.
- **#3 gather/mask: NOT APPLICABLE.** No Nx kernels are touched.
- **#4 defn on BinaryBackend: NOT APPLICABLE.** There is no defn. `Nx.size/1` is metadata only and needs no backend.
- **#5 host loops over 2^n: PASS.** The new code adds no loops.
  - `validate_size!` in draw.ex:89, :137, :178 and the call in tables.ex:65 use `Nx.size` / `map_size`, which are O(1).
  - The size check runs before the existing `Nx.to_flat_list` / `Enum.map` host loops (draw.ex:183-192, tables.ex:78-96). It bounds them rather than adding to them.
  - PRE-EXISTING: tables.ex:78-96 `build_table_data` and draw.ex:183-192 `histogram` still loop host-side over every amplitude. They are now capped at 2^max_qubits, with a default of 12.
- **#6 public API surface: PASS.**
  - CHANGELOG.md, Unreleased, `### Changed`: the entry is marked **Breaking:** and names `Qx.draw/2`, `draw_histogram/2`, `draw_state/2`, `draw_counts/2`. It names the `Qx.Draw` equivalents (`plot/2`, `histogram/2`, `state_table/2`, `counts/2`) and gives the migration (`max_qubits:`). `### Added` lists `Qx.DrawSizeError` and the new option.
  - The version bump is deliberately deferred, so it is not flagged. The release step must bump the minor version (0.x), because patch releases must not break.
  - Tier: `Qx.Draw` already carries the "Utility module:" opener (draw.ex:5). The new "Size limit" moduledoc section (draw.ex:~30-41) does not touch it.
  - `Qx.DrawSizeError` is an exception module, not a tier-annotated module. Its moduledoc is present and documents its fields. It is registered in the `Qx.Error` list (errors.ex:~11) and under "Error Handling" in the mix.exs docs groups.
  - Docs: the `Raises` and `Options` sections are updated on all four `Qx.Draw` functions and on the four `Qx.draw*` delegates. README.md is updated.
- **#7 typed errors: PASS for new code.**
  - `max_qubits` of `0`, negative, a float, nil or a string raises `Qx.OptionError` via `validate_max_qubits!` (validation.ex:~453-458). `Keyword.get/3` with a non-keyword `options` raises, but that was already true for `title` / `width` / `height` before this diff. PRE-EXISTING.
  - `validate_draw_size!` clause 1 is guarded to size > 0 in effect, because `bsr(size-1, n) > 0` implies size >= 2. For size 0, `bsr(-1, n)` is -1, so clause 2 returns `:ok`. There is no FunctionClauseError for 0 or 1 element tensors.
  - Both clauses require integer size and integer `max_qubits > 0`. `max_qubits` is always pre-validated by `draw_max_qubits!`, and `Nx.size` / `map_size` always return integers. So there is no clause-miss path from caller input.
  - A huge `max_qubits` is safe: `bsr` of a small integer by a huge shift returns 0 and builds no bignum. `exception/1` computes `bsl(1, max_qubits)` only when the size already exceeds the limit, so `max_qubits` is bounded by the size.
  - `exception({size, max_qubits})` is called only from the raising clause, where its guards hold. The `qubits_to_hold` result is correct.
  - NOTE (minor, narrow): `Nx.size(result.probabilities)` (draw.ex:89) and `map_size(result.counts)` (draw.ex:137) are new accesses made before any existing code runs. A hand-built non-`SimulationResult` argument now fails here with `KeyError` / `BadMapError` / `ArgumentError`. Before, it failed slightly later with the same class of error in `VL.plot` (vega_lite.ex:21) / `VL.counts` (vega_lite.ex:53, 60). Not a new leak class. The `SimulationResult` struct has `@enforce_keys` for both fields, so real results cannot trigger it. PRE-EXISTING behaviour, order only.
  - `Qx.Draw.Tables.render/2`: a non-tensor, non-register argument still raises `Qx.RegisterError` before the new check (tables.ex:58-59). A Register passes through to the check. No new leak.
  - `histogram/2` given a non-tensor (e.g. a list): `Nx.size(list)` may raise `ArgumentError` where `Nx.to_flat_list` would also have raised before. PRE-EXISTING class, same error type.
- **#8 float tolerance: PASS.** All new comparisons are integer bit-shifts. No float tolerance is added. PRE-EXISTING: tables.ex:88 `prob > 1.0e-10` is a sub-epsilon threshold. It is a display filter, not a norm/equality target, and the diff does not touch it.
- **#9 dispatch completeness: NOT APPLICABLE.** No instruction shapes are added or changed.

## Violations
None.
