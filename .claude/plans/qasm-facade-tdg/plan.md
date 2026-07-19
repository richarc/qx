# tdg gate + QASM facade surface (v0.11 Additive surface, part 2 · T1-05/07/12)

**Branch:** `feat/qasm-facade-tdg`
**ROADMAP:** v0.11 "Additive surface" (part 2 of 2 — landing this **completes**
the item; tick the ROADMAP checkbox in the merge commit, since part 1
`feat/circuit-appenders` already merged to `main`).
**Depth:** comprehensive · **Complexity:** 8 (new gate/domain concept +3,
crosses Operations/Simulation/Draw/Export +3, changes declared-public
`Qx`/`Qx.Operations`/`Qx.Export.OpenQASM` surface +3, follows the
sdg/t + defdelegate pattern −2). Full Iron Law #9 dispatch exercise.
**Research:** hex-deps → NO new dep (`Qx.Gates.t_dagger/0` matrix + existing
nimble_parsec/Nx). Summary in `research/hex-deps.md`, decisions in `scratchpad.md`.

## Decision

Complete the `{s, sdg, t, tdg}` phase-gate family and give the `Qx` facade the
OpenQASM entry points, all ADDITIVE:

1. **Native `tdg` gate** (symmetric with the already-native `sdg`/`t`):
   `Qx.Operations.tdg/2` emits `{:tdg, [q], []}`, dispatched in the shared
   `apply_instruction/3` via the EXISTING `Qx.Gates.t_dagger/0` matrix (covers
   both `run/2` and `steps/2`), drawn `"T†"`, and round-tripped through QASM.
2. **`Qx.tdg/2`** facade delegate to `Operations`.
3. **QASM facade delegates:** `Qx.to_qasm/2`, `Qx.from_qasm/1`, `Qx.from_qasm!/1`
   → `Qx.Export.OpenQASM`.
4. **Opportunistic fix:** the draw layer is missing `:sdg` (a pre-existing gap —
   `:sdg` is in neither `validate_gate!`'s `supported_gates` nor
   `gate_label_and_color`); add `:sdg`/`:tdg` labels together for a consistent
   dagger family.

**Auto-decided while user away (2026-07-11 timeout — revisit if wrong):**
native `:tdg` over a thin `phase(-π/4)` convenience; fix `:sdg` draw gap in
this branch; QASM facade = the three delegates only (`from_qasm_function`
stays deferred to its own atom-vs-string SemVer item).

**This is NEW code → TDD applies.** House doc style on every new public
function: `@spec` + `## Parameters`/`## Returns`/`## Raises` + doctest.

### Scope

**IN:** `Operations.tdg/2` + full `:tdg` dispatch (simulation, draw, QASM
export+import round-trip), `:sdg` draw-label fix, `Qx.tdg/2` +
`Qx.to_qasm/2`/`from_qasm/1`/`from_qasm!/1` facade delegates, docs + tests.
**OUT (→ separate item):** `from_qasm_function/1` + `from_qasm_function!/1`
facade delegates and the atom-vs-string SemVer change. **OUT:** any new gate
beyond `tdg`.

### Target signatures

```elixir
# Qx.Operations
@spec tdg(QuantumCircuit.t(), non_neg_integer()) :: QuantumCircuit.t()
def tdg(circuit, qubit), do: QuantumCircuit.add_gate(circuit, :tdg, qubit)

# Qx facade
@spec tdg(circuit(), non_neg_integer()) :: circuit()
defdelegate tdg(circuit, qubit), to: Operations
@spec to_qasm(circuit(), keyword()) :: String.t()
defdelegate to_qasm(circuit, options \\ []), to: Qx.Export.OpenQASM
@spec from_qasm(String.t()) :: {:ok, circuit()} | {:error, Exception.t()}
defdelegate from_qasm(source), to: Qx.Export.OpenQASM
@spec from_qasm!(String.t()) :: circuit()
defdelegate from_qasm!(source), to: Qx.Export.OpenQASM
```

### Dispatch surface (Iron Law #9 — every `:tdg` emission needs a consumer)

