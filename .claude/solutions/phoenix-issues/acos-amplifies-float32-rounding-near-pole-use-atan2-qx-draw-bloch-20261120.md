---
module: "Qx.Draw.SVG.Bloch"
date: "2026-11-20"
problem_type: logic_error
component: numerics
symptoms:
  - "Bloch sphere readout could show an arbitrary φ beside θ = 0.00π for a state that is |0⟩ or |1⟩ to float32 precision"
  - "θ computed as 2·acos(|α|) read about 7e-4 rad for |α| = 0.99999994 (one float32 step under 1), so a pole guard of sin θ < 1.0e-6 never fired"
  - "After switching to atan2, a NaN or infinite amplitude raised ArgumentError from :math.atan2 where the old min/max clamp had hidden it"
root_cause: "acos has infinite slope at 1: a rounding error ε in |α| becomes about sqrt(2ε) in the angle, so float32 noise of 6e-8 turns into 3.5e-4 in θ/2. The guard that decides 'this is a pole, φ has no meaning' was set at the float32 noise level of the amplitude, not at the noise level of the derived angle, so φ was read from the phase of a noise-level β"
severity: medium
iron_law_number: 8
tags: [bloch, acos, atan2, float32, c64, pole, tolerance, iron-law-8]
related_solutions:
  - ".claude/solutions/phoenix-issues/spec-tolerance-below-float32-epsilon-qx-simulation-20260516.md"
  - ".claude/solutions/testing-issues/widen-c64-test-tolerances-iron-law-8-20260615.md"
---

# `acos` near 1 amplifies float32 rounding: use `atan2` of the two magnitudes

## Symptoms

`Qx.draw_bloch/2` on a state at a pole, after float32 rounding:

```elixir
# |α| one float32 step under 1, β noise with a phase of its own
Nx.tensor([Complex.new(0.99999994, 0.0),
           Complex.new(1.0e-8 * :math.cos(2.0), 1.0e-8 * :math.sin(2.0))], type: :c64)
# readout before the fix: θ = 0.00π  φ = 0.64π
```

The review found the mechanism by reading; `H·H`, `Rx(π)·Rx(π)` and similar
did not reproduce it, because their β is exactly zero or real. It needs a
β that is noise *with a phase*.

## Root cause

```elixir
theta = 2 * :math.acos(max(-1.0, min(1.0, Complex.abs(alpha))))
phi = if :math.sin(theta) < 1.0e-6, do: 0.0, else: arg(beta) - arg(alpha)
```

`acos(1 - ε) ≈ sqrt(2ε)`. With ε = 6e-8 that is 3.5e-4, so θ ≈ 7e-4 and
`sin θ` is far above the 1.0e-6 guard. The tolerance was feasible for the
amplitude (Iron Law #8) but not for a quantity derived from it through a
function with unbounded slope.

## Solution

```elixir
theta = 2 * :math.atan2(Complex.abs(beta), Complex.abs(alpha))
phi = if :math.sin(theta) < @pole_epsilon, do: 0.0, else: ...   # 1.0e-5
```

`atan2` has slope at most 1 in both arguments, so noise in β stays noise
in θ. It needs no clamp. For a normalised state the result equals
`2·acos(|α|)`.

Two consequences to handle on purpose:

- An unnormalised state is now drawn by direction (`[0.5, 0.5]` is on the
  equator; `acos` put it at θ = 0.67π). CHANGELOG it.
- The clamp had swallowed NaN and infinity (`min(1.0, :nan)` is `1.0`,
  because atoms sort above numbers). `:math.atan2/2` raises on them, so
  check the amplitudes are numbers first and raise a typed error.

## Prevention

- When a tolerance guards a *derived* quantity, propagate the float32
  error through the function first. `acos`/`asin` near ±1 and `sqrt` near 0
  turn ε into sqrt(ε); a 1e-6 guard after them is unreachable.
- Prefer `atan2(|β|, |α|)` to `acos(|α|)` and `atan2(y, x)` to
  `acos(x / r)` for any angle taken from amplitudes.
- A test for a pole guard needs noise with a non-zero phase in the small
  amplitude; exact zeros and real values pass whatever the guard is.
- When removing a `min`/`max` clamp, ask what else it was absorbing: Nx
  returns NaN and infinity to the host as atoms.
