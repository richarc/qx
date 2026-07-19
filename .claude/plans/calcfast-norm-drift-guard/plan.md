# Plan: Norm-drift guard + configurable renormalization (qx-53v)

**ROADMAP:** v0.8 — line 52, "Add norm-drift guard and configurable
renormalization in CalcFast (qx-53v)"
**Branch:** `feat/calcfast-norm-drift-guard` (create from `main` before `/phx:work`)
**Complexity:** ~7 (MED-HIGH) — crosses Simulation↔Math↔Validation;
touches `defn`-adjacent code; additive public-API change.
**Type:** additive feature (new opt + dev/test guard). Non-breaking.

## Context (legacy issue qx-53v — read-only, bd deprecated)

Unitary gates preserve normalization in theory, but float accumulation
drifts the statevector norm over long circuits. `CalcFast` applies no
renormalization. Add (1) a configurable renormalize step and (2) a
dev/test-only assertion that norm stays within tolerance.

**Acceptance criteria (qx-53v):**
1. Configurable `renormalize: true` option in `run/2` opts.
2. Norm assertion available in test/dev mode.
3. ~~Test: norm stays within `1.0e-10` after a 100-gate circuit.~~
   **AMENDED 2026-05-16 (user, Option A):** `1.0e-10` is infeasible in
   `:c64`/float32 (machine floor ≈1.2e-7 even post-`normalize`; see
   scratchpad DEAD-END). New AC #3: after a 100-gate circuit,
   `renormalize: 10` keeps |Σ|a|²−1| within **`1.0e-6`** AND strictly
   lower than the same circuit with `renormalize: false` (renorm
   demonstrably reduces drift, ~9×).
4. No performance regression on short circuits.

## Key discovery (drives the plan)

- **The issue title says "in CalcFast" but `Qx.CalcFast` is the wrong
  home.** `Qx.CalcFast` is stateless per-gate `defn` kernels — no run
  loop, no `run/2`, no opts. The renormalization *cadence* + opt
  plumbing belongs to **`Qx.Simulation`** (owns `run/2` opts and the
  `execute_circuit/1` `Enum.reduce` gate loop, `simulation.ex:221`).
  `CalcFast` is **not modified**. (Document this scoping correction;
  do not force logic into CalcFast.)
- **Renormalization primitive already exists:** `Qx.Math.normalize/1`
  (`math.ex:61`, a `defn`: `state / Nx.sqrt(Nx.sum(Nx.abs(state)**2))`).
  Renorm = call `Math.normalize/1`. No new Nx primitive.
- **Norm-drift guard already exists:** `Qx.Validation.validate_normalized!/2`
  (`validation.ex:102`) raises `Qx.StateNormalizationError` when total
  probability ≠ 1 within a caller tolerance. The guard reuses it with
  tolerance `1.0e-10`. (Note: it checks total prob `p=Σ|a|²`; AC says
  "norm"; near 1, `|p−1|≤1e-10 ⟹ |‖ψ‖−1| ≤ ~5e-11` — equivalent and
  *stricter*. Use the existing helper; document the equivalence.)
- **No new hex dep** (hex-library-researcher: pure Nx + ExUnit correct).
- `config/config.exs` + `config/test.exs` exist; no `compile_env` in
  `lib/` yet — this introduces the first compile-time config flag.
- Existing measurement collapse (`collapse_to_measurement`,
  `simulation.ex:468`) already renormalizes post-collapse — leave it.

## Decisions (confirmed with user 2026-05-16)

1. **Trigger:** configurable — `renormalize: N` (positive int) renorms
   every N gates in the gate loop **and** at measurement-time;
   `renormalize: true` renorms at measurement-time only; `false`
   (default) = off. (`true` satisfies AC #1 literally; `N` satisfies
   the "every N gates" mode.)
2. **Default:** `renormalize: false` (opt-in) — zero behaviour/perf
   change for existing users; trivially satisfies AC #4.
3. **Norm assertion gating:** compile-time via
   `Application.compile_env(:qx, :assert_norm, false)` captured into a
   module attribute and wrapped in `if @assert_norm` so it is compiled
   to a no-op in `:prod`. `config/test.exs` sets it `true`.
4. **Scope:** both the non-conditional path (`execute_circuit`) and the
   conditional shot-by-shot path (`execute_single_shot` timeline).
5. **No new hex dep.** Reuse `Qx.Math.normalize/1` +
   `Qx.Validation.validate_normalized!/2` + ExUnit `assert_in_delta`.

## Option semantics (public API — additive, non-breaking)

`Qx.Simulation.run/2` / `Qx.run/2` new opt `:renormalize`:

| value | meaning |
|-------|---------|
| `false` (default) | no renormalization — current behaviour, no cost |
| `true` | renorm once at measurement-time (before probabilities) |
| pos integer `N` | renorm every `N` gates **and** at measurement-time |

