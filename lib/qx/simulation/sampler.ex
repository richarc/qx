defmodule Qx.Simulation.Sampler do
  @moduledoc false

  # Internal: shot sampler for `Qx.Simulation.run/2` on circuits without
  # conditionals. Not part of the public API.
  #
  # The cumulative distribution is computed once in Nx (f64, so the running
  # sum of the f32 outcome probabilities loses nothing to rounding) and
  # reaches the host in one sync as a tuple. Each shot is then one
  # `:rand.uniform/0` draw and an O(n) binary search for the first index `i`
  # with `draw <= cumulative[i]`, which maps every draw to the same outcome a
  # linear `Enum.find_index/2` scan would, for O(2^n + shots·n) total work
  # instead of O(shots · 2^n).
  #
  # The f32 probabilities can sum to slightly less than 1. A draw above the
  # total is clamped to it, so it maps to the first index that reaches the
  # total, which is the last outcome with non-zero probability (never a
  # zero-probability outcome).

  import Nx.Defn

  @doc """
  Returns the cumulative sums of `probabilities` (a rank-1 tensor) as a tuple
  of floats.
  """
  @spec cumulative(Nx.Tensor.t()) :: tuple()
  def cumulative(probabilities) do
    probabilities
    |> cumulative_f64()
    |> Nx.to_flat_list()
    |> List.to_tuple()
  end

  @doc """
  Draws `shots` outcome indices from a `cumulative/1` tuple, one
  `:rand.uniform/0` (process RNG) per shot.
  """
  @spec sample(tuple(), pos_integer()) :: [non_neg_integer()]
  def sample(cumulative, shots)
      when tuple_size(cumulative) > 0 and is_integer(shots) and shots > 0 do
    last = tuple_size(cumulative) - 1
    total = elem(cumulative, last)

    for _ <- 1..shots do
      draw = min(:rand.uniform(), total)
      first_reaching(cumulative, draw, 0, last)
    end
  end

  defnp cumulative_f64(probabilities) do
    probabilities |> Nx.as_type(:f64) |> Nx.cumulative_sum()
  end

  # First index in lo..hi whose cumulative value is >= draw. The cumulative
  # sums are non-decreasing and draw <= elem(cumulative, hi), so one exists.
  defp first_reaching(_cumulative, _draw, index, index), do: index

  defp first_reaching(cumulative, draw, lo, hi) do
    mid = div(lo + hi, 2)

    if draw <= elem(cumulative, mid) do
      first_reaching(cumulative, draw, lo, mid)
    else
      first_reaching(cumulative, draw, mid + 1, hi)
    end
  end
end
