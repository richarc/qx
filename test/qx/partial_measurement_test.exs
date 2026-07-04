defmodule Qx.PartialMeasurementTest do
  use ExUnit.Case, async: true

  # qx-d1f — verify partial measurement of a multi-qubit entangled state
  # leaves the unmeasured subsystem in the correct post-collapse state.
  #
  # The simulator uses deferred-measurement semantics (all measurements
  # sampled from the final joint distribution after every unitary has
  # been applied). For circuits without conditionals this is
  # quantum-mechanically equivalent to mid-circuit collapse — these
  # tests pin down that equivalence by checking joint distributions
  # against analytic expectations.

  @shots 4000
  # Loose tolerance: 5·√shots covers ≫5σ for any p in [0.1, 0.9].
  @tol trunc(:math.sqrt(@shots) * 5)

  defp outcomes(result), do: result.counts |> Map.keys() |> MapSet.new()

  describe "partial measurement on an entangled multi-qubit state" do
    test "measuring one qubit of a 3-qubit GHZ leaves the other two perfectly correlated" do
      # GHZ = (|000⟩ + |111⟩)/√2. The only legal joint outcomes are
      # 000 and 111 — anything with q0 ≠ q1 or q1 ≠ q2 would prove the
      # unmeasured qubits no longer track the measured one.
      result =
        Qx.create_circuit(3, 3)
        |> Qx.h(0)
        |> Qx.cx(0, 1)
        |> Qx.cx(1, 2)
        |> Qx.measure(0, 0)
        |> Qx.measure(1, 1)
        |> Qx.measure(2, 2)
        |> Qx.run(shots: @shots)

      assert MapSet.subset?(outcomes(result), MapSet.new(["000", "111"]))
      assert Map.get(result.counts, "000", 0) > 0
      assert Map.get(result.counts, "111", 0) > 0

      half = div(@shots, 2)
      assert_in_delta Map.get(result.counts, "000", 0), half, @tol
      assert_in_delta Map.get(result.counts, "111", 0), half, @tol
    end

    test "gate applied to qubit 2 after measuring qubit 0 still produces the correct joint distribution" do
      # GHZ, then H on qubit 2, then measure all. Analytic result:
      # the state becomes (|000⟩ + |001⟩ + |110⟩ - |111⟩)/2, so the
      # four outcomes 000/001/110/111 are equiprobable (p = 1/4 each).
      # The surviving correlation is q0 = q1 — any outcome violating
      # that would indicate the H corrupted the unmeasured subsystem.
      result =
        Qx.create_circuit(3, 3)
        |> Qx.h(0)
        |> Qx.cx(0, 1)
        |> Qx.cx(1, 2)
        |> Qx.measure(0, 0)
        |> Qx.h(2)
        |> Qx.measure(1, 1)
        |> Qx.measure(2, 2)
        |> Qx.run(shots: @shots)

      expected = MapSet.new(["000", "001", "110", "111"])
      assert MapSet.equal?(outcomes(result), expected)

      forbidden = MapSet.new(["010", "011", "100", "101"])
      assert MapSet.disjoint?(outcomes(result), forbidden)

      quarter = div(@shots, 4)

      for outcome <- expected do
        assert_in_delta Map.get(result.counts, outcome, 0), quarter, @tol
      end
    end

    test "sequential measurements on independent qubits give the correct joint distribution" do
      # |+⟩ ⊗ |0⟩ ⊗ |+⟩ with measurements interleaved between gates.
      # q0 and q2 are uniformly random and independent; q1 is
      # deterministically 0. Inserting measure(0) between H(0) and H(2)
      # must not affect q2's later distribution.
      result =
        Qx.create_circuit(3, 3)
        |> Qx.h(0)
        |> Qx.measure(0, 0)
        |> Qx.h(2)
        |> Qx.measure(1, 1)
        |> Qx.measure(2, 2)
        |> Qx.run(shots: @shots)

      expected = MapSet.new(["000", "001", "100", "101"])
      assert MapSet.equal?(outcomes(result), expected)

      quarter = div(@shots, 4)

      for outcome <- expected do
        assert_in_delta Map.get(result.counts, outcome, 0), quarter, @tol
      end
    end
  end
end
