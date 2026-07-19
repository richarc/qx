# Qx public API audit

**Branch:** _not yet_ — this is a **findings-and-proposals plan**. Each
finding becomes a checkbox; the user picks which to elevate to a
fix. Several findings interact (the leaked-internals fixes overlap
with the proposed `Qx.Internal.*` namespace decision), so this plan
groups them by category and proposes phases that can ship
independently.

**Source:** User request — "perform an audit of the Qx public API,
check for leaks from what should be private functions, check for
inconsistencies, check for duplication or redundancies".

**Target version:** Most low-risk doc-only fixes (`@doc false` tags,
docstring corrections) fit the unreleased `0.8.0` scope. Anything
that **moves a public function** (rename, namespace change, removal)
is a breaking change and must wait for **v1.0.0** per the existing
`v1.0 — Stability & Production Readiness` ROADMAP entry. Each
finding's row in the table below flags which version it fits.

## Audit method

Surveyed every `lib/qx/*.ex` module:
1. Counted `def` (public) vs `defp` (private) and `defdelegate`.
2. For every public function, asked: *would a user calling
   `iex> use Qx; Qx.…` find this in their workflow, or is it a
   library-internal helper?*
3. Cross-checked names across modules for duplication and naming
   collisions.
4. Cross-checked error types, return shapes, and arity conventions
   for inconsistency.
5. Checked `mix.exs` `groups_for_modules` against the actual public
   surface — modules labelled "Low-Level" or "Validation &
   Utilities" should mostly be `@doc false`, but currently aren't.

Total findings: **23**. Broken into 4 categories: **Leaks** (8),
**Inconsistencies** (8), **Duplication / redundancy** (4),
**Dead code** (3).

---

## A — Leaks: functions that look private but are `def`

These are documented public API surfaces (`def`, with `@doc`) used
**only** from inside `lib/`. They appear in ExDoc, in the navigation
sidebar, and in IDE auto-complete — but a typical user never calls
them. The choices are: tag `@doc false` (cheapest, non-breaking; the
function stays callable but disappears from docs) or move to a
`Qx.Internal.*` namespace (cleanest, breaking, v1.0 work).

| # | Finding | Citation | Verdict | Fit |
|---|---|---|---|---|
| A1 | `Qx.QuantumCircuit.add_gate/4`, `add_two_qubit_gate/5`, `add_three_qubit_gate/6`, `add_measurement/3` — used only by `Qx.Operations` and `Qx.Patterns`; the user-facing API is `Qx.h(qc, 0)` etc. | `lib/qx/quantum_circuit.ex:102-229` | `@doc false` (callable for advanced users adding custom gates; not in docs) | 0.8.0 |
| A2 | `Qx.Validation.validate_qubit_index!/2`, `validate_qubit_indices!/2`, `validate_qubits_different!/1`, `validate_classical_bit!/2`, `validate_state_shape!/2`, `validate_parameter!/1`, `validate_gate_name!/1`, `validate_num_qubits!/1`, `validate_renormalize!/1`, `validate_normalized!/2` — all internal contracts; never called from outside lib/qx/. | `lib/qx/validation.ex:18-307` (approx) | `@doc false` for all `validate_*!`; **keep public** `valid_qubit?/2` and `valid_register?/2` (these are user-facing predicates). | 0.8.0 |
| A3 | `Qx.Gates.*` — all 20 functions are matrix factories used only by `Qx.Calc`, `Qx.CalcFast`, `Qx.Simulation`. `mix.exs` already labels the module "Low-Level Operations" but every function is `def` with `@doc`. | `lib/qx/gates.ex:1-end` | `@doc false` for all (the module stays public for the "I want to inspect the matrix of gate X" use case, but individual functions are no longer ExDoc-indexed). Alt: move to `Qx.Internal.Gates` (v1.0). | 0.8.0 |
| A4 | `Qx.Calc.*`, `Qx.CalcFast.*` — same shape as A3. "Low-Level" group label; only used by `Qx.Simulation` and the simulation handlers. | `lib/qx/calc.ex`, `lib/qx/calc_fast.ex` | `@doc false` for `apply_single_qubit_gate/4`, `apply_cnot/4`, `apply_toffoli/5`, `apply_cswap/5`. Alt: move to `Qx.Internal` (v1.0). | 0.8.0 |
| A5 | `Qx.Math.complex_to_tensor/1`, `tensor_to_complex/1`, `complex_matrix/1` — internal converters between `Complex.t()` and `Nx.Tensor.t()`. Not user-facing. (`complex/2`, `identity/1`, `basis_state/2`, `unitary?/1`, `probabilities/1` *are* user-facing — keep public.) | `lib/qx/math.ex` | `@doc false` only on the three converters; rest stay public. | 0.8.0 |
| A6 | `Qx.Format.*` — `complex/2`, `basis_state/2`, `dirac_notation/2`, `state_label/2`. All used only by `Qx.Draw`, `Qx.Draw.Tables`, `Qx.Draw.VegaLite`, `Qx.Register.show_state`. | `lib/qx/format.ex` | `@doc false` on the whole module's public functions (or `@moduledoc false` + collapse to a single hidden helper). Keep callable so existing internal callers still work. | 0.8.0 |
| A7 | `Qx.ResultBuilder.from_counts/3` — internal helper for `Qx.Hardware` result decoding. Not used outside lib/. | `lib/qx/result_builder.ex` | `@doc false` (function stays callable for hardware modules). Alt: move under `Qx.Hardware.ResultBuilder` (v1.0). | 0.8.0 |
| A8 | `Qx.Simulation.run/2`, `get_state/2`, `get_probabilities/2` — the top-level `Qx.run/2`, `Qx.get_state/2`, `Qx.get_probabilities/2` delegate-with-normalisation to these. The `Qx.Simulation.*` functions are documented public; a user can legitimately bypass `Qx.*` and call them directly. **Not a leak in itself**, but worth flagging: every other layer-2 module (`Qx.Operations`, `Qx.Patterns`) is also documented public, so the pattern is consistent — *keep as-is*. | `lib/qx/simulation.ex:79-244` | No change. (Audit-resolved finding.) | — |

