# Iron Law Judge — qx v0.11 tier trim (feat/stateinit-math-tier-trim)

Scope: lib/qx/math.ex, lib/qx/state_init.ex, lib/qx/qubit.ex, lib/qx/register.ex,
lib/qx/behaviours/quantum_state.ex, lib/qx.ex, AGENTS.md, CHANGELOG.md,
test/qx/math_test.exs, test/qx/tier_trim_test.exs (new).

No Bash access available in this session — verification is by direct Read/Grep
of current file contents against AGENTS.md §IRON LAWS, not `git diff` hunks.
Findings below are therefore state-based ("current code complies/doesn't"),
not diff-based; nothing found needing a diff to interpret (all changes are
additive `@deprecated`/`@moduledoc false`/deletions of already-`@doc false`
functions, consistent with the plan description).

## Law #6 — Public API surface / breaking changes: COMPLIANT

- All 17 functions named in AGENTS.md's updated Iron Law #6 text (9 in
  `Qx.StateInit`, 8 in `Qx.Math`) carry `@deprecated "..."` with a working
  drop-in replacement in the message (math.ex:38,84,105,123,155,187,211,247;
  state_init.ex:99,115,131,148,184,218,278,355,393). None of the deprecated
  functions were deleted — bodies are untouched, confirmed by reading full
  file contents.
- Survivors `StateInit.basis_state/3` (state_init.ex:61) and
  `Math.normalize/1`, `Math.probabilities/1` (math.ex:66,140) carry no
  `@deprecated`. `test/qx/tier_trim_test.exs:37-75` asserts this mapping
  programmatically via `Code.fetch_docs/1` — a durable regression guard.
- Deletion of `Qx.Math.complex_to_tensor/1` and `tensor_to_complex/1`:
  grep confirms zero remaining references anywhere in `lib/`
  (`complex_matrix/1`, math.ex:164, is the surviving internal builder used
  by gate factories). Both deleted functions were already `@doc false`
  (per CHANGELOG "Removed" note and tier_trim_test.exs:53-58) — not part of
  the declared-public surface, so deletion is not a breaking change.
- `Qx.Behaviours.QuantumState` demotion to `@moduledoc false`
  (behaviours/quantum_state.ex:8): callbacks and `@optional_callbacks`
  untouched (lines 15-65); `Qx.Register` still declares
  `@behaviour Qx.Behaviours.QuantumState` (register.ex:9) — grep confirms
  no other module references it. AGENTS.md's Iron Law #6 text
  (line 393) explicitly lists this module as demoted and explains the
  rationale (sole implementor is internal, QuantumCircuit follows the shape
  only by convention) — matches the code state and follows the cited v0.10
  calc-mode precedent (Qx.Qubit/Qx.Register, also `@moduledoc false` with
  the same "still functional, no stability guarantee" framing at
  qubit.ex:1-6, register.ex:1-6).
- CHANGELOG.md `[Unreleased]` has Deprecated / Removed / Changed sections
  (lines 8-51) matching all three categories of change. No version bump
  yet — consistent with `[Unreleased]` convention (bump happens at release
  time per AGENTS.md §Release, not at commit time).

## Law #7 — Typed errors: COMPLIANT (no changes in scope)

No new `raise`/error-path code found in any changed file. `Qx.Qubit.from_basis/1`
still raises `Qx.BasisError` (qubit.ex:191); `Register` still raises
`Qx.RegisterError`/`Qx.QubitIndexError` unchanged. No raw `Nx`/`Complex`/
`ArgumentError` leaks introduced.

## Laws #3/#4/#5 — Nx kernel discipline: COMPLIANT

- Only body change: `Qx.Math.unitary?/1` (math.ex:249-281) now inlines
  `Nx.eye(n) |> Nx.as_type(...)` (line 260) instead of calling the
  deprecated `identity/1` — a self-call swap, comment explicitly notes why
  (avoid lib/ emitting its own deprecation warnings, math.ex:258-259). Same
  gather-free, reshape/contract-only computation as before; no `defn` body
  semantics changed elsewhere (`kron`, `normalize`, `inner_product`,
  `outer_product`, `apply_gate`, `trace`, `probabilities` bodies are
  byte-identical to their pre-trim form — attribute-only additions).
  `unitary?/1` itself is `def`, not `defn` (not a kernel), so this
  substitution is out of scope for the Nx-kernel laws anyway, but it's
  the one flagged "host-side body swap" and it checks out.
- No host-side loops over `2^n` amplitudes introduced or removed.
- No BinaryBackend-incompatible constructs introduced.

## Law #9 — Dispatch completeness: N/A, confirmed

No instruction/message-shape dispatch code touched by this change set
(no `apply_instruction`/producer-consumer shapes in any changed file).

## Laws #1/#2 (String.to_atom, unsupervised process): COMPLIANT

No occurrences of `String.to_atom` or process primitives in any changed file.

## Summary

No violations found. All three at-risk areas (Law #6 surface change, Nx
kernel discipline, error-path integrity) check out against the current file
state: deprecations are additive and reversible, the two deletions are of
already-internal (`@doc false`) dead code, the behaviour demotion follows
the sanctioned v0.10 precedent with callbacks intact and its sole
`@behaviour` user unaffected, and the one non-doctest code body change
(`unitary?/1`'s `identity/1` → `Nx.eye/1` swap) is semantically identical.

**Caveat**: this review was performed via Read/Grep against working-tree
file contents, not `git diff` (no Bash tool available this session). If the
actual uncommitted diff touches lines not visible in a full-file read (e.g.
whitespace-only hunks, or reverted-then-reapplied sections), a
diff-based pass would be needed to catch that class of issue. Nothing in
the current file states suggests such an issue exists.
