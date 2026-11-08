defmodule Qx.Simulation.SamplerTest do
  use ExUnit.Case, async: true

  # Pins `Qx.Simulation.Sampler` (the shot sampler behind `run/2` for circuits
  # without conditionals) against a test-local copy of the pre-v0.12 linear
  # algorithm: same process `:rand` draws ⇒ same sample indices, exactly one
  # `:rand.uniform/0` per shot, and (D3) a draw above the cumulative total
  # never maps to a zero-probability outcome.
  #
  # Each test runs in its own process, so seeding the process `:rand` here
  # only affects this test.

  alias Qx.Simulation.Sampler

  # The pre-v0.12 `generate_samples/2`, verbatim.
  defp reference_samples(probabilities, shots) do
    cumulative = Enum.scan(probabilities, &(&1 + &2))

    for _ <- 1..shots do
      rand = :rand.uniform()
      Enum.find_index(cumulative, fn cum_prob -> rand <= cum_prob end) || 0
    end
  end

  # Random f32 distribution over 2^n outcomes; roughly a third of the
  # outcomes are forced to probability 0 (n ≥ 2).
  defp random_distribution(num_qubits, seed) do
    size = Integer.pow(2, num_qubits)

    {weights, _} =
      Enum.map_reduce(1..size, :rand.seed_s(:exsss, seed), fn _, rand ->
        {zero?, rand} = :rand.uniform_s(rand)
        {w, rand} = :rand.uniform_s(rand)
        {if(zero? < 0.33 and size > 2, do: 0.0, else: w), rand}
      end)

    weights = if Enum.all?(weights, &(&1 == 0.0)), do: [1.0 | tl(weights)], else: weights
    tensor = Nx.tensor(weights, type: :f32)
    Nx.divide(tensor, Nx.sum(tensor))
  end

  defp run_seeded(seed, fun) do
    :rand.seed(:exsss, seed)
    result = fun.()
    {result, :rand.export_seed()}
  end

  describe "sample/2 matches the pre-v0.12 linear search" do
    for num_qubits <- 1..8, seed <- [11, 22] do
      @num_qubits num_qubits
      @seed seed
      test "same draws ⇒ same samples (n=#{num_qubits}, seed=#{seed})" do
        probs = random_distribution(@num_qubits, @seed)
        shots = 2000

        {expected, expected_rand} =
          run_seeded(@seed, fn -> reference_samples(Nx.to_flat_list(probs), shots) end)

        {actual, actual_rand} =
          run_seeded(@seed, fn -> probs |> Sampler.cumulative() |> Sampler.sample(shots) end)

        assert actual == expected
        # Exactly one :rand.uniform/0 per shot: the RNG ends in the same state.
        assert actual_rand == expected_rand
      end
    end
  end

  describe "cumulative/1" do
    test "returns a tuple of the running sums" do
      cumulative = Sampler.cumulative(Nx.tensor([0.25, 0.0, 0.5, 0.25], type: :f32))

      assert is_tuple(cumulative)
      assert tuple_size(cumulative) == 4

      for {got, want} <- Enum.zip(Tuple.to_list(cumulative), [0.25, 0.25, 0.75, 1.0]) do
        assert_in_delta got, want, 1.0e-12
      end
    end
  end

  describe "sample/2 fallback (draw above the cumulative total)" do
    test "never returns a zero-probability outcome" do
      # Total is 0.6, so ~40% of draws exceed it. Pre-v0.12 these fell back to
      # index 0, which has probability 0. Index 3 also has probability 0.
      probs = Nx.tensor([0.0, 0.3, 0.3, 0.0], type: :f32)
      shots = 2000

      {old, _} = run_seeded(5, fn -> reference_samples(Nx.to_flat_list(probs), shots) end)
      assert 0 in old, "sanity: the old algorithm falls back to the zero-probability index 0"

      {samples, _} =
        run_seeded(5, fn -> probs |> Sampler.cumulative() |> Sampler.sample(shots) end)

      assert Enum.all?(samples, &(&1 in [1, 2]))

      # Draws within the total map exactly as before; draws above it map to
      # the last positive-probability outcome (index 2).
      for {old_index, new_index} <- Enum.zip(old, samples) do
        expected = if old_index == 0, do: 2, else: old_index
        assert new_index == expected
      end
    end

    test "a single-outcome distribution always returns that outcome" do
      probs = Nx.tensor([0.0, 0.0, 0.99, 0.0], type: :f32)
      {samples, _} = run_seeded(9, fn -> probs |> Sampler.cumulative() |> Sampler.sample(500) end)
      assert Enum.uniq(samples) == [2]
    end
  end
end
