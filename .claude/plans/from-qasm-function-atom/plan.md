# from_qasm_function/1 — usable module atom (v0.11 · finding addendum 2026-07-04)

> **⚠️ SUPERSEDED (2026-07-12).** Option A below (return a `module_ref` atom)
> was implemented, then the merge-gate review flagged it as a CRITICAL Iron
> Law #1 (atom-table exhaustion) violation — `Module.concat/1` interns an atom
> eagerly per call, before/without the caller compiling. Reverted. Resolved
> instead as **A′ (doc-only):** document the safe `Code.compile_string(source)`
> idiom + a caveat against eager interning. See `scratchpad.md` "CRITICAL
> FINDING". The phases below are the abandoned Option A, kept for the record.

**Branch:** `feat/from-qasm-function-atom`
**ROADMAP:** v0.11 "API Review Follow-Through" — the `from_qasm_function/1`
`module:` item. Ticks that checkbox on merge.
**Depth:** standard · **Complexity:** 3 (2 files: codegen + facade docs/tests;
changes declared-public `Qx.Export.OpenQASM` return shape +3; ADDITIVE, follows
existing map-return pattern −2). No new dep (stdlib `Module.concat/1` only).

## Decision — Option A (ADDITIVE), auto-decided 2026-07-11 (user away; REVISIT)

Callers of `from_qasm_function/1` currently get `module:` as a **string**
(`"Qx.Generated.Bell_<hash>"`) and must recover the real module atom from
`Code.eval_string(source)`'s return. Make the atom directly available:

- **Keep** `module: <string>` (back-compat — zero breakage, no existing test
  touched; the README + doctest already destructure only `%{name, arity,
  source}`, so nothing documented depends on `module:`).
- **Add** `module_ref: <atom>` (the generated module as an atom, via
  `Module.concat/1`).

Rejected: (B) change `module:` string→atom — breaks `codegen_test.exs:68/69/94`
and v0.11's non-breaking framing; (C) punt to 1.0. Rationale in `scratchpad.md`.

**Iron Law #1 (atom-table):** SAFE. The atom `Qx.Generated.<Name>_<hash>`
already comes into existence when the caller compiles `source` (which literally
is `defmodule Qx.Generated.<Name>_<hash> do …`). `Module.concat/1` on the same
qx-generated, `validate_identifier`-checked name creates no atom that compiling
`source` wouldn't. No `String.to_atom/1` on raw caller input.

### Target

`Codegen.generate/1` return map gains one key:

```elixir
%{name: name, arity: arity, module: module, module_ref: module_ref, source: source}
#                                            ^^^^^^^^^^^^^^^^^^^^^^^ NEW (atom)
# module      = "Qx.Generated.Bell_a1b2c3"          (String, unchanged)
# module_ref  = :"Elixir.Qx.Generated.Bell_a1b2c3"  (atom == the compiled module)
```

`module_ref` is built from the SAME string via `Module.concat([module])` so the
two are guaranteed consistent (`inspect(module_ref) == module`).

## Phase 1 — Codegen: add `module_ref` (TDD)

- [x] [P1-T1] **Tests first** (`test/qx/export/openqasm/codegen_test.exs`, new
      assertions in the existing "wraps the generated def…" describe — ADDITIVE,
      no existing assertion changed): `module_ref` is an atom;
      `inspect(module_ref) == module` (string/atom consistency); after
      `Code.compile_string(source)`, the compiled module atom `==` `module_ref`
      and `apply(module_ref, :bell, [circuit, 0, 1])` runs. Run — MUST FAIL
      (`module_ref` absent → KeyError/MatchError).
- [x] [P1-T2] Implement in `Codegen.generate/1`: `module_ref =
      Module.concat([module])` (one call; `module` is the existing string), add
      `module_ref:` to the returned map. Update the codegen `@doc` line
      ("Generates a `%{name, arity, module, source}` map") → include
      `module_ref`. Compile clean; tests pass.

## Phase 2 — Docs + facade (TDD)

- [x] [P2-T1] **Tests first**: extend the `from_qasm_function` doctest (or a new
      test) to show `module_ref` usage — compile `source`, then
      `module_ref.<name>(circuit, …)` WITHOUT capturing from `eval_string`.
      Confirm `Qx.Export.OpenQASM.from_qasm_function/1` doctest still runs
      (its `doctest` directive lives where? verify — else the example won't run).
- [x] [P2-T2] Update `from_qasm_function/1` `@doc` + README §"Import a `gate`
      definition as an Elixir function" to document `module_ref` and show the
      direct-call idiom (`Code.compile_string(source); module_ref.bell(...)`) as
      the preferred path over recovering the module from `eval_string`. Keep the
      `@spec` as `{:ok, map()}`.

## Phase 3 — CHANGELOG & verify

- [x] [P3-T1] CHANGELOG `[Unreleased]` **Added**: `from_qasm_function/1` /
      `from_qasm_function!/1` now include a `module_ref` (atom) key alongside the
      existing `module` (string), so the generated module is directly callable
      after compiling `source`. Non-breaking, additive.
- [x] [P3-T2] Full gate: `mix compile --warnings-as-errors && mix format
      --check-formatted && mix credo --strict && mix test`.
- [x] [P3-T3] `mix docs` warning count ≤ baseline (36); stash-diff the lists if
      it moves (new doc prose refs `module_ref`/`Module.concat` — grep the
      autolink targets exist).

## Iron Laws check

- **#6 (public API):** purely ADDITIVE — one new map key; `module:` string and
  every existing key/behaviour unchanged. CHANGELOG **Added**; no version bump.
- **#1 (atom-table):** `Module.concat/1` on the qx-generated, validated module
  name — the atom already exists once `source` compiles; no unbounded caller-
  driven atom creation. No `String.to_atom/1` on raw input.
- **#7 (typed errors):** unchanged — `from_qasm_function` still returns
  `{:error, Qx.Qasm*Error}` on failure; the new key only appears on `:ok`.

## Risks

1. **Naming** — `module` (string) vs `module_ref` (atom) is slightly
   counter-intuitive (one might expect `module` to be the atom), but the
   additive constraint forbids retyping `module`. Documented in both `@doc` and
   README. A 1.0 cleanup can collapse to a single atom `module:` key.
2. **Doctest home** — `from_qasm_function`'s example must actually run; verify
   the `doctest Qx.Export.OpenQASM` directive covers it (P2-T1), else it's
   silently unrun (the recurring gap — see the operations/patterns doctest
   lessons).

## Self-check

- *What breaks?* Nothing external — `module:` unchanged; only an added key.
- *Deferred?* The string→atom retype (Option B) → 1.0 breaking bucket if ever
  wanted. This item is then fully closed for v0.11.
