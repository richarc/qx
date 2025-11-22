defmodule ComplexSupportTest do
  use ExUnit.Case
  doctest Qx

  alias Complex, as: C
  alias Qx.{Gates, Math, Qubit}

  test "complex number creation" do
    c = Math.complex(1.0, 2.0)
    assert C.real(c) == 1.0
    assert C.imag(c) == 2.0
  end

  test "complex matrix creation for Pauli-Y" do
    y_gate = Gates.pauli_y()
    assert Nx.shape(y_gate) == {2, 2}

    # Check Y = [[0, -i], [i, 0]]
    # Element [0,0] should be 0+0i
    elem_00 = Nx.to_number(y_gate[0][0])
    assert Complex.real(elem_00) == 0.0
    assert Complex.imag(elem_00) == 0.0

    # Element [0,1] should be 0-1i
    elem_01 = Nx.to_number(y_gate[0][1])
    assert Complex.real(elem_01) == 0.0
    assert Complex.imag(elem_01) == -1.0

    # Element [1,0] should be 0+1i
    elem_10 = Nx.to_number(y_gate[1][0])
    assert Complex.real(elem_10) == 0.0
    assert Complex.imag(elem_10) == 1.0

    # Element [1,1] should be 0+0i
    elem_11 = Nx.to_number(y_gate[1][1])
    assert Complex.real(elem_11) == 0.0
    assert Complex.imag(elem_11) == 0.0
  end

  test "complex matrix creation for S gate" do
    s_gate = Gates.s_gate()
    assert Nx.shape(s_gate) == {2, 2}

    # Check S = [[1, 0], [0, i]]
    # Element [0,0] should be 1+0i
    elem_00 = Nx.to_number(s_gate[0][0])
    assert Complex.real(elem_00) == 1.0
    assert Complex.imag(elem_00) == 0.0

    # Element [1,1] should be 0+1i
    elem_11 = Nx.to_number(s_gate[1][1])
    assert Complex.real(elem_11) == 0.0
    assert Complex.imag(elem_11) == 1.0
  end

  test "complex matrix creation for T gate" do
    t_gate = Gates.t_gate()
    assert Nx.shape(t_gate) == {2, 2}

    # Element [1,1] should be e^(iπ/4) = cos(π/4) + i*sin(π/4)
    expected_real = :math.cos(:math.pi() / 4)
    expected_imag = :math.sin(:math.pi() / 4)

    elem_11 = Nx.to_number(t_gate[1][1])
    actual_real = Complex.real(elem_11)
    actual_imag = Complex.imag(elem_11)

    assert abs(actual_real - expected_real) < 1.0e-6
    assert abs(actual_imag - expected_imag) < 1.0e-6
  end

  test "rotation gates with complex numbers" do
    theta = :math.pi() / 2

    # Test RX gate
    rx_gate = Gates.rx(theta)
    assert Nx.shape(rx_gate) == {2, 2}

    # RX(π/2) should have cos(π/4) and -i*sin(π/4) components
    _cos_val = :math.cos(theta / 2)
    sin_val = :math.sin(theta / 2)

    # Element [0,1] should be 0-i*sin(π/4)
    elem_01 = Nx.to_number(rx_gate[0][1])
    assert abs(Complex.real(elem_01) - 0.0) < 1.0e-6
    assert abs(Complex.imag(elem_01) - -sin_val) < 1.0e-6
  end

  test "qubit creation with complex coefficients" do
    # Test with complex numbers
    alpha = C.new(0.6, 0.0)
    beta = C.new(0.8, 0.0)

    qubit = Qubit.new(alpha, beta)
    assert Nx.shape(qubit) == {2}
    assert Qubit.valid?(qubit)
  end

  test "qubit creation with purely imaginary coefficients" do
    # Test with imaginary coefficients
    # 0.6i
    alpha = C.new(0.0, 0.6)
    # 0.8i
    beta = C.new(0.0, 0.8)

    qubit = Qubit.new(alpha, beta)
    assert Nx.shape(qubit) == {2}
    assert Qubit.valid?(qubit)

    # Check normalization: |0.6i|² + |0.8i|² = 0.36 + 0.64 = 1.0
    probs = Math.probabilities(qubit)
    total_prob = Nx.sum(probs) |> Nx.to_number()
    assert abs(total_prob - 1.0) < 1.0e-6
  end

  test "complex state normalization" do
    # Create unnormalized complex state
    # |ψ⟩ = 2|0⟩ + 2i|1⟩
    complex_state = Nx.tensor([C.new(2.0, 0.0), C.new(0.0, 2.0)], type: :c64)

    normalized = Math.normalize(complex_state)
    probs = Math.probabilities(normalized)
    total_prob = Nx.sum(probs) |> Nx.to_number()

    assert abs(total_prob - 1.0) < 1.0e-6
  end

  test "complex probability calculation" do
    # Create state |ψ⟩ = (1+i)|0⟩ + (1-i)|1⟩ (unnormalized)
    complex_state = Nx.tensor([C.new(1.0, 1.0), C.new(1.0, -1.0)], type: :c64)

    probs = Math.probabilities(complex_state)
    prob_list = Nx.to_flat_list(probs)

    # |1+i|² = 1² + 1² = 2
    # |1-i|² = 1² + (-1)² = 2
    assert abs(Enum.at(prob_list, 0) - 2.0) < 1.0e-6
    assert abs(Enum.at(prob_list, 1) - 2.0) < 1.0e-6
  end

  test "Y gate on |0⟩ produces i|1⟩" do
    qc = Qx.create_circuit(1) |> Qx.y(0)
    final_state = Qx.get_state(qc)

    # After Y|0⟩ = i|1⟩, we should have [0+0i, 0+1i]
    assert Nx.shape(final_state) == {2}

    # |0⟩ amplitude should be 0+0i
    # real part
    assert abs(Complex.real(Nx.to_number(final_state[0]))) < 1.0e-6
    # imaginary part
    assert abs(Complex.imag(Nx.to_number(final_state[0]))) < 1.0e-6

    # |1⟩ amplitude should be 0+1i
    # real part should be ~0
    assert abs(Complex.real(Nx.to_number(final_state[1]))) < 1.0e-6
    # imaginary part should be ±1
    assert abs(abs(Complex.imag(Nx.to_number(final_state[1]))) - 1.0) < 1.0e-6
  end

  test "S gate on |1⟩ produces i|1⟩" do
    qc = Qx.create_circuit(1) |> Qx.x(0) |> Qx.s(0)
    final_state = Qx.get_state(qc)

    # After X|0⟩ = |1⟩, then S|1⟩ = i|1⟩
    assert Nx.shape(final_state) == {2}

    # |0⟩ amplitude should be 0+0i
    assert abs(Complex.real(Nx.to_number(final_state[0]))) < 1.0e-6
    assert abs(Complex.imag(Nx.to_number(final_state[0]))) < 1.0e-6

    # |1⟩ amplitude should be 0+1i
    # real part should be ~0
    assert abs(Complex.real(Nx.to_number(final_state[1]))) < 1.0e-6
    # |imaginary part| should be 1
    assert abs(abs(Complex.imag(Nx.to_number(final_state[1]))) - 1.0) < 1.0e-6
  end

  test "T gate application" do
    qc = Qx.create_circuit(1) |> Qx.x(0) |> Qx.t(0)
    final_state = Qx.get_state(qc)

    # After X|0⟩ = |1⟩, then T|1⟩ = e^(iπ/4)|1⟩
    expected_real = :math.cos(:math.pi() / 4)
    expected_imag = :math.sin(:math.pi() / 4)

    actual_real = Complex.real(Nx.to_number(final_state[1]))
    actual_imag = Complex.imag(Nx.to_number(final_state[1]))

    assert abs(actual_real - expected_real) < 1.0e-6
    assert abs(actual_imag - expected_imag) < 1.0e-6
  end

  test "complex superposition with Hadamard" do
    qc = Qx.create_circuit(1) |> Qx.h(0)
    final_state = Qx.get_state(qc)

    # H|0⟩ = (|0⟩ + |1⟩)/√2
    expected_amp = 1.0 / :math.sqrt(2)

    # Both amplitudes should be real and equal
    amp_0_real = Complex.real(Nx.to_number(final_state[0]))
    amp_0_imag = Complex.imag(Nx.to_number(final_state[0]))
    amp_1_real = Complex.real(Nx.to_number(final_state[1]))
    amp_1_imag = Complex.imag(Nx.to_number(final_state[1]))

    assert abs(amp_0_real - expected_amp) < 1.0e-6
    assert abs(amp_0_imag) < 1.0e-6
    assert abs(amp_1_real - expected_amp) < 1.0e-6
    assert abs(amp_1_imag) < 1.0e-6
  end

  test "complex circuit: H then S" do
    qc = Qx.create_circuit(1) |> Qx.h(0) |> Qx.s(0)
    final_state = Qx.get_state(qc)

    # H|0⟩ = (|0⟩ + |1⟩)/√2
    # S((|0⟩ + |1⟩)/√2) = (|0⟩ + i|1⟩)/√2

    expected_amp = 1.0 / :math.sqrt(2)

    # |0⟩ coefficient should be 1/√2 + 0i
    amp_0_real = Complex.real(Nx.to_number(final_state[0]))
    amp_0_imag = Complex.imag(Nx.to_number(final_state[0]))
    assert abs(amp_0_real - expected_amp) < 1.0e-6
    assert abs(amp_0_imag) < 1.0e-6

    # |1⟩ coefficient should be 0 + (1/√2)i
    amp_1_real = Complex.real(Nx.to_number(final_state[1]))
    amp_1_imag = Complex.imag(Nx.to_number(final_state[1]))
    assert abs(amp_1_real) < 1.0e-6
    assert abs(amp_1_imag - expected_amp) < 1.0e-6
  end

  test "rotation gate with arbitrary angle" do
    # 60 degrees
    theta = :math.pi() / 3
    qc = Qx.create_circuit(1) |> Qx.ry(0, theta)
    final_state = Qx.get_state(qc)

    # RY(θ)|0⟩ = cos(θ/2)|0⟩ + sin(θ/2)|1⟩
    expected_cos = :math.cos(theta / 2)
    expected_sin = :math.sin(theta / 2)

    amp_0_real = Complex.real(Nx.to_number(final_state[0]))
    amp_1_real = Complex.real(Nx.to_number(final_state[1]))

    assert abs(amp_0_real - expected_cos) < 1.0e-6
    assert abs(amp_1_real - expected_sin) < 1.0e-6
  end

  test "phase gate with arbitrary phase" do
    # 30 degrees
    phi = :math.pi() / 6
    qc = Qx.create_circuit(1) |> Qx.x(0) |> Qx.phase(0, phi)
    final_state = Qx.get_state(qc)

    # X|0⟩ = |1⟩, then Phase(φ)|1⟩ = e^(iφ)|1⟩
    expected_real = :math.cos(phi)
    expected_imag = :math.sin(phi)

    amp_1_real = Complex.real(Nx.to_number(final_state[1]))
    amp_1_imag = Complex.imag(Nx.to_number(final_state[1]))

    assert abs(amp_1_real - expected_real) < 1.0e-6
    assert abs(amp_1_imag - expected_imag) < 1.0e-6
  end

  test "Bell state maintains correct complex structure" do
    qc = Qx.bell_state()
    final_state = Qx.get_state(qc)

    # Bell state should be (|00⟩ + |11⟩)/√2, all real coefficients
    expected_amp = 1.0 / :math.sqrt(2)

    # |00⟩ coefficient
    amp_00_real = Complex.real(Nx.to_number(final_state[0]))
    amp_00_imag = Complex.imag(Nx.to_number(final_state[0]))

    # |11⟩ coefficient
    amp_11_real = Complex.real(Nx.to_number(final_state[3]))
    amp_11_imag = Complex.imag(Nx.to_number(final_state[3]))

    assert abs(amp_00_real - expected_amp) < 1.0e-6
    assert abs(amp_00_imag) < 1.0e-6
    assert abs(amp_11_real - expected_amp) < 1.0e-6
    assert abs(amp_11_imag) < 1.0e-6
  end

  test "complex qubit alpha and beta extraction" do
    alpha_c = C.new(0.6, 0.8)
    beta_c = C.new(0.0, 0.0)

    qubit = Qubit.new(alpha_c, beta_c)

    extracted_alpha = Qubit.alpha(qubit)
    extracted_beta = Qubit.beta(qubit)

    # Should be normalized, so we need to check the ratio
    norm_factor = C.abs(alpha_c)
    expected_alpha = C.divide(alpha_c, norm_factor)
    expected_beta = C.divide(beta_c, norm_factor)

    assert abs(C.real(extracted_alpha) - C.real(expected_alpha)) < 1.0e-6
    assert abs(C.imag(extracted_alpha) - C.imag(expected_alpha)) < 1.0e-6
    assert abs(C.real(extracted_beta) - C.real(expected_beta)) < 1.0e-6
    assert abs(C.imag(extracted_beta) - C.imag(expected_beta)) < 1.0e-6
  end
end
