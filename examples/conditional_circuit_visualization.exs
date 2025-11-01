#!/usr/bin/env elixir

# Conditional Circuit Visualization Examples
# Demonstrates the visualization of classically-controlled quantum operations

# Ensure output directory exists
File.mkdir_p!("output")

IO.puts("=== Conditional Circuit Visualization Examples ===\n")

# Example 1: Simple conditional with filled circle (==1)
IO.puts("1. Creating circuit with conditional X gate (==1)")
qc1 = Qx.create_circuit(2, 2)
      |> Qx.h(0)
      |> Qx.measure(0, 0)
      |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
      |> Qx.measure(1, 1)

svg1 = Qx.Draw.circuit(qc1, "Conditional X Gate (c0==1)")
File.write!("output/conditional_filled_circle.svg", svg1)
IO.puts("   Saved to: output/conditional_filled_circle.svg")
IO.puts("   Features: X gate with double lines to classical register")
IO.puts("   Circle: Filled (indicates checking for ==1)\n")

# Example 2: Conditional with hollow circle (==0)
IO.puts("2. Creating circuit with conditional Z gate (==0)")
qc2 = Qx.create_circuit(2, 2)
      |> Qx.h(0)
      |> Qx.measure(0, 0)
      |> Qx.c_if(0, 0, fn c -> Qx.z(c, 1) end)
      |> Qx.measure(1, 1)

svg2 = Qx.Draw.circuit(qc2, "Conditional Z Gate (c0==0)")
File.write!("output/conditional_hollow_circle.svg", svg2)
IO.puts("   Saved to: output/conditional_hollow_circle.svg")
IO.puts("   Features: Z gate with double lines to classical register")
IO.puts("   Circle: Hollow (indicates checking for ==0)\n")

# Example 3: Multiple gates in one conditional
IO.puts("3. Multiple gates controlled by single classical bit")
qc3 = Qx.create_circuit(3, 3)
      |> Qx.x(0)
      |> Qx.measure(0, 0)
      |> Qx.c_if(0, 1, fn c ->
           c |> Qx.x(1) |> Qx.h(2)
         end)
      |> Qx.measure(1, 1)
      |> Qx.measure(2, 2)

svg3 = Qx.Draw.circuit(qc3, "Multiple Conditional Gates")
File.write!("output/conditional_multiple_gates.svg", svg3)
IO.puts("   Saved to: output/conditional_multiple_gates.svg")
IO.puts("   Features: Both X and H gates have classical control")
IO.puts("   Note: Each gate has its own double-line connection\n")

# Example 4: Quantum Teleportation - Full Protocol
IO.puts("4. Quantum Teleportation with Conditional Corrections")
qc4 = Qx.create_circuit(3, 3)
      |> Qx.x(0)              # State to teleport: |1⟩
      |> Qx.h(1)              # Create Bell pair
      |> Qx.cx(1, 2)
      |> Qx.cx(0, 1)          # Bell measurement
      |> Qx.h(0)
      |> Qx.measure(0, 0)
      |> Qx.measure(1, 1)
      |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)  # X correction
      |> Qx.c_if(0, 1, fn c -> Qx.z(c, 2) end)  # Z correction
      |> Qx.measure(2, 2)

svg4 = Qx.Draw.circuit(qc4, "Quantum Teleportation Protocol")
File.write!("output/teleportation_circuit.svg", svg4)
IO.puts("   Saved to: output/teleportation_circuit.svg")
IO.puts("   Features: Shows full teleportation with conditional corrections")
IO.puts("   Classical bits c1 and c0 control X and Z corrections on qubit 2\n")

# Example 5: Multiple conditionals on different classical bits
IO.puts("5. Circuit with multiple classical controls")
qc5 = Qx.create_circuit(3, 3)
      |> Qx.h(0)
      |> Qx.h(1)
      |> Qx.measure(0, 0)
      |> Qx.measure(1, 1)
      |> Qx.c_if(0, 1, fn c -> Qx.x(c, 2) end)
      |> Qx.c_if(1, 1, fn c -> Qx.z(c, 2) end)
      |> Qx.measure(2, 2)

svg5 = Qx.Draw.circuit(qc5, "Multiple Classical Controls")
File.write!("output/multiple_classical_controls.svg", svg5)
IO.puts("   Saved to: output/multiple_classical_controls.svg")
IO.puts("   Features: Different classical bits (c0, c1) controlling different gates")
IO.puts("   Labels distinguish which classical bit is checked\n")

IO.puts("=== Visualization Guide ===")
IO.puts("• Gates: Rendered in standard colors (X=red, H=cyan, Z=gray, etc.)")
IO.puts("• Classical control: Double parallel gray lines from gate to classical register")
IO.puts("• Filled circle (●): Checking for classical bit == 1")
IO.puts("• Hollow circle (○): Checking for classical bit == 0")
IO.puts("• Label 'c_X': Shows which classical bit is being checked")
IO.puts("• Measurements: Single line + arrow (distinct from conditionals)")
IO.puts("\n=== Examples Complete ===")
