#!/usr/bin/env elixir

# Basic Usage Examples for Qx Quantum Computing Simulator
# This script demonstrates the core functionality of the Qx library

IO.puts("=== Qx Quantum Computing Simulator Examples ===\n")

# Example 1: Simple superposition with Hadamard gate
IO.puts("1. Creating superposition with Hadamard gate")
qc1 = Qx.create_circuit(1)
      |> Qx.h(0)

result1 = Qx.run(qc1)
probs1 = Nx.to_flat_list(result1.probabilities)

IO.puts("   Single qubit in superposition:")
IO.puts("   |0⟩ probability: #{Float.round(Enum.at(probs1, 0), 4)}")
IO.puts("   |1⟩ probability: #{Float.round(Enum.at(probs1, 1), 4)}")
IO.puts("")

# Example 2: Bell State (maximally entangled state)
IO.puts("2. Creating Bell state (entangled qubits)")
bell_circuit = Qx.bell_state()
result2 = Qx.run(bell_circuit)
probs2 = Nx.to_flat_list(result2.probabilities)

IO.puts("   Bell state probabilities:")
IO.puts("   |00⟩ probability: #{Float.round(Enum.at(probs2, 0), 4)}")
IO.puts("   |01⟩ probability: #{Float.round(Enum.at(probs2, 1), 4)}")
IO.puts("   |10⟩ probability: #{Float.round(Enum.at(probs2, 2), 4)}")
IO.puts("   |11⟩ probability: #{Float.round(Enum.at(probs2, 3), 4)}")
IO.puts("")

# Example 3: GHZ State (3-qubit entangled state)
IO.puts("3. Creating GHZ state (3-qubit entanglement)")
ghz_circuit = Qx.ghz_state()
result3 = Qx.run(ghz_circuit)
probs3 = Nx.to_flat_list(result3.probabilities)

IO.puts("   GHZ state probabilities:")
for i <- 0..7 do
  binary = Integer.to_string(i, 2) |> String.pad_leading(3, "0")
  prob = Enum.at(probs3, i)
  IO.puts("   |#{binary}⟩ probability: #{Float.round(prob, 4)}")
end
IO.puts("")

# Example 4: Circuit with measurements
IO.puts("4. Circuit with measurements")
measurement_circuit = Qx.create_circuit(2, 2)
                      |> Qx.h(0)
                      |> Qx.cx(0, 1)
                      |> Qx.measure(0, 0)
                      |> Qx.measure(1, 1)

result4 = Qx.run(measurement_circuit, 100)  # 100 shots
IO.puts("   Performed #{result4.shots} measurements")
IO.puts("   Measurement outcomes:")
Enum.each(result4.counts, fn {bits, count} ->
  bit_string = Enum.join(bits, "")
  IO.puts("   #{bit_string}: #{count} times (#{Float.round(count/result4.shots*100, 1)}%)")
end)
IO.puts("")

# Example 5: Multiple gate operations
IO.puts("5. Complex circuit with multiple gates")
complex_circuit = Qx.create_circuit(3)
                  |> Qx.h(0)      # Hadamard on qubit 0
                  |> Qx.x(1)      # X gate on qubit 1
                  |> Qx.cx(0, 2)  # CNOT from 0 to 2
                  |> Qx.ccx(0, 1, 2)  # Toffoli gate

result5 = Qx.run(complex_circuit)
probs5 = Nx.to_flat_list(result5.probabilities)

IO.puts("   Complex circuit state probabilities:")
for i <- 0..7 do
  binary = Integer.to_string(i, 2) |> String.pad_leading(3, "0")
  prob = Enum.at(probs5, i)
  if prob > 0.001 do  # Only show non-zero probabilities
    IO.puts("   |#{binary}⟩ probability: #{Float.round(prob, 4)}")
  end
end
IO.puts("")

# Example 6: Using parameterized gates
IO.puts("6. Parameterized rotation gates")
rotation_circuit = Qx.create_circuit(1)
                   |> Qx.ry(0, :math.pi/4)  # Y rotation by π/4

result6 = Qx.run(rotation_circuit)
probs6 = Nx.to_flat_list(result6.probabilities)

IO.puts("   After RY(π/4) rotation:")
IO.puts("   |0⟩ probability: #{Float.round(Enum.at(probs6, 0), 4)}")
IO.puts("   |1⟩ probability: #{Float.round(Enum.at(probs6, 1), 4)}")
IO.puts("")

# Example 7: Getting quantum state directly
IO.puts("7. Direct state access")
state_circuit = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
quantum_state = Qx.get_state(state_circuit)
state_amplitudes = Nx.to_flat_list(quantum_state)

IO.puts("   Raw quantum state amplitudes:")
for i <- 0..3 do
  binary = Integer.to_string(i, 2) |> String.pad_leading(2, "0")
  amplitude = Enum.at(state_amplitudes, i)
  IO.puts("   |#{binary}⟩: #{Float.round(amplitude, 4)}")
end
IO.puts("")

# Example 8: Grover's Algorithm Setup (2-qubit example)
IO.puts("8. Grover's algorithm setup (simplified)")
# This is a simplified version showing the structure
grover_circuit = Qx.create_circuit(2)
                 |> Qx.h(0)     # Initialize superposition
                 |> Qx.h(1)     # Initialize superposition
                 |> Qx.z(0)     # Oracle (marks |00⟩)
                 |> Qx.z(1)     # Oracle continuation
                 |> Qx.h(0)     # Diffuser part
                 |> Qx.h(1)     # Diffuser part
                 |> Qx.x(0)     # Diffuser continuation
                 |> Qx.x(1)     # Diffuser continuation
                 |> Qx.h(1)     # Diffuser
                 |> Qx.cx(0, 1) # Diffuser controlled part
                 |> Qx.h(1)     # Diffuser
                 |> Qx.x(0)     # Diffuser final
                 |> Qx.x(1)     # Diffuser final
                 |> Qx.h(0)     # Final Hadamard
                 |> Qx.h(1)     # Final Hadamard

result8 = Qx.run(grover_circuit)
probs8 = Nx.to_flat_list(result8.probabilities)

IO.puts("   After Grover-like operations:")
for i <- 0..3 do
  binary = Integer.to_string(i, 2) |> String.pad_leading(2, "0")
  prob = Enum.at(probs8, i)
  IO.puts("   |#{binary}⟩ probability: #{Float.round(prob, 4)}")
end
IO.puts("")

IO.puts("=== Library Information ===")
IO.puts("Qx version: #{Qx.version()}")
IO.puts("All examples completed successfully!")
IO.puts("")
IO.puts("Try visualizing results with:")
IO.puts("  result = Qx.run(Qx.bell_state())")
IO.puts("  Qx.draw(result)")
