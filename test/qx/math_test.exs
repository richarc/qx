defmodule Qx.MathTest do
  use ExUnit.Case
  doctest Qx.Math

  alias Qx.Math
  alias Complex, as: C

  defp approx_equal?(a, b, tolerance \\ 0.01) do
    # Handle complex numbers
    a_val = if is_struct(a, Complex), do: Complex.abs(a), else: a
    b_val = if is_struct(b, Complex), do: Complex.abs(b), else: b
    abs(a_val - b_val) < tolerance
  end

  defp tensor_approx_equal?(t1, t2, tolerance) do
    l1 = Nx.to_flat_list(t1)
    l2 = Nx.to_flat_list(t2)
    Enum.zip(l1, l2) |> Enum.all?(fn {a, b} -> approx_equal?(a, b, tolerance) end)
  end

  describe "kron/2" do
    test "computes Kronecker product of 2x2 matrices" do
      a = Nx.tensor([[1, 2], [3, 4]])
      b = Nx.tensor([[0, 5], [6, 7]])
      result = Math.kron(a, b)

      expected = Nx.tensor([
        [0, 5, 0, 10],
        [6, 7, 12, 14],
        [0, 15, 0, 20],
        [18, 21, 24, 28]
      ])

      assert tensor_approx_equal?(result, expected, 0.01)
    end

    test "kron product with identity gives block diagonal" do
      a = Nx.tensor([[1.0, 0.0], [0.0, 1.0]])
      b = Nx.tensor([[2.0, 3.0], [4.0, 5.0]])
      result = Math.kron(a, b)

      assert Nx.shape(result) == {4, 4}
      # First block should be b
      assert approx_equal?(Nx.to_number(result[0][0]), 2.0)
      assert approx_equal?(Nx.to_number(result[0][1]), 3.0)
    end

    test "kron is associative" do
      a = Nx.tensor([[1.0, 2.0], [3.0, 4.0]])
      b = Nx.tensor([[5.0, 6.0], [7.0, 8.0]])
      c = Nx.tensor([[9.0, 10.0], [11.0, 12.0]])

      ab_c = Math.kron(Math.kron(a, b), c)
      a_bc = Math.kron(a, Math.kron(b, c))

      assert tensor_approx_equal?(ab_c, a_bc, 0.01)
    end
  end

  describe "normalize/1" do
    test "normalizes simple vector" do
      state = Nx.tensor([1.0, 1.0])
      normalized = Math.normalize(state)
      list = Nx.to_flat_list(normalized)

      assert approx_equal?(Enum.at(list, 0), 0.707, 0.01)
      assert approx_equal?(Enum.at(list, 1), 0.707, 0.01)
    end

    test "normalized vector has unit norm" do
      state = Nx.tensor([3.0, 4.0])
      normalized = Math.normalize(state)

      probs = Math.probabilities(normalized)
      norm = Nx.sqrt(Nx.sum(probs)) |> Nx.to_number()
      assert approx_equal?(norm, 1.0, 1.0e-6)
    end

    test "already normalized vector unchanged" do
      state = Nx.tensor([0.6, 0.8])
      normalized = Math.normalize(state)

      assert tensor_approx_equal?(state, normalized, 0.01)
    end

    test "works with complex tensors" do
      state = Nx.tensor([C.new(1.0, 0.0), C.new(1.0, 0.0)], type: :c64)
      normalized = Math.normalize(state)

      probs = Math.probabilities(normalized)
      total = Nx.sum(probs) |> Nx.to_number()
      assert approx_equal?(total, 1.0, 1.0e-6)
    end
  end

  describe "inner_product/2" do
    test "orthogonal states have zero inner product" do
      state1 = Nx.tensor([1.0, 0.0])
      state2 = Nx.tensor([0.0, 1.0])
      result = Math.inner_product(state1, state2) |> Nx.to_number()

      assert approx_equal?(result, 0.0)
    end

    test "identical states have inner product 1" do
      state = Nx.tensor([0.707, 0.707])
      result = Math.inner_product(state, state) |> Nx.to_number()

      assert approx_equal?(result, 0.9998, 0.01)
    end

    test "works with complex states" do
      state1 = Nx.tensor([C.new(1.0, 0.0), C.new(0.0, 0.0)], type: :c64)
      state2 = Nx.tensor([C.new(0.0, 0.0), C.new(1.0, 0.0)], type: :c64)
      result = Math.inner_product(state1, state2)

      # Convert complex result to number
      result_num = Nx.to_number(result)
      assert Complex.abs(result_num) < 0.01
    end
  end

  describe "outer_product/2" do
    test "creates matrix from two vectors" do
      state1 = Nx.tensor([1.0, 0.0])
      state2 = Nx.tensor([0.0, 1.0])
      result = Math.outer_product(state1, state2)

      assert Nx.shape(result) == {2, 2}
      assert approx_equal?(Nx.to_number(result[0][1]), 1.0)
      assert approx_equal?(Nx.to_number(result[1][1]), 0.0)
    end

    test "outer product of normalized states has trace 1" do
      state1 = Nx.tensor([0.707, 0.707])
      state2 = Nx.tensor([0.707, 0.707])
      result = Math.outer_product(state1, state2)

      trace_val = Math.trace(result) |> Nx.to_number()
      assert approx_equal?(trace_val, 1.0, 0.01)
    end
  end

  describe "apply_gate/2" do
    test "applies Pauli-X gate" do
      state = Nx.tensor([1.0, 0.0])
      x_gate = Nx.tensor([[0.0, 1.0], [1.0, 0.0]])
      result = Math.apply_gate(x_gate, state)

      list = Nx.to_flat_list(result)
      assert approx_equal?(Enum.at(list, 0), 0.0)
      assert approx_equal?(Enum.at(list, 1), 1.0)
    end

    test "applies Hadamard gate" do
      state = Nx.tensor([1.0, 0.0])
      h_gate = Nx.tensor([[1.0, 1.0], [1.0, -1.0]]) |> Nx.divide(Nx.sqrt(2.0))
      result = Math.apply_gate(h_gate, state)

      list = Nx.to_flat_list(result)
      assert approx_equal?(Enum.at(list, 0), 0.707, 0.01)
      assert approx_equal?(Enum.at(list, 1), 0.707, 0.01)
    end
  end

  describe "probabilities/1" do
    test "computes probabilities from real state" do
      state = Nx.tensor([0.6, 0.8])
      probs = Math.probabilities(state)

      list = Nx.to_flat_list(probs)
      assert approx_equal?(Enum.at(list, 0), 0.36, 0.01)
      assert approx_equal?(Enum.at(list, 1), 0.64, 0.01)
    end

    test "computes probabilities from complex state" do
      state = Nx.tensor([C.new(0.707, 0.0), C.new(0.0, 0.707)], type: :c64)
      probs = Math.probabilities(state)

      list = Nx.to_flat_list(probs)
      assert approx_equal?(Enum.at(list, 0), 0.5, 0.01)
      assert approx_equal?(Enum.at(list, 1), 0.5, 0.01)
    end

    test "probabilities sum to 1 for normalized state" do
      state = Nx.tensor([0.6, 0.8])
      probs = Math.probabilities(state)

      total = Nx.sum(probs) |> Nx.to_number()
      assert approx_equal?(total, 1.0, 0.01)
    end
  end

  describe "complex/2" do
    test "creates complex number" do
      c = Math.complex(1.0, 2.0)
      assert Complex.real(c) == 1.0
      assert Complex.imag(c) == 2.0
    end

    test "defaults imaginary part to zero" do
      c = Math.complex(3.0)
      assert Complex.real(c) == 3.0
      assert Complex.imag(c) == 0.0
    end
  end

  describe "complex_to_tensor/1" do
    test "converts complex to tensor" do
      c = C.new(1.0, 2.0)
      tensor = Math.complex_to_tensor(c)

      list = Nx.to_flat_list(tensor)
      assert approx_equal?(Enum.at(list, 0), 1.0)
      assert approx_equal?(Enum.at(list, 1), 2.0)
    end
  end

  describe "tensor_to_complex/1" do
    test "converts tensor to complex" do
      tensor = Nx.tensor([3.0, 4.0])
      c = Math.tensor_to_complex(tensor)

      assert Complex.real(c) == 3.0
      assert Complex.imag(c) == 4.0
    end

    test "round trip conversion" do
      original = C.new(5.0, 6.0)
      tensor = Math.complex_to_tensor(original)
      result = Math.tensor_to_complex(tensor)

      assert Complex.real(result) == Complex.real(original)
      assert Complex.imag(result) == Complex.imag(original)
    end
  end

  describe "complex_matrix/1" do
    test "creates matrix from real numbers" do
      matrix = Math.complex_matrix([[1, 0], [0, 1]])
      assert Nx.shape(matrix) == {2, 2}
      assert Nx.type(matrix) == {:c, 64}
    end

    test "creates matrix from complex numbers" do
      matrix = Math.complex_matrix([[C.new(1.0, 0.0), C.new(0.0, 1.0)],
                                     [C.new(0.0, -1.0), C.new(1.0, 0.0)]])
      assert Nx.shape(matrix) == {2, 2}
      assert Nx.type(matrix) == {:c, 64}
    end

    test "creates matrix from mixed real and complex" do
      matrix = Math.complex_matrix([[1, C.new(0.0, 1.0)],
                                     [C.new(0.0, -1.0), 0]])
      assert Nx.shape(matrix) == {2, 2}
      assert Nx.type(matrix) == {:c, 64}
    end
  end

  describe "trace/1" do
    test "computes trace of identity matrix" do
      matrix = Nx.tensor([[1.0, 0.0], [0.0, 1.0]])
      trace_val = Math.trace(matrix) |> Nx.to_number()

      assert approx_equal?(trace_val, 2.0)
    end

    test "computes trace of arbitrary matrix" do
      matrix = Nx.tensor([[1.0, 2.0], [3.0, 4.0]])
      trace_val = Math.trace(matrix) |> Nx.to_number()

      assert approx_equal?(trace_val, 5.0)
    end
  end

  describe "identity/1" do
    test "creates 2x2 identity matrix" do
      id = Math.identity(2)
      assert Nx.shape(id) == {2, 2}
      assert approx_equal?(Nx.to_number(id[0][0]), 1.0)
      assert approx_equal?(Nx.to_number(id[1][1]), 1.0)
      assert approx_equal?(Nx.to_number(id[0][1]), 0.0)
      assert approx_equal?(Nx.to_number(id[1][0]), 0.0)
    end

    test "creates NxN identity matrix" do
      id = Math.identity(4)
      assert Nx.shape(id) == {4, 4}

      # Check diagonal is all 1s
      for i <- 0..3 do
        assert approx_equal?(Nx.to_number(id[i][i]), 1.0)
      end
    end
  end

  describe "basis_state/2" do
    test "creates |0⟩ state" do
      state = Math.basis_state(0, 2)
      list = Nx.to_flat_list(state)

      assert approx_equal?(Enum.at(list, 0), 1.0)
      assert approx_equal?(Enum.at(list, 1), 0.0)
    end

    test "creates |1⟩ state" do
      state = Math.basis_state(1, 2)
      list = Nx.to_flat_list(state)

      assert approx_equal?(Enum.at(list, 0), 0.0)
      assert approx_equal?(Enum.at(list, 1), 1.0)
    end

    test "creates basis state in larger space" do
      state = Math.basis_state(3, 8)
      list = Nx.to_flat_list(state)

      assert approx_equal?(Enum.at(list, 3), 1.0)
      assert Enum.sum(List.delete_at(list, 3)) == 0.0
    end
  end

  describe "is_unitary?/1" do
    test "Pauli-X is unitary" do
      pauli_x = Nx.tensor([[0.0, 1.0], [1.0, 0.0]])
      assert Math.is_unitary?(pauli_x)
    end

    test "Hadamard is unitary" do
      h = Nx.tensor([[1.0, 1.0], [1.0, -1.0]]) |> Nx.divide(Nx.sqrt(2.0))
      assert Math.is_unitary?(h)
    end

    test "identity is unitary" do
      id = Math.identity(2)
      assert Math.is_unitary?(id)
    end

    test "non-square matrix is not unitary" do
      matrix = Nx.tensor([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0]])
      refute Math.is_unitary?(matrix)
    end

    test "non-unitary matrix returns false" do
      matrix = Nx.tensor([[2.0, 0.0], [0.0, 2.0]])
      refute Math.is_unitary?(matrix)
    end
  end
end
