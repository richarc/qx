# Qx Architecture Review

Scope: `lib/qx/**/*.ex` only. 34 source files, 20,679 LOC total.

`mix xref graph --format stats` (raw):

```
Tracked files: 34 (nodes)
Compile dependencies: 0 (edges)
Exports dependencies: 15 (edges)
Runtime dependencies: 58 (edges)
Cycles: 1
```

Cycle (`mix xref graph --format cycles`):

```
Cycle of length 4:
  lib/qx/draw/tables.ex
  lib/qx/register.ex (export)
  lib/qx/qubit.ex
  lib/qx/draw.ex
```

Top fan-in: `errors.ex` (11), `quantum_circuit.ex` (9), `math.ex` (7), `validation.ex` (5), `format.ex` (5). Top fan-out: `register.ex` (8), `simulation.ex` (7), `hardware.ex` (7), `draw.ex` (7).

There are **0 compile-time dependencies** between project files — that is a strong signal: every cross-module reference is either a runtime call or an export. Recompilation graph is minimal.

## 1. Module structure & layering

**MED — `lib/qx/qubit.ex:154`** — `Qx.Qubit` (domain layer) `defdelegate`s `draw_bloch/2` to `Qx.Draw`, creating the only upward edge from a domain module into the visualization layer.
Why it matters: forces the Qubit module to know about Draw at compile time and produces the 4-cycle `tables → register → qubit → draw → tables`. Any future Draw refactor (e.g. extracting a `qx_draw` sibling library) is blocked while this lives in `Qx.Qubit`.
Fix: drop the `defdelegate` from `Qx.Qubit`; require callers to use `Qx.draw_bloch/2` (already defined in `Qx`) or `Qx.Draw.bloch_sphere/2` directly.

**MED — `lib/qx/draw/tables.ex:56,64` & `lib/qx/draw.ex:251`** — `Qx.Draw.Tables.render/2` pattern-matches on `%Qx.Register{}` (and Draw docstrings reference `Qx.Register`), so the Draw layer reaches sideways into the calc-mode `Register` domain rather than accepting only the lower-common-denominator `Nx.Tensor`.
Why it matters: closes the cycle above and couples Draw to Register's struct shape. If Register's field names change, Draw breaks.
Fix: have callers pass `register.state` (an `Nx.Tensor`), or move the `%Register{}` unwrap into a tiny `Qx.Register.to_state/1` helper that Tables calls — keeping the struct knowledge inside Register.

**LOW — clean elsewhere.** Calc → CalcFast is a thin facade (Calc has `@moduledoc false` and just forwards). Operations → QuantumCircuit/Validation is correct direction. Simulation → Calc/Gates/Math is correct. Hardware → OpenQASM/Portal/Ibm/ResultBuilder is correct. Export/OpenQASM is internally clean (`parser → ast → lowering → quantum_circuit`). No lower-layer Nx kernel reaches up into Simulation or Operations.

## 2. Module size & cohesion

Top 5 by LOC:

| LOC  | File                                  | Note |
|-----:|---------------------------------------|------|
| 1243 | `lib/qx.ex`                           | Public-API facade — mostly `defdelegate` + docstrings. Cohesive. |
| 917  | `lib/qx/operations.ex`                | 36 gate/measurement/tap functions, one concern. Cohesive. |
| 850  | `lib/qx/register.ex`                  | Multi-qubit calc-mode struct + 28-gate behaviour impl + tensor product. Cohesive. |
| 826  | `lib/qx/qubit.ex`                     | Single-qubit calc-mode (32 functions: constructors + gates + measurements + Bloch + Draw delegate). Cohesive, but see §1 (Draw delegate). |
| 750  | `lib/qx/export/openqasm/parser.ex`    | OpenQASM 3 lexer+parser. Cohesive (parsing is naturally large). |

No size-driven cohesion problem found — every large file owns a single concept. None mixes unrelated concerns.

## 3. Public API boundary