---

## B — Inconsistencies

| # | Finding | Citation | Verdict | Fit |
|---|---|---|---|---|
| B1 | **`Qx.bell_state/1` vs `Qx.StateInit.bell_state/2`** — same name, **different return types**: top-level returns a `%QuantumCircuit{}` recipe; `StateInit` returns a state-vector `Nx.Tensor`. Confusing collision. | `lib/qx.ex:1137-1165`, `lib/qx/state_init.ex:264-296` | Rename the **state-vector** form to `Qx.StateInit.bell_state_vector/2` (or `bell_statevector/2`). Pro: aligns with `superposition_state/2` which already includes the "_state" suffix to signal "returns a state vector". Breaking change — v1.0. For 0.8.0: docstring cross-link both functions explicitly so the distinction is unmissable. | docstring → 0.8.0; rename → v1.0 |
| B2 | **`Qx.ghz_state/0` vs `Qx.StateInit.ghz_state/2`** — same name, **different arity AND return type**. Top-level is hardcoded 3-qubit circuit. | `lib/qx.ex:1179-1184`, `lib/qx/state_init.ex:328-345` | Same fix as B1: rename `StateInit.ghz_state/2` → `ghz_state_vector/2`. Also fix `Qx.ghz_state/0` to accept an optional `num_qubits` arg (currently hardcoded 3 — limiting). | docstring → 0.8.0; rename + n-qubit support → v1.0 |
| B3 | **`Qx.superposition/0` vs `Qx.StateInit.superposition_state/2`** — different names already (good), but `Qx.superposition/0` is hardcoded 1-qubit. Should accept `num_qubits`. | `lib/qx.ex:1198-1200` | Extend signature: `Qx.superposition(num_qubits \\ 1)`. Backward-compatible (default arg). | 0.8.0 |
| B4 | **State-shaped helpers (`bell_state`, `ghz_state`, `superposition`) defined inline in `lib/qx.ex`** instead of delegated to a sibling. Every other top-level Qx function is a `defdelegate` to `Qx.Operations` / `Qx.Patterns` / `Qx.Draw` / `Qx.Simulation`. This is the *only* place top-level Qx has its own `def` (besides `run` / `get_state` / `get_probabilities`, which need argument normalisation). | `lib/qx.ex:1137-1200` | Move bodies to a new `Qx.Circuits` module (or extend `Qx.Patterns`); replace inline `def`s with `defdelegate`. Net code is the same, but placement is consistent. | 0.8.0 (additive — old name kept via delegate; no break) |
| B5 | **`Qx.Register` has incomplete gate parity with circuit mode.** Missing: `iswap/3`, `cp/4`, `cy/3`, `crx/4`, `cry/4`, `crz/4`, `cswap/4`, `u/5`, `measure_x`/`measure_y`/`measure_z`. (Has: `h`, `x`, `y`, `z`, `s`, `sdg`, `t`, `rx`, `ry`, `rz`, `phase`, `cx`, `cz`, `ccx`.) Calc-mode users get a strictly smaller toolkit than circuit-mode users. | `lib/qx/register.ex:97-209` | Add the missing gates as direct state-vector evolutions, mirroring the existing pattern. Each is ~10 lines. Pure additive. | 0.8.x (a separate plan slug) |
| B6 | **`Qx.Qubit` lacks basis-explicit measurement.** `measure_probabilities/1` exists; `measure_x/measure_y/measure_z` do not, even though their circuit-mode counterparts shipped in QAAL-parity. | `lib/qx/qubit.ex` | Add three methods. Each is a 2-line wrapper. Pure additive. | 0.8.x |
| B7 | **`Qx.Qubit.draw_bloch/2` is `def`-wrapper, not `defdelegate`.** Single-line body just calls `Qx.Draw.bloch_sphere/2`. Every other "this delegates" pattern in the codebase uses `defdelegate`. | `lib/qx/qubit.ex` (def around line ~30) | Convert to `defdelegate draw_bloch(qubit, options \\ []), to: Qx.Draw, as: :bloch_sphere`. | 0.8.0 |
| B8 | **`Qx.Hardware.transpile/3` clause shape vs `Qx.Hardware.run/3` shape** — `transpile/3` dispatches on input type via two clauses; `run/3` and `submit_qasm/3` are two separate functions even though they conceptually overlap (`run` accepts a `QuantumCircuit`, `submit_qasm` accepts a binary). Minor: consider unifying to `Qx.Hardware.run/3` with a `QuantumCircuit | binary` first-arg, mirroring `transpile/3`. | `lib/qx/hardware.ex:run/3, submit_qasm/3, transpile/3` | Documentation cross-link in 0.8.0; signature unification in v1.0. | docstring → 0.8.0; unify → v1.0 |

