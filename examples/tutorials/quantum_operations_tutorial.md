# Quantum Operations and Gates: A Tutorial with Qx Simulator

## Introduction

This tutorial provides a comprehensive introduction to quantum operations and gates, covering both the theoretical foundations and practical implementation using the Qx quantum simulator for Elixir. We'll explore how quantum gates manipulate qubit states and how they're represented mathematically.

## Table of Contents

1. [Fundamental Theory of Quantum Operators](#fundamental-theory-of-quantum-operators)
2. [Pauli Gates](#pauli-gates)
3. [Pauli Gates and the Bloch Sphere](#pauli-gates-and-the-bloch-sphere)
4. [Two-Qubit Gates](#two-qubit-gates)
5. [Practical Examples with Qx](#practical-examples-with-qx)

---

## 1. Fundamental Theory of Quantum Operators

### 1.1 Quantum States

A single qubit exists in a quantum state that can be represented as a linear combination of two basis states $|0\rangle$ and $|1\rangle$:

$$|\psi\rangle = \alpha|0\rangle + \beta|1\rangle$$

where $\alpha$ and $\beta$ are complex numbers called probability amplitudes, and they must satisfy the normalization condition:

$$|\alpha|^2 + |\beta|^2 = 1$$

The computational basis states are represented as column vectors:

$$|0\rangle = \begin{pmatrix} 1 \\ 0 \end{pmatrix}, \quad |1\rangle = \begin{pmatrix} 0 \\ 1 \end{pmatrix}$$

### 1.2 Quantum Operators as Matrices

Quantum gates are represented by unitary matrices that transform quantum states. A unitary matrix $U$ satisfies:

$$U^\dagger U = U U^\dagger = I$$

where $U^\dagger$ is the conjugate transpose of $U$ and $I$ is the identity matrix.

For a single qubit, gates are $2 \times 2$ unitary matrices. When a gate $U$ is applied to a state $|\psi\rangle$, the resulting state is:

$$|\psi'\rangle = U|\psi\rangle$$

### 1.3 Properties of Quantum Gates

**Reversibility**: Since quantum gates are unitary, they are always reversible. For any gate $U$, there exists an inverse gate $U^{-1} = U^\dagger$.

**Preservation of Normalization**: Unitary operations preserve the normalization of quantum states. If $|\psi\rangle$ is normalized, then $U|\psi\rangle$ is also normalized.

**Example with Qx - Creating and Inspecting States**:

```elixir
# Using Qx's Calculation Mode to explore quantum states
alias Qx.Qubit

# Create a qubit in |0⟩ state
q0 = Qubit.new()
Qubit.show_state(q0)
# Output: %{state: "1.000|0⟩ + 0.000|1⟩", ...}

# Create a custom superposition state
# |ψ⟩ = (1/√2)|0⟩ + (1/√2)|1⟩
alpha = 1 / :math.sqrt(2)
beta = 1 / :math.sqrt(2)
q_super = Qubit.new(alpha, beta)
Qubit.show_state(q_super)
# Output: %{state: "0.707|0⟩ + 0.707|1⟩", ...}

# Verify normalization
probs = Qubit.measure_probabilities(q_super)
# [0.5, 0.5] - probabilities sum to 1.0
```

---

## 2. Pauli Gates

The Pauli gates are fundamental single-qubit gates named after physicist Wolfgang Pauli. They form the basis for many quantum operations.

### 2.1 Pauli-X Gate (Bit Flip)

The Pauli-X gate flips the computational basis states:

$$X = \begin{pmatrix} 0 & 1 \\ 1 & 0 \end{pmatrix}$$

**Action**:
- $X|0\rangle = |1\rangle$
- $X|1\rangle = |0\rangle$

This is the quantum analogue of the classical NOT gate.

**Qx Example**:

```elixir
# Circuit Mode
qc = Qx.create_circuit(1)
  |> Qx.x(0)

state = Qx.get_state(qc)
# State vector: [0, 1] representing |1⟩

# Calculation Mode - Apply gate in real-time
q = Qubit.new()  # Start with |0⟩
  |> Qubit.x()   # Apply X gate

Qubit.show_state(q)
# Output: %{state: "0.000|0⟩ + 1.000|1⟩", ...}
# The state is now |1⟩
```

### 2.2 Pauli-Y Gate

The Pauli-Y gate combines a bit flip with a phase flip:

$$Y = \begin{pmatrix} 0 & -i \\ i & 0 \end{pmatrix}$$

**Action**:
- $Y|0\rangle = i|1\rangle$
- $Y|1\rangle = -i|0\rangle$

**Qx Example**:

```elixir
# Circuit Mode
qc = Qx.create_circuit(1)
  |> Qx.y(0)

state = Qx.get_state(qc)
# State vector contains complex numbers [0, i]

# Calculation Mode
q = Qubit.new()
  |> Qubit.y()

Qubit.show_state(q)
# Output shows: "0.000|0⟩ + 1.000i|1⟩"
# Note the imaginary component
```

### 2.3 Pauli-Z Gate (Phase Flip)

The Pauli-Z gate applies a phase flip to the $|1\rangle$ state:

$$Z = \begin{pmatrix} 1 & 0 \\ 0 & -1 \end{pmatrix}$$

**Action**:
- $Z|0\rangle = |0\rangle$
- $Z|1\rangle = -|1\rangle$

The Z gate is crucial for quantum algorithms as it introduces relative phase between basis states.

**Qx Example**:

```elixir
# Circuit Mode - Z on superposition
qc = Qx.create_circuit(1)
  |> Qx.h(0)  # Create superposition: (|0⟩ + |1⟩)/√2
  |> Qx.z(0)  # Apply phase flip

state = Qx.get_state(qc)
# State: (|0⟩ - |1⟩)/√2 - note the minus sign

# Calculation Mode - Observe phase change
q = Qubit.new()
  |> Qubit.h()
  
Qubit.show_state(q)
# Before Z: "0.707|0⟩ + 0.707|1⟩"

q = q |> Qubit.z()
Qubit.show_state(q)
# After Z: "0.707|0⟩ - 0.707|1⟩"
```

### 2.4 Properties of Pauli Gates

**Self-Inverse**: All Pauli gates are their own inverse:
$$X^2 = Y^2 = Z^2 = I$$

**Anti-Commutation**: Pauli gates anti-commute:
$$XY = -YX, \quad YZ = -ZY, \quad ZX = -XZ$$

**Eigenvalues**: Each Pauli gate has eigenvalues $+1$ and $-1$.

**Qx Example - Self-Inverse Property**:

```elixir
# Applying X twice returns to original state
q = Qubit.new()
  |> Qubit.x()
  |> Qubit.x()

Qubit.show_state(q)
# Output: "1.000|0⟩ + 0.000|1⟩" - back to |0⟩
```

---

## 3. Pauli Gates and the Bloch Sphere

### 3.1 The Bloch Sphere Representation

The Bloch sphere is a geometric representation of a single qubit's state. Any pure qubit state can be written as:

$$|\psi\rangle = \cos\left(\frac{\theta}{2}\right)|0\rangle + e^{i\phi}\sin\left(\frac{\theta}{2}\right)|1\rangle$$

where:
- $\theta \in [0, \pi]$ is the polar angle
- $\phi \in [0, 2\pi]$ is the azimuthal angle

The qubit state maps to a point on a unit sphere in 3D space with coordinates:

$$\vec{r} = (\sin\theta\cos\phi, \sin\theta\sin\phi, \cos\theta)$$

### 3.2 Pauli Gates as Rotations

The Pauli gates can be interpreted as $\pi$ rotations about different axes of the Bloch sphere:

**Pauli-X**: Rotation by $\pi$ around the X-axis
$$X = e^{-i\frac{\pi}{2}\sigma_x}$$

**Pauli-Y**: Rotation by $\pi$ around the Y-axis
$$Y = e^{-i\frac{\pi}{2}\sigma_y}$$

**Pauli-Z**: Rotation by $\pi$ around the Z-axis
$$Z = e^{-i\frac{\pi}{2}\sigma_z}$$

### 3.3 Visualizing Pauli Gates on the Bloch Sphere

**State Positions**:
- $|0\rangle$: North pole $(0, 0, 1)$
- $|1\rangle$: South pole $(0, 0, -1)$
- $|+\rangle = \frac{1}{\sqrt{2}}(|0\rangle + |1\rangle)$: Positive X-axis $(1, 0, 0)$
- $|-\rangle = \frac{1}{\sqrt{2}}(|0\rangle - |1\rangle)$: Negative X-axis $(-1, 0, 0)$
- $|i\rangle = \frac{1}{\sqrt{2}}(|0\rangle + i|1\rangle)$: Positive Y-axis $(0, 1, 0)$
- $|-i\rangle = \frac{1}{\sqrt{2}}(|0\rangle - i|1\rangle)$: Negative Y-axis $(0, -1, 0)$

**Qx Example - Creating States and Visualizing on Bloch Sphere**:

```elixir
# Create |+⟩ state (X-axis of Bloch sphere)
q_plus = Qubit.plus()
Qx.draw_bloch(q_plus, title: "|+⟩ State")

# Create |-⟩ state
q_minus = Qubit.minus()
Qx.draw_bloch(q_minus, title: "|-⟩ State")

# Create custom state from Bloch coordinates
# θ = π/2, φ = 0 gives |+⟩
theta = :math.pi() / 2
phi = 0
q_bloch = Qubit.from_bloch(theta, phi)
Qubit.show_state(q_bloch)

# Apply X gate and visualize rotation
q = Qubit.new()  # Start at north pole
  |> Qubit.x()   # Rotate to south pole

Qx.draw_bloch(q, title: "After X Gate")
```

### 3.4 Common State Transformations

**X Gate Effect**:
```elixir
# |0⟩ → |1⟩ (North to South pole)
q = Qubit.new() |> Qubit.x()

# |+⟩ → |+⟩ (No change, eigenstate)
q = Qubit.plus() |> Qubit.x()

# |-⟩ → -|-⟩ (Phase flip, still on negative X-axis)
q = Qubit.minus() |> Qubit.x()
```

**Z Gate Effect**:
```elixir
# |0⟩ → |0⟩ (No change, eigenstate)
q = Qubit.new() |> Qubit.z()

# |1⟩ → -|1⟩ (Phase flip, still at south pole)
q = Qubit.one() |> Qubit.z()

# |+⟩ → |-⟩ (Flip from positive to negative X-axis)
q = Qubit.plus() |> Qubit.z()
Qubit.show_state(q)
# Output: "0.707|0⟩ - 0.707|1⟩" which is |-⟩
```

### 3.5 Rotation Gates (General Case)

The general rotation gates are parametrized versions of Pauli rotations:

**RX (Rotation around X-axis)**:
$$R_X(\theta) = e^{-i\frac{\theta}{2}X} = \begin{pmatrix} \cos(\frac{\theta}{2}) & -i\sin(\frac{\theta}{2}) \\ -i\sin(\frac{\theta}{2}) & \cos(\frac{\theta}{2}) \end{pmatrix}$$

**RY (Rotation around Y-axis)**:
$$R_Y(\theta) = e^{-i\frac{\theta}{2}Y} = \begin{pmatrix} \cos(\frac{\theta}{2}) & -\sin(\frac{\theta}{2}) \\ \sin(\frac{\theta}{2}) & \cos(\frac{\theta}{2}) \end{pmatrix}$$

**RZ (Rotation around Z-axis)**:
$$R_Z(\theta) = e^{-i\frac{\theta}{2}Z} = \begin{pmatrix} e^{-i\frac{\theta}{2}} & 0 \\ 0 & e^{i\frac{\theta}{2}} \end{pmatrix}$$

**Qx Example - Parametrized Rotations**:

```elixir
# Rotate by π/4 around X-axis
q = Qubit.new()
  |> Qubit.rx(:math.pi() / 4)

Qubit.show_state(q)
Qx.draw_bloch(q, title: "RX(π/4)")

# Create superposition using RY(π/2)
q = Qubit.new()
  |> Qubit.ry(:math.pi() / 2)

# This creates (|0⟩ + |1⟩)/√2, equivalent to H gate on |0⟩

# Combine rotations to reach any point on Bloch sphere
q = Qubit.new()
  |> Qubit.ry(:math.pi() / 3)
  |> Qubit.rz(:math.pi() / 4)

Qx.draw_bloch(q, title: "RY(π/3) then RZ(π/4)")
```

---

## 4. Two-Qubit Gates

Two-qubit gates create entanglement and enable quantum computation beyond what's possible with single qubits alone.

### 4.1 Controlled-NOT (CNOT/CX) Gate

The CNOT gate is the most important two-qubit gate. It flips the target qubit if and only if the control qubit is $|1\rangle$.

**Matrix Representation** (in computational basis $\{|00\rangle, |01\rangle, |10\rangle, |11\rangle\}$):

$$\text{CNOT} = \begin{pmatrix} 
1 & 0 & 0 & 0 \\
0 & 1 & 0 & 0 \\
0 & 0 & 0 & 1 \\
0 & 0 & 1 & 0
\end{pmatrix}$$

**Action**:
- $\text{CNOT}|00\rangle = |00\rangle$
- $\text{CNOT}|01\rangle = |01\rangle$
- $\text{CNOT}|10\rangle = |11\rangle$
- $\text{CNOT}|11\rangle = |10\rangle$

In general: $\text{CNOT}|c,t\rangle = |c, t \oplus c\rangle$ where $\oplus$ is XOR.

**Creating Bell States with CNOT**:

The Bell states are maximally entangled two-qubit states. The most famous is:

$$|\Phi^+\rangle = \frac{1}{\sqrt{2}}(|00\rangle + |11\rangle)$$

Created by applying Hadamard to the first qubit, then CNOT:

```elixir
# Circuit Mode - Bell State
bell_circuit = Qx.create_circuit(2)
  |> Qx.h(0)     # Create superposition on control
  |> Qx.cx(0, 1) # Entangle with target

state = Qx.get_state(bell_circuit)
probs = Qx.get_probabilities(bell_circuit)

# The state is now (|00⟩ + |11⟩)/√2
# Probabilities: 50% for |00⟩, 0% for |01⟩, 0% for |10⟩, 50% for |11⟩

# Using the convenience function
bell_circuit = Qx.bell_state()
result = Qx.run(bell_circuit, 1000)
Qx.draw_counts(result)
```

**Calculation Mode - Bell State**:

```elixir
alias Qx.Register

# Create a 2-qubit register
reg = Register.new(2)
  |> Register.h(0)      # Hadamard on qubit 0
  |> Register.cx(0, 1)  # CNOT from qubit 0 to 1

Register.show_state(reg)
# Output shows: "0.707|00⟩ + 0.707|11⟩"

# Check probabilities
probs = Register.get_probabilities(reg)
# Shows equal probability for |00⟩ and |11⟩, zero for |01⟩ and |10⟩
```

### 4.2 Understanding Entanglement

After applying CNOT to create a Bell state, the two qubits are entangled. This means:

1. **Correlation**: Measuring one qubit immediately determines the other
2. **No Individual State**: Neither qubit has a definite state on its own
3. **Non-local**: The correlation exists regardless of spatial separation

**Qx Example - Demonstrating Entanglement**:

```elixir
# Create Bell state and measure
qc = Qx.create_circuit(2, 2)
  |> Qx.h(0)
  |> Qx.cx(0, 1)
  |> Qx.measure(0, 0)
  |> Qx.measure(1, 1)

result = Qx.run(qc, 1000)

# Check the measurement outcomes
outcomes = result.counts

# You'll see only "00" and "11" outcomes, never "01" or "10"
# This demonstrates perfect correlation between the qubits
```

### 4.3 Controlled-Z (CZ) Gate

The CZ gate applies a phase flip to the target qubit if the control qubit is $|1\rangle$. Unlike CNOT, CZ is symmetric.

**Matrix Representation**:

$$\text{CZ} = \begin{pmatrix} 
1 & 0 & 0 & 0 \\
0 & 1 & 0 & 0 \\
0 & 0 & 1 & 0 \\
0 & 0 & 0 & -1
\end{pmatrix}$$

**Action**:
- $\text{CZ}|00\rangle = |00\rangle$
- $\text{CZ}|01\rangle = |01\rangle$
- $\text{CZ}|10\rangle = |10\rangle$
- $\text{CZ}|11\rangle = -|11\rangle$

**Key Property**: CZ is symmetric - it doesn't matter which qubit is the "control":
$$\text{CZ}_{0,1} = \text{CZ}_{1,0}$$

**Qx Example - CZ Gate**:

```elixir
# Circuit Mode
qc = Qx.create_circuit(2)
  |> Qx.h(0)     # Create superposition on qubit 0
  |> Qx.h(1)     # Create superposition on qubit 1
  |> Qx.cz(0, 1) # Apply CZ gate

state = Qx.get_state(qc)
# State: 0.5(|00⟩ + |01⟩ + |10⟩ - |11⟩)
# Note the negative phase on |11⟩

# Calculation Mode
reg = Register.new(2)
  |> Register.h(0)
  |> Register.h(1)

Register.show_state(reg)
# Before CZ: "0.500|00⟩ + 0.500|01⟩ + 0.500|10⟩ + 0.500|11⟩"

reg = reg |> Register.cz(0, 1)
Register.show_state(reg)
# After CZ: "0.500|00⟩ + 0.500|01⟩ + 0.500|10⟩ - 0.500|11⟩"
```

### 4.4 Relationship Between CZ and CNOT

The CZ and CNOT gates are related through Hadamard gates:

$$\text{CZ} = (I \otimes H) \cdot \text{CNOT} \cdot (I \otimes H)$$

This means applying H to the target, then CNOT, then H again gives you CZ.

**Qx Example - Converting CNOT to CZ**:

```elixir
# These two circuits are equivalent:

# Circuit 1: Direct CZ
qc1 = Qx.create_circuit(2)
  |> Qx.cz(0, 1)

# Circuit 2: CNOT with Hadamards
qc2 = Qx.create_circuit(2)
  |> Qx.h(1)      # H on target before CNOT
  |> Qx.cx(0, 1)  # CNOT
  |> Qx.h(1)      # H on target after CNOT

# Verify they produce the same result
state1 = Qx.get_state(qc1)
state2 = Qx.get_state(qc2)
# state1 and state2 will be identical
```

### 4.5 Three-Qubit Gate: Toffoli (CCX)

The Toffoli gate (also called CCNOT) is a three-qubit gate that flips the target qubit if and only if both control qubits are $|1\rangle$.

**Action**:
$$\text{CCX}|c_1, c_2, t\rangle = |c_1, c_2, t \oplus (c_1 \land c_2)\rangle$$

The Toffoli gate is universal for classical computation and plays a key role in quantum error correction.

**Qx Example - Toffoli Gate**:

```elixir
# Circuit Mode
qc = Qx.create_circuit(3)
  |> Qx.x(0)      # Set control 1 to |1⟩
  |> Qx.x(1)      # Set control 2 to |1⟩
  |> Qx.ccx(0, 1, 2)  # Toffoli gate

state = Qx.get_state(qc)
# Target qubit (2) is now |1⟩ because both controls are |1⟩

# Calculation Mode
reg = Register.new(3)
  |> Register.x(0)
  |> Register.x(1)

Register.show_state(reg)
# Before: "0.000|000⟩ + ... + 1.000|110⟩"

reg = reg |> Register.ccx(0, 1, 2)
Register.show_state(reg)
# After: "0.000|000⟩ + ... + 1.000|111⟩"
# The state changed from |110⟩ to |111⟩
```

---

## 5. Practical Examples with Qx

### 5.1 Quantum Teleportation

Quantum teleportation uses entanglement and classical communication to transfer a quantum state from one location to another.

**Protocol**:
1. Create Bell pair between qubits 1 and 2
2. Apply Bell measurement to qubits 0 (state to teleport) and 1
3. Apply conditional corrections to qubit 2 based on measurement results

```elixir
# Teleport |1⟩ state from qubit 0 to qubit 2
qc = Qx.create_circuit(3, 3)
  # Prepare state to teleport
  |> Qx.x(0)
  
  # Create Bell pair between qubits 1 and 2
  |> Qx.h(1)
  |> Qx.cx(1, 2)
  
  # Bell measurement on qubits 0 and 1
  |> Qx.cx(0, 1)
  |> Qx.h(0)
  |> Qx.measure(0, 0)
  |> Qx.measure(1, 1)
  
  # Conditional corrections on qubit 2
  |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)
  |> Qx.c_if(0, 1, fn c -> Qx.z(c, 2) end)
  |> Qx.measure(2, 2)

result = Qx.run(qc, 1000)

# Qubit 2 measurement should always be |1⟩
# demonstrating successful teleportation
Qx.draw_counts(result)
```

### 5.2 Grover's Search Algorithm (2-Qubit Example)

Grover's algorithm provides quadratic speedup for unstructured search.

```elixir
# Search for state |11⟩ in 2-qubit space
grover = Qx.create_circuit(2, 2)
  # Initialize superposition
  |> Qx.h(0)
  |> Qx.h(1)
  
  # Oracle: flip phase of |11⟩
  |> Qx.cz(0, 1)
  
  # Diffusion operator
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

result = Qx.run(grover, 1000)

# Should measure |11⟩ with high probability
Qx.draw_counts(result)
```

### 5.3 Interactive State Exploration

Use Calculation Mode to explore quantum mechanics interactively:

```elixir
alias Qx.{Qubit, Register}

# Single qubit exploration
q = Qubit.new()
  |> Qubit.h()
  |> Qubit.tap(fn q -> 
    Qx.draw_bloch(q, title: "After H") 
  end)
  |> Qubit.rz(:math.pi() / 4)
  |> Qubit.tap(fn q -> 
    Qx.draw_bloch(q, title: "After RZ(π/4)") 
  end)

# Multi-qubit exploration
reg = Register.new(3)
  |> Register.h(0)
  |> Register.h(1)
  |> Register.h(2)
  |> Register.tap(fn r ->
    IO.puts("All in superposition:")
    Register.show_state(r) |> IO.puts()
  end)
  |> Register.cx(0, 1)
  |> Register.cx(1, 2)
  |> Register.tap(fn r ->
    IO.puts("After creating GHZ state:")
    Register.show_state(r) |> IO.puts()
  end)

# Visualize final state
Qx.draw_state(reg, hide_zeros: true)
```

### 5.4 Comparing Circuit and Calculation Modes

**Circuit Mode** (build then execute):
```elixir
# Good for: algorithms, measurements, multiple shots
qc = Qx.create_circuit(2, 2)
  |> Qx.h(0)
  |> Qx.cx(0, 1)
  |> Qx.measure(0, 0)
  |> Qx.measure(1, 1)

result = Qx.run(qc, 1000)  # Run 1000 shots
```

**Calculation Mode** (immediate application):
```elixir
# Good for: learning, debugging, state inspection
reg = Register.new(2)
  |> Register.h(0)
  |> Register.cx(0, 1)

# State is immediately available
Register.show_state(reg)
Register.get_probabilities(reg)
```

---

## Conclusion

This tutorial has covered the fundamental concepts of quantum operations:

1. **Quantum Operators**: Unitary matrices that preserve quantum state normalization
2. **Pauli Gates**: Fundamental single-qubit gates (X, Y, Z) with distinct actions
3. **Bloch Sphere**: Geometric visualization showing Pauli gates as π rotations
4. **Two-Qubit Gates**: CNOT and CZ gates that create entanglement
5. **Practical Implementation**: Using Qx simulator for both circuit construction and real-time exploration

### Key Takeaways

- Quantum gates are reversible unitary transformations
- Pauli gates form the foundation for quantum computation
- The Bloch sphere provides intuition for single-qubit operations
- Two-qubit gates enable entanglement, the resource that powers quantum computation
- The Qx simulator offers both circuit mode (for algorithms) and calculation mode (for learning)

### Further Exploration

Continue your quantum computing journey by exploring:
- Quantum error correction codes
- Variational quantum algorithms (VQE, QAOA)
- Quantum Fourier Transform
- Shor's factoring algorithm

The Qx simulator provides the tools you need to experiment with these advanced topics!

---

## References

1. Nielsen, M. A., & Chuang, I. L. (2010). *Quantum Computation and Quantum Information*. Cambridge University Press.
2. Qx Simulator Documentation: https://hexdocs.pm/qx_sim/
3. Qx GitHub Repository: https://github.com/richarc/qx

## About This Tutorial

This tutorial was created to provide a comprehensive introduction to quantum gates and operations using the Qx quantum simulator for Elixir. The combination of mathematical theory with practical code examples helps bridge the gap between abstract quantum mechanics and hands-on experimentation.
