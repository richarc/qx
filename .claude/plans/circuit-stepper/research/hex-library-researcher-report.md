# Library Research: Qx.steps/1 lazy step-through API

## Recommended

None — stdlib covers this fully.

## Considered but Rejected

### iterex
- **Why not**: Lazy external iterators, but `Stream.transform/3` over the existing internal reduce already gives exactly this; adding a dep for iterator semantics stdlib already provides is unjustified.

### quickrand / crypto_rand / entropy_string
- **Why not**: These generate random strings/IDs (UUIDs, tokens), not explicit-state RNG. None expose a seed/state-threading API comparable to `:rand.seed_s/2` + `:rand.uniform_s/1`, which is required for reproducible trajectories passed explicitly through the reduce accumulator.

### act
- **Why not**: "Compose stateful actions to simulate mutable state" — generic state-simulation DSL, unrelated to circuit stepping; would add abstraction with no fit to the existing internal reduce shape.

No quantum-simulation-stepping or circuit-trace package exists on hex.pm (searched "quantum simulation", "circuit trace" — hits are unrelated: Quantum job scheduler adapters, Spandex/OpenTelemetry tracing).

## No Library Needed

- **Stepping**: `Stream.transform/3` wrapping the existing internal `reduce` — idiomatic, lazy, zero new deps.
- **Per-step struct**: plain `defstruct` + `@type t`.
- **Inspect**: `defimpl Inspect, for: Qx.Step do ... end` — stdlib protocol, no dep.
- **Seeded RNG**: `:rand.seed_s/2` and `:rand.uniform_s/1` (OTP stdlib) thread RNG state explicitly through the reduce accumulator for reproducible trajectories — this is the built-in, functional (non-process-global) RNG API and is the correct primitive here.

## Compatibility Notes

- Elixir version requirement: whatever qx already targets (Stream, Inspect protocol, `:rand` all present since early OTP/Elixir; no floor change).
- Phoenix version requirement: n/a (qx is pure Elixir, no Phoenix dep).
- Known conflicts: none — no new deps proposed.
