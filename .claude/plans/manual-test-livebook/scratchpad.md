# Scratchpad — manual-test-livebook (v0.11 final item)

## HANDOFF (2026-07-12): plan approved conceptually, implementation not started

User confirmed scope = **modernise + the 5 proposed expansion sections** (chose
"start in fresh session" at the plan gate — the expansion proposal itself was
not objected to; re-confirm only if trimming feels needed).

## Verified facts (don't re-derive)

- `Qx.draw_bloch/2` takes a plain **state tensor** (2 amplitudes) — circuit
  mode fully supported: `Qx.create_circuit(1) |> Qx.h(0) |> Qx.get_state()
  |> Qx.draw_bloch(...)`. (qx.ex @doc + Draw.bloch → qubit_to_bloch_coordinates
  does `Nx.to_flat_list` on the tensor.)
- Circuit mode has the real `Qx.u/5` — the old calc-mode U cell hand-composed
  `rz |> ry` only because `Qx.Qubit` lacked `u`. Use `Qx.u(qc, 0, pi/2, 0, pi)`.
- `|+⟩` prep in circuit mode: `Qx.create_circuit(1) |> Qx.h(0)` (replaces
  `Qubit.plus()`).
- `Qx.superposition/1` is `@deprecated` (this release) → the livebook must use
  `Qx.create_circuit(n) |> Qx.h_all()`.
- The livebook is at `test/qx_manual_test.livemd` (530 lines). §2/§3/§5/§6 are
  ALREADY circuit mode — only §1 (11 cells), the setup aliases, and §4's
  superposition cell are stale.
- The test-file-guard PreToolUse hook points at a nonexistent path (never
  fires), and the user explicitly requested modifying this file — authorised.
- livemd is not covered by `mix format`/`doctest`/`mix docs` extras — the ONLY
  verification is the P3-T1 headless script (extract cell bodies → `mix run`
  in the session scratchpad dir; assert Expected claims numerically; write
  Expected lines FROM verified output).
- Iron Law #8: any state comparison in the script uses tolerance ≥ 1.0e-6.

## Watch items

- Teleportation capstone: correction mapping is the classic bug — measure q0
  → Z-correction on q2? NO: standard protocol is X-correction keyed on the
  Bell-measurement of q1 (the entangled half), Z-correction keyed on q0 (the
  H-then-measured input). Derive numerically in the script FIRST, then write
  the cells.
- Seeded trajectory (§7): pass `seed:` to `Qx.steps/2`; confirm the seeded
  outcome is stable across runs in the script before writing its Expected line.
- Keep every cell Run-All-safe: no raises, no credentials, no EXLA.

## API Failure — 2026-07-15 21:49

Turn ended due to API error. Check progress.md for last completed task.
Resume with: /phx:work --continue
