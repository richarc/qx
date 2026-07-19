# Code Review: feat/calc-mode-demotion (main...HEAD, 31c4024)

## Summary
- **Status**: ✅ Approved
- **Issues Found**: 3 (0 critical, 0 major, 3 minor)

Scope matches the stated intent exactly: `Qx.Qubit`/`Qx.Register` get
`@moduledoc false` + a short comment block, function bodies untouched
(verified — `Register.new/1`, `tensor_product/1`, `kronecker_product/2`
are unmodified), removed from `mix.exs` `groups_for_modules` and from
the AGENTS.md Iron Law #6 declared-public list, docs/README rewritten
to circuit-mode + `Qx.steps/2`, CHANGELOG has Added/Changed/Deprecated/
Fixed entries, and `skip_undefined_reference_warnings_on: ["CHANGELOG.md"]`
is in place for the historical calc-mode references there.

## Doctest / example verification (traced by hand, not executed)

- `lib/qx.ex` `draw_bloch/2` doctest: `Qx.create_circuit(1) |> Qx.get_state()`
  returns a `{2}` `:c64` tensor (single-qubit statevector) — correct shape
  for `Draw.bloch_sphere/2`, which calls `Bloch.qubit_to_bloch_coordinates/1`
  on a 2-element tensor. Valid.
- `lib/qx.ex` `draw_state/2` doctest: `Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0,1) |> Qx.get_state()`
  returns a `{4}` tensor, piped into `Qx.draw_state/2` → `Draw.state_table/2`
  → `Tables.render/2`. Confirmed in `lib/qx/draw/tables.ex:33-48`: `render/2`
  pattern-matches `%Qx.Register{state: s}`, `tensor when is_struct(tensor, Nx.Tensor)`,
  else raises `Qx.RegisterError`. A raw `Nx.Tensor` hits the middle clause. Valid.
- README "Upgrading from calc mode" migration snippet:
  `Qx.create_circuit(1) |> Qx.h(0) |> Qx.steps() |> Enum.at(-1) |> Qx.Step.show()`
  — `Qx.steps/2` yields one step per gate (here: one `:gate` step for `h`),
  `Enum.at(-1)` materializes the stream and takes the last element (fine for
  a 1-op circuit), `Qx.Step.show/1` needs `state`/`probabilities` set on the
  step, which `Simulation`'s stepper populates. Valid end-to-end.
- `test/qx/calc_mode_internal_test.exs`: `Code.fetch_docs/1` pattern
  `{:docs_v1, _, :elixir, _, :hidden, _, _}` correctly matches the 7-tuple
  `docs_v1` shape (anno, language, format, module_doc, metadata, docs) with
  `module_doc` position pinned to `:hidden`. Correct assertion for
  `@moduledoc false`.

## Warnings
(none)

## Suggestions

1. **`lib/qx.ex:1227` `@spec draw_state(Nx.Tensor.t() | struct(), keyword())`**:
   `struct()` type-checks *any* struct, not just the hidden `Qx.Register.t()`
   — e.g. `Qx.draw_state(%Qx.QuantumCircuit{})` now passes Dialyzer/spec but
   still raises `Qx.RegisterError` at runtime (unchanged runtime behavior,
   just a looser static contract). Given the alternative is referencing a
   hidden type and triggering an ExDoc warning, this is a reasonable
   trade-off — flagging only so it's a deliberate, documented choice rather
   than an overlooked side effect of the doc-warning fix.

2. **`mix.exs` `groups_for_modules`**: `Qx.Step` is declared public in
   AGENTS.md (Iron Law #6 surface, "Public API surface" bullet and the
   complexity-score table) but has no entry in any `groups_for_modules`
   group (unlike `Qx.SimulationResult`, which is grouped under "Simulation &
   Results"). It will render in ExDoc's default/ungrouped module list. Not
   introduced by this diff (pre-existing gap, `Qx.Step` predates this
   commit) but worth a follow-up line in `ROADMAP.md` since this PR touched
   the same `groups_for_modules` block for the calc-mode removal.

3. **`mix.exs` `groups_for_modules` "Error Handling"**: `Qx.ParameterError`,
   `Qx.RegisterError`, `Qx.BasisError`, and `Qx.Hardware.ExecutionError`
   (all defined in `lib/qx/errors.ex`) are absent from the "Error Handling"
   group, same pre-existing/out-of-scope caveat as above — noted for
   completeness since the reviewed diff didn't touch `errors.ex`.

## Verified, no issues

- No accidental behavior change in `Qx.Qubit`/`Qx.Register`: only
  `@moduledoc false` + comments added; all `def`/`defp` bodies match
  pre-demotion logic (spot-checked `Register.new/1,2`, `tensor_product/1`,
  `kronecker_product/2`).
- No leftover public-facing reference to the hidden modules outside the
  intentional "Upgrading from calc mode" migration section in README.md
  (grep across README.md/AGENTS.md/lib/qx.ex for `Qx.Register`/`Qx.Qubit`
  turned up only that section, the AGENTS.md Iron Law #6 prose describing
  the demotion itself, and unrelated `Qx.QubitIndexError`/`Qx.QubitCountError`
  hits).
- `Qx.Behaviours.QuantumState` moduledoc correctly explains why
  `Qx.Qubit` doesn't implement the behaviour (different arg shape) —
  unaffected by this diff, still accurate.
- CHANGELOG `Deprecated` entry wording matches the AGENTS.md Iron Law #6
  description of the demotion (hidden, no stability guarantee, removal
  deferred to v1.0) — consistent story across both files.
