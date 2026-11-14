# Library Research: O(1) amortised circuit instruction append

Recommendation: NO new dependency. Stdlib suffices.

## 1. Cost model (OTP 29.0.3, stdlib-8.0.2, Elixir 1.20.2)
- Kernel.++/2 docs: "The complexity of `a ++ b` is proportional to `length(a)`, so avoid repeatedly appending to lists of arbitrary length" (https://elixir.hexdocs.pm/Kernel.html). Left list is copied; no single-element optimisation is documented.
- Measured here (scratchpad bench, one run, cold script):
  n=1,000: ++ 1.2ms, prepend+reverse 10us, queue 18us
  n=10,000: ++ 157ms, prepend+reverse 86us, queue 63us
  n=50,000: ++ 5.0s, prepend+reverse 0.56ms, queue 1.1ms
  Quadratic for ++, linear for the others.
- `[x | list]` is O(1); one Enum.reverse/1 is O(n) once (Enum.reverse on a list delegates to :lists.reverse/1, which is implemented in lists.erl with a BIF-backed reverse/2 at line ~203). Total O(n).
- Caveat: ++ also allocates a new left-list copy each time (garbage ~ n^2/2 cons cells), so GC pressure matters, not just time.

## 2. Stdlib alternatives
- :queue (stdlib-8.0.2/src/queue.erl): type is `-opaque queue(Item) :: {list, list}` (line 110), i.e. opaque; docs say all ops amortised O(1) except all/any/etc. in/2 O(1) amortised; to_list/1 O(n). Observed repr `{[3,2],[1]}`. Cannot pattern-match as a list; Enum does not work on it directly (it is a plain 2-tuple, no Enumerable impl). Would change the public `instructions` field type: breaking.
- :array: opaque, tree-based; set/get O(log n)-ish (fixed-radix 10 tree), to_list O(n); :array.set(i, v, arr) with extendable arrays appends. Not a list, no Enum/pattern matching. Heavier than needed.
- Others: Erlang `:gb_trees`/`:ets` are not sequence-appropriate. Plain list with prepend + one reverse at consumption (or at a boundary) is the idiomatic stdlib answer. Note: any option that keeps `instructions` as an ordinary list in append order requires a reverse somewhere; keeping it reversed makes the public field order-inverted.

## 3. Hex packages (API https://hex.pm/api, queried 2026-11-14)
- qex 0.5.2: :queue wrapper with Enumerable/Collectable protocols. MIT. 662k total, ~98k recent. Last release 2026-02-14 (prior 2021). Still a queue under the hood; not a list. Not worth a dep.
- vector 1.1.0: geometric vectors, NOT a persistent vector. Irrelevant (name collision). Last 2023.
- persistent_vector 0.1.4: MIT, 1.7k downloads, last 2017. Reject (abandoned).
- arrays_rrb_vector 0.3.0: Rust NIF RRB vector, Apache-2.0, 1.9k downloads, last 2022-05. Its own README says NIF overhead dominates. Reject (NIF, abandoned, tiny).
- deque 1.x: MIT, 926k downloads, last 2018. Reject.
- glearray: Gleam-origin, Apache-2.0, 103k, 2026-06; not idiomatic for Elixir structs. Reject.
- Verdict: none justified. Every option produces a non-list type, forcing a to-list conversion anyway, which prepend+reverse already gives for free.

## 4. deps/ readers of %Qx.QuantumCircuit{}
`grep -rl "QuantumCircuit" deps/` returned nothing; `grep -rl "Qx\." deps/` returned nothing. mix.lock deps (benchee, bypass, credo, ex_doc, finch, jason, kino, nx, req, vega_lite, etc.) do not touch the struct. Confirmed: Qx is upstream. Internal readers (lib/, test/, benchmarks) are outside this check; the plan should grep them for `.instructions` / `instructions:` itself.

## 5. Official guidance
- Kernel.++/2 docs (above) say avoid repeated appends and advise prepend + reverse. https://elixir.hexdocs.pm/Kernel.html
- The Elixir "what-anti-patterns" guide (four categories) has no ++/list-append entry that I could confirm; the category sub-pages were not read. Cite Kernel.++/2 and the Erlang efficiency guide rather than the anti-pattern guide.
- Note: quantum_circuit.ex also uses `circuit.measurements ++ [measurement]` at line 208 (same quadratic pattern; the lines listed also include 122,148,168,210,221,234).

## Compatibility
Elixir 1.20.2 / OTP 29; no dependency changes; no conflicts.
