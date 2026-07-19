# Qx Consolidated Audit Synthesis

**Strategy**: Compress (40% reduction)
**Input**: 5 auditor reports, ~20.6k tokens
**Output**: ~8.2k tokens (40% compression)

---

## Health Scores Summary

| Category | Score | 1-Line Takeaway |
|---|---:|---|
| **Architecture** | 82/100 | Clean layering overall; one 4-cycle (tables↔register↔qubit↔draw) blocks Draw refactor. 27 untyped `ArgumentError` sites leak internal errors. |
| **Performance** | 44/100 | **CRITICAL.** Gather+select kernels in `CalcFast` violate Iron Law #3; 2^n host loops in measurement/sampling; unbounded draw charts crash at n>12. |
| **Security** | 84/100 | Plaintext HTTP accepts portal token over cleartext; QASM parser unbounded recursion; untyped float parse errors. No atom-table DoS or file-I/O issues. |
| **Test Health** | 84/100 | 81.4% coverage (target 80% met); two CRIT and one HIGH `:c64` sub-epsilon tolerances pass by luck on integer amplitudes; 16 pure-compute files left at default sync. |
| **Dependencies** | 86/100 | No known vulns; `nx` and `complex` are 2 minors behind; `req` widen needed for 0.6; commented `exla`/`emlx` are misleading dead weight. |

---

## Critical Findings (CRIT)

| File:Line | Issue | Auditors |
|---|---|---|
| `lib/qx/calc_fast.ex:67–91` | Single-qubit gate uses `Nx.take` gather + two `Nx.select` calls — violates Iron Law #3 (reshape+contract). O(2^n) Erlang binary traversals per gate. | perf |
| `lib/qx/calc_fast.ex:114–143, 157–185, 187–229` | CNOT / CSWAP / Toffoli kernels same gather+select+rebuild pattern, allocate 4–6 full-size index tensors per gate. | perf |
| `lib/qx/simulation.ex:552–572, 575–599` | `calculate_measurement_probability` + `collapse_to_measurement`: host loop `for i <- 0..(2^n - 1)` with `Nx.to_number` per amplitude, then rebuild state from `%Complex{}` list. Runs per shot: 1M host syncs at 1024 shots × n=10. | perf |
| `test/qx/cswap_iswap_matrix_test.exs:33` | `@delta 1.0e-12` asserted against `:c64` matrices (ε≈1.2e-7) — sub-epsilon tolerance unreachable. Passes only because entries are exact 0/1/±i; future non-integer matrix will flake. | test |
| `test/qx/export/openqasm/round_trip_test.exs:8` | `@tolerance 1.0e-10` on two `:c64` statevectors — Iron Law #8 violation. Passes only because fixture circuits round-trip exactly; richer fixture would flake. | test |
| `lib/qx/draw/svg/charts.ex:31–69, 103–137` + `lib/qx/draw/vega_lite.ex:32–50, 102–109` | Probability bar charts / histograms materialise every basis state (2^n rows) with no truncation, no warning. At n=20: 1M-bar SVG (>100 MB XML, crashes browsers). | perf |

---

## High Findings (HIGH)

