## Requirements Coverage (from Plan .claude/plans/draw-state-size-cap/plan.md)

**Summary**: 24 MET · 3 PARTIAL (2.2, 2.3, 2.4: recorded deviations, intent met) · 0 UNMET · 2 UNCLEAR (1.6 red run, 3.1/3.4 docs-warning baseline: unverifiable claims)

`mix test test/qx/draw_size_cap_test.exs` re-run: 59 passed.

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| Goal | Draw functions refuse > 2^12 bars/rows with a typed error naming the override; <= 12 qubits unchanged | MET | guards `draw.ex:89,137,178`, `tables.ex:65`; boundary tests `draw_size_cap_test.exs:154-177` |
| Scope In | errors, validation, draw, tables, qx docs, mix.exs, one test file, CHANGELOG, one README line | MET | all 8 tracked files + new test are in the diff; nothing else |
| D1 | Measure `Nx.size` (plot/histogram/state_table), `map_size(counts)`; raise when size > 2^max_qubits | MET | `draw.ex:89,178,137`; `tables.ex:65`; `validation.ex:253-258` |
| D2 | Default max_qubits 12 | MET | `validation.ex:6`; 4096 boundary tests `draw_size_cap_test.exs:156` |
| D3 | `:max_qubits` positive integer, else `Qx.OptionError{option: :max_qubits}` "Expected a positive integer."; validated even for small input | MET | `validation.ex:241-246`; tests `draw_size_cap_test.exs:194-205` (4 functions x 5 values, size 4) |
| D4 | `Qx.DrawSizeError` with fields `:size,:limit,:max_qubits,:message`; exact message; smallest suggested value | MET | `errors.ex:182-232` (fields :213, message :230-231, `qubits_to_hold` integer math); exact string asserted `draw_size_cap_test.exs:135-137`; 8193 -> 14 at :141-144 |
| D5 | `counts/2` capped on `map_size(result.counts)`; 20-qubit GHZ still draws | MET | `draw.ex:137`; `draw_size_cap_test.exs:123-130,186-190` |
| D6 | Guard after `ensure_vega_lite!`, before `VL` call; state_table inside `Tables.render/2` after unwrap, before `build_table_data`; hide_zeros does not bypass | MET | `draw.ex:88-89,136-137,177-178` (histogram guard before its `Nx.to_flat_list` at :183); `tables.ex:65` precedes `build_table_data` at :67 (after Register deprecation/RegisterError unwrap at ~:48-60); hide_zeros test `draw_size_cap_test.exs:147-151,179-184`; `Draw.state_table` delegates to `render` unchanged |
| D7 | Guard-before-build tested with `:max_heap_size` on 2^20 tensor, no timing | MET | `draw_size_cap_test.exs:79-109,208-225` incl. control test killing `Nx.to_flat_list` |
| D8 | Breaking change entry in CHANGELOG Unreleased/Changed; ROADMAP intro amended in squash commit | MET | `CHANGELOG.md:10-28` ("**Breaking:**"); ROADMAP.md not in diff (deferred by plan) |
| D9 | No new dependency | MET | `mix.exs` diff is the single docs-group line only |
| 1.1 | Default-cap error for 4 functions; fields, `max_qubits: 13` in message | MET | `draw_size_cap_test.exs:112-130` |
| 1.2 | Boundary 4096, override 13, `max_qubits: 2` lowers limit | MET | `draw_size_cap_test.exs:154-177` |
| 1.3 | Option validation values 0,-1,1.5,:all,"13" on all four, small input | MET | `draw_size_cap_test.exs:193-206` |
| 1.4 | Guard-before-build for plot/histogram/state_table; measurements recorded | MET | test `:208-225`; numbers in scratchpad.md "Measurements" (2^17 words; 562x/576x margins). Measurement itself not re-verifiable from code |
| 1.5 | Facade four functions and Register path capped after deprecation warning | MET | `draw_size_cap_test.exs:227-263` |
| 1.6 | Red run recorded | UNCLEAR | scratchpad.md "Task 1.6" claims 20/59 passed; cannot be verified from the final code |
| 2.1 | `Qx.DrawSizeError` with moduledoc, integer-only suggestion, in mix.exs group | MET | `errors.ex:182-232`, `qubits_to_hold` `:259`-area via `Integer.digits`; `mix.exs:122`; `Qx.Error` moduledoc `errors.ex:11` |
| 2.2 | `validate_max_qubits!/1`, `validate_draw_size!/2`, `@doc false`, multi-clause | PARTIAL | DEVIATION: comparison is `Bitwise.bsr(size - 1, max_qubits) > 0` (`validation.ex:256-257`) instead of `size > bsl(1, max_qubits)`; `bsl` used only for `:limit` (`errors.ex:~207`). Extra `draw_max_qubits!/1` (`:233`). Intent met: same result, avoids bignum for huge max_qubits; tested at `draw_size_cap_test.exs:174-176`. size 0 passes (`bsr(-1,n)` = -1) |
| 2.3 | Draw reads `:max_qubits`, default from one module attribute in Qx.Draw, validates, guards per D6 | PARTIAL | DEVIATION: attribute is `@default_draw_max_qubits` in `Qx.Validation` (`validation.ex:6`), read via `draw_max_qubits!/1`; `Qx.Draw` has a private `validate_size!` (`draw.ex:312`). Intent (one shared default, validated, guarded) met |
| 2.4 | Tables guard, default shared with Qx.Draw rather than repeating 12 | PARTIAL | DEVIATION: shared via `Qx.Validation` (`tables.ex:65`), not via `Qx.Draw`, to avoid a new tables->draw edge. No repeated literal 12 (only `validation.ex:6`). Intent met |
| 2.5 | Hand trace + green | MET | guards precede every `Nx.to_flat_list` (`draw.ex:183`) and `VL` call; 59 passed (re-run) |
| 2.6 | Full suite, compile, format, credo; no existing test touched | MET (partly claim) | no test file other than the new one in diff; full-suite/credo results are claims, not re-run here |
| 3.1/3.4 | `mix docs` warning baseline and diff | UNCLEAR | not re-run; scratchpad claim only. (Counted above as part of UNCLEAR only for 1.6; treat 3.1/3.4 as unverified claims) |
| 3.2 | `:max_qubits` Options + Raises in Draw plot/counts/histogram/state_table, moduledoc, 4 facade docs, hide_zeros note, Tables.render doc | MET | `draw.ex:30-41` moduledoc; `:67-78` plot, `:111-124` counts, `:156-167` histogram, `:242-258` state_table; `qx.ex:1438-1449` draw, `:1476-1495` draw_counts, `:1523-1548` draw_histogram, `:1618-1632` draw_state (hide_zeros note :1619-1623); `tables.ex:20-33` |
| 3.3 | One README line, 12-qubit default and `max_qubits:` | MET | `README.md:381` |
| 3.5 | CHANGELOG Changed (breaking) + Added `Qx.DrawSizeError` | MET | `CHANGELOG.md:10-36` |
| 3.6 | Final verification, stop before review, ROADMAP untouched | MET | ROADMAP.md absent from diff |