**LOW — `examples/tutorials/systems_of_qubits_and_entanglement.livemd:534`** — Livebook tutorial calls `Qx.StateInit.w_state(3)`. `Qx.StateInit` carries a public `@moduledoc` (not `@moduledoc false`) yet is **not** listed in `lib/qx.ex`'s top-of-module module list, which advertises `Qx.Math`, `Qx.QuantumCircuit`, `Qx.Operations`, `Qx.Simulation`, `Qx.Draw`, `Qx.Export.OpenQASM` as the public surface.
Why it matters: a tutorial uses a module as if it were public, but the public-API enumeration omits it. Either ratify it or hide it — the current state risks a silent breaking-change miss.
Fix: decide. Either (a) add `Qx.StateInit` to the `Qx` moduledoc's module list and treat it as public surface (CHANGELOG-tracked), or (b) keep it internal — mark `Qx.StateInit` `@moduledoc false` and replace the tutorial call with `Qx.Register.new(3) |> ...`.

**Clean elsewhere.** README only uses `Qx.*` top-level helpers, `Qx.QuantumCircuit`, `Qx.Hardware.*`, `Qx.Hardware.Config`. No example dives into `Qx.Calc`, `Qx.CalcFast`, `Qx.Gates`, `Qx.Format`, `Qx.ResultBuilder`, `Qx.Draw.SVG.Circuit` — all of which carry `@moduledoc false`. Internal-module hygiene is good.

## 4. Behaviour usage

**MED — `lib/qx/behaviours/quantum_state.ex` has exactly one implementor (`Qx.Register`)** — `lib/qx/register.ex:47` is the only `@behaviour Qx.Behaviours.QuantumState` in the codebase.
Why it matters: a behaviour with a single implementor is dead abstraction overhead. The moduledoc itself describes "Qx.QuantumCircuit via Qx.Operations" as a second consumer but it isn't actually wired (Operations is a module-of-functions, not a struct that implements the behaviour). And `Qx.Qubit` is explicitly excluded by docstring (lines 12–17).
Fix: either (a) make `Qx.QuantumCircuit` a real `@behaviour Qx.Behaviours.QuantumState` implementor (its instruction-adding shape matches `(state, qubit_index) :: state`), or (b) accept the single-implementor reality, drop the behaviour, and inline the spec as a moduledoc convention table on `Qx.Register`. Right now it's neither — type-checker leverage is zero and the behaviour drifts as Register grows.

## 5. Library hygiene

**Clean.** No `use Application`, no `GenServer.start_link`, no `Agent.start_link`, no `Task.start`/`Task.async` anywhere in `lib/qx/`. `mix.exs` has no `mod:` start callback (no `def start(` in lib/). The only `Application` references are:

- `lib/qx.ex:1185` — `Application.spec(:qx, :vsn)` — version readout, no process.
- `lib/qx/simulation.ex:21` — `Application.compile_env(:qx, :assert_norm, false)` — compile-time config, no process.

Both are correct library uses. Qx is a clean pure-data library — no rogue processes, no supervision required of callers.

## 6. Error boundary

**HIGH — `lib/qx/validation.ex:127,152,165`** — Three `Qx.Validation` helpers still raise raw `ArgumentError`:
- `validate_qubits_different!/1` — line 127
- `validate_state_shape!/2` — line 152
- `validate_parameter!/1` — line 165

Each has an inline comment naming Iron Law #7 as the reason to convert (e.g. line 146 "(Iron Law #7 follow-on: route through `Qx.StateShapeError`.)") — TODO markers that never landed.
Why it matters: `validate_state_shape!` is called from `QuantumCircuit.initialize/2` and `validate_qubits_different!` from `Operations` — both are public-API entry points. Public callers can't distinguish a Qx misuse from any other library's `ArgumentError`.
Fix: route line 152 through the existing `Qx.StateShapeError` (`errors.ex:107`); add typed errors (or reuse `Qx.OptionError`) for the other two; remove the `raise ArgumentError` sites.

