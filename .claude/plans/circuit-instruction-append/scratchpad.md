# Scratchpad: circuit-instruction-append

## Decisions

- **2026-11-14 (user):** rename the field. Options offered: rename
  (chosen), reverse in place under the same name (silently breaking),
  defer to 1.0, batch appends in `Qx.Patterns` only (non-breaking, partial).
- **2026-11-14 (user, via the same choice):** existing tests may be edited
  for the field rename. Scope of that approval: access-path changes only
  (plan Phase 3). Anything else needs a new approval.
- **2026-11-14 (plan, open for the user):** `measurements` stays as is
  (D6); no custom `Inspect` (D7).
- **Research** (research/hex-library-researcher-report.md): no new
  dependency. `Kernel.++/2` docs: cost proportional to the left list;
  prepend then reverse is the documented idiom. `:queue` and `:array` are
  opaque, not lists. Hex: `qex` wraps `:queue`; `persistent_vector` (2017),
  `deque` (2018), `arrays_rrb_vector` (Rust NIF, 2022) are not candidates.
  No dependency in `deps/` references `Qx.QuantumCircuit`.

## Current code facts (2026-11-14, main @ 42ff62c)

- `++ [x]` on `instructions`: `lib/qx/quantum_circuit.ex` lines 122, 148,
  168, 210, 221, 234. On `measurements`: line 208.
- Readers/writers of the field in `lib/`:
  - `lib/qx/simulation.ex:655` (`has_conditionals?/1`, `Enum.any?`),
    `:695` (`create_instruction_timeline/1`).
  - `lib/qx/operations.ex:842,848` (`c_if/4`: clears, runs the function,
    reads back), `:1058` (`Enum.any?` for `c_if`), `:909` (doc example).
  - `lib/qx/draw/svg/circuit.ex:91, 158, 181`.
  - `lib/qx/export/openqasm.ex:219, 275` (pattern-match in function heads).
  - `lib/qx/export/openqasm/lowering.ex:98` (already accumulates newest
    first in its own state, then `Enum.reverse` into the struct).
  - `lib/qx.ex:1885` (doc example).
  - `lib/qx/quantum_circuit.ex`: `new/2`, `get_instructions/1`, `depth/1`,
    `reset/1` and its doctest.
- Existing tests: 8 sites build a circuit with `instructions:`
  (`simulation_typed_errors_test.exs` ×5, `typed_errors_sweep_test.exs` ×2,
  `export/openqasm_test.exs` ×1, plus `round_trip_test.exs:23`); 22 read
  `.instructions` (`lowering_test.exs` ×17, `openqasm_import_test.exs` ×2,
  `codegen_test.exs`, `round_trip_test.exs`, `simulation_steps_test.exs`).
- No `Inspect` impl for `Qx.QuantumCircuit`; `Kino.Render` goes through the
  SVG renderer (`lib/qx/draw/kino_render.ex:6`).
- `kino_qx`, `qxportal`: no use of `.instructions`, `get_instructions` or
  `.measurements`.

## Measurements

### Baseline build time (2026-11-14, OTP 29, Elixir 1.20.2, dev env, best of 3)

`Enum.reduce(1..n, Qx.create_circuit(4), &Qx.h(&2, rem(&1, 4)))` against the
same loop with validation and a prepend:

| n | `++` (current) | prepend |
|---|---|---|
| 100 | < 0.1 ms | < 0.1 ms |
| 1,000 | 1.2 ms | < 0.1 ms |
| 5,000 | 29.6 ms | 0.2 ms |
| 10,000 | 142.2 ms | 0.4 ms |
| 20,000 | 728.0 ms | 0.7 ms |
| 50,000 | 4,806 ms | 1.9 ms |
| 100,000 | 19,187 ms | 2.5 ms |

- 5,000 `Qx.measure/3` calls (two appends each): 309.9 ms.
- Script (not committed):
  `/private/tmp/claude-501/-Users-richarc-Development-qxquantum-qx/c7c63220-39c7-4402-9bd2-18e7b0134bd1/scratchpad/append_bench.exs`.

### Complexity-test metric (task 1.5, 2026-11-14, OTP 29, Elixir 1.20.2, dev env)

Three fresh VMs each; reductions spread under 0.1% between runs.
"public" = `Qx.h/2` loop on current code (`++`). "proxy" = validate +
prepend onto the field. "no-accumulate" = `Qx.h/2` with the result
discarded (per-call cost without the growing list).

Whole build, reductions (per gate) and wall-clock:

| n | public (`++`) | proxy (prepend) | no-accumulate |
|---|---|---|---|
| 5,000 | 983,078 (196.6) / 32 ms | 35,141 (7.0) / 0.3 ms | |
| 10,000 | 3,681,409 (368.1) / 146 ms | 64,878 (6.5) / 0.7 ms | |
| 20,000 | 8,821,741 (441.1) / 714 ms | 118,426 (5.9) / 1.1 ms | 210,575 (10.5) / 0.6 ms |
| 50,000 | 32,201,646 (644.0) / 4,833 ms | 265,430 (5.3) / 3.0 ms | 525,812 (10.5) / 1.5 ms |
| 100,000 | 114,963,523 (1,149.6) / 19,346 ms | | 1,051,208 (10.5) / 3.0 ms |

