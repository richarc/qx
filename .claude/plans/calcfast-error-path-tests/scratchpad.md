# Scratchpad — calcfast-error-path-tests (qx-eb1)

Decisions, open questions, and dead-ends for the CalcFast error-path /
edge-case test work.

## Key decisions

### D1 — Test the module directly via a new `test/qx/calc_fast_test.exs`
`Qx.CalcFast` is `@moduledoc false` and today is exercised only
*indirectly* through `Qx.Calc` (`calc_test.exs`) and `Qx.Simulation`.
That indirection is exactly why the rewrite in v0.8.2 is risky: nothing
pins the kernels' own behaviour. We add a dedicated file that calls
`Qx.CalcFast.*` directly, so the v0.8.2 reshape (gather/select →
reshape + 2×2 contraction) has a behavioural net to check against.

Rejected: extending `calc_test.exs` (tests the `Qx.Calc` wrapper, not
the kernels in isolation) — would not isolate the rewrite target.

### D2 — "Invalid inputs" = characterization tests, NOT typed-error assertions
CalcFast performs **no** input validation. Out-of-range / negative
qubit indices flow straight into bit-shift math; a wrong-length state
or non-2×2 gate flows into Nx ops. There is no `Qx.*Error` at this
layer — typed errors live upstream in `Qx.Validation` /
`Qx.Operations`, reached only via the public `Qx.*` API (the Iron
Law #7 sweep already covers that boundary).

So the invalid-input tests **pin the raw behaviour** (assert it
raises *something* — `ArgumentError`/`ArithmeticError`/Nx error — or
produces a defined result), and the file's moduledoc states plainly
that CalcFast is unvalidated by design. We do **not** add a validation
branch to the `defn` hot path — that is out of scope (pure test
additions) and against the module's perf intent. If we later *want*
validation at this layer, that is a separate v0.8.x roadmap item, not
this one.

### D3 — New file is born `async: true`
Pure compute, no shared state. The separate roadmap item "flip 16
pure-compute test files to async" is about *existing* files; a new one
should just start async rather than add to that backlog.

### D4 — MSB qubit convention is the thing most worth pinning
Every kernel encodes `bit_pos = num_qubits - 1 - qubit` (qubit 0 =
MSB). The reshape rewrite is most likely to silently flip this. Use
explicit 3-qubit basis-state truth tables (all 8 states) so a
convention flip fails loudly.

## Boundary / scope notes
- Two dispatch paths for `apply_single_qubit_gate/4`: the
  `num_qubits == 1` head (`Nx.dot`) and the compiled multi-qubit head.
  BOTH need direct coverage — they are different code.
- `apply_single_qubit_gate_compiled` / `_direct` are `defn`/`defnp`;
  test through the public arity-4 head, not the private defn.
- Reuse the local `complex_approx_equal?` / `state_approx_equal?`
  tolerance helpers from `calc_test.exs` (there is no shared test
  support helper for this). Tolerance 1.0e-6 (consistent with the
  c64-tolerances work already merged).

## Open questions
- (resolved) Should invalid-input raise typed errors? → No, see D2.
- None blocking.

## Implementation notes (post-work)

### Phase 5 divergence — non-2×2 gate does NOT raise
Plan Phase 5 expected "Non-2×2 gate matrix — assert raises." Measured
behaviour on the compiled multi-qubit head is **no raise**: the kernel
reads only `gate[0..1][0..1]`, so an oversized gate produces a defined
(physically meaningless) result. Per **D2** we pin the *actual*
behaviour — the test uses a 3×3 gate with a Pauli-X top-left block and
asserts it acts as X on qubit 0 (`|00⟩ → |10⟩`), proving the trailing
row/column are ignored. The other four invalid-input cases raise
`ArgumentError` (out-of-range qubit → "cannot right shift by -1";
negative qubit / state-length mismatch → Nx out-of-bounds take).

### Coverage result (Phase 6)
`lib/qx/calc_fast.ex` went from indirect-only coverage to **100.0%**
line coverage (59/59 relevant lines) — the regression net is complete.

## Out-of-scope work discovered (deferred — needs its own fix/ branch)

These came out of `/phx:review` but touch `lib/`, so they are NOT part
of this test-only plan:

- **`lib/qx/calc_fast.ex:145` — wrong `@doc`.** The `@doc` above
  `apply_cswap/5` reads "Applies a Toffoli (CCX) gate" (copy-paste from
  `apply_toffoli`). Should describe CSWAP (Fredkin). One-line doc fix.
- **`test/qx/calc_test.exs` missing `async: true`.** The sibling file
  this one mirrors is still synchronous; it is pure compute and belongs
  in the existing "flip pure-compute test files to async" roadmap item,
  not here.

## Dead-ends
- (none yet)
