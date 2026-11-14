# Plan: O(1) instruction append in `Qx.QuantumCircuit`

**Branch:** `fix/circuit-instruction-append`
**ROADMAP:** v0.12 — "Replace `instructions ++ [new]` quadratic append in
`Qx.QuantumCircuit` with prepend + reverse-on-finalise" (audit: perf HIGH)
**Depth:** standard
**Complexity:** 6 (4+ files across QuantumCircuit / Operations / Simulation /
Draw / Export +3, tier 1 public API change +3)

## Goal

Adding an instruction to a circuit is O(1) instead of O(n), so building a
circuit of n instructions is O(n) instead of O(n²). Instruction order, as seen
by every consumer (run, steps, draw, export, `get_instructions/1`), is
unchanged.

Measured today (2026-11-14, `Qx.h/2` in a loop on a 4-qubit circuit):

| Instructions | Current (`++`) | Prepend |
|---|---|---|
| 1,000 | 1.2 ms | < 0.1 ms |
| 10,000 | 142 ms | 0.4 ms |
| 50,000 | 4.8 s | 1.9 ms |
| 100,000 | 19.2 s | 2.5 ms |

User decision (2026-11-14): **rename the field.** The public `instructions`
field is replaced by an internal newest-first field, and
`Qx.QuantumCircuit.get_instructions/1` is how the list is read in order.
Breaking, but old code fails loudly.

## Scope

**In:**
- `lib/qx/quantum_circuit.ex`: struct field, type, the six `add_*`
  producers, `new/2`, `reset/1`, `depth/1`, `get_instructions/1`, a new
  internal `put_instructions/2`.
- Every `lib/` reader or writer of the field: `lib/qx/operations.ex`
  (`c_if/4`, `tap_circuit` doc, line ~1058), `lib/qx/simulation.ex` (2
  sites), `lib/qx/draw/svg/circuit.ex` (3 sites),
  `lib/qx/export/openqasm.ex` (2 sites),
  `lib/qx/export/openqasm/lowering.ex` (1 site), `lib/qx.ex` (1 doc example).
- One new test file. Mechanical edits to 8 existing test files (listed in
  Phase 3; approved by the user on 2026-11-14 for the field rename only).
- `CHANGELOG.md`.

**Out (see scratchpad):**
- `circuit.measurements ++ [measurement]` (`quantum_circuit.ex:208`). Same
  pattern on another public field; not named in the ROADMAP item. **Flagged
  for the user** (D6).
- `acc ++ [line]` / `acc ++ [name]` in `lib/qx/export/openqasm/codegen.ex`
  (lines 115, 171).
- A custom `Inspect` for `Qx.QuantumCircuit` (D7).
- A `Qx.*` facade accessor for instructions.
- Historical `spec/*_SUMMARY.md` files that mention `c.instructions`.
- Version bump (release step).

## Decisions

- **D1 — field name `reversed_instructions`,** a list, newest first. The
  `instructions` key is removed from the struct, so `qc.instructions` raises
  `KeyError` and `%Qx.QuantumCircuit{instructions: ...}` fails to compile.
  Rejected: keeping the name with reversed contents (silent wrong gate
  order for any reader or hand-built struct).
- **D2 — one read path, one bulk write path, both in `Qx.QuantumCircuit`.**
  `get_instructions/1` (existing, public) returns the list in circuit order
  (`Enum.reverse/1`, O(n) per call). New `put_instructions/2` (`@doc false`)
  takes a list in circuit order and stores it. No other module names the
  field. `depth/1` uses `length/1` on the field directly.
- **D3 — each consumer reads once.** `get_instructions/1` is O(n), so a
  consumer binds its result once per call and never calls it inside a loop
  over instructions. `Qx.Simulation` has two readers on one run path
  (`has_conditionals?/1` and `create_instruction_timeline/1`):
  `has_conditionals?/1` is order-independent and scans the field through a
  second internal helper, `QuantumCircuit.any_instruction?/2` (`@doc false`),
  without reversing.
