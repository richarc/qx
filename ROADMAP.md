# Roadmap

What's planned for Qx, by release version. Released versions and the
changes they shipped are in [`CHANGELOG.md`](CHANGELOG.md).

---

## v0.8.1: Test Coverage & Quality

Raise test coverage to the v0.8 target and harden the simulator's
quality: error-path tests, missing `@spec`s, and inline documentation
for the bit-manipulation hot paths.

- [ ] Test coverage to 80%+ (currently ~66%)
- [x] Add tests verifying partial measurement does not corrupt unmeasured qubits (qx-d1f)
- [ ] Add tests for nested and chained c_if conditional operations (qx-sso)
- [ ] Add error path tests for CalcFast edge cases and invalid inputs (qx-eb1)
- [ ] Add @spec to all defp functions in CalcFast and Simulation (qx-atv)
- [ ] Add WHY comments to bit-manipulation logic in CalcFast Nx.Defn blocks (qx-8gf)
- [ ] Rename is_* private helpers to *? per Elixir naming convention (qx-mbv)
- [ ] Iron Law #7 follow-on: route `Qx.Validation.validate_parameter!/1` through a typed `Qx.*Error` instead of raw `ArgumentError`. Affects every rotation gate (`rx`/`ry`/`rz`/`cp`/`crx`/`cry`/`crz`). Currently a visible inconsistency in the new QAAL-parity gates' `## Raises` sections.
- [x] Widen `:c64` sub-ε test tolerances and add non-integer fixtures: `test/qx/cswap_iswap_matrix_test.exs:33` (`1.0e-12` → `1.0e-6`), `test/qx/export/openqasm/round_trip_test.exs:8` (`1.0e-10` → `1.0e-6`), and the boundary case at `test/qx/u_gate_convention_test.exs:24`. Currently pass only because fixtures use exactly-representable amplitudes; prerequisite for the v0.8.2 `CalcFast` rewrite (audit: test CRIT C5/C6; Iron Law #8)
- [ ] Migrate three deprecated `Qx.Math.basis_state/2` test calls → `Qx.StateInit.basis_state/3` at `test/qx/math_test.exs:303,311,319`. Unblocks `--warnings-as-errors` in the test gate (audit: test MED)
- [ ] Flip 16 pure-compute test files to `async: true` for ~10–15 % suite-runtime improvement (audit: test MED, listed in summary)
- [ ] Update stale `coveralls.json:16` `_comment` ("66.4 %" → actual 81.4 %) (audit: test LOW)
- [ ] Expand the Iron Law #7 follow-on above to also route `Qx.Validation.validate_qubits_different!/2` and `validate_state_shape!/2` through `Qx.*Error`. Both still raise raw `ArgumentError` with in-source TODO markers at `lib/qx/validation.ex:127,152` (audit: arch HIGH)
- [ ] `ArgumentError` → typed `Qx.*Error` sweep across the rest of the public surface: `lib/qx/register.ex` (11 sites), `lib/qx/draw/svg/circuit.ex` (5 sites reached via public `Qx.Draw.circuit/2`), `lib/qx/qubit.ex:290` (`from_basis/1`), `lib/qx/draw.ex` (4 `:format`-option sites), `lib/qx/export/openqasm.ex:177`, `lib/qx/export/openqasm/parser.ex:568` (`String.to_float/1` on hostile input) (audit: arch HIGH cluster + security MED)
- [ ] Decide `Qx.StateInit` public/internal status: used by `examples/tutorials/systems_of_qubits_and_entanglement.livemd:534` but omitted from `Qx`'s public-module list. Pick one and document, currently at risk of a silent breaking change (audit: arch LOW)
- [ ] Expand the Iron-Laws declared public surface in `AGENTS.md` / `CLAUDE.md` to match reality: add `Qx.Qubit`, `Qx.Register`, `Qx.StateInit`, `Qx.Patterns`, `Qx.Math`, `Qx.Hardware`, `Qx.Hardware.Config`, `Qx.Export.OpenQASM`, and `Qx.Draw`. README and every tutorial alias-import these as primary surface; a breaking change today would not trip Iron Law #6 (audit: public-api S2 HIGH)
- [ ] Mark internals `@moduledoc false` so they stop reading as public: `Qx.Draw.SVG.Bloch`, `Qx.Draw.SVG.Charts`, `Qx.Draw.SVG.Circuit`, `Qx.Draw.Tables`, `Qx.Draw.VegaLite`, `Qx.Export.OpenQASM.{AST,Codegen,Expr,Lowering,Parser}`, `Qx.Hardware.Ibm`, `Qx.Hardware.Portal` (audit: public-api LOW × 3)
- [ ] Add `defdelegate barrier(circuit, qubits), to: Operations` in `lib/qx.ex`. `Qx.barrier_all/1,/2` are delegated but the single-instruction primitive `Qx.barrier/2` is missing; accidental gap from when `Qx.Patterns` landed (audit: public-api S4 MED)
- [ ] Fix `Qx.run/2` docstring at `lib/qx.ex:854-861`. Currently says "A map containing: …" but `Qx.Simulation.run/2` returns `%Qx.SimulationResult{}` (confirmed by `test/qx/result_builder_test.exs:10` and `test/qx/simulation_renormalization_test.exs:162,176`). Replace prose with "Returns a `Qx.SimulationResult.t()`" and update the `@spec` (audit: public-api S5 MED)
- [ ] Deprecate `Qx.StateInit.bell_state/2` and `Qx.StateInit.ghz_state/1` in favour of `Qx.StateInit.bell_state_vector/2` and `ghz_state_vector/1`. Eliminates the type collision with `Qx.bell_state/1` / `Qx.ghz_state/1` (which return circuits, not state vectors). Add `@deprecated` to the old names, ship the `_vector` variants alongside; removal scheduled for v0.9 (audit: public-api S1 CRIT)
- [ ] Lead `Qx`'s moduledoc with a "Which `h` am I calling?" decision tree: single/multi × calc/circuit grid. `Qx.Qubit.h/1`, `Qx.Register.h/2`, `Qx.Operations.h/2`, `Qx.h/2` all exist for principled reasons but constitute the largest cognitive load in the API. Pull the `Qx.Behaviours.QuantumState` callout (`lib/qx/behaviours/quantum_state.ex:13`) about `Qx.Qubit` deliberately not implementing the behaviour up into the lead doc (audit: public-api MED)
- [ ] Rename `Qx.histogram/2` to `Qx.draw_histogram/2` (alias the old name with `@deprecated`). Only noun-only member of the `Qx.draw*` family; rest are `draw`, `draw_counts`, `draw_bloch`, `draw_state` (audit: public-api LOW naming)
- [ ] Decide `Qx.Validation` public/internal: currently has a full `@moduledoc` with examples (suggests public, useful for downstream library extension) but isn't in the Iron-Laws list. Either add to the declared public surface or mark `@moduledoc false` and stop documenting examples (audit: public-api LOW)
- [ ] Mark `Qx.Patterns.ghz_state_circuit/1` (`lib/qx/patterns.ex:373`) `@doc false` or merge with `Qx.StateInit.ghz_state/1`. Currently three names for one concept once `Qx.ghz_state/1` is counted (audit: public-api MED)
- [ ] Document `to_qasm/1` vs `from_qasm/1` return-shape asymmetry: `to_qasm` raises while `from_qasm` returns `{:ok, _} | {:error, _}`. Defensible (`to_qasm` failure modes are limited to version + unsupported instruction) but currently surprising. Add a one-paragraph note to `Qx.Export.OpenQASM`'s moduledoc (audit: public-api MED return-shape)

---

## v0.8.2: Simulation Refactor, Visualization & AWS Braket

Replace the case-dispatch core in `Qx.Simulation` with a gate registry
/ multi-clause functions, clarify the Calc / CalcFast split, polish the
Bloch sphere renderer, and broaden hardware support beyond IBM.

- [ ] Replace case dispatch with gate registry in apply_instruction (qx-agu)
- [ ] Convert case gate_name dispatch to multi-clause functions in Simulation (qx-dn2)
- [ ] Clarify or merge Calc module responsibility with CalcFast (qx-rut)
- [ ] Improve Bloch sphere SVG visual quality (qx-w93)
- [ ] Support for running on AWS Braket QPUs (moved from v0.7)
- [ ] Reshape `Qx.CalcFast` kernels to eliminate `Nx.take` gather + `Nx.select` mask: single-qubit (`lib/qx/calc_fast.ex:67–91`), CNOT (`114–143`), CSWAP (`157–185`), Toffoli (`187–229`). Replace with reshape + 2×2 tensor contraction along the qubit axis. Highest-leverage perf change in the audit; depends on the v0.8.1 tolerance widening (audit: perf CRIT C1/C2; Iron Law #3)
- [ ] Vectorise measurement probability and state collapse: `lib/qx/simulation.ex:552–599`. Current host loop `for i <- 0..(2^n - 1), Nx.to_number(state[i])` runs once per shot (~1 M host syncs at 1024 shots × n=10) (audit: perf CRIT C3; Iron Law #5)
- [ ] Replace `2^n × 2^n` matrix materialisation in SWAP / iSWAP / CP / CY / CRx / CRy / CRz: `lib/qx/simulation.ex:402–431` + the host-loop matrix builders in `lib/qx/gates.ex:331–569`. Currently OOM above n≈10 (4.3 GB at n=14) (audit: perf HIGH)
- [ ] Replace host-side `2^n` Elixir-list construction in `Qx.StateInit` (`basis_state`, `random_state`, `ghz_state`, `w_state`, fresh-circuit init) and in `Qx.ResultBuilder.build_probability_tensor` (`List.replace_at` over 2^n list) (audit: perf HIGH; Iron Law #5)
- [ ] Vectorise sample generation: current `Enum.scan` cumulative distribution + per-shot `Enum.find_index` linear scan at `lib/qx/simulation.ex:467–476` is O(shots × 2^n); 100M+ host iterations at 100k shots × n=10 (audit: perf HIGH)
- [ ] Cap retained state in `run_with_conditionals`: `simulation.ex:142–148,156` materialises the full list of `{state, cbits}` for every shot before `Enum.frequencies`; at 100k shots × n=20 holds ~1.6 TB resident before reduce (audit: perf HIGH)
- [ ] Replace `instructions ++ [new]` quadratic append in `Qx.QuantumCircuit:98,122,142,184,602` with prepend + reverse-on-finalise (audit: perf HIGH; also flagged by `usage_rules.elixir`)
- [ ] Cap or auto-truncate probability charts above n≈12 qubits: `lib/qx/draw/svg/charts.ex:31–69,103–137` and `lib/qx/draw/vega_lite.ex:32–50,102–109` currently render one bar per basis state with no bound (n=20 → ~1 M-bar SVG, >100 MB XML, crashes browsers). Raise typed `Qx.*Error` instead (audit: perf CRIT C4)
- [ ] Break the 4-module cycle `tables → register → qubit → draw → tables`: anchored by `Qx.Qubit.draw_bloch/2` defdelegating up to `Qx.Draw` (`lib/qx/qubit.ex:154`) and `Qx.Draw.Tables.render/2` pattern-matching on `%Qx.Register{}` (`lib/qx/draw/tables.ex:56`). Blocks future Draw refactors (audit: arch MED)
- [ ] Replace `:math.pow(2, n) |> trunc/1` with `Integer.pow(2, n)` (or `Bitwise.bsl(1, n)`) across `state_init.ex`, `quantum_circuit.ex`, `simulation.ex`, `gates.ex`, `validation.ex`. Exact integer math (audit: perf LOW)
- [ ] Fix `lib/qx/simulation.ex:50–57` docstring example referencing `EXLA.Backend` while EXLA is commented out of `mix.exs`. Users following the example hit `UndefinedFunctionError` (audit: perf MED; pair with the v0.8.3 `exla`/`emlx` decision)

---

## v0.8.3: Security & Hardening

Hardening pass over the IBM Quantum client, the OpenQASM parser, and
the runtime dependency surface. Items here come from the 2026-06-14
project-health audit
(`.claude/audit/summaries/project-health-2026-06-14.md`). No
behavioural changes, no new features, just closing the MED/LOW findings
that don't fit the test-quality or simulator-refactor cuts.

- [ ] Reject plaintext `http://` for `QX_PORTAL_URL`: `lib/qx/hardware/config.ex:237` `validate_portal_url/1` currently accepts both schemes, so a misconfigured environment sends the portal bearer token over cleartext (audit: security MED)
- [ ] Validate `:base_url` / `:iam_url` test-hook overrides: `lib/qx/hardware/config.ex:42,112–113` accept any scheme/host without sanity checks; a caller setting `base_url: "http://attacker/api/v1"` routes IAM token exchange to an attacker host. Allowlist hosts or require `https://` (audit: security MED)
- [ ] Add a parenthesis-depth cap to the QASM expression grammar: `lib/qx/export/openqasm/parser.ex:180–243` is unbounded within the 1 MB source cap; deep `((((…))))` walks ~0.5 M parser frames and can `:enomem` before erroring (audit: security MED)
- [ ] Wrap generated `def …` from `Qx.Export.OpenQASM.from_qasm_function/1` in a `defmodule Qx.Generated.<id>` envelope so downstream users can't accidentally compile attacker-named helpers into a host module: `lib/qx/export/openqasm/codegen.ex:54–74` + `lib/qx/export/openqasm.ex:432` (audit: security LOW, defence in depth)
- [ ] Harden the IBM Quantum client at `lib/qx/hardware/ibm.ex:91–93,432–434`: bump `/results` `receive_timeout` to 60 s, enable `retry: :safe_transient` on GETs, stream multi-MB Sampler V2 result bodies rather than buffering. Combines a perf HIGH with the security finding that test-hook misconfiguration compounds these failure paths (audit: perf HIGH + security correlation)
- [ ] Redact or trim `{:error, {:http, status, body}}` echoes: `ibm.ex:104–105,464–465` and `portal.ex:163–164` propagate the full decoded response body; downstreams that log errors verbatim leak response headers / request context (audit: security LOW)
- [ ] Resolve the `exla` / `emlx` "optional" story in `mix.exs`: currently commented out with `optional: true`, but no `Code.ensure_loaded?` runtime detection anywhere; EXLA appears only in docstrings telling users to pass `EXLA.Backend` themselves. Pick one: (a) delete the commented lines and the docstring references, or (b) uncomment with `optional: true` and add the runtime guards (audit: deps LOW)
- [ ] Widen runtime dep specs: `nx ~> 0.10` → `~> 0.12` (2 minors behind; `defn` Iron-Law verification required), `complex ~> 0.6` → `~> 0.7`, `req ~> 0.5` → `~> 0.6`. Each is a deliberate spec widen + full `/phx:verify` cycle, not a blind bump (audit: deps MED)

---

## v0.9: Noise & Realism

- [ ] Noise models for simulating real-hardware decoherence (bit-flip, phase-flip, depolarising)
- [ ] Density matrix simulation as an alternative to statevector
- [ ] Circuit optimisation / gate cancellation pass
- [ ] Mid-circuit reset operation `Qx.reset/2`: QAAL `MzReset q` parity; first-class in OpenQASM 3 / IBM hardware. Needs new `:reset` instruction handler in `Qx.Simulation` (projection-and-relabel) (plan: tbd, see qaal-analysis A3)
- [ ] Remove the v0.8.1-deprecated `Qx.StateInit.bell_state/2` and `Qx.StateInit.ghz_state/1` aliases (the state-vector returners): `_vector`-suffixed names become canonical. CHANGELOG entry required; deprecation window closes here (audit: public-api S1 CRIT, removal phase)
- [ ] Remove the deprecated `Qx.Math.basis_state/2` shim (`lib/qx/math.ex:225`): already `@deprecated` in 0.8.x, only internal callers remain. CHANGELOG entry (audit: public-api MED)
- [ ] Remove the deprecated `Qx.histogram/2` alias once `Qx.draw_histogram/2` has shipped for one minor (audit: public-api LOW naming)

---

## v0.10: Algorithms & Learning

- [ ] More quantum algorithm examples in tutorials: Quantum Phase Estimation (QPE), Variational Quantum
  Eigensolver (VQE), Shor's algorithm
- [ ] Quantum error correction tutorial (repetition code)

---

## v1.0: Stability & Production Readiness

- [ ] API stability guarantee: no breaking changes without a major version bump
- [ ] Complete algorithm library covering all canonical textbook algorithms
- [x] Performance benchmarking infrastructure: Benchee suite for GHZ and QFT circuits across
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
- Named circuit-mode register views: bind a name to a contiguous (or arbitrary)
  qubit-index list so `Qx.h_all(qc, alice)` reads like QAAL `H alice`. Stashed
  from `qaal-analysis` plan (A4). Naming collides with the existing calc-mode
  `Qx.Register` struct; large API design surface; B1 (list/range overload of
  `Qx.Patterns`, shipped in v0.8) covers ~80% of the value. Revisit when
  multi-register tutorials (Shor / QPE) start feeling unmanageable.
- `else` branches on `c_if` conditionals (currently raises on import; rewrite as two ifs)
- WASM / browser-side simulation for LiveBook embedding

---

## Out of Scope (for now)

These are explicitly not planned, to set honest expectations:

- **Full fault-tolerant simulation**: the memory requirements make this impractical at the qubit
  counts Qx targets
- **Hardware control / pulse-level scheduling**: IBM Quantum handles the hardware layer; Qx stays at
  the circuit abstraction level
- **Classical co-processing / hybrid workflows beyond conditional gates**: out of scope until the
  core simulation story is complete
