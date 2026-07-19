---
module: "Qx.StateInit"
date: "2026-07-08"
problem_type: documentation_issue
component: configuration
symptoms:
  - "`mix docs` warning count rose 36 → 38 after the tier-trim edits, but the grouped warning output was dominated by ~36 pre-existing warnings (hidden Qx.Hardware.Ibm/Portal refs etc.) — eyeballing it could not say WHICH warning was new"
  - "The new warning was `documentation references function \"Qx.superposition_circuit/1\" but it is undefined or private` — the reviewed-and-approved plan had prescribed that exact replacement pointer for the superposition_state deprecation, and nothing at compile/test time flagged it"
root_cause: "Deprecation messages and moduledoc prose name functions as free text — the Elixir compiler never resolves them, so a pointer to a function that does not exist (`Qx.superposition_circuit/1`; the real one is `Qx.Patterns.superposition_circuit/1` with no facade delegate) sails through compile, credo, and the full test suite. Only ex_doc's autolinker checks doc-prose references, and a count-only baseline gate says THAT the count moved, not WHAT moved — against a noisy pre-existing baseline the offending site is invisible without diffing the actual warning lists from the same tree with and without the change."
severity: medium
tags:
  [
    mix-docs,
    warning-baseline,
    stash-diff,
    autolink,
    deprecation-message,
    phantom-function,
    exdoc,
    docs-gate,
  ]
related_solutions:
  [
    "hidden-module-doc-refs-warning-sweep-qx-calc-mode-20260703",
    "deprecate-public-fn-rename-shim-qx-stateinit-20260627",
  ]
---

# Stash-diff the `mix docs` warning LISTS — a count-only gate hid a phantom replacement pointer

## Symptoms

- Tier-trim branch, after the behaviour demotion phase: `mix docs 2>&1 |
  grep -c "warning:"` returned **38** against a Phase-1 baseline of
  **36**. The demotion itself was clean (zero warnings referenced
  `Qx.Behaviours.QuantumState`).
- The grouped warning dump was ~95% pre-existing noise (hidden
  `Qx.Hardware.Ibm`/`Qx.Hardware.Portal` refs, `Qx.Patterns.*_circuit`
  hidden-function refs, a README `RELEASE.md` file ref) — reading it top
  to bottom gave no confident answer to "which two lines are new?".
- The actual new warning: `documentation references function
  "Qx.superposition_circuit/1" but it is undefined or private` — ×2
  because the html and epub formatters each emit it once (one real site).

## Investigation

1. **Grep the dump for the demoted module** — nothing referenced
   `QuantumState`, ruling out the change that was EXPECTED to move the
   count. So the +2 came from an unexpected direction.
2. **Diff the lists, not the counts**: capture
   `mix docs 2>&1 | grep "warning:" | sort | uniq -c` to a file, then
   `git stash push -- lib/ test/` + recompile + same capture on the
   pre-change tree, `git stash pop`, and `diff` the two files. One line
   of output: the phantom `Qx.superposition_circuit/1` reference.
3. **Trace the source**: the string came verbatim from the plan — both
   the `@deprecated` message on `superposition_state/2` and the new
   StateInit moduledoc used it. `grep "superposition" lib/qx.ex
   lib/qx/patterns.ex` showed the function lives on `Qx.Patterns` only;
   `Qx` has no delegate. The plan (reviewed and approved) had simply
   asserted a function into existence.

## Root Cause

Two mechanisms compound:

1. **Doc prose is never compile-checked.** A backticked
   `` `Qx.superposition_circuit/1` `` in a `@deprecated` string or
   moduledoc is free text to the compiler; `mix compile
   --warnings-as-errors`, credo, and 1005 passing tests all say nothing.
   ex_doc's autolinker is the ONLY tool in the pipeline that resolves
   these references — doc generation is therefore a semantic check, not
   a cosmetic step.
2. **A count gate compresses away the answer.** `count_after ≤
   count_before` is the right cheap PASS/FAIL, but the moment it fails
   you need set-difference on the actual warning lines. Against a
   36-warning pre-existing baseline, "find the 2 new ones by reading"
   does not scale and invites wrongly blaming the change you expected
   (the demotion) rather than the one you didn't (the pointer).

## Solution

The diff procedure (works on any dirty working tree, no commits needed):

```bash
mix docs 2>&1 | grep "warning:" | sort | uniq -c | sort -rn > /tmp/docs_after.txt
git stash push -m wip -- lib/ test/
mix compile > /dev/null 2>&1
mix docs 2>&1 | grep "warning:" | sort | uniq -c | sort -rn > /tmp/docs_before.txt
git stash pop && mix compile > /dev/null 2>&1
diff /tmp/docs_before.txt /tmp/docs_after.txt
# > 2  warning: documentation references function "Qx.superposition_circuit/1" ...
```

Fix was mechanical once seen: point the deprecation message and
moduledoc at `Qx.Patterns.superposition_circuit/1`. Count returned to
36 = baseline. (Remember html+epub double-count: Δ2 in the count is
usually ONE real site.)

## Prevention

- **Verify replacement pointers exist before writing them.** When a
  plan or finding prescribes "deprecate X → point at Y", grep Y's
  definition first — plans can assert phantom functions, and review
  agents verified THIS pointer only because the docs diff had already
  corrected it.
- **Treat `mix docs` as part of the semantic gate** whenever doc prose
  gains function references (deprecations, See-Also blocks, moduledoc
  rewrites) — it is the only reference-resolver in the toolchain.
- **When a warning-count gate moves, diff the lists** with the stash
  recipe above instead of eyeballing grouped output. Counts gate;
  diffs diagnose.
- Corollary for messages that must name a recipe from a HIDDEN module:
  write the code inline without a backticked `Module.fun/arity` form
  (e.g. the `random_state/2` message inlines the recipe rather than
  autolinking internal `Qx.Qubit.random/0`), or the pointer itself
  becomes the next hidden-ref warning.
