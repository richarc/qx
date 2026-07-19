# OpenQASM 3.0 Import — Implementation Plan

**Bead**: qx-0c5
**Target version**: 0.6.0 (minor bump — additive feature, no breaking changes)
**Slug**: `openqasm-import`
**Complexity**: 11 (deep) — new domain concept, public API surface, new dep, ~6 new modules

## Goal

Add `Qx.Export.OpenQASM.from_qasm/1` and `from_qasm_function/1` so Qx can read OpenQASM 3.0 source emitted by itself, by Qiskit, or by IBM Quantum, completing the round-trip with the existing `to_qasm/1`.

## Scope

**In scope** (locked with user):
1. Round-trip: any program `to_qasm/1` produces parses back to an equivalent circuit
2. IBM stdgates: parse all stdgates.inc names and either map directly, decompose, or raise typed unsupported-error
3. `from_qasm_function/1` returns `{:ok, %{name, arity, source}}` where `source` is an Elixir string defining a circuit-transforming function — the form qxportal will store
4. nimble_parsec backend (~1.4)
5. Single quantum + single classical register (matches `Qx.QuantumCircuit`)
6. Conditionals without `else`
7. Parameter expressions: literals, `pi`, `+ - * /`, parens, `sin/cos/tan/exp/ln/sqrt`

**Out of scope** (raise typed error if encountered):
- `def`, `for`, `while`, `switch`, classical types beyond `bit`, `defcal`, `let`, `pragma`, `extern`, `box`, `delay`, `reset`, gate modifiers (`inv`/`pow`/`ctrl`/`negctrl`), annotations, multi-register programs, `else` branches, complex boolean conditions, `iswap` from stdgates (not standard), `rxx`/`ryy`/`rzz`/`rzx` (Qiskit extensions, no Qx equivalent)

## Architecture

```
QASM source (string)
      │
      ▼
┌──────────────────────────┐
│ Parser (nimble_parsec)   │ lib/qx/export/openqasm/parser.ex
│   defparsec :program     │
│   defparsec :gate_def    │
│   → AST nodes            │
└──────────────────────────┘
      │
      ▼ AST
┌──────────────────────────┐
│ Expression evaluator     │ lib/qx/export/openqasm/expr.ex
│   AST node {:expr, ...}  │
│   → float                │
└──────────────────────────┘
      │
      ▼
┌──────────────────────────┐    from_qasm/1 path
│ Lowering                 │ ────────────────────► %Qx.QuantumCircuit{}
│   AST → instructions     │ lib/qx/export/openqasm/lowering.ex
│   - gate name resolution │
│   - decomposition        │
│   - validation           │
└──────────────────────────┘
      │
      ▼ (gate_def AST only)
┌──────────────────────────┐    from_qasm_function/1 path
│ Codegen                  │ ────────────────────► %{name, arity, source: "def ..."}
│   gate AST → Elixir str  │ lib/qx/export/openqasm/codegen.ex
└──────────────────────────┘
```

### File layout

| Path | Purpose | Approx LOC |
|---|---|---|
| `lib/qx/export/openqasm.ex` | Public API: extend with `from_qasm/1`, `from_qasm!/1`, `from_qasm_function/1`, `from_qasm_function!/1` | +120 |
| `lib/qx/export/openqasm/parser.ex` | nimble_parsec grammar → AST | ~500 |
| `lib/qx/export/openqasm/ast.ex` | AST node type docs (no runtime logic; keeps shapes documented) | ~80 |
| `lib/qx/export/openqasm/expr.ex` | Compile-time evaluator for parameter expressions | ~120 |
| `lib/qx/export/openqasm/lowering.ex` | AST → `%QuantumCircuit{}`; stdgate dispatch table; decompositions | ~350 |
| `lib/qx/export/openqasm/codegen.ex` | Gate-def AST → Elixir source string | ~150 |
| `lib/qx/errors.ex` | Add `Qx.QasmParseError`, `Qx.QasmUnsupportedError` | +60 |
| `mix.exs` | Add `{:nimble_parsec, "~> 1.4"}` | +1 |
| `test/qx/export/openqasm/parser_test.exs` | Grammar coverage | ~250 |
| `test/qx/export/openqasm/expr_test.exs` | Expression evaluator | ~80 |
| `test/qx/export/openqasm/lowering_test.exs` | AST → circuit, including decompositions | ~250 |
| `test/qx/export/openqasm/codegen_test.exs` | Gate-def → Elixir source | ~120 |
| `test/qx/export/openqasm/round_trip_test.exs` | `circuit |> to_qasm |> from_qasm` produces matching simulation results | ~150 |
| `test/qx/export/openqasm_test.exs` | Public API smoke + error paths | +80 |
| `test/fixtures/qasm/*.qasm` | Bell, GHZ, QFT(3), Grover(2), one IBM Quantum example | 5 files |
| `CHANGELOG.md` | v0.6.0 entry | +20 |
| `README.md` | "Importing OpenQASM" section | +40 |

