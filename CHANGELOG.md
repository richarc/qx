# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `Qx.draw_histogram/2`, replacing `Qx.histogram/2`. The new name
  matches the rest of the `Qx.draw*` family (`Qx.draw/2`,
  `Qx.draw_counts/2`, `Qx.draw_bloch/2`, `Qx.draw_state/2`).

### Changed

- **Typed errors for the last raw `ArgumentError`s in `Qx.Validation`
  (plan: iron-law-7-followon).** Completes the Iron Law #7 pass begun
  in 0.8.0. `Qx.Validation` now raises typed exceptions instead of
  `ArgumentError`:

    - a non-numeric gate parameter raises the new `Qx.ParameterError`
      (carries the offending `:value`);
    - duplicate qubit indices raise `Qx.QubitIndexError`;
    - a state-vector shape mismatch raises `Qx.StateShapeError`.

  Observable on the public rotation/phase gates `Qx.rx/3`, `ry/3`,
  `rz/3`, `u/5`, `cp/4`, `crx/4`, `cry/4`, `crz/4` (and their
  `Qx.Operations` equivalents): a non-numeric angle now raises
  `Qx.ParameterError` rather than `ArgumentError`. Code rescuing the
  old `ArgumentError` must be updated.

- **Typed errors across the rest of the public surface
  (plan: iron-law-7-sweep).** Clears the remaining raw `ArgumentError`s
  and one stray `FunctionClauseError` from the public API, finishing the
  Iron Law #7 work begun in 0.8.0. Two new exceptions:

    - `Qx.RegisterError` — register construction input (an empty list, a
      malformed qubit, or a renderer handed a non-register); carries a
      `:reason`.
    - `Qx.BasisError` — a computational basis value that is not 0 or 1;
      carries the offending `:value`.

  Retyped surfaces — code rescuing the old `ArgumentError` /
  `FunctionClauseError` must be updated:

    - `Qx.Register.new/1` and `Qx.Register.from_basis_states/1` →
      `Qx.RegisterError` / `Qx.BasisError`;
    - the register two-qubit distinctness gates (`cx`, `cz`, `cy`,
      `ccx`, `swap`, `iswap`, `cswap`, and the controlled-target gates)
      → `Qx.QubitIndexError`;
    - `Qx.Qubit.from_basis/1` → `Qx.BasisError`;
    - `Qx.Draw.*` plots and `Qx.Draw.Tables.render/2` with an invalid
      `:format` → `Qx.OptionError`; a non-register input →
      `Qx.RegisterError`;
    - `Qx.Export.OpenQASM.to_qasm/2` with an invalid `:version` →
      `Qx.OptionError`;
    - `Qx.Draw.SVG.Circuit.render/1` on a malformed circuit →
      `Qx.QubitCountError` / `Qx.GateError` / `Qx.QubitIndexError` /
      `Qx.ClassicalBitError`;
    - `Qx.u/5` with an out-of-range qubit now raises
      `Qx.QubitIndexError` instead of `FunctionClauseError`, matching
      `rx`/`ry`/`rz`/`cp`.

### Deprecated

- `Qx.histogram/2` is deprecated. Use `Qx.draw_histogram/2` instead.
  Emits a compile-time warning and is hidden from ExDoc. Scheduled
  for removal in v1.0.

## [0.8.0] - 2026-05-22

### Added

- **Full calc-mode gate parity on Qx.Register
  (plan: api-cleanup-phase-b).** Eight gates that previously existed
  only in circuit mode are now available on `Qx.Register` as direct
  state-vector evolutions:

    - `Qx.Register.cy/3`: controlled-Y
    - `Qx.Register.crx/4`, `cry/4`, `crz/4`: controlled rotations
    - `Qx.Register.cp/4`: controlled-phase
    - `Qx.Register.swap/3`, `iswap/3`: two-qubit swaps
    - `Qx.Register.cswap/4`: Fredkin (controlled-SWAP)
    - `Qx.Register.u/5`: general single-qubit unitary

  All five controlled-target gates (`cy`, `crx`, `cry`, `crz`, `cp`)
  share an `apply_controlled_target/4` internal helper that lifts a
  2×2 gate matrix into the full controlled two-qubit unitary via the
  internal Qx.Gates.controlled_gate factory and applies it to
  `register.state`.

- **Basis-explicit measurement on Qx.Qubit
  (plan: api-cleanup-phase-b).** `Qx.Qubit.measure_x/1`, `measure_y/1`,
  and `measure_z/1` return the probability distribution in the X, Y,
  and Z bases respectively (the Z form is an alias of the existing
  `measure_probabilities/1` for symmetry). Maps directly to QAAL `Mx`,
  `My`, `Mz`. Implementation reuses the existing single-qubit gate
  pipeline (`H` for X-basis, `Sdg ; H` for Y-basis).

