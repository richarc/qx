---
module: "Qx.QuantumCircuit"
date: "2026-11-14"
problem_type: logic_error
component: configuration
symptoms:
  - "After renaming a public struct field, `mix compile --warnings-as-errors`, credo and 1,572 tests were green, but `examples/openqasm/round_trip.exs` raised `KeyError` on `.instructions`"
  - "The repo-wide leftover grep had been piped through `head -20`; 20 hits from `.claude/plans/` filled the window and the four `examples/` hits were never shown"
  - "Three independent review agents found the four sites; the work phase had recorded 'no reference remains'"
root_cause: "`examples/*.exs` scripts are not compiled by `mix compile` and not run by `mix test`, so a removed struct field in them fails only at run time; the one check that could see them (a repo-wide grep) was truncated before its output was read, and the truncated result was taken as complete"
severity: medium
tags: [grep, truncated-output, struct-field-rename, examples, breaking-change, sweep, keyerror]
related_solutions:
  - ".claude/solutions/architecture-issues/hidden-module-doc-refs-warning-sweep-qx-calc-mode-20260703.md"
---

# A truncated grep hid leftover readers of a renamed struct field

## Symptoms

The `instructions` field of `Qx.QuantumCircuit` was replaced by
`reversed_instructions`. `lib/` and `test/` were swept and the full gate
passed. `examples/openqasm/round_trip.exs:19,29,69` and
`examples/openqasm/import_gate_definition.exs:47` still read
`.instructions`.

## Root cause

Nothing in the gate touches `examples/`. The sweep that covered it was:

```bash
grep -rn "\.instructions\b" --include="*.exs" --include="*.md" . | grep -v deps/ ... | head -20
```

Plan and research files under `.claude/` matched first and used all 20
lines.

## Solution

Exclude the noisy directories instead of truncating, and count:

```bash
grep -rn "\.instructions\b\|instructions:" --include="*.ex" --include="*.exs" \
  --include="*.md" --include="*.livemd" . \
  | grep -v "^./deps/\|^./_build/\|^./doc/\|^./\.claude/\|^./cover/"
```

Then run each touched example: `mix run examples/openqasm/round_trip.exs`.

## Prevention

- Never read a leftover sweep through `head`. If the output is long, narrow
  the pattern or exclude directories, and say how many hits there were.
- A field or function rename sweep covers `examples/`, `bench/`, `guides/`,
  `README.md` and livebooks as well as `lib/` and `test/`. List the
  directories covered in the plan task.
- Write the plan's scope as "every reader in the repo", not "every `lib/`
  reader".
- Review agents with their own grep are a real second check here: brief
  them to grep the whole repo themselves, not to trust the stated sweep.