### Key design decisions (records to scratchpad)

1. **AST shape**: simple tagged tuples mirroring Qx's instruction format. e.g.
   ```elixir
   {:program, [
     {:openqasm_version, "3.0", line: 1},
     {:include, "stdgates.inc", line: 2},
     {:qreg_decl, "q", 5, line: 4},
     {:creg_decl, "c", 5, line: 5},
     {:gate_call, "h", [], [{:qubit_ref, "q", 0}], line: 7},
     {:gate_call, "rx", [{:expr, :div, [{:expr, :pi}, {:expr, 2}]}], [{:qubit_ref, "q", 1}], line: 8},
     {:measure, {:qubit_ref, "q", 0}, {:cbit_ref, "c", 0}, line: 9},
     {:c_if, {:cbit_ref, "c", 0}, 1, [{:gate_call, "x", [], [{:qubit_ref, "q", 1}], line: 10}], line: 10},
     {:gate_def, "myname", ["theta"], ["a", "b"], [...body...], line: 14}
   ]}
   ```
2. **Symbol whitelisting** — Iron Law 1: NEVER `String.to_atom(gate_name)`. Use a literal `%{"h" => :h, "cx" => :cx, ...}` map; unknown names raise `QasmUnsupportedError`.
3. **Multi-register rejection**: detect during lowering (second qreg/creg → error with line of second decl).
4. **Decomposition**: `tdg`, `sx`, `u1`, `u2` decompose to one or more existing Qx instructions. Decompositions live in lowering.ex as a small lookup function returning a list of instructions.
5. **Codegen output**: The Elixir source emits a function taking `(circuit, q0, q1, ...)` and (if parametric) `(circuit, theta, phi, q0, q1, ...)`. Body is a `|>` pipeline of `Qx.h(q0)`, `Qx.cx(q0, q1)`, etc. Function name = QASM gate name; classical bits cannot appear inside a `gate` body so no measure/c_if codegen needed.

## Iron Law compliance

| Law | How addressed |
|---|---|
| 1. No `String.to_atom` on caller input | Hand-written `%{"h" => :h, ...}` whitelist in `lowering.ex`. Same for parameter-expression function names. |
| 2. No process without runtime reason | Pure function pipeline; no GenServer / Task / Agent. |
| 3. Reshape over gather in `defn` | N/A — no `defn` code in this feature. |
| 4. defn backend-agnostic | N/A. |
| 5. No host loops over 2^n | N/A. |
| 6. CHANGELOG + version bump on public API change | v0.6.0 (minor — additive); CHANGELOG entry mandatory. |
| 7. Typed `Qx.*Error` at boundary | `Qx.QasmParseError` (parse failure with line/col), `Qx.QasmUnsupportedError` (out-of-scope feature). Public functions return `{:ok, _}` / `{:error, %Qx.*Error{}}`; bang versions raise. |

## Phased implementation (TDD)

**Branch convention**: `qx-0c5/openqasm-import`

