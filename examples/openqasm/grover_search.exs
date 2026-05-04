# Grover's Search Algorithm - OpenQASM Export Example
#
# Demonstrates Grover's algorithm searching for the state |11⟩ in a 2-qubit
# system. This is a complete Grover iteration: state preparation, oracle,
# diffuser. For N = 4 basis states a single iteration yields the marked
# state with probability 1 — the optimal iteration count is
# round((π/4)·√N) which evaluates to 1 here.
#
# To search for a different basis state, change ONLY the oracle block:
#
#   |11⟩  → cz q[0], q[1];
#   |10⟩  → x q[1]; cz q[0], q[1]; x q[1];
#   |01⟩  → x q[0]; cz q[0], q[1]; x q[0];
#   |00⟩  → x q[0]; x q[1]; cz q[0], q[1]; x q[1]; x q[0];
#
# Run from project root:
#   mix run examples/openqasm/grover_search.exs

# Grover's algorithm for 2 qubits, searching for |11⟩.
circuit =
  Qx.create_circuit(2, 2)
  # Step 1 — State preparation: uniform superposition of all 4 basis states.
  |> Qx.h(0)
  |> Qx.h(1)
  # Step 2 — Oracle marking |11⟩ by phase flip. CZ is the canonical oracle
  # for this target on two qubits: it flips the phase iff both qubits are
  # |1⟩. (This is the actual oracle, not a simplification.)
  |> Qx.cz(0, 1)
  # Step 3 — Diffuser (inversion about the mean). The H–X–CZ–X–H sandwich
  # implements 2|s⟩⟨s|−I (up to a global phase) where |s⟩ is the uniform
  # superposition. The diffuser shape is independent of the marked state;
  # only the oracle in step 2 changes for a different target.
  |> Qx.h(0)
  |> Qx.h(1)
  |> Qx.x(0)
  |> Qx.x(1)
  |> Qx.cz(0, 1)
  |> Qx.x(0)
  |> Qx.x(1)
  |> Qx.h(0)
  |> Qx.h(1)
  # Step 4 — Measure both qubits.
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

# Calculate success probability. `result.counts` is keyed by a list of
# classical bits in declaration order — `[c[0], c[1]]` — so |11⟩ is
# `[1, 1]`, not the string "11".
success_count = Map.get(result.counts, [1, 1], 0)
success_prob = success_count / 1000 * 100

IO.puts("\nSuccess probability: #{Float.round(success_prob, 1)}%")
IO.puts("(Ideal: 100% for this simple case)")
