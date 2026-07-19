# Iron Law Judge Report — `feat/deprecation-batch`

## Scope
Reviewed: `lib/qx.ex`, `lib/qx/operations.ex`, `lib/qx/patterns.ex`,
`lib/qx/quantum_circuit.ex`, `lib/qx/draw.ex`, `lib/qx/draw/tables.ex`,
`CHANGELOG.md`, `.claude/plans/deprecation-batch/plan.md`.

## Verdict: VIOLATIONS-FOUND (one MEDIUM defect; no CRITICAL breakage)

All 5 deprecations are genuinely non-breaking — every deprecated function
still works, unchanged behavior, no removals, no version bump (correct
pre-1.0 policy). One real defect found: a stale `@spec`/doc on the
`Qx.barrier/2` facade that doesn't reflect the new Range support the
CHANGELOG advertises for it.

---

## Iron Law #6 (public API surface)

### [MEDIUM] Stale `@spec`/doc on `Qx.barrier/2` facade — doesn't reflect the new Range support it advertises
- **File**: `lib/qx.ex:1032-1050`
- **Code**:
  ```elixir
  @doc """
  Adds a barrier across the given qubits.
  See `Qx.Operations.barrier/2`. ...
  ## Examples
      iex> qc = Qx.create_circuit(3) |> Qx.barrier([0, 2])
      ...
  """
  @spec barrier(circuit(), list(non_neg_integer())) :: circuit()
  defdelegate barrier(circuit, qubits), to: Operations
  ```
