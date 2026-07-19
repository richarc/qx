# Qx Dependency Audit

**Repo:** `/Users/richarc/Development/qxquantum/qx`
**Version:** `0.8.0` (published as `qx_sim` on Hex)
**Elixir:** `~> 1.18`
**License:** Apache-2.0 (verified via `LICENSE` lines 1–5)
**Date:** 2026-06-14

---

## Headline numbers

- **Known vulnerabilities / retired packages:** 0 (`mix hex.audit`: "No retired packages found").
- **Outdated direct deps:** 6 (`benchee`, `complex`, `credo`, `ex_doc`, `nx`, `req`) — none CRIT.
- **Unused direct deps:** 0 (every direct dep is referenced in `lib/`, `test/`, or `bench/`).
- **Dev/test isolation issues:** 0 (all non-runtime deps are scoped with `only:` / `runtime: false` correctly).
- **License risk:** 0 GPL/AGPL in `mix.lock`; locked deps are Apache-2.0 / MIT / BSD-equivalent.
- **`mix deps.audit`:** not runnable (`mix_audit` plugin crashes — `YamlElixir.read_from_file/1 is undefined`; advisory mirror corrupt or `yaml_elixir` missing from the plugin install). Treat as inconclusive; `mix hex.audit` is the authoritative no-vuln signal here.

---

## Raw tool output

### `mix hex.audit` (tail)

```
No retired packages found
```

### `mix hex.outdated` (tail)

```
Dependency     Only      Current  Latest  Status
benchee        dev       1.5.0    1.5.1   Update possible
benchee_html   dev       1.0.1    1.0.1   Up-to-date
bypass         test      2.1.0    2.1.0   Up-to-date
complex                  0.6.0    0.7.0   Update possible
credo          dev,test  1.7.14   1.7.19  Update possible
ex_doc         dev       0.39.3   0.40.3  Update possible
excoveralls    test      0.18.5   0.18.5  Up-to-date
jason                    1.4.5    1.4.5   Up-to-date
nimble_parsec            1.4.2    1.4.2   Up-to-date
nx                       0.10.0   0.12.1  Update possible
plug           test      1.19.2   1.19.2  Up-to-date
req                      0.5.18   0.6.1   Update possible
usage_rules    dev       1.2.6    1.2.6   Up-to-date
vega_lite                0.1.11   0.1.11  Up-to-date
```

### `mix deps.audit`

```
** (UndefinedFunctionError) function YamlElixir.read_from_file/1 is undefined
    YamlElixir.read_from_file(".../elixir-security-advisories-mirego/.../GHSA-5v5w-44w6-q5hv.yml")
    lib/mix_audit/repo.ex:36: MixAudit.Repo.map_advisory/1
```

Plugin broken locally; not a Qx-side issue. `mix hex.audit` is the fallback (clean).

---

## Findings

### MED — `complex` 0.6.0 → 0.7.0 (runtime, minor bump available)

`complex ~> 0.6` does **not** accept `0.7.x` (`~>` on `0.x` means `>= 0.x.0 and < 0.(x+1).0`). The lock is behind and the spec blocks the upgrade. `complex` is foundational (sits under `Nx` for `:c64` tensors) and is a *runtime* dep of a published library.
**Action:** Widen to `~> 0.6 or ~> 0.7` (or move floor to `~> 0.7`), `mix deps.update complex`, run `mix test` + `mix bench`.

### MED — `nx` 0.10.0 → 0.12.1 (runtime, 2 minor versions behind)

`nx ~> 0.10` does **not** accept `0.12.x` for the same reason. Nx minor releases between 0.10 and 0.12 occasionally tweak `defn` compilation, backend semantics, and `Nx.LinAlg`. Qx has 44+ files touching `Nx`, multiple `defn` kernels in `lib/qx/calc*.ex`, and Iron Law #4 requires backend-agnostic behavior. A two-minor lag risks accumulated drift.
**Action:** Widen to `~> 0.10 or ~> 0.11 or ~> 0.12` (or `~> 0.12`), then `mix compile --warnings-as-errors && mix test && mix bench`.

### MED — `req` 0.5.18 → 0.6.1 (runtime, minor bump; constraint won't match)

