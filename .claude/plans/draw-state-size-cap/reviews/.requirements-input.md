# Plan: Cap state-sized rendering in `Qx.Draw`

**Branch:** `fix/draw-state-size-cap`
**ROADMAP:** v0.12 — "Cap or auto-truncate state-sized rendering above n≈12 qubits" (audit: perf CRIT C4)
**Depth:** standard
**Complexity:** 4 (4+ files across Draw / Validation / errors +3, tier 2 public
API change +3, follows the existing typed-error + option-validation pattern −2)

## Goal

The draw functions refuse to build a chart or table with more than 2^12 = 4096
bars/rows, raising a typed error that names the override. Today
`Qx.Draw.plot/2`, `histogram/2` and `state_table/2` call `Nx.to_flat_list` on
the 2^n tensor and build one map or row per basis state, so a 20-qubit state
becomes about a million bars in a 400 px chart.

User decision (2026-11-14): **raise, with an override option.** No truncation.

Small inputs are unchanged: anything up to and including 12 qubits renders
exactly as before.

## Scope

**In:**
- `lib/qx/errors.ex`: new `Qx.DrawSizeError`.
- `lib/qx/validation.ex`: `validate_max_qubits!/1`, `validate_draw_size!/2`.
- `lib/qx/draw.ex`: guard in `plot/2`, `histogram/2`, `counts/2`; docs.
- `lib/qx/draw/tables.ex`: guard in `render/2` (reached via `state_table/2`).
- `lib/qx.ex`: docs for `draw/2`, `draw_counts/2`, `draw_histogram/2`,
  `draw_state/2` (delegates; no code change).
- `mix.exs`: add the new error to the "Error Handling" docs group.
- One new test file. `CHANGELOG.md`, one README line.

**Out (see scratchpad):**
- Truncation / top-K rendering.
- `Qx.Step.show/1` (`lib/qx/step.ex:100-101`): same host-side 2^n build, but
  tier 1 and not named in the ROADMAP item.
- `:math.pow` cleanup in `tables.ex:64`; the `tables → register → qubit → draw`
  cycle. Both are separate ROADMAP items.
- `bloch/2` and `circuit/2`: not state-sized.
- Version bump (release step, not this change).

## Decisions

- **D1 — what is measured: the number of bars/rows, against `2^max_qubits`.**
  `Nx.size/1` of the tensor for `plot` (`result.probabilities`), `histogram`
  and `state_table`; `map_size(result.counts)` for `counts`. Raise when
  `size > 2^max_qubits`. `Nx.size/1` is a struct-field read with no backend
  transfer on any backend (research: `deps/nx/lib/nx.ex:4729`, Nx 0.13.0).
- **D2 — default `max_qubits` is 12 (4096 elements).** From the ROADMAP item.
  It is a self-chosen cap: neither `vega_lite` 0.1.11 nor `kino` 0.19.0 has a
  row limit (research). Exactly 12 qubits still renders.
