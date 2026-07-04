# Qx API design principles

The yardstick for the API consistency review, and after that, the
standing contract for new surface. Score every public function against
these rules. A deviation is either a finding (we change the code) or a
documented exception (we add it here, with the reason).

Draft for argument. Nothing below is settled until Craig signs it.

## 1. Qx is an API

Functions over data structures. Circuits are plain data you can build
with `Enum.reduce`, inspect with `dbg`, and pattern match. Elixir's
pipe operator supplies the fluent feel; the library adds no syntax of
its own.

There are no macros in the public surface today, and that's a feature.
A circuit DSL stays off the table at least until 1.0. If someone
proposes one, the burden of proof is on the DSL: it must beat plain
functions on error messages, tooling, and composability, and the BV
oracle (a circuit built inside `Enum.reduce`) is the test case it has
to survive.

## 2. The layer map

Dependencies point down. A lower layer never reaches up.

```
Qx                                the facade: one documented name per task
──────────────────────────────────────────────────────────────────────────
Draw · Export.OpenQASM · Hardware leave the simulator: render, QASM, QPUs
Simulation · SimulationResult · Step   run circuits, inspect trajectories
QuantumCircuit · Operations · Patterns build circuits (pure data, no math)
StateInit · Math                  raw state vectors: make, normalise, dot
```

The known violation is the `tables → register → qubit → draw → tables`
cycle already scheduled for v0.11. The review should hunt for others.

Two rules fall out of the map:

- **Build never simulates.** Adding a gate touches no tensor. Anything
  that computes a state belongs to the simulation layer, whatever
  module it happens to sit in. (`tap_state/2` runs a simulation from
  inside a build pipeline. That's a deliberate exception for teaching;
  its docs must say so loudly.)
- **Inspect never mutates.** `get_state`, `get_probabilities`,
  `steps`, and every `draw_*` leave the circuit exactly as found.

## 3. Three tiers, and the word "public" is banned

The StateInit lesson from the tutorial rewrite: a module can be
documented, listed in HexDocs, and still be the wrong thing to teach.
"Public" conflates two questions. Split them:

- **Tier 1, taught.** `Qx` plus the structs it hands back
  (`QuantumCircuit`, `SimulationResult`, `Step`). This is the entire
  surface the README, tutorials, and guides may use. A learner needs
  zero aliases.
- **Tier 2, documented utilities.** `StateInit`, `Math`, `Patterns`,
  `Draw`, `Export.OpenQASM`, `Hardware.*`. For library authors and
  advanced escape hatches. Documented, stable, covered by Iron Law #6,
  and absent from learning material.
- **Tier 3, internal.** `@moduledoc false`. No stability promise.
  `Qubit`, `Register`, `Format`, `Validation`, the Draw and QASM
  internals live here.

