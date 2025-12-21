# OpenQASM Export Examples

This directory contains examples demonstrating how to use Qx's OpenQASM exporter to generate quantum circuits that can be executed on real quantum hardware.

## Running the Examples

```bash
# From the qx project root directory
elixir examples/openqasm/bell_state.exs
elixir examples/openqasm/quantum_teleportation.exs
elixir examples/openqasm/grover_search.exs
```

## Examples

### 1. Bell State (`bell_state.exs`)

Creates a maximally entangled Bell state and exports it to both OpenQASM 2.0 and 3.0 formats.

- **Platforms**: IBM Quantum, AWS Braket, Google Cirq
- **Features**: Basic gates, measurements
- **Difficulty**: Beginner

### 2. Quantum Teleportation (`quantum_teleportation.exs`)

Implements the quantum teleportation protocol with conditional operations.

- **Platforms**: IBM Quantum (OpenQASM 3.0), AWS Braket
- **Features**: Conditional operations, barriers, mid-circuit measurements
- **Difficulty**: Intermediate
- **Note**: Requires OpenQASM 3.0 support

### 3. Grover's Search (`grover_search.exs`)

Demonstrates Grover's algorithm for searching an unsorted database.

- **Platforms**: IBM Quantum, AWS Braket
- **Features**: Multi-qubit gates, amplitude amplification
- **Difficulty**: Intermediate

## Exporting Your Own Circuits

```elixir
# Create a circuit
circuit = Qx.create_circuit(2, 2)
  |> Qx.h(0)
  |> Qx.cx(0, 1)
  |> Qx.measure(0, 0)
  |> Qx.measure(1, 1)

# Export to OpenQASM 3.0 (default)
qasm = Qx.Export.OpenQASM.to_qasm(circuit)

# Export to OpenQASM 2.0 for broader compatibility
qasm2 = Qx.Export.OpenQASM.to_qasm(circuit, version: 2)

# Save to file
File.write!("my_circuit.qasm", qasm)
```

## Platform Support

| Platform | OpenQASM Version | Mid-circuit Measurements | Conditionals |
|----------|-----------------|-------------------------|--------------|
| IBM Quantum | 2.0, 3.0 | 3.0 only | 3.0 only |
| AWS Braket | 3.0 | Yes | Yes |
| Google Cirq | 2.0 (import) | No | No |
| Rigetti | 2.0, 3.0 | 3.0 only | 3.0 only |

## Submitting to Quantum Hardware

### IBM Quantum

1. Export your circuit: `qasm = Qx.Export.OpenQASM.to_qasm(circuit, version: 3)`
2. Visit [IBM Quantum](https://quantum.cloud.ibm.com/)
3. Create a new circuit and paste the QASM code
4. Select a backend and run

### AWS Braket

1. Export your circuit: `qasm = Qx.Export.OpenQASM.to_qasm(circuit)`
2. Save to file: `File.write!("circuit.qasm", qasm)`
3. Use AWS CLI or SDK to submit:
   ```bash
   aws braket create-quantum-task \
     --device-arn arn:aws:braket:us-east-1::device/qpu/ionq/Aria-1 \
     --action-type OPENQASM \
     --shots 100 \
     --output-s3-bucket my-bucket \
     --output-s3-key-prefix results/ \
     --action file://circuit.qasm
   ```

## Supported Gates

- **Single-qubit**: H, X, Y, Z, S, T, RX, RY, RZ, Phase
- **Two-qubit**: CNOT (CX), CZ
- **Three-qubit**: Toffoli (CCX)
- **Special**: Measurements, Barriers, Conditional operations (v3.0)

## Further Resources

- [OpenQASM 3.0 Specification](https://openqasm.com/)
- [IBM Quantum Documentation](https://quantum.cloud.ibm.com/docs/)
- [AWS Braket Documentation](https://docs.aws.amazon.com/braket/)
- [Qx Documentation](https://hexdocs.pm/qx/)