- **Named circuit recipes consolidated under Qx.Patterns
  (plan: api-cleanup-phase-b).** New helpers
  `Qx.Patterns.bell_state_circuit/1`, `ghz_state_circuit/1`, and
  `superposition_circuit/1`. The top-level `Qx.bell_state`,
  `Qx.ghz_state`, and `Qx.superposition` now delegate to these
  helpers (no break: old call sites continue to work). Two of the
  three got new optional arguments: `Qx.ghz_state(num_qubits \\ 3)`
  and `Qx.superposition(num_qubits \\ 1)`: previously hardcoded to
  3 and 1 qubits respectively.

### Changed

- **Qx.Behaviours.QuantumState now has callbacks (and an
  implementor).** Previously a dead behaviour that no module
  implemented: `Qx.Register` now declares `@behaviour
  Qx.Behaviours.QuantumState` and provides every required callback.
  The callback list grew to cover the full Phase B gate surface
  (`sdg`, `u`, `cy`, `swap`, `iswap`, `cp`, `crx`, `cry`, `crz`,
  `ccx`, `cswap`); the new callbacks are listed under
  `@optional_callbacks` so future implementors with smaller surfaces
  (e.g. a 2-qubit-only subset) don't need to provide them. Going
  forward, adding a gate to the multi-qubit calc-mode surface is
  compile-time-enforced to update both the behaviour and `Qx.Register`.

  Single-qubit `Qx.Qubit` is **not** an implementor: its functions
  take `(state)` rather than `(state, qubit_index)`, so the
  signature is structurally incompatible. Unifying both paradigms
  under one behaviour is a v1.0 redesign and is documented in the
  behaviour's `@moduledoc`.

- **Qx.Validation.validate_gate_name!/1 removed.** It was dead code
  (called only from its own tests) with a stale known-gates list
  (missing CY/CRx/CRy/CRz/CP added in qaal-parity). The
  corresponding test block is removed from `validation_test.exs`.

- **Qx.Validation removed from `mix.exs` `groups_for_modules`.**
  After Phase A's `@doc false` sweep, only `valid_qubit?/2` and
  `valid_register?/2` remain visible: too thin to warrant a top-level
  group. The module page itself is still reachable; the renamed
  "Utilities" group lists `Qx.Math` and `Qx.StateInit`.

- **Internal-only functions hidden from documentation
  (plan: api-cleanup-phase-a).** A public-API audit found that several
  modules labelled "Low-Level Operations" or "Validation & Utilities"
  in `mix.exs` were exporting `def` functions that are used only inside
  the library. The following are now `@moduledoc false` or
  per-function `@doc false`:

  - **Qx.Gates, Qx.Calc, Qx.CalcFast, Qx.Format, Qx.ResultBuilder**:
    entire modules tagged `@moduledoc false`. Removed from `mix.exs`
    `groups_for_modules`. Functions remain callable for advanced users;
    they just no longer appear in ExDoc or IDE auto-complete.
  - **Qx.QuantumCircuit.add_gate, add_two_qubit_gate,
    add_three_qubit_gate, add_measurement**: `@doc false`. The
    user-facing API is `Qx.h(qc, 0)` etc.; these are internal helpers.
  - **Qx.Validation `validate_*!` family (10 functions)**: `@doc false`.
    Internal Iron Law #7 contracts. The user-facing predicates
    `Qx.Validation.valid_qubit?/2` and `valid_register?/2` remain
    public.
  - **Qx.Math.complex_to_tensor, tensor_to_complex, complex_matrix**:
    `@doc false`. The rest of `Qx.Math` (`complex/2`, `identity/1`,
    `unitary?/1`, `probabilities/1`) stays public.

  No call site breaks. Existing tests pass unchanged.

- **`Qx.Qubit.draw_bloch/2`** converted from a `def` wrapper to a
  `defdelegate`. Behaviour unchanged.

- **`Qx.Error` `@moduledoc` rewritten to be accurate.** The previous
  text described it as a "base exception" Qx users could rescue to
  catch any Qx error. Elixir exceptions do not inherit, so
  `rescue Qx.Error` catches *nothing* today: the docstring now says
  so explicitly and lists every typed exception users actually need
  to rescue.

### Deprecated

- **Qx.Math.basis_state/2 is deprecated**: use
  `Qx.StateInit.basis_state/3` instead. The two functions returned
  different types (Math was f32, StateInit is c64), and the StateInit
  form is the canonical one. The deprecated function emits a
  compile-time warning and is hidden from ExDoc; it will be removed
  in v1.0.

### Fixed

