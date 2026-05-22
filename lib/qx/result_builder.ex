defmodule Qx.ResultBuilder do
  @moduledoc false

  # Internal: builds `Qx.SimulationResult` structs from counts data. Used by
  # `Qx.Hardware` and provider adapters to convert hardware shot-based
  # responses (e.g. IBM Quantum) into the unified `SimulationResult` shape.
  # The `state` field is set to a zero-vector placeholder since hardware
  # backends don't return statevectors — use `counts`/`probabilities` only.

  @doc false
  @spec from_counts(map(), pos_integer(), pos_integer()) :: Qx.SimulationResult.t()
  def from_counts(counts, shots, num_bits)
      when is_map(counts) and is_integer(shots) and is_integer(num_bits) do
    total_counts = Enum.reduce(counts, 0, fn {_k, v}, acc -> acc + v end)

    probabilities =
      counts
      |> Enum.map(fn {outcome, count} ->
        index = String.to_integer(outcome, 2)
        {index, count / max(total_counts, 1)}
      end)
      |> build_probability_tensor(num_bits)

    classical_bits =
      counts
      |> Enum.flat_map(fn {outcome, count} ->
        bits = outcome |> String.graphemes() |> Enum.map(&String.to_integer/1)
        List.duplicate(bits, count)
      end)

    # Hardware backends don't return statevectors, use a zero-vector placeholder
    state_size = Integer.pow(2, num_bits)
    state = Nx.broadcast(Nx.tensor(0.0), {state_size})

    %Qx.SimulationResult{
      counts: counts,
      probabilities: probabilities,
      classical_bits: classical_bits,
      state: state,
      shots: shots
    }
  end

  defp build_probability_tensor(index_prob_pairs, num_bits) do
    size = Integer.pow(2, num_bits)
    probs = List.duplicate(0.0, size)

    probs =
      Enum.reduce(index_prob_pairs, probs, fn {index, prob}, acc ->
        if index < size, do: List.replace_at(acc, index, prob), else: acc
      end)

    Nx.tensor(probs)
  end
end
