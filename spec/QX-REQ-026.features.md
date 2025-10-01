### QX-REQ-026: Circuit Visualization
**Requirement**: The system shall support a circuit drawing function using information from the Qx.QuantumCircuit structure, including the list of instructions to visualize the circuit diagram. The diagrams should follow as closely as possible to the visualization and standards used in the IBM Qiskit Python SDK.

## Features

### F1: Circuit Layout & Structure
- **Layout**: Horizontal qubit lines arranged from top to bottom (q0 at top, q1 below, etc.)
- **Gate Ordering**: Gates applied left to right in instruction order as they appear in the circuit
- **Temporal Positioning**: Per-qubit gate positioning maintains correct temporal sequence
- **Auto-sizing**: Automatic image dimensions based on circuit complexity
- **Spacing**:
  - Horizontal gate spacing: 40pt minimum between gates
  - Vertical qubit line spacing: 45pt between adjacent qubit lines
  - Diagram padding: 20pt on all sides
- **Collision Avoidance**: Gates with vertical connecting lines (multi-qubit gates and measurements) must not pass through or overlap with other gates:
  - Multi-qubit gates: Check all qubits between control and target for existing gates
  - Measurement gates: Check all qubits from the measured qubit down to the classical register
  - If collision detected, move the gate to the next column
  - When a gate with a vertical line is placed, mark all qubits along its path as occupied

### F2: Gate Visualization
- **Single-qubit gates**: Standard rectangular boxes with text labels (H, X, Y, Z, RX, RY, RZ, etc.)
  - All gate boxes have uniform dimensions: 30pt × 30pt
  - Parametric gates (RX, RY, RZ, P) display parameter values in the label (e.g., "RX(π/4)")
  - Custom gate definitions are not supported in this iteration
- **Multi-qubit gates**: IEEE standard symbols (⊕ for CNOT control/target, ⊙ for controlled gates)
  - Control dot (filled circle): ~4.5pt radius
  - Target symbol outer circle: ~10.5pt radius with proportional cross lines
  - Vertical connecting lines: 2pt thickness
- **Color coding**: Different colors for different gate types (see color scheme below)
- **Positioning**: Gates positioned to preserve instruction sequence and avoid overlap

### F3: Qubit & Classical Bit Representation
- **Qubit lines**: Solid horizontal lines with labels q0, q1, q2, etc. on the left side
  - Line thickness: 2pt
  - All qubit lines span the full width of the diagram
- **Classical bits**:
  - All classical bit registers use double horizontal lines (regardless of bit count)
  - Labeled with forward slash notation: c/n (where n is the number of bits)
  - Line thickness: 2pt
  - Classical bit lines span the full width of the diagram (same length as qubit lines)
  - Measurement connections shown with triangular arrows pointing to the classical register

### F4: Output & Integration
- **Function signature**: `Qx.Draw.circuit(quantum_circuit)` or `Qx.Draw.circuit(quantum_circuit, title)`
  - `quantum_circuit`: Required - the QuantumCircuit structure to visualize
  - `title`: Optional - string for circuit title displayed at top of diagram (15pt font)
- **Return format**: SVG image data (default and only format in this iteration)
- **No file I/O**: Function returns image data only; user decides whether to save or display
- **Integration**: Seamless integration with existing Qx.Draw module
- **Validation**: Function validates circuit structure before drawing:
  - Checks for invalid gate parameters
  - Verifies qubit indices are within valid range (0-19)
  - Verifies classical bit indices are valid
  - Throws descriptive errors for invalid circuits
- **No additional parameters**: Scale, show_labels, and style options are not supported in this iteration

### F5: Supported Operations
- **Quantum gates**: All single-qubit, two-qubit, and multi-qubit gates
  - Unsupported or unrecognized gate types will throw an error
  - Gate inverse notation (†, ⁻¹) is not supported in this iteration
- **Measurements**: Measurement operations with classical bit connections
  - Measurement symbol: arc with diagonal arrow (~10.5pt radius)
  - Vertical line connects measurement to classical register (2pt thickness)
- **Circuit elements**: Barriers and separators for circuit organization
  - Barriers span all qubit lines (not classical bit lines)
  - Rendered as vertical dashed lines (dash pattern: 3.7,1.6)
  - No minimum width requirement
- **Exclusions**: No classical control flow support

### F6: Visual Design Standards

