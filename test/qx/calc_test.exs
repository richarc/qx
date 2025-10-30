defmodule Qx.CalcTest do
  use ExUnit.Case

  alias Qx.{Calc, Gates, Math}
  alias Complex, as: C

  defp complex_approx_equal?(c1, c2, tolerance) do
    abs(Complex.real(c1) - Complex.real(c2)) < tolerance and
      abs(Complex.imag(c1) - Complex.imag(c2)) < tolerance
  end

  defp state_approx_equal?(state1, state2, tolerance \\ 0.01) do
    list1 = Nx.to_flat_list(state1)
    list2 = Nx.to_flat_list(state2)

    Enum.zip(list1, list2)
    |> Enum.all?(fn {c1, c2} -> complex_approx_equal?(c1, c2, tolerance) end)
  end

  describe "apply_single_qubit_gate/4" do
    test "applies Hadamard to single qubit" do
      # Start with |0⟩
      state = Nx.tensor([C.new(1.0, 0.0), C.new(0.0, 0.0)], type: :c64)
      gate = Gates.hadamard()

      result = Calc.apply_single_qubit_gate(state, gate, 0, 1)

      # Should produce |+⟩ = (|0⟩ + |1⟩)/√2
      inv_sqrt2 = 1.0 / :math.sqrt(2)
      expected = Nx.tensor([C.new(inv_sqrt2, 0.0), C.new(inv_sqrt2, 0.0)], type: :c64)

      assert state_approx_equal?(result, expected)
    end

    test "applies Pauli-X to single qubit" do
      # Start with |0⟩
      state = Nx.tensor([C.new(1.0, 0.0), C.new(0.0, 0.0)], type: :c64)
      gate = Gates.pauli_x()

      result = Calc.apply_single_qubit_gate(state, gate, 0, 1)

      # Should produce |1⟩
      expected = Nx.tensor([C.new(0.0, 0.0), C.new(1.0, 0.0)], type: :c64)

      assert state_approx_equal?(result, expected)
    end

    test "applies gate to first qubit in 2-qubit system" do
      # Start with |00⟩
      state = Nx.tensor([C.new(1.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)], type: :c64)
      gate = Gates.pauli_x()

      result = Calc.apply_single_qubit_gate(state, gate, 0, 2)

      # X on qubit 0: |00⟩ -> |10⟩
      expected = Nx.tensor([C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(1.0, 0.0), C.new(0.0, 0.0)], type: :c64)

      assert state_approx_equal?(result, expected)
    end

    test "applies gate to second qubit in 2-qubit system" do
      # Start with |00⟩
      state = Nx.tensor([C.new(1.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)], type: :c64)
      gate = Gates.pauli_x()

      result = Calc.apply_single_qubit_gate(state, gate, 1, 2)

      # X on qubit 1: |00⟩ -> |01⟩
      expected = Nx.tensor([C.new(0.0, 0.0), C.new(1.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)], type: :c64)

      assert state_approx_equal?(result, expected)
    end

    test "applies Hadamard to create superposition in 2-qubit system" do
      # Start with |00⟩
      state = Nx.tensor([C.new(1.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)], type: :c64)
      gate = Gates.hadamard()

      result = Calc.apply_single_qubit_gate(state, gate, 0, 2)

      # H on qubit 0: |00⟩ -> (|00⟩ + |10⟩)/√2
      inv_sqrt2 = 1.0 / :math.sqrt(2)
      expected = Nx.tensor([
        C.new(inv_sqrt2, 0.0),
        C.new(0.0, 0.0),
        C.new(inv_sqrt2, 0.0),
        C.new(0.0, 0.0)
      ], type: :c64)

      assert state_approx_equal?(result, expected)
    end

    test "applies gate to middle qubit in 3-qubit system" do
      # Start with |000⟩
      state = Nx.tensor([C.new(1.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0),
                         C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)], type: :c64)
      gate = Gates.pauli_x()

      result = Calc.apply_single_qubit_gate(state, gate, 1, 3)

      # X on qubit 1: |000⟩ -> |010⟩ (index 2 in standard ordering)
      expected = Nx.tensor([C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(1.0, 0.0), C.new(0.0, 0.0),
                            C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)], type: :c64)

      assert state_approx_equal?(result, expected)
    end

    test "applies rotation gate with parameter" do
      # Start with |0⟩
      state = Nx.tensor([C.new(1.0, 0.0), C.new(0.0, 0.0)], type: :c64)
      gate = Gates.ry(:math.pi() / 2)

      result = Calc.apply_single_qubit_gate(state, gate, 0, 1)

      # RY(π/2)|0⟩ should give (|0⟩ + |1⟩)/√2
      inv_sqrt2 = 1.0 / :math.sqrt(2)
      expected = Nx.tensor([C.new(inv_sqrt2, 0.0), C.new(inv_sqrt2, 0.0)], type: :c64)

      assert state_approx_equal?(result, expected)
    end
  end

  describe "apply_cnot/4" do
    test "CNOT on |00⟩ gives |00⟩" do
      # Start with |00⟩
      state = Nx.tensor([C.new(1.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)], type: :c64)

      result = Calc.apply_cnot(state, 0, 1, 2)

      # Should remain |00⟩ (control is 0)
      assert state_approx_equal?(result, state)
    end

    test "CNOT on |01⟩ gives |01⟩" do
      # Start with |01⟩
      state = Nx.tensor([C.new(0.0, 0.0), C.new(1.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)], type: :c64)

      result = Calc.apply_cnot(state, 0, 1, 2)

      # Should remain |01⟩ (control is 0)
      assert state_approx_equal?(result, state)
    end

    test "CNOT on |10⟩ gives |11⟩" do
      # Start with |10⟩
      state = Nx.tensor([C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(1.0, 0.0), C.new(0.0, 0.0)], type: :c64)

      result = Calc.apply_cnot(state, 0, 1, 2)

      # Should flip to |11⟩ (control is 1)
      expected = Nx.tensor([C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(1.0, 0.0)], type: :c64)

      assert state_approx_equal?(result, expected)
    end

    test "CNOT on |11⟩ gives |10⟩" do
      # Start with |11⟩
      state = Nx.tensor([C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(1.0, 0.0)], type: :c64)

      result = Calc.apply_cnot(state, 0, 1, 2)

      # Should flip to |10⟩ (control is 1)
      expected = Nx.tensor([C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(1.0, 0.0), C.new(0.0, 0.0)], type: :c64)

      assert state_approx_equal?(result, expected)
    end

    test "CNOT creates Bell state from H|0⟩|0⟩" do
      # Start with |00⟩
      state = Nx.tensor([C.new(1.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)], type: :c64)

      # Apply H to qubit 0
      state = Calc.apply_single_qubit_gate(state, Gates.hadamard(), 0, 2)

      # Apply CNOT(0, 1)
      result = Calc.apply_cnot(state, 0, 1, 2)

      # Should create Bell state (|00⟩ + |11⟩)/√2
      inv_sqrt2 = 1.0 / :math.sqrt(2)
      expected = Nx.tensor([
        C.new(inv_sqrt2, 0.0),
        C.new(0.0, 0.0),
        C.new(0.0, 0.0),
        C.new(inv_sqrt2, 0.0)
      ], type: :c64)

      assert state_approx_equal?(result, expected)
    end

    test "CNOT with reversed control/target" do
      # Start with |01⟩
      state = Nx.tensor([C.new(0.0, 0.0), C.new(1.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)], type: :c64)

      # CNOT(1, 0) - qubit 1 is control, qubit 0 is target
      result = Calc.apply_cnot(state, 1, 0, 2)

      # |01⟩ -> |11⟩ (control qubit 1 is |1⟩, so flip target qubit 0)
      expected = Nx.tensor([C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(1.0, 0.0)], type: :c64)

      assert state_approx_equal?(result, expected)
    end

    test "CNOT in 3-qubit system" do
      # Start with |100⟩
      state = Nx.tensor([
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0),
        C.new(1.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)
      ], type: :c64)

      # CNOT(0, 2) in 3-qubit system
      result = Calc.apply_cnot(state, 0, 2, 3)

      # |100⟩ -> |101⟩ (qubit 0 is |1⟩, so flip qubit 2)
      expected = Nx.tensor([
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0),
        C.new(0.0, 0.0), C.new(1.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)
      ], type: :c64)

      assert state_approx_equal?(result, expected)
    end
  end

  describe "apply_toffoli/5" do
    test "Toffoli on |000⟩ gives |000⟩" do
      # Start with |000⟩
      state = Nx.tensor([
        C.new(1.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0),
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)
      ], type: :c64)

      result = Calc.apply_toffoli(state, 0, 1, 2, 3)

      # Should remain |000⟩ (not both controls are 1)
      assert state_approx_equal?(result, state)
    end

    test "Toffoli on |110⟩ gives |111⟩" do
      # Start with |110⟩ (index 6)
      state = Nx.tensor([
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0),
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(1.0, 0.0), C.new(0.0, 0.0)
      ], type: :c64)

      result = Calc.apply_toffoli(state, 0, 1, 2, 3)

      # Should flip to |111⟩ (index 7) (both controls are 1)
      expected = Nx.tensor([
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0),
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(1.0, 0.0)
      ], type: :c64)

      assert state_approx_equal?(result, expected)
    end

    test "Toffoli on |111⟩ gives |110⟩" do
      # Start with |111⟩ (index 7)
      state = Nx.tensor([
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0),
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(1.0, 0.0)
      ], type: :c64)

      result = Calc.apply_toffoli(state, 0, 1, 2, 3)

      # Should flip to |110⟩ (index 6) (both controls are 1)
      expected = Nx.tensor([
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0),
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(1.0, 0.0), C.new(0.0, 0.0)
      ], type: :c64)

      assert state_approx_equal?(result, expected)
    end

    test "Toffoli on |100⟩ gives |100⟩" do
      # Start with |100⟩ (index 4)
      state = Nx.tensor([
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0),
        C.new(1.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)
      ], type: :c64)

      result = Calc.apply_toffoli(state, 0, 1, 2, 3)

      # Should remain |100⟩ (only control 0 is 1)
      assert state_approx_equal?(result, state)
    end

    test "Toffoli on |010⟩ gives |010⟩" do
      # Start with |010⟩ (index 2)
      state = Nx.tensor([
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(1.0, 0.0), C.new(0.0, 0.0),
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)
      ], type: :c64)

      result = Calc.apply_toffoli(state, 0, 1, 2, 3)

      # Should remain |010⟩ (only control 1 is 1)
      assert state_approx_equal?(result, state)
    end

    test "Toffoli with different qubit ordering" do
      # Start with |011⟩ (index 3)
      state = Nx.tensor([
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(1.0, 0.0),
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0)
      ], type: :c64)

      # Toffoli with controls on qubits 1,2 and target on qubit 0
      result = Calc.apply_toffoli(state, 1, 2, 0, 3)

      # |011⟩ -> |111⟩ (both controls 1 and 2 are |1⟩, so flip target qubit 0)
      expected = Nx.tensor([
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0),
        C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(1.0, 0.0)
      ], type: :c64)

      assert state_approx_equal?(result, expected)
    end
  end

  describe "gate operations preserve normalization" do
    test "single qubit gate preserves normalization" do
      # Start with normalized superposition
      inv_sqrt2 = 1.0 / :math.sqrt(2)
      state = Nx.tensor([C.new(inv_sqrt2, 0.0), C.new(inv_sqrt2, 0.0)], type: :c64)

      result = Calc.apply_single_qubit_gate(state, Gates.pauli_x(), 0, 1)

      # Check normalization
      probs = Math.probabilities(result)
      total = Nx.sum(probs) |> Nx.to_number()
      assert abs(total - 1.0) < 1.0e-6
    end

    test "CNOT preserves normalization" do
      # Start with Bell state
      inv_sqrt2 = 1.0 / :math.sqrt(2)
      state = Nx.tensor([
        C.new(inv_sqrt2, 0.0),
        C.new(0.0, 0.0),
        C.new(0.0, 0.0),
        C.new(inv_sqrt2, 0.0)
      ], type: :c64)

      result = Calc.apply_cnot(state, 0, 1, 2)

      # Check normalization
      probs = Math.probabilities(result)
      total = Nx.sum(probs) |> Nx.to_number()
      assert abs(total - 1.0) < 1.0e-6
    end

    test "Toffoli preserves normalization" do
      # Start with equal superposition
      inv_sqrt8 = 1.0 / :math.sqrt(8)
      state = Nx.tensor([
        C.new(inv_sqrt8, 0.0), C.new(inv_sqrt8, 0.0), C.new(inv_sqrt8, 0.0), C.new(inv_sqrt8, 0.0),
        C.new(inv_sqrt8, 0.0), C.new(inv_sqrt8, 0.0), C.new(inv_sqrt8, 0.0), C.new(inv_sqrt8, 0.0)
      ], type: :c64)

      result = Calc.apply_toffoli(state, 0, 1, 2, 3)

      # Check normalization
      probs = Math.probabilities(result)
      total = Nx.sum(probs) |> Nx.to_number()
      assert abs(total - 1.0) < 1.0e-6
    end
  end
end
