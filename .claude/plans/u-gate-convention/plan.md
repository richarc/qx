# Plan: Document and test U gate parameter convention explicitly

**ROADMAP:** v0.8 — line 50, "Document and test U gate parameter convention explicitly (qx-xt2)"
**Branch:** `feat/u-gate-convention` (create from `main` before `/phx:work`)
**Complexity:** 1 (LOW) — docstring precision + test hardening for an already-correct gate
**Type:** documentation + test coverage (no API change, no kernel change)

## Context

`Qx.Gates.u/3` (`lib/qx/gates.ex:279`) already implements the
**Qiskit / OpenQASM 3.0** general single-qubit unitary:

```
U(θ,φ,λ) = [[ cos(θ/2),          -e^(iλ)·sin(θ/2) ],
            [ e^(iφ)·sin(θ/2),  e^(i(φ+λ))·cos(θ/2) ]]
```

Verified by hand against this convention (all hold **exactly**, no residual
phase in Qiskit's `UGate`):

- `U(π, 0, π)` = X
- `U(π/2, 0, π)` = H
- `U(0, 0, 0)` = I
- `U(π, π/2, π/2)` = Y

Relation to rotations: `U(θ,φ,λ) = RZ(φ)·RY(θ)·RZ(λ)` **up to a global
phase** `e^{i(φ+λ)/2}`.

The implementation is correct. The gap is purely (a) the docstrings do not
cite the exact convention/reference or the decomposition identity, and
(b) existing tests in `test/qx/u_gate_test.exs` only spot-check `Complex.real`
of statevector amplitudes — there is no global-phase-tolerant matrix-level
identity test as the acceptance criteria require.

Doc appears in **three** places that must stay consistent:
- `lib/qx/gates.ex:257-290` — `Qx.Gates.u/3` (matrix builder)
- `lib/qx/operations.ex:249-284` — `Qx.Operations.u/5` (circuit op)
- `lib/qx.ex:469-495` — `Qx.u/5` (public delegate + `@spec`)

## Acceptance criteria (from qx-xt2)

1. Doc on `Qx.u/5` cites the exact convention with a named reference.
2. Tests verify `U(π,0,π)==X`, `U(π/2,0,π)==H`, `U(0,0,0)==I` up to global phase.
3. Parameter names in `@spec`/`@doc` match the documented convention.

## ⚠️ Hook caveat (read before Phase 2)

A `PreToolUse` hook in `.claude/settings.local.json` **hard-blocks** any
`Edit`/`Write` to a path matching `*_test.exs`. This applies to a *new*
test file too. Phase 2 will trip it — that is expected (TDD guard). At
`/phx:work` time: stop, state the intended new tests to the human, get
explicit approval, then proceed. Do **not** modify existing assertions in
`u_gate_test.exs` (TDD rule #2) — add a **new** file instead.

---

## Phase 1 — Documentation (3 files, keep wording identical)

- [x] `lib/qx/gates.ex` — replaced `u/3` `@doc`: added convention +
      decomposition block, added `U(0,0,0)=I` special case, θ/φ/λ param
      names. Doctest `Nx.shape(Qx.Gates.u(0,0,0)) == {2,2}` still passes.
- [x] `lib/qx/operations.ex` — same convention + decomposition + `U(0,0,0)=I`
      applied to `u/5` `@doc`; `## Parameters` / `## Raises` kept.
- [x] `lib/qx.ex` — same convention + decomposition applied to `Qx.u/5`
      `@doc`. Confirmed `@spec` (lib/qx.ex:494) is `circuit, qubit, theta,
      phi, lambda` — matches θ,φ,λ order; left unchanged.
- [x] No URL invention — cited "OpenQASM 3.0 specification built-in `U`
      gate" and "Qiskit `qiskit.circuit.library.UGate`" by name only.

**Verify Phase 1:** `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict` (docstring doctests must still pass: `mix test --only doctest` or full run).

## Phase 2 — Global-phase-tolerant identity tests (NEW file)

Create `test/qx/u_gate_convention_test.exs` (do **not** edit the existing
`u_gate_test.exs`). Get human approval first (hook).

- [x] Added private helper `assert_unitary_equal_up_to_phase/3` —
      `Nx.to_list/1` + `List.flatten/1`, first ref entry with
      `Complex.abs > 1.0e-9`, ratio via `Complex.divide`, `|r|≈1` and
      entrywise `a≈r·b` (real & imag) at delta `1.0e-6`.
- [x] Test `U(π,0,π) ≈ pauli_x()` — passes.
- [x] Test `U(π/2,0,π) ≈ hadamard()` — passes.
- [x] Test `U(0,0,0) ≈ identity()` — passes.
- [x] Test `U(π,π/2,π/2) ≈ pauli_y()` — passes.
- [x] Decomposition test (data-driven `for`/`unquote`): `{0.7,1.1,0.3}`,
      `{π/3,π/5,-π/4}`, `{2.0,0.0,1.0}` vs `rz(φ)|>Nx.dot(ry(θ))|>Nx.dot(rz(λ))`.
- [x] All 7 tests pass first run against current impl (regression lock,
      not red→green) — stated in the file's `@moduledoc`.

**Verify Phase 2:** `mix test test/qx/u_gate_convention_test.exs` then full `mix test`.

## Phase 3 — Close out

- [x] Full gate: compile (warnings-as-errors) ✓, format ✓, credo --strict
      (no issues) ✓, `mix test` → 229 doctests, 703 tests, 0 failures ✓.
- [x] `/phx:review` → **PASS WITH WARNINGS**. 9/9 requirements MET, 0 Iron
      Law violations, 0 blockers. W-A (test-name AST), W-B (matmul comment),
      W-C (helper pivot guard) fixed in `u_gate_convention_test.exs`;
      W-D (1.0e-6 delta) accepted as-is. Suite re-verified green (703
      tests, 229 doctests, 0 failures). Reviews in `reviews/`.
- [x] Squash-merged to `main` as `d77919e` (ROADMAP line 50 ticked in that
      commit), pushed `origin/main`, `feat/u-gate-convention` deleted.
      `main` in sync with `origin/main`. (Branch `-d` failed as expected
      for squash-merge; force-deleted — content fully in d77919e.)
- [x] `/phx:compound` → `.claude/solutions/testing-issues/unitary-equality-up-to-global-phase-qx-gates-20260516.md`
      (gitignored local KB) — captures `assert_unitary_equal_up_to_phase/3`
      pattern for reuse by qx-uos.

## Risks / notes

- Three docstrings can drift — Phase 1 explicitly keeps wording identical
  across all three; a reviewer should diff them.
- The Nx matrix-product order for the decomposition test must match the
  operator convention (`rz(φ)` applied last). If the first decomposition
  test fails by a *global phase only*, the helper still passes — that is
  correct and intended.
- No public API/signature change → no CHANGELOG entry and no version bump
  required (Iron Law #6 does not trigger; doc-only).
- See `scratchpad.md` for the convention derivation and open decisions.
