# Scratchpad: draw-state-size-cap

## Decisions

- **2026-11-14 (user):** raise a typed error above the cap, with an override
  option. Truncation / top-K was considered and not chosen: it keeps v0.12
  non-breaking and keeps sparse large states drawable, but needs more design
  (K, "other" bar, truncation marker in three table formats) and can mislead
  if unlabelled.
- **2026-11-14 (plan, open for the user):** `Qx.Draw.counts/2` is included,
  capped on `map_size(result.counts)` (plan D5). Error type is a new
  `Qx.DrawSizeError` (plan D4), not `Qx.QubitCountError`.
- **Research** (research/hex-library-researcher-report.md):
  - No new dependency.
  - Nx 0.13.0: `Nx.size/1`, `Nx.shape/1`, `Nx.axis_size/2` read the struct
    only; no backend transfer on any backend.
  - `vega_lite` 0.1.11 / `kino` 0.19.0: no row limit. Livebook front-end
    limits were not checked (Livebook is not a dep). 4096 is our own number.
  - `nimble_options` 1.1.1 is in the lock only via dev-only deps.

- **2026-11-14 (work, deviation from plan 2.3/2.4):** the default
  `max_qubits` (12) is a module attribute in `Qx.Validation`, read through
  `Qx.Validation.draw_max_qubits!/1`, not an attribute in `Qx.Draw`. Reason:
  `Qx.Draw.Tables` needs the same default, and reading it from `Qx.Draw` would
  add a direct `tables → draw` edge to the existing
  `tables → register → qubit → draw → tables` cycle. The ROADMAP item for that
  cycle expects it to dissolve when the calc engine is removed at 1.0; a new
  direct edge would leave a 2-module cycle behind. Precedent: `Qx.Validation`
  already holds the 1..20 qubit-count limit.
