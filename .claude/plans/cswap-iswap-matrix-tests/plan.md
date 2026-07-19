# Plan: Explicit matrix-equality tests for CSWAP and iSWAP gates

**ROADMAP:** v0.8 — line 51, "Add explicit matrix-equality tests for CSWAP and iSWAP gates (qx-uos)"
**Branch:** `feat/cswap-iswap-matrix-tests`
**Complexity:** ~5 (MED) — crosses Gates↔(doctest); internal repr change + new tests + docs
**Type:** internal representation normalization + test coverage + docs (no public API signature change)

## Context

Legacy issue **qx-uos** (read-only, bd deprecated): existing
`cswap_gate_test.exs` / `iswap_gate_test.exs` only assert probabilistic
statevector outcomes — never the gate matrix. A convention error (wrong
control qubit, wrong sign on the `i` phase) could pass every test.

**Acceptance criteria (qx-uos):**
1. Test asserts `Gates.cswap()` matrix equals reference **exactly**.
2. Test asserts `Gates.iswap()` matrix equals reference with **+i** convention.
3. Convention documented in moduledoc with citation.
4. Both tests run in CI (i.e. in `mix test`).

## Key discovery (drives the plan)

- `Gates.iswap/3` returns a `{4,4}` `:c64` tensor (uses
  `Nx.eye(_, type: :c64)` + `Math.complex_matrix`).
- `Gates.cswap/4` returns a `{8,8,2}` **real** tensor (`Nx.broadcast(0.0,
  {n,n,2})`, real/imag split) — a *different representation*. The
  `gates.ex:484` doctest locks `{8,8,2}`.
- **`Gates.cswap/4`'s only consumer is its own doctest.** Simulation
  routes `:cswap` through `Qx.CalcFast.apply_cswap` (a `defn` kernel),
  NOT the matrix builder (`simulation.ex:334-335` → `Calc.apply_cswap`).
  `:iswap` *does* use `Gates.iswap/3` (`simulation.ex:316-317`).
- ⇒ Normalizing `cswap/4` to `:c64` is **low blast radius**: only the
  doctest shape assertion changes; no simulation/Calc path touched.

## Decisions (confirmed with user 2026-05-16)

1. **Normalize `Gates.cswap/4` → `:c64`** ({8,8} like iswap), fix the
   `gates.ex:484` doctest `{8,8,2}` → `{8,8}`.
2. **Exact** matrix equality (NOT the global-phase-tolerant helper from
   `u-gate-convention` — qx-uos wants exactness to catch sign/control
   errors; these are fixed canonical matrices with no free global phase).
3. Document convention + citation in **BOTH** the new test file
   `@moduledoc` AND the `gates.ex` `cswap/4` & `iswap/3` `@doc`.
