# Review of fix commit f0c1dec (lib/ only)

Status: changes requested, no BLOCKER. 5 WARNINGs, 4 SUGGESTIONs.
"V" = verified by reading source. "I" = inferred.

## WARNING

1. lib/qx/validation.ex:138 (hit from lib/qx/draw/svg/circuit.ex:165, 172, 157) [V]
   `validate_classical_bit!/2` has a single clause guarded by `is_integer(index)`. A hand-built circuit with a non-integer classical bit raises `FunctionClauseError`. Examples: `{:c_if, [:a, 1], []}`, `{:measure, [0, "1"], []}`, or a `circuit.measurements` entry that is not an integer pair.
   - The new "malformed instruction" work covers shape but not element types for these two clauses.
   - `Qx.ClassicalBitError` already has a `{:not_an_integer, v}` constructor (errors.ex:378), so add the fallback clause as `validate_qubit_index!` has.
   - `circuit.measurements` entries that are not `{q, c}` tuples would also hit a FunctionClauseError in the `Enum.each` fn at circuit.ex:155 (hand-built only).

2. lib/qx/draw.ex:336-339 and lib/qx/draw/tables.ex:40, 65 [V]
   The `state_table/2` docs (draw.ex:326-327) and the Qx.draw_state docs now promise `Qx.OptionError` when `options` is not a keyword list. The code is unchanged: `Tables.render` calls `Keyword.get(options, ...)`, and `Qx.Draw.state_table(state, "x")` still raises an untyped `FunctionClauseError`.
   - Call `validate_draw_options!(options, [:precision, :hide_zeros, :max_qubits])` in `state_table/2`, or remove the claim.
   - Check that the Qx.draw_state docs in qx.ex make the same claim.

3. lib/qx/draw/svg/bloch.ex:130 [I from deps/complex/lib/complex.ex:636-645]
   The atan2 change turns NaN/Inf amplitudes into an untyped `ArithmeticError`.
   - `Nx.to_flat_list` yields `:nan` or `%Complex{re: :nan}`.
   - `Complex.abs` returns `:nan` or `:infinity`, and `:math.atan2/2` raises badarith on an atom.
   - The old code survived this: `max(-1.0, min(1.0, :nan))` is 1.0 by term order, which drew |0>.
   - Add a finite check in `amplitudes!/1` and raise a typed error (`Qx.StateNormalizationError` or `StateShapeError`).
   - Reachability is low (NaN state), but this is a regression against Iron Law #7.

4. lib/qx/draw/svg/circuit.ex:175-177 [V]
   `Qx.barrier(qc, [])` is accepted by the public API (operations.ex:694 validates an empty list as fine). It is a valid no-op circuit, and the simulator and `to_qasm` take it. The drawer now rejects it with `GateError`.
   - Patterns and the OpenQASM importer cannot produce an empty barrier (patterns.ex:261 skips empty lists, and the parser requires a qubit list).
   - Prefer skipping it in `render` (filter before `flatten`) over raising. If raising is intended, the doc should say that `Qx.barrier(qc, [])` is the reachable path, not only "circuit built by hand".

5. lib/qx/draw/svg/bloch.ex:134 (the @pole_epsilon change) [V, partly I]
   For normalised states, `2*atan2(|b|,|a|)` equals `2*acos(|a|)` mathematically, so there is no behaviour change apart from improved precision near the poles. The effects below are real but acceptable.
   - Unnormalised inputs now map by direction. `[0.5, 0.5]` gave θ=2π/3 before and gives π/2 now. This is arguably more correct; it deserves a CHANGELOG line.
   - A state with 1e-5 > sin θ > 1e-6 used to keep its φ and now reads φ=0 and snaps to the pole. For c64 (float32) this is the intended trade-off, but `qubit_to_bloch_coordinates/1` is `def`/public-ish and the `@doc` says "At a pole … it is 0". Document the 1e-5 threshold there.

## SUGGESTION

6. lib/qx/draw/svg/circuit.ex:75-76, 205 [V]
   `@max_integer_angle 1.0e300` is a float compared with integers. This is correct in Erlang (exact comparison), but it needlessly rejects integers between 1e300 and 1.79e308 that would format fine. Harmless. Float angles up to 1.79e308 pass, and `pi_fraction` returns nil via the `abs > 7` guard, so `format_decimal` works (verified by reading markup.ex:132-160).

7. lib/qx/draw/svg/bloch.ex:517 [V]
   The φ-arc guard hides the arc for φ within 0.02 rad of 2π, but the readout (bloch.ex:629) only rounds to "0.00" above 1.995π. For φ in [1.9936π, 1.995π) the arc is hidden while the readout says "1.99π" or "2.00→0.00". It is symmetric with the existing low side (φ<0.02 reads "0.01π"). Cosmetic only.

8. lib/qx/validation.ex:270-273 [V]
   `draw_circuit_options!` runs `Keyword.keyword?` and then `validate_draw_options!`, which checks `keyword?` again. Harmless duplication. Pre-existing, one line: chart `:width`/`:height`/`:title` values are not validated (draw.ex:129-131 and others), so a non-string title is passed through to VegaLite.

9. Pre-existing, one line each: `Qx.Draw.circuit/2` with a non-`%QuantumCircuit{}` raises `FunctionClauseError` (draw.ex:389). `Draw.plot/counts` with a non-result map raises `KeyError`/`BadMapError` (draw.ex:129, 186).

## Checked and found correct

- escape/1 regex (markup.ex:79) [V]: `[^\x{9}\x{A}\x{D}\x{20}-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]` is exactly the XML 1.0 `Char` production, including excluding U+FFFE/FFFF.
  - `/u` is right for PCRE UTF mode.
  - `String.replace_invalid/2` needs Elixir 1.16+; mix.exs requires ~> 1.18.
  - Running replace_invalid first guarantees the regex sees valid UTF-8.
  - `to_string/1` on a non-binary non-chardata still raises `Protocol.UndefinedError`, but titles are validated as binary upstream.
- Shape validation vs valid circuits [V]: every gate atom in `Theme @gate_families` except measure, c_if and barrier appears in `@qubit_counts` with the arity the producers use.
  - Operations.add_gate, add_two_qubit_gate and add_three_qubit_gate give 1, 2 and 3 qubits.
  - The lowering table lines 12-42 match: u/u3 → 1 qubit, cp/crx/... → 2, ccx/cswap → 3.
  - `params` is always a list in producers, so the new guard rejects no valid circuit.
  - The `c_if` guard (`is_integer(value)`, `is_list(block)`) matches `Qx.c_if` (value in [0, 1]).
  - Barrier qubits are checked for range.
  - The empty barrier is the only valid-API rejection (finding 4).
- `Qx.GateError {:invalid_parameter, gate, param}` and `Qx.StateShapeError` with `{size, 2}` or a binary both have matching `exception/1` clauses (errors.ex:302-312, 419).
- size cap (validation.ex:621): works with bignums (`10 ** 400 <= 10_000` is false → typed error). Tiny positive sizes cannot divide by zero (scale is only multiplied; `f` is clamped).
- VegaLite.histogram/4 now takes a list. Only Draw.histogram and VL.plot call it, so there is no stale caller. The empty-counts title is now forwarded, and `Draw.counts` supplies the old default.
