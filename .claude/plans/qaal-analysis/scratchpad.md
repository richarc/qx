# QAAL Analysis — Scratchpad

Open decisions and dead-ends collected during the analysis. Resolve
each before opening the corresponding A/B implementation plan.

## Decisions pending

1. **A1 — naming:** `Qx.cy/3` (lowercase, matches `cx`/`cz`) vs
   `Qx.cY/3` (matches QAAL casing). Recommend lowercase.
2. **A2 — post-measurement-state semantics for `measure_x`/`measure_y`:**
   - Option α: match QAAL — re-apply the basis-change after the
     z-measure so the qubit ends in the ±/±i eigenstate matching the
     classical result. Cost: 1 extra gate per measurement. Benefit:
     correctness if the qubit is reused after a non-Z basis measure.
   - Option β: stay z-aligned — leave the qubit in the
     computational-basis eigenstate. Cheaper; *different* from QAAL.
   - Decision drives whether tutorials can be 1:1 transcriptions or
     need a footnote.
3. **A3 — `reset/2`:** confirm interaction with `:c_if`. Likely
   independent; reset is unconditional in QAAL.
4. **A4 — `Qx.Register` collision:** either generalise the existing
   calc-mode struct to dual-mode (Iron Law #6 → CHANGELOG entry +
   possible major bump on the calc-mode API) **or** pick a new name
   (`Qx.QubitGroup`, `Qx.CircuitRegister`, …). Cleaner long-term but
   requires a design spike.
5. **A4 — slice syntax:** Elixir custom-struct bracket access is not
   idiomatic. Sketch: `Qx.Register.at(r, i)` / `Qx.Register.slice(r,
   i, j)` returns a sub-register (or list of qubit indices).
6. **B1 vs A4 ordering:** B1 (range/list overload of `Qx.Patterns`)
   is a strict subset of A4. Ship B1 only if A4 is deferred or
   rejected — otherwise it's churn.

## Dead-ends (reject + reason recorded)

- **QAAL macro / DSL** — Sussex spec is explicit it isn't a target
  language; Qx CLAUDE.md "only macros if explicitly requested"; pipes
  already clearer than QAAL gotos.
- **Imperative classical control (`!set`, `@loop`, `!jump`)** —
  anti-idiomatic for Elixir; `Enum.reduce` / recursion already cover it.
- **`Qx.Subroutine` struct / behaviour** — Elixir functions on
  `QuantumCircuit.t()` already are subroutines.
- **Mutable parameter arrays (`!array N: n integers`)** — Elixir
  immutability + `Nx.tensor` / lists / maps already cover every QAAL
  use case.

## Material consulted (for reproducibility)

- `Reference material/Week 4_ Many-qubit procedures_ examples and
  intuitions_ Prepare - Reading_ Foundations of Quantum Computing
  [24_25].pdf` — full QAAL specification (sections a–e).
- `Reference material/Foundations of Quantum Computing_Week
  {4,5,6,7}_Study.pdf` — QAAL usage in teleportation, oracles,
  phase estimation, QFT.
- `qx/lib/qx.ex` + `qx/lib/qx/operations.ex` + `qx/lib/qx/patterns.ex`
  + `qx/lib/qx/quantum_circuit.ex` + `qx/lib/qx/register.ex` — current
  Qx surface.
- `qxportal/priv/static/tutorials/quantum_algorithms.livemd` and
  siblings — current tutorial style (hand-rolled `Enum.reduce`-based
  bulk ops).

## Notes

- The `Qx.Patterns` work just merged (commit `8e9f346`) already
  closed the most-glaring QAAL/Qx gap (whole-register `H`/`X`/`Y`/`Z`/
  `measure`/`barrier`/`cx`-chain). The proposals here are
  second-tier — none of them block tutorials *today*, but each
  improves narrative parity with the Foundations module.
