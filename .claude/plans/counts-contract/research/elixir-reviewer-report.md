# elixir-reviewer report — counts-contract (commit 0f38904)

**Scope reviewed:** `git show 0f38904` on `fix/counts-contract`; full grep of
`lib/`, `test/`, `examples/`, `spec/`, `bench/`, `scripts/`, `README.md`,
`CHANGELOG.md` for list-shaped counts keys; empirical probes of
`perform_measurements` / `run_with_conditionals` edge cases via `mix run`.

**Verdict: PASS WITH WARNINGS**

The core change is correct and idiomatic. Three `examples/` scripts still
consume the old list-key contract (two now crash, one silently reports 0%),
and the new "classical bit 0 leftmost" doc claim is not true for
out-of-order `measure/3` calls. Nothing in `lib/` or `test/` was missed.

---

## What the change gets right (verified, not assumed)

- `Enum.frequencies_by(classical_bits, &Enum.join/1)` at both producer
  sites (`lib/qx/simulation.ex:180`, `:627`) is the idiomatic one-pass
  form; `Enum.join/1` defaults to the `""` joiner and integer bits render
  as `"0"`/`"1"`. Correct.
- **Empty-cbits edge case is unreachable.** `perform_measurements`
  short-circuits `measurements == []` to `{[], %{}}`
  (`lib/qx/simulation.ex:614-615`) — verified live: a measurement-free
  circuit returns `counts: %{}`, never a `"" => shots` key. The
  conditional path cannot produce `""` either: every `c_if/4` guard
  requires `classical_bit < circuit.num_classical_bits`
  (`lib/qx/operations.ex:736-739`), so a conditional circuit always has
  ≥ 1 classical bit and `Enum.join` gets a non-empty register.
- **Dead `is_list` head deletion is sound.** After this commit no code
  path constructs list keys: both simulator sites emit strings,
  `Qx.ResultBuilder.from_counts/3` requires string keys
  (`String.to_integer(outcome, 2)`, `String.graphemes` —
  `lib/qx/result_builder.ex:19,27`), and `Qx.Hardware` infers width via
  `String.length/1` (`lib/qx/hardware.ex:481`). Iron Law #9 applied
  correctly. A caller hand-feeding `Draw.plot_counts` an old-style
  list-key map now gets a `FunctionClauseError` instead of a silent
  render — acceptable post-contract-change behaviour.
- `@typep counts :: %{optional(String.t()) => pos_integer()}` matches the
  public `SimulationResult.t()` it feeds.
- Doctest fixes are right: the new moduledoc example is deterministic
  (`X` on q0 → `{"10", 1000}`, cbit 0 leftmost — verified by execution),
  and the `to_map` doctest sorting removes map-order dependence.
- CHANGELOG entry is accurate and appropriately loud; the "identical to
  the labels `Qx.draw_counts/2` renders" claim is true (the deleted
  heads computed exactly `Enum.join(key, "")`).
- No stragglers in `lib/` or `test/`: repo-wide grep finds zero remaining
  list-key producers, consumers, or assertions there. README, `lib/qx.ex`
  (`:906`), and guides already used string keys.

---

## Findings

### F-1 (HIGH) — `examples/openqasm/grover_search.exs` still asserts the old contract, now silently wrong

`examples/openqasm/grover_search.exs:63-66`:

```elixir
# Calculate success probability. `result.counts` is keyed by a list of
# classical bits in declaration order — `[c[0], c[1]]` — so |11⟩ is
# `[1, 1]`, not the string "11".
success_count = Map.get(result.counts, [1, 1], 0)
```

The comment now actively documents the *wrong* contract (it explicitly
says "not the string \"11\""), and the lookup always misses, so the
script prints `Success probability: 0.0%` — a silent lie, no crash.

**Fix:** `Map.get(result.counts, "11", 0)` and rewrite the comment to
describe the string contract.

### F-2 (HIGH) — `examples/conditional_gates_example.exs` crashes on string keys

Two sites treat the counts key as a list:

