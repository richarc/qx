# Consolidated Summary

**Strategy**: Index (total input under 8k tokens; all BLOCKER/WARNING items kept in full)
**Input**: 4 files (elixir.md, testing.md, iron-laws.md, requirements.md), ~4k tokens (.requirements-input.md excluded per instructions)
**Output**: ~2k tokens (~50% reduction)

## Requirements Coverage

(verbatim from requirements.md)

## Requirements Coverage (from plan .claude/plans/calcfast-reshape-kernels/plan.md, D1 as amended)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| D1 | Rank-n axis slicing, no Nx.take/Nx.select, one shared primitive | MET | `calc_fast.ex:11-41` axis comment; `in_axes/on_controls/halves` at :253-268; no take/select in file; static guard test `simulation_slicing_kernels_test.exs:181` |
| D2 | Static qubits/n via opts + deftransformp; gate stays tensor | MET | `calc_fast.ex:208-243` (defnp with opts, deftransformp builders) |
| D3 | Existing tests unmodified; ArgumentError for bad qubits, length mismatch, oversized gate | MET | git diff --stat shows no existing test file modified; `validate_qubits!` :308-326; `validate_2x2!` :329; single-qubit wrapper :62-68 |
| D4 | Keep num_qubits == 1 head | MET | `calc_fast.ex:62` |
| D5 | New numeric assertions at 1.0e-6 | MET | `calc_fast_slicing_test.exs:25` `@tolerance 1.0e-6` |
| R1 | BinaryBackend win measured; STOP if slower | MET | spike table in scratchpad; D1 amended; `research/bench-comparison.md`; CHANGELOG figures |
| R2 | Axis-order oracle tests, all orderings, non-adjacent | MET | `calc_fast_slicing_test.exs:128-290` (CNOT/CCX/CSWAP/CU/SWAP/iSWAP vs Gates/embed oracles) |
| R3 | EXLA cache growth noted in comment | MET | `calc_fast.ex:34-38` notes per-(qubits,n) compile (n^k growth not stated explicitly) |
| R4 | Check sub-1e-6 tolerances | MET | scratchpad P2-T1 grep result |
| Scope-In: calc_fast.ex entry points | Four existing entry points same names/arities on slicing + new ones | MET | `calc_fast.ex:62,94,120,146,159,185,199` |
| Scope-In: calc.ex delegators | MET | `calc.ex:135,145,155` |
| Scope-In: simulation.ex routing | cz/swap/iswap/controlled-target via kernels | MET | `simulation.ex:557-564,597`; no Nx.dot/Gates.swap/iswap/controlled_gate left |
| Scope-In: kernels_bench + mix bench alias | MET | `bench/kernels_bench.exs`; `mix.exs:150-160` (kernels in @bench_suites) |
| Scope-Out respected (Register, measurement, registry, public API) | MET | diff touches none of register.ex, measurement, gates.ex |
| P0 T1-T3 baselines + kernels bench | MET | `research/baseline/{ghz,qft,renormalization,kernels,commit}.txt` |
| P1 T1-T2 spike + R1 gate | MET | scratchpad P1 table; D1 amended |
| P2 T1-T8 tests first | MET | `calc_fast_slicing_test.exs` (CU :214, swap :255, iswap :273, invalid :321); `simulation_slicing_kernels_test.exs:140-192` (QFT, mixed, steps, static guard). Red-first not verifiable from diff (UNCLEAR on that sub-point only) |
| P3 T1-T5 kernel implementation | MET | `calc_fast.ex:208-300`; delegators; existing tests untouched. Green run not re-verified here |
| P4 T1-T3 route Simulation | MET | `simulation.ex:557-564,597`. Full-suite green / docs-warning count not re-run here |
| P5-T1 after benches + comparison | MET | `research/after/*.txt`, `research/bench-comparison.md` |
| P5-T2 CHANGELOG Performance entry | MET | `CHANGELOG.md` [Unreleased] > Performance |
| P5-T3 ROADMAP two lines | MET | CalcFast item ticked `[x]`; matrix item amended, left unticked |
| P5-T4 /phx:verify -> /phx:review | IN PROGRESS | review underway (not counted UNMET) |

**Summary**: 22 MET · 0 PARTIAL · 0 UNMET · 0 UNCLEAR (P5-T4 in progress, excluded)

## Key Findings

### BLOCKER

None (elixir, testing, iron-laws all report none).

### WARNING

**W1. `num_qubits == 1` clause skips qubit and gate validation** (calc_fast.ex:62-65)
- Found by: iron-laws (rated LOW, "not a law", pre-existing), elixir (WARNING), testing (WARNING)
- Deconfliction: per priority instructions the iron-laws finding is kept as the classification source. Its LOW rating and "pre-existing" claim conflict with elixir's and testing's view that this is new code on this branch with a correctness gap. Treat as WARNING until the pre-existing claim is verified against git history.
- Detail: `target_qubit` is ignored, so `apply_single_qubit_gate(s, g, 5, 1)` silently succeeds. Gate shape and state length are not checked. Docs promise ArgumentError for an out-of-range target. The "only top-left 2x2 is read" note is false on this path because `Nx.dot` uses the whole matrix.
- Fix: call `validate_qubits!([target_qubit], 1)` and `validate_2x2!` in this clause, or drop the special case (`Tuple.duplicate(2, 1)` gives `{2}`, so the general kernel should handle n=1).
- Also needed: an n=1 oracle test (testing: no n=1 case exists; tests use n=3,4,5).

