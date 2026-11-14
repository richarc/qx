## Requirements Coverage (from Plan .claude/plans/host-side-state-lists/plan.md)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| Goal | basis_state and from_counts build 2^n tensors with Nx, no host list | MET | `state_init.ex:73-80`, `result_builder.ex:44-66` |
| D1 | `Nx.indexed_put` onto zero broadcast, both functions | MET | `state_init.ex:77-79`, `result_builder.ex:49,56-60` |
| D2 | basis_state/3 with real type returns one-hot tensor | MET | `state_init.ex:77-79` (type passed through); tests `host_side_state_lists_test.exs:85,92` |
| D3 | invalid type keeps the same ArgumentError | MET | test `:79`; no handling added in `state_init.ex` |
| D4a | pairs with index >= size dropped (filter first) | MET | `result_builder.ex:51`; test `:115` |
| D4b | empty pair list returns f32 zeros | MET | `result_builder.ex:52-54`; test `:108` |
| D4c | result stays f32 (cast updates) | MET | `result_builder.ex:59` `type: :f32`; test `:101` |
| D4d | duplicates last-write-wins, no indexed_add | MET | `result_builder.ex:56` uses indexed_put; test `:121` |
| D5 | pow sweep uses `Integer.pow(2, n)`; `bsl` exception for valid_register? | MET | 13 sites `Integer.pow`; `validation.ex:68` `Bitwise.bsl(1, n)`; CHANGELOG makes no correctness claim |
| 1.1 | basis_state characterisation tests | MET | `test:57-84` (5 tests) |
| 1.2 | real-type tests (f32, s32) | MET | `test:85,92` |
| 1.3 | from_counts characterisation (f32, empty, dropped, same index) | MET | `test:101,108,115,121` |
| 1.4 | heap-limit tests plus control, measured limit with comment | MET | `test:131-152`, `max_heap_size` at `:30`; measured numbers are in progress.md and the plan note (I did not re-check the comment text) |
| 1.5 | valid_register? negative num_qubits pin | MET | `test:154-155` |
| 1.6 | red run recorded in progress.md | MET | progress.md records the 4 expected failures |
| 2.1 | state_init valid clause replaced, guards and fallback untouched | MET | `state_init.ex:73-80`; `Complex` alias kept since deprecated fns use `C.new` (`:217,254`) |
| 2.2 | build_probability_tensor rewritten per D1 and D4 | MET | `result_builder.ex:44-66` |
| 2.3 | targeted tests green, doctest count unchanged | MET | host-side test file re-run: 14 passed; doctest count not re-verified |
| 3.1 | 14 sites replaced | MET | gates 5 (`:332,407,454,500,541`), validation 1, quantum_circuit 3 (`:79,320,443`), state_init 5 (`:131,217,250,389,425`) = 14 (13 `Integer.pow` + 1 `bsl`) |
| 3.2 | `grep ":math.pow(2" lib` empty | MET | grep of `math.pow` finds only `draw/tables.ex:79`, `:math.pow(Complex.abs(amp), 2)`, which is a different pattern and not in scope |
| 3.3 | full suite | UNCLEAR | not re-run by me; progress.md claims 1586 passed |
| 4.1 | CHANGELOG with measured numbers under unreleased 0.12; D2 recorded; no version bump | MET | `CHANGELOG.md` diff: 227 ms to 4.7 ms, 111 ms to 11 ms, D2 under Fixed; matches progress.md and plan 4.1 notes. Plan said "Changed" but the note records the Fixed placement as intentional |
| 4.2 | verification gate, stop for review | UNCLEAR | gate results are only recorded in progress.md; not re-run |
| Scope In | one new test file | MET | `test/qx/host_side_state_lists_test.exs` untracked and new |
| Scope In | CHANGELOG edited | MET | `CHANGELOG.md` modified |
| Scope In | ROADMAP ticks at merge | NOTE | `ROADMAP.md:33,38` still `[ ]`, deferred to the squash commit by design; not UNMET |
| Scope Out | deprecated StateInit fns get only the pow swap | MET | diff at `state_init.ex:217,250,389,425`: one-line swaps only, list builds untouched |
| Scope Out | Gates host-loop builders pow swap only | MET | `gates.ex` diff: 5 one-line changes |
| Scope Out | no existing test file edited | MET | `git diff --name-only main` lists no `test/` file; `git status` shows only the new test file |
| Scope Out | `simulation.ex` untouched | MET | not in diff; no `:math.pow` in it |

**Checks**
- Site count: 14 swapped, 0 remaining `:math.pow(2` in `lib`.
- CHANGELOG says "(14 sites)", which is accurate (13 `Integer.pow` + 1 `bsl`); the entry does not mention the `bsl` special case.
- CHANGELOG numbers match progress.md and the plan 4.1 note (227 ms, 4.7 ms, 111 ms, 11 ms, under 1,600 words, over 41M words).
- The CHANGELOG says "Internal:" under the performance section, which is consistent with D5.

**Not requested but present**
- Code comments added in `state_init.ex`, `result_builder.ex` and `validation.ex` (mild "Iron Law #5" references in comments).
- A CHANGELOG bullet about `Qx.Hardware` results. It is derived from the `from_counts` change and is in scope.
- Nothing else beyond the plan.

## Requirements Coverage

**Summary**: 25 MET · 0 PARTIAL · 0 UNMET · 2 UNCLEAR (3.3 and 4.2 were not re-run). Notes: ROADMAP ticks deferred, as planned.
