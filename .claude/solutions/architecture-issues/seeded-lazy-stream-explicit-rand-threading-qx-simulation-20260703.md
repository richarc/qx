---
module: "Qx.Simulation"
date: "2026-07-03"
problem_type: architecture_pattern
component: stream_api
symptoms:
  - "A library `seed:` option implemented with `:rand.seed/2` silently clobbers the caller's process RNG state — an invisible side effect (spirit of Iron Law #2: a library must not mutate caller-owned runtime state)"
  - "Naively seeding once at stream-construction time makes every materialisation of an UNSEEDED stream replay the same trajectory, because `Stream.transform/3` reuses the same initial accumulator"
  - "Two consumers needed the same execution semantics — `run/2`'s eager per-shot reduce and a new lazy `steps/2` stream — and duplicating the timeline walk risked behavioural drift (the taps' initial-state bug came from exactly such a second path)"
root_cause: "Erlang's default `:rand` API is process-dict-backed, so seeding for reproducibility is a hidden write to caller state; and stream accumulators built eagerly are shared across materialisations, so entropy must be drawn inside `Stream.transform/4`'s start_fun, not at construction. The two-consumer problem is solved by making the single step function return emissions (per-operation snapshots) alongside the threaded accumulator: the eager path discards them, the lazy path maps them to structs."
severity: high
tags: [rand, seed-s, uniform-s, stream-transform, start-fun, laziness, single-execution-path, emissions, trajectory]
related_solutions: ["test-rejected-and-chained-conditionals-qx-cif-20260626"]
---

# Seeded lazy stream without touching the caller's process RNG

## Symptoms

`Qx.steps/2` needed a `seed:` option so measured-circuit trajectories
reproduce in teaching material. The obvious `:rand.seed(:exsss, seed)`
mutates the calling process's RNG — invisible, and rude in a library.
And a seed captured in an eagerly-built accumulator gets reused every
time the stream is re-materialised, which is right for seeded streams
and wrong for unseeded ones.

## Investigation

1. **Process-dict seeding** (`:rand.seed/2`): works, but
   `:rand.export_seed/0` before/after shows the caller's state
   replaced. Rejected during planning (scratchpad DECISION).
2. **Seed once in `steps/2`, close over the state**: seeded streams
   reproduce, but unseeded streams also replay identical trajectories
   on every `Enum.to_list/1` — the accumulator is fixed at
   construction.
3. **Root cause found**: reproducibility state belongs in
   `Stream.transform/4`'s `start_fun`, and randomness must be the
   functional API (`:rand.seed_s/1,2` + `:rand.uniform_s/1`) threaded
   through the accumulator.

## Root Cause

`:rand.uniform/0` reads and writes the process dictionary. Any library
that seeds it steals determinism from its caller. The functional
variants (`seed_s`, `uniform_s`) carry state explicitly, so the stream
accumulator is the natural home. Separately, `Stream.transform/3`
evaluates its initial accumulator once; per-materialisation freshness
requires the `/4` form whose `start_fun` runs each time enumeration
starts.

```elixir
# Problematic: clobbers caller state, and entropy fixed at construction
def steps(circuit, opts) do
  if seed = opts[:seed], do: :rand.seed(:exsss, seed)
  Stream.transform(timeline, {state0, cbits0, 0}, &step/2)
end
```

## Solution

```elixir
Stream.transform(
  timeline,
  fn -> {state0, cbits0, 0, 0, seed_rand(opts[:seed])} end,  # start_fun: per-materialisation
  fn item, {state, cbits, count, index, rand} ->
    {emissions, state, cbits, count, rand} =
      step_timeline_item(item, state, cbits, count, rand, num_qubits, renorm)
    {Enum.map(Enum.with_index(emissions, index), &to_step/1),
     {state, cbits, count, index + length(emissions), rand}}
  end,
  fn _acc -> :ok end
)

defp seed_rand(nil), do: :rand.seed_s(:exsss)        # fresh entropy per materialisation
defp seed_rand(seed), do: :rand.seed_s(:exsss, seed) # reproducible

defp perform_single_measurement(state, qubit, num_qubits, rand) do
  {uniform, new_rand} = :rand.uniform_s(rand)
  # ... collapse ...
  {collapsed, measured_value, new_rand}
end
```

Single execution path: `step_timeline_item/7` returns
`{[emission], state, cbits, count, rand}` where an emission is a
per-operation snapshot. `run/2`'s per-shot reduce pattern-matches the
emissions away; `steps/2` maps them to `%Qx.Step{}`. One walk, two
consumers, no drift.

Two test patterns worth stealing:

```elixir
# 1. The library never touches caller RNG:
before_seed = :rand.export_seed()
Simulation.steps(qc, seed: 1234) |> Enum.to_list()
assert :rand.export_seed() == before_seed

# 2. Laziness probe — poison the tail; take(1) must not reach it:
poisoned = %{qc | instructions: qc.instructions ++ [{:bogus_gate, [0], []}]}
assert [%Step{}] = Enum.take(Simulation.steps(poisoned), 1)
assert_raise Qx.GateError, fn -> Enum.to_list(Simulation.steps(poisoned)) end
```

### Files Changed

- `lib/qx/simulation.ex` — `steps/2` (`Stream.transform/4`), `seed_rand/1`,
  `step_timeline_item/7`, `step_conditional/7`, `perform_single_measurement/4`
- `test/qx/simulation_steps_test.exs` — seed, export_seed, laziness tests

## Prevention

- [ ] Add to Iron Laws? Candidate corollary to #2: "no writes to
      caller-owned runtime state (process dict, `:rand`, Logger
      metadata) without a documented reason"
- [x] Test pattern: any new `seed:`-style option gets an
      `export_seed`-unchanged assertion
- Specific guidance: "Reproducibility state lives in the stream
  accumulator, seeded in `start_fun`; randomness uses `_s` variants
  only. When two consumers need one execution path, return emissions
  the eager consumer discards."

## Related

- `.claude/solutions/testing-issues/test-rejected-and-chained-conditionals-qx-cif-20260626.md`
  — the timeline/`c_if` semantics this stream is built over
- Iron Law #2 (spirit): a library must not force runtime side effects
  on its callers
