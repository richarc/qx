# README.md audit against released v0.10.0

Audited: `README.md` at `main` (== tag `v0.10.0`, Hex release 2026-07-04).
Method: every code example extracted and checked against `lib/`; behaviour
claims executed with `mix run` where feasible; prose cross-checked against
`CHANGELOG.md [0.10.0]` and `mix.exs`.

Verification evidence is inline per finding. Everything not listed below was
checked and found correct — notably: the teleportation seed-42 step transcript
(lines 220–231) reproduces byte-for-byte; all gate facades in the feature list
exist (`h x y z s sdg t rx ry rz cx cy cz cp crx cry crz swap iswap u cswap
ccx`); `Qx.Patterns` helpers and their range forms exist; `measure_x/y/z/3`
exist; all `Qx.Hardware` entry points exist at the stated arities
(`run/3`, `submit_qasm/3`, `transpile/3`, `list_backends/2`, `cancel/3`);
`Qx.Hardware.Config.from_env!/1` reads exactly the six `QX_*` env vars shown;
`Config.new/1` accepts the shown keys; `Qx.Draw.Image` has `:svg`/`:title` and
`Qx.Draw.StateTable` has `:text`/`:markdown`/`:html` as the standalone table
claims; the three chart functions return `VegaLite.t()` and `draw_bloch`/
`draw_circuit` return `Qx.Draw.Image` as stated; `vega_lite` and `kino` are
optional deps as described; `Qx.MissingDependencyError`, `Qx.QasmParseError`
(`:line`, `:column`, `:snippet`) and `Qx.QasmUnsupportedError` exist; the
calc-mode migration snippet still runs (`Qx.Qubit` demoted but working); max
qubits is 20 (`Qx.QubitCountError` at 21); default shots is 1024; string
counts keys are used in the Quick Start and Bell examples; all four in-page
section anchors resolve (`#performance--acceleration`,
`#livebook-acceleration-snippets`, `#step-through-a-circuit`,
`#exla--nvidia-gpu-cuda`); no references remain to `format: :svg`,
`Qx.histogram`, `plot_counts`, `bloch_sphere`, `Qx.Remote`, or the
`StateInit.bell_state` aliases; `ROADMAP.md` and `RELEASE.md` exist.

Summary: **8 WRONG, 3 STALE, 4 COSMETIC**.

---

## WRONG — factually incorrect for 0.10.0

### W1. `{:qx_sim, "~> 0.8.0"}` install form does not work (and is two minors stale)

- Lines: **32** (Installation), **48** (GitHub variant), **587** (EXLA CPU
  step 1), **681** (EMLX step 1)
- Quote (line 32): `{:qx_sim, "~> 0.8.0"}`
- Quote (line 48): `{:qx_sim, github: "richarc/qx", branch: "main"}`
- Why: the OTP app name is `:qx` (`mix.exs` line 6: `app: :qx`); only the Hex
  *package* is `qx_sim` (`package/0`, `name: "qx_sim"`). A dep keyed
  `:qx_sim` therefore breaks. Verified empirically:
  `Mix.install([{:qx_sim, "~> 0.8.0"}])` resolves and fetches but fails to
  compile — the dependency graph is wired under the wrong app name, so qx's
  own deps are not on its load path:
  `error: module Nx.Defn is not loaded ... lib/qx/qubit.ex:9`,
  `could not compile dependency :qx_sim`. `mix hex.info qx_sim` prints the
  canonical form: `Config: {:qx, "~> 0.10.0", hex: :qx_sim}`. The version is
  also stale (0.8.0 vs released 0.10.0).
- Fix: replace all four occurrences with `{:qx, "~> 0.10", hex: :qx_sim}`,
  and the GitHub variant with `{:qx, github: "richarc/qx", branch: "main"}`.

### W2. `Qx.bell_state() |> Qx.run()` cannot produce the shown counts

- Lines: **66–68** (Quick Start), **247–250** (Bell State example)
- Quote (66–68):
  ```
  iex> result = Qx.bell_state() |> Qx.run()
  iex> IO.inspect(result.counts)
  %{"00" => 512, "11" => 512}
  ```
  and (247–249): `result = Qx.bell_state() |> Qx.run(1000)` …
  `# => %{"00" => ~500, "11" => ~500}`
- Why: `Qx.bell_state/1` → `Patterns.bell_state_circuit/1` builds
  `QuantumCircuit.new(2)` — 2 qubits, **0 classical bits, no measurements**
  (`lib/qx/patterns.ex:304–308`). Verified: `Qx.bell_state() |> Qx.run()`
  returns `counts: %{}` (and `|> Qx.measure_all()` can't rescue it — it
  raises `Qx.ClassicalBitError: Classical bit index 0 out of range (0..-1)`).
  The follow-on `Qx.draw_counts(result)` (line 250) renders an empty chart.
  Line 71's `Qx.draw(result)` is fine — it plots probabilities.
