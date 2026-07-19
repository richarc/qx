# Elixir Review: feat/deprecation-batch

## Summary
- **Status**: ⚠️ Changes Requested
- **Issues Found**: 4 (0 critical, 2 warnings, 2 suggestions/info)

Overall the five deprecations are well-executed: `@deprecated` is placed at
facade level or on functions with no internal callers (verified via grep —
`get_state/1` calls the *un-deprecated* `initial_state/1`; `Qx.superposition/1`'s
`defdelegate` target, `Patterns.superposition_circuit/1`, was deliberately left
un-deprecated to avoid a self-warn at the `defdelegate` call site — this
diverges from the plan's literal wording but is the correct mitigation and is
reflected consistently in CHANGELOG.md, which documents only `Qx.superposition/1`
as deprecated). The `barrier/2` Range clause is byte-identical to the list form
(`Enum.to_list/1` then falls into the same validate+add path), has its own
doctest that actually runs (`doctest Qx.Operations` is wired, not excluded),
and a dedicated `barrier_dispatch_test.exs` asserts `via_range == via_list`.
`run/2`'s soft-deprecation doc is clear. The `IO.warn` message in
`Qx.Draw.Tables.render/2` is good quality (names the deprecated facade, states
removal version, points to the circuit-mode replacement) and is captured by a
dedicated test (`state_table_register_deprecation_test.exs`) asserting silence
on the tensor path and a warning on the Register path.

Two spec/doc staleness issues need fixing before merge.

## Warnings

1. **`lib/qx.ex:1049`** — `Qx.barrier/2` facade `@spec` was not updated for
   Range support. `Qx.Operations.barrier/2` (the function this
   `defdelegate` fronts) gained a `Range.t()` clause in this branch, and the
   new `Qx.barrier_all/2` deprecation notice explicitly tells users to switch
   to `Qx.barrier/2` "which now accepts a list **or range**" — but the facade
   itself still declares:
   ```elixir
   @spec barrier(circuit(), list(non_neg_integer())) :: circuit()
   ```
   Runtime behavior is correct (`defdelegate` just forwards), but Dialyzer will
   flag calls like `Qx.barrier(qc, 0..2)` against this narrower contract, and
   the facade's own `@doc`/example shows only the list form — a user reading
   `Qx.barrier/2`'s docs (the one they're told to migrate to) won't see the
   range capability that's the entire point of the migration.
   ```elixir
   # Fix
   @spec barrier(circuit(), [non_neg_integer()] | Range.t()) :: circuit()
   ```
   and add a second `## Examples` block mirroring `Operations.barrier/2`'s
   range example.

2. **`lib/qx/draw.ex:221`, `lib/qx.ex:1607`** — `Qx.Draw.state_table/2` (and
   its facade `Qx.draw_state/2`) had its `@spec` tightened to the tensor path
   per the plan:
   ```elixir
   @spec state_table(Nx.Tensor.t(), keyword()) :: Qx.Draw.StateTable.t()
   ```
   but the implementation (`Qx.Draw.Tables.render/2`) still has a live,
   non-error branch that pattern-matches `%Qx.Register{state: s}` and
   proceeds (after `IO.warn`) to build the table from `s` — this is
   deliberate (Phase 5's whole point is "still works, just warns"), not dead
   code. Because the accepted-and-handled input set genuinely includes
   `Qx.Register.t()` until 1.0, the `@spec` is narrower than what the function
   actually does, which is the classic Dialyzer `invalid_contract` shape
   (spec narrower than the success typing Dialyzer infers from the body).
   UNVERIFIED (no Dialyzer run available in this review pass — flagging by
   source inspection): confirm with `mix dialyzer` before merge. If it fires,
   either widen the spec (`Nx.Tensor.t() | Qx.Register.t()`, keeping the
   the deprecated-but-still-typed branch) or leave a `@dialyzer` suppress
   with a comment tying it to the 1.0 removal, so the removal commit has an
   obvious spot to also delete the suppression.

## Suggestions

1. **`lib/qx.ex:1041-1043`** — `Qx.barrier/2`'s only `## Examples` block
   shows the list form; once the `@spec`/doc fix above lands, add the range
   example so the facade doc is self-sufficient (currently a reader has to
   jump to `Qx.Operations.barrier/2` to discover range support even though
   the deprecation notice on `barrier_all/2` sends them to `Qx.barrier/2`
   specifically).

2. **Plan/implementation divergence (informational, not a defect)** —
   `.claude/plans/deprecation-batch/plan.md` (P2-T1) says to `@deprecated`
   both `Qx.superposition/1` **and** `Patterns.superposition_circuit/1`; only
   the former is deprecated in `lib/qx/patterns.ex`. This is the right call
   (deprecating the `defdelegate` target would self-warn at its own call site
   in `qx.ex`, the exact risk the plan calls out), and CHANGELOG.md already
   documents the as-built behavior accurately — but worth a one-line plan
   update so the plan doesn't read as contradicting the CHANGELOG for future
   readers.

## Verified, no issues

- `Operations.barrier/2` Range clause: `Enum.to_list/1` → falls through to
  the existing list clause → same `validate_qubit_indices!` + `add_barrier`
  path. Confirmed byte-identical via `barrier_dispatch_test.exs`.
- `QuantumCircuit.get_state/1` `@deprecated` delegates to un-deprecated
  `initial_state/1` — no self-warn under `--warnings-as-errors`.
- `Qx.superposition/1` `@deprecated` facade; delegate target
  (`Patterns.superposition_circuit/1`) left un-deprecated — no self-warn.
- No `lib/` caller found for any of the five freshly-deprecated call sites
  (`Qx.barrier_all/2`, `Patterns.barrier_all/2`, `Qx.superposition/1`,
  `QuantumCircuit.get_state/1`) via grep.
- `run/2` integer-shots clause: doc-only, no `@deprecated`/`IO.warn`, both
  clauses intact, doc note is clear and gives the exact keyword-form
  replacement.
- `IO.warn` message in `Qx.Draw.Tables.render/2` names the facade, the
  underlying function, the removal version, and the replacement — good
  quality; `Qx.Register` is `@moduledoc false` so no doc-autolink hazard from
  referencing it in the warning string (it's a plain string, not backticked
  in `@doc`).
- Test coverage present and TDD-shaped for all 5 items (range doctest +
  `barrier_dispatch_test.exs`; `initial_state`/`get_state` equality test in
  `quantum_circuit_state_test.exs`; Register-vs-tensor `capture_io` test in
  `state_table_register_deprecation_test.exs`).
