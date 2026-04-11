# Roadmap

This roadmap captures the strategic direction for Qx. Items are grouped by release version, not by
date — software dates go stale; versions don't.

**The two-tool model:**
- `ROADMAP.md` — *What* and *When* (strategic, version-scoped, public intent)
- `bd` (beads) — *How* and *Who* (granular issues, dependencies, in-progress work)
- `CHANGELOG.md` — *What was done* (historical record of completed work)

When a roadmap item is ready to be worked on → create bd issues from it.
When a bd epic closes → mark the item done here and record it in `CHANGELOG.md`.

---

## Current: v0.5.1

Statevector simulation with up to 20 qubits, two modes of operation (Circuit Mode and Calculation
Mode), a growing gate library, OpenQASM 3.0 export, visualization, and remote execution via QxServer.
See [CHANGELOG.md](CHANGELOG.md) for the full history.

---

## v0.5.2 — Bug Fixes & Visualisation Improvements

- [ ] Improved Bloch sphere rendering — clearer 3D representation and more visually distinct Bloch
  vector position
- [ ] Fix circuit diagram arrowhead on measure operations — arrowhead currently extends past the
  double line representing the classical register
- [x] All four Bell states — `bell_state/1` and `StateInit.bell_state/2` now accept `:phi_plus`,
  `:phi_minus`, `:psi_plus`, and `:psi_minus`; previously only `|Φ+⟩` was supported

---

## v0.6 — Expanded Gates & Better Coverage

- [ ] Additional standard gates: iSWAP, Fredkin (CSWAP), and U-gate (general single-qubit unitary)
- [ ] OpenQASM import (currently export-only)
- [ ] Test coverage to 80%+ (currently ~66%)

---

## v0.7 — Noise & Realism

- [ ] Noise models for simulating real-hardware decoherence (bit-flip, phase-flip, depolarising)
- [ ] Density matrix simulation as an alternative to statevector
- [ ] Circuit optimisation / gate cancellation pass

---

## v0.8 — Algorithms & Learning

- [ ] More quantum algorithm examples in tutorials: Quantum Phase Estimation (QPE), Variational Quantum
  Eigensolver (VQE), Shor's algorithm
- [ ] Quantum error correction tutorial (repetition code)

---

## v1.0 — Stability & Production Readiness

- [ ] API stability guarantee — no breaking changes without a major version bump
- [ ] Stable remote execution contract (QxServer protocol versioned and documented)
- [ ] Complete algorithm library covering all canonical textbook algorithms
- [ ] Performance benchmarks published and tracked across releases

---

## Backlog / Under Consideration

These have no commitment and no scheduled version. They may move up, move down, or be dropped.

- Symbolic / algebraic simulation (exact fractions, no floating point)
- Circuit-level visualization improvements (multi-qubit gate boxes, measurement symbols)
- Qiskit/Cirq circuit import adapters
- WASM / browser-side simulation for LiveBook embedding

---

## Out of Scope (for now)

These are explicitly not planned, to set honest expectations:

- **Full fault-tolerant simulation** — the memory requirements make this impractical at the qubit
  counts Qx targets
- **Hardware control / pulse-level scheduling** — QxServer handles the hardware layer; Qx stays at
  the circuit abstraction level
- **Classical co-processing / hybrid workflows beyond conditional gates** — out of scope until the
  core simulation story is complete
