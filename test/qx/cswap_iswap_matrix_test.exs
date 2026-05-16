defmodule Qx.CswapIswapMatrixTest do
  @moduledoc """
  Explicit matrix-equality tests for the CSWAP (Fredkin) and iSWAP gate
  builders (`Qx.Gates.cswap/4`, `Qx.Gates.iswap/3`).

  Pre-existing `cswap_gate_test.exs` / `iswap_gate_test.exs` only assert
  probabilistic statevector outcomes — a convention error (wrong control
  qubit, or a −i instead of +i phase) could pass every one of them.
  These tests pin the **exact** gate matrix against a hand-built
  reference.

  Convention: OpenQASM 3.0 `cswap` / `iswap` (Qiskit `CSwapGate` /
  `iSwapGate`). MSB qubit order (qubit 0 = most significant bit,
  matching the rest of Qx: `num_qubits - 1 - q`).

    * CSWAP — real 0/1 permutation: with the control |1⟩, the two
      targets swap, e.g. `cswap(0, 1, 2, 3)` swaps |101⟩↔|110⟩
      (indices 5↔6).
    * iSWAP — `[[1,0,0,0],[0,0,i,0],[0,i,0,0],[0,0,0,1]]`: a **+i**
      (not −i) phase on the swapped |01⟩↔|10⟩ amplitudes.

  Equality is asserted **exactly** (entrywise, delta `1.0e-12`), NOT
  up to a global phase: these are fixed canonical matrices with no free
  global phase, and exactness is what catches sign / control-qubit
  errors.
  """

  use ExUnit.Case, async: true

  alias Qx.Gates
  alias Qx.Math

  @delta 1.0e-12

  # Exact entrywise equality of two :c64 tensors. Shape is checked
  # first so a representation regression fails loudly rather than
  # crashing inside the zip.
  defp assert_complex_matrix_equal(actual, expected, message) do
    assert Nx.shape(actual) == Nx.shape(expected),
           "#{message}: shape #{inspect(Nx.shape(actual))} != #{inspect(Nx.shape(expected))}"

    a = actual |> Nx.to_list() |> List.flatten()
    e = expected |> Nx.to_list() |> List.flatten()

    Enum.zip(a, e)
    |> Enum.with_index()
    |> Enum.each(fn {{av, ev}, idx} ->
      assert_in_delta Complex.real(av),
                      Complex.real(ev),
                      @delta,
                      "#{message}: real mismatch at flat index #{idx}"

      assert_in_delta Complex.imag(av),
                      Complex.imag(ev),
                      @delta,
                      "#{message}: imag mismatch at flat index #{idx}"
    end)
  end

  # n×n identity as a plain number list with rows r1 and r2 exchanged
  # (a transposition permutation matrix). Built independently of
  # Qx.Gates so it is a genuine reference, not a tautology.
  defp identity_with_rows_swapped(n, r1, r2) do
    for i <- 0..(n - 1) do
      src =
        cond do
          i == r1 -> r2
          i == r2 -> r1
          true -> i
        end

      for j <- 0..(n - 1), do: if(j == src, do: 1, else: 0)
    end
  end

  describe "CSWAP (Fredkin) matrix" do
    test "cswap(0, 1, 2, 3) is identity with |101⟩↔|110⟩ (rows 5↔6) swapped" do
      reference = Math.complex_matrix(identity_with_rows_swapped(8, 5, 6))

      assert_complex_matrix_equal(
        Gates.cswap(0, 1, 2, 3),
        reference,
        "cswap(0,1,2,3)"
      )
    end

    test "cswap(2, 0, 1, 3) — permuted qubits give a DIFFERENT permutation (rows 3↔5)" do
      # Guards the 'wrong control qubit' failure mode: control = q2,
      # targets q0/q1 ⇒ swap |011⟩↔|101⟩ (indices 3↔5), NOT 5↔6.
      reference = Math.complex_matrix(identity_with_rows_swapped(8, 3, 5))

      assert_complex_matrix_equal(
        Gates.cswap(2, 0, 1, 3),
        reference,
        "cswap(2,0,1,3)"
      )
    end

    test "control |0⟩ subspace is left as the identity (negative-control sanity)" do
      # cswap(0,1,2,3): control = q0 = MSB (bit 2). Indices 0..3 have
      # control |0⟩ and must be untouched identity rows.
      cswap = Gates.cswap(0, 1, 2, 3) |> Nx.to_list()

      for i <- 0..3 do
        cswap
        |> Enum.at(i)
        |> Enum.with_index()
        |> Enum.each(fn {entry, j} ->
          expected_real = if i == j, do: 1.0, else: 0.0
          assert_in_delta Complex.real(entry), expected_real, @delta
          assert_in_delta Complex.imag(entry), 0.0, @delta
        end)
      end
    end
  end

  describe "iSWAP matrix" do
    test "iswap(0, 1, 2) equals [[1,0,0,0],[0,0,i,0],[0,i,0,0],[0,0,0,1]] exactly" do
      i = Complex.new(0, 1)

      reference =
        Math.complex_matrix([
          [1, 0, 0, 0],
          [0, 0, i, 0],
          [0, i, 0, 0],
          [0, 0, 0, 1]
        ])

      assert_complex_matrix_equal(Gates.iswap(0, 1, 2), reference, "iswap(0,1,2)")
    end

    test "swapped amplitudes carry +i, not −i (the sign guard)" do
      iswap = Gates.iswap(0, 1, 2) |> Nx.to_list()

      e12 = iswap |> Enum.at(1) |> Enum.at(2)
      e21 = iswap |> Enum.at(2) |> Enum.at(1)

      # +i ⇒ real 0, imag +1.0. A −i regression would give imag −1.0.
      assert_in_delta Complex.real(e12), 0.0, @delta
      assert_in_delta Complex.imag(e12), 1.0, @delta
      assert_in_delta Complex.real(e21), 0.0, @delta
      assert_in_delta Complex.imag(e21), 1.0, @delta
    end
  end
end
