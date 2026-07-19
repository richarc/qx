# Qx Public API Consistency Review

Scope: `lib/qx/**/*.ex`, `README.md`, `examples/tutorials/*.livemd` headers,
representative `test/qx/*_test.exs`. The 27 raw `ArgumentError` leaks and the
`tables ↔ register ↔ qubit ↔ draw` cycle from `arch-review.md` are factored
in but not re-investigated.

## 1. Headline verdict

The Qx surface is **mostly clean but the declared public surface in the Iron
Laws is too narrow** to match what the README and tutorials actually teach.
`Qx.Qubit`, `Qx.Register`, `Qx.StateInit`, and `Qx.Patterns` are all
prominent in the README's "Quick Start" and every tutorial's `alias` header,
yet only `Qx.Behaviours.*` and the five core modules are listed as the
public surface — the gap is the dominant source of inconsistency. Inside
the listed surface, naming and arg-order are tight (subject-first
everywhere, predicates end in `?`, bang-variants follow convention).
Encapsulation is good for `Qx.Calc*` and `Qx.Gates` (only reached from
public modules, all `@moduledoc false`), but `Qx.Draw` is a leaky facade:
its five submodules carry real `@moduledoc`s, are aliased from `Qx.Draw`,
and four call sites in `Qx.Draw` itself raise raw `ArgumentError`. The
biggest user-confusion landmine is `Qx.bell_state/1` vs
`Qx.StateInit.bell_state/2` (and the `ghz_state` twin): same name, same
module-level position, **different return type** (circuit vs state
vector).

**API consistency score: 72 / 100**

| Axis                          | Weight | Score | Notes |
|-------------------------------|-------:|------:|-------|
| Visibility hygiene            |     25 |    16 | Every module has explicit `@moduledoc`. But Iron-Laws surface list omits four de-facto-public modules (`Qubit`, `Register`, `StateInit`, `Patterns`) and includes `Qx.Math` only in `Qx`'s moduledoc, not Iron Laws. Five `Qx.Draw.*` submodules are de-facto public. |
| Encapsulation / escape paths  |     20 |    13 | `Qx.Calc`/`Qx.Gates`/`Qx.Format`/`Qx.ResultBuilder` are correctly `@moduledoc false` and only reached from inside the library. But `Qx.Register` reaches `Qx.Calc`/`Qx.Gates`/`Qx.Format` directly (many call sites), and `Qx.Draw` raises raw `ArgumentError` from public entry points. |
| No duplicate paths            |     15 |     9 | Twin `bell_state` / `ghz_state` (circuit vs state) is the worst case. Three layered paths for "single-qubit H": `Qx.h/2`, `Qx.Operations.h/2`, `Qx.Register.h/2`, `Qx.Qubit.h/1`. Documented but not flattened. |
| Arg-order consistency         |     10 |    10 | Subject (`circuit` / `register` / `state` / `qubit`) is arg 1 everywhere. No offenders. |
| Naming consistency            |     10 |     9 | Predicates end in `?` (`valid?`, `measured?`, `unitary?`); no `is_*` defs (only guards). `measure_x/y/z` symmetric. Mild verb/noun blip: `Qx.draw/2` (verb) vs `Qx.histogram/2` (noun). |
| Return-shape consistency      |     10 |     7 | `to_qasm/1` raises but `from_qasm/1` returns `{:ok, _} \| {:error, _}`. `Qx.run/2` docstring says "map" but returns a `%Qx.SimulationResult{}` struct. |
| Delegation principledness     |     10 |     8 | `Qx` re-exports 54 functions cleanly; gaps are mostly principled (`Qx.QuantumCircuit.set_state` is internal-ish, `Qx.Operations.barrier/2` is the one accidental omission given that `Qx.barrier_all` exists). |

## 2. Findings

