---
module: "Qx.Simulation"
date: "2026-11-10"
problem_type: test_design
component: testing
symptoms:
  - "Qx.run/2 on a c_if circuit held shots × 2^n × 8 bytes until the run ended (6.64 MB at n=12 × 200 shots; ~5 GB at n=16 × 10k), yet process heap stayed at 1-3 MB whatever the shot count"
  - "After the fix, the planned memory test (n=10, 200 shots, threshold 0.82 MB) read 720,564 B on a cold VM: only 1.14× under the threshold, against a research estimate of 0.28 MiB"
  - "Memory measured after run/2 returned showed nothing retained on the old code"
root_cause: "run_with_conditionals/3 collected {state, cbits} for every shot in a list and used only the cbits and the last state; Nx.BinaryBackend tensors are refc (off-heap) binaries, so heap metrics cannot see them, the retention is transient (gone once the function returns), and after the fix a fixed 0.3-0.75 MB of not-yet-collected binaries remains that does not scale with n or shots"
severity: medium
tags: [memory, refc-binary, process-info, garbage-collection, regression-test, nx, binary-backend, run-with-conditionals]
related_solutions:
  - ".claude/solutions/performance-issues/sampling-binary-search-preserves-draw-mapping-qx-sampler-20261108.md"
  - ".claude/solutions/architecture-issues/tightened-guard-exposes-unvalidated-option-qx-run-shots-20261108.md"
---

# Testing that a loop does not retain Nx tensors: peak refc-binary bytes, sized above the GC slack

## Symptoms

- `for _ <- 1..shots, do: execute_single_shot(...)` returned `{state, cbits}`
  per shot; all states stayed referenced until the run ended.
- `Process.info(pid, :memory)` / `:total_heap_size` did not move with shots.
- Nothing was visible after `run/2` returned: the list is garbage by then.

## Investigation

1. **Process heap** — flat at 1–3 MB. Tensors on `Nx.BinaryBackend` are
   binaries over 64 bytes, so they live off-heap.
2. **`:erlang.memory(:binary)`** — tracks the retention, but is VM-global, so
   other tests' allocations pollute it.
3. **`Process.info(pid, :binary)`**, summing the sizes — tracks
   `shots × 2^n × 8` within 1–7 %, per process. Chosen.
4. **Proxy for the post-fix peak** (a reduce over repeated
   `Qx.run(c, shots: 1)`): 0.28 MiB at n=10. The real fix read 0.30–0.34 MB
   warm but **0.72–0.75 MB as the first run in a fresh VM**, identical in
   6 of 6 VMs at n=12. The proxy under-read the cold case.
5. **The slack is absolute, not a number of states**: 88 states at n=10,
   5.6 at n=14, about 0.3–0.75 MB either way. So a small run cannot separate
   "retains everything" from "retains one plus slack".

## Root Cause

The loop kept data it never used, and the only metric that sees it is the
per-process refc-binary total sampled *during* the run.

```elixir
# Before: every shot's 2^n state stays alive in `results`
results = for _shot <- 1..shots, do: execute_single_shot(circuit, renorm)
classical_bits = Enum.map(results, fn {_state, cbits} -> cbits end)
{last_state, _} = List.last(results)
```

## Solution

```elixir
# lib/qx/simulation.ex — keep cbits, carry only the latest state
{reversed_bits, last_state} =
  Enum.reduce(1..shots//1, {[], nil}, fn _shot, {bits, _previous_state} ->
    {state, cbits} = execute_single_shot(circuit, renorm)
    {[cbits | bits], state}
  end)

classical_bits = Enum.reverse(reversed_bits)
```

The regression test runs the work in its own process and polls from the test
process (no `Process.sleep`, no separate poller):

```elixir
defp peak_binary_bytes(fun) do
  parent = self()
  runner = spawn_link(fn -> send(parent, {:done, self(), fun.()}) end)
  poll_peak(runner, 0)
end

defp poll_peak(runner, peak) do
  receive do
    {:done, ^runner, result} -> {peak, result}
  after
    1 -> poll_peak(runner, max(peak, binary_bytes(runner)))
  end
end

defp binary_bytes(pid) do
  case Process.info(pid, :binary) do
    {:binary, binaries} -> binaries |> Enum.map(fn {_id, size, _refs} -> size end) |> Enum.sum()
    nil -> 0
  end
end
```

Assertions, at n=12 × 200 shots (all states = 6.55 MB):

- `peak < all_states_bytes / 2` (3.28 MB): old code 6.64 MB (2× over), fix
  ≤ 0.75 MB (4.4× under).
- `peak > 2^n * 8`: a floor, so a poller that saw nothing cannot pass.

Measured: old code 6,636,528 B; fixed 381 KB warm, 745,140 B cold. The file
runs in about 1.6 s, `async: false`.

### Files Changed

- `lib/qx/simulation.ex:174-195` — reduce instead of a list of per-shot states
- `test/qx/simulation_conditionals_retention_test.exs` — new (6 tests)
- `CHANGELOG.md` — Unreleased → Fixed

## Prevention

- To assert "does not retain tensors", poll `Process.info(pid, :binary)` for
  the peak **during** the run. Heap metrics and after-the-fact measurements
  both read zero.
- Size the test from the **real** fix measured in a **fresh VM**, not from a
  proxy and not from a warm second run. Make the retained total several MB so
  that half of it clears ~0.75 MB of GC slack with a wide margin. Growing n or
  shots does not grow the slack.
- Always pair an upper-bound memory assertion with a floor; `Process.info`
  returning `nil` or a refactor that moves the work to another process would
  otherwise pass at 0.
- Unseeded per-shot results cannot have their order pinned outcome by outcome.
  Check an order-dependent invariant (last list entry matches the returned
  state) and repeat it ~30 times; confirm with a mutation (remove the
  `Enum.reverse`) that the test goes red.
- A threshold margin below the plan's bar is a stop-and-amend moment, with the
  numbers, not a reason to loosen the threshold.
- Review check: a `for`/`Enum.map` whose elements carry a 2^n tensor that is
  only partly used afterwards is a retention bug; reduce and carry what is used.

## Related

- `.claude/solutions/performance-issues/sampling-binary-search-preserves-draw-mapping-qx-sampler-20261108.md` — the preceding change on the same shot paths
- Plan: `.claude/plans/conditionals-retained-state/` (measurements in `scratchpad.md`); commit `69902d2`
