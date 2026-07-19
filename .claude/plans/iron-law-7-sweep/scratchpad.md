# Scratchpad — iron-law-7-sweep

## Decisions
- **New error types:** `Qx.RegisterError` + `Qx.BasisError` (user-chosen). Rejected: one
  combined `RegisterError` (would fold the non-register `qubit.ex:290` basis check into a
  register-named type) and BasisError-only (left construction sites with loose-fitting generics).
- **`u` stray fix:** drop the bounds from `Qx.Operations.u/5`'s guard so it falls through to
  `add_gate/4`'s existing `QubitIndexError` — matches how `rx/ry/rz/cp` already behave. No new
  validation call needed.

## Open / to confirm during work
- Does `qubit.ex:290` (`from_basis/1`) sit on the public boundary? `from_basis/0,1` are public on
  `Qx.Qubit` (a declared public module) → yes, Iron Law #7 applies.
- `openqasm/parser.ex:568` `String.to_float/1` — deferred to v0.8.3 parser hardening unless it
  proves to raise across the public boundary. Reassess in Phase 5.
- Are there `Qx.*` top-level delegators for the `Qx.Register` distinctness gates (`Qx.swap` etc.)?
  Grep `qx.ex` for delegators during the doc pass — their `## Raises` may also need updating.

## Resolved during work
- `qubit.ex` `from_basis/1` IS on the public boundary → routed to `Qx.BasisError`.
- `openqasm/parser.ex:568` `String.to_float/1`: confirmed it does NOT leak across the public
  boundary. `to_number/1` is a private NimbleParsec callback; `parts` is already grammar-matched
  as a float literal, and a malformed numeric fails earlier as `Qx.QasmParseError`. Left as-is;
  deferred to v0.8.3 parser hardening per plan.
- No `Qx.*` top-level delegators referenced `ArgumentError` (grep of `qx.ex` was clean); `Qx.u/5`
  already documented `Qx.QubitIndexError`, now accurate.
- `register.ex:163` (empty `from_basis_states`) folded into `Qx.RegisterError, :empty` alongside
  `:92` — the two empty-list messages collapsed to one generic message (no test asserted the old
  basis-specific wording).

## Latent (out of scope — note for a later sweep)
- `lib/qx/gates.ex:404,451` and `lib/qx.ex:79,100` still document `FunctionClauseError` for
  guard-only out-of-range/`num_qubits <= 0` cases. These are guard behaviours, not raw
  `ArgumentError`, so outside this sweep's roadmap line. Candidate for a future typed-error pass
  if `Qx.Gates` / `Qx.create_circuit` guards are routed through `Qx.Validation`.
- Pre-existing `IO.puts`/`IO.inspect` in `qubit.ex` display helpers and `operations.ex`
  `tap_circuit`/`tap_state` doctests (flagged by the debug-statement hook) — intentional display
  code, untouched.
- Final `grep -rn "raise ArgumentError" lib/` after this work: **NONE**. Iron Law #7 raw-error
  residue on public paths in v0.8.1 is cleared.

## Review triage (merge-gate findings)
Accepted & fixed in-branch:
- `qx.ex:79,100` `## Raises` docs were stale — `Qx.create_circuit/1,2` raises `Qx.QubitCountError`
  (verified empirically), not `FunctionClauseError`, for an out-of-range integer. Docs corrected to
  list both (QubitCountError for range, FunctionClauseError only for non-integer / negative cbits).
- `openqasm_test.exs` version test now asserts `e.option`/`e.value` instead of a brittle message regex.
- Added `bloch_sphere/2` + `histogram/2` format-error tests (retyped sites that were untested).

Deferred (out of this plan's roadmap line — note for a later typed-error/guard sweep):
- `Qx.Register.from_basis_states/1` with a NON-LIST arg still leaks `FunctionClauseError`
  (`when is_list(states)` guard). Genuine Iron Law #7 residue but a guard-only path, not an
  `ArgumentError` site — same class as the `gates.ex` / `create_circuit` guard cases.
- `test/qx/u_gate_test.exs` is not `async: true` (pre-existing; not touched beyond the one retype).
- `register.ex:99` `unless` — reviewer speculated a 1.18 deprecation; `mix compile
  --warnings-as-errors` is CLEAN, so no warning fires. No action.