Every module belongs to exactly one tier, recorded in its moduledoc
(tier 2 modules open with "Utility module: reached from `Qx.*` in
normal use"). A tutorial importing tier 2 is a bug. A tier 2 module
that tier 1 never delegates to should justify its existence.

## 4. Simplicity: one obvious way

- Every task the tutorials teach has exactly one documented spelling,
  and it lives on `Qx`. Two names for one concept is a finding; the
  v0.8.1 GHZ cleanup (three names, one concept) is the template for
  fixing them.
- Convenience variants earn their keep by appearing in real circuits.
  The `*_all` family stays because every multi-qubit algorithm opens
  with it. A variant nobody's notebook calls gets deprecated.
- Prefer composition over new surface. Before adding a function, write
  the two-line pipeline it replaces. If the pipeline is clear, ship
  the pipeline as a doc example instead.

## 5. Orthogonality

- Each function does one thing. No flag may change what *kind* of
  thing comes back. (`draw_bloch`'s `format: :svg | :vega_lite`
  switches the return type with an option value; the review decides
  whether that's a documented exception or two functions.)
- Gates are uniform: `(circuit, qubit_or_qubits, params...) ->
  circuit`. No gate is special. Controlled gates put controls before
  targets. Angles come last.
- Measurement is the only operation with classical output, and its
  shape is uniform too: `(circuit, qubit, classical_bit) -> circuit`.
- Feature interactions must be boring: `c_if` wraps any gate, `steps`
  walks any circuit `run` accepts, barriers are no-ops everywhere. A
  combination that raises is a finding (the multi-qubit barrier crash
  fixed in v0.10 is the cautionary tale).

## 6. Consistency contracts

The mechanical rules the inventory scores against.

**Argument order.** Subject first (circuit, state, or result), then
required scalars, then a keyword list of options. Options never change
the return kind (see orthogonality).

**Naming families.**

| Family | Meaning | Members today |
|---|---|---|
| `create_*` | make the subject | `create_circuit` |
| `get_*` | pure read, returns data | `get_state`, `get_probabilities` |
| `draw_*` | produce something to look at | `draw`, `draw_counts`, `draw_histogram`, `draw_bloch`, `draw_state` |
| `measure*` | add measurement instructions | `measure`, `measure_x/y/z`, `measure_all` |
| `*_all` | broadcast over qubits | `h_all`, `x_all`, `y_all`, `z_all`, `barrier_all`, `measure_all` |
| `tap_*` | peek mid-pipeline, return the circuit | `tap_circuit`, `tap_state`, `tap_probabilities` |
| `to_* / from_*` | leave / enter another format | `to_qasm`, `from_qasm` |
| `*dg` | dagger (inverse) gate | `sdg` |

New functions join a family or argue for a new row here. Predicates
end in `?`. The `sdg` row implies a `tdg` question the review should
answer: either add it or document why `phase(-π/4)` is the answer.

**Return shapes.** Same family, same shape. Builders return the
circuit for piping. `run` returns `%SimulationResult{}` and nothing
else does. Streams are lazy (`steps`) and say so.

**Error contract.** Raise a typed `Qx.*Error` when the caller controls
the input (bad qubit index, bad angle: programmer error). Return
`{:ok, _} | {:error, _}` when the input comes from outside the program
(QASM text, network), with a `!` variant for the raising form. The
`to_qasm` / `from_qasm` pair is the precedent. Raw `ArgumentError` or
`FunctionClauseError` escaping a tier 1 or 2 function is a finding.

**Environment independence.** A function's return type is determined
by its arguments, never by which modules are loaded.
`Code.ensure_loaded?(Kino)` inside `draw_state` is the standing
violation: the same call returns `%Kino.Markdown{}` in Livebook and a
string in a release. The sanctioned pattern for environment-aware
display is the `Kino.Render` protocol, implemented for Qx structs
behind an optional `kino` dependency, so every function keeps one
static return type and Livebook still renders richly.

The corollary is that `draw_*` functions *produce artifacts*, they
don't display. Every Qx function computes the identical value in
Livebook and in a release; what differs is what the host does with it
(Livebook renders automatically, a standalone app writes the SVG,
serves the spec, or prints the table). "Will it work outside
Livebook" is therefore always yes; the `@spec` tells the developer
what they're holding and the docs say what to do with it.

**The package boundary is the Livebook signal.** Anything that
*requires* the Livebook runtime lives in `kino_qx` (or another
`kino_*` package), never in qx. qx may implement protocols for
optional dependencies, but it never calls Kino APIs directly — the
`apply(Kino.Markdown, :new, ...)` in `tables.ex`, invoking a module
qx doesn't even declare as a dependency, is the standing violation.
This is the ecosystem convention (`kino_vega_lite`, `kino_db`): the
package name itself tells a developer they're in Livebook territory.

**Dependencies.** A hard dependency must be exercised on the core
path (build, run, inspect). `vega_lite` fails that test today; the
review decides between optional dep and plain-data chart specs.

**Docs.** Every tier 1 and 2 function carries `@spec`, a `## Returns`
section, `## Raises` when it raises, and a doctest when output is
stable. Where behaviour differs in and out of Livebook, the doc says
so in the first paragraph, and a single "Visualisation in and out of
Livebook" guide owns the full story.

## 7. Learnability tests

Fast smell tests, applied per function during review:

- **The README test.** Tier 1 is whatever an honest README needs.
  A tier 1 function the README can't motivate should drop a tier.
- **The tutorial-apology test.** If teaching a function needs an
  apology ("we drop one level down just for this section"), either
  the tier is wrong or the API is. The tutorial rewrite left a list
  of these; they're pre-paid findings.
- **The one-import test.** Any example that needs `alias` to be
  readable is using the wrong tier.
- **The error-message test.** A typed error names the fix
  ("qubit 3 out of range for a 2-qubit circuit"), and never leaks an
  internal module name.
- **The bare-IEx test.** Every tier 1 doc example runs in a plain IEx
  session with only qx installed. An example that needs Livebook to
  be meaningful belongs in a Livebook-specific guide or in kino_qx's
  docs, clearly marked. Standalone-safety becomes a property review
  can check mechanically, not a doc-writing aspiration.

## 8. Growing the surface: building blocks and domain libraries

Developers shouldn't hand-craft standard algorithms from scratch. The
plan is layers of building blocks above the gate set: oracles first
(`Qx.Oracle`), then algorithm components (diffusion, QFT, phase
estimation), then domain libraries. These rules govern how that
surface grows without eroding the ones above.

**The gate contract is the extension contract.** A building block is a
compound operation with exactly the gate shape:

```
(circuit, qubits_and_params..., opts \\ []) -> circuit
```

Anything with this shape composes with `run`, `steps`, `c_if`
wrapping, `draw`, and QASM export for free, because to the rest of Qx
it just added instructions. A block with any other shape needs
bespoke integration everywhere, and that cost lands on every layer
above it.

**Appenders by default, creators as facades.** An appender
(`cx_chain/2`) nests inside a larger circuit: an oracle inside Grover
inside an error-corrected register. A creator (`bell_state/1`) can't
nest; it can only start. So every block ships as an appender, and a
from-scratch creator is only added where teaching wants a one-liner,
as a thin wrapper over the appender. `Patterns` currently mixes the
two shapes with no appender underneath its creators; that's a tension
for the review (section 9).

**Blocks compose operations; they never invent instruction shapes.**
A building block calls tier 1 and 2 functions and nothing else. The
simulator's dispatch stays closed: no library-emitted tuple the
timeline has never heard of (Iron Law #9 is the enforcement, the
multi-qubit barrier crash is the precedent). A block that genuinely
needs a new primitive proposes the primitive as its own change, with
its own dispatch arm and execution tests, and the block builds on it
afterwards.

**Where a block lives.** Domain-neutral circuit machinery ships in
core under one namespace per concern (`Qx.Oracle`, later
`Qx.Algorithm.*`): it needs no new dependencies and every user
benefits. A library leaves core and becomes a separate `qx_*` hex
package when either holds: it drags in domain dependencies (chemistry
data, optimisation solvers), or its users model a domain rather than
circuits (molecules in, energies out). Separate packages depend on
the tier 1 and 2 surface only, and Iron Law #6 is their stability
guarantee.

**Tier rules recurse.** Each domain area gets one facade module, and
learning material for that domain teaches only the facade, exactly as
`Qx` fronts the core. The facade's functions join the section 6
naming families or argue for a new row.

## 9. Known tensions for the review to adjudicate

Named here so the review starts from the same list, undecided on
purpose:

1. `draw_state`'s loaded-module sniffing, and the Draw layer's three
   return contracts (VegaLite spec, SVG string, Kino-or-string).
2. `vega_lite` as a hard dependency of a simulation library.
3. `StateInit` and `Math` tier placement now that no tutorial uses
   them. The v0.8.1 "declared PUBLIC" decision cited tutorial usage
   that no longer exists.
4. `tap_*`: simulation cost hiding inside build-shaped functions.
5. `measure_x/y` post-measurement state staying Z-aligned
   mid-circuit (documented today; is documentation enough?).
6. Missing `tdg` versus the `phase(-π/4)` idiom the tutorials teach.
7. Whether Iron Law #6's flat "public surface" list should become
   the tier annotations from section 3.
8. `Patterns` mixes appenders (`cx_chain`, `*_all`) with creators
   (`bell_state`, `ghz_state`, `superposition`). Review evidence
   (build-layer report B-10): `superposition_circuit` already wraps
   the `h_all` appender, `ghz` half-composes `cx_chain`, and only
   `bell` has no appender underneath. Decide before v0.13 algorithm
   work multiplies whichever shape stands: add the missing appender
   forms (e.g. `bell_pair(circuit, q0, q1)`) and reframe the creators
   as wrappers, or grandfather the creators as teaching facades.

## 10. How the review applies this

Phase 1 inventories the tier 1 and 2 surface via `Code.fetch_docs`:
one row per function with family, arg order, return shape, error
contract, tier, and doc status. Phase 2 scores each row against
sections 5 through 7. Every deviation becomes a finding; every finding
either changes the code or adds a documented exception to this file.
Findings then triage into three buckets: non-breaking now, deprecate
next minor, and a breaking list that becomes the 1.0 gate. The backlog
already defers 1.0 until the surface settles; this review is the
settling.
