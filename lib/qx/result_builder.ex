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

  # Scatters the probabilities onto an f32 zero tensor, with no host-side list
  # of 2^num_bits elements (Iron Law #5). Pairs whose index is outside the
  # tensor are dropped. When two pairs share an index the later one wins; they
  # are collapsed here with `Map.new/1` because `Nx.indexed_put/3` does not
  # define an order for repeated indices.
  defp build_probability_tensor(index_prob_pairs, num_bits) do
    size = Integer.pow(2, num_bits)
    zeros = Nx.broadcast(Nx.tensor(0.0, type: :f32), {size})

    in_range =
      index_prob_pairs
      |> Enum.filter(fn {index, _prob} -> index >= 0 and index < size end)
      |> Map.new()
      |> Map.to_list()

    case in_range do
      # `Nx.indexed_put/3` cannot take an empty update.
      [] ->
        zeros

      pairs ->
        {indices, probs} = Enum.unzip(pairs)

        Nx.indexed_put(
          zeros,
          Nx.tensor(Enum.map(indices, &[&1])),
          Nx.tensor(probs, type: :f32)
        )
    end
  end
end
