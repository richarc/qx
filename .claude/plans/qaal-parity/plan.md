# Qx ↔ QAAL parity: A1 + A2 + B1

**Branch:** `feat/qaal-parity`
**Source:** Elevation of items A1, A2, B1 from
`.claude/plans/qaal-analysis/plan.md`. A3 (`reset/2`) deferred to
v0.9.0; A4 (named circuit-mode register views) stashed for future
consideration.
**Target version:** Ships **in `0.8.0`** (additive, no breaking change).
`0.8.0` is committed on `main` but not yet tagged — this work extends
its release scope, joining the `Qx.Patterns` work from `circuit-helpers`.

## Context

The QAAL analysis (Reference material/Week 4 Prepare reading) flagged
three additive gaps in Qx's circuit-mode API:

- **A1** — controlled rotations and CY (`CRx`, `CRy`, `CRz`, `CY` in
  QAAL): missing entirely from Qx. Standard in OpenQASM 3 / Qiskit /
  Cirq.
- **A2** — basis-explicit measurement (`Mx`, `My`, `Mz` in QAAL): Qx
  has only `Qx.measure/3` (Z-basis). Tutorials hand-roll the basis
  change.
- **B1** — range/list overload of the `Qx.Patterns._all/1` helpers:
  natural generalisation of the just-shipped `h_all/measure_all/…`
  family to sub-registers.

Deferred / stashed:
- **A3** (`Qx.reset/2`) — deferred to v0.9.0 (touches `Qx.Simulation`
  instruction dispatch; bigger blast radius warrants its own milestone).
- **A4** (named circuit-mode register views) — stashed indefinitely:
  loses narrative-only value vs B1, costs significant API design work,
  collides with the existing calc-mode `Qx.Register` struct. Revisit
  if multi-register tutorials (Shor / phase estimation) start feeling
  unmanageable.

## Decisions resolved (from `qaal-analysis/scratchpad.md`)

1. **A1 naming:** `Qx.cy/3`, `Qx.crx/4`, `Qx.cry/4`, `Qx.crz/4`
   (lowercase, consistent with existing `cx/3`, `cz/3`, `ccx/4`,
   `rx/3`, `rz/3`).
2. **A2 post-measurement state:** **Option β (z-aligned, no rotate-back)**
   — `measure_x = H ; Mz`, `measure_y = Sdg ; H ; Mz`. *Decision changed
   from Option α during implementation* because Qx's simulator
   (`Qx.Simulation.run/2`) is a **deferred end-of-circuit sampler**:
   the `:measure` instruction is a no-op during state evolution and
   only records which qubit→bit pair to sample from the final state
   in the computational basis. A trailing `H` after the `Mz`
   instruction would undo the basis change in the simulated final
   state and yield 50/50 sampling on `|+⟩`/`|−⟩`. The **classical
   outcome** still matches QAAL `Mx`/`My`; only the post-measurement
   *quantum state* deviates (it stays Z-basis-aligned). Documented
   explicitly in the helper docstrings. Future mid-circuit measurement
   support (A3 reset/2 territory, v0.9.0) is the right place to
   revisit Option α.
3. **B1 overload arity:** add a 2-arg overload (`h_all/2`, …)
   accepting `[non_neg_integer()] | Range.t()`. The existing
   `h_all/1` (whole-circuit) stays as-is — strict superset is
   `h_all/2` accepting `0..(num_qubits - 1)`.

## Scope summary

| # | Helper | Signature | Notes |
|---|---|---|---|
| A1.1 | `Qx.Operations.cy/3` | `(QC.t(), c, t) :: QC.t()` | Pauli-Y controlled on `c`, applied to `t` |
| A1.2 | `Qx.Operations.crx/4` | `(QC.t(), c, t, float()) :: QC.t()` | Controlled-Rx(α) |
| A1.3 | `Qx.Operations.cry/4` | `(QC.t(), c, t, float()) :: QC.t()` | Controlled-Ry(α) |
| A1.4 | `Qx.Operations.crz/4` | `(QC.t(), c, t, float()) :: QC.t()` | Controlled-Rz(α) |
| A2.1 | `Qx.Operations.measure_x/3` | `(QC.t(), q, b) :: QC.t()` | `H q → Mz q b → H q` (Option α) |
| A2.2 | `Qx.Operations.measure_y/3` | same | `Sdg q → H q → Mz q b → H q → S q` |
| A2.3 | `Qx.Operations.measure_z/3` | same | alias of `Qx.measure/3` for symmetry |
| B1.1 | `Qx.Patterns.h_all/2` | `(QC.t(), [qi] \| Range.t()) :: QC.t()` | sub-register H |
| B1.2 | `Qx.Patterns.x_all/2`, `y_all/2`, `z_all/2` | same | sub-register Pauli |
| B1.3 | `Qx.Patterns.measure_all/2` | `(QC.t(), [qi] \| Range.t()) :: QC.t()` | sub-register Z-measure; uses same-index classical bits |
| B1.4 | `Qx.Patterns.barrier_all/2` | `(QC.t(), [qi] \| Range.t()) :: QC.t()` | sub-register barrier |