| Sev  | Category      | Location | Issue | Suggested fix |
|------|---------------|----------|-------|---------------|
| CRIT | duplication   | `lib/qx.ex:1132` & `lib/qx/state_init.ex:271` | `Qx.bell_state/1` returns `Qx.QuantumCircuit.t()`, `Qx.StateInit.bell_state/2` returns `Nx.Tensor.t()` — same name, same module-as-noun position, different return type. Same shape at `lib/qx.ex:1155` vs `lib/qx/state_init.ex:341` for `ghz_state`. | Rename one side. Either `Qx.StateInit.bell_state_vector/2` / `ghz_state_vector/2`, or move circuit-recipes to `Qx.bell_circuit/1` / `Qx.ghz_circuit/1`. Today's `## See Also` cross-refs paper over the type collision. |
| HIGH | visibility    | Iron Laws block in `CLAUDE.md` (declared surface) vs `lib/qx/qubit.ex:1`, `lib/qx/register.ex:1` | `Qx.Qubit` and `Qx.Register` are taught as primary user surface in README (lines 61–219) and every `examples/tutorials/*.livemd` `alias` header, but are NOT in the Iron-Laws declared public surface. A breaking change here would not trip Iron Law #6. | Add `Qx.Qubit`, `Qx.Register`, `Qx.StateInit`, `Qx.Patterns` to the Iron-Laws declared public surface in `CLAUDE.md` so semver discipline applies. |
| HIGH | visibility    | `lib/qx/draw.ex:1` plus `lib/qx/draw/svg/{bloch,charts,circuit}.ex`, `lib/qx/draw/{tables,vega_lite}.ex` | `Qx.Draw` is not in the declared public surface but is the only documented way to reach `draw_state`, `histogram`, `circuit`. Five Draw sub-modules have real public-looking `@moduledoc` even though they are escape paths reachable through `Qx.Draw`. | Either add `Qx.Draw` to the declared public surface (matching how it's used) and mark the five submodules `@moduledoc false`; or replace `Qx.Draw`'s usage in README with the seven `Qx.draw*` delegates and mark `Qx.Draw` itself `@moduledoc false`. |
| HIGH | encapsulation | `lib/qx/draw.ex:98`, `:140`, `:182`, `:231` | Four call sites raise raw `ArgumentError "Unsupported format: …"` from a public entry point. Iron Law #7 disallows raw `ArgumentError` at the public boundary. | Convert to a typed `Qx.OptionError` via `Qx.Validation` (or add a dedicated `Qx.DrawError`) at all four sites. |
| HIGH | encapsulation | `lib/qx/draw.ex:59-60` (alias chain) → `lib/qx/draw/svg/circuit.ex:1` | Per `arch-review.md`, `Qx.Draw.circuit/2` lets `Qx.Draw.SVG.Circuit.render/2` exceptions bubble unchanged. Same delegation pattern applies to `bloch_sphere/2` → `Qx.Draw.SVG.Bloch.render/2`, `plot/2`/`plot_counts/2`/`histogram/2` → `Qx.Draw.VegaLite` / `Qx.Draw.SVG.Charts`, and `state_table/2` → `Qx.Draw.Tables.render/2`. Any internal raise is a public leak. | Wrap each delegate to convert internal raises to typed `Qx.*Error`s, or rescue + re-raise in `Qx.Draw`. |
| HIGH | encapsulation | `lib/qx/register.ex:234, 257, 280, 303, 326, 349, 372, 400, 423, 446, 474, 514, 573, 588, 601, 614, 627, 640, 660, 683, 708, 727, 750, 811, 816, 822` | `Qx.Register` (de-facto public per README §"Multi-Qubit Registers") reaches into `Qx.Calc` (`@moduledoc false`), `Qx.Gates` (`@moduledoc false`), and `Qx.Format` (`@moduledoc false`) from ~25 call sites. The escape paths themselves are fine (internal), but they cement `Qx.Register`'s status as public — confirm it via Finding HIGH-visibility above. | Either promote `Qx.Register` to declared-public (it's already used like that), or hide it (`@moduledoc false`) and rewrite tutorials to use only `Qx.create_circuit + Qx.run`. The current "Calculation Mode" doc surface won't survive a `Qx.Register` revisit otherwise. |
| HIGH | encapsulation | `lib/qx/register.ex:92, 100, 163, 168, 510, 538, 569, 657, 680, 704, 746`; `lib/qx/qubit.ex:290` | 12 raw `ArgumentError` raises in `Qx.Register` and one in `Qx.Qubit` — extending the 27 ArgumentError leaks from `arch-review.md`. Already in scope for ROADMAP v0.8.1; flagged here for completeness of the public-API picture, not for re-investigation. | (See `arch-review.md`.) |
| MED  | duplication   | `lib/qx/math.ex:225` | `Qx.Math.basis_state/2` is `@deprecated` to `Qx.StateInit.basis_state/3`. Confirmed only call site is internal — but the deprecation window is open in 0.8.x; planned removal needs a 0.9 entry. | Add ROADMAP v0.9 item: "remove `Qx.Math.basis_state/2`" and a CHANGELOG line at removal. |
| MED  | duplication   | `lib/qx/qubit.ex:372`, `lib/qx/register.ex:230`, `lib/qx/operations.ex:35`, `lib/qx.ex:125` | `h/?` exists at four levels: `Qx.Qubit.h/1` (calc-single), `Qx.Register.h/2` (calc-multi), `Qx.Operations.h/2` (circuit), `Qx.h/2` (delegate). All return the correct shape for their subject — defensible — but a new user hitting "which `h` do I call?" must internalize the calc/circuit + single/multi grid. The `Qx` moduledoc + README cover this, but it's the largest cognitive load in the API. | Keep, but make `Qx`'s moduledoc lead with a one-paragraph "Which `h` am I calling?" decision tree. The `Qx.Behaviours.QuantumState` doc (`lib/qx/behaviours/quantum_state.ex:13`) already notes `Qx.Qubit` deliberately doesn't implement the behaviour — pull that callout up into `Qx`'s moduledoc. |
| MED  | return-shape  | `lib/qx.ex:854-861` (docstring), `lib/qx/simulation.ex:130, :160` | `Qx.run/2` docstring describes "A map containing: …" — but `Qx.Simulation.run/2` returns `%Qx.SimulationResult{}` (confirmed by `test/qx/result_builder_test.exs:10` and `test/qx/simulation_renormalization_test.exs:162, :176`). Works because struct access is map-shaped, but the typespec and docs claim a different type. | Replace the prose with "Returns a `Qx.SimulationResult.t()`. See `Qx.SimulationResult` for fields and helpers." Update `@spec` accordingly. |
| MED  | return-shape  | `lib/qx/export/openqasm.ex:156, :408, :419, :460, :508` | `to_qasm/1` returns raw `String.t()` and raises on bad version. `from_qasm/1` returns `{:ok, _} \| {:error, _}` with `from_qasm!/1` as the raising twin. No `to_qasm!/1`; no `from_qasm/1` returning raw. The pair is asymmetric. | Either add `to_qasm/1` → `{:ok, _} \| {:error, _}` + `to_qasm!/1`, or document the asymmetry. (Hex: `to_qasm` failure modes are limited to version + unsupported instruction, so the asymmetry is defensible — document it.) |
| MED  | delegation    | `lib/qx/operations.ex:598` (`barrier/2`) | `Qx.barrier_all/1` and `/2` are delegated, but `Qx.barrier/2` (a single barrier spanning a specific qubit list, the only-arity in `Qx.Operations`) is NOT exposed on `Qx`. Likely accidental — the `_all` form is exposed, the basic form isn't. | Add `defdelegate barrier(circuit, qubits), to: Operations` in `lib/qx.ex`. |
| MED  | duplication   | `lib/qx/state_init.ex:341` & `lib/qx/patterns.ex:373` | `Qx.StateInit.ghz_state(n)` and `Qx.Patterns.ghz_state_circuit(n)` are both general-n. `Qx.ghz_state/1` delegates to the circuit form with default 3. Three names for one concept. | Document that `Qx.ghz_state/1` is the user-facing entry; mark `Qx.Patterns.ghz_state_circuit/1` `@doc false`-or-deprecate. Pair with the rename in CRIT-duplication. |
| LOW  | visibility    | `lib/qx/validation.ex:1` | Public moduledoc with extensive examples (`validate_qubit_index!` etc.) — but `Qx.Validation` is documented in `arch-review.md` as the internal validation hub. Currently used directly by `Qx.QuantumCircuit` (line 54, 95, 113, etc.) and is helpful for downstream library authors. | Decide: keep public (and add to declared surface), or mark `@moduledoc false` (it's an internal helper and not in any tutorial). Lean: keep public for downstream extension, add to declared surface. |
| LOW  | visibility    | `lib/qx/export/openqasm/{ast,codegen,expr,lowering,parser}.ex` | All five have real `@moduledoc`s, but `arch-review.md` cycle analysis treats them as the OpenQASM internals. None appear in README or tutorials; all are reached only through `Qx.Export.OpenQASM.{to_qasm,from_qasm}`. | Mark all five `@moduledoc false`. Keep the AST module's prose as a `# Internal AST shape` comment in `Lowering` (the only legitimate documentation audience). |
| LOW  | visibility    | `lib/qx/math.ex:1` | `Qx.Math` is named in `Qx`'s moduledoc (line 36) but missing from Iron-Laws declared surface. It's used directly by user code (probabilities, normalize, kron). | Add `Qx.Math` to the Iron-Laws declared surface. |
| LOW  | naming        | `lib/qx.ex:979` (`draw/2`), `:1028` (`histogram/2`), `:1065` (`draw_bloch/2`), `:1101` (`draw_state/2`), `:997` (`draw_counts/2`) | The `Qx.draw*` family mixes verb-first (`draw`, `draw_counts`, `draw_bloch`, `draw_state`) with the lone noun-only `histogram`. Both forms accept a result and return a chart — they're the same conceptual operation. | Rename `histogram/2` → `draw_histogram/2` (or alias). |
| LOW  | naming        | `lib/qx/quantum_circuit.ex:310` (`reset/1`) | Already noted in the docstring: this clears the entire circuit, not a qubit; will need rename when mid-circuit qubit reset lands (ROADMAP v0.9). | Tracked in docstring; no change today. |
| LOW  | docs-drift    | `lib/qx.ex:854-861` | (See MED return-shape above — counted once.) | (See above.) |
| LOW  | encapsulation | `lib/qx/draw/svg/charts.ex:49`, `lib/qx/draw/tables.ex:104-105` | Inside the Draw sub-implementations, calls to `Qx.Format.*` (`@moduledoc false`) — fine because the caller is itself `@moduledoc false` after the fix above; flagged as a confirmation that today the call chain `Qx.draw → Qx.Draw.plot → Qx.Draw.SVG.Charts → Qx.Format` traverses two layers of would-be-private modules with public moduledocs. | Resolves automatically when the `Qx.Draw.SVG.*` and `Qx.Draw.Tables` modules are marked `@moduledoc false`. |

## 3. Per-module `@moduledoc` audit

`Declared` reflects the Iron-Laws block in `CLAUDE.md`:
`Qx`, `Qx.QuantumCircuit`, `Qx.Operations`, `Qx.Simulation`,
`Qx.SimulationResult`, `Qx.Behaviours.*`.

| Module                                | `@moduledoc` | Declared | Verdict |
|---------------------------------------|--------------|:--------:|---------|
| `Qx`                                  | real         | Y        | keep |
| `Qx.QuantumCircuit`                   | real         | Y        | keep |
| `Qx.Operations`                       | real         | Y        | keep |
| `Qx.Simulation`                       | real         | Y        | keep |
| `Qx.SimulationResult`                 | real         | Y        | keep |
| `Qx.Behaviours.QuantumState`          | real         | Y        | keep |
| `Qx.Qubit`                            | real         | N        | **promote to public** (taught in README §"Calculation Mode", every tutorial alias) |
| `Qx.Register`                         | real         | N        | **promote to public** (same reason) |
| `Qx.StateInit`                        | real         | N        | **promote to public** (used by tutorial `quantum_algorithms.livemd`; see arch-review LOW finding) |
| `Qx.Patterns`                         | real         | N        | **promote to public** (added in v0.8 per ROADMAP; named in `Qx`'s moduledoc, exposed via delegates) |
| `Qx.Math`                             | real         | N        | **promote to public** (named in `Qx`'s moduledoc; user-facing for state inspection) |
| `Qx.Validation`                       | real         | N        | **decide** — keep public for downstream extension, or mark `@moduledoc false` and stop documenting examples |
| `Qx.Draw`                             | real         | N        | **promote to public** OR collapse into `Qx`-only — pick one (see HIGH finding) |
| `Qx.Draw.SVG.Bloch`                   | real         | N        | **mark `@moduledoc false`** (internal renderer; access through `Qx.draw_bloch/2`) |
| `Qx.Draw.SVG.Charts`                  | real         | N        | **mark `@moduledoc false`** (same) |
| `Qx.Draw.SVG.Circuit`                 | real         | N        | **mark `@moduledoc false`** (same; the inner `CircuitDiagram` is already `false`) |
| `Qx.Draw.Tables`                      | real         | N        | **mark `@moduledoc false`** (same) |
| `Qx.Draw.VegaLite`                    | real         | N        | **mark `@moduledoc false`** (same) |
| `Qx.Export.OpenQASM`                  | real         | N        | **promote to public** (named in `Qx`'s moduledoc; primary hardware export entry) |
| `Qx.Export.OpenQASM.AST`              | real         | N        | **mark `@moduledoc false`** (internal node-shape doc; relocate prose into `Lowering` comments) |
| `Qx.Export.OpenQASM.Codegen`          | real         | N        | **mark `@moduledoc false`** |
| `Qx.Export.OpenQASM.Expr`             | real         | N        | **mark `@moduledoc false`** |
| `Qx.Export.OpenQASM.Lowering`         | real         | N        | **mark `@moduledoc false`** |
| `Qx.Export.OpenQASM.Parser`           | real         | N        | **mark `@moduledoc false`** |
| `Qx.Hardware`                         | real         | N        | **promote to public** (named in README; primary entry for IBM execution) |
| `Qx.Hardware.Config`                  | real         | N        | **promote to public** (required to call `Qx.Hardware.run/3`) |
| `Qx.Hardware.Ibm`                     | real         | N        | **mark `@moduledoc false`** (HTTP client; not for direct use) |
| `Qx.Hardware.Portal`                  | real         | N        | **mark `@moduledoc false`** (same) |
| `Qx.Error`                            | real         | N        | keep public (base error; user catches it) |
| `Qx.QubitIndexError`                  | real         | N        | keep public (Iron Law #7 requires users see these typed errors) |
| `Qx.StateShapeError`                  | real         | N        | keep public (same) |
| `Qx.MeasurementError`                 | real         | N        | keep public (same) |
| `Qx.ConditionalError`                 | real         | N        | keep public (same) |
| `Qx.ClassicalBitError`                | real         | N        | keep public (same) |
| `Qx.GateError`                        | real         | N        | keep public (same) |
| `Qx.OptionError`                      | real         | N        | keep public (same) |
| `Qx.QubitCountError`                  | real         | N        | keep public (same) |
| `Qx.QasmParseError`                   | real         | N        | keep public (raised by `from_qasm/1`) |
| `Qx.QasmUnsupportedError`             | real         | N        | keep public (same) |
| `Qx.Hardware.NoMeasurementsError`     | real         | N        | keep public |
| `Qx.Hardware.ExecutionError`          | real         | N        | keep public |
| `Qx.Hardware.ConfigError`             | real         | N        | keep public |
| `Qx.Calc`                             | `false`      | N        | keep `false` |
| `Qx.CalcFast`                         | `false`      | N        | keep `false` |
| `Qx.Format`                           | `false`      | N        | keep `false` |
| `Qx.Gates`                            | `false`      | N        | keep `false` |
| `Qx.ResultBuilder`                    | `false`      | N        | keep `false` |

No modules lacked an `@moduledoc` at all — visibility-hygiene at that
baseline is clean.

## 4. Top 5 simplifications (ordered by user impact)

### S1. Rename the twin `bell_state` / `ghz_state` to remove the type collision

`lib/qx.ex:1132, :1155` vs `lib/qx/state_init.ex:271, :341`. Same name,
different module, different return type (circuit recipe vs state vector).
A new user reading `Qx.bell_state()` and `Qx.StateInit.bell_state()`
expects one to be a thin wrapper of the other — neither is. Rename the
state-vector side: `Qx.StateInit.bell_state_vector/2`,
`Qx.StateInit.ghz_state_vector/2`. CHANGELOG + deprecate the old names
for one minor. Keep `Qx.bell_state/1` / `Qx.ghz_state/1` as the canonical
circuit-recipe path (it's already in the README quick-start).

### S2. Expand the Iron-Laws declared public surface to match reality

`CLAUDE.md` (Iron Law #6). Add `Qx.Qubit`, `Qx.Register`, `Qx.StateInit`,
`Qx.Patterns`, `Qx.Math`, `Qx.Hardware`, `Qx.Hardware.Config`,
`Qx.Export.OpenQASM`, `Qx.Draw` to the list. Mark the five
`Qx.Draw.*` submodules, the five `Qx.Export.OpenQASM.*` submodules, and
`Qx.Hardware.{Ibm,Portal}` as `@moduledoc false`. Without this, a
breaking change in `Qx.Qubit` does not trip semver discipline even
though the README quick-start would break.

### S3. Stop raw `ArgumentError` leaking from `Qx.Draw` public entry points

`lib/qx/draw.ex:98, :140, :182, :231`. Four call sites raise raw
`ArgumentError "Unsupported format: …"` — exactly the leak pattern Iron
Law #7 prohibits. Route through `Qx.Validation` and either re-use
`Qx.OptionError` (the `:format` option is the invalid one) or add a
`Qx.DrawError`. Also wrap the `Qx.Draw.SVG.*` and `Qx.Draw.Tables`
internal raises behind a rescue-and-re-raise in `Qx.Draw` so the
delegation arrows in §3 don't keep leaking unchanged exceptions.

### S4. Add `Qx.barrier/2` to close the `Qx` re-export gap

`lib/qx/operations.ex:598`. `Qx.barrier_all/1, /2` exist; `Qx.barrier/2`
does not, even though it's the single-instruction primitive that
`_all` wraps. Likely an oversight when `Qx.Patterns` was added. One
`defdelegate` line in `lib/qx.ex`.

### S5. Fix the `Qx.run/2` docstring to say struct, not map

`lib/qx.ex:854-861`. Replace "A map containing: `:probabilities`, …"
with "Returns a `Qx.SimulationResult.t()`. See `Qx.SimulationResult`
for fields and helpers." Update the `@spec` to
`Qx.SimulationResult.t()`. Currently the docstring contradicts the
tests (`test/qx/result_builder_test.exs:10`,
`test/qx/simulation_renormalization_test.exs:162, :176`) which assert
`%Qx.SimulationResult{}` — the type *is* the struct, the docstring is
a leftover from a pre-struct era.
