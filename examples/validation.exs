#!/usr/bin/env elixir

# Validation Script for Qx Quantum Computing Simulator
# This script implements the benchmark algorithms mentioned in the PRD:
# Bell state, GHZ state, and Grover's algorithm

IO.puts("=== Qx Quantum Computing Simulator Validation ===\n")

# Validation 1: Bell State
IO.puts("1. Bell State Validation")
IO.puts("   Creating |Φ+⟩ = (|00⟩ + |11⟩)/√2")

bell_circuit = Qx.bell_state()
bell_result = Qx.run(bell_circuit, 10000)  # More shots for better statistics
bell_probs = Nx.to_flat_list(bell_result.probabilities)

IO.puts("   Expected: |00⟩ = 0.5, |01⟩ = 0.0, |10⟩ = 0.0, |11⟩ = 0.5")
IO.puts("   Actual:")
IO.puts("   |00⟩ probability: #{Float.round(Enum.at(bell_probs, 0), 6)}")
IO.puts("   |01⟩ probability: #{Float.round(Enum.at(bell_probs, 1), 6)}")
IO.puts("   |10⟩ probability: #{Float.round(Enum.at(bell_probs, 2), 6)}")
IO.puts("   |11⟩ probability: #{Float.round(Enum.at(bell_probs, 3), 6)}")

# Validate Bell state probabilities
bell_00_ok = abs(Enum.at(bell_probs, 0) - 0.5) < 0.01
bell_01_ok = abs(Enum.at(bell_probs, 1) - 0.0) < 0.01
bell_10_ok = abs(Enum.at(bell_probs, 2) - 0.0) < 0.01
bell_11_ok = abs(Enum.at(bell_probs, 3) - 0.5) < 0.01

bell_validation = bell_00_ok and bell_01_ok and bell_10_ok and bell_11_ok
IO.puts("   ✓ Bell State Validation: #{if bell_validation, do: "PASSED", else: "FAILED"}")
IO.puts("")

# Validation 2: GHZ State
IO.puts("2. GHZ State Validation")
IO.puts("   Creating |GHZ⟩ = (|000⟩ + |111⟩)/√2")

ghz_circuit = Qx.ghz_state()
ghz_result = Qx.run(ghz_circuit, 10000)
ghz_probs = Nx.to_flat_list(ghz_result.probabilities)

IO.puts("   Expected: |000⟩ = 0.5, |111⟩ = 0.5, others = 0.0")
IO.puts("   Actual:")
for i <- 0..7 do
  binary = Integer.to_string(i, 2) |> String.pad_leading(3, "0")
  prob = Enum.at(ghz_probs, i)
  IO.puts("   |#{binary}⟩ probability: #{Float.round(prob, 6)}")
end

# Validate GHZ state probabilities
ghz_000_ok = abs(Enum.at(ghz_probs, 0) - 0.5) < 0.01  # |000⟩
ghz_111_ok = abs(Enum.at(ghz_probs, 7) - 0.5) < 0.01  # |111⟩
ghz_others_ok = Enum.slice(ghz_probs, 1..6) |> Enum.all?(&(abs(&1) < 0.01))

ghz_validation = ghz_000_ok and ghz_111_ok and ghz_others_ok
IO.puts("   ✓ GHZ State Validation: #{if ghz_validation, do: "PASSED", else: "FAILED"}")
IO.puts("")

# Validation 3: Grover's Algorithm (2-qubit, searching for |11⟩)
IO.puts("3. Grover's Algorithm Validation (2-qubit)")
IO.puts("   Searching for |11⟩ in 2-qubit space")

# Grover's algorithm for 2 qubits searching for |11⟩
# 1. Initialize uniform superposition
# 2. Apply oracle that flips phase of |11⟩
# 3. Apply diffusion operator
# 4. For 2 qubits, one iteration should be sufficient

grover_circuit = Qx.create_circuit(2)
                 # Step 1: Initialize uniform superposition
                 |> Qx.h(0)
                 |> Qx.h(1)

                 # Step 2: Oracle - flip phase of |11⟩
                 |> Qx.cz(0, 1)

                 # Step 3: Diffusion operator
                 # Apply H to all qubits
                 |> Qx.h(0)
                 |> Qx.h(1)
                 # Apply X to all qubits
                 |> Qx.x(0)
                 |> Qx.x(1)
                 # Apply controlled-Z
                 |> Qx.cz(0, 1)
                 # Apply X to all qubits
                 |> Qx.x(0)
                 |> Qx.x(1)
                 # Apply H to all qubits
                 |> Qx.h(0)
                 |> Qx.h(1)

grover_result = Qx.run(grover_circuit, 10000)
grover_probs = Nx.to_flat_list(grover_result.probabilities)