- Fix: build the measured circuit explicitly, as the (correct) LiveBook
  example at lines 94–101 already does:
  `Qx.create_circuit(2, 2) |> Qx.h(0) |> Qx.cx(0, 1) |> Qx.measure(0, 0) |> Qx.measure(1, 1) |> Qx.run()`
  — or keep `Qx.bell_state()` but show `Qx.get_probabilities/1` instead of
  `result.counts`.

### W3. GHZ example shows list counts keys; 0.10.0 keys are strings

- Line: **264**
- Quote: `# => %{[0, 0, 0] => ~500, [1, 1, 1] => ~500}`
- Why: the headline 0.10.0 fix ("SimulationResult.counts keys are now the
  binary strings the docs always promised", CHANGELOG [0.10.0] Fixed).
  Verified: the exact circuit at lines 257–262 run for 1000 shots returns
  `%{"000" => 489, "111" => 511}`. This is the one counts example the
  counts-contract sweep missed.
- Fix: `# => %{"000" => ~500, "111" => ~500}`.

### W4. `from_qasm_function/1` example describes the pre-0.9.0 return shape; its compile recipe raises

- Lines: **461–473**
- Quote (464): `# source is an Elixir `def …` string:` and (472–473):
  ```elixir
  [{module, _bin}] = Code.compile_string("defmodule MyGates do\n  #{source}\nend")
  new_circuit = MyGates.bell(Qx.create_circuit(2), 0, 1)
  ```
- Why: since v0.9.0 (CHANGELOG Security), `source` is a **self-contained
  `defmodule Qx.Generated.<Name>_<hash> do … end`** and the result map gained
  a `:module` key (`lib/qx/export/openqasm.ex:450–460`). Verified output:
  `defmodule Qx.Generated.Bell_d0f2b402 do\n  def bell(circuit, a, b) do …`.
  Running the README recipe compiles the nested module
  `MyGates.Qx.Generated.Bell_d0f2b402` and then raises
  `UndefinedFunctionError: function MyGates.bell/3 is undefined or private`
  (verified). The pattern match on line 461 still succeeds (extra `:module`
  key is ignored), which makes the broken comment and recipe more misleading.
- Fix: match `{:ok, %{name: "bell", arity: 3, module: module_name, source: source}}`,
  say `source` is a self-contained `defmodule`, and compile with
  `[{module, _bin}] = Code.compile_string(source)` then
  `module.bell(Qx.create_circuit(2), 0, 1)`.

### W5. LiveBook `Mix.install` snippets pin `~> 0.6.0`

- Lines: **82** (Getting Started with LiveBook), **735**, **748**, **761**
  (all three acceleration snippets)
- Quote: `{:qx, "~> 0.6.0", hex: :qx_sim}`
- Why: the form is right (unlike W1) but the constraint installs 0.6.x —
  an API where the README's own snippets fail: no string counts keys, no
  `Qx.steps/2`, no `Qx.draw_circuit/2`, no `Qx.Draw.Image`/`StateTable`,
  no `measure_all` range forms. 0.10.0 is on Hex (verified with
  `mix hex.info qx_sim`).
- Fix: `{:qx, "~> 0.10", hex: :qx_sim}` in all four snippets.

### W6. `RemoteError` listed among exception types; it does not exist

- Line: **784**
- Quote: "Exception types include `QubitIndexError`, …, `QubitCountError`,
  and `RemoteError`."
- Why: `grep -rn RemoteError lib/` — no matches. `lib/qx/errors.ex` defines
  no such module; the hardware-side errors are
  `Qx.Hardware.NoMeasurementsError`, `Qx.Hardware.ExecutionError`, and
  `Qx.Hardware.ConfigError`. Rescuing `Qx.RemoteError` would itself raise a
  CompileError/UndefinedFunctionError for the module. (The other seven names
  on the line all exist; the try/rescue example at 776–782 runs as shown.)
- Fix: drop `RemoteError`; optionally mention `Qx.Hardware.ExecutionError`
  and the 0.9/0.10 additions (`QasmParseError`, `QasmUnsupportedError`,
  `MissingDependencyError`).

### W7. Requirements state "Nx 0.10+"; the floor is 0.12

- Line: **788**
- Quote: "Elixir 1.18+, Nx 0.10+, VegaLite 0.1+"
- Why: v0.9.0 raised the minimum to `{:nx, "~> 0.12"}` (CHANGELOG [0.9.0]
  Changed; `mix.exs` deps). A project holding nx at 0.10 cannot resolve
  qx_sim 0.10.0. (Elixir 1.18+ is correct. VegaLite is a separate stale
  issue — see S2.)
- Fix: "Elixir 1.18+, Nx 0.12+; optional VegaLite 0.1+ for the chart
  functions".

### W8. Footer says "Current version: 0.6.0"

- Line: **819**
- Quote: `Current version: 0.6.0`
- Why: released version is 0.10.0 (`mix.exs version: "0.10.0"`, tag
  `v0.10.0`, Hex). Verified `Qx.version()` returns `"0.10.0"`.
- Fix: `Current version: 0.10.0` — or delete the line/section; it has now
  been wrong across four releases, and the Hex badge at line 3 already shows
  the live version.

---

## STALE — outdated but not (or barely) false

### S1. Feature bullet still calls the backend service "QxServer"

- Line: **24**
- Quote: "Run circuits on real quantum hardware via QxServer, a standalone
  backend service…"
- Why: "QxServer" is the pre-`Qx.Hardware` name (last real appearance:
  CHANGELOG ~0.5 era, alongside the removed `Qx.Remote.Config`). The
  README's own hardware section (line 484) correctly says circuits are
  "transpiled through the qxportal service". No `QxServer` exists in `lib/`.
- Fix: "…via `Qx.Hardware` and the qxportal service, supporting IBM Quantum
  and other providers".

### S2. VegaLite listed as a hard requirement

- Line: **788** (same line as W7)
- Quote: "…, VegaLite 0.1+"
- Why: since 0.10.0 `vega_lite` is optional (`mix.exs`:
  `{:vega_lite, "~> 0.1", optional: true}`); only
  `draw/draw_counts/draw_histogram` need it, and they raise
  `Qx.MissingDependencyError` when absent — as the README itself explains at
  lines 413–414. Listing it under base requirements contradicts that.
- Fix: move to the optional list (see W7's suggested wording).

### S3. "Optional: EXLA 0.10+ or EMLX 0.2+"

- Line: **789**
- Quote: "Optional: EXLA 0.10+ or EMLX 0.2+ for acceleration"
- Why: EXLA 0.10 depends on Nx 0.10 and cannot coexist with the nx ~> 0.12
  floor (W7). The EXLA snippet at line 588 already says `{:exla, "~> 0.12"}
  # (match Qx's Nx version)`, which is the correct guidance.
- Fix: "Optional: EXLA 0.12+ (match the installed Nx) or EMLX for
  acceleration".

---

## COSMETIC

### C1. Quick Start shows a fabricated tensor inspect format

- Line: **63**
- Quote: `#Nx.Tensor<[0.5, 0.5]>`
- Why: real output (Nx 0.12, f32) is multi-line:
  `#Nx.Tensor<\n  f32[2]\n  [0.49999997, 0.49999997]\n>` (verified). The
  shorthand is readable but not something iex ever prints, and the 0.5s are
  idealised.
- Fix: either show the real output or drop the `iex>` framing so it reads as
  illustrative.

### C2. `Step.show/1` probabilities shown as exact 0.5

- Line: **348**
- Quote: `IO.inspect(state_info.probabilities)  # [{"|0⟩", 0.5}, {"|1⟩", 0.5}]`
- Why: actual values are f32-rounded (`{"|0⟩", 0.4999999701976776}`,
  verified). Structure and keys (`:state`, `:probabilities`, `:amplitudes`)
  are exactly right; only the numbers are idealised.
- Fix: annotate as approximate (`# ≈ [{"|0⟩", 0.5}, …]`) or show real values.

### C3. Typos in the intro paragraph

- Line: **9**
- Quote: "it is eventualy valuable" / "the memory cliff that would occurs
  around 30 qubits"
- Why: "eventualy" → "eventually"; "would occurs" → "occurs" (or "would
  occur").
- Fix: as above.

### C4. Contributing section instructs "open a Pull Request"

- Line: **803**
- Quote: "Commit and open a Pull Request"
- Why: harmless for external GitHub contributors, but the project's own
  development model is explicitly no-PR (workspace CLAUDE.md). Worth a
  conscious decision rather than an accident.
- Fix: keep for external contributors, or point at the issue tracker /
  contact instead.

---

## Cross-check against CHANGELOG [0.10.0]

| 0.10.0 change | README status |
|---|---|
| Counts keys now strings | Quick Start/Bell/teleport correct; GHZ example missed (**W3**) |
| Draw contract: one static type per function | Correctly described (lines 353, 364–368, 406–411) |
| `draw_circuit/2` facade returning `Qx.Draw.Image`, `File.write!(path, image.svg)` | Correct (lines 379–381) |
| `format: :svg` removed | No references remain |
| `vega_lite` optional + `MissingDependencyError` | Prose correct (413–416) but Requirements line contradicts (**S2**) |
| Calc-mode demotion + migration note | Present and runnable (lines 131–144) |
| `Qx.histogram`, `StateInit.bell_state` aliases, `Math.basis_state/2` removed | No references remain |
| Barrier no-op fix | Not mentioned (fine — bugfix) |
| 0.9.0: `from_qasm_function` wraps in `Qx.Generated.*` module | README still shows pre-0.9.0 shape (**W4**) |
| 0.9.0: nx ~> 0.12 floor | Requirements line stale (**W7**, **S3**) |
