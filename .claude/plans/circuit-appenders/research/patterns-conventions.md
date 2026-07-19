# Codebase analysis — bell_pair/2,3 + ghz/2 appenders

Note: qx is a pure-Elixir library (no Phoenix/Ecto/Ash — `mix.exs` has no
phoenix/ash deps, confirmed by grep). Phoenix-context rules (scopes, Repo
boundaries, LiveView) do not apply; this analysis instead follows qx's own
documented API-design contract at `spec/api-design-principles.md`.

## 1. Home module + facade pattern

- New appenders belong in `Qx.Patterns` (lib/qx/patterns.ex), alongside the
  `_all` family and `cx_chain/2` (patterns.ex:267-296), fronted by
  `Qx.bell_pair/3` and `Qx.ghz/2` `defdelegate`s in lib/qx.ex, mirroring
  `defdelegate cx_chain(circuit, qubits), to: Patterns` (qx.ex:1078) and
  `defdelegate bell_state(...), to: Patterns, as: :bell_state_circuit`
  (qx.ex:1589).
- House doc style (v0.11 sweep): `@spec`, a prose paragraph, `## Examples`
  with doctests, `## Returns`/`## Raises` sections when applicable
  (spec/api-design-principles.md:168-172, "Docs" rule). See
  `h_all/2` (patterns.ex:88-104) and `cx_chain/2` (patterns.ex:267-296) as
  the template — note `cx_chain`'s doc explicitly states the "lists of
  length 0/1 are deliberate no-ops" contract in prose, not just tests.
- `Patterns.qubits()` type (patterns.ex:63-69, `[non_neg_integer()] | Range.t()`)
  is the established type for "list or range of qubit indices" used by all
  `_all/2` overloads — reuse it if `ghz/2` should accept a range as well as
  a list (task says `ghz(circuit, qubits)`; `cx_chain/2` itself is typed
  `[non_neg_integer()]` only, not `qubits()` — decide whether `ghz` widens
  to accept ranges, which would require normalizing via the existing
  private `qubits_to_list/1` helper, patterns.ex:392-393, before delegating
  to `cx_chain`).
- `bell_state_circuit/1` and `ghz_state_circuit/1` currently carry
  `@doc false` (patterns.ex:303-304, 342-343) — they are creators reached
  through the `Qx.bell_state/1`/`Qx.ghz_state/1` facade, per the moduledoc
  note (patterns.ex:32-35). The new `bell_pair/3` and `ghz/2` are
  *appenders* and should be full public docs (not `@doc false`), since
  callers may reach them directly through `Qx.Patterns` (tier 2, see §3).

## 2. Reframe safety — exact sequence match

Current creators (patterns.ex:303-361), on a fresh `QuantumCircuit.new(2)`:
- `:phi_plus` → `h(0), cx(0,1)`
- `:phi_minus` → `x(0), h(0), cx(0,1)`
- `:psi_plus` → `x(1), h(0), cx(0,1)`
- `:psi_minus` → `x(0), x(1), h(0), cx(0,1)`

`bell_pair(circuit, q0, q1, which)` must emit the identical gate/order using
`q0`/`q1` in place of the hardcoded `0`/`1`. Reframe:
```elixir
new(2) |> bell_pair(0, 1, which)
```
reproduces each sequence exactly IF `bell_pair` dispatches on `which` with
the same 4 clause bodies, substituting `0→q0`, `1→q1` positionally (control
qubit of `cx` is always `q0`, target always `q1` — matches `cx(0,1)` in all
four variants). No ordering mismatch found.

`ghz_state_circuit(num_qubits)` (patterns.ex:346-350):
```elixir
QuantumCircuit.new(num_qubits) |> Operations.h(0) |> cx_chain(Enum.to_list(0..(num_qubits - 1)))
```
`ghz(circuit, qubits)` must do `h(hd(qubits))` then `cx_chain(qubits)` (H on
the *first* qubit in the given list, not literal index 0) so that
`new(n) |> ghz(0..(n-1))` reproduces `h(0)` + the same chain. Confirmed:
`cx_chain([0,1,...,n-1])` == `Enum.to_list(0..(n-1))` chunked into pairs,
identical to today's call.

