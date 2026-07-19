# Scratchpad — qasm-facade-tdg (v0.11 Additive surface, part 2)

## USER-CONFIRMED 2026-07-11: "native + A"

- `tdg` = **native `:tdg` gate** (confirmed).
- QASM import = **option A (native round-trip)**: remove `tdg` from
  `@decomposable_gates`, map to native `:tdg`. **User explicitly approved
  updating the existing test `test/qx/export/openqasm/lowering_test.exs:159`
  ("tdg → phase(-pi/4)")** to assert `{:tdg,[0],[]}`. CHANGELOG **Changed** entry.
- `:sdg` draw-gap fix + 3 QASM facade delegates: as planned (unchanged).

## Scope decisions (originally auto-decided 2026-07-11; now user-confirmed above)

1. **`tdg` = native `:tdg` gate** (recommended), not a thin `phase(-π/4)`
   convenience. Rationale: `s`/`sdg`/`t` are all native; `Qx.Gates.t_dagger/0`
   matrix already exists; completes the family + faithful QASM round-trip.
   Cost: full Iron Law #9 dispatch (Operations/Simulation/Draw/Export/Import).
2. **Fix the `:sdg` draw gap in this branch.** `:sdg` is currently missing from
   `validate_gate!` supported_gates AND `gate_label_and_color` (draw/svg/
   circuit.ex) — a pre-existing gap. Add `:sdg`("S†")+`:tdg`("T†") together.
3. **QASM facade = 3 delegates** (`to_qasm/2`, `from_qasm/1`, `from_qasm!/1`).
   `from_qasm_function/1` + `from_qasm_function!/1` stay OUT — their
   atom-vs-string SemVer change remains its own separate ROADMAP item.

## Research (2026-07-11)

- **hex-deps.md:** NO new dependency. `t_dagger/0` matrix + nimble_parsec
  (import) + Nx (sim) all already present.
- **Dispatch map (verified by grep):**
  - `add_gate/4` does NOT whitelist gate names → no change; `:tdg` instruction
    just works structurally.
  - `run/2` and `steps/2` SHARE `apply_instruction/3` (simulation.ex:479) →
    ONE `:tdg` arm covers both. Unsupported gates hit
    `raise Qx.GateError, {:unsupported_gate, gate_name}` (484) — so a missing
    `:tdg` arm raises at runtime (the Iron Law #9 trap to avoid).
  - Existing native siblings: sim uses `Gates.s_dagger()` for `:sdg` (509),
    `Gates.t_gate()` for `:t` (510) → `:tdg` uses `Gates.t_dagger()`.
  - Export emit: `instruction_to_qasm/2` (openqasm.ex:268) has `{:sdg,…} ->
    single_qubit_gate_to_qasm("sdg",…)` at 285 → add `:tdg` clause after `:t`
    (289).
  - Import: `@stdgate_table` has `"s"/"sdg"/"t"` (lowering.ex:16-18); `tdg` is
    instead in `@decomposable_gates` (225) → `expand_gate({:decompose,"tdg"})`
    → `{:phase,[q],[-π/4]}` (273). Native switch = add table entry + remove
    decompose.

## Open decisions / watch items

- **Import behaviour change — BLOCKER CONFIRMED (2026-07-11).** An existing
  test pins the old decomposition:
  `test/qx/export/openqasm/lowering_test.exs:159` → `test "tdg → phase(-pi/4)"`
  (input `tdg q[0];` at L164). The native-import switch (P3-T3) WOULD BREAK
  this test → **requires explicit human sign-off** to modify (TDD rule 2 +
  PreToolUse hook). Two resolutions to choose from:
    - **(A) Native round-trip:** remove tdg from decomposable, update that
      existing test to assert `{:tdg,[0],[]}`. Cleanest, but needs sign-off +
      CHANGELOG **Changed**.
    - **(B) Export-only native, keep import decomposing:** `to_qasm` emits
      "tdg q;", but `from_qasm` still lowers tdg → phase(-π/4). No existing
      test touched; round-trip is semantically-equal (tdg→phase), not
      instruction-identical. Fully additive, no sign-off needed.
  Also unconfirmed: the native-vs-thin-`phase(-π/4)` `tdg` scope call itself
  (auto-decided native). Both open questions gate Phases 3–4 → HELD for user.
- **Single-qubit classifier** — must add `:tdg` to whatever set routes
  gate_name to `apply_single_qubit_op` (simulation.ex ~479-495), else GateError.
  Confirm during P1-T3.

## DISCOVERED WORK (out of scope — record for later)

- **Broken `Qx.Operations` doctests.** Wiring `doctest Qx.Operations` (this
  branch) surfaced 5 PRE-EXISTING broken doctests, excluded via `:except` in
  `test/qx/operations_test.exs`: `tap_circuit/2`, `tap_state/2`,
  `tap_probabilities/2` (rely on `IO.inspect`/`IO.puts` side-output +
  `%Qx.QuantumCircuit{...}` ellipsis that never validated) and `c_if/4`. These
  were never run before (no directive). Fix or rewrite them as valid doctests,
  then remove from the `:except` list. Added a ROADMAP line.

## Post-merge

- Landing this **completes** v0.11 "Additive surface" (part 1
  `feat/circuit-appenders` already on `main`). Tick the ROADMAP checkbox in the
  merge commit → then it's a release candidate.
- Still separate after this: `from_qasm_function/1` atom-vs-string SemVer item;
  the `api-design-principles.md §6` family-row edit.
