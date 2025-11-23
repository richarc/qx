
# Reproduction script for controlled gate bug
Nx.default_backend(Nx.BinaryBackend)
alias Qx.Gates
alias Qx.Qubit
alias Nx

# Test CNOT
# Expected: |10> (control=1, target=0) -> |11>
# |11> -> |10>

# Create CNOT matrix
cnot = Gates.cnot(0, 1, 2)

# Input |10> (q0=1, q1=0) -> Index 1 (binary 01? Wait. q0 is LSB?)
# If q0 is LSB, |10> means q1=1, q0=0. Index 2.
# If q0 is control, q0=0 -> Identity.
# So |10> -> |10>.

# Let's clarify qubit ordering.
# Qx.Format.basis_state(1, 2) -> "|01>".
# 1 in binary is 01.
# Usually rightmost is LSB (q0).
# So |01> means q1=0, q0=1.
# If q0 is control, q0=1. Target q1 (0) should flip to 1.
# So |01> -> |11> (Index 3).

# Let's check the matrix element M[3, 1].
# And M[1, 1] (should be 0).

IO.puts("Checking CNOT matrix elements...")
m11 = cnot[1][1] |> Nx.to_number() # Should be 0
m31 = cnot[3][1] |> Nx.to_number() # Should be 1

IO.puts("M[1, 1] (should be 0): #{m11}")
IO.puts("M[3, 1] (should be 1): #{m31}")

if m11 != 0 do
  IO.puts("BUG DETECTED: Diagonal element M[1, 1] is not 0!")
end

# Check Controlled-Z
# CZ(0, 1). Control q0, Target q1.
# |11> (Index 3) -> -|11>.
# M[3, 3] should be -1.

cz = Gates.controlled_gate(Gates.pauli_z(), 0, 1, 2)
m33 = cz[3][3] |> Nx.to_number()
IO.puts("Checking CZ matrix elements...")
IO.puts("M[3, 3] (should be -1): #{m33}")

if m33 != -1 do
  IO.puts("BUG DETECTED: CZ element M[3, 3] is not -1!")
end
