defmodule Qx.CalcFastSlicingTest do
  use ExUnit.Case, async: true

  # Regression net for the v0.12 rank-n axis-slicing kernels in `Qx.CalcFast`
  # (plan: calcfast-reshape-kernels). Every entry point is checked against a
  # test-local full-matrix EMBEDDING oracle — `embed/3` lifts a small 2^k×2^k
  # gate onto arbitrary qubits of an n-qubit space by explicit index
  # arithmetic, independently of the kernel under test — and, where one
  # exists, against the legacy `Qx.Gates` n-qubit matrix builder (the
  # pre-v0.12 Simulation path). Each gate is exercised on every qubit
  # ordering at n = 3 and on non-adjacent / reversed samples at n = 5, using
  # random normalised states so a wrong axis mapping cannot hide behind a
  # basis-state symmetry.
  #
  # Convention under test (MSB): qubit 0 is the most significant bit of a
  # basis index; for a k-qubit gate on `qubits`, `qubits[0]` is the most
  # significant bit of the gate's own 2^k index.

  import Bitwise

  alias Complex, as: C
  alias Qx.{Calc, CalcFast, Gates}

  # :c64 floor (Iron Law #8).
  @tolerance 1.0e-6

  # ---------------------------------------------------------------------------
  # Oracle helpers
  # ---------------------------------------------------------------------------

  defp bit(index, qubit, n), do: index >>> (n - 1 - qubit) &&& 1

  defp gate_index(index, qubits, n),
    do: Enum.reduce(qubits, 0, fn q, acc -> acc * 2 + bit(index, q, n) end)

  defp spectator_bits(index, qubits, n),
    do: for(q <- 0..(n - 1), q not in qubits, do: bit(index, q, n))

  # Full 2^n × 2^n matrix of `gate` (2^k × 2^k) acting on `qubits`.
  defp embed(gate, qubits, n) do
    g = gate |> Nx.to_list() |> Enum.map(&List.to_tuple/1) |> List.to_tuple()
    dim = Integer.pow(2, n)
    zero = C.new(0.0, 0.0)

    rows =
      for i <- 0..(dim - 1) do
        for j <- 0..(dim - 1), do: embedded_entry(g, i, j, qubits, n, zero)
      end

    Nx.tensor(rows, type: :c64)
  end

  # ⟨i|G_full|j⟩: the gate element if i and j agree on every spectator qubit.
  defp embedded_entry(g, i, j, qubits, n, zero) do
    if spectator_bits(i, qubits, n) == spectator_bits(j, qubits, n),
      do: g |> elem(gate_index(i, qubits, n)) |> elem(gate_index(j, qubits, n)),
      else: zero
  end

  defp apply_matrix(matrix, state), do: Nx.dot(matrix, state)

  # Basis-permutation gate: column j carries |j⟩ to |perm[j]⟩.
  defp permutation_gate(perm) do
    size = length(perm)

    entries = for r <- 0..(size - 1), c <- 0..(size - 1), do: permutation_entry(perm, r, c)
    entries |> Nx.tensor(type: :c64) |> Nx.reshape({size, size})
  end

  defp permutation_entry(perm, r, c), do: if(Enum.at(perm, c) == r, do: 1.0, else: 0.0)

  defp cx_gate, do: permutation_gate([0, 1, 3, 2])
  defp swap_gate, do: permutation_gate([0, 2, 1, 3])
  defp ccx_gate, do: permutation_gate([0, 1, 2, 3, 4, 5, 7, 6])
  defp cswap_gate, do: permutation_gate([0, 1, 2, 3, 4, 6, 5, 7])

  defp iswap_gate do
    o = C.new(1.0, 0.0)
    z = C.new(0.0, 0.0)
    i = C.new(0.0, 1.0)
    Nx.tensor([[o, z, z, z], [z, z, i, z], [z, i, z, z], [z, z, z, o]], type: :c64)
  end

  # |0⟩⟨0| ⊗ I + |1⟩⟨1| ⊗ U, control = gate MSB.
  defp controlled(u) do
    [[a, b], [c, d]] = Nx.to_list(u)
    o = C.new(1.0, 0.0)
    z = C.new(0.0, 0.0)
    Nx.tensor([[o, z, z, z], [z, o, z, z], [z, z, a, b], [z, z, c, d]], type: :c64)
  end

  defp random_state(n, seed) do
    size = Integer.pow(2, n)
    key = Nx.Random.key(seed)
    {re, key} = Nx.Random.normal(key, shape: {size})
    {im, _key} = Nx.Random.normal(key, shape: {size})
    state = Nx.complex(re, im)
    norm = state |> Nx.abs() |> Nx.pow(2) |> Nx.sum() |> Nx.sqrt()
    state |> Nx.divide(norm) |> Nx.as_type(:c64)
  end

  defp assert_state_close(actual, expected, context) do
    assert Nx.shape(actual) == Nx.shape(expected), "shape mismatch: #{context}"
    assert Nx.type(actual) == {:c, 64}, "type is not c64: #{context}"

    max_err = actual |> Nx.subtract(expected) |> Nx.abs() |> Nx.reduce_max() |> Nx.to_number()
    assert max_err < @tolerance, "max |Δ| = #{max_err} ≥ #{@tolerance}: #{context}"
  end

  defp ordered_pairs(n), do: for(a <- 0..(n - 1), b <- 0..(n - 1), a != b, do: [a, b])

  defp ordered_triples(n),
    do: for([a, b] <- ordered_pairs(n), c <- 0..(n - 1), c not in [a, b], do: [a, b, c])

  # Non-adjacent and reversed orderings in a 5-qubit space.
  @pairs_n5 [[0, 4], [4, 0], [1, 3], [3, 1], [0, 2], [4, 1]]
  @triples_n5 [[0, 2, 4], [4, 2, 0], [3, 0, 1], [1, 4, 2], [2, 4, 0]]

  defp pair_cases, do: Enum.map(ordered_pairs(3), &{3, &1}) ++ Enum.map(@pairs_n5, &{5, &1})

  defp triple_cases,
    do: Enum.map(ordered_triples(3), &{3, &1}) ++ Enum.map(@triples_n5, &{5, &1})

  # ---------------------------------------------------------------------------
  # Single-qubit gates (k = 1)
  # ---------------------------------------------------------------------------

  describe "apply_single_qubit_gate/4 vs embedding oracle" do
    test "a generic U lands on the right axis for every qubit (n = 3, 5)" do
      u = Gates.u(0.3, 1.1, -0.7)

      for n <- [3, 5], q <- 0..(n - 1) do
        state = random_state(n, 100 + 10 * n + q)

        assert_state_close(
          CalcFast.apply_single_qubit_gate(state, u, q, n),
          apply_matrix(embed(u, [q], n), state),
          "U on q#{q}, n=#{n}"
        )
      end
    end

    test "non-symmetric gates (S, T†, RY) on every qubit at n = 4" do
      for gate <- [Gates.s_gate(), Gates.t_dagger(), Gates.ry(0.9)], q <- 0..3 do
        state = random_state(4, 200 + q)

        assert_state_close(
          CalcFast.apply_single_qubit_gate(state, gate, q, 4),
          apply_matrix(embed(gate, [q], 4), state),
          "gate on q#{q}, n=4"
        )
      end
    end
  end

  # ---------------------------------------------------------------------------
  # CNOT / Toffoli / CSWAP (existing entry points, new kernels)
  # ---------------------------------------------------------------------------

  describe "apply_cnot/4 vs oracles" do
    test "every ordering at n = 3 and non-adjacent samples at n = 5" do
      for {n, [c, t]} <- pair_cases() do
        state = random_state(n, 300 + 10 * c + t)
        actual = CalcFast.apply_cnot(state, c, t, n)
        context = "CX(#{c}, #{t}), n=#{n}"

        assert_state_close(actual, apply_matrix(embed(cx_gate(), [c, t], n), state), context)

        assert_state_close(
          actual,
          apply_matrix(Gates.controlled_gate(Gates.pauli_x(), c, t, n), state),
          context <> " (Gates.controlled_gate oracle)"
        )
      end
    end
  end

  describe "apply_toffoli/5 vs embedding oracle" do
    test "every ordering at n = 3 and non-adjacent samples at n = 5" do
      for {n, [c1, c2, t] = qubits} <- triple_cases() do
        state = random_state(n, 400 + 100 * c1 + 10 * c2 + t)

        assert_state_close(
          CalcFast.apply_toffoli(state, c1, c2, t, n),
          apply_matrix(embed(ccx_gate(), qubits, n), state),
          "CCX(#{c1}, #{c2}, #{t}), n=#{n}"
        )
      end
    end
  end

  describe "apply_cswap/5 vs oracles" do
    test "every ordering at n = 3 and non-adjacent samples at n = 5" do
      for {n, [c, a, b] = qubits} <- triple_cases() do
        state = random_state(n, 500 + 100 * c + 10 * a + b)
        actual = CalcFast.apply_cswap(state, c, a, b, n)
        context = "CSWAP(#{c}, #{a}, #{b}), n=#{n}"

        assert_state_close(actual, apply_matrix(embed(cswap_gate(), qubits, n), state), context)

        assert_state_close(
          actual,
          apply_matrix(Gates.cswap(c, a, b, n), state),
          context <> " (Gates.cswap oracle)"
        )
      end
    end
  end

  # ---------------------------------------------------------------------------
  # New entry points: controlled-U, SWAP, iSWAP
  # ---------------------------------------------------------------------------

  describe "apply_controlled_gate/5 vs oracles" do
    test "CP / CY / CRx / CRy / CRz / CZ, control above and below target, non-adjacent" do
      targets = [
        {"P(0.7)", Gates.phase(0.7)},
        {"Y", Gates.pauli_y()},
        {"RX(0.4)", Gates.rx(0.4)},
        {"RY(1.3)", Gates.ry(1.3)},
        {"RZ(-0.9)", Gates.rz(-0.9)},
        {"Z", Gates.pauli_z()}
      ]

      for {label, u} <- targets, {n, [c, t]} <- pair_cases() do
        state = random_state(n, 600 + 10 * c + t)
        actual = CalcFast.apply_controlled_gate(state, u, c, t, n)
        context = "C-#{label}(#{c}, #{t}), n=#{n}"

        assert_state_close(actual, apply_matrix(embed(controlled(u), [c, t], n), state), context)

        assert_state_close(
          actual,
          apply_matrix(Gates.controlled_gate(u, c, t, n), state),
          context <> " (Gates.controlled_gate oracle)"
        )
      end
    end

    test "works in a 2-qubit system (smallest controlled case)" do
      u = Gates.ry(0.6)

      for [c, t] <- ordered_pairs(2) do
        state = random_state(2, 650 + c)

        assert_state_close(
          CalcFast.apply_controlled_gate(state, u, c, t, 2),
          apply_matrix(Gates.controlled_gate(u, c, t, 2), state),
          "C-RY(#{c}, #{t}), n=2"
        )
      end
    end
  end

  describe "apply_swap/4 vs oracles" do
    test "every ordering at n = 3 and non-adjacent samples at n = 5" do
      for {n, [a, b]} <- pair_cases() do
        state = random_state(n, 700 + 10 * a + b)
        actual = CalcFast.apply_swap(state, a, b, n)
        context = "SWAP(#{a}, #{b}), n=#{n}"

        assert_state_close(actual, apply_matrix(embed(swap_gate(), [a, b], n), state), context)

        assert_state_close(
          actual,
          apply_matrix(Gates.swap(a, b, n), state),
          context <> " (Gates.swap oracle)"
        )
      end
    end
  end

  describe "apply_iswap/4 vs oracles" do
    test "every ordering at n = 3 and non-adjacent samples at n = 5" do
      for {n, [a, b]} <- pair_cases() do
        state = random_state(n, 800 + 10 * a + b)
        actual = CalcFast.apply_iswap(state, a, b, n)
        context = "iSWAP(#{a}, #{b}), n=#{n}"

        assert_state_close(actual, apply_matrix(embed(iswap_gate(), [a, b], n), state), context)

        assert_state_close(
          actual,
          apply_matrix(Gates.iswap(a, b, n), state),
          context <> " (Gates.iswap oracle)"
        )
      end
    end
  end

  describe "Qx.Calc delegators for the new entry points" do
    test "apply_controlled_gate/5, apply_swap/4, apply_iswap/4 match CalcFast" do
      state = random_state(4, 900)
      u = Gates.rx(0.8)

      assert_state_close(
        Calc.apply_controlled_gate(state, u, 3, 1, 4),
        CalcFast.apply_controlled_gate(state, u, 3, 1, 4),
        "Calc.apply_controlled_gate"
      )

      assert_state_close(
        Calc.apply_swap(state, 0, 2, 4),
        CalcFast.apply_swap(state, 0, 2, 4),
        "Calc.apply_swap"
      )

      assert_state_close(
        Calc.apply_iswap(state, 3, 0, 4),
        CalcFast.apply_iswap(state, 3, 0, 4),
        "Calc.apply_iswap"
      )
    end
  end

  # ---------------------------------------------------------------------------
  # Invalid input — raw ArgumentError (CalcFast is unvalidated by the typed
  # layer; typed Qx.*Errors live upstream in the public API). Plan D3.
  # ---------------------------------------------------------------------------

  describe "invalid input raises ArgumentError" do
    setup do
      %{s2: random_state(2, 1), s3: random_state(3, 2)}
    end

    test "apply_controlled_gate/5 rejects out-of-range, negative and equal qubits", %{s2: s2} do
      u = Gates.pauli_y()
      assert_raise ArgumentError, fn -> CalcFast.apply_controlled_gate(s2, u, 2, 0, 2) end
      assert_raise ArgumentError, fn -> CalcFast.apply_controlled_gate(s2, u, 0, 2, 2) end
      assert_raise ArgumentError, fn -> CalcFast.apply_controlled_gate(s2, u, -1, 0, 2) end
      assert_raise ArgumentError, fn -> CalcFast.apply_controlled_gate(s2, u, 1, 1, 2) end
    end

    test "apply_controlled_gate/5 rejects a state whose length ≠ 2^num_qubits", %{s2: s2} do
      assert_raise ArgumentError, fn ->
        CalcFast.apply_controlled_gate(s2, Gates.pauli_y(), 0, 1, 3)
      end
    end

    test "apply_swap/4 and apply_iswap/4 reject out-of-range and equal qubits", %{s3: s3} do
      assert_raise ArgumentError, fn -> CalcFast.apply_swap(s3, 0, 3, 3) end
      assert_raise ArgumentError, fn -> CalcFast.apply_swap(s3, 1, 1, 3) end
      assert_raise ArgumentError, fn -> CalcFast.apply_iswap(s3, -1, 2, 3) end
      assert_raise ArgumentError, fn -> CalcFast.apply_iswap(s3, 2, 2, 3) end
    end

    test "existing kernels reject repeated qubit indices", %{s2: s2, s3: s3} do
      assert_raise ArgumentError, fn -> CalcFast.apply_cnot(s2, 1, 1, 2) end
      assert_raise ArgumentError, fn -> CalcFast.apply_toffoli(s3, 0, 0, 2, 3) end
      assert_raise ArgumentError, fn -> CalcFast.apply_toffoli(s3, 0, 1, 1, 3) end
      assert_raise ArgumentError, fn -> CalcFast.apply_cswap(s3, 0, 2, 2, 3) end
      assert_raise ArgumentError, fn -> CalcFast.apply_cswap(s3, 1, 1, 2, 3) end
    end

    test "non-integer qubit index is rejected", %{s2: s2} do
      assert_raise ArgumentError, fn -> CalcFast.apply_swap(s2, 0, 1.0, 2) end
    end
  end
end
