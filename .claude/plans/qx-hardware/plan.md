# Plan: `Qx.Hardware` — direct-to-IBM hardware execution

**Slug**: `qx-hardware`
**Repo**: `qx/` (upstream — ships first; downstream `kino_qx/` follows in its own plan)
**Input**: `../kino_qx/.claude/plans/kino-qx-circuit-pipeline/interview.md` (Status: COMPLETE)
**Created**: 2026-05-14
**Branch (to create before `/phx:work`)**: `feat/qx-hardware`
**Target version**: `0.7.0` (breaking minor; pre-1.0 — see SemVer note in interview §release plan)

## Summary

Introduce a new `Qx.Hardware` namespace owning the **full IBM-direct execution pipeline** (IAM → portal transpile → IBM submit → poll → result-build). Delete the obsolete `Qx.Remote` (qx_server-based) in the same release — kino_qx is the only known consumer and is being rewritten downstream. Adds the test-only `:bypass` dep and an explicit `:jason` pin.

## Goals & non-goals

**In scope**
- New public modules: `Qx.Hardware`, `Qx.Hardware.Config`, `Qx.Hardware.Ibm`, `Qx.Hardware.Portal`, `Qx.Hardware.NoMeasurementsError`, `Qx.Hardware.ConfigError`.
- Migration of IBM REST client + transpile orchestrator from `kino_qx` (528 + 174 lines).
- Migration of the hardware-relevant portion of `Kino.Qx.Client` (the `/me` + `/transpile` calls) into `Qx.Hardware.Portal`.
- Deletion of `Qx.Remote`, `Qx.Remote.Config`, `test/qx/remote_test.exs`, `examples/remote/run_on_hardware.exs` (or rewrite the example against `Qx.Hardware`).
- `mix.exs` deps: add `{:bypass, "~> 2.1", only: :test}`, pin `{:jason, "~> 1.4"}`.
- CHANGELOG entry (BREAKING) + version bump to 0.7.0 + ROADMAP check-off (if applicable).
- All moved tests (~35) green; full suite green; `mix compile --warnings-as-errors`, `mix format --check-formatted`, `mix credo --strict` clean.

**Out of scope** (handled by the kino_qx plan)
- `Kino.Qx.CredentialsCell` UI rebuild.
- `Kino.Qx.run!/2,3` + `Kino.Frame` status renderer.
- Demo notebook.
- Anything that touches `kino` as a dep.

## Architecture

```
┌─────────────────────── Qx.Hardware (public) ───────────────────────┐
│ run/3, run!/3, submit_qasm/3, transpile/3, list_backends/1,        │
│ cancel/2  — pipeline orchestrator + entry points                   │
└────────┬────────────────────────────────────────────────┬──────────┘
         │                                                │
         ▼                                                ▼
┌──────────── Qx.Hardware.Portal ─────────┐  ┌─── Qx.Hardware.Ibm ──┐
│ /api/v1/me, /api/v1/transpile           │  │ IAM exchange         │
│ (qxportal HTTP via Req)                 │  │ list_backends        │
└─────────────────────────────────────────┘  │ fetch_backend_config │
                                             │ submit_sampler       │
┌──────────── Qx.Hardware.Config ─────────┐  │ poll_job             │
│ struct + new/1, new!/1, from_env/from_env!│ │ fetch_results        │
│ Required: portal_url, portal_token,     │  │ cancel_job           │
│           ibm_api_key, ibm_crn,         │  └──────────────────────┘
│           ibm_region, backend           │
│ Defaulted: optimization_level=1,        │
│            shots=4096                   │  Error types:
│ Transient/cached: identity,             │  ├ Qx.Hardware.NoMeasurementsError
│                   backends_list         │  ├ Qx.Hardware.ConfigError
└─────────────────────────────────────────┘  └ (existing) Qx.GateError, etc.
```

**Privacy invariant** (carried over): two HTTP clients, two configs in, **portal_token never reaches `Qx.Hardware.Ibm`; ibm_api_key/crn never reach `Qx.Hardware.Portal`.**

## Iron Law compliance