All 13 helpers raise the existing typed errors (`Qx.QubitIndexError`,
`Qx.ClassicalBitError`) inherited from the primitives — no new
exception types.

## Module placement

- **A1** — extends `Qx.Operations` (one-instruction-per-call gates).
  Top-level `Qx` delegates added.
- **A2** — extends `Qx.Operations` (single helper emits 2–4
  instructions; arguably bordering the `Qx.Patterns` boundary). Place
  in `Qx.Operations` because the instruction *category* is measurement
  (single qubit, single classical bit), not "composite pattern over
  every qubit". Top-level `Qx` delegates added.
- **B1** — extends `Qx.Patterns` (adds `/2` arity to each existing
  `/1` helper). Top-level `Qx` delegates already exist for `/1` —
  add matching `/2` delegates so call-site stays `Qx.h_all(qc, 0..2)`.

## Simulation backend

A1 needs simulation handlers for `:cy`, `:crx`, `:cry`, `:crz` in
`Qx.Simulation` / `Qx.Calc[Fast]`. Survey the existing two-qubit gate
handlers (`:cx`, `:cz`, `:cp`, `:swap`, `:iswap`) and follow the
matrix-contraction shape they use — Iron Law #3 (prefer reshape +
tensor contraction over gather/mask).

Matrix definitions:
- `CY`: 4×4 controlled-Y. Same as `CX` but target gate is Y instead of X.
- `CRx(α)`: 4×4 controlled-`Rx(α)` — `|0⟩⟨0|⊗I + |1⟩⟨1|⊗Rx(α)`.
- `CRy(α)`, `CRz(α)`: same shape with `Ry`/`Rz` as the target.

A2 needs no new simulation paths — it emits H/S/Sdg + existing measure.

B1 needs no new simulation paths — it emits the same instructions
as the `/1` form.

## OpenQASM export

A1 must round-trip in `Qx.Export.OpenQASM`:
- `CY` → `cy q[c], q[t];`
- `CRx(α)` → `crx(α) q[c], q[t];`
- `CRy(α)` → `cry(α) q[c], q[t];`
- `CRz(α)` → `crz(α) q[c], q[t];`

(All four exist in OpenQASM 3 stdgates.inc.)

A2 lowers to plain `h` / `s` / `sdg` + `measure` in OpenQASM — no new
export work; the basis-change gates are already emitted.

B1 needs no export change — the underlying instructions are unchanged.

## Phases

### Phase 1 — A1: controlled rotations
- [x] `Qx.Operations.cy/3` — emits `{:cy, [c, t], []}` via `QuantumCircuit.add_two_qubit_gate/5`
- [x] `Qx.Operations.crx/4`, `cry/4`, `crz/4` — emit `{:crx, [c, t], [theta]}` etc., via `add_two_qubit_gate/5` with params
- [x] `@spec` and `@doc` (with doctests asserting instruction shape) for each
- [x] `Qx.Simulation` dispatch entries for `:cy`, `:crx`, `:cry`, `:crz` — use the same contraction pattern as `:cz`/`:cp`
- [x] `Qx.Export.OpenQASM` entries for all four gates
- [x] `test/qx/operations_controlled_rotations_test.exs` — instruction-shape + simulation correctness (e.g. `CRz(π) ≡ CZ` up to phase; `CRx(π) ≡ iCX`)
- [x] `test/qx/export/openqasm_controlled_rotations_test.exs` — export round-trip
- [x] `mix compile --warnings-as-errors && mix format --check-formatted && mix test test/qx/operations_controlled_rotations_test.exs test/qx/export/openqasm_controlled_rotations_test.exs`

### Phase 2 — A2: basis-explicit measurement
- [x] `Qx.Operations.measure_z/3` — alias of `Qx.Operations.measure/3` (single-line)
- [x] `Qx.Operations.measure_x/3` — `qc |> h(q) |> measure(q, b) |> h(q)`
- [x] `Qx.Operations.measure_y/3` — `qc |> sdg(q) |> h(q) |> measure(q, b) |> h(q) |> s(q)`
- [x] `@spec` + `@doc` (cross-link to QAAL Mx/My/Mz)
- [x] `test/qx/operations_basis_measurement_test.exs` — instruction-list shape (verify the 3-/5-instruction expansion) and `Qx.run/2` outcome distribution on `|+⟩` and `|+i⟩` states
- [x] Verify

