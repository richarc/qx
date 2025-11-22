defmodule Qx.ValidationTest do
  use ExUnit.Case
  doctest Qx.Validation

  alias Complex, as: C
  alias Qx.Validation

  describe "valid_qubit?/2" do
    test "validates normalized single qubit" do
      q = Qx.Qubit.new()
      assert Validation.valid_qubit?(q)
    end

    test "validates custom qubit state" do
      q = Qx.Qubit.new(0.6, 0.8)
      assert Validation.valid_qubit?(q)
    end

    test "rejects unnormalized qubit" do
      invalid = Nx.tensor([C.new(1.0, 0.0), C.new(1.0, 0.0)], type: :c64)
      refute Validation.valid_qubit?(invalid)
    end

    test "rejects wrong shape" do
      wrong_shape = Nx.tensor([C.new(1.0, 0.0)], type: :c64)
      refute Validation.valid_qubit?(wrong_shape)
    end

    test "rejects multi-qubit state" do
      reg = Qx.Register.new(2)
      refute Validation.valid_qubit?(reg.state)
    end

    test "respects custom tolerance" do
      # Slightly unnormalized (1.001 instead of 1.0)
      almost = Nx.tensor([C.new(0.708, 0.0), C.new(0.708, 0.0)], type: :c64)

      # Strict tolerance rejects
      refute Validation.valid_qubit?(almost, 1.0e-6)

      # Lenient tolerance accepts
      assert Validation.valid_qubit?(almost, 0.01)
    end
  end

  describe "valid_register?/2" do
    test "validates 1-qubit register" do
      reg = Qx.Register.new(1)
      assert Validation.valid_register?(reg)
    end

    test "validates 2-qubit register" do
      reg = Qx.Register.new(2)
      assert Validation.valid_register?(reg)
    end

    test "validates register after gates" do
      reg =
        Qx.Register.new(2)
        |> Qx.Register.h(0)
        |> Qx.Register.cx(0, 1)

      assert Validation.valid_register?(reg)
    end

    test "rejects register with wrong state size" do
      # Manually create invalid register
      wrong_state = Nx.tensor([C.new(1.0, 0.0), C.new(0.0, 0.0)], type: :c64)
      invalid_reg = %{state: wrong_state, num_qubits: 2}

      refute Validation.valid_register?(invalid_reg)
    end
  end

  describe "validate_normalized!/2" do
    test "passes for normalized state" do
      state = Qx.Qubit.new()
      assert Validation.validate_normalized!(state) == :ok
    end

    test "raises for unnormalized state" do
      unnormalized = Nx.tensor([C.new(1.0, 0.0), C.new(1.0, 0.0)], type: :c64)

      assert_raise Qx.StateNormalizationError, ~r/State not normalized/, fn ->
        Validation.validate_normalized!(unnormalized)
      end
    end

    test "includes total probability in error message" do
      unnormalized = Nx.tensor([C.new(1.0, 0.0), C.new(1.0, 0.0)], type: :c64)

      assert_raise Qx.StateNormalizationError, ~r/total probability = 2\.0/, fn ->
        Validation.validate_normalized!(unnormalized)
      end
    end
  end

  describe "validate_qubit_index!/2" do
    test "accepts valid indices" do
      assert Validation.validate_qubit_index!(0, 3) == :ok
      assert Validation.validate_qubit_index!(1, 3) == :ok
      assert Validation.validate_qubit_index!(2, 3) == :ok
    end

    test "rejects negative index" do
      assert_raise Qx.QubitIndexError, ~r/Qubit index -1 out of range/, fn ->
        Validation.validate_qubit_index!(-1, 3)
      end
    end

    test "rejects index >= num_qubits" do
      assert_raise Qx.QubitIndexError, ~r/Qubit index 3 out of range \(0\.\.2\)/, fn ->
        Validation.validate_qubit_index!(3, 3)
      end
    end

    test "rejects large index" do
      assert_raise Qx.QubitIndexError, ~r/Qubit index 100 out of range/, fn ->
        Validation.validate_qubit_index!(100, 5)
      end
    end

    test "works with 1-qubit system" do
      assert Validation.validate_qubit_index!(0, 1) == :ok

      assert_raise Qx.QubitIndexError, fn ->
        Validation.validate_qubit_index!(1, 1)
      end
    end
  end

  describe "validate_qubit_indices!/2" do
    test "accepts all valid indices" do
      assert Validation.validate_qubit_indices!([0, 1, 2], 5) == :ok
    end

    test "accepts empty list" do
      assert Validation.validate_qubit_indices!([], 5) == :ok
    end

    test "rejects if any index is invalid" do
      assert_raise Qx.QubitIndexError, ~r/Qubit index 5 out of range/, fn ->
        Validation.validate_qubit_indices!([0, 1, 5], 3)
      end
    end

    test "stops at first invalid index" do
      # Should raise error for index 10, not 20
      assert_raise Qx.QubitIndexError, ~r/Qubit index 10/, fn ->
        Validation.validate_qubit_indices!([0, 10, 20], 5)
      end
    end
  end

  describe "validate_qubits_different!/1" do
    test "accepts all different qubits" do
      assert Validation.validate_qubits_different!([0, 1, 2]) == :ok
    end

    test "accepts single qubit" do
      assert Validation.validate_qubits_different!([0]) == :ok
    end

    test "accepts empty list" do
      assert Validation.validate_qubits_different!([]) == :ok
    end

    test "rejects duplicate qubits" do
      assert_raise ArgumentError, ~r/All qubit indices must be different/, fn ->
        Validation.validate_qubits_different!([0, 1, 0])
      end
    end

    test "rejects all same qubits" do
      assert_raise ArgumentError, ~r/All qubit indices must be different/, fn ->
        Validation.validate_qubits_different!([2, 2, 2])
      end
    end

    test "includes qubit list in error message" do
      assert_raise ArgumentError, ~r/\[0, 1, 0\]/, fn ->
        Validation.validate_qubits_different!([0, 1, 0])
      end
    end
  end

  describe "validate_classical_bit!/2" do
    test "accepts valid classical bit indices" do
      assert Validation.validate_classical_bit!(0, 5) == :ok
      assert Validation.validate_classical_bit!(4, 5) == :ok
    end

    test "rejects negative index" do
      assert_raise Qx.ClassicalBitError, ~r/Classical bit index -1 out of range/, fn ->
        Validation.validate_classical_bit!(-1, 5)
      end
    end

    test "rejects index >= num_bits" do
      assert_raise Qx.ClassicalBitError, ~r/Classical bit index 5 out of range \(0\.\.4\)/, fn ->
        Validation.validate_classical_bit!(5, 5)
      end
    end
  end

  describe "validate_state_shape!/2" do
    test "accepts correct shape" do
      state = Qx.Qubit.new()
      assert Validation.validate_state_shape!(state, 2) == :ok
    end

    test "accepts multi-qubit correct shape" do
      reg = Qx.Register.new(3)
      assert Validation.validate_state_shape!(reg.state, 8) == :ok
    end

    test "rejects wrong shape" do
      state = Qx.Qubit.new()

      assert_raise ArgumentError, ~r/Invalid state shape: expected \{4\}, got \{2\}/, fn ->
        Validation.validate_state_shape!(state, 4)
      end
    end
  end

  describe "validate_parameter!/1" do
    test "accepts integer" do
      assert Validation.validate_parameter!(42) == :ok
    end

    test "accepts float" do
      assert Validation.validate_parameter!(3.14159) == :ok
    end

    test "accepts :math functions" do
      assert Validation.validate_parameter!(:math.pi()) == :ok
    end

    test "rejects string" do
      assert_raise ArgumentError, ~r/Parameter must be a number/, fn ->
        Validation.validate_parameter!("not a number")
      end
    end

    test "rejects atom" do
      assert_raise ArgumentError, ~r/Parameter must be a number/, fn ->
        Validation.validate_parameter!(:atom)
      end
    end

    test "includes invalid value in error message" do
      assert_raise ArgumentError, ~r/"not a number"/, fn ->
        Validation.validate_parameter!("not a number")
      end
    end
  end

  describe "validate_gate_name!/1" do
    test "accepts known single-qubit gates" do
      assert Validation.validate_gate_name!(:h) == :ok
      assert Validation.validate_gate_name!(:x) == :ok
      assert Validation.validate_gate_name!(:y) == :ok
      assert Validation.validate_gate_name!(:z) == :ok
      assert Validation.validate_gate_name!(:s) == :ok
      assert Validation.validate_gate_name!(:t) == :ok
    end

    test "accepts known parameterized gates" do
      assert Validation.validate_gate_name!(:rx) == :ok
      assert Validation.validate_gate_name!(:ry) == :ok
      assert Validation.validate_gate_name!(:rz) == :ok
      assert Validation.validate_gate_name!(:phase) == :ok
    end

    test "accepts known multi-qubit gates" do
      assert Validation.validate_gate_name!(:cx) == :ok
      assert Validation.validate_gate_name!(:cnot) == :ok
      assert Validation.validate_gate_name!(:cz) == :ok
      assert Validation.validate_gate_name!(:ccx) == :ok
      assert Validation.validate_gate_name!(:toffoli) == :ok
    end

    test "rejects unknown gate" do
      assert_raise Qx.GateError, ~r/Unsupported gate: :not_a_gate/, fn ->
        Validation.validate_gate_name!(:not_a_gate)
      end
    end
  end

  describe "validate_num_qubits!/1" do
    test "accepts valid qubit counts" do
      assert Validation.validate_num_qubits!(1) == :ok
      assert Validation.validate_num_qubits!(10) == :ok
      assert Validation.validate_num_qubits!(20) == :ok
    end

    test "rejects zero qubits" do
      assert_raise Qx.QubitCountError, ~r/Invalid qubit count: 0/, fn ->
        Validation.validate_num_qubits!(0)
      end
    end

    test "rejects negative qubits" do
      assert_raise Qx.QubitCountError, ~r/Invalid qubit count/, fn ->
        Validation.validate_num_qubits!(-1)
      end
    end

    test "rejects more than 20 qubits" do
      assert_raise Qx.QubitCountError, ~r/Invalid qubit count: 25/, fn ->
        Validation.validate_num_qubits!(25)
      end
    end

    test "rejects extremely large values" do
      assert_raise Qx.QubitCountError, ~r/Invalid qubit count/, fn ->
        Validation.validate_num_qubits!(1000)
      end
    end
  end

  describe "integration with actual quantum operations" do
    test "validates register creation" do
      reg = Qx.Register.new(2)
      assert Validation.valid_register?(reg)
      assert Validation.validate_num_qubits!(reg.num_qubits) == :ok
    end

    test "validates after gate operations" do
      reg =
        Qx.Register.new(3)
        |> Qx.Register.h(0)
        |> Qx.Register.cx(0, 1)
        |> Qx.Register.ccx(0, 1, 2)

      assert Validation.valid_register?(reg)
    end

    test "validates parameterized gates" do
      angle = :math.pi() / 4
      assert Validation.validate_parameter!(angle) == :ok

      q = Qx.Qubit.new() |> Qx.Qubit.rx(angle)
      assert Validation.valid_qubit?(q)
    end
  end
end
