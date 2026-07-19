# Review: cswap-iswap-matrix-tests (merge gate)

**Verdict: PASS WITH WARNINGS**

Scope: `lib/qx/gates.ex` (modified) + `test/qx/cswap_iswap_matrix_test.exs` (new).
Agents: elixir-reviewer, testing-reviewer, iron-law-judge, requirements-verifier (all 4 ran).

- **0 BLOCKER · 2 WARNING · 2 SUGGESTION · 1 note**
- Iron Laws: **0 violations** (7/7 applicable laws COMPLIANT or N/A).
- Requirements (qx-uos): **4 MET · 0 PARTIAL · 0 UNMET · 0 UNCLEAR**.
- Bit-math independently verified by hand by two agents: `cswap(0,1,2,3)`→rows 5↔6,
  `cswap(2,0,1,3)`→rows 3↔5, `iswap(0,1,2)`→ +i at [1][2]/[2][1]. All correct.
- Reference matrices confirmed independent of `Qx.Gates` (not tautological).

---

## Requirements Coverage (plan `.claude/plans/cswap-iswap-matrix-tests/plan.md` — qx-uos)

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | `Gates.cswap()` matrix == reference **exactly** | MET | `cswap_iswap_matrix_test.exs:80-85` — entrywise delta 1e-12, hand-built ref |
| 2 | `Gates.iswap()` == reference with **+i** | MET | exact 4×4 ref lines 118-129 + explicit sign guard lines 132-143 (`imag == 1.0`) |
| 3 | Convention documented in moduledoc + citation | MET | test `@moduledoc` lines 12-14 **and** `gates.ex` `@doc` for `cswap/4` & `iswap/3` (OpenQASM 3.0 / Qiskit, names only, no URL) |
| 4 | Tests run in CI (`mix test`) | MET | default ExUnit path, no excluding tag; 5 tests, 0 failures |

---

## Warnings

### W1 — `lib/qx/gates.ex` `cswap/4` `@doc`: "real 0/1 permutation tensor" reads as contradicting `:c64`
The doc says `Returns a :c64 {2ⁿ,2ⁿ} real 0/1 permutation tensor`. Values are
real (0/1) but the dtype is complex; "real … tensor" alongside `:c64` will
confuse readers. Suggested: `… permutation tensor (all entries are real 0 or 1).`
(Doc-only; no behaviour impact.)

### W2 — `cswap_iswap_matrix_test.exs:42-43`: `List.flatten/1` on `Nx.to_list` output is fragile
`a = actual |> Nx.to_list() |> List.flatten()` is **correct today** (`%Complex{}`
are leaf nodes, and the helper checks shape first). But if the tensor
representation ever reverted to a `{2,n,n}` real/imag split, `flatten` would
silently flatten the imag axis too and compare garbage instead of failing
loudly. An explicit two-level comprehension
(`for row <- Nx.to_list(actual), e <- row, do: e`) fails loudly on a shape
change. Future-proofing, not a current defect.

## Suggestions

### S1 — `lib/qx/gates.ex` `cswap/4`: `Math.complex_matrix([[C.new(1, 0)]])` → `Nx.tensor([[1]], type: :c64)`
The `iswap/3` precedent uses `Math.complex_matrix` because `C.new(0,1)` is a
genuinely complex value. For CSWAP the value is `1+0i`; `Nx.tensor([[1]],
type: :c64)` is simpler, allocation-free, and makes the "real integer 1" intent
obvious. Identical output — pure simplification.

### S2 — `assert_complex_matrix_equal/3`: report `row R, col C` instead of flat index (raised by 2 agents)
Failure message says `flat index 13`; for an 8×8 matrix `row 1, col 5` is far
more actionable. Thread `n = elem(Nx.shape, 0)` and report `div/rem`, or iterate
rows×cols. Diagnostics-only.

## Note (optional, low value)

The "negative-control sanity" test exercises only `cswap(0,1,2,3)`. The
`cswap(2,0,1,3)` full-matrix test already asserts the entire matrix (including
its control-off rows) exactly, so the dedicated negative-control test is
redundant-but-correct. Harmless; keep or drop at author's discretion.

---

## Merge-gate disposition

No blockers, no UNMET requirements, no Iron Law violations — this is a
PASS-class verdict and the merge gate is satisfiable. W1 (doc wording) and
S1 (simplification) are ~2-line touch-ups in `gates.ex`; W2/S2 are
test-robustness/diagnostics. None block merge; all are author's-discretion.