## Deviations (tasks 2.2, 2.3, 2.4)

1. 2.2: `bsr(size - 1, max_qubits) > 0` rather than `size > bsl(1, max_qubits)`. Intent (cap at 2^max_qubits, no raw system-limit error for huge values) is met; behaviour identical for all sizes >= 1.
2. 2.3: default attribute lives in `Qx.Validation`, not `Qx.Draw`. Intent (one source of the default) met.
3. 2.4: Tables shares the default through `Qx.Validation`, not `Qx.Draw`. Intent (no repeated literal) met; rationale is the tables->draw cycle.

## Scope "Out" check

All confirmed unchanged: `lib/qx/step.ex` not in diff; `:math.pow` in `tables.ex` untouched (diff hunks only add alias, docs, guard); no `bloch/2` or `circuit/2` code change (only a moduledoc sentence); `mix.exs` version unchanged (one docs-group line); ROADMAP.md not in diff. No existing test modified (only the new untracked test file).

## Not asked for by the plan (minor)

- `Qx.Error` moduledoc list updated (`errors.ex:11`); plan 2.1 notes this.
- `validate_draw_size!` has no size-0 or non-integer fallthrough clause, so a non-integer size would raise `FunctionClauseError` (existing odd-input behaviour stated as kept in Risks).
- Message says "states" for counts (documented in scratchpad; plan D4 has one shape).
- Doc text in README/CHANGELOG/facade is slightly longer than "one line", acceptable.
