defmodule Qx.SimulationResultSeamTest do
  @moduledoc """
  Seam tests: every counts-consuming `Qx.SimulationResult` helper run
  against real `Qx.run/2` output, never a hand-built fixture.

  Regression guard for api-consistency-review R-01, where the engine
  emitted bit-list counts keys for four releases while every doc,
  type, and hand-built doctest promised strings — and nothing executed
  the seam to notice.
  """
  use ExUnit.Case, async: true

  doctest Qx.SimulationResult

  alias Qx.SimulationResult

  test "counts keys are binary strings matching the draw_counts labels" do
    result =
      Qx.create_circuit(2, 2)
      |> Qx.x(0)
      |> Qx.measure_all()
      |> Qx.run(shots: 50)

    assert result.counts == %{"10" => 50}
  end

  test "every helper works on a real Bell-state result" do
    result =
      Qx.create_circuit(2, 2)
      |> Qx.h(0)
      |> Qx.cx(0, 1)
      |> Qx.measure_all()
      |> Qx.run(shots: 1024)

    {outcome, count} = SimulationResult.most_frequent(result)
    assert outcome in ["00", "11"]
    assert count >= 512

    assert SimulationResult.outcomes(result) == ["00", "11"]

    p = SimulationResult.probability(result, "00") + SimulationResult.probability(result, "11")
    assert_in_delta p, 1.0, 1.0e-9
    assert SimulationResult.probability(result, "01") == 0.0

    filtered = SimulationResult.filter_by_probability(result, 0.25)
    assert filtered |> Map.keys() |> Enum.sort() == ["00", "11"]
  end

  test "conditional (c_if) runs use the same string-key contract" do
    result =
      Qx.create_circuit(2, 2)
      |> Qx.x(0)
      |> Qx.measure(0, 0)
      |> Qx.c_if(0, 1, fn qc -> Qx.x(qc, 1) end)
      |> Qx.measure(1, 1)
      |> Qx.run(shots: 20)

    assert result.counts == %{"11" => 20}
  end
end
