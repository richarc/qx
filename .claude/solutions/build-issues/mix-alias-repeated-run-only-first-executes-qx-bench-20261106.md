---
module: "mix.exs (aliases)"
date: "2026-11-06"
problem_type: build_error
component: configuration
symptoms:
  - "`mix bench` alias listing `run bench/a.exs`, `run bench/b.exs`, … only ever ran the first suite"
  - "With `run --no-halt` entries the first benchmark never exited, masking the problem entirely"
root_cause: "Mix.Task.run/2 is a no-op for a task already run in the same mix invocation, so repeating `run` in an alias list silently skips every entry after the first; --no-halt additionally kept the VM alive after the first script"
severity: low
tags: [mix, alias, mix-task-rerun, benchee, bench]
---

# A mix alias that repeats `run` executes only the first entry

## Symptoms

```elixir
bench: ["run --no-halt bench/ghz_bench.exs", "run --no-halt bench/qft_bench.exs", ...]
```

Only `ghz` ever ran. The baseline for the other suites had to be captured by
running `mix run bench/<x>_bench.exs` one at a time.

## Root cause

Mix marks a task as invoked after it runs once per invocation, and later `run`
entries in the alias are skipped. `--no-halt` hid this because the first script
never returned.

## Solution

```elixir
bench: &run_benches/1

@bench_suites ~w(ghz qft renormalization kernels)
defp run_benches(_args) do
  Enum.each(@bench_suites, &Mix.Task.rerun("run", ["bench/#{&1}_bench.exs"]))
end
```

## Prevention

Any alias that repeats the same task with different args needs `Mix.Task.rerun/2`
in a function alias. Never put `--no-halt` on scripts that are meant to finish.
