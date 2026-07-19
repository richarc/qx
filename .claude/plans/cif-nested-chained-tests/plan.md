# Plan — Nested & chained `c_if` conditional tests (qx-sso)

**Branch:** `feat/cif-nested-chained-tests`
**Roadmap:** v0.8.1 "Test Coverage & Quality" — *Add tests for nested
and chained c_if conditional operations (qx-sso)*
**Type:** Pure test additions. No public API, no `lib/` changes.

## Goal

Close the coverage gap on `Qx.c_if/4` for **chained** conditionals
(multiple `c_if` blocks in one circuit, executed shot-by-shot) and
**nested** conditionals (a `c_if` inside a `c_if` block). Lock the
observed semantics so the v0.8.2 simulation refactor and the
`run_with_conditionals` hot-path work cannot silently change them.

## Context (verified)

- `Qx.c_if(circuit, classical_bit, value, gate_fn)` captures the gates
  `gate_fn` adds to a temp circuit and stores
  `{:c_if, [classical_bit, value], sub_instructions}`
  (`lib/qx/operations.ex:736`). Public entry is `Qx.c_if/4`
  (`defdelegate` → `Operations`, `lib/qx.ex:857`).
- **Nested `c_if` is REJECTED at construction time.**
  `validate_conditional_block/1` (`operations.ex`) does
  `Enum.each` over the captured block and
  `raise Qx.ConditionalError, :nested_conditionals` on any inner
  `{:c_if, _, _}`. So "nested" tests are **rejection / characterization**
  tests, not nested-execution tests (see scratchpad **C1**). The raise
  happens while *building* the circuit, before any `run/2`.
- Execution is shot-by-shot: `run_with_conditionals/3` →
  `execute_single_shot/2` builds a timeline; `process_conditional/8`
  fires a block iff `Enum.at(cbits, cbit) == value`, threading the same
  1-based gate counter across the block (the W1 renorm fix,
  `simulation.ex:618`).
- **Existing coverage (do NOT duplicate)** — `test/qx_test.exs`
  "conditional operations": single-`c_if` true/false/value-0/
  probabilistic; teleportation (2 `c_if`, different bits, X & Z);
  "multiple conditionals in sequence" (2 `c_if`, different bits, same
  target, both fire → identity). `test/qx/operations_typed_errors_test.exs`:
  out-of-range cbit, invalid value, non-function `gate_fn`, and one
  bare nested-`c_if`-raises (via `Operations.c_if`).
- **Hook constraint:** the TDD guard blocks editing existing
  `*_test.exs`. New tests go in a NEW file
  `test/qx/conditional_operations_test.exs` (scratchpad **C2**), born
  `async: true` (pure compute). No new dependencies → hex evaluation N/A.

## Iron Law notes

- Test-only; no `lib/` edits. `c_if` already routes typed
  `Qx.ConditionalError` / `Qx.ClassicalBitError` (Iron Law #7 satisfied
  upstream) — these tests assert those typed errors, they do not add or
  change validation.