- **D4 — `c_if/4` keeps its capture approach.** It clears the instructions
  with `put_instructions(circuit, [])`, runs the caller's function, and reads
  the body with `get_instructions/1`. Body order inside the
  `{:c_if, [bit, value], body}` tuple stays circuit order: instruction
  shapes do not change (Iron Law #9).
- **D5 — breaking change, tier 1 (Iron Law #6).** `CHANGELOG.md` Unreleased →
  "Changed" entry marked breaking, with the migration
  (`qc.instructions` → `Qx.QuantumCircuit.get_instructions(qc)`), plus a
  "Performance" entry with the table above re-measured. The ROADMAP v0.12
  intro ("one breaking change") is amended in the squash-merge commit with
  the item tick.
- **D6 — `measurements` is left alone.** It has the same `++` and is also a
  public field. 5,000 `Qx.measure/3` calls cost 310 ms today, part from each
  list. Measurements per circuit are few in practice. **Flagged for the
  user:** say so to add it (same rename treatment, or a separate item).
- **D7 — no custom `Inspect`.** `inspect(circuit)` will show
  `reversed_instructions:` newest first. The field name says so. **Flagged
  for the user.**
- **D8 — the complexity claim is tested without a tight timing threshold.**
  Task 1.5 measures candidate metrics on current code and picks one. First
  choice is a deterministic count (process reductions for a 20,000-gate
  build). Fallback is wall-clock on 50,000 gates (4.8 s today vs 1.9 ms
  prepend) with a budget at least 10× from both sides. Numbers go in the
  scratchpad.
- **D9 — no new dependency** (research). `:queue` and `:array` are opaque
  and not lists; the Hex candidates are unmaintained or NIFs.

## Phase 1 — Tests first (red)

New file `test/qx/quantum_circuit_instruction_order_test.exs`, `async: true`.

- [x] 1.1 Order through `get_instructions/1`: a circuit built with one of each
  producer kind through the public API (`h`, `rx`, `cx`, `ccx`, `measure`,
  `barrier`, `c_if`) returns its instructions in call order, with the exact
  tuples. The `c_if` body is in call order inside its tuple. These pass
  today (characterization).
  — done: 2 tests (all seven producer kinds; empty circuit).
- [x] 1.2 Order at each consumer, on an order-sensitive circuit (for example
  `x(0) |> cx(0, 1)` gives `|11⟩`; the reverse order gives `|01⟩`):
  `Qx.run/2` probabilities, `Qx.steps/2` step sequence, `Qx.to_qasm` line
  order (use the real exporter name), and an OpenQASM import whose
  `get_instructions/1` matches source order. Pass today.
  — done: 8 tests. Added beyond the plan: `run/2` and `steps/2` on the conditional (timeline) path, a QASM round trip, and `Qx.draw_circuit/1` gate x-positions.
- [x] 1.3 Struct contract: `Map.has_key?(circuit, :instructions)` is false;
  `put_instructions/2` followed by `get_instructions/1` round-trips a list;
  `depth/1` counts; `reset/1` empties. The first two FAIL today.
  — done: 4 tests; the put+append check is folded into the round-trip test so two tests fail, as planned.
- [x] 1.4 `c_if/4` with a caller function that adds several gates, and a
  circuit that already has instructions before the `c_if`: earlier
  instructions are kept, the body has only the new ones. Passes today.
  — done: 2 tests (earlier instructions kept + gate after the block; two blocks).
- [x] 1.5 Complexity test (D8). Measure on current code and on a prepend
  proxy: reductions and wall-clock for 20,000 and 50,000 gates, three runs
  each, fresh VM. Choose the metric and threshold with at least 10× margin
  on both sides; record all numbers in the scratchpad. If no metric gives
  that margin, stop and report. The test FAILS today.
  — done: metric is reductions per gate for gates 50,001–100,000, limit 140 (today 1,654; per-call cost without the list 10.5). Whole-build reductions at 20,000 gave only 42×, so the plan's first choice was replaced by the marginal form. Numbers in scratchpad.
- [x] 1.6 Run the new file. Confirm 1.3 (two tests) and 1.5 fail and the
  rest pass. Record the red summary in the scratchpad.
  — done: 14 pass, 3 fail (1.3 ×2, 1.5), 19.5 s.

## Phase 2 — Implementation (green)

- [x] 2.1 `lib/qx/quantum_circuit.ex`: rename the field and type (D1);
  `[instruction | circuit.reversed_instructions]` in all six `add_*`
  functions; `new/2`, `reset/1`; `get_instructions/1` reverses;
  `depth/1`; add `put_instructions/2` and `any_instruction?/2` (D2, D3).
  Update the producer-surface comment block and the moduledoc.
  — done. Field `reversed_instructions`; six producers prepend; `get_instructions/1` reverses; `put_instructions/2` and `any_instruction?/2` added (`@doc false`, with specs). Moduledoc gained a "Reading the instructions" section with a doctest; the `reset/1` doctest now reads through `get_instructions/1` (it had to change here to compile).
- [x] 2.2 `lib/qx/operations.ex`: `c_if/4` per D4; line ~1058 through
  `any_instruction?/2`.
  — done. `c_if/4` uses `put_instructions(circuit, [])` and `get_instructions/1`; `final_step/2` uses `any_instruction?/2`.
- [x] 2.3 `lib/qx/simulation.ex`: `has_conditionals?/1` through
  `any_instruction?/2`; `create_instruction_timeline/1` reads once (D3).
  — done. `has_conditionals?/1` through `any_instruction?/2`. Beyond the plan: `run_with_conditionals/3` now builds the timeline once and passes it to `execute_single_shot/3`; before, it was rebuilt (and would now be re-reversed) on every shot.
- [x] 2.4 `lib/qx/draw/svg/circuit.ex` (3 sites) and
  `lib/qx/export/openqasm.ex` (2 function heads that pattern-match the
  field): read through `get_instructions/1`, once per function. In
  `circuit.ex`, check whether the three sites are on one call path and
  share one read if so.
  — done. `circuit.ex`: the three sites are on one call path (`render/2`), which reads once and passes the list to `validate_circuit!/2` and `analyze_circuit/3`. `openqasm.ex`: the version check uses `any_instruction?/2`, the generator reads once.
- [x] 2.5 `lib/qx/export/openqasm/lowering.ex`: build the circuit with
  `put_instructions/2`.
  — done. `build_circuit/1` uses `put_instructions/2`.
- [x] 2.6 `grep -rn "instructions" lib` and confirm no reference to the old
  field remains outside `quantum_circuit.ex`. `mix compile
  --warnings-as-errors` (the compiler flags unknown struct keys).
  — done. No reference to the field outside `quantum_circuit.ex`; `lowering.ex` keeps its own `state.instructions` map key. `mix compile --warnings-as-errors` clean. Two doc examples still say `.instructions` (4.2).
- [x] 2.7 Iron Law #9 trace: for each producer shape in the `add_*` surface,
  follow one real output into `Qx.Simulation`'s dispatch by hand and confirm
  the shape is unchanged. Re-run the new test file to green.
  — done. Traced `{:h,[0],[]}`, `{:cx,[0,1],[]}`, `{:ccx,[0,1,2],[]}` (arity dispatch in `apply_instruction/3`), `{:barrier,qubits,[]}` (`apply_gate_step/5` head), `{:measure,[q,c],[]}` (timeline arm; `:measure` arm of `apply_two_qubit_op/5` on the non-conditional path), `{:c_if,[bit,value],body}` (timeline arm → `step_conditional/7`, body in order). No tuple construction changed in the diff. New file: 17 pass, 0.1 s. Post-change cost: 8.64 reductions per gate (limit 140).

## Phase 3 — Existing tests (approved mechanical edits only)

The user approved editing existing tests for the field rename on 2026-11-14.
Only the access path changes; no assertion changes value. If a test needs
any other change to pass, stop and report.

- [x] 3.1 Reads, `x.instructions` → `Qx.QuantumCircuit.get_instructions(x)`:
  `test/qx/export/openqasm/lowering_test.exs` (17),
  `test/qx/export/openqasm_import_test.exs` (2),
  `test/qx/export/openqasm/codegen_test.exs` (1),
  `test/qx/export/openqasm/round_trip_test.exs` (1),
  `test/qx/simulation_steps_test.exs` (1).
  — done: 22 reads across the five files (`lowering_test.exs` 17, `openqasm_import_test.exs` 2, `codegen_test.exs` 1, `round_trip_test.exs` 1, `simulation_steps_test.exs` 1).
- [x] 3.2 Hand-built circuits, `%{qc | instructions: list}` →
  `Qx.QuantumCircuit.put_instructions(qc, list)`:
  `test/qx/simulation_typed_errors_test.exs` (5),
  `test/qx/export/openqasm_test.exs` (1),
  `test/qx/export/openqasm/round_trip_test.exs` (1), and the two struct
  literals in `test/qx/typed_errors_sweep_test.exs` (lines 103, 114).
  — done: 10 writes (`simulation_typed_errors_test.exs` 5, `openqasm_test.exs` 1, `round_trip_test.exs` 1, `typed_errors_sweep_test.exs` 2, and the write half of `simulation_steps_test.exs:88`, which the plan had counted only as a read).
- [x] 3.3 `mix test` (full suite, including `doctest Qx` and
  `doctest Qx.QuantumCircuit`). List every existing test file touched, with
  line counts, in the scratchpad.
  — done: 1,572 passed (330 doctests, 1,242 tests), 2.8 s. No assertion value changed. The guard hook did not fire (stale path, see scratchpad).

## Phase 4 — Docs and wrap-up

- [x] 4.1 `mix docs` warning baseline before doc edits (stash method from
  `AGENTS.md`).
  — done: 12 distinct warning lines on the pre-change tree (stash method).
- [x] 4.2 Docs: `Qx.QuantumCircuit` moduledoc (how to read instructions),
  `get_instructions/1` (returns circuit order; O(n)), the `reset/1` doctest
  (`length(qc_reset.instructions)`), the `tap_circuit` examples in
  `lib/qx/operations.ex` (~909) and `lib/qx.ex` (~1885). Check whether each
  example is an `iex>` doctest and that the doctest counts do not drop.
  — done. `tap_circuit` examples: `lib/qx/operations.ex` now uses `get_instructions(&1)` (an `iex>` example already in the `doctest` `:except` list, so never run); `lib/qx.ex` uses `Qx.QuantumCircuit.depth(c)` (not an `iex>` example). Doctests in the four doctest-bearing files went 130 → 132 (the two new ones in `Qx.QuantumCircuit`).
- [x] 4.3 `mix docs` again; warning list ≤ baseline (diff the lists).
  — done: warning list identical to baseline (`diff` empty).
- [x] 4.4 `CHANGELOG.md` per D5, with the build-time table re-measured on the
  new code.
  — done: Changed (breaking, with migration) + Performance (re-measured: 0.06 ms / 0.6 ms / 3.6 ms / 7.6 ms for 1k / 10k / 50k / 100k gates).
- [x] 4.5 Full verification (below), then stop for `/phx:review` (merge
  gate). ROADMAP tick and intro amendment go in the squash-merge commit.
  Offer `mix bench`: `lib/qx/simulation.ex` is touched.
  — verification done 2026-11-14: compile `--warnings-as-errors` clean, format clean, credo `--strict` no issues (114 files), `mix test` 1,572 passed (330 doctests, 1,242 tests). Review and the merge gate follow; `mix bench` still to be offered.

## Risks

- **A missed reader runs gates backwards.** Mitigated by removing the old
  key (compile error or `KeyError`, not a silent reversal), the grep in 2.6,
  and the consumer-order tests in 1.2.
- **`get_instructions/1` is now O(n) per call.** A consumer that calls it
  per instruction would reintroduce O(n²). D3 and the review should check
  each call site.
- **Downstream.** `kino_qx` and `qxportal` do not read the field or call
  `get_instructions/1` (grep of `.ex`, `.exs`, `.livemd`, `.md`, `.heex` on
  2026-11-14). Neither repo is tested by this plan. User code that reads
  `qc.instructions` breaks; the CHANGELOG gives the replacement.
- **Second breaking change in v0.12.** Accepted by the user's choice; both
  ride the same minor bump.
- **Complexity test stability (D8).** If reductions do not separate the two
  implementations, the fallback is a wall-clock budget, which is
  load-sensitive. The 10× margin and three-run measurement are the
  mitigation; if it cannot be made robust, say so rather than loosen it.
- **Test-file guard hook.** It may block `Edit` on existing `*_test.exs`.
  If it does, stop and ask.

## Verification

```
mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test
```
