# Visualization Guide

## Overview

Qx provides three main visualization functions for quantum circuits and results. This guide clarifies when to use each one.

## Functions Summary

### 1. `Qx.draw/2` (alias for `Qx.Draw.plot/2`)

**Purpose:** Quick visualization of simulation results

**Input:** Simulation result map from `Qx.run/1` or `Qx.run/2`

**Use when:**
- You have already run a simulation
- You want to quickly visualize the probability distribution
- You don't need customization beyond basic options

**Example:**
```elixir
qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
result = Qx.run(qc)
Qx.draw(result)  # Automatic extraction of probabilities
```

---

### 2. `Qx.histogram/2` (alias for `Qx.Draw.histogram/2`)

**Purpose:** Visualization of raw probability tensors

**Input:** Nx tensor of probabilities

**Use when:**
- You have probability tensors from `Qx.get_probabilities/1`
- You want to visualize theoretical distributions without simulation
- You need to compare multiple probability distributions
- You're working with custom probability calculations

**Example:**
```elixir
# Get probabilities without full simulation
qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.h(1)
probs = Qx.get_probabilities(qc)  # Just probabilities, no shots/measurements
Qx.histogram(probs)

# Visualize custom distribution
custom_probs = Nx.tensor([0.25, 0.25, 0.25, 0.25])
Qx.histogram(custom_probs, title: "Uniform Distribution")
```

---

### 3. `Qx.draw_counts/2` (alias for `Qx.Draw.plot_counts/2`)

**Purpose:** Visualization of measurement outcomes

**Input:** Simulation result map with measurement counts

**Use when:**
- You have measurements in your circuit
- You want to see the distribution of measurement outcomes (not probabilities)
- You're analyzing classical bit patterns

**Example:**
```elixir
qc = Qx.create_circuit(2, 2)
     |> Qx.h(0)
     |> Qx.cx(0, 1)
     |> Qx.measure(0, 0)
     |> Qx.measure(1, 1)

result = Qx.run(qc, 1000)
Qx.draw_counts(result)  # Shows: [0,0] -> 523 times, [1,1] -> 477 times
```

---

## Quick Decision Tree

```
Do you have a simulation result?
├─ Yes
│  ├─ Want to see probabilities? → Use Qx.draw(result)
│  └─ Want to see measurement counts? → Use Qx.draw_counts(result)
│
└─ No, just have probabilities
   └─ Use Qx.histogram(probabilities)
```

---

## Key Differences: `draw` vs `histogram`

| Aspect | `draw/2` | `histogram/2` |
|--------|----------|---------------|
| **Input** | Simulation result map | Nx probability tensor |
| **Extracts probabilities?** | Yes, automatically | No, already has them |
| **Requires simulation?** | Yes | No |
| **Color** | Blue (#1f77b4) | Green (#2ca02c) |
| **Best for** | Quick results visualization | Custom probability analysis |
| **Default title** | "Quantum State Probabilities" | "Probability Histogram" |

---

## Advanced Usage

### Comparing Probabilities Before and After

```elixir
qc = Qx.create_circuit(2) |> Qx.h(0)

# Before CNOT
probs_before = Qx.get_probabilities(qc)
Qx.histogram(probs_before, title: "Before Entanglement")

# After CNOT
qc = qc |> Qx.cx(0, 1)
probs_after = Qx.get_probabilities(qc)
Qx.histogram(probs_after, title: "After Entanglement")
```

### Full Simulation Workflow

```elixir
qc = Qx.create_circuit(2, 2)
     |> Qx.h(0)
     |> Qx.cx(0, 1)
     |> Qx.measure(0, 0)
     |> Qx.measure(1, 1)

result = Qx.run(qc, 1000)

# Visualize probabilities
Qx.draw(result)

# Visualize measurement outcomes
Qx.draw_counts(result)
```

---

## Output Formats

All visualization functions support:
- `:vega_lite` (default) - Interactive plots for LiveBook
- `:svg` - Static SVG for saving to files

```elixir
# VegaLite for LiveBook
Qx.draw(result, format: :vega_lite)

# SVG for export
svg = Qx.draw(result, format: :svg)
File.write!("probability_distribution.svg", svg)
```