| Law | How this plan complies |
|---|---|
| #1 — no `String.to_atom` on caller input | Status events use literal atom tuples (`:portal, :transpiling`, etc.). IBM job statuses (`"DONE"`, `"FAILED"`, etc.) decoded via explicit case/match, never `String.to_atom`. Allowlisted set documented in `Qx.Hardware.Ibm.@known_statuses`. |
| #2 — no unjustified processes | `Qx.Hardware` is purely functional. Polling uses `Process.sleep` between HTTP calls (same as existing `Qx.Remote.remote.ex:229` precedent — acceptable for a library blocking call). No GenServer / Task supervision added. |
| #6 — public-API breaks need CHANGELOG + major bump | Deletion of `Qx.Remote.*` is a breaking change. Since qx is pre-1.0, a minor bump (0.6.x → 0.7.0) is the right level (SemVer §4). CHANGELOG `[Unreleased]` section gains a **BREAKING** entry with migration notes. |
| #7 — typed errors at public boundary | `Qx.Hardware.Config.new/1` returns `{:ok, _}` / `{:error, %Qx.Hardware.ConfigError{}}`. `run/3` returns `{:ok, %Qx.SimulationResult{}}` / `{:error, term}` where the term is **always** one of: a typed `Qx.Hardware.*` exception, or a `{:stage, reason}` tuple matching the status-callback contract (interview §9). Bang variants raise the same typed exceptions. No raw `Req.TransportError`, `Jason.DecodeError`, or `RuntimeError` leaks. |

## Phases

### Phase 0 — Pre-flight (no code changes)

- [x] Create branch `feat/qx-hardware` from `main` (run from `qx/` root).
- [x] Confirm `mix test` green on `main` baseline (currently 620 tests, 0 failures + 226 doctests). — 620 tests + 226 doctests green on feat branch baseline.
- [x] Confirm no other in-progress branch touches `lib/qx/remote*` or `lib/qx/result_builder.ex`. — only remote refs returned.

### Phase 1 — Dependencies & scaffolding

