# Scratchpad: u-gate-convention

## Convention derivation (verified by hand)

Qx implements (gates.ex:279-290), matching Qiskit `UGate` / OpenQASM 3.0:

```
U(θ,φ,λ) = [[ cos(θ/2),          -e^(iλ)·sin(θ/2) ],
            [ e^(iφ)·sin(θ/2),  e^(i(φ+λ))·cos(θ/2) ]]
```

Special cases (exact in this convention — Qiskit's UGate adds no global phase):

- U(π,0,π):   cos(π/2)=0, sin(π/2)=1 → [[0, -e^{iπ}],[1, 0]] = [[0,1],[1,0]] = X
- U(π/2,0,π): cos/sin = 1/√2        → [[1/√2,1/√2],[1/√2,-1/√2]] = H
- U(0,0,0):                          → [[1,0],[0,1]] = I
- U(π,π/2,π/2): → [[0,-e^{iπ/2}],[e^{iπ/2},0]] = [[0,-i],[i,0]] = Y

Decomposition: U(θ,φ,λ) = RZ(φ)·RY(θ)·RZ(λ) up to global phase e^{i(φ+λ)/2}.
Tests are global-phase-tolerant regardless, which is convention-robust.

## Decisions

- Test at the **matrix level** (`Qx.Gates.u/3` vs `pauli_x/hadamard/identity/
  pauli_y` and vs `rz·ry·rz`) rather than statevector amplitudes — this is
  the "decomposition identity test" the acceptance criteria ask for and is
  global-phase-tolerant.
- New file `test/qx/u_gate_convention_test.exs` rather than extending
  `u_gate_test.exs` — avoids modifying existing assertions (TDD rule #2)
  and keeps the convention-lock self-contained.
- Cite by spec/library **name**, not URL (no URL guessing).
- Doc-only for the public API → no CHANGELOG / no version bump.

## Open decisions / dead-ends

- (none yet)

## Out-of-scope / discovered work

- Sibling ROADMAP item qx-uos ("matrix-equality tests for CSWAP and iSWAP")
  could reuse the `assert_unitary_equal_up_to_phase` helper — note for that
  plan; not pulled in here.
- DISCOVERED (review, 2026-05-16): `lib/qx/gates.ex:197,221` — `ry/0` & `rz/0`
  `@doc` examples use `math.pi/2` (missing `:` module prefix). Not executed
  as `iex>` doctests so the suite stays green; pre-existing, untouched by
  this branch. Fix on a separate `fix/` branch (add a ROADMAP line if it
  doesn't get picked up).
