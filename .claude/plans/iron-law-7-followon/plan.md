# Iron Law #7 follow-on — typed errors for the last three `Qx.Validation` raises

**Branch:** `fix/iron-law-7-followon` (cut from `main`)
**Source:** `ROADMAP.md` v0.8.1 — two checklist lines:
- "Iron Law #7 follow-on: route `Qx.Validation.validate_parameter!/1` through a typed `Qx.*Error` …"
- "Expand the Iron Law #7 follow-on above to also route `validate_qubits_different!/2` and `validate_state_shape!/2` …"

**Predecessor:** `.claude/plans/iron-law-7-critical/` (shipped in 0.8.0 — C1/C2/C3). This
finishes the H1 leak that plan deferred: `Qx.Validation`'s own raw `ArgumentError`s.
**Target version:** `0.8.x` patch line (v0.8.1). Observable error-type change on the
public gate surface — pre-1.0, so a minor/patch is fine; **CHANGELOG entry required**
(Iron Law #6, `Qx.Operations`).

## Iron Law #7 (qx CLAUDE.md)
> Public functions raise typed `Qx.*Error` on misuse. Do not let raw `Nx` / `Complex` /
> `ArgumentError` leak across the API boundary — route through `Qx.Validation`.

## Decision (settled in planning)
`validate_parameter!` gets a **new `Qx.ParameterError`** exception carrying `:value`
(one-error-per-concept, matching the existing family). The other two reuse errors that
already exist:
- `validate_qubits_different!/1` → `Qx.QubitIndexError.exception({:duplicate, qubits})` (errors.ex:61) — already built by the predecessor plan.
- `validate_state_shape!/2` → `Qx.StateShapeError.exception({actual, expected})` (errors.ex:117).

## Scope facts (verified)
- The three offending raises: `validation.ex:127` (qubits_different), `:152` (state_shape), `:165` (parameter). All carry in-source TODO/follow-on markers.
- **Only `validate_parameter!/1` has `lib/` callers** — `operations.ex:294,295,296` (`u` × theta/phi/lambda), `:454` (`cp`), `:512` (`crx`), `:542` (`cry`), `:576` (`crz`). The other two are currently called only from tests, so no gate docs reference them.
- Public `## Raises` sections naming `ArgumentError` for a parameter: `operations.ex:289` (`u`), `:451` (`cp`), `:509` (`crx`), `:539` (`cry`), `:573` (`crz`). `rx`/`ry`/`rz` docs do **not** list it. No other public module (`qx.ex`, `register.ex`, `qubit.ex`) documents an `ArgumentError` for these paths (verify in Phase 3).
- The `validate_*` functions are all `@doc false` → **no doctests** to fix. The `Qx.Validation` moduledoc doctest (lines 18–19) already demonstrates `Qx.QubitIndexError`; unchanged.

## ⚠ Process gate — existing test edits need approval
`test/qx/validation_test.exs` currently asserts `ArgumentError` for all three functions
(lines 169–182 distinctness, 220 shape, 240–253 parameter). A `PreToolUse` hook
**hard-blocks** editing `*_test.exs`, and TDD rule #2 forbids modifying existing tests
without explicit human approval. These assertions **must** flip to the typed errors —
there is no new-file workaround, because the existing assertions break the moment the
raise type changes. **Get explicit approval before Phase 1's test edits**, and (TDD)
land them red before touching `validation.ex`.

---

## Phase 1 — Tests first (TDD) ⚠ requires human approval to edit `validation_test.exs`
- [x] Get explicit human approval to modify `test/qx/validation_test.exs` (hook + TDD rule #2)
- [x] `validate_parameter!/1` group (lines 240–253): `assert_raise ArgumentError, …` → `assert_raise Qx.ParameterError, ~r/Parameter must be a number/` (and the `~r/"not a number"/` value-echo assertion stays valid against the new message)
- [x] `validate_qubits_different!/1` group (lines 169–182): → `assert_raise Qx.QubitIndexError`. Update the `~r/All qubit indices must be different/` regex to match the new message `Qubit indices must be distinct, got: …`; the `~r/\[0, 1, 0\]/` value-echo assertion still holds
- [x] `validate_state_shape!/2` group (line 220): → `assert_raise Qx.StateShapeError`, regex `~r/State vector size mismatch: expected 4, got 2/` (replaces `Invalid state shape: expected {4}, got {2}`)
- [x] Run `mix test test/qx/validation_test.exs` → confirm **red** (typed errors not raised yet)

## Phase 2 — Route the three raises through typed errors (`lib/qx/validation.ex`)
- [x] Add `Qx.ParameterError` to `lib/qx/errors.ex`: `defexception [:value, :message]`; `exception(value)` → message `"Parameter must be a number, got: #{inspect(value)}"`; `exception(message) when is_binary` fallback (match the family's two-clause convention)
- [x] Add `Qx.ParameterError` to the typed-exception list in the `Qx.Error` moduledoc (errors.ex:8–13)
- [x] `validate_parameter!/1` (validation.ex:164–166): `raise Qx.ParameterError, param`; drop the `# … Raises ArgumentError` comment + follow-on marker
- [x] `validate_qubits_different!/1` (validation.ex:125–132): `raise Qx.QubitIndexError, {:duplicate, qubits}`; update comment, drop marker
- [x] `validate_state_shape!/2` (validation.ex:148–157): `raise Qx.StateShapeError, {Nx.axis_size(state, 0), expected_size}`; update comment, drop the `Iron Law #7 follow-on` marker
- [x] `mix test test/qx/validation_test.exs` → **green**

## Phase 3 — Public gate docs (`lib/qx/operations.ex`)
- [x] `## Raises` `ArgumentError` → `Qx.ParameterError` in `u` (289), `cp` (451), `crx` (509), `cry` (539), `crz` (573) — wording e.g. `* \`Qx.ParameterError\` - If theta/phi/lambda is not a number`
- [x] Grep-confirm no other public `## Raises` names `ArgumentError` for these paths: `grep -rn "ArgumentError" lib/qx.ex lib/qx/operations.ex lib/qx/register.ex lib/qx/qubit.ex` (expect none left referencing parameters)

## Phase 4 — CHANGELOG, verify, roadmap
- [x] `CHANGELOG.md` `[Unreleased]` (or `[0.8.1]`) — Changed: `Qx.Validation` now raises `Qx.ParameterError` / `Qx.QubitIndexError` / `Qx.StateShapeError` instead of `ArgumentError`; the rotation/phase gates (`u`, `cp`, `crx`, `cry`, `crz`) surface `Qx.ParameterError` on non-numeric angles
- [x] Full gate: `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test`
- [x] Tick **both** ROADMAP v0.8.1 follow-on lines in the merge commit (this plan covers both)

## Risks / notes
- **SemVer:** error-type change is observable to anyone rescuing `ArgumentError` from `u/cp/crx/cry/crz`. Pre-1.0 + it's the documented Iron Law #7 contract → acceptable under v0.8.1 with the CHANGELOG entry. Not a major bump.
- **No new deps**, no Nx/`defn` changes, no `mix bench` needed. `hex-library-researcher` intentionally skipped (plan Iron Law #6: nothing to evaluate).
- `validate_qubits_different!/1` and `validate_state_shape!/2` are dead in `lib/` today — routing them is consistency/forward-proofing, not a live-path fix. Noted in scratchpad as a latent gap (multi-qubit gates don't currently call the distinctness check).