- Deterministic-circuit tests (fixed measured outcomes) assert exact
  `result.counts` over all shots. Probabilistic chains use
  `assert_in_delta` with a wide band (Iron Law #8: don't over-tighten).
- Verification gate (compile `--warnings-as-errors`, format, full test,
  credo, cover) is mandatory — Phase 4.

---

## Phase 1 — Test scaffold

- [x] Create `test/qx/conditional_operations_test.exs` with
      `use ExUnit.Case, async: true`, `alias Qx`.
- [x] Moduledoc comment: this file pins **chained** execution semantics
      and **nested** rejection of `Qx.c_if/4`, complementing the single-
      `c_if` and structural tests already in `qx_test.exs` /
      `operations_typed_errors_test.exs` (state the non-overlap).
- [x] Small helper(s) only if they reduce noise (e.g. a deterministic
      "measure-to-known-bit" preamble). Prefer explicit circuits.

## Phase 2 — Chained conditionals (execution semantics)

> Deterministic circuits → assert exact `result.counts` across all shots.

- [x] **Same classical bit, two `c_if` both fire.** `x(0) |> measure(0,0)`
      then `c_if(0,1, X q1)` and `c_if(0,1, X q1)` → q1 flipped twice →
      measures `|0⟩`. Pins that one cbit can gate multiple blocks.
- [x] **Mixed fire/skip chain (deterministic).** Set cbit0=1, cbit1=0;
      `c_if(0,1, X q2)` fires, `c_if(1,1, X q2)` skips → q2 = `|1⟩`.
      Exact counts. (Existing chain tests have both fire or use identity.)
- [x] **Chain length ≥ 3, independent targets.** Three `c_if` on distinct
      cbits flipping three distinct qubits, with a known mixed
      fire pattern → one pinned `counts` key.
- [x] **Multi-gate conditional block that EXECUTES.** A single `c_if`
      whose block applies ≥ 2 gates (e.g. `X q1 |> X q2`), gated true,
      then measure both → pins that the whole block runs (existing
      multi-gate test only checks capture, never runs it).
- [x] **Probabilistic chain.** `h(0) |> measure(0,0)` then two `c_if(0,1)`
      on different qubits → ~50% all-fire / ~50% all-skip; `assert_in_delta`
      wide band; assert the two outcome buckets sum to the shot count.

## Phase 3 — Nested conditionals (rejection / characterization)

> Nesting raises `Qx.ConditionalError` at BUILD time (scratchpad **C1**).
> Assert via the public `Qx.c_if/4` (existing nested test uses
> `Operations.c_if`).

- [x] Bare nested `c_if` (inner is the sole block instruction) via
      `Qx.c_if/4` raises `Qx.ConditionalError` (message ~ "Nested").
- [x] **Inner `c_if` not first** — block = `X q1` then an inner `c_if`
      — still raises (pins `Enum.each`-over-all-instructions, not just
      head).
- [x] **Build-time, not run-time** — assert the raise fires during the
      `Qx.c_if/4` call itself (no `run/2` needed); e.g. wrap only the
      `c_if` construction in `assert_raise`.
- [x] **Triple nesting** — `c_if` inside `c_if` inside `c_if` raises at
      the outer construction (first nesting detected).

## Phase 4 — Verify (mandatory gate)

- [x] `mix compile --warnings-as-errors` clean.
- [x] `mix format` clean.
- [x] `mix test test/qx/conditional_operations_test.exs` green.
- [x] `mix test` (full suite) green — no regressions.
- [x] `mix test --cover` — note any rise in `Qx.Simulation`
      conditional-path / `Qx.Operations` `c_if` coverage.
- [x] `mix credo --strict` clean on the new file.

---

## Risks / self-check

- **Wasted effort?** If the v0.8.2 refactor *adds* nested-execution
  support, the Phase 3 rejection tests would need updating — but that is
  a deliberate behaviour change that SHOULD break a test and force a
  review. Today nesting is rejected; we pin today's contract.
- **Overlap with existing tests?** Mitigated by the explicit non-overlap
  audit in Context; new tests target same-bit chains, mixed fire/skip,
  ≥3 chains, executing multi-gate blocks, and build-time/non-head
  nesting rejection — none of which exist today.
- **Flaky probabilistic test?** Wide `assert_in_delta` band + assert the
  bucket sum equals shots (deterministic invariant) rather than tight
  per-bucket counts.

## Out of scope (explicit)

- Adding nested-conditional *execution* support (a behaviour change, not
  a test) — would be its own roadmap item.
- Editing the existing `qx_test.exs` / `operations_typed_errors_test.exs`
  conditional tests (TDD hook; no need — new file covers the gap).
- `c_if` OpenQASM export/lowering tests (separate concern, already have
  their own files).
