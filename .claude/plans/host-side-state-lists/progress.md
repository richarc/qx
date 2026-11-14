# Progress: host-side-state-lists

## 2026-11-14

Phase 1 (red), `mix test test/qx/host_side_state_lists_test.exs` on unchanged `lib/`:
4 failures, all expected.
- basis_state/2 at dimension 2^20 within the heap limit: `:killed`
- from_counts/3 at 20 bits within the heap limit: `:killed`
- basis_state(1, 4, :f32): `CaseClauseError`
- basis_state(1, 4, :s32): `ArgumentError`
The characterisation tests, the control and the `valid_register?/2` pin passed.

Heap probes (cold VM, fresh `mix run` per probe, 2^20 elements):
- indexed_put basis state: killed at 1,500 words, survives at 1,598
- indexed_put probabilities: killed at 1,500, survives at 1,598
- current `basis_state/2`: killed at 41,523,437, survives at 44,640,625
- current `from_counts/3`: killed at 22,820,312, survives at 24,378,906

Phases 2 to 4: all tasks done. Final gate: compile (warnings as errors),
format, credo --strict clean; `mix test` 1586 passed (330 doctests, 1256 tests).

Not done: `/phx:review` (merge gate), ROADMAP ticks, commit, push.
