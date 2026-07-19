## Requirements Coverage (from plan `.claude/plans/cswap-iswap-matrix-tests/plan.md` — legacy qx-uos)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Test asserts `Gates.cswap()` matrix equals reference **exactly** | MET | `test/qx/cswap_iswap_matrix_test.exs:80-85` — `assert_complex_matrix_equal` (entrywise delta 1e-12, not global-phase-tolerant) called on `Gates.cswap(0,1,2,3)` against a hand-built reference |
| 2 | Test asserts `Gates.iswap()` matrix equals reference with **+i** convention | MET | Exact 4×4 ref at `test/qx/cswap_iswap_matrix_test.exs:118-129`; explicit sign guard at lines 132-143 (`assert_in_delta Complex.imag(e12), 1.0, @delta`) |
| 3 | Convention documented in moduledoc with citation | MET | (a) test `@moduledoc` at lines 12-14 names "OpenQASM 3.0 `cswap` / `iswap` (Qiskit `CSwapGate` / `iSwapGate`)"; (b) `lib/qx/gates.ex` `@doc` for `iswap/3` (diff line 9): "Convention: OpenQASM 3.0 `iswap` / Qiskit `iSwapGate`"; for `cswap/4` (diff line 21): "Convention: OpenQASM 3.0 `cswap` / Qiskit `CSwapGate`" — both by name, no invented URL |
| 4 | Both tests run in CI (`mix test`) — file in default ExUnit path, no excluding `@tag` | MET | `mix test test/qx/cswap_iswap_matrix_test.exs` ran 5 tests, 0 failures; no `@tag :skip` or similar; file lives at `test/qx/` (auto-discovered) |

### Plan-phase notes

- Phase 1 (cswap/4 normalized to `:c64` `{2ⁿ,2ⁿ}`): doctest updated in diff (line 33 shows `{8,8}` shape); body change in diff at line 38. MET.
- Phase 2 (citations in both `@doc`s): confirmed above (AC 3). MET.
- Phase 3 (new test file, all 5 cases): 3 CSWAP + 2 iSWAP tests present and passing. MET.
- Phase 4 (human-gated merge workflow): out of scope — not evaluated.

**Summary**: 4 MET · 0 PARTIAL · 0 UNMET · 0 UNCLEAR