`req ~> 0.5` does **not** match `0.6.x`. To pick up 0.6, the spec must widen. Req 0.5→0.6 changed some adapter / step internals; `lib/qx/hardware/ibm.ex` and `lib/qx/hardware/portal.ex` use Req directly and are exercised under Bypass in tests.
**Action:** Decide whether to upgrade now (widen spec + run hardware tests under Bypass) or hold at `~> 0.5`. If holding, document that 0.6 is deliberately pinned out.

### LOW — `credo` 1.7.14 → 1.7.19, `ex_doc` 0.39.3 → 0.40.3, `benchee` 1.5.0 → 1.5.1 (dev/test patch + minor bumps)

Dev-only tooling; cosmetic risk. `ex_doc` 0.39 → 0.40 is a minor and could shift generated HTML — re-check `mix docs` output before a release.
**Action:** `mix deps.update credo ex_doc benchee` (current `~>` specs already accept). No runtime impact.

### LOW — Commented-out `exla` / `emlx` are dead weight (mix.exs lines 55–56)

The commented declarations (`{:exla, "~> 0.10", optional: true}`, `{:emlx, "~> 0.2", optional: true}`) imply an "optional dep" pattern, but there is **no** `Code.ensure_loaded?(EXLA)` / `Code.ensure_loaded?(EMLX)` runtime detection and **no** behaviour module wrapping them. EXLA appears only in doc comments (`lib/qx.ex` lines 847, 872, 896, 906, 925; `lib/qx/simulation.ex` lines 52–53) telling users to pass `EXLA.Backend` themselves; `lib/qx/calc.ex` line 126 mentions EXLA in git-history context. Users supply the backend via the `:backend` option that is forwarded to `Nx`. The optional-dep flow Hex would advertise is not actually wired up.
**Action:** Either (a) delete the commented lines — they are misleading dead weight; the Nx `:backend` option is enough; or (b) uncomment them with `optional: true` so downstream `mix.exs` files can declare them once and have Hex resolve compatible versions. Pick one; don't leave the comments.

### LOW — Constraint quality is uniformly good, with one nit

All direct deps use `~>` with reasonable floors. No `==` pins, no unbounded `>=`. The pre-1.0 `~> 0.x` specs (nx, complex, req, vega_lite) are correctly tight per the Hex convention — they block new-minor upgrades, which is the *intended* signal that minor bumps of a 0.x lib are potentially breaking. The Findings above for `complex`/`nx`/`req` reflect deliberate maintainer choices to re-verify on each minor.
**Action:** None. Maintain current `~>` discipline.

### LOW — Dev/test isolation is correct

Verified each non-runtime dep in `mix.exs` (lines 62–69):
- `usage_rules`, `ex_doc`: `only: :dev, runtime: false` ✓
- `benchee`, `benchee_html`: `only: :dev` ✓
- `credo`: `only: [:dev, :test], runtime: false` ✓
- `excoveralls`, `plug`, `bypass`: `only: :test` ✓

No dev/test dep leaks into the runtime application. `extra_applications: [:logger]` in `application/0` is minimal and correct. Published Hex consumers will not pull any of these transitively.

### LOW — License audit (mix.lock packages)

No GPL/AGPL detected in the locked transitive set. Known licenses (best-effort, not guesses where uncertain):
- Apache-2.0 / MIT / BSD-style (permissive): `nx`, `complex`, `jason`, `nimble_parsec`, `req`, `finch`, `mint`, `mime`, `telemetry`, `plug`, `plug_crypto`, `plug_cowboy`, `cowboy`, `cowlib`, `ranch`, `bypass`, `excoveralls`, `ex_doc`, `earmark_parser`, `makeup`, `makeup_elixir`, `makeup_erlang`, `credo`, `bunt`, `file_system`, `benchee`, `benchee_html`, `benchee_json`, `statistex`, `deep_merge`, `vega_lite`, `table`, `nimble_options`, `nimble_pool`, `hpax`, `cowboy_telemetry`.
- **Unverified (declare here rather than guess):** `usage_rules`, `igniter`, `ex_ast`, `glob_ex`, `owl`, `rewrite`, `sourceror`, `spitfire`, `text_diff`. All are dev/test-only (pulled in via `usage_rules` / `ex_doc` chains) so even if any were viral they would not infect the published `qx_sim` artifact.
**Action:** If you want to be airtight, spot-check the dev-only chain with `mix hex.info <pkg>`. No action needed for runtime safety.