4. New test file `test/qx/cswap_iswap_matrix_test.exs` — do NOT modify
   existing `cswap_gate_test.exs` / `iswap_gate_test.exs` (TDD rule #2).
5. No new hex deps (internal Nx + ExUnit) → hex-library-researcher N/A.

## Reference matrices (convention)

Convention: **OpenQASM 3.0** `cswap`/`iswap` (Qiskit `CSwapGate` /
`iSwapGate`). MSB qubit order (qubit 0 = leftmost), matching the rest of
Qx (`num_qubits - 1 - q`).

- **CSWAP** `cswap(0,1,2,3)` — 8×8: identity except basis states with
  control=|1⟩ and differing targets swap. With |q0 q1 q2⟩: swaps
  index 5 (|101⟩) ↔ index 6 (|110⟩). Real 0/1 permutation matrix.
- **iSWAP** `iswap(0,1,2)` — 4×4:
  `[[1,0,0,0],[0,0,i,0],[0,i,0,0],[0,0,0,1]]` — **+i** (not −i) on the
  swapped |01⟩↔|10⟩ amplitudes.

---

## Phase 1 — Normalize `Gates.cswap/4` to `:c64`

- [x] Rewrite `cswap/4` body (`lib/qx/gates.ex:488-513`) to mirror the
      `iswap/3` pattern: seed `Nx.eye(state_size, type: :c64)`; for rows
      where `control_bit==1 and ta_bit!=tb_bit`, zero `[i,i]` and set
      `[i,j]` to `C.new(1,0)` via `Math.complex_matrix`. Keep the MSB
      bit-position logic (`num_qubits-1-q`) unchanged. — done; seed is
      `Nx.eye(:c64)`, swap rows zero `[i,i]` + set `[i,j]`=1, non-swap
      rows keep eye (no else branch needed).
- [x] Update doctest `lib/qx/gates.ex:484`: `{8, 8, 2}` → `{8, 8}`.
- [x] Confirm NO other caller depends on `{8,8,2}` — grep `Gates.cswap`
      across lib/ + test/ shows ONLY the gates.ex:484 doctest. Sim uses
      `Calc.apply_cswap` (CalcFast), not this builder. 16 behaviour
      tests + 229 doctests pass unchanged.

**Verify Phase 1:** `mix compile --warnings-as-errors` + `mix test
test/qx/cswap_gate_test.exs test/qx/draw/cswap_svg_test.exs` (simulation
behaviour must be unchanged — it uses CalcFast, not this matrix) +
`mix test --only doctest`.

## Phase 2 — Document convention + citation

- [x] `lib/qx/gates.ex` `iswap/3` `@doc`: add "Convention: OpenQASM 3.0
      `iswap` / Qiskit `iSwapGate` — **+i** on swapped amplitudes" +
      keep matrix. Cite by name, no URL. — done; added +i convention,
      MSB note, `:c64 {2ⁿ,2ⁿ}` shape.
- [x] `lib/qx/gates.ex` `cswap/4` `@doc`: add "Convention: OpenQASM 3.0
      `cswap` / Qiskit `CSwapGate` (Fredkin). MSB order; control=|1⟩
      swaps the two targets, e.g. |101⟩↔|110⟩." + note it now returns
      `:c64` `{2ⁿ,2ⁿ}`. — done; added Fredkin/CSwapGate citation, MSB
      order, |101⟩↔|110⟩ example, `:c64 {2ⁿ,2ⁿ}` permutation note.
- [x] No URL invention — spec/library name only. — confirmed, names only.

**Verify Phase 2:** `mix compile --warnings-as-errors && mix format
--check-formatted && mix credo --strict` + `mix test --only doctest`.

## Phase 3 — Matrix-equality tests (NEW file)

Create `test/qx/cswap_iswap_matrix_test.exs`. Get human approval first
(test-file hook). `@moduledoc` documents the convention + citation
(criterion #3, second location).

- [x] Private helper `assert_complex_matrix_equal/3`: `Nx.to_list/1`
      both `:c64` tensors, flatten, assert each entry's
      `Complex.real`/`Complex.imag` equal within `1.0e-12` (EXACT — these
      are integer/`i` entries, not floating products). flunk on shape
      mismatch first. — done; shape asserted first with descriptive msg,
      then entrywise with flat-index message.
- [x] Build CSWAP 8×8 reference via `Math.complex_matrix` (eye with rows
      5↔6 swapped). Assert `Gates.cswap(0,1,2,3)` equals it exactly. —
      done via `identity_with_rows_swapped/3` (Gates-independent ref).
- [x] Add a second CSWAP case with permuted qubits (e.g.
      `cswap(2,0,1,3)`) vs its hand-built reference — guards the
      "wrong control qubit" failure mode from the issue. — done;
      `cswap(2,0,1,3)` ⇒ rows 3↔5 (distinct from 5↔6), proves the
      control/target wiring.
- [x] Build iSWAP 4×4 reference `[[1,0,0,0],[0,0,i,0],[0,i,0,0],
      [0,0,0,1]]` via `Math.complex_matrix`. Assert
      `Gates.iswap(0,1,2)` equals it exactly — explicitly asserts the
      `[1][2]`/`[2][1]` entries are `+i` (imag `+1.0`), the
      "wrong sign on i" guard. — done; exact-matrix test + dedicated
      +i sign-guard test asserting imag = +1.0.
- [x] Negative-control sanity: assert `Gates.cswap` leaves
      control=|0⟩ subspace as identity (rows where control bit 0). —
      done; rows 0..3 of `cswap(0,1,2,3)` asserted exact identity.

**Verify Phase 3:** `mix test test/qx/cswap_iswap_matrix_test.exs` then
full `mix test`.

## Phase 4 — Close out (/phx:full continues here)

- [x] Full gate: `mix compile --warnings-as-errors && mix format
      --check-formatted && mix credo --strict && mix test`. — all green:
      compile clean, format OK, credo no issues, 229 doctests + 708
      tests, 0 failures.
- [x] `/phx:review` (MERGE GATE) — verdict PASS WITH WARNINGS: 0
      blockers, 4/4 qx-uos requirements MET, 0 Iron Law violations.
      W1 (cswap @doc wording) + S1 (`Math.complex_matrix`→`Nx.tensor`)
      fixed; W2/S2/note accepted as author's-discretion. Full gate
      re-run green (229 doctests, 708 tests, 0 failures). Awaiting
      human merge authorization.
- [x] On PASS: `git merge --squash`, tick ROADMAP.md line 51
      `- [ ]`→`- [x]` in that commit, `git push origin main`, delete branch.
      — done: branch commit 4890767 → squash commit `6236959` on main
      (ROADMAP qx-uos ticked in it), pushed to origin
      (`d77919e..6236959`), feat branch force-deleted (squash-merge
      leaves no merge commit, `-D` required).
- [x] `/phx:compound` — done: new
      `testing-issues/exact-vs-phase-tolerant-gate-matrix-equality-qx-gates-20260516.md`
      (the exact-vs-phase-tolerant decision rule); corrected the
      over-broad Prevention in the existing
      `unitary-equality-up-to-global-phase-qx-gates-20260516.md` and
      cross-linked both ways.

## Risks / notes

- The new test proves `Gates.cswap/4`/`iswap/3` *matrix builders* are
  correct. It does NOT prove `CalcFast.apply_cswap` (the actual
  simulation path) is correct — that's a separate gap. Recorded in
  `scratchpad.md` as discovered work, not pulled into qx-uos.
- `toffoli/4` uses an LSB bit convention (`bsr(i, control1)`)
  inconsistent with cswap/iswap MSB — latent bug, out of scope; logged
  to scratchpad.
- `Qx.Gates` is not in the Iron Law #6 public-API list; the cswap repr
  change is internal (no signature change, no behaviour change for any
  real consumer) → no CHANGELOG/version bump. The doctest output change
  is the only externally visible delta.