| Consumer | File | Change |
|---|---|---|
| Producer | `lib/qx/operations.ex` | new `tdg/2` → `{:tdg,[q],[]}` |
| Simulate (run+steps) | `lib/qx/simulation.ex` ~509 | `:tdg -> Calc.apply_single_qubit_gate(state, Gates.t_dagger(), q, n)` + add `:tdg` to the single-qubit classifier at `apply_instruction/3` (~479-495) so it routes to `apply_single_qubit_op`, not the `{:unsupported_gate}` fallback |
| Draw | `lib/qx/draw/svg/circuit.ex` | add `:sdg`,`:tdg` to `supported_gates` (~112) + `:sdg -> {"S†",…}`, `:tdg -> {"T†",…}` in `gate_label_and_color` (~676) |
| QASM export | `lib/qx/export/openqasm.ex` ~289 | `{:tdg, qubits, params} -> single_qubit_gate_to_qasm("tdg", qubits, params)` |
| QASM import | `lib/qx/export/openqasm/lowering.ex` | add `"tdg" => {:tdg, 1, 0}` to `@stdgate_table` (~18); REMOVE `tdg` from `@decomposable_gates` (~225) + delete the `expand_gate({:decompose,"tdg"},…)` clause (~273) |

`Qx.Gates.t_dagger/0` already exists — no matrix work. `add_gate` does NOT
whitelist gate names (accepts any atom) — no change there.

---

## Phase 1 — Native `tdg` gate: Operations + Simulation (TDD)

