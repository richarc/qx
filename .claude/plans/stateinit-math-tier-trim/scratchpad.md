# Scratchpad — stateinit-math-tier-trim

## Open decisions

- (none blocking) Findings adjudication #3 pre-decided demote-and-trim;
  plan executes it. Veto point offered at plan review: keeping
  `kron`/`inner_product`/`outer_product`/`trace`/`unitary?` as a "quantum
  linear algebra" surface instead of deprecating — R-07 says nothing
  motivates them today (README test fails); plan deprecates all.

## Facts verified 2026-07-08 (supersede R-07 where they differ)

- R-07 said the dead converters have "no callers anywhere" — WRONG for
  tests: `test/qx/math_test.exs:209–233` has three describe blocks using
  `complex_to_tensor`/`tensor_to_complex`. Deletion needs hook approval.
- `lib/qx.ex:57` moduledoc lists `Qx.Behaviours.QuantumState` — must be
  removed at demotion or mix docs warnings rise.
- qxportal tutorial `quantum_state_and_qubit.livemd` teaches
  `Math.normalize/1` + `Math.probabilities/1` ("a small public utility") —
  these MUST stay public; settles the trio-location question (slimmed
  public modules, not internal re-homing).
- Internal callers of soon-deprecated fns (would break
  `--warnings-as-errors`): register.ex:48 (zero_state), qubit.ex:109/125/
  141/156 (one/plus/minus/random), math.ex unitary? → identity.
- mix.exs has no `warnings_as_errors` elixirc option; test-compile
  deprecation warnings are non-fatal.

## Outcome (2026-07-08, all phases done)

- Final survivor surface: `StateInit.basis_state/2,3`;
  `Math.normalize/1`, `Math.probabilities/1` (+ `complex_matrix/1`
  stays `@doc false` internal, untouched). The 17 orphans are
  `@deprecated` with replacement messages; converters deleted;
  behaviour hidden. mix docs 36 = baseline.
- PLAN CORRECTION found by docs stash-diff: the plan's replacement
  pointer `Qx.superposition_circuit/1` does not exist — the real
  function is `Qx.Patterns.superposition_circuit/1` (no Qx facade
  delegate). Deprecation message + moduledoc fixed; consider a facade
  delegate as a v0.11+ nicety if tutorials want it shorter.
- Internal re-homes: register.ex → `basis_state(0, Integer.pow(2, n))`;
  qubit.ex `one` → `basis_state(1, 2)`, `plus`/`minus` → shared
  `hadamard_basis_state(sign)` defp, `random` → inline amps +
  `Math.normalize/1`. Full `--force` recompile of lib/ emits zero
  deprecation warnings.
- Noise: plugin post-edit hook flags pre-existing `IO.puts` in
  qubit.ex show/print helpers and doc examples in qx.ex `tap_*` —
  intentional output/doc snippets, predates this branch, left alone.

## Review (2026-07-08): PASS WITH WARNINGS → all findings applied

- 4 agents (elixir/testing/iron-law/requirements): 0 blockers, 7/7
  requirements MET, all Iron Laws compliant. Artifacts in `reviews/`
  + `summaries/review-consolidated.md`.
- Applied post-review (user-approved, incl. test edits): W1 coverage-
  coupling note in tier_trim_test moduledoc; S2 non-empty-message
  assertions; S1 random_state recipe in deprecation message; S3
  `hadamard_basis_state/1` → `x_eigenstate/1`. A1/A2 (mix test
  deprecation-warning noise) accepted per plan Risk #2 — do NOT
  mistake that warning volume for a regression.
- Gate re-run green after fixes; mix docs still 36 = baseline.
- Merge to main pending human authorization.

## Docs-completeness sweep (2026-07-08, post-review, user-prompted)

- Swept README, CONTRIBUTING, ROADMAP, RELEASE, mix.exs docs config,
  qx.ex prose, and qxportal/kino_qx for the 17 names + behaviour +
  converters. Two real gaps found and fixed:
  1. mix.exs `groups_for_modules` still had the dead
     `Behaviours: [Qx.Behaviours.QuantumState]` group (hidden modules
     are silently dropped by ex_doc — no warning) → removed.
  2. qx.ex bell_state/ghz_state "See Also" blocks recommended the
     deprecated `*_state_vector` constructors without saying so →
     annotated "(deprecated, removal at 1.0 — run this circuit and
     `Qx.get_state/1` instead)".
- Clean surfaces: README (only pre-existing v0.10 calc-engine snippet,
  out of scope), CHANGELOG (has the entries), qxportal tutorials teach
  circuit-mode + Math survivors only (grep hits were `draw_state`/
  `new_state` substring false positives), kino_qx clean.
- Gate re-run green; mix docs still 36 = baseline.

## For later cycles

- Cycle 2 (typed-error sweep): StateInit scope shrinks to `basis_state`
  only; `Math.normalize` zero-vector NaN (R-09) still in scope. The
  "seven StateInit constructors" in the ROADMAP sweep line are deprecated
  by this cycle — do not add validation to them.
- Cycle 6 (docs sweep): @spec targets exclude the 17 deprecated fns.
- 1.0 gate additions from here: remove the 17; R-05 opts-last + R-06
  naming apply only to survivors (basis_state).

## Baselines (Phase 1, recorded 2026-07-08)

- mix docs warning count: **36** (`mix docs 2>&1 | grep -c "warning:"`;
  includes a pre-existing `RELEASE.md` file-ref warning from README)
- @deprecated-on-defn spike result: **WORKS, no fallback needed.**
  `@deprecated` on a `defn` behaves identically to `def`: caller compile
  warning ("SpikeDep.foo/1 is deprecated. …"), `Code.fetch_docs` meta
  `deprecated: "…"` on `foo/1`, and entry in `__info__(:deprecated)`.
  The generated internal `__defn:foo__/1` carries no meta (hidden, fine).
  Spike: scratchpad `spike_deprecated_defn.exs`, Elixir 1.18.4.
- Converter callers re-verified: only `test/qx/math_test.exs:209–232`
  (3 describe blocks) + one historical CHANGELOG.md:378 mention (stays).
- Solution-doc note (deprecate-public-fn-rename-shim, 2026-06-27):
  `@deprecated` call sites do NOT fail `mix compile --warnings-as-errors`
  (deprecation warnings are exempt). Re-homing internal callers (Phase 4)
  is still done for clean output + 1.0-readiness.
