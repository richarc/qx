# Scratchpad — from-qasm-function-atom (v0.11)

## USER-CONFIRMED 2026-07-11: "Start here" → Option A (additive)

- Keep `module:` (string) unchanged; ADD `module_ref:` (atom via `Module.concat/1`).
- Non-breaking; no existing test modified; no version bump.
- Rejected B (string→atom break) and C (punt to 1.0). B would break
  `codegen_test.exs:68` (`String.starts_with?`), `:69` (`"defmodule #{module}"`
  interpolation → adds `Elixir.` prefix), `:94` (`inspect(module) == module_name`).

## Facts (verified 2026-07-11)

- Return map built in `lib/qx/export/openqasm/codegen.ex:63`:
  `%{name: name, arity: arity, module: module, source: source}`.
  `module` = string from `generated_module_name/2` (`"Qx.Generated.<Camel>_<hash8>"`).
- No documented caller uses `module:` — README (~L472) + the
  `from_qasm_function/1` doctest both destructure `%{name, arity, source}` only.
- In-repo `module:` users are tests: `codegen_test.exs:63,68,69,85,94`.
- Iron Law #1 SAFE: the atom already exists once the caller compiles `source`
  (`defmodule Qx.Generated.<...>`); `Module.concat/1` on the same validated,
  qx-generated name adds no atom. No `String.to_atom/1` on raw input.

## ⛔ CRITICAL FINDING (merge-gate review, 2026-07-11) — Option A is UNSAFE

Both elixir-reviewer AND iron-law-judge flagged **Iron Law #1 (atom-table
exhaustion)**, CONFIRMED valid. `Module.concat([module])` in
`Codegen.generate/1` interns the atom EAGERLY at `from_qasm_function/1` call
time — before/regardless of the caller compiling `source`. The plan's "atom
already exists once source compiles" reasoning is BACKWARDS: the atom now exists
the moment generate/1 runs. Module name embeds a caller-steerable gate name +
content hash → repeated distinct QASM submissions mint unbounded permanent
atoms. For qxportal (public transpilation service) = atom-table DoS. Before this
change from_qasm_function created NO atom → this is a NEW vector I introduced.

Key realisation: the item's premise is thin. `Code.compile_string(source)`
ALREADY returns `[{module_atom, _bin}]`, handing the caller the atom SAFELY
(interned only when the module loads, which is unavoidable). So Option A is both
unsafe AND largely unnecessary.

### Resolution options (HELD for user — the approved Option A is invalid)
- **(A′) Doc-only (RECOMMENDED):** revert the `module_ref` map key entirely;
  keep only a docs/README clarification showing the safe idiom
  `[{module, _}] = Code.compile_string(source); module.name(circuit, …)`. Zero
  atom-table risk; achieves the user goal (easy access to the callable module).
  Requires reframing the ROADMAP item (literal "return an atom" is unsafe).
- **(B) Accept-risk atom key:** keep `module_ref` but add a loud hazard note +
  push a rate cap to qxportal. Still an Iron Law #1 violation in `qx` itself —
  not recommended.
- **(C) Punt to 1.0 / drop:** revert all, tick the ROADMAP item as
  "investigated → the atom-return is an Iron Law #1 hazard; safe idiom documented
  instead" or move to Backlog.

## Watch

- Verify `from_qasm_function/1`'s doctest actually runs (find the
  `doctest Qx.Export.OpenQASM` directive) — else the new `module_ref` example
  is silently unrun (recurring doctest-directive gap).
