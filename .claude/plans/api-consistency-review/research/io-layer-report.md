# Phase 2 report — leave-the-simulator layer (Draw · Export.OpenQASM · Hardware)

Scope: `lib/qx/draw.ex`, `lib/qx/draw/`, `lib/qx/export/openqasm.ex`,
`lib/qx/hardware.ex`, `lib/qx/hardware/config.ex`. Scored against
`spec/api-design-principles.md` §3, §5, §6, §7.

## Sweep results (verifications, not findings)

- **Environment sniffing in lib/**: exactly one `Code.ensure_loaded?` /
  `function_exported?` site in the whole of `lib/` —
  `lib/qx/draw/tables.ex:181` (`kino_available?/0`). No other module
  switches behaviour on loaded modules.
- **`defimpl` in lib/**: only `defimpl Inspect, for: Qx.Step`
  (`lib/qx/step.ex:109`). There is **no `Kino.Render` implementation
  anywhere** — the sanctioned pattern from §6 does not exist yet.
- **`from_qasm!/1`**: exists (`lib/qx/export/openqasm.ex:443`), has
  `@spec`, and correctly re-raises the typed exception from the tuple
  form. The `to_qasm` (raise) / `from_qasm` (tuple) split is implemented
  exactly as the §6 precedent describes, and the moduledoc explains the
  asymmetry. Compliant.
- **Hardware error shapes**: every network-stage failure normalises to
  `{:error, {stage, reason}}` with a typed `stage` atom union
  (`lib/qx/hardware.ex:90-100`); `run!/3` is the raising variant.
  External input → tuple-shaped: **compliant** with the §6 contract
  (two wrinkles below, D-12/D-14).

### Return-type catalogue, per Draw function

| Function | `:format` values | Return type(s) |
|---|---|---|
| `Draw.plot/2` (→ `Qx.draw/2`) | `:vega_lite` (default) / `:svg` | `VegaLite.t()` / SVG `String.t()` |
| `Draw.plot_counts/2` (→ `Qx.draw_counts/2`) | `:vega_lite` (default) / `:svg` | `VegaLite.t()` / SVG `String.t()` |
| `Draw.histogram/2` (→ `Qx.draw_histogram/2`) | `:vega_lite` (default) / `:svg` | `VegaLite.t()` / SVG `String.t()` |
| `Draw.bloch_sphere/2` (→ `Qx.draw_bloch/2`) | `:vega_lite` (default) / `:svg` | `VegaLite.t()` / SVG `String.t()` |
| `Draw.state_table/2` (→ `Qx.draw_state/2`) | `:auto` (default) | `%Kino.Markdown{}` if Kino loaded, else text `String.t()` — **environment-dependent** |
| | `:text`, `:html` | `String.t()` (static) |
| | `:markdown` | `%Kino.Markdown{}` if Kino loaded, else markdown `String.t()` — **environment-dependent** |
| `Draw.circuit/2` (no facade delegate) | n/a | SVG `String.t()` (single static return — the only fully compliant chart function) |

So the Draw layer has all three return contracts from spec §9.1:
VegaLite struct, SVG string, Kino-or-string.

### vega_lite gating

`{:vega_lite, "~> 0.1"}` is a **hard dep** (`mix.exs:58`), exercised
only by `Qx.Draw.VegaLite` (`lib/qx/draw/vega_lite.ex` — direct
`VegaLite.new/…` calls, no indirection). It is never touched on the
core build/run/inspect path → fails the §6 hard-dependency test.
If it became optional-and-absent:

- `Qx.Draw.VegaLite` no longer compiles clean (bare `VegaLite.*` calls;
  repo compiles with `--warnings-as-errors`), so it needs
  `Code.ensure_loaded?` guards or extraction;
- the **default** path of `Draw.plot/2`, `plot_counts/2`,
  `histogram/2`, `bloch_sphere/2` — and therefore of `Qx.draw/2`,
  `draw_counts/2`, `draw_histogram/2`, `draw_bloch/2` — breaks
  (default is `format: :vega_lite`);
- survivors: all `format: :svg` paths, `state_table/2`, `circuit/2`.

`kino`, by contrast, is not a dependency **at all** (not even
optional) yet `tables.ex:151,161` calls `apply(Kino.Markdown, :new, …)`
— it works only when the host app happens to have Kino.

## Findings

### D-01 — `state_table`/`draw_state` returns Kino-or-string on TWO format paths
- **Functions**: `Qx.Draw.state_table/2`, `Qx.draw_state/2`
- **Rule**: §6 Environment independence
- **Severity**: high
- **Evidence**: `lib/qx/draw/tables.ex:97-103` (`:auto` →
  `kino_available?()` branch) and `tables.ex:145-155` — the **explicit**
  `format: :markdown` also branches on `Code.ensure_loaded?(Kino)`
  (`tables.ex:181`), returning `%Kino.Markdown{}` in Livebook and a
  markdown string elsewhere. The known violation is `:auto`; the
  `:markdown` branch is a second, worse one: even a caller who pins the
  format gets an environment-dependent type.
- **Fix**: every format returns a string, always. `:auto` is deleted
  (or becomes an alias for `:text`). Rich Livebook rendering moves to
  `Kino.Render` implemented for Qx structs behind an optional `kino`
  dep (the §6 sanctioned pattern; see D-02).
- **Bucket**: breaking-1.0 (return-type change for Livebook users);
  the `:markdown` de-sniffing could ship earlier as
  deprecate-next-minor.

### D-02 — Kino referenced but not declared as a dependency; no `Kino.Render` impl
- **Functions**: `Qx.Draw.state_table/2` internals
- **Rule**: §6 Dependencies + Environment independence
- **Severity**: high
- **Evidence**: `mix.exs` deps list has no `kino` entry (optional or
  otherwise); `lib/qx/draw/tables.ex:151,161` invokes
  `apply(Kino.Markdown, :new, [markdown])` with credo `Refactor.Apply`
  suppressions to hide the undeclared call. `grep defimpl lib/` shows
  zero `Kino.Render` implementations.
- **Fix**: add `{:kino, "~> 0.14", optional: true}` and implement
  `Kino.Render` for the structs Qx wants rendered richly
  (`SimulationResult`, `Step`, chart-spec struct per D-04); delete the
  `apply/3` sniffing.
- **Bucket**: non-breaking-now (adding the optional dep + protocol
  impls is additive; deleting the sniff lands with D-01).

### D-03 — `:format` option switches the return KIND in four chart functions
- **Functions**: `Qx.Draw.plot/2`, `plot_counts/2`, `histogram/2`,
  `bloch_sphere/2`; facade `Qx.draw/2`, `draw_counts/2`,
  `draw_histogram/2`, `draw_bloch/2`
- **Rule**: §5 Orthogonality ("no flag may change what kind of thing
  comes back"); §6 argument order ("options never change the return
  kind")
- **Severity**: high
- **Evidence**: `lib/qx/draw.ex:90-99, 132-141, 174-183, 223-232` —
  each `case format do :vega_lite -> VegaLite… ; :svg -> …SVG string`
  returns `VegaLite.t()` or `String.t()` off an option value. The spec
  names `draw_bloch` as the case to adjudicate; it is in fact the
  uniform pattern across **all four** chart functions, so the decision
  (documented exception vs two functions) applies to the whole family,
  not one function.
- **Fix**: decide once for the family: either (a) split — `draw/2`
  returns the chart spec, `draw_svg/2` (or `to_svg/1` on a chart-spec
  struct) returns the string; or (b) a documented exception in
  `api-design-principles.md` covering the whole `:svg | :vega_lite`
  family. Interacts with D-04 — if charts become plain-data specs,
  the split falls out naturally.
- **Bucket**: breaking-1.0.

### D-04 — `vega_lite` hard dep is not exercised on the core path
- **Functions**: gate set above ("vega_lite gating")
- **Rule**: §6 Dependencies
- **Severity**: high
- **Evidence**: `mix.exs:58` hard dep; used only from
  `lib/qx/draw/vega_lite.ex`; build/run/inspect never touch it. All
  four chart functions **default** to the vega_lite path, so the dep
  is load-bearing for defaults but idle for the core.
- **Fix**: the §6 decision point — optional dep (with
  `Code.ensure_loaded?`-guarded compile in `Qx.Draw.VegaLite` and a
  clear error when absent) or plain-data chart specs (return the
  Vega-Lite JSON map; `VegaLite.t()` is a thin wrapper around one, and
  a `Kino.Render`/`Kino.VegaLite` impl restores Livebook rendering).
  Plain-data specs also resolve D-03's type split.
- **Bucket**: breaking-1.0 (default return type changes); flipping the
  default to `:svg` first would be deprecate-next-minor.

### D-05 — Systematic same-concept-two-names split between facade and `Qx.Draw`
- **Functions**: `Draw.plot`↔`Qx.draw`, `Draw.plot_counts`↔`Qx.draw_counts`,
  `Draw.state_table`↔`Qx.draw_state`, `Draw.bloch_sphere`↔`Qx.draw_bloch`,
  `Draw.histogram`↔`Qx.draw_histogram`
- **Rule**: §6 naming families (`draw_*` is the declared family); §4
  one obvious way
- **Severity**: medium
- **Evidence**: `lib/qx.ex:1096,1114,1145,1182,1219` — five
  `defdelegate … as:` renames. The mapping isn't even internally
  consistent: `draw_histogram`↔`histogram` drops the prefix,
  `draw`↔`plot` and `draw_state`↔`state_table` change the word
  entirely. Assessment: a facade rename per se is defensible (tier 2 is
  "documented utilities… absent from learning material", so learners
  never meet both names), but five ad-hoc mappings fail §4's "two names
  for one concept is a finding" the moment anyone reads Draw's own
  HexDocs page — which tier 2 is explicitly documented for.
- **Fix**: pick one vocabulary. Cheapest coherent option: keep `Qx`'s
  `draw_*` names canonical (they're the §6 family) and rename the
  `Draw` functions to the same concept nouns (`Draw.plot` →
  `Draw.probabilities` is over-clever; `Draw.plot` → deprecated alias
  of a new `Draw.draw`? awkward inside `Draw`). Realistic outcome:
  grandfather the tier-2 names as a **documented exception** ("facade
  delegates may rename; the facade name is the taught spelling"), and
  make every `Draw` @doc open with "Reached as `Qx.draw_x/2` in normal
  use". Either way, record the decision in the principles file.
- **Bucket**: deprecate-next-minor if renaming; non-breaking-now if
  documented exception.

### D-06 — Facade gap: `Draw.circuit/2` has no `Qx.draw_circuit` delegate; README reaches into tier 2
- **Functions**: `Qx.Draw.circuit/2`
- **Rule**: §3 tiers ("a tier 2 module that tier 1 never delegates to
  should justify its existence"); §7 README test / one-import test
- **Severity**: medium
- **Evidence**: `lib/qx.ex` has no `circuit`/`draw_circuit` delegate
  (grep confirms); `README.md:374` — `svg = Qx.Draw.circuit(circuit,
  "Bell State")` — the README (tier-1-only material per §3) is forced
  to teach a tier-2 call because the facade lacks the name. Circuit
  drawing is the *most* README-motivated visual of all (it's the only
  format-stable one, see catalogue).
- **Fix**: add `Qx.draw_circuit/2` delegating to `Draw.circuit`,
  update README. Fold in D-07's options-keyword shape while adding it
  so the new facade name is born compliant.
- **Bucket**: non-breaking-now.

### D-07 — `Draw.circuit(circuit, title \\ nil)` takes a positional scalar instead of options
- **Functions**: `Qx.Draw.circuit/2`
- **Rule**: §6 argument order (subject, required scalars, keyword
  options); §5 uniformity within the module
- **Severity**: medium
- **Evidence**: `lib/qx/draw.ex:283` — the only Draw function whose
  second argument is not a keyword list; every sibling spells the same
  concept `title:` inside `options`.
- **Fix**: `circuit(circuit, opts \\ [])` with `title:` option; keep a
  `circuit(circuit, title)` clause for `is_binary(title)` as a
  deprecated bridge.
- **Bucket**: deprecate-next-minor.

### D-08 — Facade `@spec`s encode (or mis-state) the type instability
- **Functions**: `Qx.draw_state/2`; `Qx.draw/2`, `draw_counts/2`,
  `draw_histogram/2`, `draw_bloch/2`
- **Rule**: §6 Docs (`@spec` correctness); §6 environment independence
- **Severity**: medium
- **Evidence**: `lib/qx.ex:1218` — `@spec draw_state(…) :: String.t()`
  is **wrong**: the delegate returns `%Kino.Markdown{}` in Livebook
  (D-01), a struct, not a string. Lines 1095/1113/1144/1181 declare
  `VegaLite.t() | String.t()` unions — accurate today, but they are
  the D-03 violation written into the type language.
- **Fix**: corrected automatically by D-01/D-03; if those wait for
  1.0, fix `draw_state`'s spec now to
  `String.t() | struct()` with a first-paragraph doc note (§6 Docs
  requires the in/out-of-Livebook difference stated up front).
- **Bucket**: non-breaking-now (spec/doc truthing).

### D-09 — Missing `@spec` on every `Qx.Draw` function and on `to_qasm/2`
- **Functions**: `Draw.plot/2`, `plot_counts/2`, `histogram/2`,
  `bloch_sphere/2`, `state_table/2`, `circuit/2`;
  `Export.OpenQASM.to_qasm/2`
- **Rule**: §6 Docs ("every tier 1 and 2 function carries `@spec`")
- **Severity**: medium
- **Evidence**: inventory rows — Spec = NONE for all six Draw
  functions and `to_qasm/2` (`from_qasm*` all have specs). Source
  confirms: no `@spec` in `lib/qx/draw.ex`; none on
  `openqasm.ex:179`.
- **Fix**: add specs. For Draw this forces the D-03 decision into the
  open (writing `VegaLite.t() | String.t()` seven times makes the
  union smell visible).
- **Bucket**: non-breaking-now.

### D-10 — OpenQASM docs teach nonexistent facade functions
- **Functions**: `Qx.Export.OpenQASM` moduledoc and `to_qasm/2` doc
- **Rule**: §6 Docs; §7 error-message/learnability
- **Severity**: low
- **Evidence**: `lib/qx/export/openqasm.ex:87-91` and `:166` —
  examples call `Qx.circuit(2)` and `Qx.cnot(0, 1)`. Neither exists on
  the facade (it's `Qx.create_circuit/1` and `Qx.cx/3`); the examples
  fail if pasted.
- **Fix**: update examples; consider making them doctests so they
  can't rot again (`to_qasm` output is stable).
- **Bucket**: non-breaking-now.

### D-11 — `include_comments: true` emits a placeholder repo URL into QASM output
- **Functions**: `Qx.Export.OpenQASM.to_qasm/2`
- **Rule**: §6 Docs / output quality (minor)
- **Severity**: low
- **Evidence**: `lib/qx/export/openqasm.ex:229` — generated header
  comment reads `// https://github.com/your-repo/qx`.
- **Fix**: real URL or drop the line.
- **Bucket**: non-breaking-now.

### D-12 — `Hardware.run/3` doc says "raises" for a tuple return; measurement error is a third error shape
- **Functions**: `Qx.Hardware.run/3` (and `run!/3`)
- **Rule**: §6 Error contract; §6 Docs
- **Severity**: medium
- **Evidence**: `lib/qx/hardware.ex:126-127` — doc: "an unmeasured
  circuit raises `Qx.Hardware.NoMeasurementsError`". Code:
  `check_measurements/1` (`hardware.ex:467-468`) returns
  `{:error, %NoMeasurementsError{}}`; only `run!/3` raises. Also the
  error union mixes shapes: network stages give
  `{:error, {stage, reason}}`, the measurement check gives
  `{:error, exception}` bare, and `circuit_to_qasm/1`
  (`hardware.ex:472-476`) wraps a QASM-export exception as
  `{:error, {:config, exception}}` — a gate error labelled as a config
  stage.
- **Fix**: doc says "returns `{:error, %NoMeasurementsError{}}`;
  `run!/3` raises it"; normalise the measurement error to a staged
  tuple (`{:config, exception}`) or promote a `:circuit` stage for
  both pre-flight failures. Note §6 would actually class an unmeasured
  circuit as caller-controlled (raise-worthy) — the tuple is defensible
  inside a tuple-shaped pipeline, but say so.
- **Bucket**: non-breaking-now (doc); deprecate-next-minor (shape
  normalisation).

### D-13 — `list_backends/2` returns a 3-tuple, unique in the module
- **Functions**: `Qx.Hardware.list_backends/2`
- **Rule**: §6 Return shapes ("same family, same shape")
- **Severity**: low
- **Evidence**: `lib/qx/hardware.ex:222-232` —
  `{:ok, [String.t()], Config.t()}` while every sibling returns
  `{:ok, value}` / `:ok`; the updated config is a "side product"
  duplicated into the names element.
- **Fix**: return `{:ok, config}` (names live in
  `config.backends_list`, which `connect/2` already demonstrates) or
  keep as a documented exception since the 3-tuple is spec'd and used.
- **Bucket**: breaking-1.0 if changed.

### D-14 — `cancel/3` failure mislabelled with the `:ibm_poll` stage
- **Functions**: `Qx.Hardware.cancel/3`
- **Rule**: §6 Error contract (typed errors name the fix; stage
  taxonomy should be truthful)
- **Severity**: low
- **Evidence**: `lib/qx/hardware.ex:242-245` — a cancel failure
  returns `{:error, {:ibm_poll, reason}}`; there is no `:ibm_cancel`
  in the `stage` type (`hardware.ex:90-98`). A caller pattern-matching
  stages cannot distinguish a failed cancel from a failed poll.
- **Fix**: add `:ibm_cancel` to the stage union and use it.
- **Bucket**: non-breaking-now (widening a type union; callers
  matching `{:ibm_poll, _}` on cancel results are matching a lie
  today).

### D-15 — Tier annotations missing from all four in-scope moduledocs
- **Functions**: `Qx.Draw`, `Qx.Export.OpenQASM`, `Qx.Hardware`,
  `Qx.Hardware.Config` moduledocs
- **Rule**: §3 ("every module belongs to exactly one tier, recorded in
  its moduledoc; tier 2 modules open with 'Utility module: reached
  from `Qx.*` in normal use'")
- **Severity**: low
- **Evidence**: none of the four moduledocs carries the tier-2 opener
  (`draw.ex:2`, `openqasm.ex:2`, `hardware.ex:2`, `config.ex:2`).
  Hardware's is arguably the odd one out even conceptually — nothing
  on `Qx.*` reaches it (see tiering verdict below).
- **Fix**: add the openers when the tier wording is settled repo-wide
  (likely a phase-3 sweep; recorded here so this layer is on the list).
- **Bucket**: non-breaking-now.

## §3 tiering verdict — `Qx.Hardware.Config` (not a finding)

`Hardware.Config` **earns its tier 2 slot**. Real usage: `kino_qx`
constructs `%Qx.Hardware.Config{}` literally
(`../kino_qx/lib/kino/qx/credentials_cell.ex:306` and generated cell
source `:255`), calls `Qx.Hardware.connect/2`
(`credentials_cell.ex:321`), `Hardware.run/3` + `cancel/3`
(`kino/qx/run.ex`), and pattern-matches `Config` in `safe_reason.ex`.
The qx README documents `Config.from_env!/1`, `Config.new/1`,
`Hardware.run/3`, `submit_qasm/3`, `transpile/3`, `list_backends/2`,
`cancel/3` (`README.md:457-529`). Two follow-on observations:
(1) `Hardware.*` is a tier-2 surface that tier 1 never delegates to and
that the README nonetheless teaches — the same §3/§7 tension as D-06;
the review should either bless a "Hardware is deliberately not
facaded" exception in the principles file or add facade delegates.
(2) The struct's transient/internal fields (`access_token`,
`token_expires_at`, `iam_url`, `base_url`) are documented as
caller-visible but internally managed; fine for tier 2, worth a
"do not set" retained in docs (already present).

## Summary

Six Draw entry points carry three incompatible return contracts —
VegaLite struct, SVG string, and Kino-or-string — with `state_table`
environment-dependent on TWO format paths (`:auto` and explicit
`:markdown`), Kino invoked via `apply/3` without any declared dep, and
zero `Kino.Render` impls; `vega_lite` is a hard dep the core path never
exercises yet it backs the default of every chart function. OpenQASM is
the layer's model citizen (`from_qasm`/`from_qasm!`/`to_qasm` match the
§6 error precedent exactly) apart from doc rot and a missing `@spec`;
Hardware's staged-tuple error contract is §6-compliant with three edge
mislabels (`run/3` "raises" doc, bare exception shape, `:ibm_poll` on
cancel). Naming: the five-way facade/Draw rename split needs one
decision (grandfather-with-exception or rename), and `Draw.circuit` is
a facade gap that already forces tier 2 into the README.
15 findings: 4 high, 6 medium, 5 low — 8 non-breaking-now,
3 deprecate-next-minor, 4 breaking-1.0.