Resolved internally to `:off | :measurement | {:every, n}` and threaded
through private fns. Invalid values raise a typed `Qx.*Error`
(Iron Law #7) via a new `Qx.Validation.validate_renormalize!/1`.

---

## Phase 1 — Option plumbing + validation (no behaviour change when off)

- [x] [P1-T1] `Qx.Validation.validate_renormalize!/1` — added
      `Qx.OptionError` (per-concern style, `{option, value, hint}` +
      binary clauses) to `lib/qx/errors.ex`; validator has function-head
      clauses + `@doc` with 5 doctests (incl. two raise doctests).
- [x] [P1-T2] `run/2` calls `resolve_renormalize/1` (validates via
      `Validation.validate_renormalize!/1`, maps to `:off |
      :measurement | {:every, n}`, default `:off`).
- [x] [P1-T3] Threaded through `run_without_conditionals/3`,
      `run_with_conditionals/3`, `execute_circuit/2`,
      `execute_single_shot/2`; `get_state`/`get_probabilities` pass
      `:off`. No public signature change beyond the new opt.

**Verify P1:** `mix compile --warnings-as-errors` + full `mix test`
(default `:off` ⇒ behaviour identical; suite must pass unchanged).

## Phase 2 — Renormalization application (reuse `Qx.Math.normalize/1`)

- [x] [P2-T1] `execute_circuit/2` uses `Enum.with_index` + private
      `maybe_gate_renorm/3`; `{:every, n}` ⇒ `Math.normalize/1` when
      `rem(idx+1, n) == 0`; `:off`/`:measurement` hit the no-op
      catch-all clause (zero per-gate cost).
- [x] [P2-T2] `maybe_measurement_renorm/2`: `:off` → identity;
      `:measurement`/`{:every, n}` → `Math.normalize/1`. Applied in
      `run_without_conditionals/3` and on the representative final
      state in `run_with_conditionals/3`.
- [x] [P2-T3] `execute_single_shot/2` reduces over
      `Enum.with_index(timeline)` applying `maybe_gate_renorm/3`; no
      extra renorm at collapse (collapse already normalizes; every-n
      hit on a collapsed state is idempotent — documented inline).

**Verify P2:** targeted new tests (Phase 4 may run incrementally) +
full `mix test`.

## Phase 3 — Compile-time norm-drift guard (dev/test only)

- [x] [P3-T1] DONE — `@assert_norm` + `@norm_tolerance 1.0e-6` attrs;
      gated `assert_norm/1` called in `execute_circuit/2` and
      `execute_single_shot/2`. Detail:
      `@assert_norm Application.compile_env(:qx, :assert_norm,
      false)` + `@norm_tolerance 1.0e-6` in `Qx.Simulation`. Wrap a
      post-gate `Qx.Validation.validate_normalized!(state,
      @norm_tolerance)` call in `if @assert_norm do … end` in
      `execute_circuit/2` and `execute_single_shot/2` so it is compiled
      out when false. (Tolerance is `1.0e-6`, not `1.0e-10` — float32
      floor, see scratchpad RESOLVED note.)
- [x] [P3-T2] DONE — `config/config.exs`: `config :qx, assert_norm:
      false`; `config/test.exs`: `config :qx, assert_norm: true`.
- [x] [P3-T3] DONE — justification comment on `assert_norm/1` + the
      module-attr block. (Original: one-line code comment justifying
      the host-sync inside
      `validate_normalized!` (`Nx.to_number`) as acceptable **only**
      because compile-time-gated to non-prod (Iron Law Nx #5 note).

**Verify P3:** `mix compile --warnings-as-errors && mix format
--check-formatted && mix credo --strict` + `mix test` (guard active in
`:test`, must pass — proves no spurious drift in normal circuits).

## Phase 4 — Tests (TDD, NEW file — needs hook approval)

Create `test/qx/simulation_renormalization_test.exs`. Get human
approval first (test-file hook). Do NOT modify existing tests.

- [x] [P4-T1] DONE — `renormalize: 10` on 100-gate `drift_circuit`
      ⇒ dev ≤ 1e-6 (≈0.0); same circuit `renormalize: false` ⇒
      `assert_raise Qx.StateNormalizationError` (active guard catches
      the ~1.07e-6 drift renorm prevents — the relative guarantee).
- [x] [P4-T2] DONE — Bell circuit: default state flat-list ==
      explicit `renormalize: false`; probs == `[0.5,0,0,0.5]`.
- [x] [P4-T3] DONE — 80-gate circuit `renormalize: true` ⇒ dev ≤ 1e-6.
- [x] [P4-T4] DONE — `-1`, `0`, `1.5`, `:bad` each
      `assert_raise Qx.OptionError`.
- [x] [P4-T5] DONE — `measure` + `c_if` circuit, `renormalize: 5`,
      16 shots ⇒ dev ≤ 1e-6 (exercises `execute_single_shot/2`).

**Verify P4:** `mix test test/qx/simulation_renormalization_test.exs`
then full `mix test`.

## Phase 5 — Performance guard (AC #4)

- [x] [P5-T1] DONE — `bench/renormalization_bench.exs` (5 scenarios:
      short no-opt/false/true, long(100) false/10); added to the
      `bench` alias in `mix.exs`.
- [x] [P5-T2] DONE — ran the bench; short `false` ≡ baseline (+0.03%,
      within noise). Numbers recorded in `scratchpad.md`. AC #4 ✅.

**Verify P5:** `mix bench` runs clean; numbers recorded.

## Phase 6 — Public API docs + CHANGELOG (Iron Law #6: additive ⇒ minor)

- [x] [P6-T1] DONE — `:renormalize` documented in
      `Qx.Simulation.run/2` Options (with float32 floor note) + a
      doctest example; `Qx.run/2` Options updated. `@spec` unchanged
      (keyword list already covers it).
- [x] [P6-T2] DONE — `CHANGELOG.md` `## [Unreleased]` → Added: configurable
      `:renormalize` opt + dev/test norm-drift guard (qx-53v). Note it
      is **additive / non-breaking** — NO major bump (Iron Law #6
      requires CHANGELOG + major only for *breaking* API changes; this
      is additive → next minor at release time, version NOT bumped here
      since release is tag-gated separately).

**Verify P6:** `mix test --only doctest` (new `@doc` examples) + full
gate.

## Phase 7 — Close out (/phx:full continues here)

- [x] [P7-T1] DONE — full gate green: compile (warnings-as-errors),
      format --check-formatted, credo --strict (0 issues),
      `mix test` (234 doctests + 717 tests, 0 failures).
- [x] [P7-T2] `/phx:review` R1 → REQUIRES CHANGES (1 BLOCKER, 4 WARN,
      3 SUGG; reqs 11/11 MET, Iron Laws PASS). `/phx:triage` → user
      approved ALL 8 → ALL RESOLVED. `/phx:review` R2 (post-fix) →
      **PASS**: all 8 confirmed resolved, W1 refactor verified correct,
      Iron Laws PASS, reqs 10 MET/1 UNCLEAR (AC#4 bench, substantively
      met). Only 3 optional polish SUGGESTIONs (N1–N3), no
      blockers/warnings. See `reviews/calcfast-norm-drift-guard-review-v2.md`.
      Merge-gate condition MET. Hard stop for human merge authorization.
- [x] [P7-T3] DONE — branch commit `ba5fe7d` → `git merge --squash`
      → single clean commit `0a3b981` on `main` (11 files; ROADMAP
      qx-53v line 52 ticked `- [ ]`→`- [x]` in that commit). Post-merge
      gate green (234 doctests + 719 tests, 0 failures). `git push
      origin main` ✅ (`6236959..0a3b981`, main ≡ origin/main). Feature
      branch deleted (`-D`; squash-merge → `-d` false-negative).
- [ ] [P7-T4] `/phx:compound` — capture the "issue says module X but the
      seam is module Y" + reuse-existing-validator pattern.

## Risks / notes

- **Scoping correction is the main planning risk:** resist putting
  renorm logic in `Qx.CalcFast` just because the issue title says so.
  CalcFast stays untouched; the seam is `Qx.Simulation` + `Qx.Math` +
  `Qx.Validation`. Flag in the review.
- Iron Law #6: `Qx.run/2` & `Qx.Simulation.run/2` are protected API,
  but the change is **additive** (new optional keyword, default off) —
  non-breaking → CHANGELOG entry, NO major bump.
- Iron Law #7: invalid `:renormalize` must raise a typed `Qx.*Error`
  via `Qx.Validation`, never a raw `ArgumentError`/`FunctionClauseError`.
- Iron Law Nx #4/#5: renorm via `Math.normalize/1` is pure Nx,
  backend-agnostic, vectorized — compliant. The guard's host-sync
  (`Nx.to_number` in `validate_normalized!`) is acceptable ONLY because
  compile-time-gated out of prod — must be explicitly justified
  (P3-T3), or the iron-law-judge will (correctly) flag it.
- norm vs total-probability tolerance: reuse `validate_normalized!`
  (total-prob form) at `1.0e-10`; it is *stricter* than AC's
  norm-form. Documented above — don't reinvent a norm-form assertion.
- Existing-test-modification hook: Phase 4 creates a NEW file; do not
  touch `test/qx/*` existing files (TDD rule #2).
- Release is tag-gated: Phase 6 only edits CHANGELOG `[Unreleased]`;
  do NOT bump `mix.exs` version in this work (separate release step).
