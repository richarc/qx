# Iron Law #7 sweep — typed errors across the rest of the public surface + the `u` stray

**Branch:** `fix/iron-law-7-sweep` (cut from `main`)
**Source:** `ROADMAP.md` v0.8.1 — two lines:
- "`ArgumentError` → typed `Qx.*Error` sweep across the rest of the public surface" (audit: arch HIGH cluster + security MED)
- "Iron Law #7 stray: `Qx.Operations.u/5` … leaks `FunctionClauseError` for an out-of-range qubit" (discovered: iron-law-7-followon)

**Predecessors:** `iron-law-7-critical` (0.8.0, CRITICAL leaks) and `iron-law-7-followon`
(0.8.1, the `Qx.Validation` raises + new `Qx.ParameterError`). This clears nearly all
remaining Iron Law #7 debt from v0.8.1.
**Solution doc:** `.claude/solutions/architecture-issues/route-validation-raises-to-typed-errors-iron-law-7-20260624.md`
— read it; the gotchas (dual `## Raises` doc surface, `is_binary` fallback trap,
full-suite test blast radius, TDD/hook gate) all apply again.
**Target version:** v0.8.1, pre-1.0 minor/patch. Observable error-type change → **CHANGELOG
`Changed` entry required** (Iron Law #6).

## Iron Law #7 (qx CLAUDE.md)
> Public functions raise typed `Qx.*Error` on misuse. Do not let raw `Nx` / `Complex` /
> `ArgumentError` leak across the API boundary — route through `Qx.Validation`.

## Decision (settled in planning)
Two new exceptions; everything else reuses the existing family.
- **`Qx.RegisterError`** (`defexception [:reason, :message]`) — register construction / input:
  `register.ex:92,163` (empty list), `:100` (malformed qubit), `tables.ex:63` (wrong input type).
- **`Qx.BasisError`** (`defexception [:value, :message]`) — the shared "must be 0 or 1" check:
  `register.ex:168` + `qubit.ex:290`.

## Site → typed-error map (~24 raw `ArgumentError` + 1 `FunctionClauseError`)

### Reuse existing types (no new code)
| Sites | New raise |
|---|---|
| `register.ex:510,538,746` ("control ≠ target") | `Qx.QubitIndexError, {:duplicate, [c, t]}` |
| `register.ex:569,704` ("all indices different") | route via `Qx.Validation.validate_qubits_different!/1` → `Qx.QubitIndexError {:duplicate}` |
| `register.ex:657,680` ("SWAP/iSWAP distinct") | `Qx.QubitIndexError, {:duplicate, [a, b]}` |
| `draw.ex:98,140,182,231` + `tables.ex:84` ("Unsupported format") | `Qx.OptionError, {:format, format, "Use :auto/:text/…"}` |
| `openqasm.ex:177` ("Invalid OpenQASM version") | `Qx.OptionError, {:version, version, "Must be 2 or 3."}` |
| `circuit.ex:111` ("exceeds maximum of 20 qubits") | `Qx.QubitCountError, {n, 1, 20}` |
| `circuit.ex:122,173` ("Invalid qubit index") | `Qx.QubitIndexError` |
| `circuit.ex:126` ("Invalid classical bit index") | `Qx.ClassicalBitError` |
| `circuit.ex:161` ("Unsupported gate type") | `Qx.GateError, {:unsupported_gate, gate}` |

### New types (decision above)
| Sites | New raise |
|---|---|
| `register.ex:92,163` | `Qx.RegisterError, :empty` |
| `register.ex:100` | `Qx.RegisterError, {:invalid_qubit, qubit}` |
| `tables.ex:63` | `Qx.RegisterError, {:invalid_input, value}` |
| `register.ex:168`, `qubit.ex:290` | `Qx.BasisError, value` |

### The `u` stray (FunctionClauseError)
`Qx.Operations.u/5` guard `when qubit >= 0 and qubit < circuit.num_qubits` (operations.ex:293)
fires before the body, so an out-of-range qubit raises `FunctionClauseError`. **`rx`/`ry`/`rz`/`cp`
etc. don't have this guard** — they fall through to `Qx.QuantumCircuit.add_gate/4`, which already
raises `Qx.QubitIndexError` (predecessor `iron-law-7-critical`). Fix: drop the bounds from `u`'s
guard (keep `%QuantumCircuit{}` + `is_integer(qubit)`), letting it reach `add_gate`. Then
`operations.ex:290`'s doc (`FunctionClauseError`) → `Qx.QubitIndexError`; `Qx.u/5`'s doc in
`qx.ex` already (incorrectly) promises `Qx.QubitIndexError`, so this makes reality match the doc.

## ⚠ Process gate — existing test edits need approval
Hook hard-blocks `*_test.exs` edits; TDD rule #2 needs explicit human approval. Existing
assertions to retype (found by grep — **run the full suite to catch any others**, per the
solution doc's "blast radius" note):
- `test/qx/register_test.exs:58,73,277,285` (construction/basis), `:531` (`cy` distinct), `:666` (`swap`), `:667` (`iswap`)
- `test/qx/export/openqasm_test.exs:21` (version)
- Check `test/qx/u_gate_test.exs` for any `assert_raise FunctionClauseError` on an OOR qubit.
- `circuit.ex` / `draw.ex` / `tables.ex` sites have **no** existing assertions → add NEW focused tests (allowed without the modify-gate, but the hook still blocks the write → approval needed).

---

## Phase 1 — New exceptions + their unit tests (TDD)
- [x] Add `Qx.RegisterError` and `Qx.BasisError` to `lib/qx/errors.ex` (follow the family's `exception/1` clauses; **`Qx.BasisError` omits the `is_binary` fallback** — a value could be any term; mirror `Qx.ParameterError`'s documented reason)
- [x] Add both to the `Qx.Error` moduledoc typed-exception list
- [x] ⚠ Approval to add new exception tests to `test/qx/errors_test.exs` (if it exists) or a new `test/qx/typed_errors_sweep_test.exs`: assert message + struct fields (`reason`/`value`) for both
- [x] `mix test` the new error tests → green (these don't depend on routing)

## Phase 2 — Reuse-existing-type sites (lib, no new error code)
- [x] `register.ex` distinctness (510/538/569/657/680/704/746) → `Qx.QubitIndexError {:duplicate}` (use `validate_qubits_different!/1` where a list is already in hand; otherwise the 2-elem `{:duplicate, [a,b]}` form)
- [x] `draw.ex` ×4 + `tables.ex:84` → `Qx.OptionError {:format, …}`
- [x] `openqasm.ex:177` → `Qx.OptionError {:version, …}`
- [x] `circuit.ex` 111/122/126/161/173 → `QubitCountError` / `QubitIndexError` / `ClassicalBitError` / `GateError`

## Phase 3 — New-type sites (lib)
- [x] `register.ex:92,163` → `Qx.RegisterError, :empty`; `:100` → `{:invalid_qubit, qubit}`
- [x] `register.ex:168` + `qubit.ex:290` → `Qx.BasisError, value`
- [x] `tables.ex:63` → `Qx.RegisterError, {:invalid_input, value}`

## Phase 4 — The `u` stray
- [x] `operations.ex:293` — drop `qubit >= 0 and qubit < circuit.num_qubits` from `u/5`'s guard (keep struct + `is_integer(qubit)`); confirm `add_gate/4` raises `Qx.QubitIndexError` for OOR
- [x] `operations.ex:290` `## Raises` — `FunctionClauseError` → `Qx.QubitIndexError`
- [x] Confirm `Qx.u/5` doc in `qx.ex` already reads `Qx.QubitIndexError` (it does) — now accurate

## Phase 5 — Tests, docs, verify, roadmap
- [x] ⚠ Approval to retype the existing `assert_raise ArgumentError` assertions (register_test ×7, openqasm_test ×1) to the mapped typed errors; fix any test-name strings that say "ArgumentError"; remove/retype any `FunctionClauseError` u-qubit assertion
- [x] Add NEW focused tests for the `circuit.ex` / `draw.ex` sites that had no coverage (typed error + message)
- [x] Update `## Raises` docs: grep **both** `Qx.*` delegators in `qx.ex` AND the impl modules (`register.ex`, `qubit.ex`, `draw.ex`, `export/openqasm.ex`) for stale `ArgumentError` mentions — `grep -rn "ArgumentError" lib/`
- [x] `CHANGELOG.md` `[Unreleased]` Changed entry: list the new `Qx.RegisterError` / `Qx.BasisError` and the retyped surfaces (`Qx.Register.*`, `Qx.Qubit.from_basis/1`, `Qx.Draw.*`, `Qx.Export.OpenQASM.to_qasm`, `Qx.u/5` qubit OOR)
- [x] Full gate: `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test`
- [x] Tick **both** ROADMAP v0.8.1 lines (the sweep + the `u` stray) in the merge commit

## Risks / notes
- **SemVer:** observable error-type change across several public modules. Pre-1.0 minor/patch + CHANGELOG, consistent with the two predecessors. Not a major bump.
- **Doc surface is duplicated** (`qx.ex` delegators + impl modules) — the recurring trap from the solution doc. Grep `lib/` wholesale, don't trust the per-file site list.
- **Out of scope:** `openqasm/parser.ex:568` (`String.to_float/1` on hostile input) is in the roadmap line's enumeration but is a security-hardening item better handled with the v0.8.3 parser work; note it in scratchpad rather than forcing a type here. Confirm during work whether it actually raises across the public boundary.
- No Nx/`defn` changes → no `mix bench`.
