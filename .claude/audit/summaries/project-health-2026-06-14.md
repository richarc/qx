# Qx — Project Health Audit

**Date:** 2026-06-14
**Commit audited:** `797c6ed`
**Version:** 0.8.0
**Auditors:** 5 specialists (architecture, performance, security, tests, dependencies)
**Consolidation:** `elixir-phoenix:context-supervisor`

---

## Executive Summary

**Overall health: 76 / 100 — grade C (B-minus).**
Equal-weighted mean of the five category scores (82, 44, 84, 84, 86). The B-to-A categories (deps, security, tests, architecture) are stable and well-tended; the project's grade is dragged down almost entirely by one category — **Performance, at 44/100, with 6 CRIT findings clustered around Iron Laws #3 and #5.**

For a quantum-simulator library where the hot path *is* the product, performance is load-bearing. The library compiles cleanly, has 81.4 % test coverage, no known CVEs, and no rogue processes — but the Nx kernels in `lib/qx/calc_fast.ex` and the host-side `2^n` loops in `lib/qx/simulation.ex` are below what the stated Iron Laws require, and limit the largest qubit count the library can usefully reach without OOM.

**What to do first.** One focused refactor (Recommendation 1) unlocks three of the CRIT findings simultaneously. That, plus the test-tolerance fix (Recommendation 3 — 20 minutes), would lift the project to roughly 85/100 (B) without touching anything else.

---

## Category Scores