- **Issue**: `Qx.Operations.barrier/2` was correctly extended with a `Range`
  clause (`lib/qx/operations.ex:689-697`), and `CHANGELOG.md` explicitly
  advertises `Qx.barrier/2` (the top-level facade) as now accepting a range
  (`### Added`: *"`Qx.barrier/2` now accepts a **range**..."*, and the
  deprecation note on `Qx.barrier_all/2` at `lib/qx.ex:1071-1074` says the
  same). But the `Qx` **facade** — the module the README/tutorials/plan
  treat as the primary documented surface (see `Qx` moduledoc, `CLAUDE.md`
  Iron Law #6 surface list) — still has:
  - `@spec barrier(circuit(), list(non_neg_integer())) :: circuit())` — no
    `Range.t()` in the union, so Dialyzer will flag any `Qx.barrier(qc,
    0..3)` call as a spec violation despite it being the documented,
    working feature.
  - No `## Examples` or prose demonstrating the range form on the facade
    (unlike `Qx.Operations.barrier/2`, which does show both forms at
    `lib/qx/operations.ex:683-687`).
  - Runtime is unaffected — `defdelegate` has no argument-shape guard, so
    `Qx.barrier(qc, 0..3)` works today. This is a doc/spec-accuracy defect,
    not a functional break.
- **Confidence**: DEFINITE (spec/doc mismatch is directly readable from the
  two files; CHANGELOG explicitly claims facade-level range support).
- **Fix**: On `lib/qx.ex` `barrier/2`: widen
  `@spec barrier(circuit(), list(non_neg_integer()) | Range.t()) :: circuit()`
  and add a range example to the `@doc`, mirroring
  `Qx.Operations.barrier/2`'s doctest. This is the primary documented
  surface per the plan's own framing ("Qx.barrier/2 — now accepts list OR
  range") — the facade should carry the feature's public contract, not just
  the utility module behind it.

### [INFO — not a violation] Plan text vs. implementation: only the `Qx` facades were `@deprecated`, not the `Patterns` implementations
- **File**: `lib/qx/patterns.ex:229-266` (`barrier_all/1,2`), `:460-480`
  (`superposition_circuit/1`)
- **Detail**: Plan phases P1-T3 / P2-T1 describe deprecating "`Patterns.barrier_all/2` (+ the `Qx.barrier_all/2` facade)" and "`Qx.superposition/1` (facade) and `Patterns.superposition_circuit/1`". In the actual diff, `@deprecated` only landed on the two `Qx` facade `defdelegate`s (`lib/qx.ex:1084`, `lib/qx.ex:1796`) — `Qx.Patterns.barrier_all/2` and `Qx.Patterns.superposition_circuit/1` carry no `@deprecated` tag and no warning notice in their docs.
- **Why this is not a violation**: this actually satisfies the plan's own Risk-1 mitigation ("deprecate at the user-facing level ... make any internal caller NOT hit the deprecated arity") — the facade `defdelegate` calls straight into the *undeprecated* `Patterns` function, so no self-warn under `--warnings-as-errors`. Both facades and implementations still work identically either way; nothing is broken, non-breaking either way, no CHANGELOG inaccuracy (CHANGELOG only names the `Qx.*` facades). Flagged only because the plan's phase descriptions overstate what was applied to `Patterns`; no fix required against the Iron Laws.

### CHANGELOG completeness — verified
- `Qx.barrier_all/2` deprecation — `CHANGELOG.md:50-52` (Deprecated). ✓
- `Qx.superposition/1` deprecation — `CHANGELOG.md:53`. ✓
- `QuantumCircuit.get_state/1` deprecation — `CHANGELOG.md:54-57`. ✓
- `draw_state`/`state_table` Register-input deprecation — `CHANGELOG.md:58-59`. ✓
- `run/2` integer-shots soft-deprecation — `CHANGELOG.md:60-62`. ✓
- Additive: `Qx.barrier/2` range support — `CHANGELOG.md:30-31` (Added). ✓
- Additive: `QuantumCircuit.initial_state/1` — `CHANGELOG.md:32-34` (Added). ✓

### Behavior-preservation spot checks — all pass
- `Qx.barrier_all/2` (`lib/qx.ex:1086`) and `Qx.superposition/1`
  (`lib/qx.ex:1798`) are still `defdelegate`s to the same targets — no
  signature or return-type change, only `@deprecated` added.
- `QuantumCircuit.get_state/1` (`lib/qx/quantum_circuit.ex:272-276`) now
  simply calls `initial_state/1`, which returns `circuit.state` — the same
  value the old inline implementation returned. Return type/shape
  unchanged.
- No version bump in `mix.exs` (`version: "0.10.1"`, unchanged) — correct
  per the "deprecations are non-breaking, no bump" policy while < 1.0.

---

## Iron Law #7 (typed errors)

Checked, no violations:
- `Operations.barrier/2` Range clause (`lib/qx/operations.ex:690-692`)
  normalizes via `Enum.to_list/1` and falls through to the list clause,
  which calls `Validation.validate_qubit_indices!(qubits, circuit.num_qubits)`
  (`lib/qx/operations.ex:695`) before `QuantumCircuit.add_barrier/2` — same
  validation path as the pre-existing list form, so out-of-range qubits in
  a range (e.g. `Qx.barrier(qc, 0..99)` on a 3-qubit circuit) still raise
  `Qx.QubitIndexError`, not a silent/garbage instruction.
- `Qx.Draw.Tables.render/2` Register branch (`lib/qx/draw/tables.ex:34-43`)
  emits `IO.warn/2` then extracts `s` (the register's state tensor) and
  continues through the normal `build_table_data/3` path — it does not
  swallow or downgrade an actual error; the catch-all clause
  (`lib/qx/draw/tables.ex:48-49`) still `raise`s `Qx.RegisterError` for any
  input that is neither an `Nx.Tensor` nor a `Qx.Register`. No error
  hidden.

## Iron Law #1 (atom-table)

Checked, no violations: no `String.to_atom`, `Module.concat/1`,
`:erlang.binary_to_atom/2`, or `:erlang.list_to_atom/1` in any of the
diffed code. `Operations.barrier/2`'s new Range clause only calls
`Enum.to_list/1` on a `Range` struct — no atom interning from input.

## Iron Law #9 (dispatch completeness / instruction shapes)

Checked, no violations: the new `Operations.barrier/2` `Range` clause
converts to a list and re-enters the existing list clause
(`lib/qx/operations.ex:690-697`), which calls the same
`QuantumCircuit.add_barrier/2` producer that always emits
`{:barrier, qubits, []}` (`lib/qx/quantum_circuit.ex:220-222`). No new
instruction shape introduced; the range form byte-identically converges on
the pre-existing tuple shape, confirmed by the doctest at
`lib/qx/operations.ex:683-687`.

---

## Summary

| Law | Status |
|---|---|
| #6 public API | 1 MEDIUM finding (stale facade spec/doc for `Qx.barrier/2` range) |
| #7 typed errors | PASS |
| #1 atom-table | PASS |
| #9 dispatch completeness | PASS |

**Overall verdict: VIOLATIONS-FOUND** — one MEDIUM-severity documentation/
spec-accuracy defect (not a functional break, not a breaking API change).
Recommend fixing the `Qx.barrier/2` `@spec`/doc before merge so Dialyzer
and docs match the advertised (and already-working) range support.
