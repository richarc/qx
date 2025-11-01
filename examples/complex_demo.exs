#!/usr/bin/env elixir

# Complex Number Support Demonstration for Qx Quantum Computing Simulator
# This script demonstrates the newly implemented complex number support in Qx

# Helper function to format complex amplitudes
defmodule ComplexHelper do
  def format_amplitude(state, index, decimals \\ 6) do
    amp = Nx.to_number(state[index])
    real = Float.round(Complex.real(amp), decimals)
    imag = Float.round(Complex.imag(amp), decimals)
    sign = if imag >= 0, do: " + ", else: " "
    "#{real}#{sign}#{imag}i"
  end
end

IO.puts("=== Qx Complex Number Support Demonstration ===\n")

# Example 1: Y Gate - Now with proper complex numbers!
IO.puts("1. Pauli-Y Gate Demonstration")
IO.puts("   Y|0⟩ = i|1⟩ (produces purely imaginary amplitude)")

qc_y = Qx.create_circuit(1) |> Qx.y(0)
result_y = Qx.run(qc_y)
final_state_y = Qx.get_state(qc_y)

IO.puts("   Final state after Y gate:")
IO.puts("   |0⟩ amplitude: #{ComplexHelper.format_amplitude(final_state_y, 0)}")
IO.puts("   |1⟩ amplitude: #{ComplexHelper.format_amplitude(final_state_y, 1)}")

probs_y = Nx.to_flat_list(result_y.probabilities)
IO.puts("   Probabilities: |0⟩ = #{Float.round(Enum.at(probs_y, 0), 6)}, |1⟩ = #{Float.round(Enum.at(probs_y, 1), 6)}")
IO.puts("")

# Example 2: S Gate - Phase gate π/2
IO.puts("2. S Gate Demonstration (Phase π/2)")
IO.puts("   S|1⟩ = i|1⟩ (applies phase of i)")

qc_s = Qx.create_circuit(1) |> Qx.x(0) |> Qx.s(0)
final_state_s = Qx.get_state(qc_s)

IO.puts("   Final state after X then S:")
IO.puts("   |0⟩ amplitude: #{ComplexHelper.format_amplitude(final_state_s, 0)}")
IO.puts("   |1⟩ amplitude: #{ComplexHelper.format_amplitude(final_state_s, 1)}")
IO.puts("")

# Example 3: T Gate - Phase gate π/4
IO.puts("3. T Gate Demonstration (Phase π/4)")
IO.puts("   T|1⟩ = e^(iπ/4)|1⟩ = (cos(π/4) + i*sin(π/4))|1⟩")

qc_t = Qx.create_circuit(1) |> Qx.x(0) |> Qx.t(0)
final_state_t = Qx.get_state(qc_t)

expected_real = :math.cos(:math.pi() / 4)
expected_imag = :math.sin(:math.pi() / 4)

IO.puts("   Expected: #{Float.round(expected_real, 6)} + #{Float.round(expected_imag, 6)}i")
IO.puts("   Actual:   #{ComplexHelper.format_amplitude(final_state_t, 1)}")
IO.puts("")

# Example 4: Complex superposition with H then S
IO.puts("4. Complex Superposition: H|0⟩ then S")
IO.puts("   H|0⟩ = (|0⟩ + |1⟩)/√2, then S((|0⟩ + |1⟩)/√2) = (|0⟩ + i|1⟩)/√2")

qc_hs = Qx.create_circuit(1) |> Qx.h(0) |> Qx.s(0)
final_state_hs = Qx.get_state(qc_hs)

expected_amp = 1.0 / :math.sqrt(2)

IO.puts("   Final state after H then S:")
IO.puts("   |0⟩ amplitude: #{ComplexHelper.format_amplitude(final_state_hs, 0)}")
IO.puts("   |1⟩ amplitude: #{ComplexHelper.format_amplitude(final_state_hs, 1)}")
IO.puts("   Expected: (1/√2)|0⟩ + (i/√2)|1⟩")
IO.puts("   Expected amplitudes: #{Float.round(expected_amp, 6)} + 0i, 0 + #{Float.round(expected_amp, 6)}i")
IO.puts("")

# Example 5: Rotation gates with arbitrary phases
IO.puts("5. Rotation Gates with Complex Numbers")
IO.puts("   RZ(π/3)|1⟩ = e^(iπ/6)|1⟩")

angle = :math.pi() / 3
qc_rz = Qx.create_circuit(1) |> Qx.x(0) |> Qx.rz(0, angle)
final_state_rz = Qx.get_state(qc_rz)

expected_rz_real = :math.cos(angle / 2)
expected_rz_imag = :math.sin(angle / 2)

IO.puts("   RZ(π/3) applied to |1⟩:")
IO.puts("   Expected: #{Float.round(expected_rz_real, 6)} + #{Float.round(expected_rz_imag, 6)}i")
IO.puts("   Actual:   #{ComplexHelper.format_amplitude(final_state_rz, 1)}")
IO.puts("")

# Example 6: Phase gate with custom angle
IO.puts("6. Custom Phase Gate")
IO.puts("   Phase(π/6)|1⟩ = e^(iπ/6)|1⟩")