`cx_chain/2` on empty/single-element lists (patterns.ex:291-296,
confirmed by `Enum.chunk_every(2, 1, :discard)` — a list of length <2
produces zero chunks) is a **no-op**, returning `circuit` unchanged — this
is already asserted by tests (patterns_test.exs:168-176). So:
- `ghz(circuit, [])` → `h(hd([]))` would crash (`hd` on empty list, a raw
  `ArgumentError`/`FunctionClauseError`, NOT a typed `Qx.*Error` — this is
  a gap the plan must close explicitly, e.g. guard `qubits == []` and raise
  `Qx.QubitCountError` to mirror `ghz_state_circuit`'s existing "< 2 qubits"
  fallback, patterns.ex:355-357).
- `ghz(circuit, [q])` (single qubit) → `h(q)` then `cx_chain([q])` (no-op) —
  well-defined, just an H on one qubit, no error. Decide in the plan
  whether single-qubit GHZ should be allowed (today's `ghz_state_circuit`
  guards `num_qubits >= 2`, patterns.ex:346, so precedent leans toward
  requiring ≥2 qubits — an explicit guard, not reliance on `hd/cx_chain`
  fallthrough, is likely the safer parity choice. Flag as an open decision.)

## 3. Typed-error contract (Iron Law #7) — no new validation needed for
   qubit indices

- `Operations.cx/3` → `QuantumCircuit.add_two_qubit_gate/4`
  (quantum_circuit.ex:117-131): raises `Qx.QubitIndexError` on out-of-range
  AND on `control_qubit == target_qubit` (quantum_circuit.ex:126-131,
  `{:duplicate, [control_qubit, target_qubit]}`). So `bell_pair(c, q, q,
  _)` (equal qubits) already raises via the underlying `cx(0,1)`→`cx(q,q)`
  call — **no explicit guard needed** in `bell_pair`.
- `Operations.h/2`, `x/2` → `QuantumCircuit.add_gate/4`
  (quantum_circuit.ex:102-116): raises `Qx.QubitIndexError` on any
  out-of-range single index (comment at quantum_circuit.ex:105). So
  out-of-range in `ghz(c, qubits)` already raises via `h`/`cx_chain`'s
  inner `cx` calls — no explicit guard needed for range checking.
- Bad `which` selector for `bell_pair`: mirror `bell_state_circuit`'s
  fallback clause (patterns.ex:337-340) — an unmatched-clause fallback
  function head that raises `Qx.OptionError, {:which, which, "Expected
  ..."}`. `bell_pair/4` (with `which` as 4th positional arg or same
  position) needs this same catch-all clause; it does NOT come for free
  from composition since `which` never reaches `Operations`.
- Net: only the `ghz(circuit, [])` empty-list case (§2) and the bad
  `which` selector (this section) need explicit guards/raises in the new
  code; equal/out-of-range qubit indices are already covered by the
  composed `cx`/`h` calls.

## 4. Naming / §8 check (spec/api-design-principles.md)

- §8 "Appenders by default, creators as facades" (lines ~217-224) is the
  exact prescribed shape for this feature: *"`Patterns` currently mixes
  the two shapes with no appender underneath its creators; that's a
  tension for the review."* This plan directly resolves that named
  tension — `bell_pair`/`ghz` are the appenders, `bell_state_circuit`/
  `ghz_state_circuit` become the thin creator wrappers over them.
- §8 "gate contract is the extension contract" (lines ~205-213): shape
  must be `(circuit, qubits_and_params..., opts \\ []) -> circuit`.
  `bell_pair(circuit, q0, q1, which \\ :phi_plus)` and
  `ghz(circuit, qubits)` both fit (subject first, then qubits, then the
  `which` selector — treat `which` as a parameter, not an opts keyword
  list, consistent with `bell_state_circuit(which \\ :phi_plus)`'s
  existing signature, not `opts \\ []`).
- §6 "Naming families" table (lines 110-125): neither `bell_pair` nor
  `ghz` cleanly fits an existing row (`create_*`, `get_*`, `draw_*`,
  `measure*`, `*_all`, `tap_*`, `to_*/from_*`, `*dg`). Per §6, "New
  functions join a family or argue for a new row here" — plan should add
  a short new row/note, e.g. a "state-prep appender" family alongside
  `cx_chain` (which is arguably the same family already — `cx_chain` has
  no row either, so precedent exists for un-tabled appenders).
