# Scratchpad: cswap-iswap-matrix-tests

## Convention (verified intent from qx-uos)

- CSWAP (Fredkin), MSB order, control=q0, targets q1/q2: swaps
  |101⟩↔|110⟩ → 8×8 indices 5↔6 swapped; real 0/1 permutation.
- iSWAP, 2-qubit: `[[1,0,0,0],[0,0,i,0],[0,i,0,0],[0,0,0,1]]` — **+i**
  (not −i) on swapped |01⟩↔|10⟩ amplitudes (indices 1↔2).
- Cite OpenQASM 3.0 `cswap`/`iswap` & Qiskit `CSwapGate`/`iSwapGate`
  by name only — NO URL invention.

## Decisions

- Normalize `Gates.cswap/4` → `:c64` `{2ⁿ,2ⁿ}` (mirror `iswap/3`):
  seed `Nx.eye(n, type: :c64)`, swap-row → zero `[i,i]`, set `[i,j]`
  to `C.new(1,0)`. Update doctest `gates.ex:484` `{8,8,2}`→`{8,8}`.
- EXACT equality (delta `1.0e-12`), NOT the global-phase-tolerant
  helper from u-gate-convention — issue wants sign/control exactness.
- Doc convention in BOTH gates.ex `@doc` (cswap/4 + iswap/3) AND new
  test `@moduledoc` (acceptance #3).
- New file `test/qx/cswap_iswap_matrix_test.exs`; existing
  `cswap_gate_test.exs`/`iswap_gate_test.exs` NOT modified (TDD rule #2).
- No new hex deps → hex-library-researcher N/A.

## Why low-risk (key discovery)

`Gates.cswap/4`'s ONLY consumer is its own `gates.ex:484` doctest.
Simulation `:cswap` → `Calc.apply_cswap` → `Qx.CalcFast.apply_cswap`
(`defn` kernel), independent of the matrix builder. `:iswap` DOES use
`Gates.iswap/3` (`simulation.ex:316`). So normalizing cswap touches
only the doctest; `cswap_gate_test.exs` (statevector behaviour) must
still pass unchanged because it exercises the CalcFast path.

## Open decisions / dead-ends

- (none yet)

## Out-of-scope / discovered work

- `Qx.CalcFast.apply_cswap` (the REAL simulation path for CSWAP) has no
  matrix-level correctness test. qx-uos only covers `Gates.*` builders.
  Note for a follow-on plan/ROADMAP item.
- `lib/qx/gates.ex` `toffoli/4` uses LSB bit convention
  (`Bitwise.bsr(i, control1)`, no `num_qubits-1-` offset) inconsistent
  with cswap/iswap MSB convention — latent bug. Separate `fix/` branch.
- Pre-existing (from u-gate-convention session): `gates.ex:197,221`
  `ry/rz` doc examples use `math.pi/2` (missing `:`). Still open.