- **Qx.QuantumCircuit.new now enforces the documented 1..20-qubit cap
  at both bounds (plan: api-cleanup-phase-a, finding D3).** Previously:
  `new(25)` silently created an over-cap circuit (upper bound unchecked
  on this path); `new(0)` raised `FunctionClauseError` via a guard
  (lower bound untyped). Both paths now raise `Qx.QubitCountError`
  consistently: the function calls the internal `validate_num_qubits!`
  validator on every input. Closes Iron Law #7 holes at both bounds,
  surfaced by `.claude/plans/public-api-audit/plan.md`.

### BREAKING

- **Typed errors at public API boundaries (Iron Law #7).** Out-of-range
  qubit indices, duplicate qubit indices, classical-bit OOR, invalid
  conditional values, and unsupported gates now raise the matching
  `Qx.*Error` exception instead of `FunctionClauseError`, `ArgumentError`,
  or `RuntimeError`. Resolves C1/C2/C3 of
  `.claude/audit/reports/arch-review.md`.

  - `Qx.QuantumCircuit.add_gate/4`, `add_two_qubit_gate/5`,
    `add_three_qubit_gate/6`, `add_measurement/3` now raise
    `Qx.QubitIndexError` for out-of-range or duplicate qubits, and
    `Qx.ClassicalBitError` for out-of-range classical-bit indices.
  - `Qx.Operations.barrier/2` now raises `Qx.QubitIndexError`.
  - `Qx.Operations.c_if/4` now raises `Qx.ClassicalBitError`
    (out-of-range bit) and `Qx.ConditionalError` (invalid value,
    non-function `gate_fn`, nested conditional).
  - `Qx.Simulation.run/2` (and the `Qx.run/2` delegate) now raises
    `Qx.GateError, {:unsupported_gate, gate_name}` instead of
    `RuntimeError` for unsupported gate names at any arity.
  - `Qx.QuantumCircuit.set_state/2` now raises `Qx.StateShapeError`
    instead of `ArgumentError` on size or rank mismatch.
  - `Qx` and `Qx.Operations` docstring `## Raises` sections updated
    accordingly.

  Migration: rescue clauses matching `FunctionClauseError`,
  `ArgumentError`, or `RuntimeError` at these public call sites must
  be updated to the matching `Qx.*Error` exception. The same `try`
  block can rescue `Qx.Error` to catch any Qx-raised exception.

  **Known deferred (not fixed in 0.8.0):** `Qx.Validation`
  (`validate_qubits_different!`, `validate_state_shape!`,
  `validate_parameter!`) still raises bare `ArgumentError`; `Qx.Qubit`
  and `Qx.Register` still raise `ArgumentError` from public functions;
  `Qx.Operations.u/5` still fires `FunctionClauseError` for OOR qubit
  (its own bounds guard). These map to arch-review findings H1, M3,
  M4, M5 and are scheduled for a follow-on Iron Law #7 sweep.

### Added

- **`Qx.StateShapeError`**: new exception type raised by
  `Qx.QuantumCircuit.set_state/2` when the supplied state vector's
  shape doesn't match `{2^num_qubits}`. Carries `:actual` and
  `:expected` size fields.

- **`Qx.QubitIndexError` `{:duplicate, qubits}` constructor.** New
  `exception/1` clause to raise on distinct-indices violations (e.g.
  CNOT with `control == target`, Toffoli with repeated qubits).
  Message: `"Qubit indices must be distinct, got: [...]"`.

- **Controlled rotations: `Qx.cy/3`, `Qx.crx/4`, `Qx.cry/4`, `Qx.crz/4`
  (plan: qaal-parity).** Standard controlled-Pauli-Y and controlled
  rotation gates, mapping directly to QAAL `CY`/`CRx`/`CRy`/`CRz` and
  OpenQASM 3 `cy`/`crx`/`cry`/`crz`. Simulation handlers reuse the
  existing two-qubit `controlled_gate/4` contraction. The OpenQASM
  importer (`Qx.Export.OpenQASM.from_qasm/1`) now also recognises these
  gates: previously they were in the unsupported-stdgates set.

- **Basis-explicit measurement: `Qx.measure_x/3`, `Qx.measure_y/3`,
  `Qx.measure_z/3` (plan: qaal-parity).** Match QAAL `Mx`/`My`/`Mz`
  classical-outcome semantics: `measure_x` lowers to `H ; Mz`,
  `measure_y` lowers to `Sdg ; H ; Mz`, `measure_z` is an alias of
  `measure/3` for symmetry. Note: Qx's simulator samples in the
  computational basis at end-of-circuit, so the post-measurement
  *quantum state* stays Z-basis-aligned (not rotated back into the
  X-/Y-basis eigenstate): the **classical outcome** is what tutorials
  care about and matches QAAL.

- **`Qx.Patterns` sub-register overload (`/2` arity)
  (plan: qaal-parity).** `h_all/2`, `x_all/2`, `y_all/2`, `z_all/2`,
  `measure_all/2`, `barrier_all/2` accept a list or `Range` of qubit
  indices in addition to the existing whole-circuit `/1` form. Lets
  tutorials operate on a sub-register without re-deriving qubit ranges
  by hand: `Qx.h_all(qc, 0..2)`, `Qx.measure_all(qc, [0, 2])`. Empty
  list/range is a no-op.

- **`Qx.Patterns`: composite circuit-building helpers.** New module
  providing seven thin wrappers over `Qx.Operations` for the recurring
  "apply to every qubit" / "CNOT chain" motifs that appear in tutorials
  (Grover diffuser, Bernstein-Vazirani oracle, GHZ preparation):

  - `Qx.Patterns.h_all/1`, `x_all/1`, `y_all/1`, `z_all/1`: apply the
    single-qubit gate to every qubit in the circuit.
  - `Qx.Patterns.measure_all/1`: measure qubit `i` into classical bit
    `i` for all qubits. Raises `Qx.ClassicalBitError` if
    `num_classical_bits < num_qubits` (caller owns circuit shape: no
    auto-grow).
  - `Qx.Patterns.barrier_all/1`: single barrier across every qubit.
  - `Qx.Patterns.cx_chain/2`: linear CNOT cascade
    (`cx(q0,q1) → cx(q1,q2) → …`) along the supplied qubit list;
    `[]` and `[q]` are deliberate no-ops.

  All seven are also exposed at the top level (`Qx.h_all/1`,
  `Qx.measure_all/1`, …) via `defdelegate`. Purely additive: no
  breaking change. Out-of-range qubit indices propagate the existing
  typed `Qx.QubitIndexError` inherited from
  `Qx.QuantumCircuit.add_*` / `Qx.Validation`.

- **Configurable statevector renormalization + dev/test norm-drift
  guard in `Qx.Simulation.run/2` / `Qx.run/2` (qx-53v).** New
  `:renormalize` option (default `false`: fully backwards compatible,
  zero cost when off): `true` renormalizes at measurement-time; a
  positive integer `N` renormalizes every `N` gates and at
  measurement-time; any other value raises the new typed
  `Qx.OptionError`. A compile-time-gated assertion
  (`Application.compile_env(:qx, :assert_norm, false)`, on in `:test`,
  off in `:prod`/`:dev`) fails fast if a circuit's total probability
  drifts beyond `1.0e-6`. Note: states are `:c64` (float32), so the
  practical norm-accuracy floor is ~1e-7; renormalization bounds drift
  rather than eliminating it.

## [0.7.1] - 2026-05-16

### Fixed

- **`Qx.Hardware.connect/2` now supports discovery before a backend is
  chosen.** It previously hard-validated `backend ∈ backends_list` and
  returned a `Qx.Hardware.ConfigError` on a blank backend, which broke
  the connect-then-pick flow (e.g. a UI populating a backend dropdown
  from the connect result). Blank (`nil`/`""`/whitespace) `backend` now
  skips the membership check and returns the populated config; a
  *set* backend is still validated (catches typos early). `run/3`,
  `run!/3`, and `submit_qasm/3` now reject a blank backend up front
  with a clear `ConfigError` instead of failing deep in an IBM call.

### Security

- **`Qx.Hardware.Config` no longer leaks credentials via `inspect/1`**
  (qx-o9h). Added `@derive {Inspect, except: [...]}` so `:portal_token`,
  `:ibm_api_key`, `:ibm_crn`, and `:access_token` are redacted in all
  inspect output (Logger, BEAM crash reports, error tuples embedding
  the struct). Non-secret fields remain visible.

## [0.7.0] - 2026-05-15

### BREAKING

- **Removed `Qx.Remote`, `Qx.Remote.Config`, and `Qx.RemoteError`.** The qx_server-based hardware path has been replaced by direct-to-IBM execution via `Qx.Hardware`. There is no shim; the credential shape and call sites are different.

  Migration:

  ```elixir
  # before (0.6.x)
  config = Qx.Remote.Config.new!(url: "...", api_key: "...")
  {:ok, result} = Qx.Remote.run(circuit, config, backend: "ibm_brisbane", shots: 4096)

  # after (0.7.x)
  config =
    Qx.Hardware.Config.new!(
      portal_url: "https://api.qxquantum.com",
      portal_token: "<qxportal token>",
      ibm_api_key: "<ibm cloud api key>",
      ibm_crn: "<ibm quantum service crn>",
      ibm_region: "us-east",
      backend: "ibm_brisbane",
      shots: 4096
    )

  {:ok, result} = Qx.Hardware.run(circuit, config)
  ```

  The new `Qx.Hardware.Config.from_env!/1` reads `QX_PORTAL_URL`, `QX_PORTAL_TOKEN`, `QX_IBM_API_KEY`, `QX_IBM_CRN`, `QX_IBM_REGION`, `QX_IBM_BACKEND` for a one-liner setup.

### Added

- **`Qx.Hardware`**: public namespace owning the full direct-to-IBM execution pipeline (IAM exchange → qxportal transpile → IBM submit → poll → result-build).
- **`Qx.Hardware.Config`**: credential + execution-preference struct (`portal_url`, `portal_token`, `ibm_api_key`, `ibm_crn`, `ibm_region`, `backend`, `optimization_level`, `shots`). Validates region against the IBM allowlist, optimization_level `0..3`, shots `1..100_000`, portal URL scheme.
- **`Qx.Hardware.Ibm`**: Req-based client for IBM Quantum (Qiskit Runtime REST API). IAM exchange + 401-refresh-retry, backends list, backend configuration, Sampler V2 submission, poll loop with Pascal-Case status allowlist, sample-aggregation to counts, best-effort cancel.
- **`Qx.Hardware.Portal`**: Req-based client for the qxportal `/api/v1/me` and `/api/v1/transpile` endpoints. Atomize allowlist for response keys.
- **`Qx.Hardware.NoMeasurementsError`**: raised when a circuit submitted to hardware has no `measure/2` instructions.
- **`Qx.Hardware.ConfigError`**: typed validation error for `Qx.Hardware.Config`.
- **Privacy invariant**: two independent HTTP clients; the portal token never reaches IBM, and the IBM API key/CRN never reach the portal.
- **Status callback**: pipeline progress events (`{:portal, :transpiling}`, `{:ibm, :polling, status}`, …). All atoms literal (Iron Law #1: no `String.to_atom` on caller input).

### Removed

- `Qx.Remote`, `Qx.Remote.Config`, `Qx.RemoteError` (see BREAKING above).
- `examples/remote/`: superseded by `examples/hardware/run_on_ibm.exs`.

### Dependencies

- New test-only dep: `{:bypass, "~> 2.1"}` (HTTP stubbing for portal + IBM tests).
- Explicit pin: `{:jason, "~> 1.4"}` (previously transitive via Req/Plug).

## [0.6.0] - 2026-05-04

### Added
- **OpenQASM 3.0 import**: `Qx.Export.OpenQASM.from_qasm/1` and `from_qasm!/1` parse OpenQASM 3 source produced by Qx itself, by Qiskit, or by IBM Quantum and return a `%Qx.QuantumCircuit{}`. Round-trips with `to_qasm/1` (statevectors match within 1e-10).
- **Gate definition codegen**: `Qx.Export.OpenQASM.from_qasm_function/1` (and the bang variant) parses a `gate name(p1, …) a, b { … }` definition and returns `%{name, arity, source}`, where `source` is an Elixir `def …` string that compiles via `Code.compile_string/1`. Function signature: `(circuit, params…, qubits…)`.
- **Supported gate set on import**: direct mappings for `h, x, y, z, s, sdg, t, rx, ry, rz, p, phase, u, u3, cx, CX, cz, swap, iswap, cp, cphase, ccx, cswap`. Decompositions for `tdg → phase(-π/4)`, `sx → u(π/2, -π/2, π/2)`, `u1(λ) → phase(λ)`, `u2(φ, λ) → u(π/2, φ, λ)`. `id` is dropped.
- **Typed import errors**: `Qx.QasmParseError` (line/column/snippet) and `Qx.QasmUnsupportedError` (feature/line/hint) for grammar failures and out-of-scope features respectively.
- `Qx.cp/4`: controlled-phase gate applying e^(i·θ) to the |11⟩ basis state, required for QFT and QPE circuits
- `Qx.swap/3`: SWAP gate exchanging the quantum states of two qubits; includes circuit diagram rendering (× symbols connected by a line) and OpenQASM 3 export
- `Qx.iswap/3`: iSWAP gate exchanging qubit states with an i phase factor on the swapped components; native to superconducting hardware; includes circuit diagram rendering (labelled iSW boxes) and OpenQASM 3 export
- `Qx.u/5`: general single-qubit unitary gate U(θ,φ,λ) per IBM/OpenQASM 3 convention; subsumes X, Y, Z, H, RX, RY, RZ as special cases; includes circuit diagram rendering and OpenQASM 3 export
- `Qx.cswap/4`: Fredkin (controlled-SWAP) gate; swaps two target qubits when the control is |1⟩; universal reversible gate used in quantum multiplexers and arithmetic circuits; includes circuit diagram rendering and OpenQASM 3 export

### Not supported on import (raises `Qx.QasmUnsupportedError`)
- Multi-register programs (Qx models a single quantum + single classical register)
- `else` branches on `if` (refactor as two `if` statements)
- Gate modifiers `inv @`, `pow(N) @`, `ctrl @`, `negctrl @`
- `def`, `for`, `while`, `switch`, classical types beyond `bit`, `defcal`, `let`, `pragma`, `extern`, `box`, `delay`, `reset`
- stdgates `cy`, `ch`, `crx`, `cry`, `crz`, `cu` (no Qx equivalent yet)
- Qiskit-extension gates `rxx`, `ryy`, `rzz`, `rzx` (not in `stdgates.inc`)
- Discarded `measure q[i];` (Qx requires a classical bit target)
- Complex boolean conditions (`&&`, `||`)

### Dependencies
- New runtime dependency: `nimble_parsec ~> 1.4` (compile-time parser generator)

## [0.5.2] - 2026-04-11

### Added
- **Bell State Extensions** - `Qx.bell_state/2` now supports all four Bell states: `phi_plus` (default), `phi_minus`, `psi_plus`, and `psi_minus`

### Fixed
- Circuit diagram: measurement arrowhead now terminates at the classical register double line instead of extending 8 px past it
- Bloch sphere rendering: improved wireframe contrast, white halos on axis and state labels, and equatorial projection indicator for clearer visualization

## [0.5.1] - 2026-03-07

### Added
- **S-dagger (Sdg) Gate** - New `sdg` gate implementing the S† operation (-π/2 phase rotation on |1⟩)
  - `Qx.sdg/2` for Circuit Mode: adds an sdg gate to a quantum circuit
  - `Qx.Operations.sdg/2` for direct operations API
  - `Qx.Qubit.sdg/1` for Calculation Mode on single qubits
  - `Qx.Register.sdg/2` for Calculation Mode on multi-qubit registers
  - Full simulation support in `Qx.Simulation` (mapped to `Qx.Gates.s_dagger/0`)
  - OpenQASM 3.0 export support (`sdg q[0];`)
  - Validation support for the `:sdg` gate atom
  - Full test coverage including matrix correctness, S·S† = I identity verification, and circuit export
- **New LiveBook Tutorials** - Expanded tutorial collection at `examples/tutorials/`
  - `quantum_state_and_qubit.livemd` - Introduction to quantum states and single-qubit operations
  - `quantum_measurement.livemd` - Quantum measurement concepts and examples
  - `systems_of_qubits_and_entanglement.livemd` - Multi-qubit systems and entanglement
  - `quantum_algorithms.livemd` - Common quantum algorithms with Qx

## [0.5.0] - 2026-02-17

### Added
- **Remote Execution via QxServer** - Run quantum circuits on real hardware through QxServer
  - New `Qx.Remote` module for submitting circuits, polling job status, and retrieving results
  - New `Qx.Remote.Config` for configuring QxServer connection (URL, API key, timeout)
  - New `Qx.ResultBuilder` for constructing `Qx.SimulationResult` structs from hardware counts data
  - New `Qx.RemoteError` exception type for remote execution errors
  - Example script at `examples/remote/run_on_hardware.exs`
- **Quantum Operations Tutorial** - New comprehensive LiveBook tutorial covering quantum gates, Bloch sphere, and two-qubit operations at `examples/tutorials/quantum_operations_tutorial.livemd`

### Changed
- **README Restructure** - Major reorganization for better new-user experience
  - Moved Performance & Acceleration section (~380 lines) from between Installation and Quick Start to the end
  - Removed API Reference section (duplicated by hexdocs) and Module Structure section
  - Added "Understanding the Two Modes" orientation section with comparison table
  - Added consolidated Visualization section
  - Added links to hexdocs and LiveBook guides
  - Reduced README from 1,308 to ~750 lines

### Fixed
- `Qx.Qubit.draw_bloch/2` now correctly defaults to `:vega_lite` format (was ignoring the default and using `:svg`)
- Draw functions (`Qx.Draw.plot_counts/2`, `Qx.Draw.plot/2`) now correctly handle `SimulationResult` structs from hardware backends where counts keys are binary strings
- OpenQASM export formatting improvements

## [0.4.0] - 2025-12-23

### Added
- **OpenQASM 3.0 Export** - Export quantum circuits to OpenQASM format for real quantum hardware execution
  - Full support for OpenQASM 3.0 syntax including conditionals
  - Export via `Qx.Export.OpenQASM.to_qasm/2` with customizable options
  - Supports all quantum gates, measurements, barriers, and conditional operations
  - Enables seamless integration with IBM Quantum, Rigetti, and other quantum hardware platforms
- **Error Handling Documentation (qx-gd5)** - Comprehensive CONTRIBUTING.md with error handling philosophy and best practices
  - Detailed guidelines for error types, messages, and recovery strategies
  - Error handling patterns for library developers
  - Examples of proper error propagation and context enrichment
  - Documentation of all custom error types and their use cases
- **Test Coverage Integration (qx-xbf)** - Complete test coverage metrics and CI/CD integration
  - Added ExCoveralls dependency for code coverage reporting
  - Achieved 66.4% test coverage across the codebase
  - Integrated coverage reporting into CI/CD pipeline
  - Configured multiple coverage output formats (HTML, JSON, Cobertura)
  - Added GitHub Actions integration for coverage tracking

### Changed
- **Predicate Function Conventions (qx-7iw)** - Enhanced predicate naming and specifications
  - Added `@spec` type specifications to all predicate functions
  - Improved naming conventions for boolean-returning functions
  - Enhanced documentation for predicate function usage patterns
  - Better consistency across module APIs
- **Module Documentation (qx-sdb)** - Verified comprehensive module documentation
  - Confirmed all modules have proper `@moduledoc` documentation
  - Ensured consistent documentation style across the codebase
  - Enhanced module-level descriptions and usage examples

### Fixed
- Credo strict mode compliance in OpenQASM export module
  - Refactored complex pattern matching to reduce cyclomatic complexity
  - Used `Enum.map_join/3` for better performance
  - Added inline Credo exception for legitimate gate mapping complexity

### Improved
- Development workflow with better error handling guidelines
- Code quality with comprehensive type specifications
- Test coverage visibility and tracking
- Documentation completeness and consistency
- Hardware integration capabilities via OpenQASM export

## [0.3.0] - 2025-12-21

### Added
- **Runtime Backend Selection** - Major new feature allowing backend specification at runtime without compile-time configuration
  - Added `:backend` option to `Qx.run/2`, `Qx.get_state/2`, and `Qx.get_probabilities/2`
  - Users can now specify different backends for different circuits: `Qx.run(circuit, backend: EXLA.Backend)`
  - Supports all Nx backends including EXLA (CPU/CUDA/ROCm) and EMLX (Apple Silicon GPU)
  - Combines with other options: `Qx.run(circuit, backend: EXLA.Backend, shots: 2048)`
  - Maintains full backward compatibility with existing code
  - Implemented using `Nx.with_default_backend/2` for proper scoped execution
  - Comprehensive documentation added to README.md with usage examples and best practices

### Changed
- **Draw Module Refactoring** - Reorganized visualization code for better maintainability and clarity
  - Split large 1,531-line `Qx.Draw` module into 5 focused sub-modules:
    - `Qx.Draw.VegaLite` - VegaLite chart generation for LiveBook (178 lines)
    - `Qx.Draw.SVG.Charts` - SVG histogram and bar charts (199 lines)
    - `Qx.Draw.SVG.Bloch` - Bloch sphere visualization with 3D projection (267 lines)
    - `Qx.Draw.SVG.Circuit` - Quantum circuit diagrams with IEEE notation (596 lines)
    - `Qx.Draw.Tables` - State table formatting with Kino support (196 lines)
  - `Qx.Draw` now serves as a clean API facade, delegating to specialized sub-modules
  - Maintains 100% backward compatibility - no API changes required
  - Improved code organization following single responsibility principle
  - Better separation of concerns between rendering formats and visualization types
  - All 557 tests continue to pass

### Fixed
- Fixed Nx backend configuration anti-pattern where library imposed compile-time backend choices on users
- Eliminated warnings about undefined `Nx.default_backend/2` function

## [0.2.5] - 2025-12-16
### Fixed
- More fixes to the pipeline

## [0.2.4] - 2025-12-16
### Fixed
- More automation of the release and build process
- pipeline fixes

## [0.2.3] - 2025-12-14

### Fixed
- Simplified application configuration to resolve Nx.Defn compilation issues
- Removed unnecessary application dependencies that were causing compile-time conflicts

## [0.2.2] - 2025-12-14

### Fixed
- Added `nx` and `complex` to extra_applications in mix.exs to fix compilation errors when using the Hex package
- Ensures dependencies are loaded before qx_sim compiles

### Changed
- Published to Hex.pm as `qx_sim` (package name "qx" was already taken)
- Updated installation instructions to use Hex.pm syntax
- Added Hex.pm badges to README

## [0.2.1] - 2025-11-26

### Changed
- Improved readability of Bloch sphere labels
- Refactored code and tidied up documentation
- Cleaned up old test files
- Updated README.md

### Fixed
- Fixed CNOT gate error
- Fixed dependencies
- Fixed `mix.exs` configuration

## [0.2.0] - 2025-11-01

### Added

#### Core Quantum Computing Features
- Full quantum circuit API with chainable operations via `Qx` module
- Support for 20+ quantum gates including:
  - Single-qubit gates: H, X, Y, Z, S, T, Sdg, Tdg
  - Parametric rotation gates: RX, RY, RZ with arbitrary angles
  - Two-qubit gates: CNOT (CX), CZ (Controlled-Z), SWAP
  - Multi-qubit support up to 20 qubits
- Measurement operations with classical bit storage and reset capabilities
- Conditional operations based on classical measurement results
- Statevector simulation using Nx tensors with Complex64 format
- Direct state access via `Qx.get_state/1`

#### Visualization
- Circuit diagram generation with `Qx.Draw.circuit/2` for publication-quality SVG output
- State visualization using VegaLite: bar charts, probability distributions, Bloch sphere
- SVG export capability for all visualization types
- Example visualization scripts in `examples/` directory including `circuit_visualization_example.exs`

#### Performance & Acceleration
- EXLA backend integration for CPU acceleration (~100x speedup vs Binary)
- EMLX backend support for Apple Silicon GPU acceleration (M1/M2/M3/M4)
- Automatic backend detection and configuration
- JIT compilation support via Nx.Defn

#### Benchmarking Suite
- Professional benchmarking infrastructure using Benchee
- GHZ state scaling benchmarks (5, 10, 15, 20 qubits)
- Backend comparison benchmarks (Binary, EXLA CPU, EMLX GPU, EXLA CUDA/ROCm)
- HTML report generation with interactive graphs
- Statistical analysis with warmup, iterations, and memory profiling
- Safe GPU backend detection with graceful fallback

#### Documentation & Examples
- Comprehensive API documentation with examples
- Example files demonstrating:
  - Basic quantum circuit operations
  - Complex number handling
  - Bell state creation
  - Quantum teleportation protocol
  - Conditional circuit operations
  - Grover's search algorithm
  - Circuit visualization techniques
- Performance benchmarking guide
- Backend configuration documentation

#### Error Handling
- Structured error types for better debugging:
  - `Qx.QubitIndexError` - Invalid qubit indices
  - `Qx.StateNormalizationError` - State vector normalization issues
  - `Qx.MeasurementError` - Measurement failures
  - `Qx.ConditionalError` - Conditional operation errors
  - `Qx.ClassicalBitError` - Classical bit access errors
  - `Qx.GateError` - Gate application failures
  - `Qx.QubitCountError` - Invalid qubit count specifications

### Changed
- Updated state representation to use `:c64` (Complex64) tensor format for improved performance
- Migrated from Torchx to EMLX for Apple Silicon GPU acceleration (pure Elixir, no Python)
- Enhanced error messages with context and suggestions
- Improved documentation structure with module grouping
- Updated examples to work with latest Complex number API

### Performance
- **~100x speedup** with EXLA CPU backend compared to Binary backend
- **Additional 2-10x speedup** with GPU acceleration (hardware dependent)
- Efficient statevector manipulation with direct tensor operations
- Optimized gate application avoiding unnecessary matrix construction

### Fixed
- Complex number handling in example files for `:c64` format
- CZ gate now properly exposed in main `Qx` module API
- Backend detection error handling for unavailable GPU platforms
- Output directory creation in visualization examples
- Grover's algorithm now uses proper CZ gates instead of H-CX-H decomposition

### Developer Experience
- Added `:usage_rules` dependency for better development ergonomics
- Comprehensive test suite with 549 passing tests
- Modular architecture separating concerns (Circuit, Operations, Simulation, etc.)
- Clean API design following Elixir conventions

---

## [0.1.0] - 2024-10-05

### Added
- Initial release
- Basic quantum circuit functionality
- Core gate operations
- Statevector simulation
- Nx backend integration

---

[Unreleased]: https://github.com/richarc/qx/compare/v0.8.0...HEAD
[0.8.0]: https://github.com/richarc/qx/releases/tag/v0.8.0
[0.7.1]: https://github.com/richarc/qx/releases/tag/v0.7.1
[0.7.0]: https://github.com/richarc/qx/releases/tag/v0.7.0
[0.6.0]: https://github.com/richarc/qx/releases/tag/v0.6.0
[0.5.2]: https://github.com/richarc/qx/releases/tag/v0.5.2
[0.5.1]: https://github.com/richarc/qx/releases/tag/v0.5.1
[0.5.0]: https://github.com/richarc/qx/releases/tag/v0.5.0
[0.4.0]: https://github.com/richarc/qx/releases/tag/v0.4.0
[0.3.0]: https://github.com/richarc/qx/releases/tag/v0.3.0
[0.2.5]: https://github.com/richarc/qx/releases/tag/v0.2.5
[0.2.4]: https://github.com/richarc/qx/releases/tag/v0.2.4
[0.2.3]: https://github.com/richarc/qx/releases/tag/v0.2.3
[0.2.2]: https://github.com/richarc/qx/releases/tag/v0.2.2
[0.2.1]: https://github.com/richarc/qx/releases/tag/v0.2.1
[0.2.0]: https://github.com/richarc/qx/releases/tag/v0.2.0
[0.1.0]: https://github.com/richarc/qx/releases/tag/v0.1.0
