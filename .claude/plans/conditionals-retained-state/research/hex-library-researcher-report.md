# Report: retained per-shot state in run_with_conditionals

## 1. Dependencies (measured from mix.exs / mix.lock)
- No new dep needed. Nx 0.13.0 (lock), Complex 0.7.0, Benchee 1.5.0 (`only: :dev`, so NOT available in :test).
- Nothing in Nx measures memory. Benchee's memory measurement is dev-only and only reports process-heap allocation (:erlang.trace based), which does not see off-heap refc binaries; not useful. The right tool is stdlib: `Process.info(pid, :binary)` plus a poller process.

## 2. Measurements (BinaryBackend, OTP 29 / Elixir 1.20.2; circuit: H(0), measure 0->0, c_if(0==1, X(1)), H on 2..n-1, measure 1->1)
Run in a fresh process; poller samples every 1 ms. MB = MiB. "pbin" = sum of sizes from `Process.info(pid,:binary)` of the runner process. "gbin" = `:erlang.memory(:binary)` minus value before the run. "heap" = `total_heap_size` peak. PROXY = reduce over `Qx.run(c, shots: 1)` keeping only last result (honest proxy only: real fix is a single run with a reduce inside; per-call overhead differs).

| n | shots | expected shots*2^n*8 | CURRENT pbin peak | CURRENT gbin peak | CURRENT heap peak | PROXY pbin peak | PROXY gbin peak | CURRENT time | PROXY time |
|---|---|---|---|---|---|---|---|---|---|
| 10 | 200 | 1.56 | 1.59 | 1.70 | 0.68-1.08 | 0.28 | 0.25 | 2.1 s | 1.5 s |
| 10 | 400 | 3.13 | 3.15 | 3.16 | 1.09-1.72 | 0.28 | 0.26 | 4.6 s | 3.0 s |
| 11 | 200 | 3.13 | 3.17-3.19 | 3.17 | 1.1-1.2 | 0.34 | 0.29-0.33 | 4.9 s | 3.1 s |
| 12 | 50 | 1.56 | 1.66 | 1.74 | 1.09 | 0.37 | 0.27 | 2.4 s | 1.6 s |
| 12 | 200 | 6.25 | 6.37 | 6.34 | 1.09 | 0.38 | 0.28 | 10.6 s | 6.5 s |
| 14 | 50 | 6.25 | 6.70 | 6.58 | 2.85 | 0.62 | 0.31 | 12.0 s | 10.9 s |
| 14 | 200 | 25.0 | 25.45 | 25.33 | 3.35 | 0.69 | 0.34 | 49.1 s | 43.4 s |

