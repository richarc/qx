defmodule Qx.ControlledGatesTest do
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

  describe "controlled_gate" do
    test "cnot (controlled-X) matrix is correct" do
      # CNOT(0, 1) in 2-qubit system
      # Control: 0, Target: 1
      # |00> -> |00> (Index 0 -> 0)
      # |01> -> |11> (Index 1 -> 3)  <-- Wait, qubit 0 is MSB?
      # Let's check convention.
      # Qx.Format.basis_state(1, 2) -> "|01>".
      # If qubit 0 is MSB (leftmost), then |01> means q0=0, q1=1.
      # If q0 is control, q0=0 -> Identity.
      # So |01> -> |01>.

      # If q0 is control, q1 is target.
      # |10> (Index 2): q0=1, q1=0. Target flips -> q1=1. Result |11> (Index 3).
      # |11> (Index 3): q0=1, q1=1. Target flips -> q1=0. Result |10> (Index 2).

      cnot = Gates.cnot(0, 1, 2)

      # Check M[2, 3] and M[3, 2] should be 1 (swap indices 2 and 3)
      # M[2, 2] and M[3, 3] should be 0

      assert complex_approx_equal?(matrix_elem(cnot, 2, 3), C.new(1.0, 0.0))
      assert complex_approx_equal?(matrix_elem(cnot, 3, 2), C.new(1.0, 0.0))
      assert complex_approx_equal?(matrix_elem(cnot, 2, 2), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(cnot, 3, 3), C.new(0.0, 0.0))

      # Check Identity block (q0=0)
      # |00> -> |00> (Index 0)
      # |01> -> |01> (Index 1)
      assert complex_approx_equal?(matrix_elem(cnot, 0, 0), C.new(1.0, 0.0))
      assert complex_approx_equal?(matrix_elem(cnot, 1, 1), C.new(1.0, 0.0))
      assert complex_approx_equal?(matrix_elem(cnot, 0, 1), C.new(0.0, 0.0))
      assert complex_approx_equal?(matrix_elem(cnot, 1, 0), C.new(0.0, 0.0))
    end

    test "controlled-Z matrix is correct" do
      # CZ(0, 1)
      # |11> -> -|11>
      # Index 3 -> -Index 3

      cz = Gates.controlled_gate(Gates.pauli_z(), 0, 1, 2)

      # M[3, 3] should be -1
      assert complex_approx_equal?(matrix_elem(cz, 3, 3), C.new(-1.0, 0.0))

      # M[2, 2] (|10>) -> |10> (Z on |0> is |0>)
      assert complex_approx_equal?(matrix_elem(cz, 2, 2), C.new(1.0, 0.0))

      # M[0, 0] and M[1, 1] should be 1 (Identity block)
      assert complex_approx_equal?(matrix_elem(cz, 0, 0), C.new(1.0, 0.0))
      assert complex_approx_equal?(matrix_elem(cz, 1, 1), C.new(1.0, 0.0))
    end

    test "controlled-Hadamard matrix is correct" do
      # CH(0, 1)
      # |10> -> 1/sqrt(2)(|10> + |11>)
      # |11> -> 1/sqrt(2)(|10> - |11>)

      ch = Gates.controlled_gate(Gates.hadamard(), 0, 1, 2)
      inv_sqrt2 = 1.0 / :math.sqrt(2)

      # Check block for q0=1 (indices 2, 3)
      # M[2, 2] = H[0, 0] = 1/sqrt(2)
      # M[2, 3] = H[0, 1] = 1/sqrt(2)
      # M[3, 2] = H[1, 0] = 1/sqrt(2)
      # M[3, 3] = H[1, 1] = -1/sqrt(2)

      assert complex_approx_equal?(matrix_elem(ch, 2, 2), C.new(inv_sqrt2, 0.0))
      assert complex_approx_equal?(matrix_elem(ch, 2, 3), C.new(inv_sqrt2, 0.0))
      assert complex_approx_equal?(matrix_elem(ch, 3, 2), C.new(inv_sqrt2, 0.0))
      assert complex_approx_equal?(matrix_elem(ch, 3, 3), C.new(-inv_sqrt2, 0.0))
    end
  end
end
