---
module: "Qx.Draw"
date: "2026-11-14"
problem_type: test_design
component: testing
symptoms:
  - "Qx.Draw.plot/2, histogram/2 and state_table/2 called Nx.to_flat_list on the 2^n tensor and built one host term per basis state; a 2^20-element call needed 75.5M words of heap (plot, histogram) or 155M words (state_table)"
  - "A size guard placed after the host-side build raises the same Qx.DrawSizeError as one placed before it, so assert_raise cannot tell the two apart"
  - "The first guarded call in a fresh VM was killed at a 1,598-word heap limit although the same call survives at 233 words once modules are loaded"
root_cause: "the order of a guard relative to an expensive host-side build is not visible in the function's result or exception; only the resources the call uses before raising show it, and a timing assertion is too noisy to pin that, while a per-process max_heap_size separates the two cases by five orders of magnitude because tensor data is an off-heap refc binary and the built list is on-heap"
severity: medium
tags: [max-heap-size, guard-order, host-side-build, nx, binary-backend, regression-test, typed-errors, draw]
elixir_version: "1.20.2"
related_solutions:
  - ".claude/solutions/testing-issues/retained-tensor-memory-test-refc-binary-peak-gc-slack-qx-simulation-20261110.md"
  - ".claude/solutions/architecture-issues/tightened-guard-exposes-unvalidated-option-qx-run-shots-20261108.md"
---

# Testing that a guard runs before a host-side 2^n build: `:max_heap_size`

## Symptoms

- The draw functions built a host list of 2^n floats or rows before anything
  else. The fix adds a size cap that raises `Qx.DrawSizeError`.
- The cap is only useful if it runs **first**. `hide_zeros: true` in
  `Qx.Draw.Tables` shows how easy it is to get wrong: the filter runs after
  the full build.
- `assert_raise Qx.DrawSizeError` passes for either order.

## Investigation

1. **Timing** — rejected. A 2^20 build takes about a second, but any
   threshold is machine- and load-dependent.
2. **`Process.info(pid, :binary)` peak** (the earlier retention technique) —
   wrong metric. The input tensor is the refc binary; the thing to detect is
   the on-heap list.
3. **`Process.flag(:max_heap_size, %{size: words, kill: true, error_logger: false})`**
   in a spawned process — chosen. The process is killed at the first GC that
   finds the heap over the limit. Off-heap binaries are not counted (the
   default `include_shared_binaries: false`).
4. **Measured both sides before choosing the limit** (OTP 29, Nx 0.13.0,
   BinaryBackend, 2^20 elements, binary search to ~3%):

   | Call | Smallest surviving heap (words) |
   |---|---|
   | unguarded `histogram/2`, `plot/2` | 75,544,576 |
   | unguarded `state_table/2` | 155,235,840 |
   | guarded, modules already loaded | 233 (the VM minimum) |
   | guarded, first call in a fresh VM | between 1,598 and 4,181 |

   A proxy for the guarded call, measured before the implementation existed,
   read 233 words. The real functions needed up to 4,181 on a cold VM:
   module loading runs in the calling process.

## Root Cause

Guard order is a resource property, not a result property. The heap limit
turns it into an observable outcome: the process either sends back the
exception or dies with reason `:killed`.

## Solution

Limit: 2^17 = 131,072 words. 31× above the cold guarded need, 576× below the
smallest unguarded survival.

```elixir
@guard_heap_words 1 <<< 17

defp run_with_heap_limit(fun) do
  parent = self()

  {pid, ref} =
    spawn_monitor(fn ->
      Process.flag(:max_heap_size, %{size: @guard_heap_words, kill: true, error_logger: false})

      outcome =
        try do
          fun.()
          :returned
        rescue
          exception -> {:raised, exception}
        end

      send(parent, {:outcome, self(), outcome})
    end)

  receive do
    {:outcome, ^pid, outcome} ->
      Process.demonitor(ref, [:flush])
      outcome

    {:DOWN, ^ref, :process, ^pid, reason} ->
      reason
  end
end

test "histogram/2 on 2^20 elements raises within the heap limit" do
  # Build the input outside the limited process, as in the measurements.
  input = Nx.broadcast(Nx.tensor(0.0, type: :f32), {1 <<< 20})

  assert {:raised, error} = run_with_heap_limit(fn -> Qx.Draw.histogram(input) end)
  assert is_exception(error, Qx.DrawSizeError)
end

# Control: proves the harness kills a real build.
test "a call that does build 2^20 elements is killed" do
  probabilities = Nx.broadcast(Nx.tensor(0.0, type: :f32), {1 <<< 20})
  assert :killed = run_with_heap_limit(fn -> Nx.to_flat_list(probabilities) end)
end
```

Red on the old code: `match (=) failed ... right: :killed`. Green after the
guard: 62 tests, stable over 25 consecutive runs and three full-suite runs.

### Files Changed

- `lib/qx/draw.ex`, `lib/qx/draw/tables.ex` — guard before the host build
- `lib/qx/validation.ex` — `draw_max_qubits!/1`, `validate_max_qubits!/1`,
  `validate_draw_size!/2`
- `lib/qx/errors.ex` — `Qx.DrawSizeError`
- `test/qx/draw_size_cap_test.exs` — new

## Prevention

- To test "X happens before an expensive host-side build", run the call under
  `:max_heap_size` with `kill: true` and assert on the outcome. Do not time it.
- Measure **both** sides and pick a limit with a wide margin on each. Measure
  the guarded side on the **real** function in a **fresh VM**; a proxy and a
  warm run both under-read it (233 vs up to 4,181 words here).
- Include a control test that a real build **is** killed at that limit, so a
  harness that never kills cannot pass silently.
- Build the large input in the test process, not inside the limited process.
  Otherwise the test also depends on how the input constructor uses heap, and
  differs from what was measured (review finding).
- Catch the exception inside the spawned process and send it back. An
  uncaught raise logs a crash report; `error_logger: false` only silences the
  kill.
- Match with `is_exception(error, Mod)` rather than `%Mod{}` while the module
  does not exist yet, or the red run is a compile failure instead of the
  intended assertion failure.
- Tests that emit `IO.warn` inside `capture_io(:stderr)` belong in an
  `async: false` module when another async test asserts its captured stderr
  is empty (review finding on the same file).
- Related, same change: test `size > 2^n` as `Bitwise.bsr(size - 1, n) > 0`
  when `n` comes from a caller option. `Bitwise.bsl(1, n)` builds a bignum
  and raises a raw system-limit error for a very large `n` (Iron Law #7).

## Related

- `.claude/solutions/testing-issues/retained-tensor-memory-test-refc-binary-peak-gc-slack-qx-simulation-20261110.md` — the off-heap counterpart: peak refc-binary bytes for retained tensors
- Plan: `.claude/plans/draw-state-size-cap/` (measurements in `scratchpad.md`); commit `6684cb9`