Key observations (measured):
- Per-process refc binary size (`Process.info(pid,:binary)`) tracks shots*2^n*8 within ~1-7% (always slightly above: one extra live state/in-flight binaries). It scales linearly with shots.
- `:erlang.memory(:binary)` delta tracks equally closely when nothing else runs, but it is VM-global (would be polluted by concurrent tests, even async: false modules only protect against other modules' tests; other processes such as Task/Application stuff still count).
- Process heap does NOT see it (1-3 MB regardless of shots; n=12 shots 50 vs 200 identical 1.09 MB). Heap is useless for this.
- "pbin_end"/"gbin_end" taken after `Qx.run` returns show nothing retained (result released); the retention is transient during the run. Peak (monotone growth during the run) is the right metric; there is no hook to sample "just before return" other than the poller's last samples, which equal the peak since growth is monotone.
- Post-fix proxy: refc binaries from dropped states ARE released during the run (peak stays ~0.3-0.7 MB constant, independent of shots). GC is triggered by the process's own heap growth, and binary-vheap pressure drives it; peak was 0.28 MB at n=10 and 0.69 MB at n=14 (about 3-4 states at n=14... 2^14*8=128 KB each, so ~5 states of slack). Garbage is therefore bounded, not unbounded, in this proxy.

## 3. Regression test design
- Metric: peak of `Process.info(pid, :binary)` summed sizes, sampled by a poller spawned by the test, for the process running `Qx.run/2` (run it in a `Task`/spawn so pid is known and isolated). Per-process, so concurrency-safe; `async: false` is NOT strictly required (recommend async: true is fine, but the poller adds CPU load; keeping async: false is harmless).
- Size: n=11, shots=200 (expected 3.13 MB retained), runtime about 5 s current, about 3-5 s after fix. Cheaper alternative n=10, shots=400 (3.15 MB, 4.6 s). Or n=10 shots=200 (1.59 MB, 2.1 s) at lower margin.
- Threshold: for n=11/shots=200: current 3.17-3.19 MB vs post-fix proxy 0.34 MB (3.12 MB retained would be gone). Threshold = 1.5 MB (= shots*2^n*8 / 2): about 2.1x above the post-fix proxy and 2.1x below the current peak. Express as `expected_all_states = shots * 2^n * 8; assert peak < expected_all_states / 2`, so it scales with parameters rather than a magic number.
- Flakiness: across 3 repeats of n=10 points the peak varied by less than 0.03 MB (CURRENT) and <0.15 MB (PROXY). The sampler could miss the peak at 1 ms intervals only if the run is shorter than a few ms; not a concern at seconds long runs, and retention is monotone so the last samples see it. A missed peak would only make the test pass wrongly on the old code (false pass), never a false fail on the fix.
- Caveat (inference): the post-fix numbers are from a proxy that re-enters Qx.run per shot, not the real reduce; real fix retains a similar bounded amount (last state + garbage awaiting GC), but verify when implemented. If the fix keeps the loop in one process with large heap growth, GC cadence could differ; the 2x margin should cover it (slack observed was about 5 states).
- Alternative non-memory assertion (inference, not measured): none needed.

## Surprises
- Nothing retained is visible via heap; only binary metrics work.
- Time: n=14/200 takes 49 s on BinaryBackend, so keep n <= 11 for tests.

## Spike script (also at /private/tmp/claude-501/-Users-richarc-Development-qxquantum-qx/51f5bcff-72ce-4150-83e1-ef107dbc0a6b/scratchpad/spike.exs, spike2.exs for the n=10/11 points)
```elixir
defmodule Spike do
  alias Qx.Operations, as: Op

  def circuit(n) do
    c = Qx.QuantumCircuit.new(n, n) |> Op.h(0) |> Op.measure(0, 0)
    c = Op.c_if(c, 0, 1, fn q -> Op.x(q, 1) end)
    Enum.reduce(2..(n - 1)//1, c, fn i, acc -> Op.h(acc, i) end) |> Op.measure(1, 1)
  end

  def pbin(pid) do
    case Process.info(pid, :binary) do
      {:binary, l} -> Enum.sum(for {_, s, _} <- l, do: s)
      _ -> 0
    end
  end

  def poll(pid, parent) do
    loop(pid, parent, %{pbin: 0, heap: 0, gbin: 0, samples: 0})
  end

  defp loop(pid, parent, acc) do
    receive do
      :stop -> send(parent, {:peaks, acc})
    after
      1 ->
        h = case Process.info(pid, :total_heap_size) do {_, w} -> w * 8; _ -> 0 end
        acc = %{acc | pbin: max(acc.pbin, pbin(pid)), heap: max(acc.heap, h),
                gbin: max(acc.gbin, :erlang.memory(:binary)), samples: acc.samples + 1}
        loop(pid, parent, acc)
    end
  end

  # fun runs in a fresh process; returns metrics
  def measure(fun) do
    parent = self()
    runner = spawn(fn ->
      receive do :go -> :ok end
      {t, res} = :timer.tc(fun)
      send(parent, {:done, t, pbin(self()), :erlang.memory(:binary)})
      receive do :exit -> res end
    end)
    :erlang.garbage_collect()
    g0 = :erlang.memory(:binary)
    poller = spawn(fn -> poll(runner, parent) end)
    send(runner, :go)
    {t, endbin, gend} = receive do {:done, t, b, g} -> {t, b, g} end
    send(poller, :stop)
    peaks = receive do {:peaks, p} -> p end
    send(runner, :exit)
    Map.merge(peaks, %{time_ms: div(t, 1000), end_pbin: endbin, g0: g0, gend: gend})
  end

  def mb(b), do: Float.round(b / 1_048_576, 2)
end

for {n, shots} <- [{12, 50}, {12, 200}, {14, 50}, {14, 200}] do
  c = Spike.circuit(n)
  expected = shots * :math.pow(2, n) * 8
  m = Spike.measure(fn -> Qx.run(c, shots: shots) end)
  # proxy for post-fix: reduce keeping only last result, shot-by-shot
  p = Spike.measure(fn ->
    Enum.reduce(1..shots, nil, fn _, _ -> r = Qx.run(c, shots: 1); {r.classical_bits, r.state} end)
  end)
  IO.puts("n=#{n} shots=#{shots} expected_MB=#{Spike.mb(trunc(expected))}")
  IO.puts("  CURRENT  time=#{m.time_ms}ms pbin_peak=#{Spike.mb(m.pbin)} pbin_end=#{Spike.mb(m.end_pbin)} gbin_peak_delta=#{Spike.mb(m.gbin - m.g0)} gbin_end_delta=#{Spike.mb(m.gend - m.g0)} heap_peak=#{Spike.mb(m.heap)} samples=#{m.samples}")
  IO.puts("  PROXY    time=#{p.time_ms}ms pbin_peak=#{Spike.mb(p.pbin)} pbin_end=#{Spike.mb(p.end_pbin)} gbin_peak_delta=#{Spike.mb(p.gbin - p.g0)} gbin_end_delta=#{Spike.mb(p.gend - p.g0)} heap_peak=#{Spike.mb(p.heap)} samples=#{p.samples}")
end
```
