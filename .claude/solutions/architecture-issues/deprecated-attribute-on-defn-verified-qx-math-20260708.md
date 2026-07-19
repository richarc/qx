---
module: "Qx.Math"
date: "2026-07-08"
problem_type: build_error
component: configuration
symptoms:
  - "Plan risk: unverified whether `@deprecated` attaches to `defn` (Nx-generated) functions at all — `kron/2`, `trace/1` etc. needed deprecation but are defn, and defn's macro expansion generates hidden `__defn:name__` companions that might swallow the attribute"
  - "First spike attempt: `Code.fetch_docs(SpikeDep)` on a Code.compile_string-defined module returned `{:error, :module_not_found}` — looked like the docs metadata was missing when it was merely unreadable"
root_cause: "No root defect — a capability question answered by spike: Elixir attaches `@deprecated` to whatever public function follows it, and `defn` ultimately defines a plain public function, so the attribute lands identically to `def` (caller compile warning, `deprecated:` key in the doc-chunk meta, entry in `__info__(:deprecated)`); only the generated internal `__defn:name__/N` carries no metadata, which is invisible and harmless. The spike's false alarm came from `Code.fetch_docs/1` needing a beam ON DISK — in-memory modules from `Code.compile_string` have no docs chunk to read until the binary is written out."
severity: low
elixir_version: "1.18.4"
tags:
  [
    deprecated,
    defn,
    nx,
    fetch-docs,
    docs-chunk,
    spike,
    compile-string,
    beam-file,
  ]
related_solutions:
  [
    "deprecate-public-fn-rename-shim-qx-stateinit-20260627",
  ]
---

# `@deprecated` attaches cleanly to `defn` — and how to spike attribute questions without touching the tree

## Symptoms

- The v0.11 tier trim needed `@deprecated` on five `defn` functions
  (`kron/2`, `inner_product/2`, `outer_product/2`, `apply_gate/2`,
  `trace/1`). Whether the attribute survives `defn`'s macro expansion was
  an explicit plan risk with a documented fallback (`@doc deprecated:`
  badge, no compile warning).
- Mid-spike red herring: after `Code.compile_string/2`, calling
  `Code.fetch_docs(SpikeDep)` failed with `{:error, :module_not_found}`
  even though the module was loaded and callable — which briefly read as
  "defn dropped the docs metadata".

## Investigation

1. **Spike shape**: one throwaway `.exs` run via `mix run` (so Nx is on
   the path), defining a module with `@deprecated` on both a `defn` and a
   control `def`, plus a caller module, all inside one
   `Code.with_diagnostics(fn -> Code.compile_string(...) end)`.
2. **Compile-warning half**: diagnostics contained
   `SpikeDep.foo/1 is deprecated. Use Nx.add/2 instead` for the defn —
   byte-for-byte the same warning shape as the `def` control. Verified.
3. **Docs-metadata half failed** — `Code.fetch_docs/1` reads the `Docs`
   beam chunk from the `.beam` FILE (via `:code.which/1`); an in-memory
   module has no file, hence `:module_not_found`. Fix: take the binary
   from `Code.compile_string`'s `[{module, binary}]` return, write it to
   `Elixir.SpikeDep.beam` in a temp dir, and fetch docs from that path.
4. **Result**: `foo/1 deprecated meta: "Use Nx.add/2 instead"`, present in
   `__info__(:deprecated)` too. The generated `__defn:foo__/1` entry has
   `deprecated: nil` — it is `:hidden` anyway. No fallback needed.

## Root Cause

Not a bug — a verified capability. `defn` is a macro that ends up calling
`def` for the public head, and Elixir's compiler binds any pending
`@deprecated` to the next public function definition regardless of which
macro produced it. So `@deprecated` + `defn` behaves exactly like
`@deprecated` + `def` on all three observable surfaces: caller
compile-time warning, `deprecated:` metadata in the docs chunk (what
ex_doc renders as the badge and what `Code.fetch_docs/1` exposes), and
the module's `__info__(:deprecated)` table.

The spike's false negative was environmental: `Code.fetch_docs/1`
requires a beam file on disk.

```elixir
# Spike essence (throwaway, run with `mix run spike.exs`):
{result, diagnostics} =
  Code.with_diagnostics(fn ->
    Code.compile_string("""
    defmodule SpikeDep do
      import Nx.Defn
      @deprecated "Use Nx.add/2 instead"
      defn foo(a), do: a + 1
    end
    defmodule SpikeCaller do
      def call, do: SpikeDep.foo(Nx.tensor(1))
    end
    """)
  end)

# diagnostics ⇒ [%{severity: :warning, message: "SpikeDep.foo/1 is deprecated. ..."}]

# fetch_docs needs the beam ON DISK:
{_mod, beam} = Enum.find(result, fn {m, _} -> m == SpikeDep end)
File.write!(Path.join(out_dir, "Elixir.SpikeDep.beam"), beam)
{:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(Path.join(out_dir, "Elixir.SpikeDep.beam"))
```

## Solution

Used plain `@deprecated "…"` on all five defn functions in
`lib/qx/math.ex` — no special-casing versus their `def` siblings. The
guard test (`test/qx/tier_trim_test.exs`) asserts the metadata through
`Code.fetch_docs/1` on the real compiled modules (beams on disk, so no
write-out dance needed), mapping `{name, arity}` → `meta[:deprecated]`
and requiring a non-empty message.

Two adjacent facts worth reusing:

- Functions with default arguments appear ONCE in the docs chunk, at max
  arity (`zero_state/1,2` ⇒ one `{:function, :zero_state, 2}` entry with
  `defaults: 1`) — assert at max arity, not per generated head.
- For a multi-clause function with a bodiless head
  (`def bell_state_vector(which \\ :phi_plus, type \\ :c64)`), put
  `@deprecated` above the head, not above a clause.

## Prevention

- When a plan flags an "does attribute X work with macro Y" risk, spike
  it in isolation FIRST (Phase-1, before any product edit): one
  `Code.with_diagnostics` + `Code.compile_string` script under `mix run`
  answers compile-behavior questions in seconds without touching the
  tree, surviving in the scratchpad as evidence.
- Remember the two halves of "deprecation works": the compile warning
  (diagnostics) and the docs metadata (fetch_docs) are produced by
  different machinery — verify both, and fetch docs from a written beam
  when the module was compiled in memory.
