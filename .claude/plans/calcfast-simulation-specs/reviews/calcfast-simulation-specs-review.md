# Review — calcfast-simulation-specs

**Verdict: PASS WITH WARNINGS → ALL FINDINGS RESOLVED**

> Post-review fixes applied (re-verified green: format/compile/credo clean,
> 242 doctests + 916 tests, 0 failures):
> - **W1** — `@typep cbits` tightened to `[bit()]`.
> - **S2** — `@typep counts` key tightened to `[bit()]`.
> - **S1** — confirmed via `operations.ex:765` (`c_if` rejects `value not in
>   [0, 1]`) that the conditional value is a `bit()`; tightened `timeline_item`'s
>   conditional payload and `process_conditional/8`'s value arg to `bit()`.
> - **W2** — `apply_cswap/5` doc rewritten to describe CSWAP (Fredkin); the
>   (correct) Toffoli prose moved onto the previously-undocumented
>   `apply_toffoli/5`.

**Verdict: PASS WITH WARNINGS** (no blockers; spec-accuracy refinements + 1
pre-existing doc fix)

Diff: 2 files (`lib/qx/calc_fast.ex`, `lib/qx/simulation.ex`), +111 lines,
strictly additive (`@spec` / `@typep` only — no logic touched).

## Requirements Coverage (source: plan.md)

**21 MET · 0 PARTIAL · 0 UNMET · 1 UNCLEAR**

Full coverage verified from the diff: 10 `@typep` aliases (all consumed), 6
CalcFast specs, 3 public Simulation specs, 28 `defp` specs (31-spec count = 31
distinct heads), all four multi-clause groups with exactly one `@spec`. Strictly
additive; no CHANGELOG; `calc.ex` untouched. The 1 UNCLEAR is the
compile/format/credo/test gate (self-reported) — confirmed green this session:
242 doctests + 916 tests, 0 failures.

## Iron Laws

- **Clean — 0 violations introduced.** Diff is 100% additive. #5 host-loops in
  `calculate_measurement_probability`/`collapse_to_measurement` are
  PRE-EXISTING (not in `defn`, untouched). #6: `@spec` on public `Qx.Simulation`
  functions is additive documentation → non-breaking, no bump/CHANGELOG. #8:
  `@norm_tolerance 1.0e-6` untouched. `@spec` on `defn`/`defnp` is a compile-time
  attribute; kernels unchanged.

## Findings (spec accuracy — no dialyzer, so reviewed by reading)

All specs confirmed accurate against implementations EXCEPT the `cbits` cluster:

- **W1 (WARNING) — `@typep cbits :: [non_neg_integer()]` should be `[bit()]`**
  (`simulation.ex`). Every write into a cbits list is a literal `0`/`1`
  (`List.duplicate(0, n)` then `List.replace_at(_, _, measured_value)` where
  `measured_value ∈ {0,1}` from `perform_single_measurement/3`). The `bit()`
  alias exists three lines above for exactly this. Tightening makes the
  register-as-bits contract visible. Accurate everywhere cbits is built.
- **W2 (WARNING, PRE-EXISTING) — `apply_cswap/5` `@doc` describes a Toffoli
  gate** (`calc_fast.ex:145-156`). The doc says "Applies a Toffoli (CCX) gate"
  with `control1`/`control2`/`target` params, but the function is CSWAP
  (Fredkin: `control`, `target_a`, `target_b`). Pre-existing copy-paste error,
  not introduced here, but the `@spec` was added right above it — worth fixing
  while in the file.
- **S1 (SUGGESTION) — `timeline_item` conditional `value` → `bit()`**
  (`simulation.ex`). The `{:conditional, {cbit, value, instructions}}` value is
  compared `Enum.at(cbits, cbit) == value`; if cbits is `[bit()]`, any
  `value > 1` is a permanently-dead branch. Tighten to `bit()` **only if**
  `Qx.c_if` constrains the value to 0/1 — verify the c_if value domain before
  applying; if c_if accepts arbitrary integers, leave `non_neg_integer()` as
  accurate-to-storage.
- **S2 (SUGGESTION, follows W1) — `counts` key → `[bit()]`**
  (`simulation.ex`). `counts = Enum.frequencies(classical_bits)` keys are
  cbit lists; once cbits is `[bit()]`, keys are `[bit()]` not
  `[non_neg_integer()]`.

## Bottom line

Coverage is complete and all but one type cluster is exactly right. The `cbits`
→ `[bit()]` tightening (W1, cascading to S2 and conditionally S1) makes the
classical-register contract precise, and the pre-existing CSWAP doc error (W2)
is worth correcting while here. All small, in-file, no behaviour impact.