**MED — `lib/qx/register.ex:92,100,163,168,510,538,569,657,680,704,746`** — `Qx.Register` raises `ArgumentError` in 11 places: empty-qubit-list, invalid-qubit-in-list, empty-basis-list, basis-not-0-1, duplicate control/target indices (6 sites), distinct-qubit checks.
Why it matters: Register is documented in the README and Qx moduledoc as a calc-mode entry point; these errors are reachable by ordinary public use.
Fix: replace with `Qx.QubitIndexError` (for index/duplicate cases) and `Qx.OptionError`/`Qx.StateShapeError` for the empty/invalid-input cases. Most can route through existing `Qx.Validation.validate_qubit_indices!` / `validate_qubits_different!` (after those are converted per the HIGH finding above).

**MED — `lib/qx/draw/svg/circuit.ex:111,122,126,161,173`** — `Qx.Draw.SVG.Circuit` (marked `@moduledoc false`, but reached transitively via the public `Qx.Draw.circuit/2`) raises `ArgumentError` in 5 sites: >20 qubits, invalid qubit index, invalid classical bit, unsupported gate type, invalid qubit index for gate.
Fix: raise `Qx.QubitCountError`, `Qx.QubitIndexError`, `Qx.ClassicalBitError`, `Qx.GateError` — all already exist in `lib/qx/errors.ex`.

**MED — `lib/qx/qubit.ex:290`** — `Qx.Qubit.from_basis/1` raises `ArgumentError` on bad basis input. Public API.
Fix: route through `Qx.Validation` to raise `Qx.OptionError` (or a new `Qx.BasisError`).

**LOW — `lib/qx/draw.ex:98,140,182,231`** — Four `raise ArgumentError, "Unsupported format: #{format}"` sites for the `:format` option.
Fix: `raise Qx.OptionError, {:format, format, "Expected :svg or :vega_lite."}`.

**LOW — `lib/qx/export/openqasm.ex:177`** — `to_qasm` raises `ArgumentError` for invalid OpenQASM version.
Fix: `raise Qx.OptionError, {:version, version, "Expected 2 or 3."}`.

**Clean elsewhere.** `Qx.Operations`, `Qx.Simulation`, `Qx.QuantumCircuit`, `Qx.Hardware`, and the OpenQASM AST/parser/lowering pipeline all use typed `Qx.*Error` consistently. Counts: 27 `ArgumentError` / `raise "..."` sites vs. 27 typed `Qx.*Error` raises — the untyped half is concentrated in Qubit (1), Register (11), Validation (3), Draw (4), Draw.SVG.Circuit (5), Export.OpenQASM (1), with two additional ones in `hardware.ex:145-146` that re-raise pre-built exceptions (legitimate).

---

## Architecture score

| Category                       | Weight | Score | Notes |
|--------------------------------|------:|-----:|-------|
| Clean layering                 |    35 |   28 | One real cycle (tables↔register↔qubit↔draw); one upward delegate (Qubit→Draw). Zero compile-deps overall is excellent. |
| Module size & cohesion         |    20 |   19 | All large modules are cohesive; no mixed-concern god module. |
| Public API discipline          |    20 |   17 | Internal modules consistently `@moduledoc false`. `Qx.StateInit` ambiguity (public moduledoc, omitted from Qx's module list, used by a tutorial) is the only smudge. |
| Behaviour consistency          |    10 |    5 | `Qx.Behaviours.QuantumState` has exactly one implementor; the docstring's stated second consumer (`QuantumCircuit`) is not wired up. |
| Library hygiene / no processes |    10 |   10 | Zero processes, zero `use Application` start callback, clean. |
| Error-type discipline          |     5 |    3 | 27 untyped `ArgumentError` sites, including 3 inside `Qx.Validation` flagged in-source as Iron Law #7 violations. |

**Total: 82 / 100**
