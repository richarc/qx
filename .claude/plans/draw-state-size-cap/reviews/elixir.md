# Code Review: draw-state-size-cap

## Summary
- Status: Approved (no blockers)
- Issues: 0 BLOCKER, 0 WARNING, 4 SUGGESTION
- Read-only review; compile/test not run (no Bash).

## Verified correct
- Boundary: `bsr(size-1, n) > 0` is equivalent to `size > 2^n` for size >= 1. 4096 passes, 4097 raises. size 0 gives `bsr(-1, n) = -1`, which passes, and the DrawSizeError clause is not reached. size 1 passes. A huge `max_qubits` is safe: it never builds a bignum.
- Suggested value: `Integer.digits(size-1, 2) |> length` is the bit length of size-1. It is the smallest n with 2^n >= size for the sizes that can raise (size >= 3). 8192 gives 13, 8193 gives 14, 4097 gives 13.
- Guard-before-build holds in all four functions:
  - `plot/2` (draw.ex:89) comes before `VL.plot` `to_flat_list` (vega_lite.ex:21).
  - `histogram/2` (draw.ex:178) comes before `to_flat_list`.
  - `counts/2` (draw.ex:137) comes before the `Enum.map` in `VL.counts`.
  - `Tables.render/2` (tables.ex:65) comes before `build_table_data`' `to_flat_list`.
  - `ensure_vega_lite!` still runs first, so a missing dep gives `MissingDependencyError`, as documented.
- Register input in `state_table`: the deprecation warning fires, then the guard. A non-tensor, non-register input raises `RegisterError` before the option check. Both match the docs and the tests.
- Odd inputs:
  - Empty counts (`map_size == 0`) passes the guard and still reaches the "No Measurements" branch.
  - A scalar tensor (size 1) passes.
  - `nil` or non-map counts raise `BadMapError`. `Nx.size(nil)` raises as well. Before this change they crashed in the build anyway, and `SimulationResult` types `counts` as a map.
  - A bare non-integer `max_qubits` raises `OptionError` through the existing `{opt, val, hint}` clause.
- Docs and CHANGELOG match the code: default 12, 4096, error fields, hide_zeros still limited, and `bloch`/`circuit` unaffected.
- `Bitwise.bsr` in a guard without `require`: not compiled here. Elixir inlines Bitwise ops (via `elixir_rewrite`) so this should be fine; the compile/test run will confirm it.

## Blockers
None.

## Warnings
None.

## Suggestions
1. lib/qx/errors.ex:`exception/1` message — it always says "Cannot draw N states". For `counts/2` the unit is distinct outcomes (a 20-qubit GHZ is 2 outcomes, not states), and `state_table` draws rows. Consider "Cannot draw N bars/rows" or "N items". The wording is tested verbatim at draw_size_cap_test.exs:135, so update that test too.
2. lib/qx/errors.ex `@type t` — `message: String.t()` is fine. `exception/1` accepts only a `{size, max_qubits}` tuple with `size > 0`, or a binary. `raise Qx.DrawSizeError, size: 5, max_qubits: 2` or a tuple with size 0 gives `FunctionClauseError`. This is consistent with the other Qx errors, so it is only a note.
3. test/qx/draw_size_cap_test.exs:3-9 and 21-25 — the moduledoc and the comment name the plan slug and a measurement date/toolchain ("Measured on 2026-11-14 (OTP 29...)"). That is commit-message material under the "comments are not commit messages" rule. Keep the 500x-margin rationale and drop the plan ref and date.
4. lib/qx/validation.ex:466-474 — `validate_draw_size!/2` has no fallback clause. A non-integer `size` gives `FunctionClauseError`. All callers pass `Nx.size`/`map_size`, so this is unreachable; a `@spec`-only note.
5. CHANGELOG.md:10-36 — "### Changed" and "### Added" appear before "### Performance"/"### Fixed" in Unreleased. This is only a section-order nit, and Keep a Changelog does not mandate an order.

## Pre-existing (one line each)
- lib/qx.ex:1651 — the `draw_state` `@spec` takes only `Nx.Tensor.t()` although a deprecated `Qx.Register` is still accepted.
- lib/qx/draw/tables.ex:82 — `trunc(:math.log2(num_states))` is wrong for non-power-of-2 sizes. This is pre-existing and now reachable only up to the cap.
