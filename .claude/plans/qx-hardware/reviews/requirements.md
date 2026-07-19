## Requirements Coverage (from `.claude/plans/qx-hardware/plan.md`)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | New public module `Qx.Hardware` | MET | `lib/qx/hardware.ex:1` |
| 2 | New public module `Qx.Hardware.Config` | MET | `lib/qx/hardware/config.ex:1` |
| 3 | New public module `Qx.Hardware.Ibm` | MET | `lib/qx/hardware/ibm.ex:1` |
| 4 | New public module `Qx.Hardware.Portal` | MET | `lib/qx/hardware/portal.ex:1` |
| 5 | New public module `Qx.Hardware.NoMeasurementsError` | MET | `lib/qx/errors.ex:149` |
| 6 | New public module `Qx.Hardware.ConfigError` | MET | `lib/qx/errors.ex:176` |
| 7 | Migration of IBM REST client from kino_qx → `Qx.Hardware.Ibm` | MET | `lib/qx/hardware/ibm.ex` — full Qiskit Runtime client present |
| 8 | Migration of `/me` + `/transpile` portal calls → `Qx.Hardware.Portal` | MET | `lib/qx/hardware/portal.ex` — `me/1` + `transpile/3` present |
| 9 | Delete `Qx.Remote`, `Qx.Remote.Config` | MET | both deleted per `git diff --name-status main` (D `lib/qx/remote.ex`, D `lib/qx/remote/config.ex`) |
| 10 | Delete `test/qx/remote_test.exs` | MET | deleted per git diff (D `test/qx/remote_test.exs`) |
| 11 | Delete `examples/remote/run_on_hardware.exs` | MET | deleted per git diff (D `examples/remote/run_on_hardware.exs`) |
| 12 | `mix.exs`: add `{:bypass, "~> 2.1", only: :test}` | MET | `mix.exs:61` |
| 13 | `mix.exs`: pin `{:jason, "~> 1.4"}` | MET | `mix.exs:53` |
| 14 | CHANGELOG entry (BREAKING) + version bump to 0.7.0 | MET | `CHANGELOG.md:10` `[0.7.0] - 2026-05-14` with `### BREAKING` block; `mix.exs:7` `version: "0.7.0"` |
| 15 | `Qx.Hardware.run/3` — signature + return type | MET | `lib/qx/hardware.ex:128-135` `@spec run(QuantumCircuit.t(), Config.t(), opts()) :: {:ok, SimulationResult.t()} \| error()` |
| 16 | `Qx.Hardware.run!/3` — bang variant | MET | `lib/qx/hardware.ex:140-147` |
| 17 | `Qx.Hardware.transpile/3` — circuit or string input | MET | `lib/qx/hardware.ex:191-214` — two-clause multifunction handles both types |
| 18 | `Qx.Hardware.list_backends/1(config)` | MET | `lib/qx/hardware.ex:220-230` — implemented as `list_backends/2` with defaulted opts; API-compatible with `list_backends/1` call sites |
| 19 | `Qx.Hardware.submit_qasm/3` | MET | `lib/qx/hardware.ex:158-184` |
| 20 | `Qx.Hardware.cancel/2(job_id, config)` | MET | `lib/qx/hardware.ex:235-245` — implemented as `cancel/3` with defaulted opts; API-compatible |
| 21 | Lazy-connect: if `identity == nil` OR `backends_list == []`, run `Portal.me/1` + `Ibm.list_backends/1` first | MET | `lib/qx/hardware.ex:267-285` — two `ensure_connected` clauses guard on `identity: nil` and `backends_list: []` |
| 22 | Pre-flight measurement check raising `Qx.Hardware.NoMeasurementsError` | MET | `lib/qx/hardware.ex:420-423` `check_measurements/1`; `run/3` at line 131 calls it |
| 23 | Pipeline: `iam_exchange` → `fetch_backend_configuration` → `Portal.transpile` → `submit_sampler` → `poll_job` → `fetch_results` → `ResultBuilder.from_counts/3` | MET | `lib/qx/hardware.ex:170-183` — `with` chain matches exact sequence |
| 24 | Status callback `{:portal, :transpiling}` | MET | `lib/qx/hardware.ex:341` |
| 25 | Status callbacks `{:ibm, :authenticating \| :fetching_backend \| :submitting \| :polling \| :fetching_results}` | MET | lines 331, 336, 355, 397, 360 respectively |
| 26 | Status callback `{:ibm, :job_started, job_id}` | MET | `lib/qx/hardware.ex:177` |
| 27 | Error normalisation to `{:error, {stage, reason}}` | MET | `lib/qx/hardware.ex:364-370` — `stage/2` helper wraps all HTTP calls |
| 28 | `optimization_level` validated in `0..3` | MET | `lib/qx/hardware/config.ex:250` `when level in 0..3` |
| 29 | `shots` validated in `1..100_000` | MET | `lib/qx/hardware/config.ex:260` `when is_integer(shots) and shots in 1..100_000` |
| 30 | `ibm_region` validated against allowlist `["us-east","us-south","eu-de","eu-es","jp-tok","au-syd"]` | MET | `lib/qx/hardware/config.ex:136` `@ibm_region_allowlist ~w(us-east us-south eu-de eu-es jp-tok au-syd)` |
| 31 | `portal_url` valid URI with scheme `http` or `https` | MET | `lib/qx/hardware/config.ex:229-248` `validate_portal_url/1` — uses `URI.new/1` + scheme guard |

**Summary**: 31 MET · 0 PARTIAL · 0 UNMET · 0 UNCLEAR