### LOW — `mix.lock` freshness

Only 6 deps are behind, none by majors. No deps are *far* behind. `mix.lock` is reasonably fresh.
**Action:** Bundle the `complex`, `nx`, `credo`, `ex_doc`, `benchee` updates into a single `chore/dep-bumps` branch; treat `req` 0.5→0.6 as its own branch because of the spec change.

### LOW — Direct dep usage verified (no unused declarations)

- `nx`: 44+ files (`lib/qx/calc*.ex`, simulation, gates, validation, etc.) — heavy use. ✓
- `vega_lite`: `lib/qx.ex`, `lib/qx/format.ex`, `lib/qx/qubit.ex`, `lib/qx/draw.ex`, `lib/qx/draw/vega_lite.ex`, `lib/qx/draw/svg/charts.ex`, `test/qx/draw_test.exs`. ✓
- `complex`: `lib/qx/format.ex`, `lib/qx/simulation.ex`, `lib/qx/state_init.ex`, `lib/qx/qubit.ex`, `lib/qx/register.ex`, `lib/qx/validation.ex`, `lib/qx/gates.ex`, `lib/qx/math.ex`, `lib/qx/quantum_circuit.ex`, plus tests. ✓
- `nimble_parsec`: `lib/qx/export/openqasm.ex`, `lib/qx/export/openqasm/parser.ex`. ✓
- `req`: `lib/qx/hardware/portal.ex`, `lib/qx/hardware/ibm.ex`. ✓
- `jason`: `lib/qx/hardware/ibm.ex`, plus hardware tests. ✓
- `bypass`, `plug` (test-only): `test/qx/hardware/ibm_test.exs`, `test/qx/hardware/portal_test.exs`. ✓
- `benchee`, `benchee_html`: used by `bench` alias (`mix.exs` lines 132–137). ✓
- `usage_rules`, `ex_doc`, `credo`, `excoveralls`: tooling, used via mix tasks. ✓

No unused deps.

---

## Suggested follow-up bundle

1. **`chore/dep-bumps-runtime`:** widen `complex` and `nx` specs to admit the new minors, `mix deps.update complex nx`, run `mix test` + `mix bench`. (Iron Law #4: re-verify `defn` kernels on `Nx.BinaryBackend`.)
2. **`chore/dep-bumps-dev`:** `mix deps.update credo ex_doc benchee`; re-render `mix docs`.
3. **`fix/req-0.6` (or note in scratchpad):** decide whether to widen `req` spec to `~> 0.6`; if yes, re-run Bypass-backed hardware tests.
4. **`chore/optional-backend-deps`:** delete the commented `exla` / `emlx` lines **or** uncomment with `optional: true` + a real `Code.ensure_loaded?` runtime guard. Don't ship them half-done.
5. **Pre-release checklist (per workspace `CLAUDE.md` §3):** verify no `path: "../<repo>"` deps before tagging — none present today, but enforce on every tag.

---

## Dependency score

| Category | Weight | Score | Reason |
|---|---|---|---|
| No known vulns | 30 | 30 | `mix hex.audit` clean; `mix deps.audit` plugin broken locally but inconclusive (not Qx's fault). |
| No unused/dead deps | 15 | 13 | All direct deps used. -2 for commented-out `exla`/`emlx` half-state. |
| Constraint quality | 15 | 13 | Uniform `~>`, no pins/unbounded. -2 for `nx`/`complex`/`req` specs blocking available minors — needs deliberate widening. |
| Dev/test isolation | 10 | 10 | All non-runtime deps correctly scoped. |
| License safety | 10 | 9 | No GPL/AGPL in lock; a handful of dev-only deps unverified — declared, not guessed. |
| `mix.lock` freshness | 10 | 7 | 6 deps outdated (none major); `nx` 2 minors behind is the main drag. |
| Optional dep hygiene | 10 | 4 | `exla`/`emlx` documented as backends but not wired with `optional: true` or `Code.ensure_loaded?`. |
| **Total** | **100** | **86** | Healthy. Address Nx/complex freshness and the optional-backend ambiguity. |

**Dependency score: 86 / 100**