---

## C — Duplication / redundancy

| # | Finding | Citation | Verdict | Fit |
|---|---|---|---|---|
| C1 | **`Qx.Math.basis_state/2` vs `Qx.StateInit.basis_state/3`** — both produce a basis-state vector. `Math` version is f32 with no type arg; `StateInit` is c64 (default) with type arg. Two functions, same job. | `lib/qx/math.ex:basis_state/2`, `lib/qx/state_init.ex:basis_state/3` | Remove `Qx.Math.basis_state/2` (mark `@doc false` and `@deprecated "Use Qx.StateInit.basis_state/3"` in 0.8.0; delete in v1.0). All known callers use the `StateInit` version. | deprecate → 0.8.0; remove → v1.0 |
| C2 | **`Qx.Math.identity/1` vs `Qx.Gates.identity/0`** — different shapes (Math is generic n×n real, Gates is 2×2 c64) but identical name. Pedagogically confusing if a user is exploring matrices for gates. | `lib/qx/math.ex:identity/1`, `lib/qx/gates.ex:identity/0` | Rename `Qx.Math.identity/1` → `Qx.Math.identity_matrix/1` for clarity. Breaking — v1.0. For 0.8.0: docstring cross-link. | docstring → 0.8.0; rename → v1.0 |
| C3 | **`Qx.Format.basis_state/2` — third function named `basis_state`** in the codebase. This one returns a *string label* like `"|01⟩"`. Different semantic class from C1, but the name collision is real. | `lib/qx/format.ex:basis_state/2` | Combined with A6 — `@doc false` makes this no longer ExDoc-visible, which removes the name collision from the user's point of view. | 0.8.0 |
| C4 | **`Qx.QuantumCircuit.reset/1` name collision with future `Qx.reset/2` (ROADMAP v0.9 A3 — mid-circuit reset).** Existing `reset/1` clears the entire circuit (instructions + state + measurements); the planned A3 `reset/2` resets a single qubit mid-circuit. Same verb, very different scope. | `lib/qx/quantum_circuit.ex:reset/1` | Rename existing `Qx.QuantumCircuit.reset/1` → `Qx.QuantumCircuit.clear/1` (or `reset_circuit/1`) before A3 lands. Breaking — needs to happen by v1.0 *or* before v0.9.0 A3 ships, whichever comes first. | depends on A3 timing — likely v0.9.0 prep |

---

## D — Dead code