- [x] `mix.exs`: add `{:bypass, "~> 2.1", only: :test}`.
- [x] `mix.exs`: pin `{:jason, "~> 1.4"}` (currently transitive via `req`/`plug` — explicit pin matches the defensive posture documented in kino_qx's mix.exs).
- [x] `mix deps.get`. — bypass + plug_cowboy + cowboy stack added.
- [x] Run `mix test` — baseline still green. — 620 tests + 226 doctests still green.

### Phase 2 — Error types & Config struct

- [x] `lib/qx/errors.ex`: append `Qx.Hardware.NoMeasurementsError` (accepts `%Qx.QuantumCircuit{}` or string) and `Qx.Hardware.ConfigError` (field/reason/message keyword opts).
- [x] `lib/qx/hardware/config.ex` (NEW): defstruct with enforce_keys + defaults + transient fields.
- [x] `Qx.Hardware.Config.new/1` — keyword or map, returns ok/error tuple.
- [x] `Qx.Hardware.Config.new!/1` — bang variant.
- [x] Validation: optimization_level 0..3, shots 1..100_000, ibm_region allowlist, portal_url URI scheme check.
- [x] Also added `from_env/1` and `from_env!/1` reading `QX_*` env vars (handy for examples + ops).
- [x] `@spec` every public function.
- [x] Doctests for `new/1` happy path + `optimization_level` error path + `new!/1` raising on bad scheme.
- [x] Mix docs groups updated: removed `Qx.RemoteError`, added `Qx.Hardware.{NoMeasurementsError,ConfigError}`.

**Verify**: 620 tests + 226 doctests green; `mix credo --strict` clean (610 mods, no issues); warnings-as-errors clean.

### Phase 3 — Move `Qx.Hardware.Ibm` (formerly `Kino.Qx.IbmClient`)

- [x] Copy `kino_qx/lib/kino/qx/ibm_client.ex` → `lib/qx/hardware/ibm.ex`, rename `Kino.Qx.IbmClient` → `Qx.Hardware.Ibm`.
- [x] No `Kino.*` references in the IBM client; module is HTTP-only.
- [x] Audited `decode/1` + `poll_job` status normalization — already uses `@known_statuses` allowlist; no `String.to_atom` present.
- [x] Errors returned as typed tuples (`:unauthorized`, `:not_found`, `:unsupported_result`, `{:network, _}`, `{:http, _, _}`, `{:rate_limited, _}`, `{:unknown_status, _}`). No raw exceptions leak.
- [x] All functions accept `%Qx.Hardware.Config{}` directly. Test/override hooks (`iam_url`, `base_url`, `access_token`, `token_expires_at`) are nilable fields on `Config`, documented as internal.
- [x] `base_url_for/1` now accepts string regions (`"us-south"`, `"eu-de"`, etc.) and falls back to `<region>.quantum.cloud.ibm.com/api/v1` for the other 4 allowlisted regions.
- [x] `submit_sampler/3` overload uses `config.shots` default; `/4` keeps explicit shots.
- [x] Test file at `test/qx/hardware/ibm_test.exs` — 31 tests (22 from kino_qx + 9 new for the extra regions and 3-arity shots default).
- [x] Test support at `test/support/stub_ibm.ex` (renamed to `Qx.Hardware.StubIbm`). `mix.exs` now adds `elixirc_paths(:test) = ["lib", "test/support"]`.
- [x] **Verify**: full suite 651 tests + 226 doctests green; credo strict 673 mods, no issues.

### Phase 4 — Move `Qx.Hardware.Portal` (the hardware-relevant slice of `Kino.Qx.Client`)

- [x] `lib/qx/hardware/portal.ex` — public `me/1` and `transpile/3` (kw opts: `:backend`, `:optimization_level`, `:basis_gates`, `:coupling_map`, `:seed_transpiler`). Defaults pulled from `Config` when opts omitted.
- [x] Implemented against `Req.new/1`. Same `@known_keys` atomize allowlist as kino_qx's client (snippet-only keys dropped).
- [x] `@spec` on both public functions.
- [x] `test/qx/hardware/portal_test.exs` — 13 tests covering `me/1` happy + 401, `transpile/3` happy (explicit + config defaults), 401, 422+detail, 422 fallback, 429+retry-after, 502, 503, 504, 418 passthrough, network down.
- [x] **Verify**: `mix test test/qx/hardware/portal_test.exs` 13/13 green.

### Phase 5 — Build `Qx.Hardware` orchestrator

- [x] `lib/qx/hardware.ex` — `run/3`, `run!/3`, `submit_qasm/3`, `transpile/3` (string or circuit), `list_backends/2`, `cancel/3`, `connect/2`.
- [x] Absorbed orchestration logic from `transpile_pipeline.ex` (exponential-backoff poll, deadline, terminal-status routing).
- [x] **Lazy connect** via `ensure_connected/4`: if `identity == nil` OR `backends_list == []`, calls `portal.me/1` + `ibm.list_backends/1`, rebuilds config, validates `backend ∈ backends_list`. Mismatched backend → `{:error, {:config, %Qx.Hardware.ConfigError{}}}`.
- [x] **Pre-flight measurement check**: empty `circuit.measurements` → `{:error, %Qx.Hardware.NoMeasurementsError{}}`. `run!/3` raises it.
- [x] `run/3` pipeline: check_measurements → `Qx.Export.OpenQASM.to_qasm/2` → `submit_qasm/3` (single source of truth).
- [x] `submit_qasm/3` pipeline: ensure_connected → iam_exchange → fetch_backend_configuration → Portal.transpile → submit_sampler → poll loop → fetch_results → `Qx.ResultBuilder.from_counts/3`.
- [x] Status callback: literal atom events `{:portal, :connecting | :listing_backends | :transpiling}`, `{:ibm, :authenticating | :fetching_backend | :submitting | :fetching_results}`, `{:ibm, :job_started, job_id}`, `{:ibm, :polling, status}` (Iron Law #1 — no `String.to_atom`).
- [x] Error normalisation: `{:error, {stage, reason}}` for `:config | :portal | :ibm_auth | :ibm_submit | :ibm_poll | :ibm_poll_timeout | :ibm_job_failed | :ibm_results`. Typed exceptions surface as `{:error, %Qx.Hardware.{ConfigError,NoMeasurementsError}{}}`.
- [x] `@spec` on every public function. Module overrides (`:ibm`, `:portal`, `:sleep`) for test injection.
- [x] Doctests skipped on `Qx.Hardware` itself — public entry points are network-bound; doctests live on `Qx.Hardware.Config` (Phase 2).

**Verify**: `mix compile --warnings-as-errors` clean. Test file added in Phase 6.

### Phase 6 — `Qx.Hardware` integration tests

- [x] `test/qx/hardware_test.exs` — 26 tests covering: happy-path stage sequencing, transpile payload assembly, shots threading, all 10 error routes (`:ibm_auth`, `:portal`, `:ibm_submit`, `:ibm_poll`, `:ibm_poll_timeout`, `:ibm_job_failed` for Failed/Cancelled/Cancelled-Ran-too-long, `:ibm_results`), status-callback emission, ordered events.
- [x] **NoMeasurementsError** — `run/3` returns `{:error, %NoMeasurementsError{}}`; `run!/3` raises it.
- [x] **Lazy-connect happy path** — empty `identity`/`backends_list` triggers `portal.me` + `list_backends`, then runs.
- [x] **Lazy-connect ConfigError** — backend not in account's `backends_list` → `{:error, {:config, %ConfigError{field: :backend}}}`.
- [x] **Lazy-connect skipped** when both fields already populated.
- [x] **cancel/3** happy path + ibm-failure routing through `:ibm_poll`.
- [x] **transpile/3** circuit and string inputs.
- [x] Refactored `poll_until_done` into state-map form to satisfy credo (Nesting and arity).
- [x] **Verify**: 690 tests + 226 doctests green; credo strict 742 mods, no issues.

### Phase 7 — Delete `Qx.Remote`

- [x] `rm -rf lib/qx/remote.ex lib/qx/remote/ test/qx/remote_test.exs examples/remote/`.
- [x] `Qx.RemoteError` removed in Phase 2 already; nothing else references it.
- [x] New `examples/hardware/run_on_ibm.exs` against `Qx.Hardware.Config.from_env!/1` + `Qx.Hardware.run/3`. Reads `QX_PORTAL_URL`, `QX_PORTAL_TOKEN`, `QX_IBM_API_KEY`, `QX_IBM_CRN`, `QX_IBM_REGION`, `QX_IBM_BACKEND` from env; `Mix.install` fallback for outside-of-checkout runs.
- [x] `lib/qx/result_builder.ex` docstring updated to reference `Qx.Hardware`.
- [x] `lib/qx/draw.ex` docstrings at `:21` and `:106` updated.
- [x] `mix.exs` docs groups: `Remote Execution` group → `Hardware Execution` (adds `Qx.Hardware`, `Qx.Hardware.Config`, `Qx.Hardware.Ibm`, `Qx.Hardware.Portal`; keeps `Qx.ResultBuilder`). Package description updated to "direct execution on IBM Quantum hardware".
- [x] Grep clean — only `CHANGELOG.md` historical v0.6 entries reference `Qx.Remote*`, which is correct (release-notes archaeology).
- [x] **Verify**: 673 tests + 226 doctests green (17 `Qx.Remote` tests removed); warnings-as-errors clean.

### Phase 8 — README, CHANGELOG, ROADMAP, version

- [x] `README.md` — "Running on Quantum Hardware via QxServer" section replaced with "Running on IBM Quantum Hardware" quickstart, including `Qx.Hardware.Config.from_env!/1` env-var setup and a Bell-state example with `on_status:` callback. Lower-level entry points (`submit_qasm`, `transpile`, `list_backends`, `cancel`) documented. Privacy-invariant paragraph added.
- [x] `CHANGELOG.md` — new `[0.7.0] - 2026-05-14` section with **BREAKING** migration block, full **Added** list (`Qx.Hardware*` modules + privacy invariant + status callback), **Removed** (`Qx.Remote*` + `examples/remote/`), and **Dependencies** (`:bypass` test, explicit `:jason` pin).
- [x] `mix.exs` — `version: "0.6.0"` → `"0.7.0"`. Package description updated. Docs group "Remote Execution" → "Hardware Execution" with new modules.
- [x] `ROADMAP.md` — v0.7 milestone retitled "Direct IBM Hardware Execution + Quality"; new checked entry `Qx.Hardware` direct-to-IBM (plan: qx-hardware). v0.8 milestone: "Improvements for running on IBM Q" checked + noted delivered; QxServer-protocol line crossed out as superseded.
- [x] Non-goals: "QxServer handles the hardware layer" → "IBM Quantum handles the hardware layer" to reflect new reality.
- [x] **Verify**: warnings-as-errors clean, `mix format --check-formatted` clean, 673 tests + 226 doctests green, credo strict 719 mods no issues.

### Phase 9 — Final verification + release prep

- [x] `mix compile --warnings-as-errors` — clean.
- [x] `mix format --check-formatted` — clean.
- [x] `mix credo --strict` — 719 mods, no issues.
- [x] `mix test` — 689 tests + 229 doctests, 0 failures (baseline 620 → +31 Ibm + 13 Portal + 26 Hardware + 16 Config + 3 doctests − 17 Remote = matches).
- [x] `mix coveralls` — `lib/qx/hardware*` total 78.8% (Config 90.9%, Portal 81.0%, Hardware 76.6%, Ibm 75.4%). Below 80% target; **bd issue filed** with `discovered-from:qx-hardware` to lift coverage in v0.7 quality work.
- [x] `mix docs` — all `Qx.Hardware.*` modules render (`Qx.Hardware.html`, `Config.html`, `Ibm.html`, `Portal.html`, `ConfigError.html`, `NoMeasurementsError.html`).
- [x] `mix bench` — skipped explicit run; deletion is HTTP-only, no Nx/defn hot-path code touched.
- [ ] Push branch; open PR via `/pr qx-hardware`. (User-driven step.)
- [ ] After merge, when ROADMAP version 0.7 section is fully checked, invoke `release-manager` agent to publish to Hex.pm + GitHub.

## Files touched

**New**
- `lib/qx/hardware.ex`
- `lib/qx/hardware/config.ex`
- `lib/qx/hardware/ibm.ex`
- `lib/qx/hardware/portal.ex`
- `test/qx/hardware_test.exs`
- `test/qx/hardware/ibm_test.exs`
- `test/qx/hardware/portal_test.exs`
- `test/support/stub_ibm.ex`
- `examples/hardware/run_on_ibm.exs` (replacement)

**Modified**
- `lib/qx/errors.ex` (add `NoMeasurementsError`, `ConfigError`; remove `RemoteError`)
- `lib/qx/result_builder.ex` (docstring)
- `lib/qx/draw.ex` (docstrings at :21, :106)
- `mix.exs` (deps + version)
- `CHANGELOG.md`
- `README.md`
- `ROADMAP.md`

**Deleted**
- `lib/qx/remote.ex`
- `lib/qx/remote/config.ex`
- `lib/qx/remote/` (directory)
- `test/qx/remote_test.exs`
- `examples/remote/run_on_hardware.exs`

## Risks & open questions

1. **Portal-config validation** — kino_qx's existing `validate_portal_url/1` uses a host allowlist. Carry it over or relax to `URI.new/1` scheme check only? **Decision needed before Phase 2.** (Default in plan: scheme check; allowlist deferred as a bd issue if security review wants it back.)
2. **`Qx.RemoteError` deletion** — public-API surface (audit M6 flagged it as unraised). Pre-1.0 removal is fine; flag in CHANGELOG. Confirmed by interview (no consumer).
3. **`Process.sleep` poll loop in a library function** — same precedent as `Qx.Remote`'s existing pattern (`Qx.Remote.poll_job/2`). Acceptable for now; downstream `Kino.Qx.run!` wraps it in a monitored Task so cell-interrupt cancellation works. Non-Livebook callers must handle their own supervision if they want async cancel.
4. **IBM region allowlist** — list pulled from current IBM docs. If IBM adds regions before 0.7.0 ships, expand the allowlist or relax to `is_binary/1` + downstream rejection. **Low risk** for the initial release.
5. **`:jason` explicit pin** — Req already pulls Jason in transitively. Pinning to `~> 1.4` matches kino_qx's defensive pin (against accidental dep drift). Confirm `mix deps.get` still resolves clean after the pin.
6. **Self-check (Iron Law #7 enforcement)** — When the audit's `H1` (`Qx.Validation` itself raising `ArgumentError`) is in flight, do not let new `Qx.Hardware` code copy that pattern. Every public validation here uses the typed exceptions defined in Phase 2.

## Verification gates

After every phase: `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test --max-failures 1`.

Before merge:
- All checkboxes ticked.
- `bd preflight` clean (run automatically by `/pr`).
- Manual sanity: hit IBM cloud sandbox with a 2-qubit Bell circuit using real credentials and confirm a `%Qx.SimulationResult{}` comes back. (Not gated in CI; flagged in PR description.)

## Downstream handoff

After 0.7.0 hex-publishes:
- Update `kino_qx/mix.exs` to `{:qx, "~> 0.7"}` in a separate kino_qx PR (per workspace policy §4).
- Run the second plan: `cd ../kino_qx && /phx:work .claude/plans/kino-qx-circuit-pipeline/plan.md`.
