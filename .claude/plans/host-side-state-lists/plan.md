# Plan: remove host-side 2^n list builds in `Qx.StateInit` and `Qx.ResultBuilder`

**Branch:** `fix/host-side-state-lists`
**ROADMAP:** v0.12, two items:
- "Replace host-side `2^n` Elixir-list construction in `Qx.StateInit` and in
  `Qx.ResultBuilder.build_probability_tensor`" (audit: perf HIGH; Iron Law #5)
- "Replace `:math.pow(2, n) |> trunc/1` with `Integer.pow(2, n)`" (audit: perf LOW)

**Depth:** standard
**Complexity:** 1 (4+ files +3, follows existing pattern −2, no kernel or
public-signature change)

## Goal

`Qx.StateInit.basis_state/2,3` and `Qx.ResultBuilder.from_counts/3` build
their 2^n tensors with Nx primitives. No Elixir list of 2^n elements is
created on the host. Results are unchanged for every input that works today.

Every `Qx.create_circuit(n)` goes through `basis_state/2`, so a 20-qubit
circuit currently builds a 1,048,576-element list of `Complex` structs first.

Measured 2026-11-14 on BinaryBackend, Nx 0.13.0, one cold run per point
(research report, section D). Memory is the peak total-VM delta.

| Size | `basis_state` now | with `Nx.indexed_put` | probability build now (1000 pairs) | with `Nx.indexed_put` |
|---|---|---|---|---|
| 2^16 | 11 ms / 18 MB | < 1 ms | 278 ms / 15 MB | 1 ms |
| 2^20 | 221 ms / 296 MB | 4 ms | 4.5 s / 151 MB | 5 ms / 4 MB |
| 2^22 | 1079 ms / 1347 MB | 17 ms / 64 MB | 17.7 s / 800 MB | 17 ms / 16 MB |

## Scope

**In:**
- `lib/qx/state_init.ex`: the valid-args clause of `basis_state/3`
  (lines 73–81).
- `lib/qx/result_builder.ex`: `build_probability_tensor/2` (lines 44–54).
- The `trunc(:math.pow(2, n))` sweep, 14 sites: `gates.ex` (332, 407, 454,
  500, 541), `validation.ex` (66), `quantum_circuit.ex` (79, 320, 443),
  `state_init.ex` (132, 218, 251, 390, 426).
- One new test file, `test/qx/host_side_state_lists_test.exs`.
- `CHANGELOG.md`, `ROADMAP.md` (tick both items at merge).

**Out:**
- The list builds inside the `@deprecated` `StateInit` functions
  (`superposition_state`, `random_state`, `ghz_state_vector`, `w_state`).
  They are removed at 1.0; they only get the one-line `pow` swap.
- The host-loop matrix builders in `Qx.Gates` (ROADMAP line 32). `pow` swap only.
- Existing test files. No edits are planned. If one turns out to be needed,
  stop and ask (test-file guard).
- `lib/qx/simulation.ex`: the ROADMAP names it for the `pow` sweep, but it has
  no `:math.pow` call today. Finding, no task.

## Decisions

**D1. `Nx.indexed_put` onto a zero broadcast, for both functions.**
`Nx.indexed_put(Nx.broadcast(Nx.tensor(0, type: type), {dim}), Nx.tensor([[index]]), Nx.tensor([1], type: type))`.
On BinaryBackend it has no loop over 2^n (report B). Rejected:
`equal(iota)` and `pad` loop per element and were 8–25× slower at 2^22;
`put_slice` clamps an out-of-range start silently; `concatenate` needs
branches for the first and last index; a hand-built binary encodes the
complex layout by hand. This is a construction, not a gather over state, so
Iron Law #3 does not apply.

**D2. `basis_state/3` with a real type now returns a tensor.** Today
`basis_state(1, 4, :f32)` raises a raw `CaseClauseError` and `:s32` a raw
`ArgumentError`, both leaks from `Nx.tensor/2`. After the rewrite they return
a one-hot tensor of that type, which is what the `type` parameter's doc
already promises. Not breaking: a call that crashed now works. Alternative,
if you prefer: reject non-complex types with a typed `Qx.*Error`. Say so at
the review prompt and I will swap D2.