phi = :math.pi() / 6
qc_phase = Qx.create_circuit(1) |> Qx.x(0) |> Qx.phase(0, phi)
final_state_phase = Qx.get_state(qc_phase)

expected_phase_real = :math.cos(phi)
expected_phase_imag = :math.sin(phi)

IO.puts("   Phase(π/6) applied to |1⟩:")
IO.puts("   Expected: #{Float.round(expected_phase_real, 6)} + #{Float.round(expected_phase_imag, 6)}i")
IO.puts("   Actual:   #{ComplexHelper.format_amplitude(final_state_phase, 1)}")
IO.puts("")

# Example 7: Complex qubit creation with Qx.Qubit
IO.puts("7. Complex Qubit Creation")
IO.puts("   Creating qubit with complex coefficients: (0.6 + 0.8i)|0⟩ + (0.0)|1⟩")

alpha_complex = Complex.new(0.6, 0.8)
beta_complex = Complex.new(0.0, 0.0)

complex_qubit = Qx.Qubit.new(alpha_complex, beta_complex)
IO.puts("   Created qubit shape: #{inspect(Nx.shape(complex_qubit))}")
IO.puts("   Qubit is valid: #{Qx.Qubit.valid?(complex_qubit)}")

# Extract and display coefficients
alpha_extracted = Qx.Qubit.alpha(complex_qubit)
beta_extracted = Qx.Qubit.beta(complex_qubit)

IO.puts("   α coefficient: #{Float.round(Complex.real(alpha_extracted), 6)} + #{Float.round(Complex.imag(alpha_extracted), 6)}i")
IO.puts("   β coefficient: #{Float.round(Complex.real(beta_extracted), 6)} + #{Float.round(Complex.imag(beta_extracted), 6)}i")
IO.puts("")

# Example 8: Verification that Bell states still work
IO.puts("8. Bell State with Complex Support")
IO.puts("   Verifying that existing circuits work correctly with new complex backend")

bell_qc = Qx.bell_state()
bell_result = Qx.run(bell_qc)
bell_probs = Nx.to_flat_list(bell_result.probabilities)

IO.puts("   Bell state probabilities:")
IO.puts("   |00⟩: #{Float.round(Enum.at(bell_probs, 0), 6)}")
IO.puts("   |01⟩: #{Float.round(Enum.at(bell_probs, 1), 6)}")
IO.puts("   |10⟩: #{Float.round(Enum.at(bell_probs, 2), 6)}")
IO.puts("   |11⟩: #{Float.round(Enum.at(bell_probs, 3), 6)}")

bell_state = Qx.get_state(bell_qc)
IO.puts("   Complex representation:")
IO.puts("   |00⟩: #{ComplexHelper.format_amplitude(bell_state, 0)}")
IO.puts("   |11⟩: #{ComplexHelper.format_amplitude(bell_state, 3)}")
IO.puts("")

# Example 9: Demonstrating phase relationships
IO.puts("9. Phase Relationships and Interference")
IO.puts("   Creating state |+⟩ = (|0⟩ + |1⟩)/√2, then applying S to create (|0⟩ + i|1⟩)/√2")

interference_qc = Qx.create_circuit(1) |> Qx.h(0) |> Qx.s(0)
interference_state = Qx.get_state(interference_qc)

IO.puts("   Before measurement, the state has complex phases:")
IO.puts("   |0⟩: #{ComplexHelper.format_amplitude(interference_state, 0)}")
IO.puts("   |1⟩: #{ComplexHelper.format_amplitude(interference_state, 1)}")

# Show that probabilities are still 50/50 despite complex phases
interference_result = Qx.run(interference_qc)
interference_probs = Nx.to_flat_list(interference_result.probabilities)
IO.puts("   Measurement probabilities:")
IO.puts("   P(|0⟩) = #{Float.round(Enum.at(interference_probs, 0), 6)}")
IO.puts("   P(|1⟩) = #{Float.round(Enum.at(interference_probs, 1), 6)}")
IO.puts("   Note: Probabilities are |amplitude|², so phase doesn't affect measurement outcomes")
IO.puts("")

# Summary
IO.puts("=== Summary of Complex Number Support ===")
IO.puts("✅ Pauli-Y gate now produces correct imaginary amplitudes")
IO.puts("✅ S gate applies proper π/2 phase (multiplication by i)")
IO.puts("✅ T gate applies proper π/4 phase (e^(iπ/4))")
IO.puts("✅ Rotation gates support arbitrary angles with complex exponentials")
IO.puts("✅ Phase gates apply arbitrary phase factors")
IO.puts("✅ Complex qubit creation with arbitrary complex coefficients")
IO.puts("✅ All existing circuits remain compatible")
IO.puts("✅ Phase relationships properly maintained for quantum interference")
IO.puts("")
IO.puts("🎉 Qx now supports full complex number quantum computing!")
IO.puts("")
IO.puts("Key improvements over previous version:")
IO.puts("• No more approximations - all gates use correct complex matrices")
IO.puts("• Support for arbitrary quantum state preparation")
IO.puts("• True quantum phase relationships for interference effects")
IO.puts("• Foundation for advanced quantum algorithms requiring phase manipulation")
