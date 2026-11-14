# Library research: Qx.Draw state-size cap

Verdict: no new hex dependency needed (verified from deps/ source and mix.lock).

## 1. Nx 0.13.0 (mix.lock)
Source: deps/nx/lib/nx.ex
- shape/1 line 4620: `def shape(%T{shape: shape}), do: shape` (struct field read)
- size/1 lines 4729-4730: `Tuple.product(shape(tensor))`
- axis_size/2 lines 4672-4676: shape(tensor), normalize_axis, elem/2
- Nx.Tensor defstruct (deps/nx/lib/nx/tensor.ex:34): [:data, :type, :shape, :names, vectorized_axes: []]
All three read only the shape tuple on the struct; none touch `data` (the backend struct). No backend transfer or host sync on any backend (BinaryBackend, EXLA, EMLX etc.). Caveat: size/1 on a vectorized tensor reports the inner shape, not including vectorized axes (not relevant for qx states).
Existing unguarded sinks to protect: lib/qx/draw/tables.ex:63 and lib/qx/draw/vega_lite.ex:21 (Nx.to_flat_list).

## 2. vega_lite 0.1.11 / kino 0.19.0
- VegaLite.data_from_values/2 (deps/vega_lite/lib/vega_lite.ex:307-313) does Table.to_rows |> Enum.map into maps. No row limit, no max_rows option; grep for max_rows/limit found nothing in deps/vega_lite/lib or deps/kino/lib.
- Altair's max_rows=5000 is a Python Altair setting; it does not exist in the Elixir package or in Kino source. Not verified: Livebook front-end/browser behaviour (the Livebook app is not in deps); Vega itself renders large datasets slowly in-browser but has no hard cap.
- Consequence: 2^12 = 4096 is a self-chosen, conservative default (and happens to be under 5000), not dictated by any library. Sensible; the override option is the right escape hatch.

## 3. Option validation libraries
- nimble_options 1.1.1 is in mix.lock and deps/, but only transitively: finch 0.23.0 requires it (non-optional); finch is pulled by req 0.6.2; req is pulled by igniter / usage_rules, which are `only: :dev` in mix.exs. Not a direct dep, not shipped to library consumers. (Not verified: whether benchee or others also pull finch; irrelevant to conclusion.)
- Qx lib/ does not use NimbleOptions anywhere.
- Using it would require adding it as a direct runtime dep, and it validates option shapes, not tensor size; a hand-written `Nx.size(t) > limit` check plus a `Keyword.get(opts, :max_states/:force, default)` is simpler. Recommend hand-written guard raising a typed exception.

## Compatibility
Nx ~> 0.12 declared, 0.13.0 locked; the functions used are long-stable API. vega_lite ~> 0.1 and kino ~> 0.12 are optional deps; the guard must run before the ensure_vega_lite!-dependent code paths or at least before Nx.to_flat_list.