### Phase 3 — B1: range/list overload for `Qx.Patterns`
- [x] `h_all/2`, `x_all/2`, `y_all/2`, `z_all/2` — accept `[non_neg_integer()] | Range.t()`, reduce over the list applying the gate
- [x] `measure_all/2` — measure each qubit `q` in the list into classical bit `q`
- [x] `barrier_all/2` — emit a single barrier spanning the listed qubits
- [x] Empty list / empty range are no-ops (consistent with `cx_chain/2`)
- [x] Range support: convert `Range.t()` via `Enum.to_list/1` at the boundary; document the no-op edge `0..-1//1` (Elixir empty range)
- [x] `@spec` updated to dual-arity, `@doc` examples
- [x] Add to `test/qx/patterns_test.exs`: list form, range form, empty, mixed gate sequencing
- [x] Verify

### Phase 4 — Top-level `Qx` delegates + CHANGELOG + ROADMAP
- [x] `defdelegate cy(c, control, target), to: Operations` (and same for crx/cry/crz/measure_x/measure_y/measure_z)
- [x] `defdelegate h_all(circuit, qubits), to: Patterns` for the `/2` form, and same for x_all/y_all/z_all/measure_all/barrier_all
- [x] Update `Qx.@moduledoc` to mention basis-explicit measurement and controlled rotations
- [x] `mix.exs` — no `groups_for_modules` change needed (no new modules)
- [x] `CHANGELOG.md` — **amend** `## [0.8.0] - 2026-05-21` `### Added` section with three new bullet groups (A1 / A2 / B1) after the `Qx.Patterns` entry
- [x] `ROADMAP.md` v0.8 — add three new ticked items for A1, A2, B1 (with their plan slug); add unchecked entries under v0.9 for A3 (`Qx.reset/2`), and a "future considerations" item for A4 (named register views)
- [x] Doctests on the new top-level `Qx` delegates (one per gate, instruction-list shape)
- [x] Verify

### Phase 5 — Final verification + merge-gate review
- [x] Full gate: `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test`
- [x] `/phx:review` — parallel elixir-reviewer + testing-reviewer (skip security-analyzer: no auth/IO surface; skip iron-law-judge: no Nx defn work, no atom interning, additive only)
- [x] Apply review findings if any are blocking; re-run gate
- [x] STOP at merge gate per qx CLAUDE.md — human authorizes squash-merge

## Verification gate (qx CLAUDE.md mandatory)

```
mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict
mix test
```

## Notes / Iron Law compliance

- **Iron Law #1** (no `String.to_atom` on user input): N/A — gate names
  are internal atoms picked by the library (`:cy`, `:crx`, …).
- **Iron Law #2** (no processes): N/A — pure data transformations.
- **Iron Laws #3/#4/#5/#8** (Nx kernel work): the four new
  simulation handlers use the existing two-qubit contraction shape
  (see `:cz`, `:cp`). No new gather/mask patterns; backend-agnostic;
  no `2^n` host loops; no sub-epsilon tolerances. Verify by mimicking
  `:cz` precisely.
- **Iron Law #6** (public API surface): all changes additive — no
  CHANGELOG `### BREAKING` entry; version stays at unreleased 0.8.0.
- **Iron Law #7** (typed errors): `cy/3`, `crx/4`, … route through
  `QuantumCircuit.add_two_qubit_gate/5` which already raises
  `Qx.QubitIndexError` for OOR / duplicate indices. `measure_x/3` etc.
  route through `Operations.h/2` + `Operations.measure/3` which already
  raise `Qx.QubitIndexError` and `Qx.ClassicalBitError`. B1 helpers
  route through `Operations.{h, x, y, z}/2` and
  `QuantumCircuit.add_measurement/3` — same.
- All 13 helpers are < 10 lines each; ~80 lib lines + ~250 test lines.

## Risks

1. **Simulation correctness for CRx/CRy/CRz.** Easy to write the matrix
   wrong (mixing convention of `Rx(α) = exp(-iαX/2)` vs
   `e^{-iα/2}|+⟩⟨+| + e^{iα/2}|−⟩⟨−|`). Mitigation: copy the existing
   `:rx`/`:ry`/`:rz` handlers' matrix form exactly, and add an
   equivalence test: `CRz(π) ≡ CZ` (up to global phase),
   `CRz(0) ≡ I`, `CRx(2π) ≡ I`.
2. **A2 post-measurement state on already-collapsed qubit.** The
   trailing rotate-back in `measure_y` (`H → S`) is harmless on the
   post-Z-measurement basis state, but if a user chains
   `measure_y(q, r) |> measure_y(q, r2)` the second measurement sees a
   rotated qubit. This is *intentional* (matches QAAL) but should be
   documented.
3. **B1 overload + ambiguity.** `Qx.h_all(qc, [])` is a no-op — make
   sure the dispatch is unambiguous between the `/1` and `/2` forms
   (Elixir handles arity-based dispatch fine; the test suite must
   cover both).

## Stop conditions

Per qx CLAUDE.md: skill stops at the merge gate after
`/phx:review` PASS (or all findings triaged). Human authorizes the
squash-merge.
