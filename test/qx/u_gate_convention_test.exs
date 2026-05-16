defmodule Qx.UGateConventionTest do
  @moduledoc """
  Convention / regression lock for `Qx.Gates.u/3`.

  These are **characterization tests**, not red→green TDD: the U gate is
  already correctly implemented following the OpenQASM 3.0 / Qiskit `UGate`
  convention

      U(θ,φ,λ) = [[cos(θ/2),          -e^(iλ)·sin(θ/2) ],
                  [e^(iφ)·sin(θ/2),  e^(i(φ+λ))·cos(θ/2)]]

  Every assertion below is expected to **pass on first run** against the
  current implementation. They lock the convention in place so a future
  refactor that silently changes the parameterisation is caught.

  All comparisons are global-phase-tolerant (see
  `assert_unitary_equal_up_to_phase/3`), which keeps them robust regardless
  of any overall phase a refactor might introduce.
  """
  use ExUnit.Case, async: true

  alias Qx.Gates

  @delta 1.0e-6
  @pi :math.pi()

  describe "U gate special cases (OpenQASM 3.0 / Qiskit UGate convention)" do
    test "U(π, 0, π) == X" do
      assert_unitary_equal_up_to_phase(
        Gates.u(:math.pi(), 0, :math.pi()),
        Gates.pauli_x(),
        "U(π,0,π) should equal Pauli-X"
      )
    end

    test "U(π/2, 0, π) == H" do
      assert_unitary_equal_up_to_phase(
        Gates.u(:math.pi() / 2, 0, :math.pi()),
        Gates.hadamard(),
        "U(π/2,0,π) should equal Hadamard"
      )
    end

    test "U(0, 0, 0) == I" do
      assert_unitary_equal_up_to_phase(
        Gates.u(0, 0, 0),
        Gates.identity(),
        "U(0,0,0) should equal Identity"
      )
    end

    test "U(π, π/2, π/2) == Y" do
      assert_unitary_equal_up_to_phase(
        Gates.u(:math.pi(), :math.pi() / 2, :math.pi() / 2),
        Gates.pauli_y(),
        "U(π,π/2,π/2) should equal Pauli-Y"
      )
    end
  end

  describe "U decomposition identity U(θ,φ,λ) = RZ(φ)·RY(θ)·RZ(λ) (up to global phase)" do
    # rz(phi) is the leftmost matrix in the product RZ(φ)·RY(θ)·RZ(λ); as an
    # operator it acts last on the state vector. Nx.dot is left-associative,
    # so the pipeline below builds exactly that product.
    for {theta, phi, lambda} <- [
          {0.7, 1.1, 0.3},
          {@pi / 3, @pi / 5, -@pi / 4},
          {2.0, 0.0, 1.0}
        ] do
      test "U(#{theta}, #{phi}, #{lambda}) ≈ RZ(φ)·RY(θ)·RZ(λ)" do
        theta = unquote(theta)
        phi = unquote(phi)
        lambda = unquote(lambda)

        decomposed =
          Gates.rz(phi)
          |> Nx.dot(Gates.ry(theta))
          |> Nx.dot(Gates.rz(lambda))

        assert_unitary_equal_up_to_phase(
          Gates.u(theta, phi, lambda),
          decomposed,
          "U(#{theta},#{phi},#{lambda}) should match RZ·RY·RZ up to global phase"
        )
      end
    end
  end

  # Asserts two 2×2 complex unitaries are equal up to a single global phase
  # factor: there exists |r| = 1 such that actual = r · reference, entrywise.
  defp assert_unitary_equal_up_to_phase(actual, reference, message) do
    a = actual |> Nx.to_list() |> List.flatten()
    b = reference |> Nx.to_list() |> List.flatten()

    {a_ref, b_ref} =
      Enum.zip(a, b)
      |> Enum.find(fn {av, bv} ->
        Complex.abs(bv) > 1.0e-9 and Complex.abs(av) > 1.0e-9
      end)
      |> case do
        nil -> flunk("#{message}: reference matrix is all-zero")
        pair -> pair
      end

    ratio = Complex.divide(a_ref, b_ref)

    assert_in_delta Complex.abs(ratio),
                    1.0,
                    @delta,
                    "#{message}: phase ratio magnitude #{Complex.abs(ratio)} ≉ 1"

    Enum.zip(a, b)
    |> Enum.each(fn {av, bv} ->
      expected = Complex.multiply(ratio, bv)

      assert_in_delta Complex.real(av),
                      Complex.real(expected),
                      @delta,
                      "#{message}: real part mismatch"

      assert_in_delta Complex.imag(av),
                      Complex.imag(expected),
                      @delta,
                      "#{message}: imag part mismatch"
    end)
  end
end