| File:Line | Issue | Auditors |
|---|---|---|
| `lib/qx/validation.ex:127, 152, 165` | Three helpers raise raw `ArgumentError` — `validate_qubits_different!`, `validate_state_shape!`, `validate_parameter!` — with in-source Iron Law #7 TODO comments. Public-API entry points (`QuantumCircuit.initialize`, `Operations`). | arch, security |
| `lib/qx/register.ex:92, 100, 163, 168, 510, 538, 569, 657, 680, 704, 746` | 11 sites raise `ArgumentError` (empty-qubit-list, invalid-qubit, basis validation, duplicate indices). Documented as public calc-mode entry point. | arch |
| `lib/qx/draw/svg/circuit.ex:111, 122, 126, 161, 173` | 5 sites raise `ArgumentError` for >20 qubits, invalid index, unsupported gate — reached via public `Qx.Draw.circuit/2` despite `@moduledoc false`. | arch |
| `lib/qx/hardware/ibm.ex:91–93, 432–434` | IAM: 10s `receive_timeout`; all API calls: 30s with `retry: false`. On slow link or multi-MB Sampler V2 result, 30s is tight; transient TCP RST kills call. | perf |
| `lib/qx/export/openqasm/parser.ex:568` | `String.to_float/1` raises raw `ArgumentError` on hostile input like `1e9999` instead of typed `Qx.QasmParseError` — leaks internal stack frames (Iron Law #7). | security |
| `lib/qx/export/openqasm/parser.ex:180–243` | Expression recursion unbounded within 1 MB cap. Blob of `((((((…))))))` walks 0.5 M parser frames, grows BEAM call stack, can `:enomem` before parse error. | security |
| `lib/qx/simulation.ex:467–476` | `generate_samples`: `Enum.scan` cumulative distribution, then per-shot `Enum.find_index` linear scan — O(shots × 2^n) host work. At 100k shots × n=10, 100M+ iterations. | perf |
| `lib/qx/state_init.ex:64–69, 218–223, 341–354, 376–393, 100–103` | `basis_state`, `random_state`, `ghz_state`, `w_state`, all fresh `QuantumCircuit.new`: build `2^n`-element Elixir list of `%Complex{}` structs before `Nx.tensor(_, type: :c64)`. At n=20: 1M-element traversal for |0…0⟩. | perf |
| `lib/qx/result_builder.ex:44–54` | `build_probability_tensor`: builds `2^n` Elixir list, then `List.replace_at` (O(n) per replace) over outcomes — worst case O(2^n × non-zero outcomes). | perf |
| `lib/qx/simulation.ex:402–407, 419–431` | SWAP / iSWAP / CP / CY / CRx / CRy / CRz materialize full `2^n × 2^n` gate matrix via `Gates.swap/3`, `controlled_gate/4` — O(4^n) memory, O(8^n) FLOPs. At n=14: 4.3 GB c64; OOM above ~10 qubits. | perf |
| `lib/qx/gates.ex:331–369, 406–426, 453–474, 499–525, 540–569` | `controlled_gate/4`, `swap/3`, `iswap/3`, `cswap/4`, `toffoli/4` use `for i <- 0..(2^n - 1), reduce:` with `Nx.put_slice` in loop — host-side O(2^n) traversal, one tensor per basis state (Iron Law #5 violation). | perf |
| `lib/qx/quantum_circuit.ex:98, 122, 142, 184, 602` | Every gate/measurement append uses `++ [new]` — O(length) per call → O(N²) to build N-gate circuit. | perf |
| `lib/qx/simulation.ex:142–148, 156` | `run_with_conditionals` materializes list of `{state, cbits}` for every shot before `Enum.frequencies` — at 100k shots × n=20, retains 100k × ~16 MB state until reduce finishes (process killer). | perf |
| `lib/qx/draw.ex:98, 140, 182, 231` | Four `raise ArgumentError, "Unsupported format: #{format}"` for `:format` option (Low severity, mentioned for completeness). | arch |
| `lib/qx/hardware/config.ex:237` | `validate_portal_url` accepts plaintext HTTP — misconfigured `QX_PORTAL_URL=http://…` sends bearer token over cleartext (on-path capture / reuse risk). | security |
| `lib/qx/hardware/config.ex:42, 112–113` | `:base_url` / `:iam_url` test hooks accept any scheme, no validation. Caller setting `base_url: "http://attacker/api/v1"` routes IAM token to attacker host. | security |

---

## Cross-Category Correlations

### Performance ↔ Architecture: Error Leakage Compounding

**The Problem**: Architecture audit flagged 27 untyped `ArgumentError` sites. Security audit found `String.to_float/1` raises raw `ArgumentError` in QASM parser. Performance audit found the parser is used during circuit transpilation, and *any* error surfaced to a user-facing layer (qxportal, Livebook) gets logged verbatim, potentially exposing request context / debug headers.

**Action**: Route `validation.ex` errors through typed `Qx.*Error` (§6 Arch findings), and wrap QASM float parse with `Float.parse/1` or `rescue ArgumentError`.

### Performance: Iron Law #3 + #4 + #5 Cluster

Three Iron Laws align across 6 distinct perf findings:

- **Iron Law #3** (reshape+contract): `CalcFast` gather+select (CRIT × 2), SWAP/iSWAP matrix path (HIGH)
- **Iron Law #4** (BinaryBackend-agnostic): defn discipline OK; performance is the issue, not correctness
- **Iron Law #5** (no host 2^n loops): measurement loops (CRIT), state_init (HIGH), result_builder (HIGH), Gates matrix builders (HIGH), sampling (HIGH)

**One fix unlocks multiple findings**: Replace `CalcFast` gather+select with reshape+contract, then route SWAP/iSWAP/CP/CY/CR* through a shared 4×4 direct kernel. This eliminates 3 matrix-materialisation findings *and* the O(2^n) loop in `Gates.swap/3` etc.

### Performance ↔ Test Health: Tolerances in Real World

Test audit flagged three sub-epsilon `:c64` tolerances (`1.0e-12`, `1.0e-10`, `1.0e-6` at boundary). These pass on integer / exact-representable amplitudes (Bell, GHZ, test matrices with 0/1/±i). Performance audit found that perf tests run under `MIX_ENV=dev`, skipping `assert_norm` gates that would catch drift. Combined: tight tolerances hide the true behaviour on non-integer matrices and non-renormalized states.

**Action**: Widen tolerances to `1.0e-6` and add non-integer fixtures.

### Security ↔ Perf: IBM Client Robustness

Security found test hooks accepting plaintext HTTP (`base_url`, `iam_url`). Performance found hardware client timeouts are tight (30s for large Sampler V2 bodies multi-MB JSON) and has `retry: false` on transient errors. If a slow result fetch hits a transient TCP RST without retry, the entire job fails; adding plaintext hooks invites redirection attacks on that failure path.

**Action**: Harden config validation (force `https`), bump `receive_timeout` to 60s on `/results`, enable `retry: :safe_transient` on GETs.

### Security ↔ Architecture: QASM Parser Risk & Open Codegen

Security flagged QASM parser unbounded recursion (denial of service on deep parens). Architecture audit noted no atom-table DoS (`String.to_atom` not used). But security also found `from_qasm_function/1` produces source for `Code.compile_string/1` without module isolation — a future qxportal / Livebook integration that compiles untrusted QASM in the host module could run attacker-named helper functions.

**Action**: Add explicit parenthesis-depth counter in parser (security finding #4), and wrap generated `def …` in a `defmodule Qx.Generated.<random>` envelope (defence-in-depth, security finding #8).

---

## Top 5 Actionable Recommendations

**Prioritized by (severity × resonance × effort)**:

1. **Reshape `CalcFast` kernels to eliminate gather+select + matrix materialization** (perf CRIT + HIGH cluster)
   - Files: `lib/qx/calc_fast.ex:67–91, 114–143, 157–185, 187–229` + `lib/qx/simulation.ex:402–431` + `lib/qx/gates.ex:331–569`
   - **Unlocks**: CRIT kernel perf, HIGH matrix OOM, HIGH loop in Gates (3 findings)
   - **Effort**: ~3–4 hours (reshape logic + kernel refactor + test)
   - **Impact**: Single-qubit gate 10–100× faster on BinaryBackend, SWAP usable above n=10

2. **Vectorize measurement probability & state collapse** (perf CRIT + Iron Law #5)
   - Files: `lib/qx/simulation.ex:552–572, 575–599`
   - **Unlocks**: ~1M host-sync reduction per 1024-shot measurement
   - **Effort**: ~1–2 hours
   - **Impact**: Conditional measurement circuit execution usable at scale (100k shots × 20 qubits)

3. **Fix `:c64` sub-epsilon tolerances in test suite** (test CRIT + perf stability)
   - Files: `test/qx/cswap_iswap_matrix_test.exs:33`, `test/qx/export/openqasm/round_trip_test.exs:8`, `test/qx/u_gate_convention_test.exs:24`
   - **Unlocks**: Flake-resistant tests, real-world regression detection
   - **Effort**: ~20 minutes (widen tolerances + add non-integer fixtures)
   - **Impact**: CI confidence, future kernel rewrites won't silently break

4. **Route `ArgumentError` through typed `Qx.*Error`** (arch HIGH + security HIGH, Iron Law #7)
   - Files: `lib/qx/validation.ex:127, 152, 165` + `lib/qx/register.ex` (11 sites) + `lib/qx/draw/svg/circuit.ex` (5 sites) + `lib/qx/qubit.ex:290` + `lib/qx/draw.ex` (4 sites) + `lib/qx/export/openqasm.ex:177` + security `parser.ex:568`
   - **Unlocks**: Public API contract enforcement, stack-frame leak closure, security finding #3
   - **Effort**: ~2 hours (define/reuse error types, update 20+ sites)
   - **Impact**: API users can distinguish Qx misuse from other failures; no sensitive data leaks in error messages

5. **Cap / error on draw charts above n≈12 qubits; harden IBM client** (perf HIGH + security MED)
   - Files: `lib/qx/draw/svg/charts.ex`, `lib/qx/draw/vega_lite.ex`, `lib/qx/hardware/config.ex:237, 42, 112–113`, `lib/qx/hardware/ibm.ex:91–93, 432–434`
   - **Unlocks**: Browser crash prevention + transient-error resilience + plaintext-HTTP prevention
   - **Effort**: ~1.5 hours (raise error on n>12, widen timeout, enable retry, tighten validation)
   - **Impact**: Qubits above 12 fail gracefully; hardware jobs survive transient network hiccups

---

## Quick Wins (&lt;30 minutes)

- **Widen `:math.pow` calls to `Integer.pow`**: `lib/qx/state_init.ex:101, 183, 215, 342, 377` + `lib/qx/quantum_circuit.ex:58, 221, 311` + `lib/qx/simulation.ex:553, 576` + `lib/qx/gates.ex:332, 407, 454, 500, 541` + `lib/qx/validation.ex:75` — exact integer math, no float rounding. (Perf: LOW impact but trivial.)

- **Update `coveralls.json` stale comment** (`test-audit.md`): currently says 66.4 %, actual is 81.4 %. (~5 min)

- **Flip 16 pure-compute test files to `async: true`** (test MED): `qx_test.exs`, `complex_support_test.exs`, `cp_gate_test.exs`, `qubit_test.exs`, `math_test.exs`, `format_test.exs`, `controlled_gates_test.exs`, `cswap_gate_test.exs`, `validation_test.exs`, `gates_test.exs`, `calc_test.exs`, `swap_gate_test.exs`, `iswap_gate_test.exs`, `u_gate_test.exs`, `state_init_test.exs`, `export/openqasm_test.exs`. Expected runtime cut ~10–15% (0.3s sync → ~0.2s). (~10 min)

- **Migrate 3 deprecated `Qx.Math.basis_state/2` test calls** → `Qx.StateInit.basis_state/3` (test L1): `test/qx/math_test.exs:303, 311, 319`. Removes compile warning and unblocks `--warnings-as-errors` gate. (~5 min)

- **Wrap QASM parser `String.to_float` in typed error** (security finding #3): `lib/qx/export/openqasm/parser.ex:568`. (~5 min)

- **Resolve `Qx.StateInit` public-API ambiguity** (arch LOW): decide whether to mark `@moduledoc false` (internal-only) or add to `Qx` module list (public). Livebook tutorial uses it; current state risks silent breaking change. (~10 min decision + docs update)

---

## Coverage Gaps

| File | Represented | Key Items |
|---|---|---|
| arch-review.md | Yes | 1 module-cycle, 27 ArgumentError leaks, 1 behaviour abstraction drift |
| perf-audit.md | Yes | 2 CRIT kernels, 8 HIGH allocation/loop issues, 1 draw unbounded-N issue |
| security-audit.md | Yes | 1 plaintext HTTP, 2 test-hook validation gaps, 1 parser unbounded recursion, 1 parser untyped float error |
| test-audit.md | Yes | 3 CRIT sub-epsilon tolerances, 16 async files, 2 0% coverage modules |
| deps-audit.md | Yes | 3 MED dep updates (nx/complex/req), 1 commented-dead-weight (exla/emlx) |

**No coverage gaps detected.**