- **D3 — override is a per-call option `:max_qubits`,** a positive integer.
  Anything else raises `Qx.OptionError{option: :max_qubits}` ("Expected a
  positive integer."), same shape as `validate_shots!`. The option is validated
  even when the input is small.
- **D4 — new exception `Qx.DrawSizeError`,** fields `:size`, `:limit`,
  `:max_qubits`, `:message`. Message shape:
  `"Cannot draw 8192 states: the limit is 4096 (max_qubits: 12). Pass
  max_qubits: 13 (or higher) to draw it anyway."` The suggested value is
  the smallest `max_qubits` that admits the input.
  Rejected: reusing `Qx.QubitCountError`. `counts` and `histogram` inputs are
  not a qubit count, its `{count, min, max}` message cannot name the override,
  and callers who rescue it today mean "invalid circuit size".
- **D5 — `counts/2` is in scope, capped on distinct outcomes.** The ROADMAP
  item names all three VegaLite builders. `counts` is bounded by shots, not by
  2^n, so the cap is on `map_size(result.counts)`, not on bit-string length: a
  20-qubit GHZ measurement (2 outcomes) still draws. The check is O(1).
  Consequence: a hardware or simulator result with more than 4096 distinct
  outcomes now raises. **Flagged for the user; cut 1.4 and the `counts` tests to drop it.**
- **D6 — guard placement.** `plot`, `histogram`, `counts`: in `Qx.Draw`, after
  `ensure_vega_lite!/0`, before any call into `Qx.Draw.VegaLite`. `state_table`:
  inside `Qx.Draw.Tables.render/2`, after the `%Qx.Register{}` unwrap and input
  check, before `build_table_data/3`. `render/2` has no other caller.
  `hide_zeros: true` does not bypass the guard: the filter runs after the 2^n
  host build. A sparse large state is drawn with
  `hide_zeros: true, max_qubits: n`.
- **D7 — "guard runs before the host build" is tested with `:max_heap_size`.**
  Run the draw call in a spawned process with
  `Process.flag(:max_heap_size, %{size: words, kill: true, error_logger: false})`
  on a 2^20-element tensor. With the guard first, the process exits with
  `Qx.DrawSizeError`; if `Nx.to_flat_list` runs first, the process is killed.
  No timing involved. The heap size is picked from a measurement in 1.4, not
  guessed (the tensor data is an off-heap refc binary; the list is on-heap).
- **D8 — breaking change, tier 2 (Iron Law #6).** `CHANGELOG.md` Unreleased →
  "Changed" entry marked breaking. The ROADMAP v0.12 intro line "Additive and
  internal, no breaking changes" is amended in the squash-merge commit, with
  the item tick. The minor bump to 0.12.0 at release covers it.
- **D9 — no new dependency** (research). `nimble_options` is in the lock only
  through dev-only deps and is not shipped.

## Phase 1 — Tests first (red)

New file `test/qx/draw_size_cap_test.exs`, `async: true`. New file only; no
existing test is modified. Inputs are built directly
(`Nx.broadcast/2`, hand-built `%Qx.SimulationResult{}`), not by simulating.

- [x] 1.1 `Qx.DrawSizeError` over the default cap, for `Qx.Draw.plot/2`,
  `histogram/2`, `state_table/2` with a 2^13-element tensor, and `counts/2`
  with a 4097-key counts map. Assert the struct fields (`size`, `limit: 4096`,
  `max_qubits: 12`) and that the message contains `max_qubits: 13`.
  — done; also the exact message, an 8193-element input suggesting 14, and
  `hide_zeros: true` still capped.
- [x] 1.2 Boundary and override: 2^12 elements (and a 4096-key counts map)
  render with no option; the 2^13 inputs render with `max_qubits: 13`;
  `max_qubits: 2` makes a 3-qubit input raise (the option lowers the limit too).
  — done; plus `max_qubits: 1_000_000_000_000` on a small input (no bignum
  limit is built) and a 20-qubit GHZ counts map (2 outcomes) still drawing.
- [x] 1.3 Option validation: `max_qubits:` `0`, `-1`, `1.5`, `:all`, `"13"`
  each raise `Qx.OptionError` with `option: :max_qubits`, on all four
  functions, including when the input is small.
- [x] 1.4 Guard-before-build (D7), for `plot`, `histogram`, `state_table`.
  First measure on current code: the smallest `max_heap_size` at which a
  2^20-element call survives, and the heap a guarded call needs. Pick a size
  with at least 4× margin on both sides and record all three numbers in the
  scratchpad. If no size gives that margin, stop and report rather than
  loosening it.
  — measured: unguarded survives at 75.5M words (plot, histogram) and 155M
  (state_table); guarded needs the VM minimum, 233 words. Chosen 2^17 =
  131,072 words (>500× margin each side). A control test checks the harness
  does kill a real 2^20 `Nx.to_flat_list`.
- [x] 1.5 Facade and Register paths: `Qx.draw/2`, `Qx.draw_counts/2`,
  `Qx.draw_histogram/2`, `Qx.draw_state/2` raise the same error and accept
  `max_qubits:`; a `%Qx.Register{}` passed to `state_table/2` is capped after
  the deprecation warning (capture the warning with `ExUnit.CaptureIO`).
- [x] 1.6 Run `mix test test/qx/draw_size_cap_test.exs`. Confirm 1.1, 1.3, 1.4,
  1.5 FAIL (1.1 by returning a result; 1.4 by the process being killed) and
  that the "renders with no option" half of 1.2 passes. Record the red output
  summary in the scratchpad.
  — red: 20/59 passed, 39 failed, for the expected reasons (see scratchpad).

## Phase 2 — Implementation (green)

- [x] 2.1 `lib/qx/errors.ex`: `Qx.DrawSizeError` per D4, with a moduledoc
  (it is public contract). Compute the suggested `max_qubits` with integer
  math only (no `:math.log2`/`trunc`). Add it to the "Error Handling" group in
  `mix.exs`.
  — `exception({size, max_qubits})`; suggestion is the bit length of
  `size - 1` (`Integer.digits/2`). Also listed in the `Qx.Error` moduledoc.
- [x] 2.2 `lib/qx/validation.ex`: `validate_max_qubits!/1` (D3) and
  `validate_draw_size!(size, max_qubits)` (D1), `@doc false`, multi-clause,
  limit via `Bitwise.bsl(1, max_qubits)` or `Integer.pow/2`.
  — **deviation:** the comparison is `Bitwise.bsr(size - 1, max_qubits) > 0`,
  not `size > bsl(1, max_qubits)`, so `max_qubits: 10^12` never builds a
  bignum (`bsl` would raise a raw system-limit error, Iron Law #7). `bsl` is
  used only for the error's `:limit`, where `max_qubits < log2(size)`.
  Added `draw_max_qubits!/1` (reads the option with the default).
- [x] 2.3 `lib/qx/draw.ex`: read `:max_qubits` (default from one module
  attribute), validate, guard in `plot/2`, `histogram/2`, `counts/2` per D6.
  `histogram/2`: the guard goes before its own `Nx.to_flat_list`.
  — **deviation:** the one module attribute (`@default_draw_max_qubits 12`)
  is in `Qx.Validation`, not `Qx.Draw`; see 2.4 and the scratchpad.
- [x] 2.4 `lib/qx/draw/tables.ex`: same guard in `render/2` per D6. Share the
  default with `Qx.Draw` rather than repeating the literal 12.
  — shared through `Qx.Validation.draw_max_qubits!/1`. A `Tables → Qx.Draw`
  call would add a direct edge to the `tables → … → draw → tables` cycle
  that a separate ROADMAP item expects to dissolve at 1.0.
- [x] 2.5 Trace by hand that each of the four public functions reaches the
  guard before its first `Nx.to_flat_list` / `Enum.map` over the input, then
  re-run the new test file to green.
  — traced; 59/59 green, 25 consecutive runs. Real guarded calls need 233
  words warm and at most 4,181 on the first call in a VM (scratchpad).
- [x] 2.6 `mix test` (full suite), then
  `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict`.
  If an existing test fails, stop and report: existing tests are not edited
  without approval. (`typed_errors_sweep_test.exs` and
  `draw_contracts_test.exs` are the likely places.)
  — 1550 passed (328 doctests, 1222 tests); no existing test touched;
  compile, format, credo --strict clean.

## Phase 3 — Docs and wrap-up

- [x] 3.1 Record the `mix docs` warning baseline before touching docs:
  `mix docs 2>&1 | grep "warning:" | sort | uniq -c`.
  — taken from unmodified `lib/` + `mix.exs` via `git stash push`/`pop`
  (Phase 2 had already added a moduledoc): 12 distinct warning lines.
- [x] 3.2 Docs: add `:max_qubits` under "Options" and `Qx.DrawSizeError` /
  `Qx.OptionError` under "Raises" for `Qx.Draw.plot/2`, `counts/2`,
  `histogram/2`, `state_table/2`, the `Qx.Draw` moduledoc, and the four `Qx`
  facade docs. State the `hide_zeros` interaction (D6) on `state_table` /
  `draw_state`. Update the `Qx.Draw.Tables.render/2` doc.
- [x] 3.3 README: one line in the visualization section naming the 12-qubit
  default and `max_qubits:`.
- [x] 3.4 `mix docs` again; warning list must be ≤ baseline (diff the lists,
  not the counts).
  — warning list identical to the baseline (`diff` empty).
- [x] 3.5 `CHANGELOG.md` Unreleased → Changed (**breaking**): the four draw
  functions and their facades raise `Qx.DrawSizeError` above 4096 bars/rows;
  `max_qubits:` overrides; what to do for sparse large states. Added:
  `Qx.DrawSizeError`.
- [x] 3.6 Full verification again (command below), then stop for
  `/phx:review` (merge gate). The ROADMAP tick and the v0.12 intro amendment
  (D8) go in the squash-merge commit after the human authorizes it.
  — verification passed; stopped before `/phx:review`. ROADMAP untouched.

## Risks

- **`counts` cap surprises hardware users (D5).** A noisy 15-qubit run with
  10k shots can exceed 4096 distinct outcomes and will now raise. The message
  names the fix. This is the decision most worth a second look.
- **`max_heap_size` test (D7) is environment-sensitive.** Heap growth is
  stepwise and differs across OTP versions. Mitigated by the measured 4×
  margin in 1.4 and by the huge gap expected between a guarded call and a
  2^20-element list. If it cannot be made robust, fall back to a structural
  test and say so in the scratchpad.
- **Downstream.** `kino_qx` calls only `Qx.draw_counts/2` on small results;
  the `qxportal` tutorials draw at most a few qubits. No downstream change is
  expected, but neither repo is tested by this plan.
- **Test-file guard hook.** It may block `Write` on `*_test.exs`. The file is
  new; if blocked, stop and ask rather than route around it.
- **Existing behaviour on odd inputs is kept.** A non-power-of-two tensor or
  an `Nx` scalar is not newly validated here; only the size cap is added.

## Verification

```
mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test
```

No `mix bench` needed: no kernel, gate or simulation change.