**D3. `basis_state/3` with an invalid type keeps raising the same
`ArgumentError`** ("invalid numerical type: :bogus …"). It is a raw error
across a tier-2 boundary (Iron Law #7), and it exists today. Not fixed here;
recorded in the scratchpad.

**D4. `build_probability_tensor/2` keeps its three edge behaviours**, each
with an explicit line because `indexed_put` differs:
- pairs with `index >= size` are dropped (filter first; Nx would raise);
- an empty pair list returns f32 zeros (branch; Nx raises on empty updates);
- the result stays `{:f, 32}` (cast the updates; f64 updates would promote).

Duplicate indices stay last-write-wins, same as `List.replace_at`. Do not use
`indexed_add`.

**D5. `pow` sweep uses `Integer.pow(2, n)`**, matching `calc_fast.ex`,
`register.ex` and `result_builder.ex`. It changes no result: powers of two are
exact in a float up to 2^1023, so this is a clarity change, and the CHANGELOG
must not claim a correctness fix. One exception to check:
`Qx.Validation.valid_register?/2` is a predicate on an unvalidated map. A
negative `num_qubits` gives size 0 today and returns `false`;
`Integer.pow(2, -1)` would raise. Use `Bitwise.bsl(1, n)` there if the pinned
test in 1.5 shows a difference.

## Phase 1 — Tests first (red)

New file `test/qx/host_side_state_lists_test.exs`. `async: false` for the
heap-limit tests.

- [x] 1.1 `basis_state` characterisation (must pass before and after): type
  and shape for `(1, 4)`, `(1, 4, :c128)`, `(1, 4, {:c, 64})`; exact values
  (1.0+0.0i at `index`, 0 elsewhere) for the first, a middle and the last
  index at dimension 8; `:bogus` raises `ArgumentError`.
  — 5 tests in `test/qx/host_side_state_lists_test.exs`.
- [x] 1.2 `basis_state` real types (D2, red today): `(1, 4, :f32)` and
  `(1, 4, :s32)` return a one-hot tensor of that type.
  — 2 tests; red before 2.1 (`CaseClauseError`, `ArgumentError`).
- [x] 1.3 `from_counts/3` characterisation (must pass before and after):
  probabilities are `{:f, 32}`; `%{}` gives all zeros of shape `{2^n}`; an
  outcome whose index is `>= 2^num_bits` is dropped; two keys with the same
  index (`"1"` and `"01"`): pin whichever value wins today.
  — 4 tests. Same index: the later key in map order wins ("1" over "01").
- [x] 1.4 Heap-limit tests (red today), using the `:max_heap_size` harness
  from `.claude/solutions/testing-issues/guard-before-host-build-max-heap-size-test-qx-draw-20261114.md`:
  `basis_state(0, 2 ** 20)` and `from_counts(%{<20-bit key> => 1}, 1, 20)`
  each return inside the limit. Add the control test (a real 2^20 list build
  is killed). Measure the smallest surviving heap for the current code and for
  a D1 prototype in a scratch script, on a cold VM, and put the limit between
  them with the measured margins in a comment. Do not pick the limit unmeasured.
  — Measured cold, one VM per probe: new code survives at 1,598 words; current `from_counts` killed at 22.8M, current `basis_state` at 41.5M. Limit 2^17.
- [x] 1.5 `valid_register?/2` pin (D5): `%{state: <2-element tensor>,
  num_qubits: -1}` returns `false`. Passes today.
  — Passes before and after.
- [x] 1.6 Run the file. Confirm 1.2 and 1.4 fail, and 1.1, 1.3, 1.5 and the
  control pass. Record the output in `progress.md`.
  — 4 failed (1.2 x2, 1.4 x2), the rest passed. See progress.md.

## Phase 2 — Implementation (green)

- [x] 2.1 `lib/qx/state_init.ex`: replace the comprehension in the valid-args
  clause with D1. Guards and the `Qx.BasisError` fallback clause are untouched.
  Drop the `Complex` alias only if nothing else in the module uses it.
  — `Complex` alias kept: the deprecated functions still use it.
- [x] 2.2 `lib/qx/result_builder.ex`: rewrite `build_probability_tensor/2`
  per D1 and D4.
  — Filter, empty branch and f32 cast as in D4.
- [x] 2.3 `mix test test/qx/host_side_state_lists_test.exs
  test/qx/state_init_test.exs test/qx/result_builder_test.exs`: all green.
  Check the `doctest Qx.StateInit` count is unchanged.
  — 73 passed (24 doctests, 49 tests).

## Phase 3 — `pow` sweep

- [x] 3.1 Replace the 14 `trunc(:math.pow(2, n))` sites with
  `Integer.pow(2, n)` (D5; `valid_register?/2` per 1.5).
  — 13 sites `Integer.pow`; `valid_register?/2` uses `Bitwise.bsl(1, n)` so a negative `num_qubits` still returns false.
- [x] 3.2 `grep -rn ":math.pow(2" lib` returns nothing. Read the full output,
  not a truncated one.
  — No matches.
- [x] 3.3 `mix test` (full suite).
  — 1586 passed (330 doctests, 1256 tests).

## Phase 4 — Wrap-up

- [x] 4.1 Re-measure the Goal table on the final code (2^16, 2^20) and put
  the numbers in `CHANGELOG.md` under the unreleased 0.12 section: the
  performance change, and D2 as "now works" under Changed. No version bump
  (0.12 is already the pending breaking minor).
  — 2^20: `basis_state` 227 ms to 4.7 ms; `from_counts` (1000 outcomes) 111 ms to 11 ms. The 2^16 timings were dominated by first-call module loading and are not quoted. D2 went under Fixed, not Changed.
- [x] 4.2 Full verification (below), then stop for `/phx:review` (merge
  gate). Tick both ROADMAP items in the squash commit after PASS.
  — compile, format, credo --strict, full test all pass. Stopped for `/phx:review`. ROADMAP ticks are still to do in the squash commit.

## Risks

- **Heap-limit test flakiness.** Module loading on a cold VM runs in the
  limited process and raised the need from 233 to 4,181 words last time.
  Mitigation: measure cold, keep a wide margin on both sides (1.4).
- **`indexed_put` heap use on BinaryBackend is unmeasured per process.** The
  report measured total VM memory (4 MB at 2^20), not process heap. If the
  D1 prototype needs a heap close to the current code's, the test cannot
  separate them: stop and report with the numbers.
- **A caller relying on `basis_state/3` raising for real types.** None in
  `lib/` (callers: `quantum_circuit.ex`, `register.ex`, `qubit.ex`, all
  default type). D2 is the visible change.

## Verification

```
mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test
```

No `mix bench`: `calc*.ex`, the `Qx.Gates` matrices and `simulation.ex` are
not changed beyond the `pow` swap in `gates.ex`. Offer it anyway after 3.3.

Research: `research/hex-library-researcher-report.md`.
