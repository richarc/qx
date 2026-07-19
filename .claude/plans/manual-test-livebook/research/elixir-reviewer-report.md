# Elixir Reviewer Report: test/qx_manual_test.livemd (docs/manual-test-livebook)

## Summary
- **Status**: ✅ Approved
- **Issues Found**: 2 (0 critical, 0 warnings, 2 suggestions)

Verified against source (`lib/qx/gates.ex`, `lib/qx/patterns.ex`,
`lib/qx/operations.ex`, `lib/qx/step.ex`, `lib/qx/format.ex`,
`lib/qx/export/openqasm.ex`, `lib/qx/draw/svg/circuit.ex`, `CHANGELOG.md`)
rather than by inspection alone, for every claim the headless eval script
could not check:

- **Bloch-position prose** (H, X, Y, Z, S, S†, T, T†, Rx/Ry/Rz(π/2),
  Phase(π/4), U(π/2,0,π), teleportation θ=2π/3): hand-computed each gate
  matrix from `Qx.Gates` against the claimed Bloch-sphere position. All
  correct, including the two flagged-for-special-attention ones:
  - Rx(π/2)|0⟩ → (0.707, −0.707i) = |−i⟩ = **−Y equator**. Matches.
  - U(θ=2π/3,0,0)|0⟩ → (cos 60°, sin 60°) = (0.5, 0.866), Bloch vector
    (sin θ, 0, cos θ) = (0.866, 0, −0.5): **XZ plane, below equator,
    +X side**. Matches §11's claim exactly, and P(|1⟩)=sin²(π/3)=0.75
    is correct.
- **Circuit-diagram prose**: cross-checked against
  `lib/qx/draw/svg/circuit.ex` render functions — CX (dot + ⊕ target,
  connecting line), CCX/Toffoli (two control dots + ⊕ target, line
  spans min/max y), CSWAP (control dot + two × markers, spanning
  line), CP (control dot + `"P(#{format_param})"` labelled box on the
  target wire — `format_param` renders `π/2` for that exact float),
  S†/T† labels (`"S†"`/`"T†"` per `circuit.ex:679,681`), and the
  barrier-accepts-range claim (`CHANGELOG.md` confirms v0.11). All
  descriptions match the renderer.
- **Teleportation protocol narrative**: `c_if(1, 1, fn c -> Qx.x(c, 2) end)`
  then `c_if(0, 1, fn c -> Qx.z(c, 2) end)` — X keyed on c1 (q1's
  measurement), Z keyed on c0 (q0's measurement) — matches both the
  standard protocol and the prose ("X keyed on c1, Z keyed on c0").
- **Dagger-gate draw fix claim** ("`sdg` previously raised
  `{:unsupported_gate, :sdg}` when drawn"): verbatim match to
  `CHANGELOG.md` line 42.
- **`from_qasm_function/1` return shape and codegen output**: matches
  the function's own `@doc` example exactly (`%{name: "bell", arity: 3,
  source: ...}`, `defmodule Qx.Generated.Bell_<hash>`,
  `def bell(circuit, a, b)`).
- **`Qx.Step` inspect/show format**: `Qx.Step.show/1`'s doctest and the
  `Inspect` impl's own header comment confirm the `#Qx.Step<N: ...>`
  line shapes and the `"1.000|11⟩"`-style coefficient-always-shown
  amplitude formatting (`Qx.Format.format_term/4` always prints the
  magnitude, even for 1.0) used in §7's seeded-trajectory expectations.
- **Qubit-ordering / index consistency**: q0 = MSB is stated once in
  §4 and used consistently everywhere after (bell_pair(1,2) → |000⟩/
  |011⟩ on a 3-qubit circuit, ghz(1..3) → |0000⟩/|0111⟩ on 4 qubits,
  h_all(1..2) → uniform over the last two bits with q0 fixed at 0 —
  all verified against `Qx.Patterns` source and match the stated
  ordering).
- **Tier-1-only API surface**: no `Qx.Qubit`/`Qx.Register` (calc mode)
  call anywhere in the file. The one tier-2 call,
  `Qx.Export.OpenQASM.from_qasm_function/1` in §9, is correctly
  flagged in prose as deliberate ("all from the `Qx` facade... " —
  actually the prose says "all from the Qx facade" but this one call
  is the exception; see suggestion #2 below). The deprecated
  `Qx.superposition/1` is mentioned only as a labelled replacement
  note, never called.
- **Livebook hygiene**: no direct `Kino.*` calls in any code cell (two
  prose mentions of `Kino.Render` are correct — `Qx.Draw.Image` does
  have a `Kino.Render` `defimpl` in `lib/qx/draw/kino_render.ex`).
  Cross-cell bindings `pi`, `theta`, `teleport` are each defined before
  first use and referenced only in later cells, in document order.
  `Mix.install` block is sane (path dep + kino + vega_lite family).
- **Intro section list vs. actual sections**: the 11 bullet points in
  "Introduction" match the 11 `##`/`###` section headers 1:1, in order.

## Critical Issues
None.

## Warnings
None.

## Suggestions

1. **Line 202 (§1, U gate subsection)**: "With θ=π/2, φ=0, λ=π this
   equals the Hadamard gate up to global phase" is weaker than what's
   actually true. Working the matrix (`Qx.Gates.u/3`: cos_half=
   sin_half=0.7071, exp_phi=1, exp_lambda=−1, exp_phi_lambda=−1) gives
   exactly `[[0.707, 0.707], [0.707, −0.707]]` — i.e. **exactly** H,
   not merely H up to some nontrivial phase factor. Not wrong (any
   exact match is trivially "up to phase 1"), but the wording invites a
   reader to expect a visible phase difference between the two Bloch
   dots, which doesn't exist here (and indeed the cell's own `#
   Expected:` comment says "up to invisible global phase" while the
   phase is actually 1, not merely invisible). Consider: "with θ=π/2,
   φ=0, λ=π this is exactly the Hadamard matrix."
   ```elixir
   # Current
   # ... this equals the Hadamard gate up to global phase ...

   # Suggested
   # ... this is exactly the Hadamard gate (the global-phase factor
   # here happens to be 1) ...
   ```

2. **Line 735 (§9 intro)**: "Export a circuit to OpenQASM 3.0 text,
   inspect it, re-import it, and generate Elixir source from a QASM
   `gate` definition — all from the `Qx` facade (v0.11)." This is
   slightly inaccurate: `to_qasm/2`, `from_qasm!/1` are `Qx` facade
   delegates (confirmed in `lib/qx.ex:1663,1702`), but
   `from_qasm_function/1` (used two cells later) has **no** facade
   delegate and is called directly as
   `Qx.Export.OpenQASM.from_qasm_function/1` — which the code cell
   itself gets right. Only the section's intro sentence overclaims
   "all from the Qx facade." Minor wording fix:
   ```elixir
   # Current
   # ... all from the `Qx` facade (v0.11).

   # Suggested
   # ... export/import via the `Qx` facade; code generation via
   # `Qx.Export.OpenQASM.from_qasm_function/1` directly, which has no
   # facade delegate (v0.11).
   ```
