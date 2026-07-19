# Iron Law Review — calcfast-norm-drift-guard (qx-53v)

Reviewer: iron-law-judge agent  
Date: 2026-05-16  
Scope: diff vs `main` on `feat/calcfast-norm-drift-guard`  
Changed files reviewed: `lib/qx/errors.ex`, `lib/qx/validation.ex`,
`lib/qx/simulation.ex`, `lib/qx.ex`, `config/config.exs`,
`config/test.exs`, `mix.exs`, `CHANGELOG.md`,
`test/qx/simulation_renormalization_test.exs`,
`bench/renormalization_bench.exs`

---

## Summary

- Files scanned: 10
- Iron Laws checked: 7 of 7 applicable laws
- Violations found: **0**
- Notes: 1 EXCEPTION-JUSTIFIED finding for Iron Law Nx #5 (host sync in
  `assert_norm/1`); documented below with full rationale.

---

## Iron Law Verdicts

### Law #1 — NO `String.to_atom/1` on caller input

**COMPLIANT.**  
No `String.to_atom/1` call appears anywhere in the changed files.
Grep confirms zero occurrences in the diff scope.

---

### Law #2 — NO process without a runtime reason

**COMPLIANT.**  
No `GenServer`, `Agent`, `Task`, or `spawn` is introduced. The feature
is purely functional: option parsing → validation → stateless `defn`
calls → result struct. No process boundary is crossed.

---

### Law Nx #3 — PREFER reshape+contraction over gather/mask

**COMPLIANT.**  
The new renorm helper reuses `Qx.Math.normalize/1`
(`math.ex:61–64`):

```elixir
defn normalize(state) do
  norm = Nx.sqrt(Nx.sum(Nx.abs(state) ** 2))
  state / norm
end
```

This is a pure vectorised tensor operation: no `Nx.take`, no
`Nx.select`, no gather/mask pattern. Fully compliant.

---

### Law Nx #4 — `defn` correct on `Nx.BinaryBackend`

**COMPLIANT.**  
`Qx.Math.normalize/1` uses only `Nx.sqrt`, `Nx.sum`, `Nx.abs`, and
scalar division — all implemented on `Nx.BinaryBackend`. No EXLA-only
primitives are introduced. `config/test.exs` explicitly sets
`config :nx, :default_backend, Nx.BinaryBackend`, so the entire test
suite runs (and the norm guard fires) on `BinaryBackend`.

---

### Law Nx #5 — NO host-side loops over 2^n amplitudes

**EXCEPTION-JUSTIFIED.**

`assert_norm/1` (`simulation.ex:293–296`) calls
`Qx.Validation.validate_normalized!/2` which executes
`Nx.to_number` — a host sync — inside the gate-application reduce:

```elixir
defp assert_norm(state) do
  if @assert_norm, do: Validation.validate_normalized!(state, @norm_tolerance)
  state
end
```

This is guarded by a compile-time module attribute:

```elixir
@assert_norm Application.compile_env(:qx, :assert_norm, false)
```

- `config/config.exs` sets `config :qx, assert_norm: false` (`:prod` / `:dev`).
- `config/test.exs` sets `config :qx, assert_norm: true`.

**Why EXCEPTION-JUSTIFIED:**

1. **Elixir `if false, do: X` is not dead code at the BEAM bytecode
   level** — the body is compiled but the branch is never taken at
   runtime. The comment in `simulation.ex:14–17` accurately describes
   the intent ("dead code in :prod") but the more precise claim is "never
   executed in :prod". This is the idiomatic Elixir pattern for
   compile-time feature flags; it is not equivalent to a C `#ifdef` but
   it does guarantee zero runtime cost when `@assert_norm` is `false`.

2. The host sync is a **developer/test ergonomic tool**, not a
   production code path. It exists to catch norm drift early in test
   runs, not to model concurrency or perform user-facing work.

