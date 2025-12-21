# Bell State Circuit - OpenQASM Export Example
#
# This example demonstrates how to create a Bell state (maximally entangled state)
# and export it to OpenQASM format for execution on real quantum hardware.
#
# Run from project root:
#   mix run examples/openqasm/bell_state.exs
#
# Or run standalone:
#   cd examples/openqasm && elixir -S mix run bell_state.exs

# Create a Bell state circuit
circuit =
  Qx.create_circuit(2, 2)
  |> Qx.h(0)
  |> Qx.cx(0, 1)
  |> Qx.measure(0, 0)
  |> Qx.measure(1, 1)

# Export to OpenQASM 3.0 (default)
qasm3 = Qx.Export.OpenQASM.to_qasm(circuit)

IO.puts("=== Bell State - OpenQASM 3.0 ===\n")
IO.puts(qasm3)

# Export to OpenQASM 2.0 for broader compatibility
qasm2 = Qx.Export.OpenQASM.to_qasm(circuit, version: 2)

IO.puts("\n=== Bell State - OpenQASM 2.0 ===\n")
IO.puts(qasm2)

# Save to file for submission to quantum hardware
File.write!("bell_state_v3.qasm", qasm3)
File.write!("bell_state_v2.qasm", qasm2)

IO.puts("\n✓ QASM files saved:")
IO.puts("  - bell_state_v3.qasm (OpenQASM 3.0)")
IO.puts("  - bell_state_v2.qasm (OpenQASM 2.0)")

# Simulate locally to verify
result = Qx.run(circuit, shots: 1000)

IO.puts("\n=== Local Simulation Results ===")
IO.puts("Expected outcomes: |00⟩ and |11⟩ with ~50% probability each")
IO.inspect(result.counts, label: "Measurement counts")
