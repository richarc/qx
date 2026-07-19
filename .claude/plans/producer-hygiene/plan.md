# Producer hygiene — single instruction-producer surface (v0.11 · B-04/11/12)

**Branch:** `feat/producer-hygiene`
**ROADMAP:** v0.11 "API Review Follow-Through" — the "Producer hygiene" item.
Ticks that checkbox on merge.
**Depth:** standard · **Complexity:** 5 (crosses Operations/Patterns/
QuantumCircuit +3, pure INTERNAL refactor following the existing `add_*`
pattern −2, Iron Law #9 pressure). No new dep.
**Research:** none needed — pure struct/list composition over existing helpers.

## Decision (user-confirmed 2026-07-12)

Centralise ALL instruction-tuple construction+append in `Qx.QuantumCircuit`'s
`add_*` family, so there is one auditable producer surface per instruction kind
(Iron Law #9 hygiene). Purely INTERNAL and byte-identical — no public signature,
return, or output changes.

1. **`Patterns.measure_all/2`** → compose `Operations.measure/3` instead of
   calling `QuantumCircuit.add_measurement/3` directly (consistency: patterns
   build on the `Operations` surface, not the `QuantumCircuit` internal).
2. **Barrier + c_if single producer path** → add `@doc false`
   `QuantumCircuit.add_barrier/2` and `add_conditional/4` that build+append the
   `{:barrier, …}` / `{:c_if, …}` tuples. `Operations.barrier/2` and `c_if/4`
   keep their orchestration + validation (`validate_qubit_indices!`, running
   `gate_fn`, the c_if clause guards) but delegate the final tuple
   construction+append to these helpers — removing the inline
   `%{circuit | instructions: … ++ [instruction]}` duplication.
3. **`add_gate`** → already internal (`@doc false`, zero external callers); NO
   per-name validation (gate_name is always a hardcoded atom from `Operations`;
   a per-name allowlist would need maintenance every gate add for ~zero safety
   gain — Iron Law #9 is covered by the execution-test-per-shape rule). Add a
   short doc comment naming the `add_*` family as the trusted internal producer
   surface. (Confirmed: "moves internal" is satisfied.)

**This is a PURE REFACTOR — byte-identical output is the whole contract.** The
tripwire is the UNMODIFIED existing suite (`barrier_dispatch_test`,
`conditional_operations_test`, `patterns_test` measure_all, `step_test`,
`simulation_*`) plus a few explicit invariant assertions per phase.

### Current state (verified)

| Instruction | Producer today | After |
|---|---|---|
| 1/2/3-qubit gate | `QuantumCircuit.add_gate` / `add_two_qubit_gate` / `add_three_qubit_gate` | unchanged (+ doc comment) |
| measure | `QuantumCircuit.add_measurement` | unchanged; `measure_all` now routes via `Operations.measure/3` |
| barrier | **inline in `Operations.barrier/2`** (`{:barrier, qubits, []}` + `%{circuit\| …}`) | `QuantumCircuit.add_barrier/2` |
| c_if | **inline in `Operations.c_if/4`** (`{:c_if, [cb, val], instrs}` + `%{circuit\| …}`) | `QuantumCircuit.add_conditional/4` |

---

## Phase 1 — `Patterns.measure_all/2` composes `Operations.measure/3`

- [x] [P1-T1] **Invariant test first** (`test/qx/patterns_test.exs`, additive):
      assert `new(3,3) |> measure_all()` instruction list is unchanged
      (`[{:measure,[0,0],[]},{:measure,[1,1],[]},{:measure,[2,2],[]}]`) AND
      equals `new(3,3) |> Operations.measure(0,0) |> Operations.measure(1,1) |>
      Operations.measure(2,2)`. Confirm existing measure_all tests are NOT
      modified. (These PASS now — they pin the invariant before the swap.)
- [x] [P1-T2] Change `measure_all/2` body: `Enum.reduce(qubits_to_list(qubits),
      circuit, fn i, acc -> Operations.measure(acc, i, i) end)` (was
      `QuantumCircuit.add_measurement(acc, i, i)`). Add `alias Qx.Operations` if
      needed. `measure/3` is a thin wrapper over `add_measurement/3`, so output
      is byte-identical. Full suite + measure_all tests pass unchanged;
      `mix compile --warnings-as-errors`.

## Phase 2 — `QuantumCircuit.add_barrier/2`; `Operations.barrier/2` delegates

- [x] [P2-T1] **Invariant test first**: pin `new(3) |> barrier([0,1,2])` →
      `[{:barrier,[0,1,2],[]}]`; confirm existing `barrier_dispatch_test` +
      `barrier_all` tests unmodified. A direct unit test of the new helper:
      `QuantumCircuit.add_barrier(new(3), [0,2])` → `[{:barrier,[0,2],[]}]`.
- [x] [P2-T2] Add `@doc false QuantumCircuit.add_barrier(circuit, qubits)`:
      builds `{:barrier, qubits, []}` and appends (mirrors `add_gate`'s append).
      Reframe `Operations.barrier/2` to `validate_qubit_indices!` then
      `QuantumCircuit.add_barrier(circuit, qubits)`. Byte-identical; full suite
      unchanged.

## Phase 3 — `QuantumCircuit.add_conditional/4`; `Operations.c_if/4` delegates

- [x] [P3-T1] **Invariant test first**: pin a representative c_if instruction
      list (`h |> measure |> c_if(0,1,fn c -> x(c,1) end)` →
      `…{:c_if,[0,1],[{:x,[1],[]}]}`); confirm existing
      `conditional_operations_test` unmodified. Direct unit test:
      `QuantumCircuit.add_conditional(circuit, 0, 1, [{:x,[1],[]}])` →
      appends `{:c_if,[0,1],[{:x,[1],[]}]}`.
- [x] [P3-T2] Add `@doc false QuantumCircuit.add_conditional(circuit,
      classical_bit, value, conditional_instructions)`: builds `{:c_if,
      [classical_bit, value], conditional_instructions}` and appends. Reframe the
      happy-path `Operations.c_if/4` clause to keep its orchestration (run
      `gate_fn` on the temp circuit, `validate_conditional_block`) then call
      `QuantumCircuit.add_conditional(...)` for the final build+append. KEEP all
      the c_if guard clauses (value ∉ 0/1, non-fn gate_fn, bad classical bit)
      unchanged. Byte-identical; full suite unchanged.

## Phase 4 — `add_gate` producer-surface doc

- [x] [P4-T1] Add a brief comment above the `add_*` family (or the
      `QuantumCircuit` moduledoc's internal section) naming it the single trusted
      internal instruction-producer surface: every instruction tuple is built +
      appended here, gate_name/kind atoms come only from `Operations`/`Patterns`
      (never user input), and Iron Law #9 coverage is the execution-test-per-
      shape rule — no per-name allowlist. No code change to `add_gate`.

## Phase 5 — verify

- [x] [P5-T1] Full gate: `mix compile --warnings-as-errors && mix format
      --check-formatted && mix credo --strict && mix test`. The ENTIRE suite
      passing unchanged IS the byte-identical proof.
- [x] [P5-T2] `mix docs` warning count ≤ baseline (36).
- [x] [P5-T3] No CHANGELOG version bump — internal refactor, no user-facing
      change. Optionally a one-line **Changed** (internal) note; otherwise none.

## Iron Laws check

- **#6 (public API):** NO public change — `Operations.barrier/c_if`,
  `Patterns.measure_all`, `Qx.*` facades keep identical signatures + output. New
  `QuantumCircuit.add_barrier/add_conditional` are `@doc false` internal. No
  version bump.
- **#9 (dispatch/producer completeness):** the POINT of this item — every
  instruction tuple (`:barrier`, `:c_if`, gates, `:measure`) is now produced by
  the one `QuantumCircuit.add_*` surface, greppable in one module. No new
  instruction SHAPE introduced, so no consumer arm changes.
- **#7 (typed errors):** unchanged — validations (`validate_qubit_indices!`,
  c_if guards) stay in `Operations`; the new helpers only build+append.

## Risks

1. **Behaviour drift** — the whole non-breaking claim rests on byte-identical
   output. Mitigation: invariant tests per phase + the UNMODIFIED existing
   barrier/c_if/measure_all suites as the tripwire (run full suite each phase).
2. **c_if orchestration split** — `c_if/4` builds a temp circuit via `gate_fn`
   then extracts `.instructions`. Only the FINAL `{:c_if,…}` build+append moves
   to `add_conditional/4`; the temp-circuit orchestration + validation stays in
   `Operations`. Getting that boundary wrong would change output — pinned by
   P3-T1 + `conditional_operations_test`.

## Self-check

- *What could break?* Only output drift (Risk 1/2) — covered by the frozen
  existing suite + per-phase invariants.
- *Public surface?* None touched. Fully internal.
- *Deferred?* Nothing — this closes the ROADMAP "Producer hygiene" item.