| # | Finding | Citation | Verdict | Fit |
|---|---|---|---|---|
| D1 | **`Qx.Error` exception type is never raised**. Documented as "base exception" but `grep -r 'raise Qx.Error'` returns zero hits. Elixir exceptions don't have inheritance, so a user `rescue Qx.Error` clause catches *nothing* qx-raised. CHANGELOG explicitly tells users they *can* use it — that's misleading. | `lib/qx/errors.ex:1-6` | Either (a) remove `Qx.Error` (truly dead) **or** (b) document accurately ("placeholder — not currently raised; will be added as the supertype if Qx ever uses a multi-rescue idiom") **or** (c) implement it as the rescue-everything supertype by re-raising. Option (b) is the safest immediate fix. | 0.8.0 (docstring); removal → v1.0 |
| D2 | **`Qx.Behaviours.QuantumState` is defined but no module implements it**. `grep -r '@behaviour Qx.Behaviours.QuantumState'` returns only the example in the behaviour's own moduledoc. `Qx.Qubit`, `Qx.Register`, `Qx.QuantumCircuit` all separately export `h`, `x`, etc. but none `@behaviour` it. The behaviour appears in ExDoc under "Behaviours" group, suggesting it's part of the public API. | `lib/qx/behaviours/quantum_state.ex` | Either (a) **implement it** on `Qx.Qubit` and `Qx.Register` (forces gate-parity completion — see B5/B6), **or** (b) remove the behaviour module (dead). Option (a) is the principled fix; it would *enforce* gate parity going forward. | (a) → v0.8.x; (b) → 0.8.0 |
| D3 | **Unused `Qx.QubitCountError` boundary check is only fired by `Qx.Validation.validate_num_qubits!/1`, which is only called by `Qx.Register.new/1`** — `Qx.QuantumCircuit.new/1,2` uses a guard (`when num_qubits > 0`) and does *not* call `validate_num_qubits!`. So a 25-qubit circuit (above the documented 20-qubit cap) succeeds silently from the QuantumCircuit path. | `lib/qx/quantum_circuit.ex:new/1,2`, `lib/qx/validation.ex:validate_num_qubits!` | Add `Qx.Validation.validate_num_qubits!(num_qubits)` to `QuantumCircuit.new/1` and `/2`. Pure bug fix (closes a hole the existing validator was meant to plug). | 0.8.0 |

---

## Proposed phases

The findings fall into three natural shipping units. Each can be a
separate plan and PR/branch; nothing here ships in one omnibus.

### Phase A — `@doc false` sweep + docstring fixes (0.8.0, non-breaking)

Targets: A1, A2, A3, A4, A5, A6, A7, B1 (docstring only), B2 (docstring only), B7, C1 (deprecate only), C2 (docstring only), C3, D1 (docstring), D3.

- [ ] Tag `@doc false` on the leaked-internals functions (A1–A7).
- [ ] `@deprecated "Use Qx.StateInit.basis_state/3"` on
      `Qx.Math.basis_state/2` (C1).
- [ ] Cross-link docstring fixes on B1, B2, C2 to point readers at
      the right function for their use case.
- [ ] Convert `Qx.Qubit.draw_bloch/2` from `def`-wrapper to
      `defdelegate` (B7).
- [ ] Add `Qx.Validation.validate_num_qubits!/1` call to
      `QuantumCircuit.new/1,2` (D3 — bug fix).
- [ ] Rewrite `Qx.Error` `@moduledoc` to be honest about its
      current non-raising status (D1).
- [ ] Verification gate: `mix compile --warnings-as-errors && mix
      format --check-formatted && mix credo --strict && mix test`.
- [ ] Verify `mix docs` warning set unchanged vs baseline; verify
      newly-hidden modules no longer appear in the sidebar.

### Phase B — Additive parity / gate completion (0.8.x, non-breaking)

Targets: B3, B5, B6, D2-option-(a).

- [ ] Extend `Qx.superposition/num_qubits` to accept an optional
      arg (B3).
- [ ] Complete `Qx.Register` gate parity: add `iswap`, `cp`, `cy`,
      `crx`, `cry`, `crz`, `cswap`, `u` (B5). Each ~10 lines.
- [ ] Add `Qx.Qubit.measure_x/1`, `measure_y/1`, `measure_z/1`
      (B6).
- [ ] Add `@behaviour Qx.Behaviours.QuantumState` to `Qx.Qubit`
      and `Qx.Register` (D2). Update the behaviour callbacks to
      cover the full gate set. This enforces parity going forward.
- [ ] State-shaped helpers reorganisation (B4): move
      `Qx.bell_state`/`Qx.ghz_state`/`Qx.superposition` bodies
      into a sibling module; keep top-level entries as
      `defdelegate`. Pure refactor.

### Phase C — Breaking renames + removals (v1.0)

Targets: B1 (rename), B2 (rename), B8 (unify), C1 (delete),
C2 (rename), C4 (`reset/1` rename — *or* sooner if A3 lands first),
D1 (remove `Qx.Error`), D2-option-(b) (remove behaviour if not
implemented).

