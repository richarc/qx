# Test Review: test/qx/state_init_vector_test.exs

## Summary

12 tests, pure-library module (no DB, no processes, no Mox). Structure mirrors
`state_init_test.exs` well. Two blockers found; the delegation-equivalence
describe block has a logical flaw that makes those tests tautological.

---

## Iron Law Violations

**Iron Law #1 (ASYNC BY DEFAULT)** — violated at line 2. See BLOCKER-1.

Iron Law #8 (precision feasibility at c64 float32): the `1.0e-6` tolerance at
line 76 is fine — a GHZ state for 5 qubits has only 2 non-zero amplitudes
(`inv_sqrt2`), so the probability sum is `0.5 + 0.5` with a single float32
add. Accumulated error is sub-epsilon. No violation.

---

## Issues Found

### BLOCKER

- **BLOCKER-1 — Missing `async: true` (line 2)**
  `use ExUnit.Case` without `async: true`. This module is a pure Elixir
  library: no DB, no Application env mutation, no global process state.
  Every test here can run concurrently.
  Fix: `use ExUnit.Case, async: true`

- **BLOCKER-2 — Delegation-equivalence tests are tautological (lines 81–95)**
  The implementation (lib/qx/state_init.ex lines 317–319 and 376–378) is:
  ```elixir
  def bell_state(which \\ :phi_plus, type \\ :c64), do: bell_state_vector(which, type)
  def ghz_state(num_qubits, type \\ :c64), do: ghz_state_vector(num_qubits, type)
  ```
  `bell_state(w) == bell_state_vector(w)` reduces to
  `bell_state_vector(w) == bell_state_vector(w)` — always true regardless of
  what `bell_state_vector` returns. The tests cannot fail (short of a
  compile error). They provide zero coverage of delegated correctness.
  Fix: these tests should assert that the deprecated functions produce a
  result matching a known-correct reference — e.g. compare the returned
  tensor against a hand-built expected value, or at minimum assert a
  non-trivial property (like correct shape and probability distribution)
  through the deprecated name. Alternatively, acknowledge in a comment that
  delegation coverage is supplied by the compiler (the deprecated wrapper is
  a trivial one-liner) and drop these tests.

### WARNING

- **WARNING-1 — Bell state probability tests cannot distinguish variants by
  phase (lines 19–47)**
  `:phi_plus` and `:phi_minus` have identical probability distributions
  (both concentrate on |00⟩ and |11⟩ at 0.5 each). `:psi_plus` and
  `:psi_minus` are similarly identical under probability. The new tests
  check only probabilities, so if `bell_state_vector(:phi_minus)` returned
  the `:phi_plus` tensor the tests would still pass. The existing
  `state_init_test.exs` adds amplitude sign assertions (lines 263–279) for
  the deprecated `bell_state` name; `bell_state_vector` has no equivalent.
  Fix: add two amplitude-sign tests mirroring lines 263–279 of
  `state_init_test.exs`, reading from `bell_state_vector` directly.

- **WARNING-2 — Duplicate test description for `:psi_minus` (line 39)**
  `test ":psi_minus has amplitude in |01⟩ and |10⟩"` is word-for-word
  identical to the `:psi_plus` test name on line 29. ExUnit will not error
  on duplicate names within a describe block, but any tooling that groups
  or filters by name (e.g. `mix test --only`) becomes ambiguous.
  Fix: rename to `":psi_minus has amplitude in |01⟩ and |10⟩ with opposite phase"`.

### SUGGESTION

- **SUGGESTION-1 — No assertion for the default tensor type**
  The `:c128` override is tested (lines 99–105) but there is no test
  confirming `bell_state_vector()` and `ghz_state_vector(3)` default to
  `{:c, 64}`. A single `assert Nx.type(...) == {:c, 64}` per function
  would pin the contract.

- **SUGGESTION-2 — Exact `== 0.0` sum assertions (lines 55, 62, 68)**
  `Enum.at(probs, 1) + Enum.at(probs, 2) == 0.0` and
  `Enum.sum(Enum.slice(...)) == 0.0` are exact equality on floats.
  These are safe here (the implementation writes literal `C.new(0.0, 0.0)`
  so `|0|² = 0.0` exactly) and match the style of `state_init_test.exs`.
  Acceptable as-is, but using `approx_equal?(&1, 0.0)` would be more
  defensive if the implementation ever changes to computed zeroes.

- **SUGGESTION-3 — No guard-fires test for invalid `which` atom**
  `bell_state_vector(:foo)` currently raises `FunctionClauseError` (no
  catch-all clause). A test asserting `assert_raise FunctionClauseError`
  or, better, that `Qx.StateInit` routes through `Qx.Validation` (Iron Law
  #7: expose typed `Qx.*Error` not raw Elixir errors) would expose whether
  the public API needs a guard branch. This is a separate design question
  but the test gap is worth recording.
