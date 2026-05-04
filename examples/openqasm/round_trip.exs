# OpenQASM Round-Trip Example
#
# Demonstrates `Qx.Export.OpenQASM.from_qasm/1` parsing OpenQASM 3.0 source
# back into a `Qx.QuantumCircuit` that simulates to the same statevector as
# the original.
#
# Run with:  elixir examples/openqasm/round_trip.exs

alias Qx.Export.OpenQASM
alias Qx.Simulation

# 1. Build a Bell-state circuit in Qx.
original =
  Qx.create_circuit(2, 2)
  |> Qx.h(0)
  |> Qx.cx(0, 1)

IO.puts("Original circuit instructions:")
IO.inspect(original.instructions)

# 2. Export it to OpenQASM 3.0 source.
qasm = OpenQASM.to_qasm(original)
IO.puts("\n--- OpenQASM 3.0 source ---")
IO.puts(qasm)

# 3. Re-import the QASM and confirm the round-trip is loss-free.
{:ok, reimported} = OpenQASM.from_qasm(qasm)
IO.puts("--- Reimported circuit instructions ---")
IO.inspect(reimported.instructions)

# 4. Simulate both and compare statevectors. Within numerical tolerance the
#    state should be identical.
original_state = Simulation.get_state(original)
reimported_state = Simulation.get_state(reimported)

max_abs_diff =
  original_state
  |> Nx.subtract(reimported_state)
  |> Nx.abs()
  |> Nx.reduce_max()
  |> Nx.to_number()

IO.puts("\nMax |Δ amplitude|: #{max_abs_diff}")

if max_abs_diff < 1.0e-10 do
  IO.puts("Round-trip statevector match: OK")
else
  IO.puts("Round-trip statevector mismatch — investigate")
end

# 5. Same trick with a Qiskit-style program — paste any `OPENQASM 3.0;`
#    source, including programs from IBM Quantum or Qiskit's QASM3 export.
qiskit_style_qasm = """
OPENQASM 3.0;
include "stdgates.inc";
qubit[3] q;
bit[3] c;
h q[0];
cp(pi/2) q[1], q[0];
cp(pi/4) q[2], q[0];
h q[1];
cp(pi/2) q[2], q[1];
h q[2];
swap q[0], q[2];
"""

case OpenQASM.from_qasm(qiskit_style_qasm) do
  {:ok, qft_circuit} ->
    IO.puts("\nImported a 3-qubit QFT — #{length(qft_circuit.instructions)} instructions.")

  {:error, exception} ->
    IO.puts("Import failed: #{Exception.message(exception)}")
end