**Color Scheme** (adapted from Qiskit sample):
- Pauli X gates: Red (#fa4d56)
- Hadamard (H): Cyan blue (#33b1ff)
- Control dots: Dark blue (#002d9c) for small controls, cyan blue (#33b1ff) for large controls
- Measurements and Barriers: Gray (#a8a8a8) with 0.6 opacity for barriers
- Gate fills: Solid (no transparency) except barriers
- Controlled gates: Use colors matching the sample (controlled operations use blue tones)

**Typography:**
- Font family: Helvetica
- Qubit/classical bit labels: 13pt, normal weight
- Gate labels: 10pt, normal weight
- Circuit title (optional): 15pt, normal weight, positioned at top of diagram
- Subscript positioning: Consistent for all qubit numbers (single or double-digit)

**Symbol Dimensions:**
- Gate boxes: 30pt × 30pt (uniform for all gate types)
- Control dots: ~4.5pt radius
- Target symbols: ~10.5pt outer radius with proportional cross lines
- Measurement arcs: ~10.5pt radius with diagonal arrow

**Line Specifications:**
- Qubit lines: 2pt thickness, solid black
- Classical bit lines: 2pt thickness, solid gray (#778899), double lines
- Vertical connecting lines: 2pt thickness
- Gate box borders: 1.5pt thickness
- Barrier lines: Dashed (pattern: 3.7,1.6), black

**Gate Symbol Standards:**
- Follow IEEE quantum circuit notation where applicable
- Maintain consistency with Qiskit visualization conventions as shown in sample
- Clear, readable fonts for gate labels
- Appropriate sizing based on circuit complexity

## System Limits and Edge Cases

**Circuit Size Limits:**
- Maximum qubits: 20 (system limit)
- No explicit maximum on number of gates (limited by practical rendering considerations)

**Edge Case Handling:**
- **Empty circuits** (no gates): Draw qubit lines only, no error or warning
- **Partial circuits**: Always draw all qubits in the circuit (no subset visualization)
- **Invalid circuits**: Validation errors thrown before rendering begins
- **Collision scenarios**: Multi-qubit gates automatically moved to next column if vertical line would intersect other gates

## Implementation Details

### Data Structures
Create a structure to hold the circuit diagram data, `%CircuitDiagram{}`, that will be calculated from the `%QuantumCircuit{}` structure.

### Private Functions

**1. Circuit Analysis Function**
Examines the `%QuantumCircuit{}` structure and generates the `%CircuitDiagram{}` structure. Calculates:
- Number of qubit lines to be drawn
- Number of classical bit lines to be drawn (represented as single register with c/n notation)
- Height calculation:
  - Qubit lines: `(num_qubits - 1) × 45pt + gate_box_height`
  - Classical bit line spacing from last qubit: 45pt
  - Add 20pt padding on top and bottom
  - Add space for optional title if provided (15pt font + spacing)
- Width calculation:
  - Based on number of gate columns after layout with collision avoidance
  - Minimum 40pt spacing between gate columns
  - Add 20pt padding on left and right
  - Account for space needed for qubit/classical bit labels on the left

**2. Line Drawing Function**
Draws the circuit lines with labels:
- Qubit lines: Solid horizontal 2pt black lines spanning full width
- Qubit labels: Left side, 13pt Helvetica, format "q₀, q₁, q₂..." with subscripts
- Classical bit lines: Double horizontal 2pt gray (#778899) lines spanning full width
- Classical bit label: Left side, 13pt Helvetica, format "c/n" with slash notation
- Optional title: Centered at top, 15pt Helvetica

**3. Gate Layout and Rendering Function**
Lays out gates on appropriate qubit lines with collision avoidance. Rules:
- Treat horizontal axis as numbered columns (0, 1, 2, ...)
- For each instruction in order:
  - Place gate symbol on target qubit line in earliest available column
  - For single-qubit gates: Check current column is free on that qubit line
  - For gates with vertical connectors (CNOT, CZ, CCX, measurements):
    - Multi-qubit gates: Check all qubit lines between control and target for existing gates
    - Measurement gates: Check all qubit lines from measured qubit to last qubit (classical register is below)
    - If any gate found in path, advance to next column and check again
    - When placed, mark ALL qubits along the vertical path as occupied
    - This ensures vertical lines never cut through or overlap with other gates
    - Measurements on different qubits applied sequentially will cascade to different columns
- Gate rendering:
  - Single-qubit gates: 30pt × 30pt boxes with 10pt text labels, 1.5pt borders
  - Control dots: Filled circles ~4.5pt radius
  - Target symbols: Circle ~10.5pt radius with cross lines
  - Measurement: Arc symbol ~10.5pt radius with diagonal arrow
  - Barriers: Vertical dashed line (3.7,1.6 pattern) spanning all qubit lines
- Measurement lines: 2pt vertical lines from measurement symbol to classical register with triangular arrow

**4. Validation Function**
Validates circuit before rendering:
- Verify all qubit indices are in range [0, 19]
- Verify all classical bit indices are valid
- Check gate parameters are valid for parametric gates
- Verify gate types are recognized (throw error if not)
- Return descriptive error messages for any validation failures

### Public Function
`Qx.Draw.circuit(quantum_circuit)` or `Qx.Draw.circuit(quantum_circuit, title)`

Execution sequence:
1. Validate circuit structure (throw error if invalid)
2. Analyze circuit and create `%CircuitDiagram{}` structure
3. Initialize SVG canvas with calculated dimensions
4. Draw lines and labels
5. Layout and render all gates with collision avoidance
6. Return SVG image data as string

### Reference Implementation
Use the sample SVG file (`teleportation_circuit.svg`) in this directory as the reference for:
- Visual style and design standards
- Color palette and opacity values
- Symbol shapes and proportions
- Overall diagram flow and layout conventions
