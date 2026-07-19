---
module: "Qx"
date: "2026-07-11"
problem_type: tooling_technique
component: documentation
symptoms:
  - "A single docs sweep had to add 47 `@spec`s, insert `## Returns` into 55 facade doc blocks, and add grounded `## Raises` into 18 more — doing it with individual Edit calls is slow and, in `operations.ex`/`qx.ex`, trips the debug-statement PostToolUse hook on every call (harmless but noisy) because the `tap_*` doctests contain literal `IO.inspect`/`IO.puts`"
  - "Naive `perl -i -pe` insertion by function name breaks on multi-clause functions (`c_if` has 4 clauses), functions with default args (`x_all(circuit, qubits \\\\ [])`), and blocks whose section layout varies (some have `## Examples`, some are prose-only, some end with `## See Also`)"
root_cause: "Bulk doc-section insertion needs to be *doc-block aware*, not line-or-name aware. A `@doc \"\"\" ... \"\"\"` block must be parsed as a unit, associated with the next `def`/`defdelegate` for its function name, checked for an existing section, and given an insertion anchor chosen by section priority — otherwise you double-insert on multi-clause fns, mis-place the section relative to `## Examples`/`## Raises`/`## See Also`, or miss prose-only blocks with no headers at all."
severity: low
tags:
  [
    docs-sweep,
    "@spec",
    moduledoc,
    perl,
    bulk-edit,
    doc-block,
    tooling,
    posttooluse-hook,
  ]
related_solutions:
  [
    "docs-warning-stash-diff-catches-phantom-pointer-qx-stateinit-20260708",
    "tier1-structs-not-tier2-utilities-moduledoc-opener-qx-20260711",
  ]
---

# Doc-block-aware scripting for large mechanical `@spec`/`## Returns`/`## Raises` sweeps

## Problem

The v0.11 docs sweep touched ~120 doc sites across the facade + tier-2
modules. Per-site `Edit` calls are slow and hook-noisy; per-line `perl`
substitution is wrong on multi-clause/default-arg functions and varied
block layouts.

## Resolution — the pattern that worked

Write a script (Perl/awk) that treats each `@doc """ … """` as a unit:

1. **Parse blocks.** Scan for `^\s*@doc\s+"""`; the block ends at the
   next line that is exactly `"""`.
2. **Associate a function name.** From the block's closing `"""`, scan
   forward (past `@spec`/`@type`/blank lines, ≤ ~8 lines) to the first
   `^\s*(?:def|defdelegate)\s+([a-z_]\w*)` — that name keys the content.
   This is arity-blind, so it naturally attaches ONE section per doc
   block even when the function has many clauses.
3. **Skip if already present** (`$body =~ /##\s*Returns/`).
4. **Choose the anchor by section priority**, searching only inside the
   block: first `## Examples`, else `## Raises`, else `## See Also`, else
   the closing `"""`. Insert `## Returns` *before* that anchor (this
   lands it after `## Parameters`/`## Options`, before Examples — matching
   the house order). `## Raises` conventionally goes last, so anchor it
   before `## See Also` else the closing `"""`.
5. **Two insertion spacings:** before a header anchor use
   `"  ## X\n\n<body>\n\n"`; before the closing `"""` prepend a blank:
   `"\n  ## X\n\n<body>\n"`.
6. **Apply insertions in descending line order** so earlier indices stay
   valid.
7. **Dry-run first** — print `name / anchor-line / mode` for every
   planned insert and eyeball the count against your inventory before
   `--apply`.

Gotchas that bit us:

- **Default-arg operator `\\\\` in single-quoted Perl** collapses to `\`.
  A key like `'def plot(result, options \\\\ [])'` must use `\\\\\\\\`
  (four backslashes) or match a substring that excludes the default.
- **`@spec` on a default-arg fn:** `Code.fetch_docs` reports one doc
  entry at the max arity, so a single `@spec name(a, b, c)` satisfies the
  inventory for both `name/2` and `name/3` — do NOT add a second spec.
- **The debug-statement PostToolUse hook fires on `Edit` to any file
  whose *doctests* contain `IO.puts`/`IO.inspect`** (the `tap_*` examples
  in `operations.ex`/`qx.ex`). It is a non-blocking false positive — the
  edit still applies. Bash-based scripts sidestep it entirely.

## Verification (mandatory)

After the sweep: `mix compile --warnings-as-errors && mix format &&
mix credo --strict && mix test`, then re-run the inventory
(`api_inventory.exs`) to prove **0 supported functions missing `@spec`**,
and confirm `mix docs` warning count == baseline (new `@spec` type refs
and cross-ref edits feed ex_doc's autolinker — see
[[docs-warning-stash-diff-catches-phantom-pointer-qx-stateinit-20260708]]).

## Prevention

- For any sweep > ~10 doc sites, script it doc-block-aware with a dry-run;
  reserve `Edit` for one-offs and anything needing human judgment
  (e.g. per-function `## Raises` wording, which must be grounded in the
  delegate's actual `raise` sites — never invented).
