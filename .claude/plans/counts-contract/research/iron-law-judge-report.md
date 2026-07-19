# Iron Law compliance — commit 0f38904 (fix/counts-contract)

**Verdict: PASS**

Commit: `0f38904` — "Fix SimulationResult.counts keys: bit-lists become the
documented strings". Checked against the IRON LAWS block in
`/Users/richarc/Development/qxquantum/qx/CLAUDE.md` (§ IRON LAWS, laws #5, #6,
#7, #9) plus a lib-wide `@spec` consistency sweep.

## Law #6 — public API surface (the judgement call)

`Qx.SimulationResult` is declared public, and the runtime key type of
`:counts` changed. Finding: **the CHANGELOG entry it got is sufficient; no
major bump is required.**

Reasoning:

- The declared contract never changed. `SimulationResult.t()` has said
  `counts: %{String.t() => non_neg_integer()}` all along
  (`lib/qx/simulation_result.ex:37`), every helper `@spec` takes/returns
  `String.t()` keys, and every doctest showed string keys. The runtime was
  the deviation. Under SemVer, behaviour that contradicts documentation is a
  bug; correcting it is a fix, not a contract break.
- Law #6's major-bump clause targets breaks to the *declared* surface. The
  declared surface is unchanged — strings before, strings after. What breaks
  is only code written against the undocumented actual behaviour.
- The commit still treats it as behaviour-visible, which is right: the
  CHANGELOG `### Fixed` entry is loud, bold-leads with the change, names the
  exact migration (`counts[[1, 0]]` → `counts["10"]`), and notes
  `classical_bits` still carries per-shot bit lists.
- Release positioning is correct. `mix.exs` is still `0.9.0` (bumps happen at
  release prep per workspace rules), the v0.9.0 tag is held, and the ROADMAP
  v0.10 entry marks this **release-blocking in v0.10** — so the change can
  only ship inside the next 0.x minor, which for a pre-1.0 project is the
  SemVer-appropriate vehicle. It could not silently ride a 0.9.x patch.

Conclusion: CHANGELOG entry + forced v0.10 placement satisfies both the
letter and the intent of law #6. Nothing more needed.

## Law #9 — dispatch completeness (deleted `is_list` arms)

Verified by tracing every `%Qx.SimulationResult{}` constructor in `lib/`
(grep: exactly three) to its counts source:

| Constructor | Counts source | Key type |
|---|---|---|
| `lib/qx/simulation.ex:158` (run_without_conditionals) | `perform_measurements/3` → `Enum.frequencies_by(classical_bits, &Enum.join/1)` (line 627), or `%{}` when no measurements | `String.t()` |
| `lib/qx/simulation.ex:189` (run_with_conditionals) | `Enum.frequencies_by(classical_bits, &Enum.join/1)` (line 180) | `String.t()` |
| `lib/qx/result_builder.ex:35` (hardware path) | passthrough of provider counts | `String.t()` — see below |

The passthrough's only feeder is `Qx.Hardware.run` →
`ResultBuilder.from_counts(results.counts, ...)` (`lib/qx/hardware.ex:184`),
where `results.counts` comes from `Qx.Hardware.Ibm.samples_to_counts/2`
(`lib/qx/hardware/ibm.ex:317`), which keys by
`hex_sample_to_bitstring/2` — every clause returns a binary (padded
bitstring, the raw `"0x..."` on parse failure, or `inspect(other)`).
`lib/qx/hardware/portal.ex` produces no counts. Two structural backstops
make a list key impossible to smuggle through this path anyway:
`from_counts` calls `String.to_integer(outcome, 2)` on every key
(`lib/qx/result_builder.ex:19`) and `Qx.Hardware.infer_num_bits/1` calls
`String.length/1` on a key (`lib/qx/hardware.ex:481`) — both crash on
non-strings long before a chart is drawn.

So after this commit **no producer can emit a list key** into
`counts_key_to_label/1` in `lib/qx/draw/vega_lite.ex` or
`lib/qx/draw/svg/charts.ex`. Critically, the arm deletion and the producer
change land in the *same commit* — the `is_list` heads were reachable before
it and unreachable after it; deleting them atomically is exactly what law #9
prescribes (no unproducible special-case arms left as false evidence).
Remaining `is_binary` head matches the sole producible shape. Coverage is
*execution*-grade as required: the new seam test
(`test/qx/simulation_result_seam_test.exs`) runs every SimulationResult
helper against real `Qx.run` output (verified green: 6 doctests, 3 tests, 0
failures).

## Law #5 — no host loops over 2^n

`Enum.frequencies_by(classical_bits, &Enum.join/1)` iterates the per-shot
classical-bits list — length `shots`, not `2^n`. Same at both sites.
Confirmed. (The pre-existing `Nx.to_flat_list(probabilities)` in
`perform_measurements/3` does touch `2^n` values, but it predates this
commit, is untouched by the diff, and is the host-side sampling boundary —
out of scope for this judgement.)

## Law #7 — typed errors

No new raise sites, no raw `Nx`/`Complex`/`ArgumentError` paths introduced;
the diff only swaps `Enum.frequencies/1` for `Enum.frequencies_by/2`,
deletes two dead heads, and edits docs/tests. Footnote (not a violation): a
hand-built struct with list keys — off-contract per `t()` — now hits
`FunctionClauseError` in `counts_key_to_label/1` instead of silently
rendering. That input violates the documented type, and keeping a tolerant
arm for it is precisely what law #9 forbids.

## `@spec` consistency sweep (lib-wide)

- `lib/qx/simulation.ex:23` — `@typep counts` updated to
  `%{optional(String.t()) => pos_integer()}` in this commit;
  `perform_measurements/3`'s spec (line 610) returns `counts()`, so it
  updated with it. Consistent.
- `lib/qx/simulation_result.ex` — `t()` and all five helper specs
  (`most_frequent`, `filter_by_probability`, `outcomes`, `probability`,
  `to_map`) already declared `String.t()`; now true at runtime.
- `lib/qx/result_builder.ex:11` — `from_counts(map(), ...)`, loose but not
  inconsistent.
- Greps for `optional([`, `[bit()]`-keyed maps, and residual `is_list` in
  `lib/qx/draw/` and `simulation_result.ex` found nothing stale. No doc
  example anywhere in `lib/` still shows list-keyed counts.
- `mix compile --warnings-as-errors` clean.

## Summary

PASS on all four laws. #6 is the only judgement call and it resolves cleanly:
a bug fix *toward* the always-documented contract, loudly changelogged, and
structurally pinned to the unreleased v0.10 minor — the correct SemVer
treatment for a pre-1.0 library. #9 was executed textbook-style: producers
and dead consumer arms changed atomically, verified by tracing all three
constructors, with real-execution seam coverage.
