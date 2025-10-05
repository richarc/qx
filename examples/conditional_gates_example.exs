#!/usr/bin/env elixir

# Conditional Gates Examples for Qx Quantum Computing Simulator
# This script demonstrates mid-circuit measurement with classical feedback
# (Feature-028: Classically-Controlled Quantum Operations)

IO.puts("=== Qx Conditional Gates Examples ===\n")

# Example 1: Simple conditional gate
IO.puts("1. Simple conditional X gate")
IO.puts("   Circuit: Measure |1⟩, apply X to qubit 1 if measurement == 1")

qc1 =
  Qx.create_circuit(2, 2)
  # Set qubit 0 to |1⟩
  |> Qx.x(0)
  # Measure qubit 0
  |> Qx.measure(0, 0)
  # Apply X to qubit 1 if classical bit 0 == 1
  |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
  |> Qx.measure(1, 1)

result1 = Qx.run(qc1, 100)

IO.puts("   Results (100 shots):")
Enum.each(result1.counts, fn {bits, count} ->
  IO.puts("   Classical bits #{inspect(bits)}: #{count} times")
end)

IO.puts("")

# Example 2: Conditional with value == 0
IO.puts("2. Conditional gate checking for 0")
IO.puts("   Circuit: Measure |0⟩, apply X to qubit 1 if measurement == 0")

qc2 =
  Qx.create_circuit(2, 2)
  # Qubit 0 stays in |0⟩
  |> Qx.measure(0, 0)
  # Apply X to qubit 1 if classical bit 0 == 0
  |> Qx.c_if(0, 0, fn c -> Qx.x(c, 1) end)
  |> Qx.measure(1, 1)

result2 = Qx.run(qc2, 100)

IO.puts("   Results (100 shots):")
Enum.each(result2.counts, fn {bits, count} ->
  IO.puts("   Classical bits #{inspect(bits)}: #{count} times")
end)

IO.puts("")

# Example 3: Probabilistic conditionals
IO.puts("3. Probabilistic conditional execution")
IO.puts("   Circuit: H gate creates superposition, measure, conditionally apply X")

qc3 =
  Qx.create_circuit(2, 2)
  # Create superposition on qubit 0
  |> Qx.h(0)
  |> Qx.measure(0, 0)
  # Apply X to qubit 1 if measurement == 1 (~50% chance)
  |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
  |> Qx.measure(1, 1)

result3 = Qx.run(qc3, 1000)

IO.puts("   Results (1000 shots):")
Enum.each(result3.counts, fn {bits, count} ->
  percentage = Float.round(count / 10, 1)
  IO.puts("   Classical bits #{inspect(bits)}: #{count} times (~#{percentage}%)")
end)

IO.puts("")

# Example 4: Multiple gates in conditional block
IO.puts("4. Multiple gates in conditional block")
IO.puts("   Circuit: If measurement == 1, apply X and H gates")

qc4 =
  Qx.create_circuit(3, 3)
  |> Qx.x(0)
  |> Qx.measure(0, 0)
  # Apply multiple gates if condition is true
  |> Qx.c_if(0, 1, fn c ->
    c
    |> Qx.x(1)
    |> Qx.h(2)
  end)
  |> Qx.measure(1, 1)
  |> Qx.measure(2, 2)

result4 = Qx.run(qc4, 100)

IO.puts("   Results (100 shots):")
Enum.each(result4.counts, fn {bits, count} ->
  IO.puts("   Classical bits #{inspect(bits)}: #{count} times")
end)

IO.puts("")

# Example 5: Quantum Teleportation
IO.puts("5. Quantum Teleportation Protocol")
IO.puts("   Teleporting |1⟩ state from qubit 0 to qubit 2")

qc5 =
  Qx.create_circuit(3, 3)
  # Prepare state to teleport (|1⟩)
  |> Qx.x(0)
  # Create Bell pair between qubits 1 and 2
  |> Qx.h(1)
  |> Qx.cx(1, 2)
  # Bell measurement on qubits 0 and 1
  |> Qx.cx(0, 1)
  |> Qx.h(0)
  |> Qx.measure(0, 0)
  |> Qx.measure(1, 1)
  # Conditional corrections on qubit 2 based on measurement results
  |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)
  |> Qx.c_if(0, 1, fn c -> Qx.z(c, 2) end)
  |> Qx.measure(2, 2)

result5 = Qx.run(qc5, 1000)

IO.puts("   Measuring qubit 2 (should always be |1⟩):")

total_measure_1 =
  Enum.reduce(result5.counts, 0, fn {bits, count}, acc ->
    if Enum.at(bits, 2) == 1, do: acc + count, else: acc
  end)

IO.puts("   Qubit 2 measured as |1⟩: #{total_measure_1}/1000 shots")
IO.puts("   Teleportation success rate: #{Float.round(total_measure_1 / 10, 1)}%")

IO.puts("\n   Measurement distribution:")
Enum.each(result5.counts, fn {bits, count} ->
  [m0, m1, final] = bits
  percentage = Float.round(count / 10, 1)
  IO.puts("   M0=#{m0}, M1=#{m1} → Final=#{final}: #{count} times (~#{percentage}%)")
end)

IO.puts("")

# Example 6: Bell State with Conditional Reset
IO.puts("6. Bell State with Conditional Reset")
IO.puts("   Create Bell state, measure first qubit, conditionally reset both")

qc6 =
  Qx.create_circuit(2, 2)
  # Create Bell state
  |> Qx.h(0)
  |> Qx.cx(0, 1)
  # Measure first qubit
  |> Qx.measure(0, 0)
  # If measured |1⟩, flip both qubits back to |0⟩
  |> Qx.c_if(0, 1, fn c ->
    c
    |> Qx.x(0)
    |> Qx.x(1)
  end)
  |> Qx.measure(1, 1)

result6 = Qx.run(qc6, 1000)

IO.puts("   Results (1000 shots):")
IO.puts("   After conditional reset, both qubits should measure |00⟩")
Enum.each(result6.counts, fn {bits, count} ->
  percentage = Float.round(count / 10, 1)
  IO.puts("   Classical bits #{inspect(bits)}: #{count} times (~#{percentage}%)")
end)

IO.puts("")

# Example 7: Multiple sequential conditionals
IO.puts("7. Multiple sequential conditionals")
IO.puts("   Two measurements control different gates")

qc7 =
  Qx.create_circuit(3, 3)
  # Set qubits 0 and 1 to |1⟩
  |> Qx.x(0)
  |> Qx.x(1)
  # Measure both
  |> Qx.measure(0, 0)
  |> Qx.measure(1, 1)
  # First conditional applies X
  |> Qx.c_if(0, 1, fn c -> Qx.x(c, 2) end)
  # Second conditional also applies X (cancels out)
  |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)
  |> Qx.measure(2, 2)

result7 = Qx.run(qc7, 100)

IO.puts("   Results (100 shots):")
IO.puts("   Both conditionals fire, X applied twice → qubit 2 stays |0⟩")
Enum.each(result7.counts, fn {bits, count} ->
  IO.puts("   Classical bits #{inspect(bits)}: #{count} times")
end)

IO.puts("\n=== Examples Complete ===")
IO.puts("All conditional gate examples executed successfully!")
