defmodule Qx.SimulationResult do
  @moduledoc """
  Result of quantum circuit simulation.

  This struct encapsulates all information from a circuit execution,
  including quantum state, measurement outcomes, and statistics.

  ## Fields

    * `:probabilities` - Probability amplitudes as Nx tensor
    * `:classical_bits` - List of measurement outcomes for each shot
    * `:state` - Final quantum state vector (Nx tensor)
    * `:shots` - Number of simulation shots executed
    * `:counts` - Frequency map of measurement outcomes

  ## Examples

      iex> circuit = Qx.create_circuit(2, 2)
      ...> |> Qx.h(0)
      ...> |> Qx.cx(0, 1)
      ...> |> Qx.measure(0, 0)
      ...> |> Qx.measure(1, 1)
      iex> result = Qx.run(circuit, 1000)
      iex> result.shots
      1000
      iex> Qx.SimulationResult.most_frequent(result)
      {"00", 503}

  """

  @type t :: %__MODULE__{
          probabilities: Nx.Tensor.t(),
          classical_bits: list(list(integer())),
          state: Nx.Tensor.t(),
          shots: pos_integer(),
          counts: %{String.t() => non_neg_integer()}
        }

  @enforce_keys [:probabilities, :classical_bits, :state, :shots, :counts]
  defstruct [:probabilities, :classical_bits, :state, :shots, :counts]

  @doc """
  Get the most frequent measurement outcome.

  ## Returns

  A tuple of `{outcome, count}` where outcome is a binary string like "01"
  and count is the number of times it occurred.

  ## Examples

      iex> result = %Qx.SimulationResult{
      ...>   probabilities: Nx.tensor([0.5, 0.5, 0.0, 0.0]),
      ...>   classical_bits: [[0, 0], [1, 1], [0, 0]],
      ...>   state: Nx.tensor([0.707, 0.0, 0.0, 0.707]),
      ...>   shots: 100,
      ...>   counts: %{"00" => 52, "11" => 48}
      ...> }
      iex> Qx.SimulationResult.most_frequent(result)
      {"00", 52}

  """
  @spec most_frequent(t()) :: {String.t(), non_neg_integer()}
  def most_frequent(%__MODULE__{counts: counts}) when map_size(counts) > 0 do
    Enum.max_by(counts, fn {_outcome, count} -> count end)
  end

  def most_frequent(%__MODULE__{counts: counts}) when map_size(counts) == 0 do
    {"", 0}
  end

  @doc """
  Get outcomes above a probability threshold.

  Filters measurement outcomes to only those that occurred with at least
  the specified probability.

  ## Parameters

    * `result` - Simulation result
    * `threshold` - Minimum probability (0.0 to 1.0)

  ## Returns

  A map of outcomes that meet the threshold.

  ## Examples

      iex> result = %Qx.SimulationResult{
      ...>   probabilities: Nx.tensor([0.5, 0.5, 0.0, 0.0]),
      ...>   classical_bits: [[0, 0], [1, 1], [0, 0]],
      ...>   state: Nx.tensor([0.707, 0.0, 0.0, 0.707]),
      ...>   shots: 100,
      ...>   counts: %{"00" => 52, "11" => 48}
      ...> }
      iex> Qx.SimulationResult.filter_by_probability(result, 0.5)
      %{"00" => 52}

  """
  @spec filter_by_probability(t(), float()) :: %{String.t() => non_neg_integer()}
  def filter_by_probability(%__MODULE__{counts: counts, shots: shots}, threshold)
      when is_float(threshold) and threshold >= 0.0 and threshold <= 1.0 do
    min_count = threshold * shots

    counts
    |> Enum.filter(fn {_outcome, count} -> count >= min_count end)
    |> Enum.into(%{})
  end

  @doc """
  Get all unique outcomes that occurred.

  ## Examples

      iex> result = %Qx.SimulationResult{
      ...>   probabilities: Nx.tensor([0.5, 0.5]),
      ...>   classical_bits: [[0], [1], [0]],
      ...>   state: Nx.tensor([0.707, 0.707]),
      ...>   shots: 100,
      ...>   counts: %{"0" => 52, "1" => 48}
      ...> }
      iex> Qx.SimulationResult.outcomes(result)
      ["0", "1"]

  """
  @spec outcomes(t()) :: list(String.t())
  def outcomes(%__MODULE__{counts: counts}) do
    counts
    |> Map.keys()
    |> Enum.sort()
  end

  @doc """
  Get the probability of a specific outcome.

  ## Examples

      iex> result = %Qx.SimulationResult{
      ...>   probabilities: Nx.tensor([0.5, 0.5]),
      ...>   classical_bits: [[0], [1]],
      ...>   state: Nx.tensor([0.707, 0.707]),
      ...>   shots: 100,
      ...>   counts: %{"0" => 52, "1" => 48}
      ...> }
      iex> Qx.SimulationResult.probability(result, "0")
      0.52

  """
  @spec probability(t(), String.t()) :: float()
  def probability(%__MODULE__{counts: counts, shots: shots}, outcome) do
    count = Map.get(counts, outcome, 0)
    count / shots
  end

  @doc """
  Convert result to a simplified map (for backwards compatibility).

  ## Examples

      iex> result = %Qx.SimulationResult{
      ...>   probabilities: Nx.tensor([1.0]),
      ...>   classical_bits: [[0]],
      ...>   state: Nx.tensor([1.0]),
      ...>   shots: 1,
      ...>   counts: %{"0" => 1}
      ...> }
      iex> map = Qx.SimulationResult.to_map(result)
      iex> Map.keys(map)
      [:probabilities, :classical_bits, :state, :shots, :counts]

  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = result) do
    Map.from_struct(result)
  end
end
