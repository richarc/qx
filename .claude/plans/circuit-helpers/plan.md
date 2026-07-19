# Qx Circuit-Building Helpers

**Branch:** `feat/circuit-helpers`
**Source:** User request — "recommend helper functions that would make writing Qx circuits easier and more concise"
**Target version:** Ships **in `0.8.0`** (additive — no breaking change). `0.8.0` is committed on `main` but not yet tagged, so this work extends its release scope rather than introducing a `0.8.1` patch.

## Context

The qxportal tutorials and the qx test suite hand-roll the same circuit-building motifs over and over. The most visible offender is **applying H to every qubit** (the user's named example), but the same shape appears for X, Y, Z, measurement, barrier, and CNOT cascades.

Concrete evidence from this session's Phase 1 exploration:

- `qxportal/priv/static/tutorials/quantum_algorithms.livemd:348-354` defines `apply_h_all/2` **and** `apply_x_all/2` privately, because no library equivalent exists. Both are used multiple times per algorithm (Grover diffuser, Bernstein-Vazirani oracle).
- `qxportal/priv/static/tutorials/quantum_algorithms.livemd:363-364` measures every qubit via `Enum.reduce(0..(n - 1), c, fn i, c -> Qx.measure(c, i, i) end)` — the same shape repeats in every circuit-mode example.
- `lib/qx.ex` already has *state-shaped* helpers (`Qx.bell_state/0,1`, `Qx.ghz_state/0`) and `Qx.StateInit.{superposition_state, bell_state, ghz_state, w_state}/2` for state vectors. **What's missing is the circuit-mode analogue for the simple bulk ops.**

Single human dev, single quantum lib, no rush — but every tutorial reader currently sees the same `Enum.reduce` boilerplate, which dilutes the pedagogical signal.

## Recommended scope — 7 helpers in a new `Qx.Patterns` module

Tier kept tight on purpose: every helper is < 20 lines and reduces a real boilerplate from the tutorials. No algorithm primitives (QFT, Grover diffuser, inverse, compose) — those are bigger, need careful decomposition, and fit ROADMAP v0.10 "Algorithms & Learning".

| # | Function | Signature | Replaces | Cites |
|---|---|---|---|---|
| 1 | `h_all/1` | `(QuantumCircuit.t()) :: QuantumCircuit.t()` | `apply_h_all/2` private helper | quantum_algorithms.livemd:348 |
| 2 | `x_all/1` | same | `apply_x_all/2` private helper | quantum_algorithms.livemd:352 |
| 3 | `y_all/1` | same | hand-rolled `Enum.reduce` | symmetry / Grover-like circuits |
| 4 | `z_all/1` | same | hand-rolled `Enum.reduce` | symmetry / phase-flip layers |
| 5 | `measure_all/1` | same | `Enum.reduce(0..(n - 1), c, &Qx.measure(&2, &1, &1))` | quantum_algorithms.livemd:363 |
| 6 | `barrier_all/1` | same | `Qx.Operations.barrier(qc, Enum.to_list(0..(n - 1)))` | openqasm_test.exs barrier sites |
| 7 | `cx_chain/2` | `(QuantumCircuit.t(), [non_neg_integer()]) :: QuantumCircuit.t()` | cascading `cx(q0,q1) → cx(q1,q2) → …` (e.g. GHZ-3+) | systems_of_qubits_and_entanglement.livemd ghz_circuit |

All 7 raise the *existing* typed `Qx.QubitIndexError` / `Qx.ClassicalBitError` (inherited from `Qx.Validation` and `QuantumCircuit.add_*` — no new exception types needed). `cx_chain` with `[]` or `[q]` is a deliberate no-op (returns circuit unchanged); 2+ qubits emit `length(list) - 1` CX instructions.

`measure_all/1` raises `Qx.ClassicalBitError` if `num_classical_bits < num_qubits` (delegated to the existing typed-error from `add_measurement/3`) — **no auto-grow**. Reason: consistent with the Iron Law #7 work just shipped; circuit shape is a structural decision the caller owns at `create_circuit/2`.

## Out of scope (deferred)

- **`mcx/3` (multi-controlled X for >2 controls)** — needs proper decomposition (ancilla-based or relative-phase Toffoli). The tutorial's `multi_cx/3` at `quantum_algorithms.livemd:357-372` is Grover-specific, not a general MCX. Defer to a future plan with explicit decomp design.
- **`compose/2` / `inverse/1`** — circuit concatenation and adjoint. `inverse/1` requires per-gate adjoint knowledge and parameter negation; non-trivial.
- **Algorithm primitives**: QFT, Grover diffuser, phase estimation — fit ROADMAP v0.10.
- **Range / sub-list variants** (`h_range/2`, `measure_range/3`, …) — every helper here is "all qubits". Users wanting a sub-range keep using `Enum.reduce(range, qc, &Qx.h(&2, &1))`. A future ROADMAP item can add `_range` variants if a real need surfaces.
- **Overloading existing `Qx.h/2` etc. to accept a list/range** (Qiskit-style `qc.h(range(n))`) — would change error behavior for non-integer inputs and is less discoverable. Rejected; `_all` variants are explicit and additive.

## Module placement — new `lib/qx/patterns.ex`

Precedent: `Qx.StateInit` is the sibling-module pattern for "composite ops on top of primitives" (state-vector recipes there; circuit-instruction recipes here). Reasons over extending `Qx.Operations`:

- `Qx.Operations` already exports 37 public functions, each emitting **one** instruction. Patterns emit multiple — a different category.
- Keeps gate API surface uncluttered for IDE discovery.
- New module is trivial: a thin wrapper over `Qx.Operations` + `Qx.QuantumCircuit`.

Top-level `Qx` will `defdelegate` all 7 (`Qx.h_all/1`, `Qx.measure_all/1`, …) so users don't have to type `Qx.Patterns.` — the existing top-level convenience surface stays consistent. `mix.exs` `groups_for_modules` gets a new "Composite Patterns" group listing `Qx.Patterns`.

## Phases

### Phase 1 — `Qx.Patterns` module + bulk single-qubit ops
- [x] Create `lib/qx/patterns.ex` with `@moduledoc` cross-linking to `Qx.Operations` and `Qx.StateInit`
- [x] Implement `h_all/1`, `x_all/1`, `y_all/1`, `z_all/1` — each `Enum.reduce(0..(circuit.num_qubits - 1), circuit, &Qx.Operations.{gate}(&2, &1))`
- [x] Add `@spec` for each (Iron Law #6 surface — though additive, set the example)
- [x] Write `test/qx/patterns_single_qubit_test.exs` — golden-path test per gate (2- and 3-qubit circuits; verify instructions list); edge cases (1-qubit circuit, num_qubits=1 → single instruction)
- [x] `mix compile --warnings-as-errors && mix format --check-formatted && mix test test/qx/patterns_single_qubit_test.exs`

### Phase 2 — `measure_all/1` and `barrier_all/1`
- [x] Implement `measure_all/1` — `Enum.reduce(0..(circuit.num_qubits - 1), circuit, &Qx.QuantumCircuit.add_measurement(&2, &1, &1))`
- [x] Implement `barrier_all/1` — `Qx.Operations.barrier(circuit, Enum.to_list(0..(circuit.num_qubits - 1)))`
- [x] Add `@spec` for both
- [x] Add to test file: `measure_all` happy path (3-qubit, 3-classical circuit → 3 measurements at correct bits), error path (`num_classical_bits < num_qubits` raises `Qx.ClassicalBitError`), `barrier_all` happy path
- [x] Verify

### Phase 3 — `cx_chain/2`
- [x] Implement `cx_chain/2` accepting `[non_neg_integer()]` — `qubits |> Enum.chunk_every(2, 1, :discard) |> Enum.reduce(circuit, fn [c, t], acc -> Qx.Operations.cx(acc, c, t) end)`
- [x] Empty list and single-element list: no-op, return circuit unchanged (documented in `@doc`)
- [x] Add `@spec`
- [x] Add to test file: 4-qubit chain `[0, 1, 2, 3]` → 3 CX instructions in order; empty list returns identical circuit; single-element list returns identical circuit; invalid qubit index propagates `Qx.QubitIndexError` (Iron Law #7 inheritance from `add_two_qubit_gate`)
- [x] Verify

### Phase 4 — Top-level `Qx` delegates + docs
- [x] Add `defdelegate h_all(circuit), to: Qx.Patterns` for all 7 in `lib/qx.ex` (and matching `@spec` per existing style)
- [x] Update `lib/qx.ex` `@moduledoc` to mention the patterns layer
- [x] Update `mix.exs` `groups_for_modules`: add `"Composite Patterns": [Qx.Patterns]` (after the `"Circuit Building"` group)
- [x] Doctests in `Qx.Patterns` showing each helper's effect on a small circuit (3-qubit, instruction-list-based — same shape as existing `Qx.Operations` doctests)
- [x] Verify

### Phase 5 — Release prep
- [x] **No `mix.exs` version bump** — `version: "0.8.0"` stays. These helpers extend the unreleased `0.8.0` scope (committed on `main`, not yet tagged via `release-manager`).
- [x] `CHANGELOG.md` — **amend** the existing `## [0.8.0] - 2026-05-21` section: add the new helpers under `### Added` (after the `Qx.StateShapeError` and `Qx.QubitIndexError {:duplicate, ...}` entries). No new `### BREAKING` content — purely additive.
- [x] Update `ROADMAP.md` v0.8 section: tick the existing `Circuit-building convenience helpers …` entry (added during this plan update — currently unchecked).
- [x] Full gate: `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test`
- [x] Self-review against Iron Laws (1, 2, 6, 7 — #3/#4/#5/#8 not applicable, no Nx kernel work)

## Cross-repo follow-on (not in this branch)

After `0.8.0` is tagged and ships on Hex (release-manager agent, post-this-plan):
- **`qxportal`**: separate branch + commit migrating `apply_h_all/2` / `apply_x_all/2` / `multi_cx/3` / measure-loop boilerplate in `priv/static/tutorials/quantum_algorithms.livemd` to use the new library helpers. Bumps qxportal's `qx` dep to `~> 0.8`.
- **`kino_qx`**: no expected change; smart cell doesn't construct circuits.

Per workspace CLAUDE.md "Never edit two repos in the same commit" — these are deliberate downstream steps gated by the qx release.

## Verification gate (qx CLAUDE.md mandatory)
```
mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict
mix test
```

## Notes

- All 7 helpers are < 20 lines each; total new lib code budget ~120 lines + ~150 lines of tests + doctests.
- No new exception types. Iron Law #7 enforcement is **inherited** from `Qx.QuantumCircuit.add_*` (which routes through `Qx.Validation` since the 0.8.0 work).
- No `defn`, no Nx kernel work — Iron Laws #3/#4/#5/#8 not in play.
- No processes / no atom interning of user input — Iron Laws #1/#2 trivially clean.
- The 7-helper set is the *floor* of what tutorials demand. If user wants to expand later, the natural next tier is: `compose/2`, `inverse/1`, then `mcx/3` with proper decomposition, then algorithm primitives in v0.10.

## Risks

1. **Naming collision with `Qx.superposition/0`** — that's a 0-arity top-level circuit helper that returns a 1-qubit H circuit. `Qx.h_all/1` does not collide structurally but the *concept* overlaps ("put qubits in superposition"). Mitigation: cross-link in `@moduledoc` and `@doc` of `Qx.Patterns.h_all`.
2. **User confusion with `Qx.StateInit.superposition_state/2`** — that returns a *state vector*, not a circuit. Documented difference is enough.
3. **`cx_chain` semantics ambiguity** — is `cx_chain(qc, [0,1,2])` `cx(0,1)→cx(1,2)` (linear chain) or `cx(0,1)→cx(0,2)` (star from qubit 0)? Plan picks linear chain — it's what GHZ-style entanglement uses and what the literal name "chain" implies. Document explicitly to remove ambiguity; provide `ghz_chain/2` alias if star-form ever becomes a separate need.

## Stop conditions
- Skill stops at merge gate after self-review per qx CLAUDE.md workflow. Does NOT merge to `main` — human authorization required.
