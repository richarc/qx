defmodule Qx.ResultBuilder do
  @moduledoc """
  Builds `Qx.SimulationResult` structs from counts data.

  Used by `Qx.Remote` to reconstruct results from the qx_server JSON
  response, and by provider adapters when converting hardware results.

  > #### Statevector placeholder {: .warning}
  >
  > Hardware backends do not return statevectors. The `state` field in
  > the resulting `Qx.SimulationResult` is set to a zero-vector placeholder.
  > Functions that depend on the statevector (e.g. state visualization) will
  > not produce meaningful output for hardware results. Use `counts` and
  > `probabilities` instead.
  """

  @doc """
  Builds a `Qx.SimulationResult` from a counts map, shot count, and
  number of classical bits.

  ## Parameters

    * `counts` - Map of binary string outcomes to frequencies, e.g. `%{"00" => 520, "11" => 480}`
    * `shots` - Total number of shots executed
    * `num_bits` - Number of classical bits in the circuit

  The `state` field will be a zero-vector placeholder since hardware backends
  do not return statevectors.

  ## Examples

      result = Qx.ResultBuilder.from_counts(%{"00" => 500, "11" => 500}, 1000, 2)
      result.shots
      #=> 1000
      result.counts
      #=> %{"00" => 500, "11" => 500}

  """
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
