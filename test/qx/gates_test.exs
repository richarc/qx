defmodule Qx.GatesTest do
  use ExUnit.Case

  alias Complex, as: C
  alias Qx.Gates

  defp complex_approx_equal?(c1, c2, tolerance \\ 0.01) do
    abs(Complex.real(c1) - Complex.real(c2)) < tolerance and
      abs(Complex.imag(c1) - Complex.imag(c2)) < tolerance
  end

  defp matrix_elem(matrix, row, col) do
    Nx.to_number(matrix[row][col])
  end

  describe "Pauli gates" do
    test "pauli_x has correct matrix elements" do
      x = Gates.pauli_x()
      assert Nx.shape(x) == {2, 2}

      # X = [[0, 1], [1, 0]]
      assert complex_approx_equal?(matrix_elem(x, 0, 0), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(x, 0, 1), C.new(1.0, 0.0))
      assert complex_approx_equal?(matrix_elem(x, 1, 0), C.new(1.0, 0.0))
      assert complex_approx_equal?(matrix_elem(x, 1, 1), C.new(0.0, 0.0))
    end

    test "pauli_y has correct matrix elements" do
      y = Gates.pauli_y()
      assert Nx.shape(y) == {2, 2}

      # Y = [[0, -i], [i, 0]]
      assert complex_approx_equal?(matrix_elem(y, 0, 0), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(y, 0, 1), C.new(0.0, -1.0))
      assert complex_approx_equal?(matrix_elem(y, 1, 0), C.new(0.0, 1.0))
      assert complex_approx_equal?(matrix_elem(y, 1, 1), C.new(0.0, 0.0))
    end

    test "pauli_z has correct matrix elements" do
      z = Gates.pauli_z()
      assert Nx.shape(z) == {2, 2}

      # Z = [[1, 0], [0, -1]]
      assert complex_approx_equal?(matrix_elem(z, 0, 0), C.new(1.0, 0.0))
      assert complex_approx_equal?(matrix_elem(z, 0, 1), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(z, 1, 0), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(z, 1, 1), C.new(-1.0, 0.0))
    end
  end

  describe "Hadamard gate" do
    test "has correct matrix elements" do
      h = Gates.hadamard()
      assert Nx.shape(h) == {2, 2}

      inv_sqrt2 = 1.0 / :math.sqrt(2)

      assert complex_approx_equal?(matrix_elem(h, 0, 0), C.new(inv_sqrt2, 0.0))
      assert complex_approx_equal?(matrix_elem(h, 0, 1), C.new(inv_sqrt2, 0.0))
      assert complex_approx_equal?(matrix_elem(h, 1, 0), C.new(inv_sqrt2, 0.0))
      assert complex_approx_equal?(matrix_elem(h, 1, 1), C.new(-inv_sqrt2, 0.0))
    end
  end

  describe "S and T gates" do
    test "s_gate has correct matrix elements" do
      s = Gates.s_gate()
      assert Nx.shape(s) == {2, 2}

      # S = [[1, 0], [0, i]]
      assert complex_approx_equal?(matrix_elem(s, 0, 0), C.new(1.0, 0.0))
      assert complex_approx_equal?(matrix_elem(s, 0, 1), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(s, 1, 0), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(s, 1, 1), C.new(0.0, 1.0))
    end

    test "t_gate has correct matrix elements" do
      t = Gates.t_gate()
      assert Nx.shape(t) == {2, 2}

      # T = [[1, 0], [0, e^(iπ/4)]]
      # e^(iπ/4) = cos(π/4) + i*sin(π/4)
      e_i_pi_4 = C.new(:math.cos(:math.pi() / 4), :math.sin(:math.pi() / 4))

      assert complex_approx_equal?(matrix_elem(t, 0, 0), C.new(1.0, 0.0))
      assert complex_approx_equal?(matrix_elem(t, 0, 1), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(t, 1, 0), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(t, 1, 1), e_i_pi_4)
    end
  end

  describe "Rotation gates" do
    test "rx creates correct matrix for π rotation" do
      rx = Gates.rx(:math.pi())
      assert Nx.shape(rx) == {2, 2}

      # RX(π) should be approximately [[0, -i], [-i, 0]]
      assert complex_approx_equal?(matrix_elem(rx, 0, 0), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(rx, 1, 1), C.new(0.0, 0.0))
    end

    test "ry creates correct matrix for π/2 rotation" do
      ry = Gates.ry(:math.pi() / 2)
      assert Nx.shape(ry) == {2, 2}

      # RY(π/2) should be approximately 1/√2 * [[1, -1], [1, 1]]
      inv_sqrt2 = 1.0 / :math.sqrt(2)

      assert complex_approx_equal?(matrix_elem(ry, 0, 0), C.new(inv_sqrt2, 0.0))
      assert complex_approx_equal?(matrix_elem(ry, 0, 1), C.new(-inv_sqrt2, 0.0))
      assert complex_approx_equal?(matrix_elem(ry, 1, 0), C.new(inv_sqrt2, 0.0))
      assert complex_approx_equal?(matrix_elem(ry, 1, 1), C.new(inv_sqrt2, 0.0))
    end

    test "rz creates correct matrix for π rotation" do
      rz = Gates.rz(:math.pi())
      assert Nx.shape(rz) == {2, 2}

      # RZ(π) should be approximately [[-i, 0], [0, i]]
      assert complex_approx_equal?(matrix_elem(rz, 0, 0), C.new(0.0, -1.0))
      assert complex_approx_equal?(matrix_elem(rz, 0, 1), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(rz, 1, 0), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(rz, 1, 1), C.new(0.0, 1.0))
    end
  end

  describe "Phase gate" do
    test "creates correct matrix for π/4 phase" do
      phase = Gates.phase(:math.pi() / 4)
      assert Nx.shape(phase) == {2, 2}

      # Phase gate: [[1, 0], [0, e^(iφ)]]
      e_i_phi = C.new(:math.cos(:math.pi() / 4), :math.sin(:math.pi() / 4))

      assert complex_approx_equal?(matrix_elem(phase, 0, 0), C.new(1.0, 0.0))
      assert complex_approx_equal?(matrix_elem(phase, 0, 1), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(phase, 1, 0), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(phase, 1, 1), e_i_phi)
    end
  end

  describe "Identity gate" do
    test "returns 2x2 identity matrix" do
      id = Gates.identity()
      assert Nx.shape(id) == {2, 2}

      assert complex_approx_equal?(matrix_elem(id, 0, 0), C.new(1.0, 0.0))
      assert complex_approx_equal?(matrix_elem(id, 0, 1), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(id, 1, 0), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(id, 1, 1), C.new(1.0, 0.0))
    end
  end

  describe "Gate properties" do
    test "Pauli gates are Hermitian" do
      # Pauli gates should equal their conjugate transpose
      for gate <- [Gates.pauli_x(), Gates.pauli_y(), Gates.pauli_z()] do
        ct = Nx.transpose(Nx.conjugate(gate))

        # Check all elements match
        for i <- 0..1, j <- 0..1 do
          assert complex_approx_equal?(
                   matrix_elem(gate, i, j),
                   matrix_elem(ct, i, j)
                 )
        end
      end
    end

    test "X^2 = I" do
      x = Gates.pauli_x()
      x_squared = Nx.dot(x, x)
      id = Gates.identity()

      for i <- 0..1, j <- 0..1 do
        assert complex_approx_equal?(
                 matrix_elem(x_squared, i, j),
                 matrix_elem(id, i, j)
               )
      end
    end

    test "Y^2 = I" do
      y = Gates.pauli_y()
      y_squared = Nx.dot(y, y)
      id = Gates.identity()

      for i <- 0..1, j <- 0..1 do
        assert complex_approx_equal?(
                 matrix_elem(y_squared, i, j),
                 matrix_elem(id, i, j)
               )
      end
    end

    test "Z^2 = I" do
      z = Gates.pauli_z()
      z_squared = Nx.dot(z, z)
      id = Gates.identity()

      for i <- 0..1, j <- 0..1 do
        assert complex_approx_equal?(
                 matrix_elem(z_squared, i, j),
                 matrix_elem(id, i, j)
               )
      end
    end

    test "H^2 = I (Hadamard is self-inverse)" do
      h = Gates.hadamard()
      h_squared = Nx.dot(h, h)
      id = Gates.identity()

      for i <- 0..1, j <- 0..1 do
        assert complex_approx_equal?(
                 matrix_elem(h_squared, i, j),
                 matrix_elem(id, i, j)
               )
      end
    end

    test "S^4 = I" do
      s = Gates.s_gate()
      s4 = Nx.dot(Nx.dot(Nx.dot(s, s), s), s)
      id = Gates.identity()

      for i <- 0..1, j <- 0..1 do
        assert complex_approx_equal?(
                 matrix_elem(s4, i, j),
                 matrix_elem(id, i, j)
               )
      end
    end
  end
end
