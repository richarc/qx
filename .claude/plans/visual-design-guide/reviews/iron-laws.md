# Iron Laws review: feat/visual-design-guide (Qx AGENTS.md laws 1-9, TDD, VERIFICATION)

Judged against `/Users/richarc/Development/qxquantum/qx/AGENTS.md` lines 384-420 and "TDD Rules" (line 201). Static read only: no Bash was available, so `mix compile/format/credo/test` were NOT run by this agent (VERIFICATION is unconfirmed here).

Summary: 0 BLOCKERS, 4 WARNINGS (all law #7, 1 also touches #8), 0 laws violated outright for #1-#6, #9.

## Verdicts

| Law | Verdict |
|---|---|
| #1 atoms | OK |
| #2 processes | OK |
| #3 reshape/contraction | NOT APPLICABLE |
| #4 BinaryBackend defn | NOT APPLICABLE |
| #5 no 2^n host loops | OK |
| #6 public API | OK (one release-time reminder) |
| #7 typed errors | WARNING (4 findings) |
| #8 tolerances | OK, with one WARNING note on the pole epsilon |
| #9 dispatch completeness | OK (one WARNING-level shape gap folded into #7) |
| TDD rules | OK |

## #1 atoms: OK
Grep for `String.to_atom`, `to_existing_atom`, `Module.concat`, `binary_to_atom`, `list_to_atom` across `lib/qx/draw.ex`, `lib/qx/draw/theme.ex`, `lib/qx/draw/svg/*.ex`, `lib/qx/draw/vega_lite.ex`, `lib/qx/validation.ex`, `test/qx/draw/*` and `test/support/gate_catalogue.ex`.
- lib: no matches. The drawer never turns a string into an atom. Unknown gate atoms are looked up in a literal map (`Theme.family/1`), which raises `Qx.GateError`.
- `test/support/gate_catalogue.ex:115` `Enum.map(&String.to_existing_atom/1)`: bounded. The input is the fixed set of atom names the regex finds in `lib/qx/export/openqasm/lowering.ex` at test time (about 20), it is `to_existing_atom`, it is test-only (`elixirc_paths(:test)`), and it is not caller-derived.

## #2 processes: OK
No GenServer/Agent/Task/ETS/Process in any changed lib or test file (grep). `test/support/stub_ibm.ex` has an Agent but it is not in this diff.

## #3/#4 Nx: NOT APPLICABLE
No `defn` and no `lib/qx/calc*.ex` change.

## #5 host loops: OK
- No loop over 2^n amplitudes was added. `circuit.ex` loops over gates and at most 20 qubits (`@max_qubits`). `bloch.ex` loops over fixed counts (120 segments).
- Size guard order is correct in `lib/qx/draw.ex`:
  - `plot/2` (line 125-131): `ensure_vega_lite!` then `validate_size!(Nx.size(result.probabilities), options)` at line 126, and only then `VL.plot`, which does `Nx.to_flat_list` and the per-bar map.
  - `counts/2` (line 179-185): `validate_size!(map_size(result.counts), ...)` at line 180, before `VL.counts` sorts and maps.
  - `histogram/2` (line 226-243): `validate_size!(Nx.size(probabilities), ...)` at line 227, before `Nx.to_flat_list` at 232 and the map.
  - `validate_size!` goes to `Qx.Validation.validate_draw_size!`, which uses a shift and never builds a bignum.
- Pre-existing, unchanged: `lib/qx/draw/svg/bloch.ex:120` `[alpha, beta] = Nx.to_flat_list(qubit)` runs on any tensor size with no size guard (see #7 finding W4).

## #6 public API: OK
- CHANGELOG `[Unreleased]` records every change:
  - Added: the `Qx.draw_circuit/2` and `Qx.Draw.circuit/2` options (`:title`, `:style`).
  - Changed: the new look of all drawings, with a bold "check your SVG/spec parsing" warning; the chart changes (axis 0 to 1, titles, bit-string order, layered spec); the new `Qx.OptionError` raises for `draw_circuit/2` and `draw_bloch/2`.
  - Fixed: the five-gate bug, the measurement bit index, the title escaping, and the φ readout.
- The `Qx.draw_circuit/2` spec widening is backward compatible (a title string still works). The new raises on previously accepted junk are recorded under Changed. No function was removed and no return type changed.
- Tier annotations: `Qx.Draw.Theme`, `Qx.Draw.SVG.Markup`, `Qx.Draw.SVG.Circuit`, `Qx.Draw.SVG.Bloch` and `Qx.Draw.VegaLite` are all `@moduledoc false` (tier 3). `Qx.Draw` keeps its "Utility module:" opener. No unannotated module.
- Version: mix.exs is still 0.12.0 and the CHANGELOG is under `[Unreleased]`. This is correct for the branch. At release it MUST be a minor bump (0.13.0), because the output content change and the new raises are breaking for a tier 1/2 surface under the <1.0 rule. A 0.12.1 patch would violate #6. The plan already says 0.13.0.
- README install snippets were not touched in this diff.

## #7 typed errors: WARNING (no BLOCKER)

Traced: `Qx.draw_circuit/2` and `Qx.Draw.circuit/2` (via `Validation.draw_circuit_options!`, then `Circuit.render`/`validate_circuit!`), `Qx.draw_bloch/2` and `Qx.Draw.bloch/2`, `Qx.draw/2`, `Qx.draw_counts/2`, `Qx.draw_histogram/2`.

**Fine.** These all raise a typed error: bad second argument, bad `:style` or `:title`, bad `:size` (`Qx.OptionError`); more than 20 qubits (`QubitCountError`); unknown gate atom (`GateError`); out-of-range qubit or classical bit (`QubitIndexError`/`ClassicalBitError`); nested `c_if` or a measure in a `c_if` (`ConditionalError`); bad `:max_qubits` (`OptionError`); oversized chart input (`DrawSizeError`). Every gate qubit and `c_if` bit is validated before `place/2` runs, so `Map.fetch!(free, q)` cannot KeyError.

**W1. Empty barrier crashes the drawer with a raw `Enum.EmptyError`.**
- `lib/qx/draw/svg/circuit.ex:445` and `:446`, also `:217` and `:221`. `Enum.min(qubits)` / `Enum.max(qubits)` get `[]`.
- Call: `Qx.create_circuit(2) |> Qx.barrier([]) |> Qx.draw_circuit()`.
- Why it reaches the drawer: `Operations.barrier/2` accepts `[]` (`validate_qubit_indices!([])` is `:ok`) and `add_barrier/2` emits `{:barrier, [], []}`. The same happens with `Qx.barrier_all(qc, [])` (not read, so unconfirmed).
- The old renderer also took `Enum.min(qubits)` on barriers (the removed lines near diff line 2290), so this is probably not new, but the rewrite did not fix it.
- Fix: in `validate_instruction!` treat `{:barrier, [], _}` as nothing to draw (drop it in `flatten/1`) or raise a typed `Qx.GateError`/`Qx.QubitIndexError`.

**W2. A malformed instruction shape raises a raw `FunctionClauseError`.**
- `validate_instruction!/2` (`circuit.ex:163-166`) checks only that the atom has a family and that the indices are in range. It does not check the arity. The old code had a catch-all `raise Qx.GateError, {:unsupported_gate, gate_name}`; the new `draw/3` has none.
- Call, from a hand-built circuit: `Qx.QuantumCircuit.put_instructions(qc, [{:cx, [0], []}])` followed by `draw_circuit` (also `{:h, [0, 1], []}` or `{:measure, [0], []}`). `put_instructions/2` is `@doc false` and does not validate tuples. No public producer emits these.
- Fix: add a final catch-all `defp draw(%{gate: gate, qubits: qubits}, _x, _context), do: raise Qx.GateError, ...`, or check arity per gate in `validate_instruction!`.

**W3. A very large integer angle or an oversized `:size` raises a raw `ArithmeticError`.**
- `Markup.angle/1` (`lib/qx/draw/svg/markup.ex:119`, `:140`): `value / :math.pi()` and `abs(value) * 1.0` on an integer above ~1.8e308. Call: `Qx.rx(qc, 0, 10 ** 400) |> Qx.draw_circuit()`. `validate_parameter!` accepts any number. A theoretical edge.
- `Bloch.short_vector?` (`bloch.ex:372`) and `vector/2` (`:539`) square pixel distances. `validate_draw_image_size!` (`validation.ex:285`) accepts any positive number, so `Qx.draw_bloch(state, size: 1.0e160)` overflows float `**` and raises `ArithmeticError`.
- Fix: cap `:size` in `validate_draw_image_size!` (for example `size <= 100_000`) and guard the angle with `is_float`/range before dividing.

**W4. Bloch input and option shape: raw errors (pre-existing lines, still reachable).**
- `bloch.ex:120` `[alpha, beta] = Nx.to_flat_list(qubit)` raises `MatchError` for a tensor that is not 2 elements, for example `Qx.draw_bloch(Qx.get_state(two_qubit_circuit))`. For a large state it first builds the whole 2^n host list (a #5 hazard).
- `Qx.draw_bloch(:not_a_tensor)` raises an Nx `ArgumentError`. A NaN tensor makes `Complex.abs(:nan)` fail.
- `Qx.draw_bloch(state, "My title")` raises a `FunctionClauseError` from `Keyword.get`. This is inconsistent with `draw_circuit/2`, which accepts a bare title. Likewise `Qx.draw(result, "title")`, `Qx.draw_counts/2`, `Qx.draw_histogram/2`. `draw.ex:127-129`, `:181-183`, `:228-230`, `:283-284`.
- Fix: validate the tensor shape (`Nx.size == 2`) in `Bloch.qubit_to_bloch_coordinates` via `Qx.Validation`, and run options through a keyword check that raises `Qx.OptionError`.

Doc nit: the `Raises` blocks of `Qx.draw_circuit/2` and `Qx.Draw.circuit/2` omit `GateError`, `QubitIndexError`, `ClassicalBitError` and `ConditionalError`, which `validate_circuit!` can raise.

## #8 tolerances: OK, with one WARNING note
- `bloch.ex:76` `@epsilon 1.0e-6` sits at the permitted floor, so it is OK as a number. All test tolerances are 1.0e-6 or looser (`bloch_style_test.exs:488-502`, `markup_test.exs:228-229`, which is float64 math). `Markup @angle_tolerance 0.001`, `@hidden_epsilon 0.02`. The `-1.0e-9` at `bloch_style_test.exs:477` is an input value, not an assertion tolerance.
- WARNING note (REVIEW, not run): `bloch.ex:127` tests `sin(theta) < 1.0e-6` to snap a pole. θ = 2·acos(|α|) amplifies float32 noise: |α| = 1 − 6e-8 (one c64 ulp) gives θ ≈ 3.5e-4 and sin θ ≈ 3.5e-4, well above 1e-6. A near-pole c64 state, for example after `H·H`, will not snap, so φ is taken from noise (`arg(β) − arg(α)`) and printed in the readout. The arcs are hidden at 0.02, but the readout is not. A threshold in the 1e-3 range matches the float32 floor. The changelog claim "φ is 0 at a pole" holds only for exact poles.

## #9 dispatch completeness: OK
**Producers traced.**
- `Qx.Operations`/`QuantumCircuit.add_*` emit: `h x y z s sdg t tdg` as `{a,[q],[]}`; `rx ry rz phase` as `{a,[q],[θ]}`; `u` as `{:u,[q],[θ,φ,λ]}`; `cx cz swap iswap cy` as `{a,[c,t],[]}`; `cp crx cry crz` as `{a,[c,t],[θ]}`; `ccx cswap` as `{a,[3 qubits],[]}`; `{:barrier, qubits, []}`; `{:measure,[q,cbit],[]}` (`measure`, `measure_z`; `measure_x` emits `h` + measure and `measure_y` emits `sdg` + `h` + measure); `{:c_if,[bit,val],block}`.
- `Qx.Patterns` emit only `h x y z cx barrier measure` in those shapes (`bell_pair`, `ghz`, `cx_chain`, `*_all`, `barrier_all`, `measure_all`).
- `lowering.ex` `@stdgate_table` (lines 10-43) plus decompositions: `sx` gives `{:u,[q],[π/2,−π/2,π/2]}`; `u1` gives `:phase`; `u2` gives `:u`; `id` gives `[]`; `barrier` gives `{:barrier, idx, []}`; `measure` gives `{:measure,[qi,ci],[]}`; `if` gives `{:c_if,[ci,v],body}`. No atom outside the set above.

**Each atom, each of 27, has the three things.**
- (a) Theme `@gate_families` (`theme.ex:53-81`) has all 24 gate atoms (`x y z cx ccx cy cz h s sdg t tdg phase cp rx ry rz u crx cry crz swap iswap cswap`) plus `measure c_if barrier`.
- (b) `width/1` (`circuit.ex:243-253`):
  - `:barrier` has its own clause (0).
  - `:iswap` has its own clause.
  - The `@boxed` gates (`h x y z s sdg t tdg rx ry rz phase u`) go through `box_width`.
  - The `@controlled_boxes` gates (`cy cp crx cry crz`) use the box of the target gate.
  - Everything else (`cx ccx cz swap cswap measure`) falls to `@box`.
- (c) `draw/3` clauses and shape match:
  - `@boxed` matches `[qubit]`.
  - `:cx` matches `[c,t]`.
  - `:ccx` matches `[a,b,t]`.
  - `@controlled_boxes` matches `[c,t]` with params, and `params` is `[θ]` or `[]` for `cy`.
  - `:cz` and `:swap` match `[a,b]`.
  - `:cswap` matches `[c,ta,tb]`.
  - `:iswap` matches `[a,b]` (adjacent and non-adjacent).
  - `:measure` matches `[q,cbit]`.
  - `:barrier` matches any list (see W1 for the empty list).
  - `c_if` is flattened per gate in `flatten/1`, and `place/2` and `occupied_wires/2` handle the condition. Nested `c_if` and `measure` in a block are rejected with typed `ConditionalError`.
  - Param arity is not matched on: `angles/1` is generic, so `u` with 3 params, `rx` with 1 and `cp` with 1 are all fine.

**Reverse check (clauses for shapes nothing produces).** None found.
- `occupied_wires` has four clauses, each for a producible shape. The `condition:` clause comes after the `:barrier`/`:measure` clauses, and no order masks a real shape.
- Theme map entries `c_if`, `measure` and `barrier` are only used by the `validate_instruction!` fallback. `{:cz}` has a family (`:pauli`) that `draw` never reads, since CZ is drawn in ink. Harmless.
- The only dispatch gap is the one in W1/W2: an empty barrier and a hand-built wrong arity.

**Execution-test clause.** This branch adds no new producer shape, so the "at least one execution test per shape" requirement is not newly triggered. The simulation arms were covered by earlier work. `test/support/gate_catalogue.ex` plus `uncovered/0` and `qasm_atoms/0` is a good guard that every producer function is drawn through the real shape. Those are drawing tests, which by the law do not count for execution coverage.

## TDD rules: OK
- Rule 4: `lib/qx/draw.ex` has no `iex>`. `Qx.draw_circuit/2`'s new `iex>` example (`lib/qx.ex` ~1715-1721) is covered by `doctest Qx` (`test/qx_test.exs:3`, also `test/complex_support_test.exs:3`). `Qx.Draw.Image` and `Qx.Draw.StateTable` have directives in `test/qx/doctest_directives_test.exs`. The new modules (`Theme`, `Markup`, `Circuit`, `Bloch`, `VegaLite`) have no `iex>`.
- Rule 2: the five existing test files that were edited (`circuit_test.exs`, `iswap_svg_test.exs`, `cswap_svg_test.exs`, `u_svg_test.exs`, `quantum_circuit_instruction_order_test.exs`) were edited on approval. The plan records P0-T1 and P4-T5, approved by the user on 2026-11-19. The edits keep the assertions' intent (markup changes only).
- New tests exist for theme, markup, circuit style, Bloch style and chart style.

## VERIFICATION
Not run here (no shell). The plan P4-T4/T5 states: full suite 1800/1800, dialyzer clean, docs warnings the same as main. The orchestrator should confirm `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict` itself.

## Pre-existing (unchanged code)
- lib/qx/draw/svg/bloch.ex:120 — `[alpha, beta] = Nx.to_flat_list(qubit)` has no size or shape guard (see W4).
- lib/qx/draw.ex:127-129, 181-183, 228-230, 283-284 — a non-keyword `options` raises raw `FunctionClauseError`.