- **2026-11-14 (work, deviation from plan 2.2):** the size test is
  `Bitwise.bsr(size - 1, max_qubits) > 0` instead of
  `size > Bitwise.bsl(1, max_qubits)`. D3 allows any positive integer, and
  `bsl(1, 10^12)` raises a raw system-limit error (Iron Law #7). Covered by the
  "accepts a max_qubits far above any real state" tests.
- **2026-11-14 (work):** the message says "states" for `counts/2` too (plan D4
  gives one message shape). For `counts` the number is distinct outcomes.

## Current code facts (2026-11-14, main @ 966fcb0)

- `Qx.Draw.plot/2` → `VL.plot/4`: `Nx.to_flat_list(result.probabilities)`
  (`lib/qx/draw/vega_lite.ex:21`), one map per state.
- `Qx.Draw.histogram/2`: `Nx.to_flat_list` in `lib/qx/draw.ex` itself, then
  `VL.histogram/4`.
- `Qx.Draw.counts/2` → `VL.counts/4`: iterates `result.counts`; bounded by
  shots, not 2^n.
- `Qx.Draw.state_table/2` → `Qx.Draw.Tables.render/2` →
  `build_table_data/3`: `Nx.to_flat_list(state)` (`tables.ex:63`), then
  filters for `hide_zeros` after the full host build. `render/2` has no other
  caller.
- Facade: `Qx.draw/2`, `draw_counts/2`, `draw_histogram/2`, `draw_state/2`
  are `defdelegate`s (`lib/qx.ex:1459-1613`); their docs are doctested via
  `doctest Qx`. `Qx.Draw` has no `iex>` examples and no doctest directive.
- Option-validation pattern to copy: `Qx.Validation.validate_shots!/1`
  (`validation.ex:204`).
- Downstream: `kino_qx` uses only `Qx.draw_counts/2`; `qxportal` tutorials use
  `draw_histogram/2` and `draw_state/2` on small states.

## Out of scope / discovered

- `Qx.Step.show/1` (`lib/qx/step.ex:100-101`) does the same host-side
  `Nx.to_flat_list` on the 2^n state and probabilities. Tier 1; not in the
  ROADMAP item. Candidate ROADMAP line under v0.12 if wanted.
- `tables.ex:64` uses `:math.pow(Complex.abs(amp), 2)` per amplitude and
  `trunc(:math.log2(...))`: covered by the separate `:math.pow` ROADMAP item.
- A sparse-state renderer (top-K with a truncation marker) would remove the
  need for `hide_zeros: true, max_qubits: n` on large sparse states.

## Measurements

### Task 1.4: heap limits (2026-11-14, OTP 29 / erts 17.0.3, Elixir 1.20.2, Nx 0.13.0 BinaryBackend, MIX_ENV=test)

Each call ran in a fresh process with
`Process.flag(:max_heap_size, %{size: words, kill: true, error_logger: false})`.
Input: a 2^20-element tensor built in the parent (off-heap refc binary).
"Smallest surviving" is a binary search, accurate to about 3%.

| Call (2^20 elements, current unguarded code) | Smallest surviving heap (words) |
|---|---|
| `Qx.Draw.histogram/2` | 75,544,576 |
| `Qx.Draw.plot/2` | 75,544,576 |
| `Qx.Draw.state_table/2` | 155,235,840 |

- Guarded call, measured with a proxy before the implementation existed
  (`Keyword.get` + `Nx.size` + raise with the D4 message): survives at 233
  words, the VM minimum (`:erlang.system_info(:min_heap_size)`); smaller values
  are rejected by `Process.flag/2`. Re-measured on the real functions in 2.5
  (below).
- **Chosen limit: 2^17 = 131,072 words (1 MiB).** 562× above the guarded need,
  576× below the smallest unguarded survival. Both far beyond the 4× the plan
  asks for.
- Kill is prompt: unguarded `state_table` at a 2^24-word limit died in 72 ms.
- Measuring script (not committed):
  `/private/tmp/claude-501/-Users-richarc-Development-qxquantum-qx/c7c63220-39c7-4402-9bd2-18e7b0134bd1/scratchpad/measure_heap.exs`.

### Task 1.6: red run (before any `lib/` change)

`mix test test/qx/draw_size_cap_test.exs`: **20/59 passed, 39 failed.**

- 1.1 (7 tests) and the facade "raises" tests (4): "Expected exception
  Qx.DrawSizeError but nothing was raised".
- 1.2 `max_qubits: 2` (4 tests): nothing raised.
- 1.3 (20 tests): "Expected exception Qx.OptionError but nothing was raised".
- 1.4 (3 tests): `match (=) failed ... right: :killed`.
- 1.5 Register (1 test): nothing raised.
- Passing, as intended: 4096 bars/rows with no option (4), `max_qubits: 13`
  and the huge `max_qubits` (8, the option is ignored today), `hide_zeros` +
  `max_qubits`, GHZ counts, the facade "accepts" tests (4), Register with
  `max_qubits:`, and the harness control test.
- A first draft of 1.4 matched on `%Qx.DrawSizeError{}`; that fails to compile
  while the module does not exist, so it uses `is_exception/2` instead.

### Task 2.5: guarded calls, real functions (after the implementation)

Same harness, 2^20-element input, default options:

| Call | Warm (modules loaded) | First call in a fresh VM |
|---|---|---|
| `Qx.Draw.histogram/2` | raises at 233 words | raises at 233 words |
| `Qx.Draw.plot/2` | raises at 233 words | killed at 1,598; raises at 4,181 |
| `Qx.Draw.state_table/2` | raises at 233 words | killed at 987; raises at 1,598 |

- The first-call cost is module loading, which runs in the calling process.
  Sizes between the two probes were not searched, so the cold need is "at most
  4,181 words".
- Margin of the chosen 131,072 words: 31× above the cold guarded need
  (562× above warm), 576× below the smallest unguarded survival.
- `mix test test/qx/draw_size_cap_test.exs` run 25 times in a row: 59 passed
  each time.

### Phase 3: `mix docs` warnings

Baseline (unmodified `lib/` + `mix.exs`, via `git stash push -- lib/ mix.exs`)
and after-docs lists are identical: 12 distinct lines, `diff` empty. All
pre-existing (hidden `Qx.Hardware.Ibm`/`Portal` and `Qx.Patterns.*_circuit/1`
references, missing LICENSE/RELEASE.md/ROADMAP.md extras, one IAL warning).

### Final verification (2026-11-14)

`mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test`:
all pass. 1550 passed (328 doctests, 1222 tests); credo: no issues.

## Open for the user

- **D5, `counts/2` cap on distinct outcomes** is implemented as planned and is
  still the decision to confirm. To drop it: remove the `validate_size!` line
  in `Qx.Draw.counts/2`, the `:counts` cases in the test file, and the
  `draw_counts` text in the docs, README and CHANGELOG.
- Not tested here: `kino_qx` and `qxportal` (plan Risks, "Downstream").

## Review follow-up (2026-11-14)

`/phx:review` verdict: PASS WITH WARNINGS (3 warnings, all in the new test
file). All three fixed at the user's request, in
`test/qx/draw_size_cap_test.exs` only:

1. The two Register tests moved to `Qx.DrawSizeCapRegisterTest`
   (`async: false`), so their stderr deprecation warning cannot reach the
   async `warn == ""` assertion in `state_table_register_deprecation_test.exs`.
2. The heap-limit tests build the 2^20 input before `run_with_heap_limit/1`,
   matching the measurements.
3. `plot`, `histogram` and `state_table` are now also tested at 4097 elements.

After the fixes: new file 62 passed; full suite 1553 passed (328 doctests,
1225 tests) on three consecutive runs; compile, format, credo --strict clean.
Review suggestions were not acted on.