- §6 "Argument order... Controlled gates put controls before targets"
  (line 92-94): `bell_pair(circuit, q0, q1, which)` — `q0` is the control
  in all four variants' `cx(q0, q1)` call, so `q0, q1` already reads as
  control-before-target; consistent with `cx(circuit, control, target)`.
- `ghz` vs `ghz_state`: keep `ghz` (bare) for the appender per §4's "one
  obvious way" plus the existing `cx_chain` precedent of short,
  un-suffixed names for appenders; `ghz_state`/`bell_state` stay reserved
  for the `Qx` facade creator names (already shipped, must stay
  byte-identical per task). No naming clash since appender lives on
  `Qx.Patterns.ghz/2` / `Qx.Patterns.bell_pair/3` while creators stay
  `Qx.Patterns.ghz_state_circuit/1` / `bell_state_circuit/1`.

## 5. Test/doctest conventions (TDD — tests before impl)

- Template: test/qx/patterns_test.exs — one `describe` block per function,
  each testing: exact instruction-list equality (`==` on
  `QuantumCircuit.get_instructions/1`), no-op/edge cases (empty/single
  list), typed-error propagation via `assert_raise Qx.QubitIndexError,
  ~r/.../, fn -> ... end` (e.g. lines 206-212, 241-247), and a
  "delegates to Patterns" backward-compat assertion comparing `Qx.foo(...)
  == Patterns.foo_impl(...)` (lines 391-394, 428-431, 448-451) — reuse
  this exact assertion shape for the reframe: `Qx.bell_state(which) ==
  Patterns.bell_state_circuit(which)` should stay true, and add
  `Patterns.bell_state_circuit(which) == QuantumCircuit.new(2) |>
  Patterns.bell_pair(0, 1, which)` as the reframe-safety test.
  Also confirm bit-for-bit equality (not just qubit count) for GHZ:
  `Patterns.ghz_state_circuit(n) == QuantumCircuit.new(n) |>
  Patterns.ghz(0..(n-1))`.
- Doctests belong on every public function, matching the moduledoc
  `## Examples` convention (e.g. patterns.ex:279-289 for `cx_chain`).
- New code → TDD: write patterns_test.exs additions (new `describe
  "bell_pair/3"` / `describe "ghz/2"` blocks + the reframe-equality
  assertions above) before implementing `bell_pair`/`ghz`; existing tests
  (lines 359-465) must keep passing unmodified since they pin
  byte-identical output of `bell_state_circuit`/`ghz_state_circuit`.

## Quick reference for the plan

- **Location:** both new functions in `lib/qx/patterns.ex`; facade
  delegates `Qx.bell_pair/3`, `Qx.ghz/2` in `lib/qx.ex` (mirror the
  `cx_chain` delegate block, qx.ex:1078).
- **Signatures:**
  `@spec bell_pair(QuantumCircuit.t(), non_neg_integer(), non_neg_integer(), bell_state_type()) :: QuantumCircuit.t()`
  `@spec ghz(QuantumCircuit.t(), qubits() | [non_neg_integer()]) :: QuantumCircuit.t()`
  (decide list-only vs `qubits()`/range-accepting per §1/§2 note).
- **Validation to add explicitly:** (a) bad `which` → `Qx.OptionError`
  fallback clause (copy patterns.ex:337-340 shape); (b) empty `qubits` in
  `ghz/2` → guard and raise `Qx.QubitCountError` rather than let `hd([])`
  crash raw. Everything else (equal/out-of-range qubit indices) is already
  raised as `Qx.QubitIndexError` by the composed `cx`/`h` calls — do not
  duplicate that validation.
- **Reframe:** `bell_state_circuit(which)` becomes
  `QuantumCircuit.new(2) |> bell_pair(0, 1, which)` (single clause,
  replacing all 4); `ghz_state_circuit(num_qubits)` becomes
  `QuantumCircuit.new(num_qubits) |> ghz(0..(num_qubits - 1))`, keeping its
  own `num_qubits >= 2` guard and `Qx.QubitCountError` fallbacks
  (patterns.ex:355-361) untouched, since `ghz/2`'s own empty/too-short-list
  guard is a different (list-shaped) check, not a numeric one.
- **This directly resolves** the named tension in
  spec/api-design-principles.md §9 item list precursor (§8, "Patterns
  currently mixes the two shapes with no appender underneath its
  creators").
