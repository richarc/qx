# Elixir Review: feat/from-qasm-function-atom

## Summary
- **Status**: ⚠️ Changes Requested
- **Issues Found**: 3 (1 Critical, 1 Warning, 1 Suggestion)

## Critical Issues

1. **`lib/qx/export/openqasm/codegen.ex:69` — `Module.concat/1` allocates the atom unconditionally, on every `generate/1` call, whether or not the caller ever compiles `source`.**

   `Module.concat/1` (unlike `Module.safe_concat/1`) does not check whether the
   module is loaded — it interns a new atom immediately, the same way
   `String.to_atom/1` does. It is not lazy and does not wait for
   `defmodule Qx.Generated.<Name>_<hash>` in `source` to actually compile.

   Before this change, the generated-module atom only entered the atom table
   if/when the *caller* ran `Code.eval_string(source)` / `Code.compile_string(source)`
   — i.e. only when they intended to actually use the function. After this
   change, `from_qasm_function/1` itself creates a new permanent atom on
   **every** successful call, even for callers who only want to inspect/store
   `source` (e.g. a "preview my QASM transpile" endpoint, or a batch linter)
   and never compile it.

   The module name embeds a content hash of the generated function body
   (`generated_module_name/2`, line 84-91), which is trivially
   attacker-steerable: distinct gate/qubit/param **names** in caller-supplied
   QASM text produce distinct hashes and thus distinct atoms, with no bound
   other than caller creativity. In a repo whose stated downstream consumer is
   `qxportal`'s public "transpilation services" (per `../qxportal/CLAUDE.md`),
   a service that calls `from_qasm_function/1` per web request to show a user
   a preview (without necessarily compiling every preview) now has an
   unbounded, uncapped atom-table growth path — precisely Iron Law #1
   (atom-table exhaustion), just indirected through a hash instead of
   `String.to_atom(user_input)` directly.

   The plan's and the code comment's safety rationale (codegen.ex:64-68,
   plan.md:25-29 — "the atom already comes into existence when the caller
   compiles `source`") has the causality backwards: the atom now comes into
   existence *before* any compile, as a side effect of merely calling
   `generate/1`/`from_qasm_function/1`. That's a new allocation path this
   diff introduces, not a restatement of existing behavior.

   ```elixir
   # Current — eager, unconditional atom creation on every call
   module_ref = Module.concat([module])

   # Mitigations to consider (pick one, don't ship silently as-is):
   # 1. Document the cost explicitly in @doc / README: "each call to
   #    from_qasm_function/1 permanently allocates one atom, independent of
   #    whether `source` is compiled; callers processing untrusted/high-volume
   #    QASM must cap call frequency or dedupe by content hash before calling."
   # 2. Defer atom creation: don't return `module_ref` in the map; expose a
   #    separate `Qx.Export.OpenQASM.module_ref(module_string)` helper the
   #    caller invokes only after compiling (still has the same intrinsic
   #    cost, but makes the allocation opt-in and visibly tied to compile-time).
   # 3. At minimum, fix the misleading comment/plan rationale so a future
   #    reader doesn't reuse the same incorrect "it's free, the atom would
   #    exist anyway" argument for a genuinely eager allocation.
   ```

   Fix the doc comment at minimum; strongly consider documenting the
   call-frequency caveat given the qxportal usage context.

## Warnings

1. **`lib/qx/export/openqasm/codegen.ex:64-68`** — the inline comment's Iron
   Law #1 justification is factually backwards (see Critical #1 above): it
   should say the atom is created *by this call*, and explain why that's
   still acceptable (bounded by `validate_identifier`-checked, qx-controlled
   content — bounded per gate definition but NOT bounded across many distinct
   gate definitions from arbitrary QASM input), rather than implying no new
   atom is created until compile time.

## Suggestions

1. **`module` (string) vs `module_ref` (atom) naming** — already flagged as a
   known risk in `plan.md:97-100`; agree it's a minor footgun (one might
   expect the unadorned `module:` to be the atom). Acceptable given the
   additive/non-breaking constraint for this cycle; consider collapsing to a
   single atom `module:` key at the 1.0 breaking-changes bucket, as the plan
   already notes.

## Verified as Correct

- `inspect(module_ref) == module` is guaranteed: `Module.concat/1` on a
  single-element list `[module]` where `module` is already a fully-qualified
  dotted string produces the atom `:"Elixir.<module>"`, whose `inspect/1` is
  exactly the original string — matching the `defmodule <module> do …`
  compiled by the caller. Test at
  `test/qx/export/openqasm/codegen_test.exs:102-134` exercises this
  end-to-end (compiles `source`, asserts `compiled == module_ref`, calls
  `apply(module_ref, :bell, …)`) — good coverage of the claim.
- `@spec generate(tuple()) :: {:ok, map()} | {:error, Exception.t()}` and
  `@spec from_qasm_function(String.t()) :: {:ok, map()} | {:error, Exception.t()}`
  are unchanged and remain accurate for the additive map-key change (both
  were already the loose `map()` shape, so no spec drift).
- README example (`README.md:472-487`) and the `openqasm.ex` doctest
  (`lib/qx/export/openqasm.ex:490-495`) are consistent with the implementation
  and with each other; `Code.compile_string(source); module_ref.bell(...)` is
  a correct, minimal usage idiom.
- Doc-string update at `lib/qx/export/openqasm/codegen.ex:34-45` and
  `lib/qx/export/openqasm.ex:460-470` accurately describes the new
  `module_ref` key and its relationship to `module`.
