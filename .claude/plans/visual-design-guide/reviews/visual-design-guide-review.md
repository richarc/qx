# Review: visual-design-guide

**Branch:** `feat/visual-design-guide` at `215a37e`, against `main` at `45590b2`
**Date:** 2026-11-20
**Verdict: PASS WITH WARNINGS**

No reviewer found a blocker and no requirement is unmet. There are 12
warnings. Six are in the test code; six are inputs that raise an untyped
error (Iron Law #7), of which four behave the same on `main`. With 12
findings the repo's rule is to triage them before the merge.

Panel: elixir-reviewer, testing-reviewer, iron-law-judge,
requirements-verifier. The verification runner was skipped because the full
gate ran at the end of `/phx:work` (1800 of 1800 tests, dialyzer, credo,
format, docs warnings equal to `main`, `--no-optional-deps` compile,
`mix hex.build`). None of the reviewers re-ran those gates; three of the
four only read the code. The "Checked" column below is what the
orchestrating session then ran itself, on the branch and on `main`.

## Requirements Coverage

Source: plan file `.claude/plans/visual-design-guide/plan.md`.
**47 MET, 3 PARTIAL, 0 UNMET, 2 UNCLEAR.** Detail in `requirements.md`.

| Requirement | Status | Note |
|---|---|---|
| Scope: edits to existing test files | PARTIAL | The plan names six files. Edited: four draw test files, `quantum_circuit_instruction_order_test.exs` and the Livebook. `swap_svg_test.exs` needed no edit. |
| P1-T3 label widths | PARTIAL | Replaced by an amended spec (measured width plus a minimum per gate kind). Recorded in the scratchpad; no user sign-off recorded. |
| P3-T6 scaling | PARTIAL | Strokes are clamped at 80% as well as fonts, following the reference drawings. Only the font clamp is tested below size 400. |
| Gate claims of P1-T9, P2-T9, P3-T8, P4-T5 | UNCLEAR | The verifier did not re-run them. They were run and passed during the work. |

Fidelity spot-checks all matched the guide: the six family colour pairs, the
Vega-Lite config key for key, and the Bloch camera, radius and head rules.

### Deviations with no recorded approval

1. `circuit_test.exs` connector test: renamed, and its assertion changed
   from "ends exactly at the tip" to "ends between the base and the tip".
   The approved row said "same four geometric checks". See T2.
2. `iswap_svg_test.exs` non-adjacent assertion rewritten (`iSW` substring to
   two `iSWAP` labels and two Exchange boxes). The file was approved; this
   particular rewrite was not listed.
3. New `Qx.OptionError` cases on `draw_bloch` (`:title`, `:size`) and
   `draw_circuit` (non-keyword second argument, `:title`). In the CHANGELOG.
4. P1-T3 and P3-T6 as above.

## Source findings

| # | Finding | Where | Checked | New on this branch? |
|---|---|---|---|---|
| S1 | `Qx.barrier(qc, [])` then `draw_circuit` raises `Enum.EmptyError` | `circuit.ex` barrier clause and `occupied_wires` | Confirmed | No: `main` raises the same |
| S2 | A hand-built instruction of the wrong shape, e.g. `{:cx, [0], []}`, raises `FunctionClauseError`: validation checks the atom and indices, not the shape, and `draw/3` has no catch-all | `circuit.ex` `validate_instruction!/2` | Confirmed | No: `main` raises the same. The reviewer's note that the old code had a typed catch-all is wrong |
| S3a | `Qx.rx(qc, 0, 10 ** 400)` drawn raises `ArithmeticError` | `markup.ex` `angle/1` | Confirmed | No: `main` raises the same |
| S3b | `Qx.draw_bloch(state, size: 1.0e160)` raises `ArithmeticError` | `bloch.ex` | Confirmed | **Yes**: `main` draws it |
| S4 | `Qx.draw_bloch` on a tensor that is not two elements raises `MatchError`; a string as the options argument of `bloch/2` and the chart functions raises `FunctionClauseError` | `bloch.ex:120`, `draw.ex` | Confirmed for `bloch(state, "t")` | No |
| S5 | Float32 noise can defeat the Bloch pole guard: θ = 2·acos(\|α\|) turns a rounding error of 6e-8 into θ ≈ 7e-4, above `@epsilon`, so φ is read from a noise-level β | `bloch.ex` `qubit_to_bloch_coordinates/1` | Not reproduced: `H·H`, `H·H·X`, `Rx(π)·Rx(π)` and `H·T⁸·H` all read φ = 0.00π, because their β is real or zero. The mechanism is sound; a noisy complex β would show an arbitrary φ beside θ = 0.00π | Yes |
| S6 | `Markup.escape/1` passes XML-illegal control characters: a NUL byte in a title is written into the SVG | `markup.ex` `escape/1` | Confirmed | Partly: `main` wrote titles with no escaping at all |

## Test findings

| # | Finding | Where | Checked |
|---|---|---|---|
| T1 | The ">20 qubits" test passes for the wrong reason: `Qx.create_circuit(21)` raises inside the closure, so the drawer's guard is never reached | `circuit_style_test.exs:728` | Confirmed. The guard itself works when 21 is forced through the struct |
| T2 | The rewritten connector test is weaker than the original. It accepts any end point between the arrowhead's base and tip; the lines sit 1.5 off the axis, so about 3.7 units of drift would pass. The tip test at lines 26 to 50 now compares against the lower register line | `circuit_test.exs:26-50`, `:78-112` | Read; agreed |
| T3 | Mono style is strictly asserted on two circuits only; the catalogue loop allows the whole palette in mono | `circuit_style_test.exs:739` | Test gap only: iSWAP, Toffoli, rotations, U, S†, controlled-Y, controlled-Rx and Fredkin drawn in mono contain only ink, paper and `none` |
| T4 | Untested branches. Circuit: `Qx.ConditionalError` for a nested `c_if` and a measurement in a block, a `c_if` with a bad classical bit, a `:measure` with a bad index, the one-qubit aria label, `cx`/`ccx`/`iswap` with qubits in reverse order. Bloch: the `acos` clamp, the `"2.00"` to `"0.00"` readout branch, global phase on a state off the poles, stroke scaling at size 240 | several | Not checked |
| T5 | `GateCatalogue.qasm_atoms/0` reads `lowering.ex` by regex: it depends on source formatting and the working directory, and its `>= 20` guard would miss up to four dropped entries of 24. `uncovered/0` does not detect stale entries | `test/support/gate_catalogue.ex:108-116` | Read; agreed |
| T6 | Edited tests that kept their intent: T†/S†, cswap, iswap, U, the instruction-order regex | | Reviewer's judgement |

## Iron Laws

| Law | Verdict |
|---|---|
| #1 atoms | OK. One `String.to_existing_atom` in test support, on a bounded set |
| #2 processes | OK |
| #3, #4 Nx kernels | Not applicable |
| #5 host loops | OK. `plot`, `counts` and `histogram` call the size guard before any per-bar work |
| #6 public API | OK. Every change is in the CHANGELOG; new modules are `@moduledoc false`. The release must be 0.13.0, not a patch |
| #7 typed errors | S1 to S4 above |
| #8 tolerances | OK, with the note in S5 |
| #9 dispatch | OK. 24 gate atoms plus `measure`, `barrier` and `c_if` traced from the producers to a theme entry, a width and a draw clause of the shape the producer emits. No unreachable clause |
| TDD | OK. The new facade doctest runs under `doctest Qx` |

## Suggestions (grouped)

- **Options:** `title: ""` is treated as a title and moves the first wire;
  unknown option keys are ignored silently; the empty-counts chart ignores
  the `:title` it is given.
- **Formatting:** an angle just outside the zero tolerance prints `0.00` or
  `−0.00`; the Bloch readout rounds φ ≥ 1.995π to `0.00` while the φ arc is
  still drawn nearly all the way round; title width is estimated from the
  grapheme count.
- **Duplication:** `width/1` is computed twice per gate; the histogram data
  is built in `draw.ex` and the plot data in `vega_lite.ex` by the same code.
- **Tests:** the `Enum.shuffle` at `chart_style_test.exs:225` does nothing
  (a map has no insertion order); add length assertions before the
  `Enum.zip` calls in the Bloch scaling tests; the text-extraction helper is
  pasted in six places; exact attribute-order matches will break on harmless
  refactors; `Mix.ensure_application!(:xmerl)` is in two files.

## Not reviewed

- `.claude/plans/visual-design-guide/research/` is not committed, so the
  branch on origin does not carry the reference drawings the tests' numbers
  came from.
- Rendering in Cambria and Latin Modern Roman (not installed on this
  machine). Checked by eye in STIX Two and Times New Roman only.
- The pictures in a real Livebook: the new cells were evaluated, not viewed
  there.
