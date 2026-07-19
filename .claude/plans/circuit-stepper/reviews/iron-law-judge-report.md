# Iron Law Judgment — `feat/circuit-stepper` (qx)

Scope reviewed: `lib/qx/step.ex`, `lib/qx/simulation.ex`, `lib/qx/operations.ex`, `lib/qx.ex`, `test/qx/step_test.exs`, `test/qx/simulation_steps_test.exs`, `test/qx/qx_steps_facade_test.exs`, against `AGENTS.md` §"IRON LAWS".

## #1 — No `String.to_atom/1` on caller input
**VERDICT: N/A.** No occurrences of `String.to_atom`/`to_existing_atom` anywhere in the diff.

## #2 — No process without a runtime reason
**VERDICT: N/A.** No `GenServer`/`Agent`/`Task` introduced. `Qx.Simulation.steps/2` is a lazy `Stream.transform/3` (pure data, no process).

## #3 — Reshape+contract over gather in `defn` kernels
**VERDICT: N/A.** No `defn` and no `lib/qx/calc*.ex` files touched by this diff.

## #4 — `defn` correct on `Nx.BinaryBackend`
**VERDICT: N/A.** No `defn` added. `test/qx/simulation_steps_test.exs:221-228` explicitly exercises `backend: Nx.BinaryBackend`, consistent with the law's spirit even though it doesn't apply directly.

## #5 — No host-side loops over `2^n` amplitudes in NEW code
**VERDICT: PASS for the engine, ACCEPTABLE PRECEDENT for the display API (flagged for awareness).**

- `lib/qx/simulation.ex`: the new `steps/2` machinery (`to_step/2`, `step_timeline_item/7`, `step_conditional/7`) adds no new `for i <- 0..(2^n-1)`-style loops. It calls `Math.probabilities/1` per step (Nx-vectorised) and reuses the pre-existing, grandfathered `perform_single_measurement`/`collapse_to_measurement` host loops (`lib/qx/simulation.ex:713-779`) — per the plan's explicit allowance, this is not a new violation.
- `lib/qx/step.ex:92-102` (`basis_terms/1`, shared by `show/1` and the `Inspect` impl) **is** new code and does perform a host-side `Nx.to_flat_list(state)` + `Enum.zip/with_index/map` over all `2^n` amplitudes.
  - This mirrors the existing `Qx.Register.show_state/1` pattern exactly (same shape, same intent: a display/inspection API, not a simulation-kernel hot path).
  - Judgment: this is **within the spirit of the existing precedent**, not a new class of violation — display APIs at "teaching scale" are a different concern than hot-path kernels. NOT a BLOCKER.
  - Caveat worth flagging (WARNING, not blocker): `Inspect` implementations fire automatically (IEx, `dbg`, failed-assertion output, `Logger`), and Qx circuits go up to 20 qubits (2^20 amplitudes). `basis_terms/1` always materializes the *full* flat list before `Enum.split/2` truncates to 4 terms in `Inspect.inspect/2` (`lib/qx/step.ex:150`) — i.e., the truncation is post-hoc, not lazy. Same cost profile as `Register.show_state/1` today, so it's not a regression, but printing a `%Qx.Step{}` for a 20-qubit circuit does real `2^20`-sized work. Worth a one-line doc caveat, not a stop-ship issue.
- `steps/2`'s per-step `Math.probabilities` call is `O(2^n)` per step but is Nx-native (not a host loop) and was explicitly accepted in the plan for this inspection API. **PASS.**

## #6 — Breaking changes need CHANGELOG + major bump
**VERDICT: PASS.** Additive: new module `Qx.Step`, new functions `Qx.steps/1,2` / `Qx.Simulation.steps/2`. `CHANGELOG.md:8-35` documents both the addition and the (pre-existing, separately shipped) tap fix. No public function signature changed.

## #7 — Public functions raise typed `Qx.*Error`
**VERDICT: PASS.** `steps/2` → `Qx.OptionError` via `Validation.validate_renormalize!/1` (tested); gate dispatch raises `Qx.GateError` (tested via the laziness test). Taps raise `Qx.MeasurementError` via `final_step/2`, never a raw error. `Qx.Step.show/1` / `Inspect` are pure formatting.

## #8 — No sub-1.0e-6 tolerance assertions
**VERDICT: PASS.** All three new test files declare `@tolerance 1.0e-6` and use `assert_in_delta` exclusively at that floor.

---

## Summary

| Law | Verdict |
|---|---|
| #1 to_atom | N/A |
| #2 process | N/A |
| #3 gather | N/A |
| #4 BinaryBackend | N/A |
| #5 host loop 2^n | PASS (engine) / acceptable precedent (display, minor doc suggestion) |
| #6 breaking/CHANGELOG | PASS |
| #7 typed errors | PASS |
| #8 tolerance | PASS |

No blocking Iron Law violations found. One non-blocking suggestion: note in `Qx.Step`'s moduledoc that `Inspect`/`show/1` cost is `O(2^n)` (same as `Qx.Register.show_state/1`), so it's visible for wide registers rather than a surprise.
