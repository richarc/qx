# Harden the OpenQASM subsystem (parser depth cap + codegen isolation)

**Slug:** `openqasm-hardening`
**Branch:** `fix/openqasm-hardening`
**ROADMAP:** qx v0.8.2 (Security & Hardening), Group C — two findings
(security MED + security LOW).
**Type:** Security hardening. Item 4 is a behaviour change to
`from_qasm_function/1`'s generated `source` shape. Typed errors, no new dep.

## Problem

1. **Unbounded parenthesis recursion in the QASM expression grammar**
   (`lib/qx/export/openqasm/parser.ex`). `primary` parses `( expr )` by
   re-entering `:expression` (parser.ex ~176-181), so `((((…))))` recurses one
   frame per `(`. Within the 1 MB source cap (`@max_qasm_size`, openqasm.ex:129)
   ~500K nested `(` walk ~0.5 M parser frames and can `:enomem` before erroring
   (audit: security MED).
2. **`from_qasm_function/1` emits a BARE `def`** whose name is attacker-controlled.
   `Codegen.generate/1` returns `source: "def #{name}(circuit, …) do … end"`
   (codegen.ex). A downstream caller that `Code.compile_string/1`s it injects
   `def <name>(…)` into *their* module namespace — an attacker-named helper can
   shadow/clobber a host function (audit: security LOW, defence in depth).

## Decided constraints (do not re-litigate)

- **Item 1 = pre-parse depth scan**, mirroring the existing `enforce_size/1`
  guard. Both public entry points (`from_qasm/1`, `from_qasm_function/1`) start
  with `with :ok <- enforce_size(source), …`; add `:ok <- enforce_paren_depth(source)`
  right after. O(n) scan tracking max running `(`/`)` nesting; reject over
  `@max_paren_depth` with `Qx.QasmParseError`. (Rejected: in-grammar depth
  counter — nimble_parsec has no clean depth hook; a pre-scan is simpler and
  catches it before any frame is pushed.)
- **Item 2 = `defmodule Qx.Generated.<Camelize(name)> do … end` envelope.**
  `name` is already validated as `[A-Za-z_]\w*` by `Codegen.validate_identifier/1`,
  so `Macro.camelize(name)` is a safe alias segment. The result map gains a
  `:module` field so callers know where the compiled function lives.
