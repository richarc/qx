# Modernise qx_manual_test.livemd + expand into a real manual test suite (v0.11, final item)

**Branch:** `docs/manual-test-livebook`
**ROADMAP:** v0.11 "API Review Follow-Through" — the last unchecked item.
**Ticking it completes v0.11 → release-manager cue fires after merge.**
**Depth:** standard · **Complexity:** 4 (one large livemd rewrite + a headless
verification script; no library code changes; touches a `test/` path — user
explicitly authorised modifying this manual-test file by requesting the item).
**User scope call:** modernise (not retire) + propose expanded functionality.

## Decision

Rewrite `test/qx_manual_test.livemd` onto the tier-1 circuit surface and grow
it from a gate gallery into a manual test suite that exercises every *visual/
interactive* surface of the current API. Keep its identity: human-facing,
every cell carries an `# Expected:` line, Run-All must complete cleanly.

### What's stale today (verified)

- Setup cell: `alias Qx.{Qubit, Register}` — calc-mode aliases (Register never
  even used). §1's 11 cells all use `Qubit.new()/plus()/h()/…` (tier 3,
  demoted v0.10).
- §4 preset cells use `Qx.superposition()` — deprecated THIS release.
- §1's U-gate cell hand-composes `rz|>ry` because calc mode lacked `u` —
  circuit mode has the real `Qx.u/5`.
- Coverage gaps vs today's API: no stepper (v0.10 headline), no sdg/tdg, no
  appenders, no QASM, no measurement bases, no barrier-in-diagram.

### Modernisation map (§ by §)

| Section | Change |
|---|---|
| Setup | Drop `Qubit`/`Register` aliases; keep `{:qx, path: "."}` + kino/vega_lite |
| §1 Single-qubit | Every cell → `Qx.create_circuit(1) \|> Qx.<gate>(0[, θ]) \|> Qx.get_state() \|> Qx.draw_bloch(...)` (from `\|+⟩`: prepend `Qx.h(0)`). U cell → the real `Qx.u(0, π/2, 0, π)`. **Add S† and T† cells** (dagger family: S then S† returns to \|+⟩; T\|+⟩ then T†→ back — visually tests the new tdg sim + the fixed sdg/tdg draw labels comes in §5) |
| §2/§3 Two/three-qubit | Already circuit mode — keep, light copy-edit only |
| §4 Entanglement/presets | Keep Bell/GHZ cells; `Qx.superposition()` cell → the replacement idiom `Qx.create_circuit(1) \|> Qx.h_all()` with a note that `superposition/1` is deprecated |
| §5 Circuit diagrams | Keep; **add a dagger-gates diagram** (sdg+tdg boxes render "S†"/"T†" — the v0.11 draw fix) and **a barrier cell** using the new range form `Qx.barrier(0..2)` |
| §6 Measurement/c_if | Keep |
| Intro | Update the section list; drop "(Calc mode)" |

### Proposed NEW sections (the expansion — approve/trim at this gate)

7. **Step-Through Inspection** (v0.10 stepper): walk a Bell circuit with
   `Qx.steps/2 |> Enum.each(&IO.inspect/1)` (readable per-step state lines);
   `Qx.Step.show/1` full display map of the final step; a **seeded** mid-circuit
   -measurement trajectory (`seed:`) so the `# Expected:` line is deterministic.
8. **Composite Patterns & Appenders** (v0.11): `bell_pair/4` and `ghz/2`
   appended at OFFSET qubits inside a larger circuit (histogram proves
   placement); `cx_chain/2`; `h_all/2` on a sub-range — the patterns surface
   the automated suite covers numerically, eyeballed visually here.
9. **OpenQASM Round-Trip**: `to_qasm` output rendered as text for visual
   inspection (header, stdgates include, gate lines); `from_qasm!` of that
   string drawn as a circuit diagram (proves the round-trip incl. native
   `tdg`); `from_qasm_function/1` generated Elixir source displayed.
10. **Measurement Bases**: `measure_x` / `measure_y` / `measure_z` cells with
    inputs chosen so expected count distributions differ per basis (e.g.
    measure_x on |+⟩ → all "0"; measure_z on |+⟩ → 50/50).
11. **Capstone: Quantum Teleportation** — everything composing end-to-end:
    prepare an arbitrary state with `u/5`, teleport via Bell pair + two
    mid-circuit measurements + two `c_if` corrections, then `steps` to grab the
    final state and `draw_bloch` q2 — the dot must land where the input's dot
    was. The single best "is the whole stack healthy" manual check.

Deliberately NOT added: typed-error demo cells (raises break Run-All), EXLA
backend cells (not in the Mix.install), hardware cells (need credentials).

## Phase 1 — Modernise existing sections

- [x] [P1-T1] Setup cell + intro rewrite (drop calc aliases, new section list).
- [x] [P1-T2] §1 → circuit mode (11 cells), real `u/5` cell, + S†/T† cells with
      return-trip expectations. §4 superposition cell → `h_all` idiom + note.
      §5 add dagger-diagram + range-barrier cells. Copy-edit §2/§3/§6.

## Phase 2 — New sections 7–11

- [x] [P2-T1] §7 Step-Through (incl. seeded trajectory) and §8 Patterns &
      Appenders.
- [x] [P2-T2] §9 OpenQASM round-trip, §10 Measurement bases, §11 Teleportation
      capstone.

## Phase 3 — Headless verification + gate

- [x] [P3-T1] **Verification script**: extract every elixir cell body (minus
      Mix.install) into `scratch` order-preserving `.exs`, run under `mix run`
      — every cell must complete without raising; programmatically assert a
      sample of `# Expected:` claims (Bell probs 0.5/0.5, teleported state ≈
      input state within 1.0e-6 per Iron Law #8, measure_x on |+⟩ all-zero
      counts, QASM round-trip instruction equality). Script is throwaway —
      lives in the scratchpad dir, not committed.
- [x] [P3-T2] Full gate (`compile --warnings-as-errors`, format, credo, test —
      all untouched by a livemd edit; confirms nothing else drifted) + `mix
      docs` == 36. CHANGELOG **Documentation** entry. Tick the ROADMAP item —
      **this completes v0.11**; note the release cue in the summary.

## Iron Laws check

- **#6:** no library surface touched — livemd + CHANGELOG/ROADMAP only.
- **#8:** teleportation/state assertions in the verification script use
  tolerance ≥ 1.0e-6 (c64).
- **TDD rule 2 (test files):** `test/qx_manual_test.livemd` is the explicit
  subject of this user-requested item — modification authorised. No `*_test.exs`
  touched.

## Risks

1. **Cells that render but lie** — an `# Expected:` claim wrong for the new
   circuit-mode spelling (e.g. Bloch position after re-derivation). Mitigation:
   the P3-T1 script asserts the checkable claims; Bloch positions re-derived
   from the state values it prints.
2. **Seeded trajectory nondeterminism** — `seed:` must actually pin the
   mid-circuit outcome; verify in the script, and write the Expected line from
   the script's observed (seeded) output.
3. **Teleportation correctness** — classic index/correction-order bug territory
   (X vs Z correction mapping). The script compares final q2 state to the
   prepared input state numerically before the Expected line is written.
