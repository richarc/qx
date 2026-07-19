# Iron Law Review — fix/tap-state-initial-state (vs 68e7ffd)

Scope: `lib/qx/operations.ex` (`tap_state/2`, `tap_probabilities/2`),
`test/qx/operations_tap_test.exs`, `CHANGELOG.md`, `ROADMAP.md`.

## Verdict: PASS (no BLOCKERs)

## Per-law findings

### Law #6 — Public API surface / breaking change (`Qx.Operations` is declared-public)
- **Status**: WARNING (judgment call, not a blocker)
- **File**: `lib/qx/operations.ex:871-875`, `926-930`; `CHANGELOG.md:8-19`
- This is a behaviour change to a public function's runtime output (tap now
  sees post-gate state instead of always `|0...0⟩`), plus a new raise path
  (`Qx.MeasurementError`) that didn't exist before. Law #6 literally reads
  "REQUIRE a CHANGELOG entry and a major-version bump." A CHANGELOG entry
  exists (`## [Unreleased]` → `### Fixed`), but there is no version bump in
  `mix.exs` (still `0.9.0`) yet, and the entry is filed under `Fixed` rather
  than a `Changed`/breaking heading.
- Mitigating context supports treating this as non-blocking: (1) the repo is
  pre-1.0, where SemVer treats any 0.x.y segment as free to break and a
  *minor* bump (not major) is the accepted convention — Law #6's "major
  bump" language assumes a post-1.0 project; (2) the prior behaviour was an
  undisputed bug that contradicted its own docstring (tap always returned
  initial state, docs said "current state") — fixing a doc-contradicting bug
  is conventionally a `Fixed` entry, not a `Changed`/breaking one; (3) no
  caller could have been relying on the buggy behaviour as a feature.
- **Recommendation**: bump `mix.exs` to `0.10.0` (minor, pre-1.0 convention)
  before release, per the repo's own release-prep rule ("bump version +
  CHANGELOG" before tagging) — this is a release-gate item, not a
  merge-gate blocker. The existing `Fixed` CHANGELOG entry is adequate as
  written; no split into a `Changed` section is required.

### Law #7 — Typed `Qx.*Error` across the API boundary
- **Status**: PASS
- **File**: `lib/qx/operations.ex:872, 927`
- `tap_state/2` and `tap_probabilities/2` delegate directly to
  `Qx.Simulation.get_state/1` and `get_probabilities/1`
  (`lib/qx/simulation.ex:218-224, 267-273`), which raise
  `Qx.MeasurementError` (not raw `ArgumentError`/Nx errors) when the
  circuit-so-far contains measurements/conditionals. No `rescue`/`try` in
  the tap functions that could swallow or re-wrap as an untyped error. `##
  Raises` docs on both functions correctly document `Qx.MeasurementError`.
  No raw Nx/Complex/ArgumentError leakage observed.

### Law #8 — Tolerance feasibility at `:c64` (float32)
- **Status**: PASS
- **File**: `test/qx/operations_tap_test.exs:7`
- `@tolerance 1.0e-6`, with a comment citing the Iron Law directly ("`:c64`
  states are complex float32 (eps ~1.2e-7); 1.0e-6 per Iron Law #8"). This
  is at the floor of feasibility, not below it — consistent with the law's
  ~1.0e-6 guidance, not the disallowed sub-epsilon (e.g. `1.0e-10`) case.
  Used consistently in all `assert_in_delta` calls (lines 20-21, 56-59).

### Law #5 — No host-side `2^n` loops
- **Status**: PASS
- **File**: `lib/qx/operations.ex:871-875, 926-930`
- The diff adds no new iteration over amplitudes; it replaces a stale-state
  read with a delegation to existing `Qx.Simulation.get_state/1` and
  `get_probabilities/1`, which are the same vectorised paths already used
  elsewhere. No new `defn`/`Enum`/`for` over `2^n` introduced.

### Law #1 — `String.to_atom/1` on caller strings
- **Status**: PASS (not applicable) — no atom/string handling in the diff.

### Law #2 — No process without runtime reason
- **Status**: PASS (not applicable) — no GenServer/Agent/Task introduced.

### Laws #3/#4 (Nx kernel gather/backend discipline)
- **Status**: PASS (not applicable) — no `defn`/`lib/qx/calc*.ex` touched;
  the tap functions are plain delegation, not kernels.

## Summary
- Laws checked: 7 of 8 applicable (Laws #3/#4 N/A to this diff).
- Violations found: 0 BLOCKER, 1 WARNING (Law #6 version-bump timing —
  release-prep item, not a merge blocker), 0 SUGGESTION.
