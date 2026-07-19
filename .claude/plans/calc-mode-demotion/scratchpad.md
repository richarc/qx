# Scratchpad: calc-mode-demotion

## DECISION: internal engine, not removal (interview 2026-07-03)

AskUserQuestion timed out (user away); proceeded on the recommended
default, explicitly flagged for override at the merge gate. Rationale:
non-breaking (learners' notebooks keep running until the tutorials are
rewritten), zero frozen-test churn (removal would mean deleting
register_test.exs/qubit_test.exs + reworking ~10 helper usages, which
the test-guard forbids without explicit approval), and it doesn't
foreclose removal at v1.0. Design doc called removal "the cleaner end
state"; that stays true and stays deferred.

## DECISION: qx repo only (same interview, same default)

The 6 qxportal tutorials break learners only when v0.10 RELEASES
(qxportal has no qx mix dep). The rewrite is a qxportal work item and a
release-checklist gate, not part of this plan.

## DECISION: no per-function @deprecated attributes

The stateinit precedent used @deprecated on renamed functions; here
that would stamp ~60 working functions with compile-time warnings in a
non-breaking release. Module-level hiding + CHANGELOG Deprecated entry
matches the v0.8.1 public-surface-declaration precedent instead.

## NOTE: hex-library-researcher not spawned

/phx:plan's repo table says "ALWAYS (evaluate hex deps before
adding)" — nothing is added; the plan skill's own Iron Law #6 ("do NOT
spawn for existing deps") governs. No research agents needed: the
plan's research is the coupling/doc inventory, done inline (recorded in
plan.md Summary).

## RESOLVED: Draw.bloch_sphere/2 input contract (Phase 2)

Bloch.qubit_to_bloch_coordinates/1 calls Nx.to_flat_list on its arg and
matches [alpha, beta]. Any 2-element state tensor works, so the
rewritten examples use `Qx.create_circuit(1) |> Qx.h(0) |>
Qx.get_state()` directly. No behaviour change needed.

## FOUND IN PHASE 2 (beyond the plan inventory)

- lib/qx/step.ex had 3 `Qx.Register.show_state/1` doc refs (moduledoc
  ×2 + show/1 @doc). De-linked to plain prose.
- lib/qx.ex draw_bloch/2 + draw_state/2 @docs and doctests were built
  on Qubit/Register pipelines; rewritten over circuit mode. The
  draw_state @spec named `Qx.Register.t()` (ex_doc warns on hidden
  types too); now `Nx.Tensor.t() | struct()`.
- Historical CHANGELOG entries autolink the now-hidden modules. History
  stays as written; added `skip_undefined_reference_warnings_on:
  ["CHANGELOG.md"]` to the docs config instead. Side effect: it also
  silences pre-existing CHANGELOG refs to other hidden modules
  (Hardware.Ibm etc.), so the warning count fell to 54, under the 110
  main baseline.

## OUT OF SCOPE (review findings, pre-existing)

- mix.exs `groups_for_modules`: Qx.Step (declared public) has no group,
  and Qx.ParameterError / Qx.RegisterError / Qx.BasisError /
  Qx.Hardware.ExecutionError are missing from "Error Handling". Both
  predate this branch; candidates for a small docs-config fix later.

## NOTE: debug-statement hook noise

The plugin's PostToolUse hook flags pre-existing IO.puts in qubit.ex
(show_state/tap_state print helpers) and qx.ex (tap_* doc examples) on
every edit to those files. Intentional display API + doc snippets, not
debug leftovers; left untouched (non-breaking guarantee).
