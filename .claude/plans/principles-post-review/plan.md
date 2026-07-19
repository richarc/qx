# Principles-doc post-review edits (v0.11 · T1-09/17/18, B-13, tension #7)

**Branch:** `docs/principles-post-review`
**ROADMAP:** v0.11 "API Review Follow-Through" — the "Principles-doc
post-review edits" item. Ticks that checkbox on merge. **This is the 8th of 9
v0.11 items** — only `qx_manual_test.livemd` remains after this.
**Depth:** standard · **Complexity:** 2 (docs-only, 3 files, no code, no public
API change; the Iron Law #6 rewrite is the one edit needing care).
**Research:** none — the ROADMAP item text is the spec; the original T1-*/B-*
finding reports are gone, but the code confirms each exception's substance
(verified 2026-07-12, see scratchpad).

## Decision

Fold the API-review's outstanding *documentation* debts into
`spec/api-design-principles.md` and `AGENTS.md`. Docs-only; zero code.

1. **Documented exceptions** (the doc's own contract: "a deviation is either a
   finding or a documented exception — we add it here, with the reason"):
   - `Qx.version/0` — zero-arg info fn; no subject, no family (T1-09).
   - `Qx.measure_z/3` — byte-identical alias of `measure/3` (violates §4 "one
     obvious way"); kept for X/Y/Z basis-teaching symmetry.
   - `Qx.get_state/2` raising `Qx.MeasurementError` on measured/conditional
     circuits — a `get_*` ("pure read") that raises; the raise is a typed guard
     against a meaningless question, steering to `run/2`. Still non-mutating.
2. **New §6 naming-family rows** (T1-17/18, B-13 + the rows deferred from
   `circuit-appenders`/`qasm-facade-tdg`): `run`/`steps` (execute/replay),
   `c_if` (classical feedback wrapper), `barrier` (visual no-op marker),
   `*_chain` (linear cascade), and **prep-appenders** (`bell_pair`, `ghz` —
   append a named preparation at chosen qubits; creators `bell_state`/
   `ghz_state` as thin teaching facades). Update the `*dg` row (`sdg, tdg`) and
   delete the stale "tdg question" sentence (answered: native tdg shipped).
3. **§8/§9 adjudications** — record outcomes for the now-resolved tensions:
   #6 (tdg → added natively), #7 (resolved by this change), #8 (appenders added,
   creators reframed — the `feat/circuit-appenders` outcome). Fix §8's stale
   "Patterns currently mixes the two shapes with no appender underneath" prose.
4. **Iron Law #6 flat list → §3 tier annotations** (tension #7): rewrite
   AGENTS.md Iron Law #6 to define the covered surface as **tier 1 + tier 2 per
   each module's moduledoc tier annotation** (§3 of the principles doc) instead
   of the hand-maintained flat module list, PRESERVING: the SemVer rule
   (minor-as-major pre-1.0), the StateInit/Math trimmed-surface details, the
   typed-`Qx.*Error`-are-public note, and the tier-3 examples. Also update the
   STEP 2 complexity-table row that duplicates the same flat list (pointing it
   at the tier annotations) — leaving one stale copy would recreate the drift
   this item exists to fix.

## Phase 1 — `spec/api-design-principles.md` edits

- [x] [P1-T1] §6: add the five new family rows + prep-appenders row; update
      `*dg` members to `sdg, tdg`; delete the answered tdg-question sentence.
- [x] [P1-T2] §6 (end): add a **Documented exceptions** subsection with the
      three exceptions (violated rule + reason each, per the doc's intro
      contract).
- [x] [P1-T3] §8: update the "Patterns currently mixes…" sentence to record the
      resolution (appenders `bell_pair`/`ghz` shipped; creators are wrappers).
      §9: mark tensions #6, #7, #8 adjudicated with one-line outcomes (keep the
      list numbering; the doc says the review starts from this list).

## Phase 2 — AGENTS.md Iron Law #6 tier rewrite

- [x] [P2-T1] Rewrite Iron Law #6's surface definition to the §3 tier
      annotations (tier 1 + tier 2 covered; tier 3 = `@moduledoc false`, no
      promise), preserving the four items listed in Decision-4. Reference
      `spec/api-design-principles.md` §3 as the tier source of truth.
- [x] [P2-T2] Update the STEP 2 complexity-table "declared-public" row to point
      at the tier annotations instead of duplicating the flat list.

## Phase 3 — verify & CHANGELOG

- [x] [P3-T1] CHANGELOG `[Unreleased]` **Documentation**: principles doc gains
      the post-review family rows + documented exceptions; Iron Law #6 now
      defined by moduledoc tier annotations (§3) instead of a flat module list.
- [x] [P3-T2] Gate: `mix compile --warnings-as-errors && mix format
      --check-formatted && mix credo --strict && mix test` (should be untouched
      — docs-only) and `mix docs` count == 36 (spec/ is not an extra; only
      CHANGELOG.md feeds ex_doc, and it has
      `skip_undefined_reference_warnings_on`).

## Iron Laws check

- **#6:** no public code surface touched — this *edits the law's own text*,
  keeping its substance (SemVer rule, trim details, error contract) intact.
  The definition change (flat list → tier annotations) was pre-approved as
  ROADMAP tension #7.
- Docs-only: #1/#7/#8/#9 n/a.

## Risks

1. **Iron Law #6 rewrite loses substance** — the current text encodes real
   decisions (trimmed StateInit/Math surfaces, typed errors public, minor-as-
   major). Mitigation: preserve those verbatim-ish; diff-review the law before
   commit.
2. **Tier annotations don't actually exist on every module** — §3 says tier 2
   moduledocs open with "Utility module: …". Verify the annotation is present
   on the tier-2 modules before pointing the law at it (grep); if any is
   missing, add the opener line (tiny doc fix, in scope).
