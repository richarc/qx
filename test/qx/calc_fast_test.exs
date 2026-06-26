defmodule Qx.CalcFastTest do
  use ExUnit.Case, async: true

  # `Qx.CalcFast` is internal (`@moduledoc false`) and performs NO input
  # validation by design — typed `Qx.*Error`s live upstream in
  # `Qx.Validation` / `Qx.Operations`, reached only through the public API.
  # This file pins the kernels' own observable behaviour (single-qubit gate,
  # CNOT, CSWAP, Toffoli) as a regression net for the v0.8.2 kernel rewrite
  # (gather/`select` → reshape + 2×2 contraction), which is otherwise covered
  # only indirectly through `Qx.Calc` / `Qx.Simulation`. Invalid-input tests
  # are *characterization* tests of the raw behaviour, not typed-error
  # assertions (see plan scratchpad D2).

  alias Complex, as: C
  alias Qx.{CalcFast, Gates}

  @tolerance 1.0e-6

  defp complex_approx_equal?(c1, c2, tolerance) do
    abs(Complex.real(c1) - Complex.real(c2)) < tolerance and
      abs(Complex.imag(c1) - Complex.imag(c2)) < tolerance
  end

  defp state_approx_equal?(state1, state2, tolerance \\ @tolerance) do
    list1 = Nx.to_flat_list(state1)
    list2 = Nx.to_flat_list(state2)

    Enum.zip(list1, list2)
    |> Enum.all?(fn {c1, c2} -> complex_approx_equal?(c1, c2, tolerance) end)
  end

  # Computational basis state |index⟩ in an n-qubit system (MSB convention).
  defp basis_state(index, num_qubits) do
    dim = Integer.pow(2, num_qubits)

    amps =
      for i <- 0..(dim - 1) do
        if i == index, do: C.new(1.0, 0.0), else: C.new(0.0, 0.0)
      end

    Nx.tensor(amps, type: :c64)
  end

  describe "apply_single_qubit_gate/4 — single-qubit Nx.dot head (num_qubits == 1)" do
    test "Pauli-X flips |0⟩ → |1⟩ and |1⟩ → |0⟩" do
      x = Gates.pauli_x()

      assert state_approx_equal?(
               CalcFast.apply_single_qubit_gate(basis_state(0, 1), x, 0, 1),
               basis_state(1, 1)
             )

      assert state_approx_equal?(
               CalcFast.apply_single_qubit_gate(basis_state(1, 1), x, 0, 1),
               basis_state(0, 1)
             )
    end

    test "Hadamard on |0⟩ → (|0⟩+|1⟩)/√2 and on |1⟩ → (|0⟩-|1⟩)/√2" do
      inv_sqrt2 = 1.0 / :math.sqrt(2)
      h = Gates.hadamard()

      on_zero = CalcFast.apply_single_qubit_gate(basis_state(0, 1), h, 0, 1)
      expected_zero = Nx.tensor([C.new(inv_sqrt2, 0.0), C.new(inv_sqrt2, 0.0)], type: :c64)
      assert state_approx_equal?(on_zero, expected_zero)

      on_one = CalcFast.apply_single_qubit_gate(basis_state(1, 1), h, 0, 1)
      expected_one = Nx.tensor([C.new(inv_sqrt2, 0.0), C.new(-inv_sqrt2, 0.0)], type: :c64)
      assert state_approx_equal?(on_one, expected_one)
    end

    test "identity leaves |0⟩ and |1⟩ unchanged" do
      id = Gates.identity()

      assert state_approx_equal?(
               CalcFast.apply_single_qubit_gate(basis_state(0, 1), id, 0, 1),
               basis_state(0, 1)
             )

      assert state_approx_equal?(
               CalcFast.apply_single_qubit_gate(basis_state(1, 1), id, 0, 1),
               basis_state(1, 1)
             )
    end
  end

  describe "apply_single_qubit_gate/4 — multi-qubit compiled head (MSB convention)" do
    test "X on qubit 0 (MSB) of 2-qubit |00⟩ → |10⟩" do
      result = CalcFast.apply_single_qubit_gate(basis_state(0, 2), Gates.pauli_x(), 0, 2)
      # |10⟩ is index 2 (qubit 0 is the most-significant bit).
      assert state_approx_equal?(result, basis_state(2, 2))
    end

    test "X on qubit 1 (LSB) of 2-qubit |00⟩ → |01⟩" do
      result = CalcFast.apply_single_qubit_gate(basis_state(0, 2), Gates.pauli_x(), 1, 2)
      # |01⟩ is index 1.
      assert state_approx_equal?(result, basis_state(1, 2))
    end

    test "X on middle qubit (qubit 1 of 3) of |000⟩ → |010⟩" do
      result = CalcFast.apply_single_qubit_gate(basis_state(0, 3), Gates.pauli_x(), 1, 3)
      # |010⟩ is index 2.
      assert state_approx_equal?(result, basis_state(2, 3))
    end

    test "identity leaves a non-trivial 3-qubit superposition unchanged (pairing-bug guard)" do
      # Distinct amplitudes per basis state so a mispaired update would show.
      amps = for i <- 0..7, do: C.new(i + 1.0, i * 0.5)
      state = Nx.tensor(amps, type: :c64)

      result = CalcFast.apply_single_qubit_gate(state, Gates.identity(), 1, 3)

      assert state_approx_equal?(result, state)
    end

    test "H on qubit 0 of 2-qubit |00⟩ → (|00⟩+|10⟩)/√2 (compiled-path amplitudes)" do
      inv_sqrt2 = 1.0 / :math.sqrt(2)
      result = CalcFast.apply_single_qubit_gate(basis_state(0, 2), Gates.hadamard(), 0, 2)

      expected =
        Nx.tensor(
          [C.new(inv_sqrt2, 0.0), C.new(0.0, 0.0), C.new(inv_sqrt2, 0.0), C.new(0.0, 0.0)],
          type: :c64
        )

      assert state_approx_equal?(result, expected)
    end
  end

  describe "apply_cnot/4" do
    test "control=0/target=1 truth table over all 2-qubit basis states" do
      # |00⟩→|00⟩, |01⟩→|01⟩, |10⟩→|11⟩, |11⟩→|10⟩
      expected = %{0 => 0, 1 => 1, 2 => 3, 3 => 2}

      Enum.each(expected, fn {input, output} ->
        result = CalcFast.apply_cnot(basis_state(input, 2), 0, 1, 2)
        assert state_approx_equal?(result, basis_state(output, 2)), "CNOT(0,1) |#{input}⟩"
      end)
    end

    test "reversed ordering control=1/target=0 over all 2-qubit basis states" do
      # control is qubit 1 (LSB), target is qubit 0 (MSB).
      # |00⟩→|00⟩, |01⟩→|11⟩, |10⟩→|10⟩, |11⟩→|01⟩
      expected = %{0 => 0, 1 => 3, 2 => 2, 3 => 1}

      Enum.each(expected, fn {input, output} ->
        result = CalcFast.apply_cnot(basis_state(input, 2), 1, 0, 2)
        assert state_approx_equal?(result, basis_state(output, 2)), "CNOT(1,0) |#{input}⟩"
      end)
    end

    test "non-adjacent control 0 / target 2: full 3-qubit truth table" do
      # control qubit 0 (MSB), target qubit 2 (LSB): flip q2 iff q0 = 1.
      # Controls-off states (0..3) must pass through unchanged.
      expected = %{0 => 0, 1 => 1, 2 => 2, 3 => 3, 4 => 5, 5 => 4, 6 => 7, 7 => 6}

      Enum.each(expected, fn {input, output} ->
        result = CalcFast.apply_cnot(basis_state(input, 3), 0, 2, 3)
        assert state_approx_equal?(result, basis_state(output, 3)), "CNOT(0,2) |#{input}⟩"
      end)
    end

    test "H(q0) then CNOT(0,1) on |00⟩ → Bell (|00⟩+|11⟩)/√2" do
      inv_sqrt2 = 1.0 / :math.sqrt(2)

      bell =
        basis_state(0, 2)
        |> CalcFast.apply_single_qubit_gate(Gates.hadamard(), 0, 2)
        |> CalcFast.apply_cnot(0, 1, 2)

      expected =
        Nx.tensor(
          [C.new(inv_sqrt2, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(inv_sqrt2, 0.0)],
          type: :c64
        )

      assert state_approx_equal?(bell, expected)
    end
  end

  describe "apply_cswap/5" do
    test "full 3-qubit truth table: swap targets iff control = 1 and targets differ" do
      # control qubit 0, targets qubit 1 and qubit 2.
      # Swap only when q0 = 1 AND q1 ≠ q2 → states |101⟩ (5) and |110⟩ (6) swap.
      expected = %{0 => 0, 1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 6, 6 => 5, 7 => 7}

      Enum.each(expected, fn {input, output} ->
        result = CalcFast.apply_cswap(basis_state(input, 3), 0, 1, 2, 3)
        assert state_approx_equal?(result, basis_state(output, 3)), "CSWAP(0,1,2) |#{input}⟩"
      end)
    end

    test "boundary target indices 0 and n-1 (control in the middle)" do
      # control qubit 1, targets qubit 0 and qubit 2.
      # |110⟩: control 1, targets differ (q0=1, q2=0) → swap → |011⟩.
      assert state_approx_equal?(
               CalcFast.apply_cswap(basis_state(6, 3), 1, 0, 2, 3),
               basis_state(3, 3)
             ),
             "CSWAP(1,0,2) |110⟩"
    end
  end

  describe "apply_toffoli/5" do
    test "full 3-qubit truth table: flip target iff both controls = 1" do
      # controls qubit 0 and qubit 1, target qubit 2.
      # Both controls set only for |110⟩ (6) and |111⟩ (7), which swap.
      expected = %{0 => 0, 1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 5, 6 => 7, 7 => 6}

      Enum.each(expected, fn {input, output} ->
        result = CalcFast.apply_toffoli(basis_state(input, 3), 0, 1, 2, 3)
        assert state_approx_equal?(result, basis_state(output, 3)), "Toffoli(0,1,2) |#{input}⟩"
      end)
    end

    test "boundary control/target indices 0 and n-1" do
      # controls qubit 0 and qubit 2 (the boundaries), target qubit 1.
      # Both controls set for |101⟩ (5) and |111⟩ (7); flip qubit 1 → swap 5↔7.
      assert state_approx_equal?(
               CalcFast.apply_toffoli(basis_state(5, 3), 0, 2, 1, 3),
               basis_state(7, 3)
             )

      assert state_approx_equal?(
               CalcFast.apply_toffoli(basis_state(7, 3), 0, 2, 1, 3),
               basis_state(5, 3)
             )
    end
  end

  describe "invalid-input characterization (CalcFast is unvalidated by design — D2)" do
    # These tests pin the RAW behaviour of the unvalidated kernels. They assert
    # the actual error class observed today; they do NOT assert typed
    # `Qx.*Error`s (those live upstream in the public API). A change here is a
    # signal that the v0.8.2 rewrite altered an out-of-band failure mode.

    test "apply_single_qubit_gate/4 raises on out-of-range target (target == num_qubits)" do
      # bit_pos = num_qubits - 1 - target = -1 → "cannot right shift by -1".
      assert_raise ArgumentError, fn ->
        CalcFast.apply_single_qubit_gate(basis_state(0, 2), Gates.pauli_x(), 2, 2)
      end
    end

    test "apply_single_qubit_gate/4 raises on negative target qubit" do
      # Negative index inflates the pair mask → out-of-bounds Nx.take.
      assert_raise ArgumentError, fn ->
        CalcFast.apply_single_qubit_gate(basis_state(0, 2), Gates.pauli_x(), -1, 2)
      end
    end

    test "apply_single_qubit_gate/4 raises on state length ≠ 2^num_qubits" do
      # 4-element state declared as 3 qubits → paired index out of bounds.
      assert_raise ArgumentError, fn ->
        CalcFast.apply_single_qubit_gate(basis_state(0, 2), Gates.pauli_x(), 0, 3)
      end
    end

    test "apply_single_qubit_gate/4 silently uses the top-left 2×2 block of an oversized gate" do
      # Characterization: the compiled head reads only gate[0..1][0..1], so a
      # 3×3 gate yields a defined (physically meaningless) result rather than
      # raising. Plan Phase 5 expected a raise; the measured behaviour is no
      # raise, pinned here per D2 (assert the ACTUAL behaviour, not the wish).
      #
      # A 3×3 gate whose top-left 2×2 block is Pauli-X therefore acts as X on
      # qubit 0: |00⟩ → |10⟩ (index 2), proving the trailing row/column are
      # ignored rather than triggering a shape error.
      z = C.new(0.0, 0.0)
      o = C.new(1.0, 0.0)
      gate_3x3 = Nx.tensor([[z, o, z], [o, z, z], [z, z, o]], type: :c64)

      result = CalcFast.apply_single_qubit_gate(basis_state(0, 2), gate_3x3, 0, 2)

      assert state_approx_equal?(result, basis_state(2, 2))
    end

    test "apply_cnot/4 raises on out-of-range control qubit" do
      assert_raise ArgumentError, fn ->
        CalcFast.apply_cnot(basis_state(0, 2), 2, 1, 2)
      end
    end

    test "apply_cswap/5 raises on out-of-range control qubit" do
      assert_raise ArgumentError, fn ->
        CalcFast.apply_cswap(basis_state(0, 3), 3, 1, 2, 3)
      end
    end

    test "apply_toffoli/5 raises on out-of-range control qubit" do
      assert_raise ArgumentError, fn ->
        CalcFast.apply_toffoli(basis_state(0, 3), 3, 1, 2, 3)
      end
    end
  end
end
