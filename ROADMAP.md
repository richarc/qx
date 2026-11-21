# Roadmap

What's planned for Qx, by release version. Released versions and the
changes they shipped live in [`CHANGELOG.md`](CHANGELOG.md) — shipped
milestone sections are removed from this file once they're on Hex.

Last updated: 2026-11-21. v0.12 (Simulation Refactor & Performance)
and v0.13 (Visualization) have shipped: 0.12.0 on 2026-11-15, 0.13.0 and
0.13.1 on 2026-11-21. Their scope is in `CHANGELOG.md`, per the
shipped-milestone convention above. Next up: algorithms (v0.14), noise
(v0.15) and more hardware (v0.16). The API consistency review's
yardstick is `spec/api-design-principles.md`; its findings and triage
buckets are in `.claude/plans/api-consistency-review/findings.md`.

---

## v0.14: Algorithms & Building Blocks

Governed by `spec/api-design-principles.md` §8: building blocks are
appenders with the gate shape `(circuit, args...) -> circuit`,
composing existing operations only, one facade module per domain. The
v0.11 appender work (`bell_pair`/`ghz`) sets the template. Learner
tutorial content lives in qxportal; what belongs here is the library
surface those tutorials call.

- [ ] `Qx.Oracle`: standard oracle constructors (bit-string/BV oracles, phase oracles, truth-table compilation) so algorithm examples stop hand-rolling CNOT loops. Needs its own design doc before code
- [ ] Algorithm components as appenders: Grover diffusion, QFT, phase estimation
- [ ] Grow toward a complete algorithm library covering the canonical textbook algorithms (QPE, VQE, Shor's ingredients), with matching tutorial content added on the portal
- [ ] Quantum error correction building blocks + a portal tutorial (repetition code)

---

## v0.15: Noise & Realism

- [ ] Noise models for simulating real-hardware decoherence (bit-flip, phase-flip, depolarising)
- [ ] Density matrix simulation as an alternative to statevector
- [ ] Circuit optimisation / gate cancellation pass
- [ ] Mid-circuit reset operation `Qx.reset/2`: QAAL `MzReset q` parity; first-class in OpenQASM 3 / IBM hardware. Needs new `:reset` instruction handler in `Qx.Simulation` (projection-and-relabel) — mind Iron Law #9's producer/dispatch pairing when adding the instruction kind. The name becomes clean once v0.11 deprecates `QuantumCircuit.reset/1` (plan: tbd, see qaal-analysis A3)

---

## v0.16: Hardware

Broaden hardware support beyond IBM.

- [ ] Support for running on AWS Braket QPUs (moved from v0.7, then from v0.13 on 2026-11-21)

---

## Backlog / Under Consideration

These have no commitment and no scheduled version. They may move up, move down, or be dropped.

- [ ] Moved from v0.12 on 2026-11-14 (evaluation: no user-visible need). Replace case dispatch with gate registry in apply_instruction (qx-agu) and convert case gate_name dispatch to multi-clause functions in Simulation (qx-dn2). The dispatch in `lib/qx/simulation.ex` is about 130 lines of nested `case` with one credo suppression and no measured performance cost. The real gain would be one shared gate table for the four modules that each list gate names (simulation, OpenQASM lowering, OpenQASM export, the SVG circuit drawer); whether those lists have drifted is not checked
- [ ] Moved from v0.12 on 2026-11-14. Clarify or merge Calc module responsibility with CalcFast (qx-rut): `Qx.Calc` is 189 lines of one-line delegations to `Qx.CalcFast` with stale docs. Removing it repoints 23 call sites in `simulation.ex` and 15 in `register.ex` and edits existing test files. Do it with the 1.0 calc-engine removal, or earlier as a small change
- [ ] Moved from v0.12 on 2026-11-14 (compile-time only; dissolves with the 1.0 calc-engine removal). Break the 4-module cycle `tables → register → qubit → draw → tables`: anchored by the internal calc engine's `Qx.Qubit.draw_bloch/2` defdelegating up to `Qx.Draw` and `Qx.Draw.Tables.render/2` pattern-matching `%Qx.Register{}`. Both anchors survived the v0.10 demotion (the modules are hidden, not gone); the cycle dissolves for free if the 1.0 calc-engine removal lands first — sequence accordingly (audit: arch MED)
- [ ] Moved from v0.12 on 2026-11-14 (blocked: EXLA/EMLX are not dependencies). Performance benchmarks published and tracked across releases (Benchee baseline `mix bench` exists; results to be published once GPU acceleration via EXLA/EMLX is exercised)
- [ ] `Qx.QuantumCircuit.add_measurement/3` appends with `circuit.measurements ++ [measurement]` (`lib/qx/quantum_circuit.ex:229`), a quadratic append like the instruction one fixed in v0.12. Surfaced by the v012-closeout review (2026-11-14)
- [ ] Second instruction-producer surface: `lib/qx/export/openqasm/lowering.ex`
  builds `{:measure,…}`/`{:barrier,…}`/`{:c_if,…}`/gate tuples directly on its
  raw lowering-state map (QASM import bulk-builds an instructions list, then
  wraps it in a `QuantumCircuit`), bypassing the `QuantumCircuit.add_*` producer
  surface centralized in `feat/producer-hygiene`. Iron Law #9-adjacent. At
  minimum add a moduledoc caveat; ideally a shared shape-constructor both paths
  use. Surfaced by the producer-hygiene merge-gate review (2026-07-12).
- [ ] Fix the 5 pre-existing broken `Qx.Operations` doctests currently excluded
  via `:except` in `test/qx/operations_test.exs` (`tap_circuit/2`, `tap_state/2`,
  `tap_probabilities/2`, `c_if/4` — they rely on `IO.inspect`/`IO.puts`
  side-output + `%Qx.QuantumCircuit{...}` ellipsis that never validated). Rewrite
  as valid doctests, then remove from the `:except` list. Surfaced by wiring
  `doctest Qx.Operations` in `feat/qasm-facade-tdg`.
- [x] Fix (or dialyzer-ignore with justification) the 70 `mix dialyzer`
  warnings surfaced when `dialyxir` was wired into `mix.exs` on 2026-07-19.
  Fixed 2026-07-19: widened `Qx.StateInit.basis_state/3`,
  `bell_state_vector/2`, `ghz_state_vector/2` from `Nx.Type.t()` to
  `Nx.Type.t() | Nx.Type.short_t()` (Qx's own default args pass the atom
  shorthand `:c64`, which `Nx.Type.t()` alone excludes) — this alone cleared
  56 of the 70 via cascade (`Register.new/1`, `Qubit.new/0,1`,
  `Qx.create_circuit/1,2`, `Qx.Patterns.*`, etc. all bottomed out in these 3
  specs). Added missing `@type t` to `Qx.Hardware.ConfigError` /
  `Qx.Hardware.NoMeasurementsError`. Widened `Qx.Validation.valid_register?/2`'s
  param spec from an anonymous `%{state: ..., num_qubits: ...}` map shape to
  `map()` — the closed anonymous shape structurally excluded any struct
  (extra `:__struct__` key), so `Qx.Register.valid?/1` calling it with
  `%Qx.Register{}` looked like dead code to Dialyzer. Removed a genuinely
  dead `:delete` clause from `Qx.Hardware.Ibm.authed_request/5` (no caller
  ever passes it). Remaining 6 are real false positives, filtered via
  `.dialyzer_ignore.exs` with justification: 5 `unused_fun` clauses in the
  generated OpenQASM parser (`lib/qx/export/openqasm/parser.ex`, an artifact
  of nimble_parsec's dispatch table), and 1 `pattern_match_cov` on
  `Qx.Hardware.Ibm.maybe_put_retry_delay/1` (analyzes the `:dev` env, where
  `@ibm_retry_delay` is statically `nil`; it's a real integer only in
  `:test`).

- Stream the IBM `/results` body via Req `into:` with a size cap that aborts
  over ~50 MB (real OOM/DoS protection). Deferred from `ibm-client-hardening`:
  without the cap, plain streaming saves little (the Sampler result is still
  JSON-parsed to an in-memory map) and the source (IBM Quantum) is trusted.
  Revisit if result sizes or the threat model change.
- Interactive step-through widget: scrub through a circuit drawing while
  phase circles (Quirk-style amplitude disks) update per step. Piece 1 of 3
  shipped in v0.10 (`Qx.steps/2` with `seed:` gives a scrubbable consistent
  trajectory). Remaining: (2) a phase-circle renderer in `Qx.Draw` returning
  a `Qx.Draw.Image` per the v0.10 artifact pattern (settle the global-phase
  convention), plus gate-position metadata from the circuit renderer so the
  highlight can sync with `step.index`; (3) the interactive Kino widget in
  `kino_qx`, consuming the published Qx release (workspace §4). The renderer
  would fit a visualization-themed release if pulled forward.
- Symbolic / algebraic simulation (exact fractions, no floating point)
- Circuit-level visualization improvements (multi-qubit gate boxes, measurement symbols)
- Cirq circuit import adapter (Qiskit/IBM Quantum import already covered by OpenQASM 3.0)
- Multi-register `Qx.QuantumCircuit` (current model is a single quantum + single classical
  register; OpenQASM import currently rejects multi-register programs)
- Named circuit-mode register views: bind a name to a qubit-index list so
  `Qx.h_all(qc, alice)` reads like QAAL `H alice`. Stashed from `qaal-analysis`
  (A4). The naming collision with calc-mode `Qx.Register` softened when the
  calc engine went internal in v0.10, but the API-surface cost still stands
  and B1 (list/range overloads, v0.8) covers ~80% of the value. Revisit when
  multi-register tutorials (Shor / QPE) start feeling unmanageable.
- `else` branches on `c_if` conditionals (currently raises on import; rewrite as two ifs)
- WASM / browser-side simulation for LiveBook embedding
- A 1.0 release and an API-stability guarantee (no breaking changes without a
  major bump). Since the 2026-07-04 API consistency review this has a concrete
  gate list (the "breaking-1.0" bucket in
  `.claude/plans/api-consistency-review/findings.md`): calc-engine removal,
  `QuantumCircuit` state-field extraction (initial state becomes a `run`
  option), the `measure`/`measure_z` final pick, StateInit survivor
  naming/opts, `most_frequent` → `nil` on empty, conditional-run ensemble
  semantics, plus executing the v0.11 deprecation removals. Still
  deliberately unscheduled; the list is the entry criteria, not a date.

---

## Out of Scope (for now)

These are explicitly not planned, to set honest expectations:

- **Full fault-tolerant simulation**: the memory requirements make this impractical at the qubit
  counts Qx targets
- **Hardware control / pulse-level scheduling**: IBM Quantum handles the hardware layer; Qx stays at
  the circuit abstraction level
- **Classical co-processing / hybrid workflows beyond conditional gates**: out of scope until the
  core simulation story is complete