**W2. `apply_single_qubit_gate` n>1 path does not call `validate_2x2!`** (calc_fast.ex:62-75)
- Found by: elixir
- A 4x4 gate is silently truncated to its top-left block. `apply_controlled_gate` does validate, so behaviour is inconsistent. Documented, but inconsistent.

**W3. Benchmark file stale after this branch** (bench/kernels_bench.exs:9-13, :25-37)
- Found by: elixir
- Header still says "once those gates are routed through the contraction kernel". The `matrix?` flag and `QX_BENCH_MAX_MATRIX_N` cap are obsolete because CP/CRY/SWAP/iSWAP no longer build 2^n x 2^n matrices. The cap limits benchmarks to n<=10 for the gates this branch speeds up. Remove the cap and header text.

**W4. No invalid-input tests for `apply_single_qubit_gate/4`** (calc_fast_slicing_test.exs)
- Found by: testing
- Impl documents ArgumentError for out-of-range target, wrong state length, and non-2x2 gate. Add `assert_raise ArgumentError` cases for target >= n, negative target, 4x4 gate, and bad `num_qubits` (0, non-integer).

**W5. `assert_raise` calls have no message match** (calc_fast_slicing_test.exs:321-358)
- Found by: testing
- Wrong validation branch or incidental Nx ArgumentError would still pass. Add regex messages (e.g. `~r/distinct/`). Pin: state length mismatch, non-integer index (1.0), out-of-range index.

**W6. Static guard in simulation test is brittle** (simulation_slicing_kernels_test.exs:187-190)
- Found by: testing
- Regex catches only literal `Gates.name(` calls. Misses `import Gates` or `&Gates.swap/3`. Could false-positive on docs or strings. Treat as a tripwire only; behavioural tests are the real protection.

## Suggestions (compressed)

**Test structure and coverage** (testing)
- Replace the stripped-comment guard (simulation_slicing_kernels_test.exs:171-191) with `Code.string_to_quoted` plus an AST walk for remote calls to `Nx.take`/`Nx.select`. Current guard would false-positive on trailing comments or `@doc` heredocs. calc_fast.ex moduledoc mentions old kernels, so this is a latent hazard.
- Move `defp code_lines` out of the `describe` block (simulation_slicing_kernels_test.exs:171) to module level.
- Add a per-kind loop of single-gate circuits after an H layer (cp, cy, cz, crx, cry, crz, swap, iswap). Currently kinds appear only in `@mixed` and QFT, so failures are not attributable.
- `run/2` with shots and measurement is not exercised for new kinds. Optional if it shares dispatch.
- Add n=2 cases for CX, SWAP, iSWAP in `pair_cases` (calc_fast_slicing_test.exs:239-252). Currently n=2 is tested only for controlled gates.
- Seed formulas collide across n (calc_fast_slicing_test.exs:181,195). Harmless; `:erlang.phash2({n, qubits})` would be cleaner.
- Confirm doctest directive: `grep -n doctest test/qx/calc_fast_test.exs` (not checked by reviewer).
- Oracle reports max error only, not location. Acceptable.
- Oracle design is sound: embed/3 is bit-arithmetic, and Gates builders are an independent cross-check. Toffoli oracles are test-local only (acceptable).

**Kernel and API readability** (elixir)
- Add a test calling kernels inside `Nx.Defn.jit/2` with `compiler: Nx.Defn.Evaluator` to guard against tensors passed as static qubits. EXLA is not a dependency, so EXLA behaviour is UNVERIFIED.
- Validation predicate at calc_fast.ex:308-327 is dense. Extract a `valid_qubit?/2` helper. With n=1 and two qubits, the error reads "out of range" rather than something clearer.
- `Nx.tensor(Complex.new(0, 1), type: Nx.type(tensor))` at calc_fast.ex:293 would pin dtype if c128 is ever used. Currently correct.
- Calc docs (calc.ex:105-157) do not mention ArgumentError. Minor.
- `hd(params)` in simulation.ex dispatch crashes on empty params. Pre-existing style.

**Mix task** (elixir)
- mix.exs:148-162: `Mix.Task.rerun` is correct. Alias ignores args (fine as `_args`). Consider moving `@bench_suites` above first use for readability.

**Positive** (elixir, iron-laws)
- Defnp to deftransformp to defp-closure pattern is sound under Nx.Defn.Evaluator and EXLA (trace-time only).
- swap_axes pinned patterns are idiomatic (calc_fast.ex:280-286).
- Dispatch is complete: all two-qubit and three-qubit shapes from Qx.Operations and lowering have arms (simulation.ex:550-598). Iron-laws: 0 violations across laws 1-9.
- Iron-laws spot check: test file references cy/cp/cr*/iswap/cswap/ccx 26 times, but test bodies were not read for end-to-end execution. Spot-check recommended.

## Pre-existing

- lib/qx/simulation.ex:502: credo CyclomaticComplexity disable retained (elixir).
- Laws 6 and 7 (CHANGELOG, version) not re-verified (iron-laws).

## Coverage

| File | Represented | Key Items |
|---|---|---|
| elixir.md | Yes | 3 WARNING, 7 SUGGESTION groups, 1 pre-existing |
| testing.md | Yes | 4 WARNING, 6 SUGGESTION, 1 doctest check |
| iron-laws.md | Yes | 0 violations, 1 LOW (merged into W1), notes |
| requirements.md | Yes | Coverage block verbatim, 22 MET, minor notes |
| .requirements-input.md | Excluded | Ignored per instructions |

## Coverage Gaps

- None.
