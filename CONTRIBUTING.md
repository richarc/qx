# Contributing to Qx

Thanks for considering a contribution to Qx.

If you have limited time and want to get to it:

- Read [Quick start](#quick-start) and [The contribution workflow](#the-contribution-workflow).
- Skim [Hard rules](#hard-rules). They catch the mistakes that block a PR every time.
- Run the [verification command](#verification) before you push.

---

## Ways to contribute

Any of these is welcome:

| Kind | How |
|---|---|
| **Bug report** | Open a [GitHub issue](https://github.com/richarc/qx/issues). Include the Qx version, Elixir version, Nx backend, and a minimal reproducer. |
| **Feature request** | Open a GitHub issue and describe the use case before writing code. For larger features the maintainer may ask for design discussion in the issue thread before reviewing a PR. |
| **Documentation fix** | Small typo or clarification: go straight to a PR. |
| **Code change** | Follow [The contribution workflow](#the-contribution-workflow). |
| **Question** | Open a [GitHub discussion](https://github.com/richarc/qx/discussions) or issue. |

Search existing issues before opening a new one.

---

## Quick start

```bash
# 1. Fork on GitHub, then clone your fork:
git clone https://github.com/<your-username>/qx.git
cd qx

# 2. Install dependencies
mix deps.get

# 3. Confirm the test suite passes on main
mix test

# 4. Create a branch (see "Branch naming" below)
git checkout -b feat/my-feature   # or fix/my-bug
```

You're ready to start.

---

## Development setup

**Requirements:** Elixir 1.18+, Erlang/OTP 27+, and a working `mix`.

Qx targets the `Nx.BinaryBackend` by default. No compiler toolchain
is needed to develop or run the tests. If you want to develop against
EXLA or EMLX for speed, follow the [Performance & Acceleration](README.md#performance--acceleration)
section of the README. Either way, make sure your changes still work
on the default `Nx.BinaryBackend` (see [Hard rules](#hard-rules)).

**Mix tasks you'll use a lot, or should use a lot:**

| Command | Purpose |
|---|---|
| `mix deps.get` | Install dependencies |
| `mix test` | Run the full suite |
| `mix test test/qx/foo_test.exs:42` | Run one test by line |
| `mix test --cover` | Coverage report |
| `mix format` | Auto-format |
| `mix format --check-formatted` | CI-style format check |
| `mix credo --strict` | Lint (strict mode is the project default) |
| `mix compile --warnings-as-errors` | Strict compile |
| `mix docs` | Build HexDocs locally |
| `mix bench` | Run benchmarks (see `bench/`) |

---

## The contribution workflow

Qx uses a fork-and-PR model for external contributions. As a
contributor, **your PR is the merge gate**. A clean, focused PR with
passing checks is what will most likely get merged.

### A note on the maintainer's tooling

The maintainer reviews and merges PRs using the
[`claude-elixir-phoenix`](https://github.com/oliver-kriska/claude-elixir-phoenix)
plugin for Claude Code. **You don't need it.** A normal `git` + `mix`
workflow is fine.

The only thing worth knowing: review feedback on your PR may cite the
plugin's specialist agents by name (`elixir-reviewer`,
`testing-reviewer`, `iron-law-judge`). Treat their comments as you
would any reviewer's.

1. **Open an issue first for non-trivial changes.** This avoids you
   writing code that conflicts with the project direction. Skip for
   typos and small obvious bug fixes.
2. **Fork and branch.** Use `feat/<slug>` for features and
   `fix/<slug>` for bug fixes (e.g. `feat/cphase-gate`,
   `fix/measure-after-barrier`). One change per branch.
3. **Write the tests first.** See [TDD policy](#tdd-policy). The repo
   enforces it.
4. **Implement** the change.
5. **Update documentation.** Cover any public surface with
   `@moduledoc`, `@doc`, and `@spec`. Add doctests where they earn
   their keep. Update the README only if user-facing behavior changed.
6. **Add a `CHANGELOG.md` entry** under `## [Unreleased]`. Use the
   existing categories (`Added`, `Changed`, `Fixed`, `Deprecated`,
   `Removed`).
7. **Run the [verification command](#verification).** It must pass
   before you push.
8. **Open a PR** against `main`. Describe what changed and why, link
   the issue, and include a small reproducer in the description if
   behaviour changed.
9. **Respond to review.** The maintainer may ask for changes.
   `/phx:review` runs on each PR and surfaces specialist feedback
   (Elixir idioms and Iron Law checks). Push follow-up commits to the
   same branch. No force-push or rebase needed unless asked.
10. **Merge.** The maintainer squash-merges once review passes.
    Nothing for you to do at this step.

### Branch naming

| Prefix | Use when |
|---|---|
| `feat/<slug>` | New functionality |
| `fix/<slug>` | Bug fix |
| `docs/<slug>` | Documentation-only |
| `refactor/<slug>` | Internal refactor with no behaviour change |

The slug is short, hyphenated, and descriptive (e.g.
`feat/iswap-gate`, `fix/measure-y-basis`, `docs/openqasm-subset`).

### TDD policy

This project follows a strict TDD discipline:

1. **Tests are written before implementation code.** Always.
2. **Existing tests aren't modified without explicit maintainer
   approval.** If your change requires touching an existing test
   (because the prior assertion was wrong, or because the behaviour
   intentionally changed), call it out in the PR description and wait
   for sign-off before merging. A repo-level hook enforces this on
   the maintainer's side; reviewers will flag it on yours.
3. **A new test must fail before the implementation lands.** If the
   test passes against the existing code, the test isn't proving
   anything.

Error-case tests are as important as happy-path ones (see
[Testing](#testing)).

### Commit messages

Short imperative subject line, optional body. The short version:

```
Add iSWAP gate to Qx.Operations

Implements iSWAP as an Operations primitive with the standard 4x4
matrix. Includes a doctest and an error-case test for out-of-range
qubits. Validated against Qiskit's iSWAP via QASM round-trip.
```

One logical change per commit is preferred but not required. The
squash-merge collapses multiple commits into one anyway.

---

## Hard rules

These catch the mistakes that block a PR every time. The full set of
internal "Iron Laws" lives in `AGENTS.md` (which the maintainer's
tooling loads). The contributor-facing slice is below.

**Elixir / OTP:**

- **No `String.to_atom/1` on caller-supplied strings.** It leaks the
  atom table. Use `String.to_existing_atom/1` or keep the string.
- **No processes** (`GenServer`, `Agent`, supervised `Task`) without
  a concrete runtime reason. Qx is a *library*; processes force
  callers to supervise. Justify with concurrency, isolated state, or
  fault isolation. If you can't, don't add one.

**Nx kernels (`lib/qx/calc*.ex`, anything with `defn`):**

- **Reshape + tensor contraction beats gather/select.** `Nx.take` +
  `Nx.select` patterns don't fuse and double the work. If a gather
  is genuinely unavoidable, leave a one-line comment saying why.
- **`defn` must be correct on `Nx.BinaryBackend`** (the default when
  EXLA / EMLX isn't loaded). Don't assume an accelerated backend.
- **No host-side loops over `2^n` amplitudes.** Vectorise with Nx
  primitives. A loop in Elixir over the statevector is a red flag.
- **Tolerances respect the float width.** Qx states are `:c64`
  (complex float32, ε ≈ 1.2e-7). Sub-epsilon equalities (e.g.
  `1.0e-10`) are unreachable. Express long-circuit norm drift as
  *relative*, or as a guard-fires test, and reuse
  `Qx.Math.normalize/1` + `Qx.Validation.validate_normalized!/2`
  rather than hand-rolling a norm assertion.

**Public API surface:**

- **Breaking changes to `Qx`, `Qx.QuantumCircuit`, `Qx.Operations`,
  `Qx.Simulation`, `Qx.SimulationResult`, or any `Qx.Behaviours.*`
  require a CHANGELOG entry and a major-version bump.** If your PR
  changes a public signature or return shape, call this out clearly
  in the description.
- **Public functions raise typed `Qx.*Error`** on misuse. Route
  through `Qx.Validation`. Don't let raw `Nx`, `Complex`, or
  `ArgumentError` leak across the API boundary.

---

## Error handling philosophy

Qx uses a **fail-fast approach with exceptions** for all error
conditions. We **do not** use `{:ok, result}` / `{:error, reason}`
tuple returns for our public API.

### Why exceptions, not tuples?

Tuple returns are the idiomatic choice for *runtime* failures: file
I/O, network requests, database lookups, external APIs. Exceptions
are the idiomatic choice for *programmer* errors: invalid arguments,
contract violations, invalid state, logic bugs.

All Qx errors fall into the second category. An out-of-range qubit
index always means the caller has a bug. Raising gives them a clear
stack trace, the same convention Elixir uses for `Map.fetch!`,
`Enum.fetch!`, and `Nx.tensor`.

### Exception catalogue

| Exception | Raised when |
|---|---|
| `Qx.QubitIndexError` | Qubit index is out of range |
| `Qx.ClassicalBitError` | Classical bit index is out of range |
| `Qx.QubitCountError` | Circuit qubit count is invalid (must be 1–20) |
| `Qx.GateError` | Unsupported gate type or invalid gate parameters |
| `Qx.MeasurementError` | e.g. getting pure state from a circuit with measurements |
| `Qx.ConditionalError` | Nested conditionals, unmeasured classical bits |
| `Qx.StateNormalizationError` | Quantum state not normalised (∑|ψᵢ|² ≠ 1) |
| `Qx.QasmParseError` | OpenQASM grammar/syntax errors |
| `Qx.QasmUnsupportedError` | Valid QASM outside the supported subset |
| `Qx.RemoteError` | Hardware execution or portal communication failures |
| `ArgumentError` | General argument validation (type mismatch, etc.) |

Examples:

```elixir
# Qx.QubitIndexError
Qx.create_circuit(2) |> Qx.h(5)

# Qx.QubitCountError
Qx.create_circuit(25)

# Qx.StateNormalizationError
Qx.Validation.validate_normalized!(invalid_state)
```

### Where to validate

1. **At public-API boundaries.** Every public function validates its
   inputs.
2. **Before expensive operations.** Validate before running a
   simulation, before allocating a `2^n` tensor.
3. **At state-constraint boundaries.** Normalisation, dimensions,
   gate matrix shape.

Use `Qx.Validation`:

```elixir
Qx.Validation.validate_qubit_index!(qubit, num_qubits)
Qx.Validation.validate_normalized!(state)
Qx.Validation.validate_gate_name!(gate_name)
```

Prefer pattern matching and guards in function heads when the check
is simple:

```elixir
def new(num_qubits) when num_qubits > 0 and num_qubits <= 20 do
  # ...
end

def add_gate(circuit, gate, qubit) do
  Qx.Validation.validate_qubit_index!(qubit, circuit.num_qubits)
  # ...
end
```

---

## Code style

Run `mix format` to auto-format. Run `mix credo --strict` and fix
anything it flags. Beyond that:

### Naming conventions

**Predicate functions** return booleans and **must** end with `?`:

```elixir
def valid?(state), do: # returns boolean
def measured?(circuit, qubit), do: # returns boolean

# Bad:
def is_valid(state)   # should be valid?
def check_measured(circuit, qubit)   # should be measured?
```

Predicates must:
- end with `?`
- return `true` or `false` (not tuples, not `nil`)
- have an `@spec` declaring `:: boolean()`
- be pure (no side effects)

**Guard helpers** use the `is_` prefix and can appear in `when`:

```elixir
when is_binary(name)
when is_integer(qubit) and qubit >= 0
```

(Elixir's built-in guards like `is_binary` use the `is_` prefix
because they're guard-safe. That's the exception to the
predicate-`?` rule.)

**Bang functions** (`validate_qubit_index!`, `from_qasm!`) raise on
error. Their non-bang siblings, where they exist, return
`{:ok, x}` / `{:error, reason}`. That's the *only* place in Qx where
tuple returns are conventional, and it's reserved for runtime
conditions (parsing untrusted input, hardware execution).

### Other style points

- All modules must have `@moduledoc`.
- All public functions must have `@doc` and `@spec`.
- Use pattern matching over conditionals when possible.
- Prefer multiple function clauses over nested `case`.

---

## Documentation requirements

Every public function needs:

```elixir
@doc """
One-line summary of what the function does.

Detailed description if needed: invariants, edge cases, why this
exists.

## Parameters
  * `param1`: description
  * `param2`: description

## Examples

    iex> Qx.example_function(arg1, arg2)
    expected_result

## Raises

  * `Qx.QubitIndexError`: when this condition occurs

## See Also
  * `related_function/1`: brief description
"""
@spec example_function(integer(), integer()) :: result_type()
```

Things to specifically include:

- **Doctests** wherever they earn their place. They double as
  examples and as regression tests.
- **`## Raises`** for any function that can raise. Skipping this is
  the most common doc gap in the codebase.
- **`## See Also`** when there's an obvious sibling function.

If you're not sure whether something is "public", ask in the PR.
The guideline: any module not under a `_private/` path or marked
`@moduledoc false` is public.

---

## Testing

### Layout

- Tests live in `test/` mirroring `lib/` (e.g. `test/qx/foo_test.exs`
  for `lib/qx/foo.ex`).
- Group related tests with `describe` blocks.
- Name tests so they read as English sentences when prefixed with
  "test that…".

### Running tests

```bash
mix test                                  # full suite
mix test test/qx/validation_test.exs      # one file
mix test test/qx/validation_test.exs:42   # one test
mix test --cover                          # with coverage
mix test --failed                         # re-run only previous failures
```

### What to test

- **Happy path** for every public function.
- **Every exception path.** Use `assert_raise`:

  ```elixir
  test "raises QubitIndexError for out-of-range qubit" do
    circuit = Qx.create_circuit(2)

    assert_raise Qx.QubitIndexError, fn ->
      Qx.h(circuit, 5)
    end
  end
  ```

- **Edge cases.** Empty inputs, boundary values (qubit 0, qubit
  `n-1`, `n=1`, `n=20`).
- **`Nx.BinaryBackend` correctness.** If you're touching `defn`
  code, verify behaviour on the default backend, not just under
  EXLA.

Aim for >80% coverage on touched modules. Don't sweat the remaining
few percent if they're unreachable defensive branches.

---

## Verification

Before you push, run:

```bash
mix compile --warnings-as-errors && \
  mix format --check-formatted && \
  mix credo --strict && \
  mix test
```

All four must pass. If you touched `lib/qx/calc*.ex`,
`lib/qx/gates.ex`, or `lib/qx/simulation.ex`, also run:

```bash
mix bench
```

and call out any regression in the PR description.

If a check fails:

- **Compile warnings:** fix them; don't suppress.
- **Format:** run `mix format` and re-run the check.
- **Credo strict:** fix the readability or refactor finding, or
  argue for an exception in the PR if you genuinely disagree
  (don't silently add a `# credo:disable-for-this-file`).
- **Test failure:** fix it. If the test itself is wrong, see the
  [TDD policy](#tdd-policy).

---

## Releases

You don't need to do anything for releases. The maintainer handles
them. For context: Qx is released only on a deliberate `vX.Y.Z` git
tag, which triggers the publish workflow. Pushing branches or
`main` never publishes. CHANGELOG entries you add under
`## [Unreleased]` get moved into the version section at release
time.

---

## License

Qx is licensed under the [Apache License 2.0](LICENSE). By
submitting a contribution you agree your work will be released
under the same licence.

---

## Questions?

- **Bug or feature:** [open an issue](https://github.com/richarc/qx/issues).
- **General discussion:** [GitHub discussions](https://github.com/richarc/qx/discussions).
- **API reference:** [hexdocs.pm/qx_sim](https://hexdocs.pm/qx_sim/).

Thank you for contributing.