### Phase 1 — Foundations (parser scaffold + errors)
- [x] Add `{:nimble_parsec, "~> 1.4"}` to `mix.exs`; `mix deps.get`
- [x] Add `Qx.QasmParseError` and `Qx.QasmUnsupportedError` to `lib/qx/errors.ex` with `defexception` and `message/1`
- [x] Write `test/qx/export/openqasm/parser_test.exs` covering: header alone, header + decl, line-comment skipping, block-comment skipping, identifier rules. **Tests fail first.**
- [x] Implement `lib/qx/export/openqasm/parser.ex` with `defparsec :program` for: header, `include`, `qubit[N] q;`, `bit[N] c;`, comments. Verify tests pass.
- [x] `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict`

### Phase 2 — Gate-call parsing + expression evaluator
- [x] Tests for parameter expressions: `pi`, `pi/2`, `2*pi/3`, `-pi`, `sin(0.5)`, `sqrt(2)`, nested `(pi/2 + 0.1)`
- [x] Implement `lib/qx/export/openqasm/expr.ex` (recursive eval over expression AST → float; reject unknown function names)
- [x] Tests for gate-call grammar: plain (`h q[0]`), multi-qubit (`cx q[0], q[1]`), parametric (`rx(pi/2) q[0]`, `u(0, 0, pi) q[0]`)
- [x] Extend parser with gate-call production; verify tests
- [x] Tests for measurement (modern `c[i] = measure q[j];` and legacy `measure q[j] -> c[i];`); reject discarded `measure q[j];`
- [x] Tests for `barrier` (explicit list and whole-register `barrier q;`)
- [x] Verification gate

### Phase 3 — Conditionals
- [x] Tests for `if (c[i] == N) { ... }` (braced, multi-stmt) and `if (c[i] == N) stmt;` (no braces)
- [x] Tests asserting `else` is rejected with line/col and a refactor hint
- [x] Tests asserting complex conditions (`&&`, `c == 5` register-wide) are rejected
- [x] Implement conditional production in parser
- [x] Verification gate

### Phase 4 — Lowering AST → QuantumCircuit
- [x] Build the literal stdgate dispatch map `%{"h" => :h, ...}` with arity validation
- [x] Tests for direct mappings (one test per gate)
- [x] Tests for decompositions: `tdg → phase(-pi/4)`, `sx → u(pi/2, -pi/2, pi/2)`, `u1 → phase`, `u2 → u(pi/2, φ, λ)`, `id → drop`
- [x] Tests for unsupported stdgates raising `Qx.QasmUnsupportedError` (cy, ch, crx, cry, crz, cu, rxx, ryy, rzz, rzx)
- [x] Tests for multi-register rejection (program with two `qubit` decls)
- [x] Tests for register-name mismatch (gate references `r[0]` but only `q` declared)
- [x] Tests for out-of-bounds qubit index
- [x] Tests for legacy `qreg`/`creg`/`measure ... -> ...` syntax acceptance
- [x] Implement `lib/qx/export/openqasm/lowering.ex`
- [x] Verification gate

### Phase 5 — Public API + integration
- [x] Tests for `Qx.Export.OpenQASM.from_qasm/1` returning `{:ok, %QuantumCircuit{}}`
- [x] Tests for `from_qasm/1` returning `{:error, %QasmParseError{line, col, snippet}}` on bad syntax
- [x] Tests for `from_qasm!/1` raising
- [x] Tests for parse-error line/col accuracy across 5+ malformed inputs
- [x] Implement public functions in `lib/qx/export/openqasm.ex`
- [x] Verification gate

### Phase 6 — Round-trip
- [x] Round-trip test (`test/qx/export/openqasm/round_trip_test.exs`):
  - For each fixture circuit (Bell, GHZ-3, QFT-3, Grover-2, mixed-conditional)
  - Build with Qx → `to_qasm/1` → `from_qasm/1` → simulate both → assert state vectors equal within 1e-10
