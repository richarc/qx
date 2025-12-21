# Grover's Search Algorithm - OpenQASM Export Example
#
# This example demonstrates Grover's algorithm for searching an unsorted database.
# This implementation searches for the state |11⟩ in a 2-qubit system.
#
# Run from project root:
#   mix run examples/openqasm/grover_search.exs

# Grover's algorithm for 2 qubits, searching for |11⟩
circuit =
  Qx.create_circuit(2, 2)
  # Initialize superposition
  |> Qx.h(0)
  |> Qx.h(1)
  # Oracle: mark |11⟩ (for simplicity, using CZ gate)
  |> Qx.cz(0, 1)
  # Diffusion operator (inversion about average)
  |> Qx.h(0)
  |> Qx.h(1)
  |> Qx.x(0)
  |> Qx.x(1)
  |> Qx.cz(0, 1)
  |> Qx.x(0)
  |> Qx.x(1)
  |> Qx.h(0)
  |> Qx.h(1)
  # Measure
  |> Qx.measure(0, 0)
  |> Qx.measure(1, 1)

# Export to OpenQASM
qasm = Qx.Export.OpenQASM.to_qasm(circuit)

IO.puts("=== Grover's Search Algorithm - OpenQASM 3.0 ===\n")
IO.puts(qasm)

File.write!("grover_search.qasm", qasm)

IO.puts("\n✓ Saved to grover_search.qasm")

# Simulate to verify
result = Qx.run(circuit, shots: 1000)

IO.puts("\n=== Simulation Results ===")
IO.puts("Expected: High probability of measuring |11⟩ (state 3)")
IO.inspect(result.counts, label: "Measurement counts")

# Calculate success probability
success_count = Map.get(result.counts, "11", 0)
success_prob = success_count / 1000 * 100

IO.puts("\nSuccess probability: #{Float.round(success_prob, 1)}%")
IO.puts("(Ideal: 100% for this simple case)")
