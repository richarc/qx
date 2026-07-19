# Scratchpad — circuit-appenders (v0.11 Additive surface, part 1)

## Scope decisions (CONFIRMED by user 2026-07-11)

1. **Split the ROADMAP item.** This branch = appenders + creator reframe ONLY.
   `tdg/2` + `to_qasm/from_qasm/from_qasm!` facade delegates deferred to a
   follow-up `feat/qasm-facade-tdg`. The `from_qasm_function/1` atom-vs-string
   SemVer change stays its own separate item. ROADMAP "Additive surface"
   checkbox stays UNCHECKED until BOTH pieces land.
2. **Reframe is a PURE refactor** — `Qx.bell_state`/`ghz_state` return
   byte-identical circuits and raise identical errors; existing tests/doctests
   pass UNCHANGED.

## Research (2 agents, 2026-07-11)

- **hex-deps.md:** NO new dependency. Pure struct/list composition over existing
  `Operations.h/cx/x` + `Patterns.cx_chain` + stdlib.
- **patterns-conventions.md:**
  - Home = `lib/qx/patterns.ex` next to `cx_chain/2` (patterns.ex:267-296);
    facade delegates in `lib/qx.ex` next to `cx_chain` (qx.ex:1078). New
    appenders are FULLY documented tier-2 entry points (the creators
    `bell_state_circuit`/`ghz_state_circuit` stay `@doc false`, fronted by
    `Qx.bell_state`/`Qx.ghz_state`).
  - Reframe verified byte-identical: `new(2)|>bell_pair(0,1,which)` reproduces
    all 4 Bell sequences; `new(n)|>ghz(0..(n-1))` reproduces GHZ.
  - `cx_chain` (`Enum.chunk_every(2,1,:discard)`) is a true no-op on empty/
    single lists → `ghz(c, [])` would `hd([])`-crash → needs an explicit guard.
  - Typed errors: `Operations.cx/3`→`add_two_qubit_gate` raises
    `Qx.QubitIndexError` on equal AND out-of-range; `h`/`x`→`add_gate` raises
    on out-of-range. So appenders need NO index validation of their own — only
    the bad-`which` `OptionError` fallback (copy patterns.ex:337-340) and the
    empty/short-list guard for `ghz`.
  - §8 (api-design-principles.md ~L217) literally names this tension.
  - Test template: `test/qx/patterns_test.exs` — `describe` blocks, exact
    instruction-list `==` assertions, `assert_raise` typed errors, and the
    existing "delegates to Patterns" backward-compat assertions (L391-394,
    428-431) → reuse for the byte-identical reframe-equality tests.

## Current creator bodies (reframe targets — verified)

bell_state_circuit on `new(2)`:
- :phi_plus  → h(0), cx(0,1)
- :phi_minus → x(0), h(0), cx(0,1)
- :psi_plus  → x(1), h(0), cx(0,1)
- :psi_minus → x(0), x(1), h(0), cx(0,1)
- fallback   → raise Qx.OptionError, {:which, which, "Expected :phi_plus, …"}
ghz_state_circuit(n) [n≥2] → new(n) |> h(0) |> cx_chain(0..(n-1))
  fallbacks: n<2 → QubitCountError {n,2,20}; non-integer → {:not_an_integer,n}

## Open decisions (defaults chosen; flag at approval)

- **`ghz(circuit, qubits)` minimum length. CONFIRMED: require ≥ 2 qubits.**
  Empty or single-element list → raise `Qx.QubitCountError` (reason tuple TBD in
  impl — reuse the `{len, 2, 20}` shape for a clear "needs 2..20 qubits"
  message). (Rejected alt: allow 1-qubit H-only.)
- **`bell_pair` up-front `q0≠q1` validation.** Not needed — `cx(q0,q1)` raises
  `Qx.QubitIndexError` on equal. The pipeline may append earlier gates (e.g.
  `x(q1)` for :psi_plus) before `cx` raises, but the partial circuit is
  discarded on raise (immutable; caller never sees it). No up-front guard.
- **`bell_pair` OptionError message** must byte-match the current
  bell_state_circuit fallback so the reframe preserves the exact error.

## Implementation notes (2026-07-11, /phx:full)

- All 12 plan tasks complete. Final gate green: `mix compile
  --warnings-as-errors` + `mix format --check-formatted` + `mix credo
  --strict` (no issues) + `mix test` (278 doctests, 1049 tests, 0
  failures). `mix docs` warnings = 36 (== baseline, unchanged).
- **Test-suite gap found & fixed (additive):** `test/qx/patterns_test.exs`
  had NO `doctest Qx.Patterns` directive, so the module's doctests
  (existing h_all/cx_chain/… AND the new bell_pair/ghz ones) were never
  executed. Added the directive — all 24 Patterns doctests now run and
  pass. Pure coverage addition, no existing test modified.
- `ghz/2` short-list error uses `Qx.QubitCountError` `{len, 2, 20}` shape
  → message "Invalid qubit count: {0|1} (must be between 2 and 20)".
- Reframe verified byte-identical via the P3-T1 invariant tests + the
  UNCHANGED existing bell_state/ghz_state tests & doctests (tripwire held).

## STILL PENDING after this branch (do NOT tick the ROADMAP item yet)

1. `feat/qasm-facade-tdg` — `tdg/2` gate + `to_qasm`/`from_qasm`/
   `from_qasm!` facade delegates (part 2 of 2 for "Additive surface").
2. `from_qasm_function/1` atom-vs-string SemVer change — separate item.
3. `api-design-principles.md §6` family-row edit for the prep builders —
   belongs to the "Principles-doc post-review edits" ROADMAP item.
4. ROADMAP "Additive surface" checkbox stays UNCHECKED until #1 lands.

## §6 family-row note (defer the doc edit)

`bell_pair`/`ghz` are state-prep builders with no existing §6 naming-family row.
The actual `api-design-principles.md §6` edit belongs to the SEPARATE v0.11
"Principles-doc post-review edits" ROADMAP item — note the new-row need here,
do NOT edit the principles doc in this branch.
