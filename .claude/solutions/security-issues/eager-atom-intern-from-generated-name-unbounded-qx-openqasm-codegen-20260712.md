---
module: "Qx.Export.OpenQASM.Codegen"
date: "2026-07-12"
problem_type: security_issue
component: openqasm_codegen
symptoms:
  - "Proposed returning a generated module name as an atom via `Module.concat([module])` in from_qasm_function/1"
  - "Merge-gate review (elixir-reviewer + iron-law-judge) flagged CRITICAL Iron Law #1 (atom-table exhaustion)"
  - "Repeated calls with distinct, caller-supplied QASM gate names would mint one permanent, non-GC'd atom each"
  - "Atom interned eagerly at call time — before/without the caller ever compiling the returned source"
root_cause: "`Module.concat/1` (like `String.to_atom/1`) interns its atom immediately and unconditionally; when the argument derives from unbounded caller-controlled input (a per-request gate name + content hash), each distinct input permanently grows the atom table"
severity: high
iron_law_number: 1
tags: [atom-table, module-concat, to-atom, dos, iron-law-1, code-generation, eager-interning, review-catch]
related_solutions:
  - ".claude/solutions/architecture-issues/sweep-typed-errors-public-surface-iron-law-7-20260624.md"
---

# Eagerly interning an atom from a per-request generated name is unbounded atom growth

## Symptoms

- Plan (`from-qasm-function-atom`) proposed making
  `Qx.Export.OpenQASM.from_qasm_function/1` return the generated module as an
  **atom** (`module_ref`) via `Module.concat([module])`, so callers could invoke
  it directly instead of recovering it from `Code.eval_string`.
- It was implemented and all tests passed — then the **merge-gate review**
  (elixir-reviewer AND iron-law-judge, independently) flagged it **CRITICAL,
  Iron Law #1 (atom-table exhaustion)**.
- The generated module name embeds a caller-chosen gate `name` (`Macro.camelize`)
  plus an 8-char content hash of the QASM body — both attacker-steerable. Every
  call to `from_qasm_function/1` on distinct source would intern one permanent
  atom, with no cap, in a function whose stated consumer is a **public**
  transpilation service (qxportal). ~1M distinct submissions → atom table full →
  BEAM crash.

## Investigation

1. **Plan's safety claim**: "the atom `Qx.Generated.<Name>_<hash>` already comes
   into existence when the caller compiles `source` (a `defmodule …`), so
   `Module.concat/1` creates no new atom." — **This was backwards.**
2. **Reviewers' correction**: `from_qasm_function/1` returns `source` *without*
   compiling it. Adding `Module.concat([module])` interns the atom **at
   from_qasm_function call time**, whether or not the caller ever compiles.
   Confirmed by the very doctest, which asserts `is_atom(module_ref)` with no
   preceding compile step. So the atom now exists *before* any compile — a NEW
   interning path that did not exist before the change.
3. **Was it even necessary?** No. `Code.compile_string(source)` already returns
   `[{module_atom, _bin}]` — the caller gets the atom safely, interned only when
   the module actually loads (unavoidable, bounded by real modules loaded).

## Root Cause

`Module.concat/1` and `String.to_atom/1` **intern immediately and
unconditionally**. Interning an atom is only bounded/safe when the set of
distinct values is bounded (e.g. the modules actually loaded into the VM). When
the argument derives from **unbounded, caller-controlled input** — here a
per-request gate name + content hash — each distinct input adds a permanent,
non-garbage-collected atom. That is precisely the Iron Law #1 failure mode, just
indirected through a hash so it doesn't look like `String.to_atom(user_input)`.

```elixir
# The offending change (lib/qx/export/openqasm/codegen.ex)
module = generated_module_name(name, def_source)   # String, from user QASM
module_ref = Module.concat([module])               # ⛔ interns NOW, per call, unbounded
{:ok, %{name: name, arity: arity, module: module, module_ref: module_ref, source: source}}
```

## Solution

Do **not** eagerly intern. Let the caller compile the source; compilation hands
back the module atom safely. Document that idiom instead of returning an atom.

```elixir
# The generated `source` is a self-contained `defmodule Qx.Generated.* do … end`.
# Compiling it returns the module atom — interned only on load, bounded by real
# modules, no per-request growth:
[{mod, _bin}] = Code.compile_string(source)
circuit = mod.bell(Qx.create_circuit(2), 0, 1)
```

`module` in the result map stays a **string** (for display/storage). The docs
now carry an explicit caveat: never `String.to_atom/1` / `Module.concat/1` the
`module` string on untrusted input.

### Files Changed

- `lib/qx/export/openqasm/codegen.ex` — reverted the `module_ref` atom key (kept
  `module` as a string)
- `lib/qx/export/openqasm.ex:33-43` — moduledoc documents the safe
  `Code.compile_string/1` idiom + atom-table caveat
- `README.md` — same idiom + caveat in the "Import a gate definition" section

## Prevention

- [x] Documented as a user-facing caveat (moduledoc + README) so downstream
      callers (qxportal) don't reinvent the vector.
- [ ] Reviewer heuristic: flag any `Module.concat/1`, `String.to_atom/1`,
      `:erlang.binary_to_atom/2`, or `Module.safe_concat/1`-adjacent call whose
      argument derives from request/parse-time input. Ask: "is the set of
      distinct inputs bounded?" If not → Iron Law #1.
- Specific guidance:
  - Interning is safe only over a **bounded** value set (loaded modules, a fixed
    allowlist). A content hash or user-chosen identifier is **not** bounded.
  - Prefer letting `Code.compile_string/1`/`Code.eval_string/1` mint the module
    atom at load time; don't pre-compute it from a string.
  - "The atom will exist later anyway" is not a license to intern it **now** —
    timing is the whole game (eager, per-call, pre-compile = unbounded).
- **Meta-lesson:** the merge-gate review caught a **plan-level reasoning error**
  (a wrong safety argument), not a code typo. Adversarial review of the *premise*
  — not just the diff — is what surfaced it. TDD green is not safety.

## Related

- Iron Law #1: NO `String.to_atom/1` on caller-supplied strings — atom-table
  exhaustion. `Module.concat/1` is the same hazard wearing a different name.
- `.claude/solutions/architecture-issues/sweep-typed-errors-public-surface-iron-law-7-20260624.md`
  — sibling "public-surface hazard swept via review" pattern.
