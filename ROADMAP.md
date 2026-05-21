# Roadmap

This roadmap captures the strategic direction for Qx. Items are grouped by release version, not by
date — software dates go stale; versions don't.

---

## v0.5.2 — Bug Fixes & Visualisation Improvements ✓ Released

- [x] Improved Bloch sphere rendering — clearer 3D representation and more visually distinct Bloch
  vector position
- [x] Fix circuit diagram arrowhead on measure operations — arrowhead now terminates at the
  classical register double line
- [x] All four Bell states — `bell_state/1` and `StateInit.bell_state/2` now accept `:phi_plus`,
  `:phi_minus`, `:psi_plus`, and `:psi_minus`; previously only `|Φ+⟩` was supported

---

## v0.6.0 — Expanded Gates & Round-trip OpenQASM ✓ Released

- [x] `Qx.cp/4` — controlled-phase gate applying e^(i·θ) to the |11⟩ basis state; required for
  QFT and QPE circuits; includes circuit diagram rendering (dot + P(θ) box notation) and OpenQASM
  3.0 export
- [x] Additional standard gates: iSWAP, Fredkin (CSWAP), SWAP, and U-gate (general single-qubit unitary)
- [x] **OpenQASM 3.0 import** — `Qx.Export.OpenQASM.from_qasm/1` parses programs emitted by Qx,
  Qiskit, or IBM Quantum into a `Qx.QuantumCircuit` (round-trip with `to_qasm/1` to within 1e-10
  on Bell, GHZ, QFT, Grover, and Deutsch-Jozsa fixtures); `Qx.Export.OpenQASM.from_qasm_function/1`
  converts a `gate name(p) a, b { … }` definition into compilable Elixir source. Typed
  `Qx.QasmParseError` and `Qx.QasmUnsupportedError` for grammar failures and out-of-scope features.
  Backed by a hand-written nimble_parsec grammar; new runtime dependency `nimble_parsec ~> 1.4`.
  (plan: openqasm-import)

---

## v0.7 — Direct IBM Hardware Execution

Direct-to-IBM quantum hardware execution (was originally scheduled for v0.8).

- [x] `Qx.Hardware` — direct-to-IBM execution (qxportal transpile → IBM submit → poll → result-build). Replaces the deleted `Qx.Remote` (qx_server) module. (plan: qx-hardware)
- [x] Improvements for running on IBM Q — delivered in v0.7 as `Qx.Hardware`

---

## v0.8 — Quality, Test Coverage & Additional Hardware Backends

Test-coverage and refactor items that didn't make the v0.6/v0.7 cut, plus
broadening hardware support beyond IBM.

- [ ] Test coverage to 80%+ (currently ~66%)
- [x] Document and test U gate parameter convention explicitly (qx-xt2)
- [x] Add explicit matrix-equality tests for CSWAP and iSWAP gates (qx-uos)
- [x] Add norm-drift guard and configurable renormalization in CalcFast (qx-53v)
- [x] Typed errors at public API boundaries (Iron Law #7) — resolves arch-review C1/C2/C3 + `set_state/2`; bumps 0.8.0 (plan: iron-law-7-critical)
- [ ] Replace case dispatch with gate registry in apply_instruction (qx-agu)
- [ ] Add tests verifying partial measurement does not corrupt unmeasured qubits (qx-d1f)
- [ ] Add tests for nested and chained c_if conditional operations (qx-sso)
- [ ] Add error path tests for CalcFast edge cases and invalid inputs (qx-eb1)
- [ ] Add WHY comments to bit-manipulation logic in CalcFast Nx.Defn blocks (qx-8gf)
- [ ] Clarify or merge Calc module responsibility with CalcFast (qx-rut)
- [ ] Rename is_* private helpers to *? per Elixir naming convention (qx-mbv)
- [ ] Add @spec to all defp functions in CalcFast and Simulation (qx-atv)
- [ ] Convert case gate_name dispatch to multi-clause functions in Simulation (qx-dn2)
- [ ] Improve Bloch sphere SVG visual quality (qx-w93)
- [ ] Support for running on AWS Braket QPUs (moved from v0.7)
- [ ] ~~Stable remote execution contract — QxServer protocol versioned~~ — superseded by direct IBM execution in v0.7 (qx_server path retired)

---

## v0.9 — Noise & Realism

- [ ] Noise models for simulating real-hardware decoherence (bit-flip, phase-flip, depolarising)
- [ ] Density matrix simulation as an alternative to statevector
- [ ] Circuit optimisation / gate cancellation pass

---

## v0.10 — Algorithms & Learning

- [ ] More quantum algorithm examples in tutorials: Quantum Phase Estimation (QPE), Variational Quantum
  Eigensolver (VQE), Shor's algorithm
- [ ] Quantum error correction tutorial (repetition code)

---

## v1.0 — Stability & Production Readiness

- [ ] API stability guarantee — no breaking changes without a major version bump
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
- Cirq circuit import adapter (Qiskit/IBM Quantum import already covered by OpenQASM 3.0)
- Multi-register `Qx.QuantumCircuit` (current model is a single quantum + single classical
  register; OpenQASM import currently rejects multi-register programs)
- `else` branches on `c_if` conditionals (currently raises on import; rewrite as two ifs)
- WASM / browser-side simulation for LiveBook embedding

---

## Out of Scope (for now)

These are explicitly not planned, to set honest expectations:

- **Full fault-tolerant simulation** — the memory requirements make this impractical at the qubit
  counts Qx targets
- **Hardware control / pulse-level scheduling** — IBM Quantum handles the hardware layer; Qx stays at
  the circuit abstraction level
- **Classical co-processing / hybrid workflows beyond conditional gates** — out of scope until the
  core simulation story is complete