- **Typed errors only** (Iron Law #7): `Qx.QasmParseError.exception(reason:)`.
- **`@max_paren_depth`**: a generous cap (recommend `64`); no legitimate QASM
  expression nests parens that deep. Surface the exact number in the plan.
- **CHANGELOG**: `### Security` note (the depth cap; and the codegen output-shape
  behaviour change).

## Open decisions (resolve at /phx:work)

- **Depth cap value** — recommend `64`. (Lower is safer; 64 is already 10x any
  real expression.)
- **Scan precision** — raw char scan counts `(` inside comments/string literals
  too. Acceptable (fail-closed; a legit file won't nest 64 deep anywhere). Note
  it; don't bother stripping comments/strings.
- **Module naming / collisions** — `Qx.Generated.<Camelize(name)>` is
  deterministic and doctest-friendly; two QASM files defining `bell` produce the
  same module name (caller's concern, document it). Alternative (hash suffix)
  breaks doctest determinism — rejected.
- **Result map** — add `:module` (string, e.g. `"Qx.Generated.Bell"`). Additive.

---

## Phase 1 — Tests first (TDD; test-guard hook needs approval)

> Surface the test additions at `/phx:work` time, get approval, confirm RED.

- [x] [P1-T1] **Paren-depth** — in `test/qx/export/openqasm_test.exs` (or
      `openqasm_import_test.exs`, wherever `from_qasm`/`from_qasm_function` are
      tested): a `((((…))))` source with depth > cap → `{:error, %Qx.QasmParseError{}}`
      (reason mentions depth/nesting); a normally-nested expression (a few
      parens, e.g. `rx((1+2)*3) q;`) still parses fine. Cover BOTH `from_qasm/1`
      and `from_qasm_function/1`. Build the deep string programmatically
      (`String.duplicate("(", n)`).
- [x] [P1-T2] **Codegen envelope** — in `test/qx/export/openqasm/codegen_test.exs`:
      `Codegen.generate({:gate_def, "bell", …})` `source` now contains
      `"defmodule Qx.Generated.Bell do"` AND `"def bell(circuit, a, b)"` and is
      `Code.compile_string/1`-compilable to a module exposing `bell/3`; result
      map has `module: "Qx.Generated.Bell"`. (Compile it in-test and assert the
      function exists, then `:code.purge`/`:code.delete` to clean up.)
- [x] [P1-T3] `mix test test/qx/export/...` — confirm RED.

## Phase 2 — Parenthesis-depth cap (`lib/qx/export/openqasm.ex`)

- [x] [P2-T1] Add `@max_paren_depth 64` near `@max_qasm_size`.
- [x] [P2-T2] Add `enforce_paren_depth/1`: fold over `String.to_charlist(source)`
      (or `:binary` byte scan) tracking running depth (`?(` → +1, `?)` → -1, clamp
      at 0) and the max; if max > `@max_paren_depth` return
      `{:error, Qx.QasmParseError.exception(reason: "expression nesting too deep (max #{@max_paren_depth} parentheses)")}`,
      else `:ok`.
- [x] [P2-T3] Wire `:ok <- enforce_paren_depth(source)` into the `with` chains of
      BOTH `from_qasm/1` and `from_qasm_function/1`, right after `enforce_size`.
- [x] [P2-T4] `mix test` the parser/import tests — paren-depth cases GREEN.

## Phase 3 — Codegen module envelope (`lib/qx/export/openqasm/codegen.ex` + docs)

- [x] [P3-T1] In `Codegen.generate/1`, wrap the emitted `def` in
      `defmodule Qx.Generated.#{Macro.camelize(name)} do … end` (indent the def
      one level). Return `%{name: name, arity: arity, module: module_string, source: source}`.
- [x] [P3-T2] Update `Qx.Export.OpenQASM` moduledoc (lines ~30-37) and the
      `from_qasm_function/1` `@doc` (lines ~440-454) to describe the module
      envelope: the `source` is now a `defmodule Qx.Generated.<Name>` that
      compiles to an isolated module exposing `<name>/<arity>`, so it cannot
      inject a helper into the caller's module. Update the `@spec` map type if
      it's spelled out.
- [x] [P3-T3] Fix the doctest (openqasm.ex ~468-474): keep
      `source =~ "def bell(circuit, a, b)"` (still true inside the module) and
      add `source =~ "defmodule Qx.Generated.Bell"`.
- [x] [P3-T4] `mix test` codegen + openqasm tests — GREEN.

## Phase 4 — CHANGELOG + ROADMAP

- [x] [P4-T1] `CHANGELOG.md` `[Unreleased]` `### Security`: (a) the QASM parser
      now caps parenthesis nesting depth (DoS hardening, raises
      `Qx.QasmParseError`); (b) `from_qasm_function/1` now wraps generated code in
      a `Qx.Generated.<Name>` module so it can't inject an attacker-named helper
      into the caller's module — **behaviour change**: the returned `source` is a
      `defmodule`, and the map gains `:module`.
- [x] [P4-T2] Tick the two v0.8.2 ROADMAP items (parenthesis-depth cap; wrap
      generated `def` in a `Qx.Generated.<id>` envelope).

## Verification (mandatory gate)

- [x] `mix compile --warnings-as-errors` — clean.
- [x] `mix format --check-formatted` — clean.
- [x] `mix credo --strict` — 0 issues.
- [x] `mix test` — full suite green (currently 242 doctests + 928 tests) plus
      the new cases. Watch the doctest count: the from_qasm_function doctest is
      edited, not removed, so doctests stay 242 (confirm).

## Out of scope

- The other v0.8.2 groups (config done; IBM client B; deps D).
- Brace `{ }` (gate-body / c_if) nesting — the named finding is parens; note if
  the scan should later also cap braces, but don't expand scope now.
- Changing how `to_qasm` (export) works — import/codegen only.

## Done = merge-ready

All phases checked, verification green, `/phx:review` PASS (or triaged).
Squash-merge, tick the two ROADMAP items, push `main`.
