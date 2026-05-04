# OpenQASM Examples

This directory contains examples for both directions of Qx's OpenQASM 3.0 support:

- **Export** — turning a Qx circuit into OpenQASM source you can run on real
  hardware (IBM Quantum, AWS Braket, …).
- **Import** (since v0.6.0) — loading OpenQASM 3.0 source emitted by Qx,
  Qiskit, or IBM Quantum back into a `Qx.QuantumCircuit`.

## Running the Examples

```bash
# From the qx project root
elixir examples/openqasm/bell_state.exs              # export
elixir examples/openqasm/quantum_teleportation.exs   # export with conditionals
elixir examples/openqasm/grover_search.exs           # export
elixir examples/openqasm/round_trip.exs              # export → import round-trip
elixir examples/openqasm/import_gate_definition.exs  # gate-def → Elixir source
```

## Examples

### Export — `bell_state.exs`
Maximally entangled Bell state exported to OpenQASM 2.0 and 3.0.
Beginner-friendly. **Platforms**: IBM Quantum, AWS Braket, Google Cirq.

### Export — `quantum_teleportation.exs`
Teleportation protocol with mid-circuit measurement and conditional gates.
Requires OpenQASM 3.0. **Platforms**: IBM Quantum (3.0), AWS Braket.

### Export — `grover_search.exs`
Grover's amplitude-amplification algorithm.
**Platforms**: IBM Quantum, AWS Braket.

### Round-trip — `round_trip.exs`
Builds a circuit in Qx, exports to QASM, re-imports with `from_qasm/1`, and
asserts the simulated statevectors match within 1e-10. Also imports a
3-qubit QFT in Qiskit-style source.

### Gate definition codegen — `import_gate_definition.exs`
Parses a `gate name(p) a, b { … }` definition with
`from_qasm_function/1` and `Code.compile_string/1`s the result into a
runnable module. Useful for storing user-supplied gates for later replay.

## Exporting Your Own Circuits

```elixir
circuit =
  Qx.create_circuit(2, 2)
  |> Qx.h(0)
  |> Qx.cx(0, 1)
  |> Qx.measure(0, 0)
  |> Qx.measure(1, 1)

qasm = Qx.Export.OpenQASM.to_qasm(circuit)         # OpenQASM 3.0 (default)
qasm2 = Qx.Export.OpenQASM.to_qasm(circuit, version: 2)
File.write!("my_circuit.qasm", qasm)
```

## Importing OpenQASM 3.0

```elixir
qasm = """
OPENQASM 3.0;
include "stdgates.inc";
qubit[2] q;
bit[2] c;
h q[0];
cx q[0], q[1];
c[0] = measure q[0];
c[1] = measure q[1];
"""

{:ok, circuit} = Qx.Export.OpenQASM.from_qasm(qasm)
result = Qx.run(circuit, shots: 1024)
```

Errors are typed:

- `Qx.QasmParseError` — grammar/syntax problem (`:line`, `:column`, `:snippet`).
- `Qx.QasmUnsupportedError` — valid QASM that uses a feature outside the
  supported subset (multi-register, gate modifiers, `else`, …).

`from_qasm!/1` is the bang variant. `from_qasm_function/1` returns
`%{name, arity, source}` for a single `gate` definition, where `source` is
an Elixir `def name(circuit, params…, qubits…) do … end` string.

## Platform Support (export)

| Platform     | OpenQASM Version | Mid-circuit Measurements | Conditionals |
|--------------|------------------|--------------------------|--------------|
| IBM Quantum  | 2.0, 3.0         | 3.0 only                 | 3.0 only     |
| AWS Braket   | 3.0              | Yes                      | Yes          |
| Google Cirq  | 2.0 (import)     | No                       | No           |
| Rigetti      | 2.0, 3.0         | 3.0 only                 | 3.0 only     |

## Submitting to Quantum Hardware

### IBM Quantum
1. `qasm = Qx.Export.OpenQASM.to_qasm(circuit, version: 3)`
2. Visit [IBM Quantum](https://quantum.cloud.ibm.com/), create a circuit, paste the QASM.
3. Select a backend and run.

### AWS Braket
1. `qasm = Qx.Export.OpenQASM.to_qasm(circuit)`
2. `File.write!("circuit.qasm", qasm)`
3. Submit via the AWS CLI or SDK:
   ```bash
   aws braket create-quantum-task \
     --device-arn arn:aws:braket:us-east-1::device/qpu/ionq/Aria-1 \
     --action-type OPENQASM \
     --shots 100 \
     --output-s3-bucket my-bucket \
     --output-s3-key-prefix results/ \
     --action file://circuit.qasm
   ```

## Supported Gates (Export & Import)

| Category      | Gates |
|---------------|-------|
| Single-qubit  | H, X, Y, Z, S, S† (Sdg), T, RX, RY, RZ, P (Phase), U |
| Two-qubit     | CNOT (CX/CX-uppercase), CZ, SWAP, iSWAP, CP / CPhase |
| Three-qubit   | Toffoli (CCX), Fredkin (CSWAP) |
| Special       | Measurements, Barriers, Conditional operations (3.0) |

Import additionally **decomposes** `tdg`, `sx`, `u1`, `u2` from `stdgates.inc`
and treats `id` as a no-op.

**Import does not support** (raises `Qx.QasmUnsupportedError`):
multi-register programs, gate modifiers (`inv`/`pow`/`ctrl`/`negctrl`), `else`
branches, complex boolean conditions, classical types beyond `bit`,
`def`/`for`/`while`/`switch`, `defcal`, `let`, `pragma`, `extern`, `box`,
`delay`, `reset`, the stdgates `cy/ch/crx/cry/crz/cu`, and the Qiskit
extensions `rxx/ryy/rzz/rzx`.

## Further Resources

- [OpenQASM 3.0 Specification](https://openqasm.com/)
- [IBM Quantum Documentation](https://quantum.cloud.ibm.com/docs/)
- [AWS Braket Documentation](https://docs.aws.amazon.com/braket/)
- [Qx Documentation on HexDocs](https://hexdocs.pm/qx_sim/)
