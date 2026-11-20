# Code Review: feat/visual-design-guide (Elixir)

## Summary
- Status: Changes Requested (no hard blocker; one reachable crash and one likely wrong-output case)
- Read-only review; nothing was run. Items marked UNCONFIRMED could not be verified by reading alone.

## WARNING

1. **lib/qx/draw/svg/circuit.ex:444-446 - `Enum.EmptyError` on an empty barrier.**
   `Qx.barrier(qc, [])` is accepted: `Operations.barrier/2` validates each index and `[]` passes. `Circuit.draw(%{gate: :barrier, qubits: []})` then calls `Enum.min([])`, so `Qx.draw_circuit/2` raises an untyped `Enum.EmptyError`. `place/2` is fine because its barrier clause ignores `qubits`. The OpenQASM importer always supplies indices for `barrier`, so this is reachable only through the builder API.
   Correct behaviour: draw a full-height barrier (the layout already treats a barrier as spanning every wire), or skip it.

2. **lib/qx/draw/svg/bloch.ex:123-130 - float32 rounding noise gives a garbage φ at the poles (UNCONFIRMED, not run).**
   θ = `2*acos(|α|)` amplifies f32 noise: |α| = 0.99999994 gives θ ≈ 6.9e-4, so `sin θ ≈ 6.9e-4`, far above `@epsilon = 1e-6`. The pole guard is therefore not triggered, and φ = arg β − arg α is taken from a noise-level β.
   Input: `Qx.create_circuit(1) |> Qx.h(0) |> Qx.h(0) |> Qx.get_state()`. This should be |0⟩, but the readout may show `θ = 0.00π  φ = 1.00π` (or another random φ).
   Suggested: take θ from `atan2(|β|, |α|)`, which is also correct for non-normalised input, and gate φ on |β| and |α| against an f32-sized tolerance (about 1e-4), not on `sin θ < 1e-6`.
   Related: a non-normalised state such as (0.5, 0) draws a unit vector with θ from |α| alone and a meaningless φ.

3. **lib/qx/draw/svg/markup.ex:68-76, lib/qx/draw/svg/circuit.ex:611, lib/qx/draw/svg/bloch.ex:595 - `escape/1` does not strip characters that are illegal in XML 1.0.**
   `Qx.draw_circuit(qc, "a" <> <<0>> <> "b")` or `title: "x\u0001"` produces a well-formed-looking but invalid SVG. Browsers show an XML parse error instead of the image. `Validation.validate_draw_title!/1` only checks `is_binary`, so an invalid-UTF-8 binary also gets through.
   Fix: in `escape/1`, drop or replace characters outside `#x9 | #xA | #xD | #x20-#xD7FF | #xE000-#xFFFD | #x10000-#x10FFFF`, or require `String.valid?/1` plus a control-character check in the validator (raising `Qx.OptionError`).

4. **lib/qx/draw.ex:283-284 - `Qx.Draw.bloch(state, "My title")` raises `FunctionClauseError` from `Keyword.get/3`.**
   `circuit/2` now accepts a bare title string (`draw_circuit_options!/1`), but `bloch/2` and the three chart functions still call `Keyword.get` on the options. Passing a string or other non-list raises an untyped error, which violates the typed-error rule in AGENTS.md. The same function-clause problem exists for `plot`, `counts` and `histogram` (draw.ex:127-129, 181, 228); this is pre-existing and listed here only as one line.
   Correct behaviour: route through a validator that raises `Qx.OptionError`, as `draw_circuit_options!/1` does for the circuit.

## SUGGESTION

5. **lib/qx/draw/svg/circuit.ex:96, 114, 619 - an empty-string title is treated as a title.**
   `if title` is truthy for `""`, so the diagram gets the 52-unit titled top margin, an empty `<text>` and `aria-label=""`. Normalise `""` to `nil` in the validator.

6. **lib/qx/validation.ex:258-265 - unknown keyword options are silently ignored.**
   `draw_circuit_options!(titel: "x")` is accepted and drops the title. Consider raising `Qx.OptionError` for unknown keys, as `:style` is validated.

7. **lib/qx/draw/svg/markup.ex:104-111 - angle rounding is inconsistent near zero.**
   A value of 0.0008 prints "0", but 0.004 prints "0.00" and −0.004 prints "−0.00". Treat anything that formats to 0.00 as "0".

8. **lib/qx/draw/svg/bloch.ex:605-614 - the readout and the drawing disagree for φ ≥ 1.995π.**
   φ = 6.275 is normalised to something other than 0.0, so the φ arc is drawn nearly the full way round, while the readout rounds "2.00" to "0.00π". Use the same rounded φ for both.

9. **lib/qx/draw/svg/circuit.ex:616-617 - the title width estimate is by `String.length`.**
   CJK or emoji titles are wider than 7.2 units per grapheme, so the title can overflow the viewBox.

10. **lib/qx/draw/svg/circuit.ex:230 - `width(gate)` is computed twice per `Map.update`.**
    It calls `Markup.label_width`, which allocates graphemes. Compute it once with `w = width(gate)`.

11. **lib/qx/draw/svg/circuit.ex - no size cap on gate count.**
    Output is linear in the number of gates, and `place/2` is O(gates × qubits) with maps, which is fine. A 10k-gate circuit produces a multi-megabyte SVG. Consider documenting this.

12. **lib/qx/draw.ex:235-241 vs lib/qx/draw/vega_lite.ex:62-68 - duplicated "state"/"probability" data construction.**
    `Draw.histogram/2` and `VL.plot/4` build the same data list. Have `plot` call `VL.histogram`, or share a helper.

13. **lib/qx/draw/vega_lite.ex:90 - an empty counts result ignores the caller's `title`.**
    It always shows "No Measurements"; pass `title` through, or at least document it.

14. **lib/qx/draw/svg/markup.ex:103-129 - an astronomically large integer angle raises `ArithmeticError`.**
    `10**400 / :math.pi()` is the case. Unrealistic, but `angle/1` promises to fall back to a plain number.

## Checked and found OK
- Every atom in `Theme.@gate_families` has a `draw/3` clause (boxed, cx, ccx, controlled boxes, cz, swap, cswap, iswap, measure, barrier).
- Column contiguity in `columns/1` holds.
- `num/2` handles "-0" and trailing zeros correctly.
- Pole and φ≈0 handling in `normalize_phi/1` is fine.
- The near/far split of the great circles: the start angle makes depth increase, so the first half is the near half.
- A `:measure` or conditional gate always has a register, because `validate_classical_bit!` rejects bit indices when `num_classical_bits` is 0.
- Theme has no `VegaLite` reference.
- `nil` options reach Vega-Lite as JSON null (`to_vl` handles nil), so `sort: nil` and `view: [stroke: nil]` are correct.
- Chart bar-count thresholds: 16/17 and 64/65 use `<=` consistently.
- Counts keys of unequal length do not crash; they sort lexicographically.