- [ ] Rename `Qx.StateInit.bell_state/2` → `bell_state_vector/2`
      (B1).
- [ ] Rename `Qx.StateInit.ghz_state/2` → `ghz_state_vector/2`,
      add `num_qubits` to top-level `Qx.ghz_state` (B2).
- [ ] Unify `Qx.Hardware.run/3` and `submit_qasm/3` (B8).
- [ ] Delete `Qx.Math.basis_state/2` after the 0.8.0 deprecation
      window (C1).
- [ ] Rename `Qx.Math.identity/1` → `identity_matrix/1` (C2).
- [ ] Rename `Qx.QuantumCircuit.reset/1` → `clear/1` (C4) —
      **may need to ship earlier**, see note below.
- [ ] Remove `Qx.Error` (D1) if not used by then.
- [ ] Remove `Qx.Behaviours.QuantumState` if Phase B didn't
      implement it (D2 option b).

**C4 ordering note:** if A3 (`Qx.reset/2` mid-circuit reset) is
implemented before v1.0, the `QuantumCircuit.reset/1` rename must
ship in the same release as A3 (or earlier) to avoid the collision.
Add a guardrail: when the A3 plan opens, the first phase is to
rename `QuantumCircuit.reset/1` → `clear/1`.

---

## Out of scope (deferred / not relevant to this audit)

- **Tests for the new visibility** — Phase A's `@doc false` tags
  are docstring-only; the functions remain callable, so all
  existing tests still pass without modification.
- **`Qx.Internal.*` namespace migration** — the cleaner v1.0 fix
  for A1–A7. Listed under each finding as the "Alt" option, but
  not yet committed to a phase. Worth a separate spike before v1.0
  if the user wants to take that path instead of `@doc false`.
- **`mix.exs` `groups_for_modules` reorganisation** — currently
  groups make some modules look more "public" than they are
  (Validation & Utilities, Low-Level Operations). Phase A's
  `@doc false` sweep makes the group labels irrelevant for
  individual functions; further restructuring is a v1.0 concern.
- **The 20-qubit cap** — `Qx.Validation.validate_num_qubits!`
  enforces 1..20. The cap is documented but D3 reveals it's not
  enforced from all paths. Once D3 is fixed, the cap is honest;
  *raising* the cap (or making it configurable) is a separate
  performance question.

---

## Verification gate (qx CLAUDE.md mandatory)

For each phase that's elevated to a real plan:

```
mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict
mix test
```

Plus, for Phase A specifically: `mix docs` and visual diff of
sidebar contents to confirm the newly-hidden functions disappear
from the docs.

---

## Notes / Iron Law compliance

- **Iron Law #6 (public API surface):** Phase A is the entire point
  of this audit — but `@doc false` is the *non-breaking* fix; it
  hides from docs without changing callability. Phase B is purely
  additive. Phase C is genuinely breaking and demands the v1.0
  bump.
- **Iron Law #7 (typed errors):** D3 (`validate_num_qubits!` not
  called from `QuantumCircuit.new`) is itself an Iron Law #7 hole
  — out-of-range qubit count succeeds silently instead of raising
  `Qx.QubitCountError`. Phase A fixes that path.
- **No new exception types proposed.** Existing `Qx.QubitCountError`
  is reused; the `Qx.Error` decision (rewrite docs vs delete) is
  documentation-only in Phase A.

## Risks

1. **`@doc false` is reversible but easy to over-apply.** A
   user-facing matrix factory (`Qx.Gates.hadamard/0`) that someone
   *does* call from a Livebook would silently disappear from docs
   if hidden. Mitigation: search public Livebook tutorials and
   `qxportal/priv/static/tutorials/*.livemd` for usage of every
   function before tagging, and grep the existing test suite.
2. **Phase B's `Qx.Behaviours.QuantumState` implementation forces
   future gate additions to update all three modules in lockstep**
   (`Qx.Operations`, `Qx.Register`, `Qx.Qubit`). That's the
   *point* — it's the enforcement mechanism. But it's a real cost
   when adding a single new gate.
3. **Phase C is breaking — v1.0 commitment needed.** This plan
   doesn't propose a v1.0 timeline; it just notes that several
   debts compound into a coherent v1.0 cleanup. Until v1.0, the
   debt accumulates.

## Stop conditions

Each elevated phase becomes its own `.claude/plans/<slug>/plan.md`
and its own branch. This audit plan does *not* implement anything;
it terminates after presenting findings to the user.
