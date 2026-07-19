# Scratchpad — calcfast-simulation-specs

## Decisions

- **Scope = FULL coverage both files** (user). Simulation: 28 private + 3 public;
  CalcFast: 6 (1 def, 4 defn, 1 defnp). `lib/qx/calc.ex` already 4/4 → out.
- **No dialyzer** — specs are doc-only, verified by `mix compile
  --warnings-as-errors` + careful reading. Adding dialyzer is OUT (future item).
- **No CHANGELOG / no bump** — additive `@spec`s are non-breaking even on the
  public `Qx.Simulation` functions.
- **`defn`/`defnp` spec convention** — document the CALL contract: tensor args
  `Nx.Tensor.t()`, index/count args the plain ints they're called with
  (`non_neg_integer()`/`pos_integer()`), return `Nx.Tensor.t()`. `@spec` on a
  `defn` is a legal attribute; compiles fine.
- **Internal aliases as `@typep`** (not `@type`) — they're private helpers;
  keep `simulation_result` as `@type` (already there, public-facing).

## Verified facts (from enumeration)

- Simulation recurring shapes → aliases: `state`, `renorm`
  (`:off | :measurement | {:every, pos_integer()}`), `gate_name`, `qubit`,
  `bit`, `instruction` (3-tuple), `measurement`, `cbits`, `counts`,
  `timeline_item` (3-variant union).
- 34 `defp` LINES = 28 distinct functions (extra clauses: to_renorm +2,
  maybe_measurement_renorm +1, maybe_gate_renorm +1, apply_three_qubit_op +2).
- CalcFast `def`=2 grep lines = 1 function (`apply_single_qubit_gate/4`, 2 clauses).

## Watch-outs

- `@typep` that ends up unused → `--warnings-as-errors` fails. Every alias in
  P1-T1 must be referenced by a Phase 3/4 spec; drop any that isn't.
- `perform_measurements/3` returns `{[], %{}}` OR `{[[bit()]], counts}` — make
  the union compile cleanly (`{[[bit()]], counts()}` should accept `{[], %{}}`
  since `[]` is a valid `[[bit()]]` and `%{}` a valid map type).

## Open questions

- (none blocking)

## Dead ends / adjacent

- qx-8gf (WHY comments in CalcFast defn blocks) is adjacent — NOT in scope.
