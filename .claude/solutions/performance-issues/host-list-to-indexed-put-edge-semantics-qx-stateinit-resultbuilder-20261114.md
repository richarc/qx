---
module: "Qx.StateInit / Qx.ResultBuilder"
date: "2026-11-14"
problem_type: performance_issue
component: nx_host_construction
symptoms:
  - "Qx.StateInit.basis_state/2 at dimension 2^20 took 227 ms and needed over 41 million words of process heap: a comprehension built 2^20 Complex structs before Nx.tensor/2"
  - "Qx.ResultBuilder.build_probability_tensor/2 ran List.replace_at over a 2^n list once per outcome (O(outcomes × 2^n)); 4.5 s at 2^20 with 1,000 spread-out indices"
  - "After the rewrite to Nx.indexed_put, basis_state(1, 4, nil) returned {:s, 32} instead of {:c, 64}, and two outcomes with the same index depended on an ordering Nx documents as non-deterministic; all tests were green"
root_cause: "a host list handed to Nx.tensor/2 carries semantics the list code never states: the element values drive type inference when type is nil, and sequential list updates define last-write-wins for duplicates and Elixir's negative-index wrap; a zero-broadcast plus Nx.indexed_put has none of these, so the rewrite is equivalent only for the inputs someone thought to test"
severity: medium
tags: [nx, indexed_put, repeated-indices, type-inference, host-list, iron-law-5, binary-backend, max-heap-size, behaviour-preserving-rewrite, review]
elixir_version: "1.20.2"
related_solutions:
  - ".claude/solutions/testing-issues/guard-before-host-build-max-heap-size-test-qx-draw-20261114.md"
  - ".claude/solutions/performance-issues/sampling-binary-search-preserves-draw-mapping-qx-sampler-20261108.md"
---

# Replacing a host-side 2^n list with `Nx.indexed_put`: what the list was doing for you

## Symptoms

- Two functions built a 2^n Elixir list and passed it to `Nx.tensor/2`
  (Iron Law #5). Every `Qx.create_circuit/1` paid for one.
- The obvious rewrite, a zero broadcast plus `Nx.indexed_put/3`, was 50×
  faster and passed the whole suite.
- `/phx:review` then found three inputs whose result had changed. None was
  covered by a test, and two of them returned a value rather than raising.

## Investigation

1. **Candidate primitives** (Nx 0.13.0, BinaryBackend, measured at 2^22):
   `indexed_put` and `put_slice` 17 ms; `equal(iota)` and `pad` 8–25×
   slower because BinaryBackend loops per element for them; `concatenate`
   raises on zero-length parts; a hand-built binary is fastest but encodes
   the complex layout by hand.
2. **The reviewers' edge cases were run on both sides**, new code and `main`,
   with one script and `git stash push -- lib` in between. This settled each
   claim in a minute and refuted three of them (for example, a `"-1"` outcome
   key raised on `main` too, earlier in the same function).

## Root Cause

The list was carrying behaviour implicitly:

| Input | List code | Naive `indexed_put` |
|---|---|---|
| `type: nil` | type inferred from the `Complex` elements: c64 | `Nx.tensor(0, type: nil)` infers s32 |
| two updates, same index | later `List.replace_at` wins | "the result is non-deterministic" (`Nx.indexed_put/4` docs); BinaryBackend happens to keep the last |
| negative index | `List.replace_at(-1)` wraps to the last element | raises "out of bounds" |
| index ≥ size | explicitly skipped | raises "out of bounds" |
| no updates | zeros | raises "cannot build empty tensor" |
| f64 update values | `Nx.tensor(list)` gives f32 | result promoted to f64 |

Separately, `trunc(:math.pow(2, n))` → `Integer.pow(2, n)` is identical only
for non-negative integers. A float `n` worked before and raises after; a
negative `n` gave 0 before and raises after. `Bitwise.bsl(1, n)` keeps the
negative case (0) but still raises on a float. This matters only where `n` is
not validated first, such as a predicate (`Qx.Validation.valid_register?/2`).

## Solution

```elixir
# basis_state/3
type = type || :c64

Nx.tensor(0, type: type)
|> Nx.broadcast({dimension})
|> Nx.indexed_put(Nx.tensor([[index]]), Nx.tensor([1], type: type))

# build_probability_tensor/2
in_range =
  index_prob_pairs
  |> Enum.filter(fn {index, _prob} -> index >= 0 and index < size end)
  |> Map.new()          # collapses duplicate indices, last wins, on the host
  |> Map.to_list()

case in_range do
  [] -> zeros           # indexed_put cannot take an empty update
  pairs ->
    {indices, probs} = Enum.unzip(pairs)
    Nx.indexed_put(zeros, Nx.tensor(Enum.map(indices, &[&1])), Nx.tensor(probs, type: :f32))
end
```

Host work is now O(1) and O(outcomes). Measured at 2^20: `basis_state`
227 ms → 4.7 ms, heap need 41.5M words → under 1,600; `from_counts` with
1,000 outcomes 111 ms → 11 ms.

The "no host list" property is pinned with the `:max_heap_size` harness:
limit 2^17 words, 82× above the new code's cold-VM need and 174× below the
smallest list-based build.

## Prevention

- Before replacing a list build with a scatter, write down what the list did
  for: nil/inferred type, duplicate indices, negative indices, out-of-range
  indices, empty input, and value dtype. Pin each with a test that passes on
  the old code first.
- Never rely on `Nx.indexed_put` or `Nx.indexed_add` order for repeated
  indices. Deduplicate on the host. A passing test on BinaryBackend proves
  nothing about other backends.
- For a behaviour-preserving rewrite, keep one edge-case script and run it on
  both sides (`git stash push -- lib`, run, `git stash pop`, run). Use it to
  check reviewer claims too: three of the reviewers' findings here were wrong.
- When sweeping `:math.pow` → `Integer.pow`, check each site for whether `n`
  is validated first. In a predicate, guard with `is_integer/1` rather than
  let it raise.
