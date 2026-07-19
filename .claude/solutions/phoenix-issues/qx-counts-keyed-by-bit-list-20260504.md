---
module: "Qx.SimulationResult"
date: "2026-05-04"
problem_type: logic_error
component: configuration
symptoms:
  - "Map.get(result.counts, \"11\", 0) always returns 0 even when measurements clearly produced |11>"
  - "Reported success probability is 0% but result.counts shows %{[1, 1] => 1000}"
  - "Histogram / counts lookup using a string bit-pattern returns the default"
root_cause: "Qx.SimulationResult.counts is keyed by a list of integer classical bits in declaration order (e.g. [1, 1]), not by a string bit-pattern (\"11\")"
severity: medium
tags: [qx, simulation_result, counts, classical_bits, examples]
---

# Qx.SimulationResult.counts is keyed by `[bit, bit, ...]`, not `"11"`

## Symptoms

You run a circuit, look at counts, and want to compute the probability of a specific outcome:

```elixir
result = Qx.run(circuit, shots: 1000)
IO.inspect(result.counts, label: "counts")
# counts: %{[1, 1] => 1000}

success = Map.get(result.counts, "11", 0)
prob = success / 1000 * 100
# prob: 0.0
```

The histogram clearly shows 1000/1000 measurements collapsed to |11⟩, but the lookup returns 0 and the reported probability is 0%.

This bit `examples/openqasm/grover_search.exs` — the example printed `Success probability: 0.0%` while the embedded counts inspect line clearly showed `%{[1, 1] => 1000}`. Confusing for new users.

## Investigation

1. **Read the simulation output**: counts came back as `%{[1, 1] => 1000}`. The keys are LISTS of integers, not strings.
2. **Looked at `Qx.SimulationResult` struct**: `classical_bits` is documented as a list of measured bits per shot; `counts` is the frequency map. The classical bits live in declaration order — for `bit[2] c;`, that's `[c[0], c[1]]`.
3. **Root cause**: code that copy-pasted Qiskit-style `counts['11']` syntax into Elixir produces silent zeros because the Map lookup never matches a list-typed key.

## Root Cause

Qx represents classical-bit registers as Elixir lists of integers, not as Qiskit-style bit strings. The `counts` map of `Qx.SimulationResult` is therefore `%{list_of_bits => shot_count}`. There is no string serialisation done at the `run/2` boundary.

The reasoning is reasonable: Elixir lists pattern-match cleanly into shot-counting reductions, no string parsing is required to decompose individual bits, and the order is unambiguous (declaration order — `c[0]` is leftmost in the list).

The trap is purely that Qiskit, IBM Quantum, and most QASM tooling render measurements as MSB-leftmost or LSB-leftmost bit strings, so a Qx user transferring intuition or copy-pasting tutorial code naturally writes `Map.get(result.counts, "11", 0)`.

## Solution

Use a list of integers in declaration order:

```elixir
result = Qx.run(circuit, shots: 1000)

# ✅ Correct lookup
success = Map.get(result.counts, [1, 1], 0)
prob = success / 1000 * 100

# ✅ For all-zero outcome
all_zero = Map.get(result.counts, [0, 0], 0)
```

If a string-form histogram is needed (e.g. to render a Qiskit-style chart), build it explicitly:

```elixir
counts_as_strings =
  result.counts
  |> Enum.map(fn {bits, n} -> {Enum.join(bits, ""), n} end)
  |> Map.new()
```

### Files Changed

- `examples/openqasm/grover_search.exs` — fixed `Map.get(result.counts, "11", 0)` → `Map.get(result.counts, [1, 1], 0)`. Added an inline comment explaining the key shape so future copy-paste users don't repeat the trap.

## Prevention

- [x] **Pattern to remember**: `result.counts` is `%{[bit, bit, ...] => count}`. Keys are integer lists in classical-bit declaration order.
- [x] **Always inspect first**: when writing a new example or tutorial that uses counts, run it once and `IO.inspect(result.counts)` before writing the lookup. The shape is visible and unambiguous.
- [ ] **Improve discoverability**: `Qx.SimulationResult` could include an explicit doctest example showing the key shape. Currently the type spec mentions `[integer]` but a concrete example would prevent the trap.
- **Specific guidance**: when porting Qiskit-style code into Qx, the FIRST translation step is bit-string → integer-list. `"11"` becomes `[1, 1]`. `"01"` becomes `[0, 1]` (qubit 0 = 0, qubit 1 = 1).

## Related

- `Qx.SimulationResult` struct definition in `lib/qx/simulation_result.ex`.
- Example fix in commit history: `examples/openqasm/grover_search.exs` corrected during v0.6 release prep.
