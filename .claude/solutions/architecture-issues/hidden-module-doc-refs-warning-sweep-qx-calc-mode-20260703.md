---
module: "Qx.Qubit / Qx.Register (calc engine)"
date: "2026-07-03"
problem_type: documentation_issue
component: configuration
symptoms:
  - "`mix docs` warning count jumped 110 → 198 the moment two modules got `@moduledoc false` — 88 new 'documentation references module \"Qx.Register\" but it is hidden' warnings"
  - "Warning sites went well beyond the plan's grep inventory: `lib/qx/step.ex` prose, `lib/qx.ex` function @docs and doctests, README.md, and historical CHANGELOG.md entries all autolinked the newly hidden modules"
  - "One warning survived every prose edit: 'documentation references type \"Qx.Register.t()\" but the module Qx.Register is hidden' — emitted by a `@spec`, not by any doc string"
root_cause: "ex_doc autolinks every backticked `Module`, `Module.fun/arity`, and spec type in every rendered artifact (moduledocs, @docs, doctests, @specs, and markdown extras like README/CHANGELOG). Hiding a module flips each of those references from a link into a warning, so the true blast radius of a demotion is the union of ALL rendered surfaces — a source-grep of `@moduledoc`/`@doc` strings systematically undercounts it by missing extras, doctest bodies, and typespecs."
severity: medium
tags: [moduledoc-false, exdoc, hidden-module, autolink, warning-baseline, spec-types, changelog, demotion]
related_solutions:
  [
    "moduledoc-false-count-matched-by-nested-module-20260627",
    "deprecate-public-fn-rename-shim-qx-stateinit-20260627",
  ]
---

# Demoting a public module floods `mix docs` with hidden-ref warnings from surfaces a source grep can't see

## Symptoms

- Branch `feat/calc-mode-demotion`: adding `@moduledoc false` to
  `lib/qx/qubit.ex` and `lib/qx/register.ex` (bodies untouched) took the
  `mix docs` warning count from 110 (main baseline) to 198.
- Each new warning: `documentation references module "Qx.Register" but
  it is hidden` (or `.../function "Qx.Register.show_state/1"...`).
- The plan's pre-flight inventory (grep for backticked refs in public
  `@moduledoc`/`@doc` strings) had listed 4 lib files. The warnings named
  those PLUS `lib/qx/step.ex` (3 sites), `lib/qx.ex` function docs and
  doctests (`draw_bloch/2`, `draw_state/2`), `README.md`, and 7 historical
  `CHANGELOG.md` entries.
- After all prose was fixed, one warning remained:
  `documentation references type "Qx.Register.t()" but the module
  Qx.Register is hidden` — sourced from
  `@spec draw_state(Qx.Register.t() | Nx.Tensor.t(), keyword())`.

## Investigation

1. **Assumed the plan inventory was the blast radius** — hid the modules,
   ran `mix docs`, got 88 new warnings across roughly twice as many files.
2. **Grouped warnings by source** with
   `mix docs 2>&1 | grep -E 'Qx\.(Qubit|Register)' -A6 | grep '└─' | sort | uniq -c`
   — this, not source grep, is the authoritative site list. (Counts come
   out doubled: html + epub formatters each warn once.)
3. **Prose sites**: de-linked or rewrote. **Doctest sites**: rewrote the
   pipelines onto the public path (`Qx.create_circuit(1) |> Qx.h(0) |>
   Qx.get_state()`), after confirming the consumer
   (`Bloch.qubit_to_bloch_coordinates/1`) accepts any 2-element tensor.
4. **CHANGELOG sites**: history shouldn't be rewritten. Confirmed in
   `deps/ex_doc/lib/ex_doc/autolink.ex` (`maybe_warn/4`) that
   `skip_undefined_reference_warnings_on` is matched against
   `[config.id, config.module_id, file]`, and a plain list is normalized
   to a membership check — so `["CHANGELOG.md"]` silences exactly that
   extra, list form fine on ex_doc 0.39.
5. **The stubborn last warning** came from a `@spec`, invisible to any
   doc-string grep. Widened the public spec instead of naming the hidden
   type.

## Root Cause

ex_doc renders more surfaces than developers grep: markdown extras
(README, CHANGELOG), doctest bodies, and typespecs all participate in
autolinking. `@moduledoc false` converts every autolink into a
hidden-reference warning, one per rendered format. An inventory built by
grepping `@moduledoc`/`@doc` strings therefore looks complete while
missing entire warning classes.

## Solution

Treat the warning stream itself as the worklist, with a count baseline as
the gate:

1. **Before hiding**: record `mix docs 2>&1 | grep -c 'warning:'` on main.
2. **After hiding**: group new warnings by site (`grep '└─' | sort |
   uniq -c`); fix each class with the matching tool:
   - prose in `@moduledoc`/`@doc` → de-link (plain words, no backticked
     module ref) or reword to the public replacement API;
   - doctests/examples → rewrite onto the public path (verify the
     consumer's input contract first — here everything downstream took a
     bare tensor, so no code change was needed);
   - `@spec` naming the hidden type → widen the public spec:

     ```elixir
     # before: leaks a hidden type into rendered docs
     @spec draw_state(Qx.Register.t() | Nx.Tensor.t(), keyword()) :: String.t()
     # after
     @spec draw_state(Nx.Tensor.t() | struct(), keyword()) :: String.t()
     ```

   - historical CHANGELOG entries → do NOT rewrite; excuse the file:

     ```elixir
     # mix.exs docs config
     skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
     ```

3. **Gate**: final count must be ≤ the pre-hide baseline (landed at 46
   vs 110 — the CHANGELOG skip also silenced pre-existing hidden-ref
   warnings from earlier demotions).

### Files Changed

- `lib/qx.ex`, `lib/qx/step.ex`, `lib/qx/draw.ex`, `lib/qx/errors.ex`,
  `lib/qx/behaviours/quantum_state.ex` — prose/doctest/spec sweep
- `mix.exs` — docs group removed + `skip_undefined_reference_warnings_on`

## Prevention

- When planning any `@moduledoc false` demotion, budget for a sweep of
  ALL rendered surfaces: lib docs, doctests, `@spec`s, README, CHANGELOG.
  Source grep is a starting inventory, never the acceptance check.
- The acceptance check is the `mix docs` warning-count baseline: capture
  it before the flip, require ≤ baseline after, and read the grouped
  warning sites as the definitive to-do list.
- Remember warnings print once per formatter (html + epub): divide
  per-site counts by 2 before concluding a fix "only removed half".