3. The in-file comment (`simulation.ex:14–17`, `289–292`) explicitly
   names Iron Law Nx #5 and documents the rationale. The intent is
   transparent and reviewable.

4. The alternative — a separate `Mix.env()` check at runtime — would
   be less reliable (env not always set correctly in embedded use) and
   is conventionally inferior to `Application.compile_env/3` for this
   pattern.

**Residual risk (minor):** A caller who overrides
`Application.compile_env` at build time could inadvertently enable the
guard in prod. This is a build-configuration risk, not a code defect.
No action required; the pattern is correct for this use case.

**Note on pre-existing host loops:** `calculate_measurement_probability`
(`simulation.ex:525–545`) and `collapse_to_measurement`
(`simulation.ex:548–572`) contain `for i <- 0..(state_size - 1)` loops
over 2^n amplitudes with `Nx.to_number` indexing. These are **not new
in this diff** (confirmed via scratchpad note: "already renormalizes
post-collapse — intentionally left as-is"). They are out of scope for
this review.

---

### Law #6 — Breaking changes require CHANGELOG + major bump

**COMPLIANT — ADDITIVE, non-breaking, no major bump required.**

Evidence:

1. **API surface unchanged when `:renormalize` is omitted** — the option
   defaults to `false`, which maps to `:off` (the existing behaviour).
   Call sites with no `:renormalize` key observe identical results and
   identical performance (benchmark: +0.03% noise-level delta for the
   `:off` path, `scratchpad.md`).

2. **Any invalid `:renormalize` value now raises `Qx.OptionError`**
   rather than a downstream `FunctionClauseError`. This is a tightening
   of the error contract (previously undefined / incidental), not a
   breaking change to a documented behaviour.

3. **CHANGELOG `[Unreleased]` entry exists** (`CHANGELOG.md:8–25`),
   accurately describes the feature, confirms backwards compatibility,
   and documents the float32 precision floor.

4. **No `mix.exs` version bump** is present in this diff. Correct:
   the repo uses tag-gated releases; the version bump belongs in the
   release-prep commit, not here.

---

### Law #7 — Public functions raise typed `Qx.*Error` via `Qx.Validation`

**COMPLIANT — the critical path is correctly guarded.**

Trace for an invalid `:renormalize` value (e.g. `-1`, `1.5`, `:bad`,
`0`):

```
Qx.run/2 (lib/qx.ex)
  → Qx.Simulation.run/2 (simulation.ex:79)
      → resolve_renormalize/1 (simulation.ex:104–110)
          → Validation.validate_renormalize!/1 (validation.ex:329–336)
              → raise Qx.OptionError, {:renormalize, value, hint}
```

Key points:

- `resolve_renormalize/1` calls `Validation.validate_renormalize!/1`
  **before** pattern-matching on the result (`false → :off`, `true →
  :measurement`, `n → {:every, n}`). A bad value never reaches the
  `case` arms; the `FunctionClauseError` path is eliminated.

- `Qx.Validation.validate_renormalize!/1` (`validation.ex:329–336`)
  has an explicit catch-all clause that raises `Qx.OptionError` — a
  typed, structured exception with `:option` and `:value` fields callers
  can pattern-match on.

- The new `Qx.OptionError` (`errors.ex:8–29`) follows the existing
  `Qx.*Error` struct convention: `defexception`, keyword fields, and a
  readable `:message`.

**Minor pre-existing issues (not introduced by this diff):**
`validate_qubits_different!/1` (`validation.ex:170–177`) and
`validate_state_shape!/1` (`validation.ex:211–219`) raise raw
`ArgumentError`. These are pre-existing and outside the diff scope.

---

## Final Verdict

**PASS.** Zero Iron Law violations introduced by this diff. The one
host-sync concern (`assert_norm/1`) is correctly documented,
compile-time gated, and constitutes an accepted dev/test exception
rather than a production code path violation.
