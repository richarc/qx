// Deutsch-Jozsa for f(x) = x[0] (constant?) on 3 qubits.
// Sourced from common Qiskit/IBM Quantum tutorial form.
OPENQASM 3.0;
include "stdgates.inc";
qubit[3] q;
bit[2] c;

// Prepare |0..0>|1>
x q[2];
h q[0];
h q[1];
h q[2];

// Oracle: balanced f(x) = x[0]
cx q[0], q[2];

// Disentangle ancilla
h q[0];
h q[1];

// Measure first two qubits
c[0] = measure q[0];
c[1] = measure q[1];