- [x] Add fixtures `test/fixtures/qasm/{bell,ghz3,qft3,grover2,ibm_example}.qasm`
- [x] One IBM Quantum example sourced from public Qiskit examples (Bernstein-Vazirani or Deutsch-Jozsa, kept minimal)
- [x] Verification gate; spot-check `mix bench` (no Nx code touched, but confirm import doesn't regress unrelated paths)

### Phase 7 — Gate definitions → Elixir codegen
- [x] Tests for parsing `gate g(theta) a, b { rx(theta) a; cx a, b; }` → gate-def AST
- [x] Tests rejecting modifiers in v1 (`ctrl @ h a;` inside body)
- [x] Tests rejecting nested user-gate references in v1 (`gate g a { otherg a; }`)
- [x] Tests for `from_qasm_function/1` returning `{:ok, %{name: "g", arity: 3, source: "def g(circuit, theta, a, b) do\n  circuit\n  |> Qx.rx(a, theta)\n  |> Qx.cx(a, b)\nend"}}` (param order: circuit, then params, then qubits)
- [x] Tests asserting generated source compiles when wrapped in a module (use `Code.compile_string/1`)
- [x] Tests for `from_qasm_function!/1` raising
- [x] Implement parser extension for `gate` definitions
- [x] Implement `lib/qx/export/openqasm/codegen.ex`
- [x] Wire `from_qasm_function/1` in public API
- [x] Verification gate

### Phase 8 — Docs and release prep
- [x] Update `lib/qx/export/openqasm.ex` `@moduledoc` with "Importing" section, supported-subset table, decomposition list, error types
- [x] Add "OpenQASM Import" section to `README.md` with two examples (full program, gate-def → function source)
- [x] CHANGELOG entry under `## [0.6.0]` listing: new functions, supported gate set, decompositions, explicit non-features (cite spec areas), new dep
- [x] Bump `version: "0.5.2"` → `"0.6.0"` in `mix.exs`
- [x] Final verification: `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test && mix docs`

## Risks (self-check)

1. **Will `else`-rejection frustrate users importing IBM examples?** Likely yes for mid-circuit feedback circuits. Mitigation: error message gives explicit two-`if` rewrite. Track real-world frequency post-release; consider adding `else` support to `:c_if` in a follow-up bd issue if it bites.

2. **Will the single-register restriction reject too many real programs?** Most teaching/example circuits use a single register; multi-register is common in Qiskit code that splits ancilla. Mitigation: document limitation prominently; the portal can pre-flight check. File a follow-up bd issue to add multi-register support to `Qx.QuantumCircuit` itself if demand emerges (that's a much bigger structural change).

3. **Will compile time of nimble_parsec grammar slow `mix compile`?** A 35-production grammar typically adds 1–3 seconds to first compile, then is incremental. Acceptable. If it bites, move parser into a separate `parser` Mix env or split file.

4. **Codegen string injection / safety** — generated source includes float-formatted parameter values from caller-controlled QASM. The portal will store and possibly evaluate these. Format with `:erlang.float_to_binary/2` (no eval), reject any QASM identifier containing characters outside `[A-Za-z0-9_]` at parse time so identifiers can't break out of the generated function. Test with adversarial gate names (`q\nIO.puts("pwn")`).

5. **Decomposition correctness** — `sx`, `tdg`, `u1`, `u2` decompositions must be unitarily equivalent to the canonical definitions. Mitigation: round-trip tests will catch via simulation comparison. Also add unit tests that build circuits both ways (e.g., circuit with `sx` decomposed vs hypothetical direct `sx` matrix) and assert state equality.

## Verification (every phase + final)

```
mix compile --warnings-as-errors && \
  mix format --check-formatted && \
  mix credo --strict && \
  mix test
```

Final phase additionally: `mix docs` (no warnings) and `mix bench` (smoke check — should be unaffected).

## bd integration

Create three subtask bd issues under qx-0c5 to track phase clusters in `bd`:
1. `qx-0c5.1` — Parser + lowering (Phases 1–5)
2. `qx-0c5.2` — Round-trip tests + fixtures (Phase 6)
3. `qx-0c5.3` — Gate-def codegen + docs/release (Phases 7–8)

Detailed sub-checkbox tasks live in this plan file (per phase).

## Next step

Run `/phx:work .claude/plans/openqasm-import/plan.md` (recommended in a fresh session) or `/phx:full` for plan→work→review→compound.
