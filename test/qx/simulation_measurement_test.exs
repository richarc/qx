defmodule Qx.SimulationMeasurementTest do
  use ExUnit.Case, async: true

  # Regression net for the vectorised measurement paths in `Qx.Simulation`:
  #
  #   * seeded `steps/2` trajectories equal a host reference (p0 by summing
  #     |amp|², the decision `uniform < p0` from the threaded
  #     `:rand.uniform_s/1`, collapse by zeroing + rescaling) — so seeded
  #     trajectories in tests and teaching material do not change;
  #   * `run/2` counts are statistically right on both the sampling path (no
  #     conditionals) and the per-shot `c_if` path (Iron Law #9 execution);
  #   * a static guard that the per-amplitude host loops stay gone.
  #
  # :c64 states are complex float32; tolerances are 1.0e-6 (Iron Law #8).

  alias Qx.{Simulation, Step}

  @tolerance 1.0e-6

  defp bit(index, qubit, num_qubits),
    do: Bitwise.band(Bitwise.bsr(index, num_qubits - 1 - qubit), 1)

  defp oracle_probability(amps, qubit, value, num_qubits) do
    amps
    |> Enum.with_index()
    |> Enum.filter(fn {_amp, i} -> bit(i, qubit, num_qubits) == value end)
    |> Enum.map(fn {amp, _i} -> Complex.abs(amp) ** 2 end)
    |> Enum.sum()
  end

  defp oracle_collapse(amps, qubit, value, num_qubits) do
    prob = oracle_probability(amps, qubit, value, num_qubits)
    norm = if prob > 0, do: 1.0 / :math.sqrt(prob), else: 1.0

    amps
    |> Enum.with_index()
    |> Enum.map(fn {amp, i} ->
      if bit(i, qubit, num_qubits) == value,
        do: Complex.multiply(amp, Complex.new(norm, 0.0)),
        else: Complex.new(0.0, 0.0)
    end)
  end

  defp assert_amps_close(actual, expected) do
    assert length(actual) == length(expected)

    for {a, b} <- Enum.zip(actual, expected) do
      assert_in_delta Complex.abs(Complex.subtract(a, b)), 0.0, @tolerance
    end
  end

  # Replays every measurement step of a seeded trajectory with the host
  # reference, threading the same `:rand.seed_s(:exsss, seed)` state: one
  # `uniform_s` per measurement, outcome 0 iff `uniform < p0`.
  defp assert_trajectory_matches_reference(circuit, seed) do
    num_qubits = circuit.num_qubits
    steps = circuit |> Simulation.steps(seed: seed) |> Enum.to_list()
    initial = circuit.state |> Nx.as_type(:c64) |> Nx.to_flat_list()

    {_, _, measured} =
      Enum.reduce(steps, {initial, :rand.seed_s(:exsss, seed), 0}, fn
        %Step{kind: :measurement, operation: {:measure, [qubit, cbit], []}} = step,
        {pre, rand, count} ->
          p0 = oracle_probability(pre, qubit, 0, num_qubits)
          {uniform, rand} = :rand.uniform_s(rand)
          value = if uniform < p0, do: 0, else: 1

          assert Enum.at(step.classical_bits, cbit) == value
          post = Nx.to_flat_list(step.state)
          assert_amps_close(post, oracle_collapse(pre, qubit, value, num_qubits))
          {post, rand, count + 1}

        %Step{state: state}, {_pre, rand, count} ->
          {Nx.to_flat_list(state), rand, count}
      end)

    measured
  end

  defp teleportation do
    Qx.create_circuit(3, 3)
    |> Qx.x(0)
    |> Qx.h(1)
    |> Qx.cx(1, 2)
    |> Qx.cx(0, 1)
    |> Qx.h(0)
    |> Qx.measure(0, 0)
    |> Qx.measure(1, 1)
    |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)
    |> Qx.c_if(0, 1, fn c -> Qx.z(c, 2) end)
    |> Qx.measure(2, 2)
  end

  # GHZ-5 with an RY so outcome probabilities are unequal, and two
  # mid-circuit measurements separated by gates.
  defp ghz5_mid_circuit do
    Qx.create_circuit(5, 2)
    |> Qx.ry(0, 1.1)
    |> Qx.cx(0, 1)
    |> Qx.cx(1, 2)
    |> Qx.cx(2, 3)
    |> Qx.cx(3, 4)
    |> Qx.measure(2, 0)
    |> Qx.h(4)
    |> Qx.ry(1, 0.7)
    |> Qx.measure(4, 1)
  end

  describe "seeded steps/2 trajectories equal the host reference" do
    for seed <- [1, 2, 3, 42, 1234] do
      @seed seed
      test "teleportation, seed #{seed}" do
        assert assert_trajectory_matches_reference(teleportation(), @seed) == 3
      end

      test "GHZ-5 with two mid-circuit measurements, seed #{seed}" do
        assert assert_trajectory_matches_reference(ghz5_mid_circuit(), @seed) == 2
      end
    end
  end

  # |count − shots·p| ≤ k·σ, σ = sqrt(shots·p·(1−p)).
  defp assert_binomial(count, shots, p, k) do
    sigma = :math.sqrt(shots * p * (1 - p))
    assert abs(count - shots * p) <= k * sigma + 1.0e-9
  end

  @sampling_shots 10_000

  describe "run/2 sampling path (no conditionals)" do
    # The sampler draws from the process :rand, so seeding this test process
    # makes these counts deterministic (no statistical flake). 4σ still
    # documents the expected spread if the seed changes.
    setup do
      :rand.seed(:exsss, 20_261_108)
      :ok
    end

    test "Bell state: only 00 and 11, each ~1/2" do
      qc = Qx.create_circuit(2, 2) |> Qx.h(0) |> Qx.cx(0, 1) |> Qx.measure_all()
      result = Simulation.run(qc, shots: @sampling_shots)

      assert Map.keys(result.counts) |> Enum.sort() == ["00", "11"]
      assert_binomial(result.counts["00"], @sampling_shots, 0.5, 4)
      assert length(result.classical_bits) == @sampling_shots
    end

    test "GHZ-4: only 0000 and 1111, each ~1/2" do
      qc =
        Qx.create_circuit(4, 4)
        |> Qx.h(0)
        |> Qx.cx(0, 1)
        |> Qx.cx(1, 2)
        |> Qx.cx(2, 3)
        |> Qx.measure_all()

      result = Simulation.run(qc, shots: @sampling_shots)

      assert Map.keys(result.counts) |> Enum.sort() == ["0000", "1111"]
      assert_binomial(result.counts["1111"], @sampling_shots, 0.5, 4)
    end

    test "unequal RY state: P(1) = sin²(θ/2)" do
      theta = 0.9
      p1 = :math.sin(theta / 2) ** 2
      qc = Qx.create_circuit(2, 2) |> Qx.ry(0, theta) |> Qx.measure_all()
      result = Simulation.run(qc, shots: @sampling_shots)

      # q1 stays |0⟩, so "01" and "11" are impossible.
      assert Map.keys(result.counts) |> Enum.sort() == ["00", "10"]
      assert_binomial(result.counts["10"], @sampling_shots, p1, 4)
    end
  end

  describe "run/2 per-shot c_if path" do
    # Each shot draws fresh entropy (unseedable), so use 5σ: ~6e-7 false
    # failures per assertion.
    test "teleportation always delivers |1⟩; the two Bell bits are uniform" do
      shots = 2000
      result = Simulation.run(teleportation(), shots: shots)

      assert Enum.all?(Map.keys(result.counts), &String.ends_with?(&1, "1"))

      for prefix <- ["00", "01", "10", "11"] do
        assert_binomial(Map.get(result.counts, prefix <> "1", 0), shots, 0.25, 5)
      end
    end
  end

  describe ":shots validation" do
    defp bell, do: Qx.create_circuit(2, 2) |> Qx.h(0) |> Qx.cx(0, 1) |> Qx.measure_all()

    for {label, shots} <- [zero: 0, negative: -1, float: 1.5, atom: :many] do
      @shots_value shots
      test "#{label} shots raise Qx.OptionError on both run paths" do
        for circuit <- [bell(), teleportation()] do
          error =
            assert_raise Qx.OptionError, fn -> Simulation.run(circuit, shots: @shots_value) end

          assert error.option == :shots
          assert error.value == @shots_value
        end
      end
    end

    test "the integer facade form is validated too" do
      assert_raise Qx.OptionError, fn -> Qx.run(bell(), 0) end
    end

    test "shots: 1 returns one sample on both run paths" do
      for circuit <- [bell(), teleportation()] do
        result = Simulation.run(circuit, shots: 1)
        assert length(result.classical_bits) == 1
        assert result.counts |> Map.values() |> Enum.sum() == 1
      end
    end
  end

  describe "static guard" do
    test "simulation.ex has no per-amplitude host syncs or linear sample search" do
      code =
        Path.expand("../../lib/qx/simulation.ex", __DIR__)
        |> File.read!()
        |> String.split("\n")
        |> Enum.reject(&String.starts_with?(String.trim_leading(&1), "#"))
        |> Enum.join("\n")

      refute code =~ "Nx.to_number(state["
      refute code =~ "Enum.find_index(cumulative"
    end
  end
end