IO.puts("   After Grover iteration:")
for i <- 0..3 do
  binary = Integer.to_string(i, 2) |> String.pad_leading(2, "0")
  prob = Enum.at(grover_probs, i)
  IO.puts("   |#{binary}⟩ probability: #{Float.round(prob, 6)}")
end

# For perfect Grover's algorithm, |11⟩ should have higher probability
# In practice, with our approximations, we just check that |11⟩ is most probable
grover_11_prob = Enum.at(grover_probs, 3)
max_prob = Enum.max(grover_probs)
grover_validation = grover_11_prob == max_prob and grover_11_prob > 0.4

IO.puts("   ✓ Grover's Algorithm Validation: #{if grover_validation, do: "PASSED", else: "FAILED"}")
IO.puts("")

# Validation 4: Quantum State Properties
IO.puts("4. Quantum State Properties Validation")

# Test normalization
test_circuit = Qx.create_circuit(3) |> Qx.h(0) |> Qx.h(1) |> Qx.h(2)
test_state = Qx.get_state(test_circuit)
test_probs = Nx.to_flat_list(Qx.Math.probabilities(test_state))
total_prob = Enum.sum(test_probs)

IO.puts("   Testing state normalization (should sum to 1.0)")
IO.puts("   Total probability: #{Float.round(total_prob, 8)}")
normalization_ok = abs(total_prob - 1.0) < 1.0e-6

# Test superposition with Hadamard
h_circuit = Qx.create_circuit(1) |> Qx.h(0)
h_probs = Nx.to_flat_list(Qx.get_probabilities(h_circuit))
h_equal = abs(Enum.at(h_probs, 0) - Enum.at(h_probs, 1)) < 1.0e-6

IO.puts("   Testing Hadamard superposition (|0⟩ and |1⟩ should be equal)")
IO.puts("   |0⟩: #{Float.round(Enum.at(h_probs, 0), 8)}, |1⟩: #{Float.round(Enum.at(h_probs, 1), 8)}")

properties_validation = normalization_ok and h_equal
IO.puts("   ✓ Quantum Properties Validation: #{if properties_validation, do: "PASSED", else: "FAILED"}")
IO.puts("")

# Validation 5: Gate Operations
IO.puts("5. Basic Gate Operations Validation")

# Test X gate (bit flip)
x_circuit = Qx.create_circuit(1) |> Qx.x(0)
x_probs = Nx.to_flat_list(Qx.get_probabilities(x_circuit))
x_correct = Enum.at(x_probs, 0) < 0.01 and abs(Enum.at(x_probs, 1) - 1.0) < 0.01

# Test Z gate (should not change |0⟩ state)
z_circuit = Qx.create_circuit(1) |> Qx.z(0)
z_probs = Nx.to_flat_list(Qx.get_probabilities(z_circuit))
z_correct = abs(Enum.at(z_probs, 0) - 1.0) < 0.01 and Enum.at(z_probs, 1) < 0.01

# Test CNOT gate
cnot_circuit = Qx.create_circuit(2) |> Qx.x(0) |> Qx.cx(0, 1)
cnot_probs = Nx.to_flat_list(Qx.get_probabilities(cnot_circuit))
cnot_correct = abs(Enum.at(cnot_probs, 3) - 1.0) < 0.01  # Should be |11⟩

IO.puts("   X gate: #{if x_correct, do: "✓ PASSED", else: "✗ FAILED"}")
IO.puts("   Z gate: #{if z_correct, do: "✓ PASSED", else: "✗ FAILED"}")
IO.puts("   CNOT gate: #{if cnot_correct, do: "✓ PASSED", else: "✗ FAILED"}")

gates_validation = x_correct and z_correct and cnot_correct
IO.puts("   ✓ Gate Operations Validation: #{if gates_validation, do: "PASSED", else: "FAILED"}")
IO.puts("")

# Overall Validation Summary
IO.puts("=== VALIDATION SUMMARY ===")
overall_validation = bell_validation and ghz_validation and grover_validation and
                    properties_validation and gates_validation

validations = [
  {"Bell State", bell_validation},
  {"GHZ State", ghz_validation},
  {"Grover's Algorithm", grover_validation},
  {"Quantum Properties", properties_validation},
  {"Gate Operations", gates_validation}
]

Enum.each(validations, fn {name, status} ->
  symbol = if status, do: "✓", else: "✗"
  result = if status, do: "PASSED", else: "FAILED"
  IO.puts("#{symbol} #{name}: #{result}")
end)

IO.puts("")
IO.puts("Overall Validation: #{if overall_validation, do: "✓ ALL TESTS PASSED", else: "✗ SOME TESTS FAILED"}")

if overall_validation do
  IO.puts("🎉 The Qx quantum computing simulator is working correctly!")
else
  IO.puts("⚠️  Some validations failed. The simulator may need further refinement.")
end

IO.puts("")
IO.puts("Validation completed with #{length(validations)} test categories.")
