# Quantum Teleportation - OpenQASM Export Example
#
# This example demonstrates quantum teleportation protocol and shows how
# conditional operations are exported to OpenQASM 3.0.
#
# Run from project root:
#   mix run examples/openqasm/quantum_teleportation.exs

# Create quantum teleportation circuit
# Qubit 0: State to teleport (initially |0⟩, but could be any state)
# Qubits 1-2: Bell pair for teleportation
circuit =
  Qx.create_circuit(3, 3)
  # Prepare Bell pair between qubits 1 and 2
  |> Qx.h(1)
  |> Qx.cx(1, 2)
  # Barrier to separate preparation from teleportation protocol
  |> Qx.Operations.barrier([0, 1, 2])
  # Bell measurement on qubits 0 and 1
  |> Qx.cx(0, 1)
  |> Qx.h(0)
  |> Qx.measure(0, 0)
  |> Qx.measure(1, 1)
  # Conditional corrections on qubit 2 based on measurement results
  |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)
  |> Qx.c_if(0, 1, fn c -> Qx.z(c, 2) end)
  # Final measurement to verify
  |> Qx.measure(2, 2)

# Export to OpenQASM 3.0 (required for conditional operations)
qasm = Qx.Export.OpenQASM.to_qasm(circuit, version: 3, include_comments: true)

IO.puts("=== Quantum Teleportation - OpenQASM 3.0 ===\n")
IO.puts(qasm)

# Save to file
File.write!("quantum_teleportation.qasm", qasm)

IO.puts("\n✓ Saved to quantum_teleportation.qasm")
IO.puts("\nNote: This circuit requires OpenQASM 3.0 support due to conditional operations.")
IO.puts("Compatible with: IBM Quantum (OpenQASM 3.0), AWS Braket")

# Try to export to v2 (should fail)
IO.puts("\n=== Attempting OpenQASM 2.0 export (will fail) ===")

try do
  Qx.Export.OpenQASM.to_qasm(circuit, version: 2)
  IO.puts("Unexpectedly succeeded!")
rescue
  e in Qx.ConditionalError ->
    IO.puts("✓ Correctly rejected: #{e.message}")
end
