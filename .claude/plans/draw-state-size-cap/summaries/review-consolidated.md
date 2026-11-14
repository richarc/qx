# Consolidated Review Summary: draw-state-size-cap

**Strategy**: Compress
**Input**: 4 files (elixir.md, testing.md, iron-laws.md, requirements.md), ~8k tokens
**Output**: ~2.5k tokens (~65% reduction)

## Execution limits
- elixir-reviewer: read-only, no Bash. compile/test not run. Its `Bitwise.bsr` in a guard without `require` is unconfirmed, pending a compile.
- testing reviewer: could not confirm how ExUnit routes stderr for non-capturing processes (see WARNING 1). No run is reported beyond the scratchpad's 25 runs.
- iron-law-judge: static analysis only; no run reported.
- requirements reviewer: re-ran `mix test test/qx/draw_size_cap_test.exs` (59 passed). It did NOT re-run the full suite, credo, `mix docs`, or the red run.

## BLOCKERs
None from any agent.

## WARNINGs (3, all from the testing reviewer)

1. **stderr capture isolation risk**
   - Location: test/qx/draw_size_cap_test.exs:247,259 and test/qx/draw/state_table_register_deprecation_test.exs:9-11
   - `capture_io(:stderr)` hooks a process-global device.
   - The existing test asserts `warn == ""`. The new Register tests call `IO.warn` (tables.ex:46), and both modules are `async: true`, so they run concurrently.
   - If the capture is not strictly per-process, the existing test can see "deprecated" and fail intermittently.
   - Line 259 discards the capture, so it is a no-op there. The new file's own `=~ "deprecated"` assertion is safe.
   - Fix: put both Register tests in one `async: false` module, move the existing silent-tensor test, or drop the `warn == ""` assertion.

2. **Heap-harness asymmetry**
   - Location: test/qx/draw_size_cap_test.exs:210-217, control test at :221, `result(...)` helper
   - The 2^20 tensor is built inside the heap-limited child, because `draw/3` calls `probabilities/1` and `state/1` in the fun.
   - The scratchpad measurements (Task 1.4) and the control test build it in the parent.
   - Scenario: a heap-hungry `Nx.broadcast` in the child is reported as `:killed`. That gives a false FAIL with a confusing `{:raised, error} = :killed` match error. It cannot give a false pass.
   - It passed 25 runs on OTP 29 / Nx 0.13.0, so this is a latent coupling to Nx internals.
   - The child also uses the application-level default backend, not the parent's.
   - Fix: build the input in the test process and pass it into `run_with_heap_limit`. The same applies to `result(...)`, which allocates `probabilities(2)` first.

3. **Boundary gaps**
   - Location: test/qx/draw_size_cap_test.exs:123-130,140-145
   - 4097 is tested only for `counts`. The tensor functions are tested at 8192, and 8193 for histogram only.
   - Mutations such as `bsr(size - 2, n)` or a call-site off-by-one in plot/histogram/state_table survive, because 4097 is never hit for them.
   - Fix: iterate `[4097, 8192]` over `@tensor_functions` in the over-cap tests.

## SUGGESTIONs (grouped)

**Error message and API wording**
- lib/qx/errors.ex, `exception/1`: the message always says "Cannot draw N states". For `counts/2` the unit is distinct outcomes (a 20-qubit GHZ is 2 outcomes), and `state_table` draws rows. Consider "bars/rows" or "items". The wording is asserted verbatim at draw_size_cap_test.exs:135, so update that test too. (elixir) The requirements reviewer also notes this as "not asked for by the plan".
- Documentation nit: CHANGELOG.md:10-36 has "Changed"/"Added" before "Performance"/"Fixed" in Unreleased. This is a section-order nit only. (elixir)

**Test comments (Iron Law: comments are not commit messages)**
- test/qx/draw_size_cap_test.exs:3-9,21-25: the moduledoc and comment name the plan slug and a measurement date/toolchain ("Measured on 2026-11-14 (OTP 29...)"). Keep the 500x-margin rationale and drop the plan ref and date. (elixir)

**Test coverage gaps and harness hardening (testing)**
- Add `after 10_000 -> flunk(...)` to the `receive` in the harness (lines 79-109). Without it, a hang is bounded only by the 60 s ExUnit timeout.
- `max_heap_size` semantics can differ across OTP versions. The numbers are specific to BinaryBackend. The margins (2^17, 31x cold) make it robust. The harness is otherwise sound.
- Missing paths: size 0 (empty tensor or `%{}` counts) passing; non-power-of-two sizes below the cap (4095, or 3 with `max_qubits: 2`) passing; `max_qubits: nil` and `true` in the invalid list (lines 194-205); `Qx.DrawSizeError.exception/1` binary-message clause (errors.ex:407) untested; validation tested via `Qx.Draw` only, not the facade (acceptable).
- Generated test names are unique, with minor oddities: the repeated "Qx facade for ..." describe name, `#{1 <<< 17}` depending on a module-level Bitwise import, and the odd line 196.
- `assert_raise` without a message at lines 148 and 190 is acceptable.
- No new `iex>` doctests, so no doctest directive is needed (AGENTS rule 4). `vega_lite` is `optional: true`, which is existing practice.

**Deconfliction (iron-law-judge kept over elixir-reviewer)**
- Dropped: elixir suggestions 2 and 4 (`exception/1` and `validate_draw_size!` give `FunctionClauseError` on bad input, no fallback clause). Iron-law #7 covers the same code and finds no clause-miss path: `max_qubits` is pre-validated by `draw_max_qubits!`, `Nx.size`/`map_size` always return integers, and `exception/1` is only called from the raising clause. Sizes 0 and 1 are safe.

