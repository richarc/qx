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

## Current: v0.5.2

Statevector simulation with up to 20 qubits, two modes of operation (Circuit Mode and Calculation
Mode), a growing gate library, OpenQASM 3.0 export, visualization, and remote execution via QxServer.
See [CHANGELOG.md](CHANGELOG.md) for the full history.

---

## v0.5.2 — Bug Fixes & Visualisation Improvements ✓ Released

- [x] Improved Bloch sphere rendering — clearer 3D representation and more visually distinct Bloch
  vector position
- [x] Fix circuit diagram arrowhead on measure operations — arrowhead now terminates at the
  classical register double line
- [x] All four Bell states — `bell_state/1` and `StateInit.bell_state/2` now accept `:phi_plus`,
  `:phi_minus`, `:psi_plus`, and `:psi_minus`; previously only `|Φ+⟩` was supported

---

## v0.6 — Expanded Gates & Better Coverage

- [x] `Qx.cp/4` — controlled-phase gate applying e^(i·θ) to the |11⟩ basis state; required for
  QFT and QPE circuits; includes circuit diagram rendering (dot + P(θ) box notation) and OpenQASM
  3.0 export
- [x] Additional standard gates: iSWAP, Fredkin (CSWAP), SWAP, and U-gate (general single-qubit unitary)
- [ ] OpenQASM import (currently export-only)
- [ ] Test coverage to 80%+ (currently ~66%)
- [ ] Document and test U gate parameter convention explicitly (qx-xt2)
- [ ] Add explicit matrix-equality tests for CSWAP and iSWAP gates (qx-uos)
- [ ] Add norm-drift guard and configurable renormalization in CalcFast (qx-53v)
- [ ] Replace case dispatch with gate registry in apply_instruction (qx-agu)

---

## v0.7 — Quality, Cloud & Hardware

- [ ] Add tests verifying partial measurement does not corrupt unmeasured qubits (qx-d1f)
- [ ] Add tests for nested and chained c_if conditional operations (qx-sso)
- [ ] Add error path tests for CalcFast edge cases and invalid inputs (qx-eb1)
- [ ] Add WHY comments to bit-manipulation logic in CalcFast Nx.Defn blocks (qx-8gf)
- [ ] Clarify or merge Calc module responsibility with CalcFast (qx-rut)
- [ ] Rename is_* private helpers to *? per Elixir naming convention (qx-mbv)
- [ ] Add @spec to all defp functions in CalcFast and Simulation (qx-atv)
- [ ] Convert case gate_name dispatch to multi-clause functions in Simulation (qx-dn2)
- [ ] Improve Bloch sphere SVG visual quality (qx-w93)
- [ ] Support for running on AWS Braket QPUs
- [ ] Improvements for running on IBM Q

---

## v0.8 — Noise & Realism

- [ ] Noise models for simulating real-hardware decoherence (bit-flip, phase-flip, depolarising)
- [ ] Density matrix simulation as an alternative to statevector
- [ ] Circuit optimisation / gate cancellation pass

---

## v0.9 — Algorithms & Learning

- [ ] More quantum algorithm examples in tutorials: Quantum Phase Estimation (QPE), Variational Quantum
  Eigensolver (VQE), Shor's algorithm
- [ ] Quantum error correction tutorial (repetition code)

---

## v1.0 — Stability & Production Readiness

- [ ] API stability guarantee — no breaking changes without a major version bump
- [ ] Stable remote execution contract (QxServer protocol versioned and documented)
- [ ] Complete algorithm library covering all canonical textbook algorithms
- [x] Performance benchmarking infrastructure — Benchee suite for GHZ and QFT circuits across
  n = 2–20 qubits, with console and HTML output (`mix bench`); establishes the baseline for
  measuring GPU and distributed execution improvements
- [ ] Performance benchmarks published and tracked across releases (baseline established; results
  to be published once GPU acceleration via EXLA/EMLX is implemented)

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
