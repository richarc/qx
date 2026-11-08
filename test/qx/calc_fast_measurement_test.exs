defmodule Qx.CalcFastMeasurementTest do
  use ExUnit.Case, async: true

  # Pins the single-qubit measurement kernels `Qx.CalcFast.qubit_probabilities/3`
  # and `Qx.CalcFast.collapse/5` against a host oracle that walks every basis
  # index and tests the qubit's bit (qubit 0 = MSB). :c64 states are complex
  # float32, so comparisons use 1.0e-6 (Iron Law #8).

  alias Qx.CalcFast

  @tolerance 1.0e-6

  # Random normalised :c64 state with a fixed seed (no process :rand use).
  defp random_state(num_qubits, seed) do
    size = Integer.pow(2, num_qubits)

    {amps, _} =
      Enum.map_reduce(1..size, :rand.seed_s(:exsss, seed), fn _, rand ->
        {re, rand} = :rand.normal_s(rand)
        {im, rand} = :rand.normal_s(rand)
        {Complex.new(re, im), rand}
      end)

    norm = amps |> Enum.map(&(Complex.abs(&1) ** 2)) |> Enum.sum() |> :math.sqrt()
    amps |> Enum.map(&Complex.divide(&1, Complex.new(norm, 0.0))) |> Nx.tensor(type: :c64)
  end

  defp bit(index, qubit, num_qubits),
    do: Bitwise.band(Bitwise.bsr(index, num_qubits - 1 - qubit), 1)

  # Oracle: sum |amp|² over basis indices whose `qubit` bit is `value`.
  defp oracle_probability(state, qubit, value, num_qubits) do
    state
    |> Nx.to_flat_list()
    |> Enum.with_index()
    |> Enum.filter(fn {_amp, i} -> bit(i, qubit, num_qubits) == value end)
    |> Enum.map(fn {amp, _i} -> Complex.abs(amp) ** 2 end)
    |> Enum.sum()
  end

  describe "qubit_probabilities/3" do
    for num_qubits <- [1, 3, 5], seed <- [1, 2, 3] do
      @num_qubits num_qubits
      @seed seed
      test "matches the oracle for every qubit (n=#{num_qubits}, seed=#{seed})" do
        state = random_state(@num_qubits, @seed)

        for qubit <- 0..(@num_qubits - 1) do
          {p0, p1} = CalcFast.qubit_probabilities(state, qubit, @num_qubits)

          assert is_float(p0) and is_float(p1)
          assert_in_delta p0, oracle_probability(state, qubit, 0, @num_qubits), @tolerance
          assert_in_delta p1, oracle_probability(state, qubit, 1, @num_qubits), @tolerance
          assert_in_delta p0 + p1, 1.0, @tolerance
        end
      end
    end

    test "a basis state gives exactly {1, 0} / {0, 1}" do
      # |101⟩ = index 5
      state = Nx.tensor(Enum.map(0..7, &if(&1 == 5, do: 1.0, else: 0.0)), type: :c64)

      assert CalcFast.qubit_probabilities(state, 0, 3) == {0.0, 1.0}
      assert CalcFast.qubit_probabilities(state, 1, 3) == {1.0, 0.0}
      assert CalcFast.qubit_probabilities(state, 2, 3) == {0.0, 1.0}
    end

    test "an out-of-range qubit raises ArgumentError" do
      state = random_state(3, 1)
      assert_raise ArgumentError, fn -> CalcFast.qubit_probabilities(state, 3, 3) end
      assert_raise ArgumentError, fn -> CalcFast.qubit_probabilities(state, -1, 3) end
    end
  end

  describe "collapse/5" do
    for num_qubits <- [1, 3, 5], value <- [0, 1] do
      @num_qubits num_qubits
      @value value
      test "zeroes the other branch and rescales the kept one (n=#{num_qubits}, value=#{value})" do
        state = random_state(@num_qubits, 7)

        for qubit <- 0..(@num_qubits - 1) do
          prob = oracle_probability(state, qubit, @value, @num_qubits)
          norm_factor = 1.0 / :math.sqrt(prob)

          collapsed = CalcFast.collapse(state, qubit, @value, norm_factor, @num_qubits)

          assert Nx.type(collapsed) == {:c, 64}
          assert Nx.shape(collapsed) == Nx.shape(state)

          pairs =
            Enum.zip([
              Nx.to_flat_list(state),
              Nx.to_flat_list(collapsed),
              0..(Integer.pow(2, @num_qubits) - 1)
            ])

          for {before, after_amp, i} <- pairs do
            if bit(i, qubit, @num_qubits) == @value do
              expected = Complex.multiply(before, Complex.new(norm_factor, 0.0))
              assert_in_delta Complex.abs(Complex.subtract(after_amp, expected)), 0.0, @tolerance
            else
              assert after_amp == Complex.new(0.0, 0.0)
            end
          end

          total =
            collapsed |> Nx.to_flat_list() |> Enum.map(&(Complex.abs(&1) ** 2)) |> Enum.sum()

          assert_in_delta total, 1.0, 1.0e-5
        end
      end
    end

    test "an out-of-range qubit raises ArgumentError" do
      state = random_state(3, 1)
      assert_raise ArgumentError, fn -> CalcFast.collapse(state, 5, 0, 1.0, 3) end
    end

    test "an invalid measured value raises ArgumentError" do
      state = random_state(3, 1)
      assert_raise ArgumentError, fn -> CalcFast.collapse(state, 0, 2, 1.0, 3) end
    end
  end
end
