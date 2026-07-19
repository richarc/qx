# Iron Law Violations Report

## Summary

- Files scanned: 18 (AGENTS.md, CHANGELOG.md, lib/qx.ex, lib/qx/validation.ex, 3×SVG,
  5×Export.OpenQASM.*, 2×Hardware, plus supporting context files)
- Iron Laws checked: #6, #7, and the AGENTS.md complexity-score table consistency
- Violations found: 1 (0 critical, 1 high/WARNING, 1 suggestion)

---

## High Violations (WARNING)

### [#6] `Qx.Draw.SVG.Circuit` top-level module is NOT `@moduledoc false`

- **File**: `lib/qx/draw/svg/circuit.ex:2`
- **Code**: `@moduledoc """` (full module documentation, lines 2–27)
- **Confidence**: DEFINITE
- **What happened**: Plan constraint (`Decided constraints`) and P2-T3 both assert
  "circuit.ex already has `@moduledoc false` — verify, then skip; no-op." The
  assertion is wrong. Line 31 of circuit.ex contains `@moduledoc false` for a
  *nested* private struct (`defmodule CircuitDiagram do`), not for the top-level
  `Qx.Draw.SVG.Circuit` module. The top-level module retains `@moduledoc """` and
  will appear as a full public page in ExDoc.
- **Consequence**: CHANGELOG states "the `Qx.Draw.SVG.*` and
  `Qx.Export.OpenQASM.*` sub-modules... are now `@moduledoc false`" — this is
  factually incorrect for `Qx.Draw.SVG.Circuit`. ExDoc will publish it; the
  CHANGELOG entry overstates what was done.
- **Fix**: Add `@moduledoc false` at line 2 of `lib/qx/draw/svg/circuit.ex`,
  replacing the existing `@moduledoc """...""""` block (lines 2–27). Optionally
  demote any implementation-rationale prose to a leading `#` comment. Also
  verify the CHANGELOG entry remains accurate after the fix (it will be once
  circuit.ex is patched).

---

## Medium Violations (SUGGESTION)

### [#6] `lib/qx.ex` Modules list omits `Qx.SimulationResult` and `Qx.Behaviours.*`

- **File**: `lib/qx.ex:21–41`
- **Code**: The `## Modules` list contains 13 entries — all 9 newly-declared
  modules are present, but `Qx.SimulationResult` and `Qx.Behaviours.*` (both
  listed in Iron Law #6 as pre-existing public surface) are absent.
- **Confidence**: REVIEW — this is a pre-existing omission, not introduced by
  this diff. The diff's P1-T3 scope was to add the 9 new modules; it did not
  remove SimulationResult or Behaviours from qx.ex (they were never there).
- **Consequence**: A developer reading the public API entry point (`Qx` moduledoc)
  cannot discover `Qx.SimulationResult` or any `Qx.Behaviours.*` module. Given
  that `Qx.SimulationResult` is what `Qx.run/1` returns, this is a usability gap.
- **Fix**: Add `Qx.SimulationResult` and a `Qx.Behaviours` entry to the `##
  Modules` list in `lib/qx.ex`. Either in this commit (while the list is being
  touched) or as a follow-on ROADMAP item.

---

## Coherence Checks — No Issues Found

- **Iron Law #6 vs #7 consistency**: Coherent. #6 correctly states `Qx.Validation`
  is internal while its raised `Qx.*Error` types are public. #7 says public
  functions route errors through `Qx.Validation`. An internal module raising public
  typed exceptions is valid Elixir; the two laws do not contradict each other.
- **Complexity-score table row** (AGENTS.md Step 2): Exactly matches the Iron Law
  #6 surface list — all 15 entries (14 named modules + `Qx.Behaviours.*`) are
  present in both places.
- **`@moduledoc false` on the 11 actually-changed modules**: None hides a
  genuinely public function. All 11 modules retain `@doc` strings on their
  functions (callable; just undocumented in HexDocs). The `Qx.Validation`
  module's three `@doc`-decorated functions (`valid_qubit?`, `valid_register?`,
  `validate_normalized!`) keep their doctests active — `@moduledoc false` does
  not suppress `@doc` doctests.
- **Deleted moduledoc prose**: The 11 changed modules had implementation-facing
  prose in their `@moduledoc` strings. Based on reading bloch.ex (now
  `@moduledoc false`) and codegen.ex (now has `# comment` rationale inline),
  the change appears to have preserved maintainer WHY context as inline `#`
  comments where needed. No specific rationale loss detected in the reviewed
  modules — though a full prose audit across all 11 deleted blocks is not
  possible without `git diff` access.

Checked 3 of the 22 standard Iron Laws (the three applicable to this pure
docs/governance change). 2 findings total.