Second 50,000 gates only (gates 50,001–100,000), reductions per gate:
public 1,654.07 / 1,654.36 / 1,653.94 (14.5 s); proxy 4.78 / 4.78 / 4.80.

- Plan's first choice (whole build, 20,000 gates): 8.82M vs about 0.21M
  expected = 42×. No threshold is 10× from both. Rejected.
- Whole build at 100,000: about 100×, borderline. Rejected.
- **Chosen: marginal cost of the second 50,000 gates, limit 140 reductions
  per gate.** Today 1,654 (11.8× over the limit). Expected after the change
  about 11 (10.5 per call + list work), 12× under. Actual post-change figure
  is recorded below once Phase 2 is done; if it is above 14, report it.
- Wall-clock fallback not needed (50,000 gates: 4.8 s vs about 3 ms).
- The red run of this test takes 19 s (it builds 100,000 gates on `++`).
  `@tag timeout: 300_000` so a regression fails on the assertion, not the
  ExUnit timeout.
- Scripts (not committed):
  `/private/tmp/claude-501/-Users-richarc-Development-qxquantum-qx/8de38358-4dbd-4f16-a40c-52b4401fff83/scratchpad/complexity_metric.exs`,
  `complexity_metric2.exs`, `complexity_metric3.exs` in the same directory.

### After the change (2026-11-14, same machine, three fresh VMs)

- Second 50,000 gates: 8.64 / 8.64 / 8.65 reductions per gate (3.3 ms).
  Limit 140 is 16.2× above this and 11.8× below the old 1,654.
- Build time, `Qx.h/2` loop, 4 qubits, best of 3: 1,000 → 0.06 ms;
  5,000 → 0.37 ms; 10,000 → 0.6 ms; 20,000 → 1.3 ms; 50,000 → 3.6 ms;
  100,000 → 7.6–8.1 ms.
- 5,000 `Qx.measure/3` calls: 31.6 ms (was 309.9 ms). What is left is the
  `measurements ++ [m]` append (D6).
- New test file: 17 pass in 0.1 s.
- Script: `after.exs` in the same scratchpad directory as the others.

### Existing test files touched (task 3.3; `git diff --stat -- test`)

| File | Lines changed (+/−) |
|---|---|
| `test/qx/export/openqasm/lowering_test.exs` | 17 / 17 |
| `test/qx/typed_errors_sweep_test.exs` | 10 / 10 |
| `test/qx/simulation_typed_errors_test.exs` | 5 / 5 |
| `test/qx/export/openqasm/round_trip_test.exs` | 5 / 2 |
| `test/qx/simulation_steps_test.exs` | 6 / 1 |
| `test/qx/export/openqasm_import_test.exs` | 2 / 2 |
| `test/qx/export/openqasm_test.exs` | 1 / 1 |
| `test/qx/export/openqasm/codegen_test.exs` | 1 / 1 |

All are access-path changes: reads through `get_instructions/1`, writes
through `put_instructions/2`. No expected value changed.

### Docs (tasks 4.1–4.3)

`mix docs` warning list: 12 distinct lines before and after, `diff` empty.

### Red run (task 1.6, 2026-11-14)

`mix test test/qx/quantum_circuit_instruction_order_test.exs`: 17 tests,
14 pass, 3 fail, 19.5 s.

1. "the struct has no `instructions` field": `refute` got true.
2. "put_instructions/2 stores a list…": `UndefinedFunctionError`.
3. "adding a gate to a 50,000-gate circuit…": 1,648.7 reductions per gate,
   limit 140.

## Out of scope / discovered

- `circuit.measurements ++ [measurement]` (`quantum_circuit.ex:208`): same
  pattern, public field. Candidate ROADMAP line if not added here.
- `lib/qx/export/openqasm/codegen.ex:115, 171`: `acc ++ [line]` and
  `acc ++ [name]` inside reduces. Quadratic in exported lines / names.
  Candidate ROADMAP line.
- `spec/API_IMPROVEMENTS_SUMMARY.md:82` shows `c.instructions`; historical
  summary, not updated.
- The ROADMAP wording "reverse-on-finalise" assumes a finalise step. There
  is none: circuits go straight from the builders to run/draw/export, so the
  reverse happens on read.
- The test-file guard hook did not fire on `Write` of the new test file:
  `.claude/settings.local.json` points at
  `/Users/richarc/Development/qx/.claude/hooks/test-file-guard.sh`, which
  does not exist (the repo is now at `…/qxquantum/qx`). The guard is
  currently inactive. Not changed here.
- `test/qx/simulation_steps_test.exs:88` both reads and writes the field
  (`%{qc | instructions: qc.instructions ++ [...]}`); the plan counted it as
  one read.
- `examples/openqasm/import_gate_definition.exs` fails on `main` too
  (exit 1, line 44): the generated module calls `Qx.rx/3`, which resolves to
  `Demo.UserGates.Qx` inside the example's namespace. Candidate ROADMAP line.
- Review cycle 1 (2026-11-14): `examples/openqasm/` had four reads of the old
  field that the work-phase grep missed (output truncated by `head -20`).
  Fixed after review. Mixed-producer build (`h`, `cx`, `ccx`, `barrier`):
  19.47 reductions per gate on the new code.
