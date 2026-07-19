# Review: Dialyzer install + Dialyzer warning fixes + Credo bump (41496d5..8cc8bdc)

**Verdict: PASS** (the one warning below was fixed post-review; see Resolution)

Scope: 3 commits on `main`, no plan file (ad hoc tooling/typespec maintenance,
not a feature). `514182c` bumps credo 1.7.14→1.7.19 (fixes an Elixir-1.20
sigil-tokenizer crash) and refactors a nested test helper it then flagged.
`7c8c4c0` installs `dialyxir`. `8cc8bdc` fixes the 70 `mix dialyzer` warnings
that install surfaced, and checks off the corresponding `ROADMAP.md` item.

Requirements coverage: not applicable — no task ID / plan / spec detected for
this work (branch is `main`, no matching `.claude/plans/*/` slug), so no
requirements-verifier ran.

Agents run: `elixir-reviewer`, `testing-reviewer`, `security-analyzer`
(`iron-law-judge` skipped — diff is 85 lines excluding `mix.lock`, condition
`>200 lines AND auth/LiveView/Oban files` not met; `verification-runner`
skipped — full suite already green multiple times this session).

## Findings

### Warning

1. **`lib/qx/validation.ex:55`** — `@spec valid_register?(map(), float()) :: boolean()`
   is now so wide it documents almost nothing. The widening was necessary
   (the original closed anonymous shape `%{state: ..., num_qubits: ...}`
   structurally excluded any struct, so `Qx.Register.valid?/1` calling it
   with `%Qx.Register{}` at `lib/qx/register.ex:797` looked like dead code
   to Dialyzer — confirmed real, not gratuitous), but `map()` doesn't tell a
   reader the map needs `:state`/`:num_qubits` keys, even though the
   function head still pattern-matches on them. `elixir-reviewer` suggests
   trying a keyed-map type first (`%{required(:state) => term(), required(:num_qubits) => term()}`)
   to see if it clears the same Dialyzer warning while staying more precise
   — **unverified**, no agent re-ran dialyzer against that alternative. If
   it doesn't help, `map()` + a one-line spec comment noting the required
   keys is an acceptable fallback (not currently present).
   — *elixir-reviewer*

   **Resolution (post-review)**: tried the keyed-map type
   (`%{required(:state) => Nx.Tensor.t(), required(:num_qubits) => integer()}`)
   — Dialyzer still treats it as closed and reproduces the exact original
   3-warning cascade (`Register.valid?/1` "no local return" again). Confirms
   `map()` is genuinely necessary, not just convenient. Reverted to `map()`
   and added an inline comment above the spec explaining why it's
   intentionally bare. Full suite re-verified green (compile, format, credo,
   test, dialyzer all pass).

### Suggestions

1. **`lib/qx/errors.ex`** — only 2 of ~20 exception modules in this file now
   carry `@type t` (the two Dialyzer's new checks happened to touch). Fine
   as a minimal fix, but leaves the file visibly inconsistent. Consider a
   follow-up ROADMAP item to add `@type t` uniformly — library consumers
   often pattern-match on exception types in `rescue` clauses.
   — *elixir-reviewer*
2. `.dialyzer_ignore.exs` entries are well-scoped (file + check-kind pairs,
   not blanket suppression) with clear inline justification — flagged as a
   positive pattern to keep, no change needed. — *elixir-reviewer*

### Pre-existing (not introduced by this diff)

- `lib/qx/validation.ex:56-67` — `valid_register?/2` uses `if/else` over a
  boolean where a `case`/guard reads more idiomatically; already flagged in
  a prior review (`calcfast-norm-drift-guard-review.md:130`). — *elixir-reviewer*
- `lib/qx/hardware/ibm.ex:386` — `"Bearer " <> (config.access_token || "")`
  sends an empty bearer token when nil rather than failing fast; benign
  (server 401s) but masks a missing-token bug. — *security-analyzer*
- `Qx.Hardware.Config` holds API credentials in plaintext (expected for a
  library, but consumers should avoid logging/inspecting the struct).
  — *security-analyzer*

## Verified-sound (no action needed)

- **`Nx.Type.t() | Nx.Type.short_t()`** widening in `state_init.ex`
  (`basis_state/3`, `bell_state_vector/2`, `ghz_state_vector/2`) — confirmed
  against `deps/nx/lib/nx/type.ex`: `short_t()` is Nx's own canonical
  shorthand-atom union, distinct from the tuple form in `t()`. Precise, not
  over-widened. — *elixir-reviewer*
- **`authed_request/5` `:delete` clause removal** (`lib/qx/hardware/ibm.ex`)
  — independently confirmed dead by both `elixir-reviewer` (grepped all 6
  call sites) and `security-analyzer` (confirmed job cancellation uses
  `POST /jobs/{id}/cancel`, never HTTP DELETE — no capability lost).
  **High confidence** (two independent agents, same conclusion).
- **New `@type t`** on `Qx.Hardware.NoMeasurementsError` /
  `Qx.Hardware.ConfigError` — matches `defexception` fields and `exception/1`
  clause output exactly. — *elixir-reviewer*
- **Test refactor** (`test/qx/cswap_iswap_matrix_test.exs`,
  `identity_with_rows_swapped/3` → `swapped_index/3` + `identity_row/2`) —
  verified algebraically behavior-preserving against both call sites
  (`cswap(0,1,2,3)`, `cswap(2,0,1,3)`); no Iron Law violations, no coverage
  regression. — *testing-reviewer*
- **Auth logic surrounding the `:delete` removal** — Bearer token
  header-only (never logged/URL-interpolated), IAM 401 refresh retries
  exactly once, `:safe_transient` retry policy correctly excludes POSTs
  from auto-replay (no duplicate job submission risk), no hardcoded
  secrets. — *security-analyzer*

## Full verification (already run and green this session)

`mix compile --warnings-as-errors` ✅, `mix format --check-formatted` ✅,
`mix credo --strict` ✅ (0 issues), `mix test` ✅ (1405 passed), `mix dialyzer`
✅ (6/6 warnings filtered with justification, 0 unfiltered).