## Iron Laws (iron-law-judge): 0 violations, 9 of 9 checked
- PASS: #1, #2, #5, #6, #7, #8.
- N/A: #3, #4, #9.
- #6 notes the CHANGELOG entry is marked **Breaking:**. The release step must bump the minor version (0.x), and the bump is deliberately deferred.
- Minor note (#7): `Nx.size(result.probabilities)` (draw.ex:89) and `map_size(result.counts)` (draw.ex:137) are new early accesses. A hand-built non-`SimulationResult` now fails with KeyError/BadMapError/ArgumentError slightly earlier. The error class is the same as before, and the struct has `@enforce_keys`. This is a change of order only.

## Requirements (requirements.md)
**Counts**: 24 MET, 3 PARTIAL (2.2, 2.3, 2.4: recorded deviations, intent met), 0 UNMET, 2 UNCLEAR (1.6; 3.1/3.4).

**MET (one line)**: Goal, Scope In, D1-D9, 1.1-1.5, 2.1, 2.5, 2.6 (partly a claim), 3.2, 3.3, 3.5, 3.6. The Scope "Out" check is confirmed (step.ex, `:math.pow`, bloch/circuit, version, ROADMAP and existing tests are all untouched).

### PARTIAL (full)
- **2.2 `validate_max_qubits!/1`, `validate_draw_size!/2`, `@doc false`, multi-clause**
  - Deviation: the comparison is `Bitwise.bsr(size - 1, max_qubits) > 0` (validation.ex:256-257) instead of `size > bsl(1, max_qubits)`. `bsl` is used only for `:limit` (errors.ex:~207). There is an extra `draw_max_qubits!/1` (validation.ex:233).
  - Evidence: the intent is met. The result is the same for all sizes >= 1, and no bignum is built for huge `max_qubits`. Tested at draw_size_cap_test.exs:174-176. Size 0 passes (`bsr(-1,n)` = -1).
- **2.3 Draw reads `:max_qubits`, default from one attribute in Qx.Draw, validates, guards per D6**
  - Deviation: the attribute is `@default_draw_max_qubits` in `Qx.Validation` (validation.ex:6), read via `draw_max_qubits!/1`. `Qx.Draw` has a private `validate_size!` (draw.ex:312).
  - Evidence: one shared default, validated and guarded, so the intent is met.
- **2.4 Tables guard, default shared with Qx.Draw rather than repeating 12**
  - Deviation: shared via `Qx.Validation` (tables.ex:65), not via `Qx.Draw`. This avoids a new tables->draw edge (cycle).
  - Evidence: the literal 12 appears only at validation.ex:6, so the intent is met.

### UNCLEAR (full)
- **1.6 Red run recorded**: scratchpad.md "Task 1.6" claims 20/59 passed. This cannot be verified from the final code.
- **3.1/3.4 `mix docs` warning baseline and diff**: not re-run. This is a scratchpad claim only and is treated as unverified.
- Also unverified claims: the 2.6 full-suite and credo results, and the 1.4 measurements (2^17 words; 562x/576x margins) in scratchpad.md. They are not re-verifiable from code.

### Not asked for by the plan (minor)
- The `Qx.Error` moduledoc list was updated (errors.ex:11); plan 2.1 notes this.
- `validate_draw_size!` has no size-0 or non-integer fallthrough clause (see deconfliction above).
- The message says "states" for counts (plan D4 has one shape).
- README/CHANGELOG/facade text is slightly longer than "one line".

## PRE-EXISTING (one line each)
- lib/qx.ex:1651: the `draw_state` `@spec` takes only `Nx.Tensor.t()` although a deprecated `Qx.Register` is still accepted. (elixir)
- lib/qx/draw/tables.ex:82: `trunc(:math.log2(num_states))` is wrong for non-power-of-2 sizes, now reachable only up to the cap. (elixir)
- tables.ex:78-96 `build_table_data` and draw.ex:183-192 `histogram` still loop host-side over every amplitude (Law #5), now capped at 2^max_qubits (default 12). (iron-laws)
- `Keyword.get/3` with a non-keyword `options` raises, as it already did for `title`/`width`/`height`. (iron-laws, Law #7)
- A hand-built non-`SimulationResult` fails with a KeyError/BadMapError/ArgumentError, now slightly earlier. (iron-laws, Law #7 order change)
- `histogram/2` given a non-tensor (e.g. a list): `Nx.size(list)` may raise `ArgumentError`, as `Nx.to_flat_list` did before. (iron-laws, Law #7)
- tables.ex:88 `prob > 1.0e-10` is a sub-epsilon display filter, untouched by the diff. (iron-laws, Law #8)
- The deprecated Register input still gets the deprecation warning before the guard. (elixir, noted as matching the docs)
- test/qx/draw_test.exs:119-130,140,106: small-input smoke tests and the Register escape hatch. They are unaffected and still valid under the default cap. (testing)
- test/qx/draw_contracts_test.exs: not checked against the new option. (testing)
- test/qx/draw/state_table_register_deprecation_test.exs:9-23: covers the Register deprecation at 1 qubit (see WARNING 1). (testing)
- test/qx_manual_test.livemd: 32 draw matches, not run by ExUnit. (testing)

## Coverage
| File | Represented | Key Items |
|---|---|---|
| elixir.md | Yes | 0 BLOCKER, 0 WARNING; 5 suggestions (2 deduped to iron-laws); 2 pre-existing |
| testing.md | Yes | 3 WARNING; suggestions grouped; 5 overlap items |
| iron-laws.md | Yes | 0 violations; 1 minor note; 5 pre-existing |
| requirements.md | Yes | counts; 3 PARTIAL; 2 UNCLEAR; deviations; MET line |

## Coverage Gaps
None.