- `:129` — `if Enum.at(bits, 2) == 1, do: ...` →
  `Protocol.UndefinedError` (`String` doesn't implement `Enumerable`).
- `:137` — `[m0, m1, final] = bits` → `MatchError` on a binary.

The other eight `Enum.each(resultN.counts, ...)` sites only
`inspect(bits)` and keep working (output changes from `[1, 0]` to
`"10"`, which is the intended improvement).

**Fix:** `:129` → `String.at(bits, 2) == "1"` (same pattern the commit
used in `test/qx_test.exs:316`); `:137` →
`[m0, m1, final] = String.graphemes(bits)` (adjust the interpolation) or
match `<<m0, m1, final>>` binary-style.

### F-3 (MEDIUM) — `examples/basic_usage.exs:60` crashes

```elixir
bit_string = Enum.join(bits, "")
```

`bits` is now a binary; `Enum.join/2` on a `String` raises
`Protocol.UndefinedError`.

**Fix:** the key *is* the bit string now — delete the join and use
`bits` directly.

### F-4 (MEDIUM) — "classical bit 0 leftmost" is not always true; the two simulator paths disagree

New prose in `lib/qx/simulation_result.ex` ("Keys of `:counts` are
outcome strings with classical bit 0 leftmost") and the CHANGELOG
("Keys join classical bits with bit 0 leftmost") over-promise. On the
sampled (non-conditional) path the key is joined in **measurement
insertion order**, not cbit-index order: `extract_classical_bits`
iterates `circuit.measurements` as appended
(`lib/qx/quantum_circuit.ex:182` — `measurements ++ [measurement]`).
Verified live:

- `Qx.x(0) |> Qx.measure(1,1) |> Qx.measure(0,0)` → `%{"01" => 10}`
  (cbit 0 holds 1, yet it is *rightmost* — call order won).
- Partial measurement `measure(0, 2)` on a 3-cbit circuit →
  `%{"1" => 10}` (key width = number of measurements), while the same
  circuit plus a `c_if` routes through `run_with_conditionals` and
  yields `%{"001" => 10}` (full register, genuinely cbit-0-leftmost).

The claim holds for `measure_all/1` and in-order `measure/3` chains —
i.e. every doc example and test — but it is not an invariant of the
producer. This ordering/width behaviour predates the commit; what the
commit adds is prose codifying an invariant the code doesn't enforce.

**Fix (choose one):**
1. *Docs-only (minimal, fits this branch):* reword to "outcome strings
   in measurement order (classical bit 0 leftmost when bits are measured
   in index order, as `measure_all/1` does)"; mirror in CHANGELOG.
2. *Producer normalisation (behaviour change, separate decision):* sort
   by cbit index and/or emit full-register-width keys on the sampled
   path so both simulator paths and the hardware path (which is
   register-width — `Qx.Hardware.infer_num_bits/1`) genuinely share one
   shape. If chosen, that belongs in ROADMAP as its own item, not a
   silent addition to this fix.

At minimum, record the path asymmetry in the plan's `scratchpad.md` or
`ROADMAP.md`.

### F-5 (LOW) — conditional path emits counts with zero measurements

A circuit with a `c_if` but no `measure` still returns
`counts: %{"00...0" => shots}` (full register of zeros), while the
non-conditional path returns `%{}` for the measurement-free case.
Pre-existing asymmetry, unaffected by this commit; note alongside F-4 if
the producer-normalisation route is ever taken.

### F-6 (LOW) — `spec/feature-028.md` shows list-key assertions

`spec/feature-028.md:549,562,576-577,601,630` contain the old
`result.counts[[1, 1]]` assertions. It is a historical spec archive, so
leaving it is defensible; if specs are meant to stay executable-true, a
one-line "superseded by counts-contract (2026-07-04)" note at the top is
enough. `spec/API_IMPROVEMENTS_SUMMARY.md:296` is key-shape-agnostic and
fine.

---

## Notes for the merge gate

- F-1..F-3 are mechanical, ~6 lines total across three example scripts;
  `examples/` is not in the hex package `files:` list and not exercised
  by `mix test`, which is why the suite stayed green — but they are repo
  documentation of the public contract and two of them now crash.
- F-4 needs a decision (reword vs. normalise); the reword variant is a
  two-line doc edit and keeps this branch honest.
- No changes needed in `lib/` or `test/` — the code change itself is
  complete and correct.
