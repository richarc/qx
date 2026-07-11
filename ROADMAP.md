# Roadmap

What's planned for Qx, by release version. Released versions and the
changes they shipped live in [`CHANGELOG.md`](CHANGELOG.md) — shipped
milestone sections are removed from this file once they're on Hex.

Last updated: 2026-07-08. Restructured: the old three-theme v0.11 is
now one release per theme — API follow-through (v0.11), simulation
refactor & performance (v0.12), visualization & hardware (v0.13) —
with noise and algorithms shifting down to v0.14/v0.15. The API
consistency review's yardstick is `spec/api-design-principles.md`; its
findings and triage buckets are in
`.claude/plans/api-consistency-review/findings.md`.

---

## v0.11: API Review Follow-Through

The API consistency review's non-breaking follow-through: the
typed-error and docs sweeps, the additive surface the review called
for, and the deprecations whose window opens this minor. A minor
release: additive and internal, no breaking changes (those wait for
the 1.0 gate list in the Backlog).

- [x] Typed-error sweep #3: raw `FunctionClauseError`/`ArgumentError` still escaping tier 1/2 — `create_circuit` (docs advertise the raw error), `bell_state(:bogus)`, `ghz_state(1)`, `h(qc, "0")`, `c_if` type slips, seven `StateInit` constructors (scoped to `basis_state/2,3` — the other constructors were deprecated by the v0.11 tier trim), `filter_by_probability(result, 1)`, `Math.normalize` zero-vector NaN; plus `rx/ry/rz/phase` gaining the `validate_parameter!` their `u/cp/cr*` siblings already run (findings B-09, B-14, T1-10, R-04, R-09, R-10)
- [x] Docs sweep: the 83 missing `@spec`s, `## Returns`/`## Raises` on tier 1 functions, §3 tier-annotation openers on tier-2 moduledocs, the tap_* simulation warning copied up to the facade docs, angle types unified to `number()` (findings B-08, B-15, R-12, R-15, T1-11/15/16) — landed as 47 supported `@spec`s (the other 36 were `@deprecated`/`@doc false`, exempt), 55 `## Returns` + 18 grounded `## Raises`, tier openers, tap warning copy-up, and the OpenQASM doc-rot fix
- [x] Additive surface: `bell_pair(circuit, q0, q1, which)` and `ghz(circuit, qubits)` appenders with the creators reframed as wrappers (principles §8; must land before the v0.15 building-block work multiplies the creator shape), `tdg/2` (QASM round-trip parity), `to_qasm`/`from_qasm`/`from_qasm!` facade delegates on `Qx` (findings T1-05/07/12, B-10)
- [ ] Producer hygiene: `Patterns.measure_all` composes `Operations.measure/3` instead of a hidden internal; single producer path for barrier/c_if instruction tuples; `add_gate` validates gate names or moves internal (findings B-04/11/12; Iron Law #9 pressure)
- [ ] `from_qasm_function/1` returns `module:` as an atom instead of a string (callers currently must capture the module from `Code.eval_string`'s return; the name is qx-generated so `Module.concat/1` is safe). Found by the post-release README audit (findings addendum 2026-07-04). **SemVer note:** as written this is a breaking return-type change on a declared-public module, at odds with this release's non-breaking framing — the plan must pick one of: make it additive (keep the string, add the atom under a new key), ship it as v0.11's one explicitly flagged break in the CHANGELOG, or move it to the 1.0 breaking bucket
- [ ] Deprecation batch (window opens this minor, removals at 1.0): `barrier_all/2` (vs `barrier/2` range support), `run/2`'s integer-shots overload, `superposition/1` (fails the README test), `QuantumCircuit.get_state/1` → `initial_state/1` + `reset/1` + `depth/1` (misleading names, near-zero callers), `draw_state`'s tier-3 Register escape hatch in the tier-1 spec (findings T1-04/06/08/14, R-02, B-01/05/06/07)
- [x] Decide and execute the StateInit/Math tier trim: tier 1/2 code touches only `basis_state`, `normalize`, `probabilities`; the other 16 public functions are orphans, and `Behaviours.QuantumState` has zero public implementors. Demote/deprecate per findings R-07/R-08/R-13; delete the two dead `@doc false` Math converters outright (plan: stateinit-math-tier-trim)
- [ ] Principles-doc post-review edits: documented exceptions (`version/0`, `measure_z` alias, `get_state`-raises-on-measured), new §6 family rows for run/steps/c_if/barrier/`*_chain` (findings T1-09/17/18, B-13); replace Iron Law #6's flat surface list with the §3 tier annotations (tension #7)
- [ ] Modernise or retire `test/qx_manual_test.livemd`: partially updated by the Draw rework but still built on calc-mode aliases; either rewrite onto the circuit surface or fold what it covers into the qxportal tutorials and delete

---

## v0.12: Simulation Refactor & Performance

The 2026-06-14 audit's simulation-engine refactor and performance
work: clarify the Calc / CalcFast split, kill the host-side loops.
Additive and internal, no breaking changes.

- [ ] Replace case dispatch with gate registry in apply_instruction (qx-agu)
- [ ] Convert case gate_name dispatch to multi-clause functions in Simulation (qx-dn2)
- [ ] Clarify or merge Calc module responsibility with CalcFast (qx-rut)
- [ ] Reshape `Qx.CalcFast` kernels to eliminate `Nx.take` gather + `Nx.select` mask: single-qubit (`lib/qx/calc_fast.ex:67–91`), CNOT (`114–143`), CSWAP (`157–185`), Toffoli (`187–229`). Replace with reshape + 2×2 tensor contraction along the qubit axis. Highest-leverage perf change in the audit; depends on the v0.8.1 tolerance widening (audit: perf CRIT C1/C2; Iron Law #3)
- [ ] Vectorise measurement probability and state collapse: `lib/qx/simulation.ex` host loop `for i <- 0..(2^n - 1), Nx.to_number(state[i])` runs once per shot (~1 M host syncs at 1024 shots × n=10) (audit: perf CRIT C3; Iron Law #5)
- [ ] Replace `2^n × 2^n` matrix materialisation in SWAP / iSWAP / CP / CY / CRx / CRy / CRz: `lib/qx/simulation.ex` + the host-loop matrix builders in `lib/qx/gates.ex`. Currently OOM above n≈10 (4.3 GB at n=14) (audit: perf HIGH)
- [ ] Replace host-side `2^n` Elixir-list construction in `Qx.StateInit` and in `Qx.ResultBuilder.build_probability_tensor` (`List.replace_at` over 2^n list). Scope to whatever survives the v0.11 StateInit/Math tier decision — don't optimise functions being deprecated (audit: perf HIGH; Iron Law #5)
- [ ] Vectorise sample generation: `Enum.scan` cumulative distribution + per-shot `Enum.find_index` linear scan is O(shots × 2^n); 100M+ host iterations at 100k shots × n=10 (audit: perf HIGH)
- [ ] Cap retained state in `run_with_conditionals`: materialises the full list of `{state, cbits}` for every shot before `Enum.frequencies`; at 100k shots × n=20 holds ~1.6 TB resident before reduce (audit: perf HIGH)
- [ ] Replace `instructions ++ [new]` quadratic append in `Qx.QuantumCircuit` with prepend + reverse-on-finalise (audit: perf HIGH; also flagged by `usage_rules.elixir`)
- [ ] Cap or auto-truncate state-sized rendering above n≈12 qubits, raising a typed `Qx.*Error` instead: the three VegaLite chart builders (`lib/qx/draw/vega_lite.ex`), the histogram data build in `lib/qx/draw.ex`, and the 2^n-row table build in `Qx.Draw.Tables`. Rescoped 2026-07-05: the unbounded SVG chart renderer named by the audit was deleted in the v0.10 Draw rework, which shrank this item (audit: perf CRIT C4)
- [ ] Replace `:math.pow(2, n) |> trunc/1` with `Integer.pow(2, n)` (or `Bitwise.bsl(1, n)`) across `state_init.ex`, `quantum_circuit.ex`, `simulation.ex`, `gates.ex`, `validation.ex`. Exact integer math (audit: perf LOW)
- [ ] Break the 4-module cycle `tables → register → qubit → draw → tables`: anchored by the internal calc engine's `Qx.Qubit.draw_bloch/2` defdelegating up to `Qx.Draw` and `Qx.Draw.Tables.render/2` pattern-matching `%Qx.Register{}`. Both anchors survived the v0.10 demotion (the modules are hidden, not gone); the cycle dissolves for free if the 1.0 calc-engine removal lands first — sequence accordingly (audit: arch MED)
- [ ] Performance benchmarks published and tracked across releases (Benchee baseline `mix bench` exists; results to be published once GPU acceleration via EXLA/EMLX is exercised)

---

## v0.13: Visualization & Hardware

Polish the Bloch renderer, broaden hardware support beyond IBM.

- [ ] Improve Bloch sphere SVG visual quality (qx-w93). Raised stakes since v0.10: the SVG renderer is now the *only* Bloch path (the VegaLite projection was deleted in the Draw rework) and ships as the `Qx.Draw.Image` artifact rendered inline in Livebook
- [ ] Support for running on AWS Braket QPUs (moved from v0.7)

---

## v0.14: Noise & Realism

- [ ] Noise models for simulating real-hardware decoherence (bit-flip, phase-flip, depolarising)
- [ ] Density matrix simulation as an alternative to statevector
- [ ] Circuit optimisation / gate cancellation pass
- [ ] Mid-circuit reset operation `Qx.reset/2`: QAAL `MzReset q` parity; first-class in OpenQASM 3 / IBM hardware. Needs new `:reset` instruction handler in `Qx.Simulation` (projection-and-relabel) — mind Iron Law #9's producer/dispatch pairing when adding the instruction kind. The name becomes clean once v0.11 deprecates `QuantumCircuit.reset/1` (plan: tbd, see qaal-analysis A3)

---

## v0.15: Algorithms & Building Blocks

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

## Backlog / Under Consideration

These have no commitment and no scheduled version. They may move up, move down, or be dropped.

- [ ] Fix the 5 pre-existing broken `Qx.Operations` doctests currently excluded
  via `:except` in `test/qx/operations_test.exs` (`tap_circuit/2`, `tap_state/2`,
  `tap_probabilities/2`, `c_if/4` — they rely on `IO.inspect`/`IO.puts`
  side-output + `%Qx.QuantumCircuit{...}` ellipsis that never validated). Rewrite
  as valid doctests, then remove from the `:except` list. Surfaced by wiring
  `doctest Qx.Operations` in `feat/qasm-facade-tdg`.

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
  fits the v0.13 visualization theme if pulled forward.
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