| Category | Score | Grade | Verdict |
|---|---:|:---:|---|
| Architecture | 82 | B | Clean layering; one 4-module cycle around `tables ↔ register ↔ qubit ↔ draw`; 27 raw `ArgumentError` sites on the public surface (Iron Law #7). |
| **Performance** | **44** | **F** | **Critical.** Gather+select `defn` kernels (Iron Law #3) and host-side `2^n` loops (Iron Law #5) throughout the simulator. SWAP/CR* materialise `2^n × 2^n` matrices → OOM above n≈10. |
| Security | 84 | B | No CRIT/HIGH. Plaintext `http://` accepted for portal token; QASM parser has unbounded recursion depth; one untyped float-parse error. No `String.to_atom/1`, no hardcoded secrets, no `verify: :verify_none`. |
| Test Health | 84 | B | Coverage 81.4 % (above 80 % gate). Suite: 851 tests + 243 doctests, 0.9 s, 0 failures. Three sub-ε `:c64` tolerances (1e-12 / 1e-10 / 1e-6) pass only because fixtures use exact-representable amplitudes. |
| Dependencies | 86 | B | No CVEs, no unused deps, dev/test isolation perfect, permissive licenses. `nx` and `complex` 2 minors behind; `exla`/`emlx` are commented-out dead weight. |

---

## Critical Findings (CRIT) — 6 items

All from performance (4) and tests (2). Detailed locations and rationale are in `.claude/audit/reports/perf-audit.md` and `test-audit.md`.

| # | Location | Issue |
|---|---|---|
| C1 | `lib/qx/calc_fast.ex:67–91` | Single-qubit gate uses `Nx.take` gather + double `Nx.select` — Iron Law #3 violation. O(2^n) binary traversal per gate on `Nx.BinaryBackend` (the default since EXLA is commented out). |
| C2 | `lib/qx/calc_fast.ex:114–143, 157–185, 187–229` | CNOT / CSWAP / Toffoli use the same gather+select+rebuild pattern. Allocate 4–6 full-size index tensors per gate. |
| C3 | `lib/qx/simulation.ex:552–572, 575–599` | `calculate_measurement_probability` + `collapse_to_measurement`: host loop `for i <- 0..(2^n - 1)` with `Nx.to_number` per amplitude, per shot. ~1 M host syncs for 1024 shots × n=10. |
| C4 | `lib/qx/draw/svg/charts.ex:31–69, 103–137` + `lib/qx/draw/vega_lite.ex:32–50, 102–109` | Probability bars / histograms materialise every basis state with no cap. At n=20: 1 M-bar SVG (>100 MB) crashes browsers. |
| C5 | `test/qx/cswap_iswap_matrix_test.exs:33` | `@delta 1.0e-12` against `:c64` (ε ≈ 1.2e-7) — Iron Law #8. Passes only on integer/`±i` matrices. |
| C6 | `test/qx/export/openqasm/round_trip_test.exs:8` | `@tolerance 1.0e-10` on two `:c64` statevectors — same Iron Law #8 issue; flake-prone the moment fixtures get richer. |

## High Findings (HIGH) — 16 items

Summary only; full table in `.claude/audit/summaries/consolidated.md`.

- **Untyped errors on the public surface (5 findings)** — `Qx.Validation` (3 helpers carrying in-source Iron Law #7 TODOs), `Qx.Register` (11 sites), `Qx.Draw.SVG.Circuit` reached via public `Qx.Draw.circuit/2` (5 sites), `Qx.Export.OpenQASM.to_qasm` (1), `Qx.Export.OpenQASM.Parser.String.to_float/1` (1).
- **Host-side `2^n` performance hotspots (6 findings)** — SWAP/iSWAP/CP/CY/CRx/CRy/CRz materialise full `2^n × 2^n` gate matrices (`simulation.ex:402–431` + `gates.ex:331–569`); `state_init` and `result_builder` build `2^n`-element Elixir `[%Complex{} | …]` lists; `Enum.scan` + `Enum.find_index` sampling at O(shots × 2^n); `++ [new]` quadratic append in `quantum_circuit.ex` (5 sites).
- **Memory blow-up in `run_with_conditionals`** — retains 100 k × ~16 MB states until reduce finishes.
- **IBM Quantum client robustness** — 30 s timeout, `retry: false`, no streaming on multi-MB Sampler V2 result bodies.
- **QASM parser unbounded recursion** — `((((…))))` walks half a million parser frames before erroring.

## MED / LOW summary (counts)

| Severity | Arch | Perf | Sec | Test | Deps | Total |
|---|---:|---:|---:|---:|---:|---:|
| CRIT | 0 | 4 | 0 | 2 | 0 | **6** |
| HIGH | 4 | 8 | 2 | 1 | 0 | **15** |
| MED  | 2 | 1 | 4 | 1 | 1 | **9** |
| LOW  | 2 | 1 | 4 | 4 | 3 | **14** |

---

## Cross-Category Correlations

Findings where two or more auditors approached the same problem from different angles:

1. **Iron Laws #3 + #5 cluster (perf)** — six perf findings share one root cause. Replacing `CalcFast` gather+select with reshape + tensor contraction also kills `SWAP`/`iSWAP`/`CP`/`CY`/`CR*` matrix materialisation and the host loops in `Gates.swap/3` and friends. **One fix, ≥ 3 CRIT/HIGH findings retired.**
2. **`ArgumentError` leakage (arch ↔ security)** — architecture flagged 27 raw `ArgumentError` sites on the public surface; security found the QASM parser's `String.to_float/1` (`parser.ex:568`) is one of them. They share a single remedy: route everything through `Qx.*Error` (Iron Law #7).
3. **`:c64` tolerances (test ↔ perf)** — three sub-ε tolerances pass today only because the test matrices use exact-representable amplitudes. The same kernel rewrite that makes the simulator faster (Recommendation 1) will produce non-bit-exact amplitudes, so these tests *will* flake unless widened first.
4. **IBM Quantum client (security ↔ perf)** — security flagged plaintext `http://` acceptance and unvalidated `:base_url` / `:iam_url` test hooks; perf flagged tight `receive_timeout: 30_000` with `retry: false`. Both feed a single hardening pass on `lib/qx/hardware/{config,ibm}.ex`.
5. **QASM parser surface (security ↔ arch)** — parser has unbounded recursion (security), untyped float error (security ↔ arch), and `codegen.ex` emits bare `def` rather than `defmodule` (security). Three findings; one defensive-grammar pass closes them.

---

## Top 5 Recommendations (priority order)

1. **Refactor `CalcFast` kernels to reshape + contraction.**
   Files: `lib/qx/calc_fast.ex:67–229`, then route `SWAP`/`iSWAP`/`CP`/`CY`/`CR*` through a shared 4×4 direct kernel in `lib/qx/simulation.ex:402–431` and retire the matrix-builder loops in `lib/qx/gates.ex:331–569`.
   Effort: ~3–4 h. Unlocks: C1, C2, three HIGH allocation/loop findings. Lifts perf score by an estimated ~25 points on its own.

2. **Vectorise measurement probability + state collapse.**
   Files: `lib/qx/simulation.ex:552–572, 575–599`. Eliminates ~1 M host syncs per 1024-shot run.
   Effort: ~1–2 h. Unlocks C3.

3. **Widen sub-ε `:c64` tolerances and add non-integer fixtures.**
   Files: `test/qx/cswap_iswap_matrix_test.exs:33` (→ `1.0e-6`), `test/qx/export/openqasm/round_trip_test.exs:8` (→ `1.0e-6`), `test/qx/u_gate_convention_test.exs:24` (boundary case).
   Effort: ~20 min. Unlocks C5, C6 — and is a prerequisite for Recommendation 1 (otherwise the kernel rewrite breaks these tests by luck-reversal).

4. **Route `ArgumentError` → typed `Qx.*Error` across the public surface.**
   Files: `lib/qx/validation.ex:127, 152, 165` + `lib/qx/register.ex` (11 sites) + `lib/qx/draw/svg/circuit.ex` (5 sites) + `lib/qx/qubit.ex:290` + `lib/qx/draw.ex` (4) + `lib/qx/export/openqasm.ex:177` + `lib/qx/export/openqasm/parser.ex:568`.
   Effort: ~2 h, ~20 call sites. Closes Iron Law #7 across the codebase and resolves security finding #3.

5. **Cap draw charts above n≈12 + harden IBM client.**
   Files: `lib/qx/draw/svg/charts.ex`, `lib/qx/draw/vega_lite.ex` (raise typed error or auto-truncate when `2^n` rows would exceed a cap), `lib/qx/hardware/config.ex:42, 112–113, 237` (force `https://`, validate test-hook URLs), `lib/qx/hardware/ibm.ex:91–93, 432–434` (60 s timeout on `/results`, `retry: :safe_transient` on GETs).
   Effort: ~1.5 h. Closes C4 and the 4 MED/LOW security findings around the hardware client.

## Quick wins (< 30 min each)

- Update stale `coveralls.json:16` comment ("66.4 %" → "81.4 %"). ~5 min.
- Replace `:math.pow(2, n) |> trunc/1` with `Integer.pow(2, n)` across `state_init.ex`, `quantum_circuit.ex`, `simulation.ex`, `gates.ex`, `validation.ex`. ~15 min.
- Flip 16 pure-compute test files to `async: true`. ~10 min, ~10–15 % suite-runtime win.
- Migrate 3 deprecated `Qx.Math.basis_state/2` test calls at `test/qx/math_test.exs:303,311,319` — unblocks `--warnings-as-errors`. ~5 min.
- Decide whether `Qx.StateInit` is public (it's used by `examples/tutorials/systems_of_qubits_and_entanglement.livemd:534`) or `@moduledoc false`. Right now it's ambiguous and at risk of a silent breaking change. ~10 min.
- Either delete the `# {:exla, …}` / `# {:emlx, …}` comments in `mix.exs`, or actually wire them with `optional: true` and `Code.ensure_loaded?` guards. The current half-state is misleading. ~10 min.

---

## Action Plan

### Immediate (this week)
- Recommendation 3 (tolerances, 20 min) — prerequisite for #1.
- Quick win: `coveralls.json` comment, `:math.pow`, deprecated `basis_state` calls.

### Short-term (next plan cycle)
- Recommendation 1 (`CalcFast` reshape+contract). This is the highest-leverage change in the report. Worth its own plan slug.
- Recommendation 2 (vectorise measurement). Bundle with #1 or follow immediately.
- Recommendation 4 (typed errors). Mechanical but touches 20 + sites — own plan, own commit.
- Run `mix bench` after each kernel change (Iron-Law post-action follow-up).

### Long-term (this roadmap version)
- Recommendation 5 (draw caps + IBM client hardening).
- Plan a deliberate `nx` widening to `~> 0.12` with full `/phx:verify` — the 2-minor lag is OK now but will become a release-time chore.
- Decide the EXLA story (`Recommendation` Quick Win above): either commit to it as an optional dep or remove the breadcrumbs.

---

## Reports

- `.claude/audit/reports/arch-review.md`
- `.claude/audit/reports/perf-audit.md`
- `.claude/audit/reports/security-audit.md`
- `.claude/audit/reports/test-audit.md`
- `.claude/audit/reports/deps-audit.md`
- `.claude/audit/summaries/consolidated.md` (cross-category synthesis)
