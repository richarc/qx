defmodule Qx.ResultBuilderTest do
  use ExUnit.Case, async: true

  alias Qx.ResultBuilder

  test "from_counts builds SimulationResult from counts map" do
    counts = %{"00" => 500, "11" => 500}
    result = ResultBuilder.from_counts(counts, 1000, 2)

    assert %Qx.SimulationResult{} = result
    assert result.shots == 1000
    assert result.counts == %{"00" => 500, "11" => 500}
    assert Nx.shape(result.probabilities) == {4}
    assert Nx.shape(result.state) == {4}
  end

  test "from_counts calculates correct probabilities" do
    counts = %{"00" => 750, "11" => 250}
    result = ResultBuilder.from_counts(counts, 1000, 2)

    probs = Nx.to_flat_list(result.probabilities)
    assert_in_delta Enum.at(probs, 0), 0.75, 0.001
    assert_in_delta Enum.at(probs, 3), 0.25, 0.001
  end

  test "from_counts builds classical_bits" do
    counts = %{"01" => 2, "10" => 1}
    result = ResultBuilder.from_counts(counts, 3, 2)

    assert length(result.classical_bits) == 3
  end

  test "from_counts handles single-bit counts" do
    counts = %{"0" => 700, "1" => 300}
    result = ResultBuilder.from_counts(counts, 1000, 1)

    assert Nx.shape(result.probabilities) == {2}
    probs = Nx.to_flat_list(result.probabilities)
    assert_in_delta Enum.at(probs, 0), 0.7, 0.001
    assert_in_delta Enum.at(probs, 1), 0.3, 0.001
  end
end
