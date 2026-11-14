## Requirements Coverage (from plan file `.claude/plans/circuit-instruction-append/plan.md`)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| G | Add is O(1); order unchanged for every consumer | MET | six producers prepend `quantum_circuit.ex` (diff @140,166,186,228,~240,~257); `get_instructions/1` reverses `quantum_circuit.ex:379`; order tests in new test file :70-156 pass (17/17 run) |
| S1 | quantum_circuit.ex: field, type, six add_*, new/2, reset/1, depth/1, get_instructions/1, put_instructions/2 | MET | all in diff; `put_instructions` :388, `depth` :408, `reset` :446 |
| S2 | All lib readers/writers moved (operations, simulation x2, draw x3, openqasm x2, lowering, qx.ex doc) | MET | grep of lib: no `.instructions`/`reversed_instructions` outside quantum_circuit.ex. Remaining hits are lowering's own `state.instructions` accumulator and the draw diagram map key `circuit.ex:182`, neither the struct field |
| S3 | One new test file + mechanical edits to 8 existing files | MET | new file 17 tests; 8 test files in diff |
| S4 | CHANGELOG | MET | see D5 |
| Out | Out-of-scope items untouched | MET | `measurements ++` still at quantum_circuit.ex (diff @228 context); `git diff main` on codegen.ex, mix.exs, spec/, ROADMAP.md is empty; no Inspect impl (grep); no facade accessor (lib/qx.ex change is one doc line) |
| D1 | Field `reversed_instructions`, `instructions` key removed | MET | `quantum_circuit.ex` defstruct/type (diff @33,42); test `quantum_circuit_instruction_order_test.exs:167` |
| D2 | One read path, one bulk write path, only QuantumCircuit names field; depth uses length | MET | `quantum_circuit.ex:379,388,408`; grep confirms no other module names it |
| D3 | Each consumer reads once; has_conditionals? via any_instruction?/2 | MET | `simulation.ex` has_conditionals? uses `any_instruction?`; timeline reads once; `draw/svg/circuit.ex:73-74` one read in `render/2`; `openqasm.ex` generator reads once and version check uses `any_instruction?` |
| D4 | c_if keeps capture; body in circuit order | MET | `operations.ex:842-848` put_instructions([]) / get_instructions; tests `..order_test.exs:43,200,216` |
| D5 | CHANGELOG: breaking Changed + migration; Performance with re-measured numbers; ROADMAP deferred | MET | Changed (breaking, migration, KeyError note) CHANGELOG.md:10-25 (under Unreleased/Changed, line 10); Performance entry under `### Performance` (line 55) with 0.06 ms / 0.6 ms / 3.6 ms / 7.6 ms; ROADMAP.md unchanged as expected |
| D6 | measurements left alone, flagged | MET | untouched; recorded scratchpad "Out of scope"; CHANGELOG notes measurements list unchanged |
| D7 | No custom Inspect, flagged | MET | no Inspect impl; CHANGELOG notes inspect shows newest first |
| D8 | Complexity test w/o tight timing; metric chosen on measurements | PARTIAL | Deterministic reductions metric used (test :231-270), numbers in scratchpad 67-100. Deviates from D8's first choice (whole build, 20k gates), but the deviation is recorded in the 1.5 note and scratchpad (42x, rejected) and stays within D8's intent (deterministic count, >=10x margin both sides: 1,654 vs limit 140 vs 8.64 post-change). Status PARTIAL only for literal deviation |
| D9 | No new dependency | MET | mix.exs unchanged |
| 1.1 | Order via get_instructions, all producer kinds, exact tuples, c_if body order | MET | `..order_test.exs:43-67` (all 7 kinds), :65 empty |
| 1.2 | Consumer order tests: run, steps, to_qasm, import | MET | :71, :84, :108, :118. Extras (confirmed): conditional run :77, conditional steps :95, round trip :142, draw :151 (8 tests as claimed) |
| 1.3 | Struct contract tests | MET | :167 (no field), :171 (put/get round trip + append), :184 depth, :190 reset (4 tests as claimed) |
| 1.4 | c_if with multi-gate fn and prior instructions | MET | :200, :216 |
| 1.5 | Complexity test, measured, 10x margin, numbers in scratchpad | MET | test :246-270 (limit 140, `@tag timeout`); scratchpad 67-112 |
| 1.6 | Red run recorded | MET (claim unverifiable now) | scratchpad 134-142 records 14 pass/3 fail; cannot re-run red against old code; current file passes 17/17 (run just now) |
| 2.1 | quantum_circuit.ex changes, comment block, moduledoc | MET | moduledoc "Reading the instructions" :~12-26 with doctest; comment block diff @114; `any_instruction?` :398 |
| 2.2 | operations.ex c_if and final_step | MET | `operations.ex:842,848,1058` |
| 2.3 | simulation.ex has_conditionals? + timeline reads once | MET | `simulation.ex` ~655, ~695 |
| 2.4 | draw (3 sites, shared read) and openqasm (2 heads) | MET | `draw/svg/circuit.ex:73-74,82,160`; `openqasm.ex:219-221,272-275` |
| 2.5 | lowering uses put_instructions | MET | `lowering.ex:104` |
| 2.6 | grep clean, warnings-as-errors | MET (grep verified) | grep result above; compile not re-run |
| 2.7 | Iron Law #9 trace; tuples unchanged | MET | diff builds the same tuples in all six producers; only the cons/append changed |
| 3.1 | Reads converted (22) | MET | lowering 17, import 2, codegen 1, round_trip 1, steps 1 per diff |
| 3.2 | Writes converted (10 incl. steps:88) | MET | typed_errors 5, openqasm_test 1, round_trip 1, sweep 2, steps 1 |
| 3.3 | Access-path-only, no assertion value changed | MET | every changed test line in the diff swaps `x.instructions` for `get_instructions(x)` or `%{qc \| instructions: l}` for `put_instructions(qc, l)`; expected values identical. Two reformatted blocks (sweep tests restructure struct literal to `put_instructions(%QuantumCircuit{...}, list)`; steps:88 splits one expression across lines) are still access-path only |
| 4.1/4.3 | docs warning baseline | UNCLEAR | `mix docs` not re-run; cannot verify from diff |
| 4.2 | Docs updates: moduledoc, get_instructions, reset doctest, tap_circuit x2 | MET | `quantum_circuit.ex` doc diffs; `operations.ex:909`; `qx.ex:1885` (uses `depth(c)`) |
| 4.4 | CHANGELOG re-measured table | MET | CHANGELOG.md Performance entry; figures match scratchpad 106-108 |
| 4.5 | Full verification; offer mix bench | UNCLEAR | compile/format/credo/full suite not re-run by me; new file re-run 17/17 |
| R | Risks mitigations (old key removed; per-call O(n) sites checked; downstream noted) | MET | KeyError via removed key; call sites checked under D3; CHANGELOG migration |

### Beyond-plan changes and deviations
- Timeline hoisted out of the per-shot loop (`simulation.ex` run_with_conditionals, `execute_single_shot/3` now takes `timeline`): not asked for in tasks, but recorded in the 2.3 note, directly serves D3 (avoids re-reversing per shot) and does not change behaviour. Within intent.
- Extra tests in 1.2 (conditional run/steps, round trip, draw): recorded in the 1.2 note; additive; within intent.
- D8 metric (marginal reductions, gates 50,001-100,000, limit 140) instead of whole-build 20k: recorded in 1.5 note and scratchpad with data. Within intent.
- Moduledoc doctest and a second `get_instructions` doctest added (doctests 130 to 132, recorded 4.2): small extra, within the doc task.
- `reset/1` doctest edited (existing doctest, necessary to compile): recorded in 2.1.
- Plan's test-count mismatch (steps:88 is read and write): recorded in scratchpad and 3.2 note.
- Nothing from the Scope "Out" list was changed.

**Summary**: 31 MET . 1 PARTIAL (D8, literal deviation only) . 0 UNMET . 2 UNCLEAR (docs warning baseline, full verification not re-run)
