---
module: "Qx.Draw.SVG.Circuit"
date: "2026-06-27"
problem_type: verification_gap
component: tooling
symptoms:
  - "A plan task to mark `Qx.Draw.SVG.Circuit` `@moduledoc false` was marked DONE because `grep -c '@moduledoc false' lib/qx/draw/svg/circuit.ex` returned 1"
  - "The outer module `Qx.Draw.SVG.Circuit` still rendered a full HexDocs page after the change — ROADMAP item only partially closed"
  - "The CHANGELOG claim 'the Qx.Draw.SVG.* sub-modules are now @moduledoc false' was factually wrong; caught at /phx:review by 3 of 4 agents, not by the verification gate"
root_cause: "The `@moduledoc false` the grep counted belonged to a NESTED private module (`defmodule CircuitDiagram do @moduledoc false …`), not the outer public module. A file-level `grep -c` cannot tell which module owns an attribute, so a count of 1 was satisfied by the wrong module. The outer module kept its 26-line prose `@moduledoc \"\"\"…\"\"\"`."
severity: medium
tags: [moduledoc, moduledoc-false, nested-module, grep-verification, hexdocs, exdoc, public-api, verification-gap, false-positive]
related_solutions: ["deprecate-public-fn-rename-shim-qx-stateinit-20260627"]
---

# `@moduledoc false` count satisfied by a nested module, not the outer one

## Symptoms

- Plan task "mark `Qx.Draw.SVG.Circuit` `@moduledoc false`" was treated as a
  no-op / already-done because:

  ```
  $ grep -c '@moduledoc false' lib/qx/draw/svg/circuit.ex
  1
  ```

- After merge prep, `Qx.Draw.SVG.Circuit` would **still** publish a HexDocs
  page. The CHANGELOG asserted the `Qx.Draw.SVG.*` sub-modules were now hidden —
  false. `/phx:review` (requirements-verifier + elixir-reviewer + iron-law-judge)
  flagged it; the `mix compile/test` gate did **not** (it's not a compile error).

## Investigation

1. **Trusted the count.** `grep -c '@moduledoc false' …` → `1`, so the task was
   checked off as done in Phase 2. WRONG — the count says *a* module has it, not
   *which* one.
2. **Review caught it.** Three independent agents reported the outer module still
   had prose. Confirmed with a structural grep:

   ```
   $ grep -n '^defmodule\|@moduledoc' lib/qx/draw/svg/circuit.ex
   1:defmodule Qx.Draw.SVG.Circuit do
   2:  @moduledoc """          # <-- outer module, still prose
   31:    @moduledoc false      # <-- nested private CircuitDiagram, indented
   ```

3. **Root cause:** the `@moduledoc false` lived on a nested `defmodule
   CircuitDiagram do` (a private struct module), not on `Qx.Draw.SVG.Circuit`.

## Root Cause

A file can hold more than one module. `@moduledoc` is a *per-module* attribute,
but `grep -c` is *per-file* — it counts lines, blind to which `defmodule` owns
the match. A file with one nested `@moduledoc false` and one outer
`@moduledoc """…"""` yields count `1`, which looks "done" but verifies the wrong
module.

```elixir
defmodule Qx.Draw.SVG.Circuit do
  @moduledoc """…26 lines of prose, still public in HexDocs…"""

  defmodule CircuitDiagram do
    @moduledoc false   # <-- the `grep -c` match — nested, private
    defstruct [...]
  end
end
```

## Solution

Mark the **outer** module. A non-greedy perl replace on the FIRST
`@moduledoc """…"""` block targets the outer one and leaves the nested
`@moduledoc false` untouched:

```bash
perl -0777 -i -pe 's/\@moduledoc """.*?"""/\@moduledoc false/s' lib/qx/draw/svg/circuit.ex
# now: line 2 (outer) AND the nested one are both `@moduledoc false`
```

Then verify by MODULE, not by file count:

```bash
# show every defmodule + every @moduledoc line together, with line numbers
grep -n '^defmodule\|@moduledoc' lib/qx/draw/svg/circuit.ex
```

The outer `@moduledoc` must sit directly under the top-level `defmodule`. If the
only `@moduledoc false` is indented under a nested `defmodule`, the public
module is NOT hidden.

### Files Changed

- `lib/qx/draw/svg/circuit.ex:2` — outer module `@moduledoc """…"""` → `@moduledoc false`

## Prevention

- [ ] Add to Iron Laws? No — too specific.
- [x] Add to agent checks: when verifying `@moduledoc false`, the iron-law /
      requirements agents already caught this; keep scoping such checks
      per-module, not per-file.
- Specific guidance:
  - **Never verify a per-module attribute with `grep -c` over a file.** A file
    can contain nested `defmodule`s. Use
    `grep -n '^defmodule\|@moduledoc'` and read which `defmodule` the attribute
    sits under, or confirm via `mix docs` (the module either renders a page or
    it doesn't).
  - The fastest unambiguous proof that a module is hidden: run `mix docs` and
    check `doc/` for `<Module>.html`, or that ExDoc omits it.
  - `@moduledoc false` only hides the module from HexDocs; functions stay
    callable and `@doc` doctests still run (see
    [[deprecate-public-fn-rename-shim-qx-stateinit]] for the doctest angle).

## Related

- `.claude/solutions/architecture-issues/deprecate-public-fn-rename-shim-qx-stateinit-20260627.md`
  — `@moduledoc false` does not disable `@doc` doctests (sibling docs gotcha)
- ROADMAP v0.8.1 `public-surface-declaration` (audit: public-api #24)
