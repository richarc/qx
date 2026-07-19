# Code Review: public-surface-declaration

## Summary
- **Status**: ⚠️ Changes Requested
- **Issues Found**: 4 (1 critical, 1 warning, 2 suggestions)

---

## Critical Issues

### 1. `Qx.Draw.SVG.Circuit` was not converted to `@moduledoc false`

**Location**: `lib/qx/draw/svg/circuit.ex` lines 2–27

The perl non-greedy replace missed this file. `Qx.Draw.SVG.Circuit` still carries a
full 27-line `@moduledoc """` prose block. All other `Qx.Draw.SVG.*` sub-modules
(`Bloch`, `Charts`) are correctly `@moduledoc false`.

Consequence: The CHANGELOG `### Changed` entry states "`Qx.Draw.SVG.*` ... are now
`@moduledoc false`" — that claim is factually wrong in its current state. HexDocs will
publish the SVG.Circuit module page when the intent is to hide it.

Confirming detail: the module's own prose already self-declares its status — "This module
is part of the Qx.Draw refactoring and should be accessed through the public `Qx.Draw`
API rather than directly." The intent is clear; the mechanical substitution simply did not
reach this file.

**Fix**: Replace `@moduledoc """..."""` (the block ending at line 27) with `@moduledoc false`.
No `@doc` or attribute follows directly, so no swallowing risk. Verify with `mix docs` that
`Qx.Draw.SVG.Circuit` no longer appears in the sidebar.

---

## Warnings

### 2. CHANGELOG names `Qx.Draw.SVG.Circuit.render/1` as a consumer-facing retyped surface

**Location**: `CHANGELOG.md`, `### Changed`, third bullet, line ~83

The typed-errors bullet includes:
```
- `Qx.Draw.SVG.Circuit.render/1` on a malformed circuit →
  `Qx.QubitCountError` / `Qx.GateError` / `Qx.QubitIndexError` /
  `Qx.ClassicalBitError`;
```

`Qx.Draw.SVG.Circuit` is declared internal (`@moduledoc false` — once the critical issue
above is fixed). Naming an internal function's exception behaviour in a user-facing
CHANGELOG entry signals to consumers that calling `Qx.Draw.SVG.Circuit.render/1` directly
is expected. It contradicts the surface-declaration intent.

If the behaviour change matters to consumers, attribute the observable effect to the public
entry point (`Qx.Draw.draw_circuit/2` or equivalent), not the internal function. If no
public entry point exposes this path directly, remove the sub-bullet entirely.

---

## Suggestions

### 3. `Qx.Export.OpenQASM.AST` (−47 lines): type schema WHY-context at risk

**Location**: `lib/qx/export/openqasm/ast.ex`

The current file is `@moduledoc false` followed immediately by `end` — the module body is
empty. The deleted 47-line moduledoc very likely described the node-type taxonomy for the
QASM AST (what each tagged tuple looks like, which fields are optional, ordering
constraints). That structural contract is the kind of WHY-context that is non-obvious to
reconstruct from the lowering/codegen code alone, and it is gone from every public channel.

Consider preserving the shape descriptions as `# ` comments inside the module body, or as
a `@type` block — not for HexDocs, but for maintainability.

### 4. `Qx.Hardware.Config` `## Modules` one-liner understates the constraint

**Location**: `lib/qx.ex` line 41

```
- `Qx.Hardware.Config` - Hardware backend configuration
```

The module's own `@moduledoc` (first line of `lib/qx/hardware/config.ex`) reads:
"Configuration for `Qx.Hardware` execution against IBM Quantum via the qxportal
transpilation service." The one-liner in the list omits that this is specifically
IBM Quantum via qxportal — it is not a generic backend configuration struct. A reader
scanning the module list might expect it to work with other backends (e.g., a local
simulator backend config). The existing voice in sibling entries ("e.g. IBM Quantum"
appears on the `Qx.Hardware` line already) makes the truncation on `Config` feel like
the detail was intentionally dropped, but it could mislead.

Suggested revision:
```
- `Qx.Hardware.Config` - IBM Quantum backend configuration (API key, backend name, shots)
```
or match the sibling's parenthetical style:
```
- `Qx.Hardware.Config` - Hardware backend configuration (IBM Quantum via qxportal)
```

---

## Syntactic Cleanliness Check (all 12 `@moduledoc false` substitutions)

Checked the first several lines of every converted file:

| Module | Result |
|--------|--------|
| `Qx.Validation` | Clean — `@moduledoc false` immediately followed by `@doc """` |
| `Qx.Draw.SVG.Bloch` | Clean |
| `Qx.Draw.SVG.Charts` | Clean |
| `Qx.Draw.Tables` | Clean |
| `Qx.Draw.VegaLite` | Clean |
| `Qx.Export.OpenQASM.AST` | Clean (`@moduledoc false` then `end`) |
| `Qx.Export.OpenQASM.Codegen` | Clean (`@moduledoc false` then comment) |
| `Qx.Export.OpenQASM.Expr` | Clean |
| `Qx.Export.OpenQASM.Lowering` | Clean |
| `Qx.Export.OpenQASM.Parser` | Clean |
| `Qx.Hardware.Ibm` | Clean |
| `Qx.Hardware.Portal` | Clean |
| `Qx.Draw.SVG.Circuit` | **NOT converted** — see Critical #1 |

No orphaned `"""`, dangling text, or swallowed `@doc`/attributes found in any of the twelve
files that were actually converted.

---

## AGENTS.md Iron Laws #6/#7 and Complexity Table

Iron Law #6 prose: the declared-public surface list is complete and internally consistent
with the `## Modules` list in `lib/qx.ex` (once Critical #1 is resolved). The
internal/external split is stated unambiguously.

Iron Law #7 prose: "Do not let raw `Nx` / `Complex` / `ArgumentError` leak across the API
boundary — route through `Qx.Validation`." Clear and correct.

Complexity-table row for public API changes: the parenthetical correctly enumerates the
full declared surface (14 modules + `Qx.Behaviours.*`). No discrepancies detected.

---

## CHANGELOG `### Changed` Entry (doc quality, altitude, style)

The entry is factually accurate (pending Critical #1 fix), written at the right altitude
for a library CHANGELOG, and free of marketing language. The format matches existing
entries. The only issue is the internal-module reference in Warning #2.