- [x] [P1-T1] **Tests first** — `test/qx/operations_test.exs` (or the file that
      tests sdg/t): assert `tdg(new(1),0)` emits `{:tdg,[0],[]}`; out-of-range
      qubit → `Qx.QubitIndexError`. **Execution test (Iron Law #9)** in the
      simulation test file: a circuit exercising `:tdg` via `Qx.run/2` (and one
      via `Qx.steps/2`) produces the correct state — e.g. `t |> tdg` on `|+⟩`
      equals identity (state ≈ `|+⟩`), and `tdg` alone applies the −π/4 phase
      on `|1⟩` (compare probabilities/state to a `phase(-π/4)`-built reference,
      tolerance ≥ 1.0e-6 per Iron Law #8). Run — MUST FAIL (`tdg` undefined /
      `:tdg` unsupported).
- [x] [P1-T2] Implement `Operations.tdg/2` (mirror `sdg/2`): one-line
      `add_gate(circuit, :tdg, qubit)` + `@spec` + `@doc` (Parameters/Returns/
      Raises/doctest asserting the `{:tdg,[0]}` shape like the sdg doctest).
- [x] [P1-T3] Wire simulation dispatch: add `:tdg` to the single-qubit gate
      classifier in `apply_instruction/3` and the `:tdg -> …Gates.t_dagger()…`
      arm in `apply_single_qubit_op`. Confirm the P1-T1 execution tests pass for
      BOTH `run/2` and `steps/2`; `mix compile --warnings-as-errors`.

## Phase 2 — Draw: `:tdg` label + `:sdg` gap fix (TDD)

- [x] [P2-T1] **Tests first** — the draw/svg test file: assert a circuit with
      `tdg` renders a `"T†"` gate label, and a circuit with `sdg` renders `"S†"`
      (pins the pre-existing gap fix). Assert neither raises in `validate_gate!`.
      Run — FAIL (`:tdg`/`:sdg` unsupported or mislabeled).
- [x] [P2-T2] Add `:sdg`, `:tdg` to `supported_gates` in `validate_gate!` and
      `:sdg -> {"S†", @color_hadamard}`, `:tdg -> {"T†", @color_hadamard}` to
      `gate_label_and_color/2`. Tests pass; compile clean.

## Phase 3 — QASM export + import round-trip (TDD)

- [x] [P3-T1] **Tests first** — `test/qx/export/openqasm_test.exs`: `to_qasm`
      of a `tdg` circuit contains `"tdg q[0];"`; `from_qasm` of a program with
      `tdg q[0];` yields a NATIVE `{:tdg,[0],[]}` instruction (NOT
      `{:phase,…}`); a **round-trip** test `circuit_with_tdg |> to_qasm |>
      from_qasm!` preserves the `:tdg` instruction. Run — FAIL (export has no
      `:tdg` arm; import still decomposes to `:phase`).
- [x] [P3-T2] Export: add the `{:tdg, …} -> single_qubit_gate_to_qasm("tdg",…)`
      clause in `instruction_to_qasm/2` (after `:t`).
- [x] [P3-T3] Import: add `"tdg" => {:tdg, 1, 0}` to `@stdgate_table`; remove
      `tdg` from `@decomposable_gates` and delete the decompose clause. Verify
      NO existing openqasm test that asserted the old `tdg → phase(-π/4)`
      decomposition breaks — if one exists, it's an **intended behaviour change**
      (get human sign-off before modifying an existing test; note in scratchpad
      + CHANGELOG **Changed**). Full openqasm suite passes.

## Phase 4 — Facade delegates: `Qx.tdg/2` + QASM (TDD)

- [x] [P4-T1] **Tests first** — facade delegate tests (mirror existing
      "delegates to …" assertions): `Qx.tdg` == `Operations.tdg`; `Qx.to_qasm`
      == `Qx.Export.OpenQASM.to_qasm`; same for `from_qasm`/`from_qasm!`. Run — FAIL.
- [x] [P4-T2] Add `Qx.tdg/2` delegate near the `t`/`sdg` delegates
      (`lib/qx.ex`); add `Qx.to_qasm/2`, `Qx.from_qasm/1`, `Qx.from_qasm!/1`
      delegates near the existing QASM-referencing docs. Add `alias
      Qx.Export.OpenQASM` if not already aliased. Full `@doc`
      (Returns/Raises) + `@spec` + a facade doctest for each (e.g. `Qx.tdg`
      shape doctest; a `to_qasm`/`from_qasm!` round-trip doctest). These run via
      the existing `doctest Qx`. Compile clean.

## Phase 5 — CHANGELOG & verify

- [x] [P5-T1] CHANGELOG `[Unreleased]`: **Added** — `Qx.tdg/2` (native T† gate,
      full run/steps/draw/QASM support) and `Qx.to_qasm/2`, `Qx.from_qasm/1`,
      `Qx.from_qasm!/1` facade delegates. **Changed** — `from_qasm` now maps
      `tdg` to a native `:tdg` instruction instead of decomposing to
      `phase(-π/4)` (semantically identical; cleaner round-trip). Fixed the
      `sdg`/`tdg` circuit-drawing labels. Non-breaking; no version bump
      (tag-gated). Note tag-worthiness: with part 1 already merged, this
      completes v0.11 "Additive surface".
- [x] [P5-T2] Full gate: `mix compile --warnings-as-errors && mix format
      --check-formatted && mix credo --strict && mix test`.
- [x] [P5-T3] `mix docs` warning count ≤ baseline (36) — new doctests + type
      refs autolink; stash-diff the warning LISTS if the count moves (CLAUDE.md
      docs discipline).

## Iron Laws check

- **#6 (public API):** ADDITIVE — new `tdg/2` + 4 facade delegates. The import
  `tdg → :tdg` change is a behaviour refinement, not a signature/return-type
  break; CHANGELOG **Changed** entry; no minor bump needed (same observable
  simulation result). No existing public signature changed.
- **#7 (typed errors):** `tdg` qubit misuse → `Qx.QubitIndexError` via
  `add_gate`/`validate_qubit_index!`; QASM funcs already raise
  `Qx.Qasm*Error`. No raw error leaks through the new facade delegates.
- **#9 (dispatch completeness):** `:tdg` is a NEW instruction shape → every
  consumer gets an arm (table above), verified by tracing `Operations.tdg`
  output through `run/2` AND `steps/2` with an **execution** test (not just
  construction/draw/export). No dead special-case arm added; the `tdg` import
  decompose clause is DELETED (not left as false evidence).
- **#8 (tolerance):** `:c64` float32 — tdg-vs-phase equivalence assertions use
  tolerance ≥ 1.0e-6; reuse `assert_in_delta`/existing state-compare helpers.
- **TDD:** every new public function + the new dispatch arm gets a failing test
  first (Phases 1–4); existing tests unmodified except a possible intended
  openqasm decomposition-behaviour test (Phase 3, human-approved).

## Risks

1. **Import behaviour change** (`tdg → :tdg` vs `→ phase`). Mitigation: P3-T1
   round-trip test + explicit check for a pre-existing decomposition test;
   CHANGELOG **Changed**; human sign-off before touching any existing test.
2. **Single-qubit classifier miss** — if `:tdg` is added to the
   `apply_single_qubit_op` arm but NOT to the classifier that routes it there,
   it falls to `{:unsupported_gate}` → `Qx.GateError`. Mitigation: P1-T1
   execution test catches it; trace the ~479-495 dispatch by hand (Iron Law #9).
3. **Draw `:sdg` scope creep** — the `:sdg` fix is opportunistic; kept tiny
   (two label lines + supported list) and pinned by its own test.
4. **Docs-warning autolink** — new doctests/specs feed ex_doc; P5-T3 count gate.

## Self-check (comprehensive)

- *What could break unexpectedly?* The import round-trip change (Risk 1) and the
  classifier routing (Risk 2) — both covered by execution/round-trip tests.
- *What did research rule out?* A new hex dep (`t_dagger` matrix + nimble_parsec
  already present).
- *What's deferred?* `from_qasm_function/1` facade + its atom-vs-string SemVer
  change (separate item). After this merges, the ROADMAP "Additive surface"
  item is COMPLETE → tick it and consider a release.
