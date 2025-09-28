defmodule Qx.Draw do
  @moduledoc """
  Visualization functions for quantum simulation results.

  This module provides functions for plotting quantum simulation results,
  including probability distributions and measurement outcomes, with support
  for SVG output and LiveBook integration with VegaLite.
  """

  @doc """
  Plots the probability distribution of quantum states.

  ## Parameters
    * `result` - Simulation result containing probabilities
    * `options` - Optional plotting parameters (default: [])

  ## Options
    * `:format` - Output format (:svg, :vega_lite) (default: :vega_lite)
    * `:title` - Plot title (default: "Quantum State Probabilities")
    * `:width` - Plot width (default: 400)
    * `:height` - Plot height (default: 300)

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 0) |> Qx.Operations.h(0)
      iex> result = Qx.Simulation.run(qc)
      iex> Qx.Draw.plot(result)
      # Returns VegaLite specification
  """
  def plot(result, options \\ []) do
    format = Keyword.get(options, :format, :vega_lite)
    title = Keyword.get(options, :title, "Quantum State Probabilities")
    width = Keyword.get(options, :width, 400)
    height = Keyword.get(options, :height, 300)

    case format do
      :vega_lite ->
        plot_vega_lite(result, title, width, height)

      :svg ->
        plot_svg(result, title, width, height)

      _ ->
        raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  @doc """
  Plots measurement counts as a bar chart.

  ## Parameters
    * `result` - Simulation result containing measurement counts
    * `options` - Optional plotting parameters (default: [])

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 2)
      iex> qc = qc |> Qx.Operations.h(0) |> Qx.Operations.cx(0, 1)
      iex> qc = qc |> Qx.Operations.measure(0, 0) |> Qx.Operations.measure(1, 1)
      iex> result = Qx.Simulation.run(qc)
      iex> Qx.Draw.plot_counts(result)
      # Returns VegaLite specification for measurement counts
  """
  def plot_counts(result, options \\ []) do
    format = Keyword.get(options, :format, :vega_lite)
    title = Keyword.get(options, :title, "Measurement Counts")
    width = Keyword.get(options, :width, 400)
    height = Keyword.get(options, :height, 300)

    case format do
      :vega_lite ->
        plot_counts_vega_lite(result, title, width, height)

      :svg ->
        plot_counts_svg(result, title, width, height)

      _ ->
        raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  @doc """
  Creates a histogram of quantum state probabilities.

  ## Parameters
    * `probabilities` - Nx tensor of probabilities
    * `options` - Optional plotting parameters (default: [])

  ## Examples

      iex> probs = Nx.tensor([0.5, 0.5, 0.0, 0.0])
      iex> Qx.Draw.histogram(probs)
      # Returns VegaLite specification
  """
  def histogram(probabilities, options \\ []) do
    format = Keyword.get(options, :format, :vega_lite)
    title = Keyword.get(options, :title, "Probability Histogram")
    width = Keyword.get(options, :width, 400)
    height = Keyword.get(options, :height, 300)

    # Convert probabilities to data format
    prob_list = Nx.to_flat_list(probabilities)
    num_states = length(prob_list)

    data =
      prob_list
      |> Enum.with_index()
      |> Enum.map(fn {prob, index} ->
        state_label =
          "|#{Integer.to_string(index, 2) |> String.pad_leading(trunc(:math.log2(num_states)), "0")}⟩"

        %{"state" => state_label, "probability" => prob, "index" => index}
      end)

    case format do
      :vega_lite ->
        histogram_vega_lite(data, title, width, height)

      :svg ->
        histogram_svg(data, title, width, height)

      _ ->
        raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  # Private helper functions

  defp plot_vega_lite(result, title, width, height) do
    probabilities = Nx.to_flat_list(result.probabilities)
    num_states = length(probabilities)

    data =
      probabilities
      |> Enum.with_index()
      |> Enum.map(fn {prob, index} ->
        state_label = format_state_label(index, num_states)
        %{"state" => state_label, "probability" => prob}
      end)

    VegaLite.new(width: width, height: height, title: title)
    |> VegaLite.data_from_values(data)
    |> VegaLite.mark(:bar)
    |> VegaLite.encode_field(:x, "state", type: :nominal, title: "Quantum State")
    |> VegaLite.encode_field(:y, "probability", type: :quantitative, title: "Probability")
    |> VegaLite.encode(:color, value: "#1f77b4")
  end

  defp plot_counts_vega_lite(result, title, width, height) do
    if result.counts == %{} do
      # No measurements, show empty plot
      VegaLite.new(width: width, height: height, title: "No Measurements")
      |> VegaLite.data_from_values([])
      |> VegaLite.mark(:bar)
    else
      data =
        result.counts
        |> Enum.map(fn {bit_string, count} ->
          label = Enum.join(bit_string, "")
          %{"measurement" => label, "count" => count}
        end)

      VegaLite.new(width: width, height: height, title: title)
      |> VegaLite.data_from_values(data)
      |> VegaLite.mark(:bar)
      |> VegaLite.encode_field(:x, "measurement", type: :nominal, title: "Measurement Outcome")
      |> VegaLite.encode_field(:y, "count", type: :quantitative, title: "Count")
      |> VegaLite.encode(:color, value: "#ff7f0e")
    end
  end

  defp histogram_vega_lite(data, title, width, height) do
    VegaLite.new(width: width, height: height, title: title)
    |> VegaLite.data_from_values(data)
    |> VegaLite.mark(:bar)
    |> VegaLite.encode_field(:x, "state", type: :nominal, title: "Quantum State")
    |> VegaLite.encode_field(:y, "probability", type: :quantitative, title: "Probability")
    |> VegaLite.encode(:color, value: "#2ca02c")
  end

  defp plot_svg(result, title, width, height) do
    probabilities = Nx.to_flat_list(result.probabilities)
    num_states = length(probabilities)
    max_prob = Enum.max(probabilities)

    # Calculate bar dimensions
    bar_width = width / num_states * 0.8
    bar_spacing = width / num_states * 0.2

    # Generate SVG bars
    bars =
      probabilities
      |> Enum.with_index()
      |> Enum.map(fn {prob, index} ->
        bar_height = if max_prob > 0, do: prob / max_prob * (height - 50), else: 0
        x = index * (bar_width + bar_spacing) + bar_spacing / 2
        y = height - 30 - bar_height

        state_label = format_state_label(index, num_states)

        """
        <rect x="#{x}" y="#{y}" width="#{bar_width}" height="#{bar_height}"
              fill="#1f77b4" stroke="#000" stroke-width="0.5"/>
        <text x="#{x + bar_width / 2}" y="#{height - 10}" text-anchor="middle"
              font-size="10" font-family="Arial">#{state_label}</text>
        <text x="#{x + bar_width / 2}" y="#{y - 5}" text-anchor="middle"
              font-size="8" font-family="Arial">#{Float.round(prob, 3)}</text>
        """
      end)
      |> Enum.join("\n")

    """
    <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
      <title>#{title}</title>
      <text x="#{width / 2}" y="20" text-anchor="middle" font-size="14" font-family="Arial" font-weight="bold">#{title}</text>
      #{bars}
      <text x="#{width / 2}" y="#{height - 2}" text-anchor="middle" font-size="12" font-family="Arial">Quantum State</text>
    </svg>
    """
  end

  defp plot_counts_svg(result, title, width, height) do
    if result.counts == %{} do
      """
      <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
        <title>No Measurements</title>
        <text x="#{width / 2}" y="#{height / 2}" text-anchor="middle" font-size="14" font-family="Arial">No Measurements</text>
      </svg>
      """
    else
      counts = Enum.to_list(result.counts)
      max_count = counts |> Enum.map(&elem(&1, 1)) |> Enum.max()
      num_outcomes = length(counts)

      # Calculate bar dimensions
      bar_width = width / num_outcomes * 0.8
      bar_spacing = width / num_outcomes * 0.2

      bars =
        counts
        |> Enum.with_index()
        |> Enum.map(fn {{bit_string, count}, index} ->
          bar_height = if max_count > 0, do: count / max_count * (height - 50), else: 0
          x = index * (bar_width + bar_spacing) + bar_spacing / 2
          y = height - 30 - bar_height

          label = Enum.join(bit_string, "")

          """
          <rect x="#{x}" y="#{y}" width="#{bar_width}" height="#{bar_height}"
                fill="#ff7f0e" stroke="#000" stroke-width="0.5"/>
          <text x="#{x + bar_width / 2}" y="#{height - 10}" text-anchor="middle"
                font-size="10" font-family="Arial">#{label}</text>
          <text x="#{x + bar_width / 2}" y="#{y - 5}" text-anchor="middle"
                font-size="8" font-family="Arial">#{count}</text>
          """
        end)
        |> Enum.join("\n")

      """
      <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
        <title>#{title}</title>
        <text x="#{width / 2}" y="20" text-anchor="middle" font-size="14" font-family="Arial" font-weight="bold">#{title}</text>
        #{bars}
        <text x="#{width / 2}" y="#{height - 2}" text-anchor="middle" font-size="12" font-family="Arial">Measurement Outcome</text>
      </svg>
      """
    end
  end

  defp histogram_svg(data, title, width, height) do
    max_prob = data |> Enum.map(&Map.get(&1, "probability")) |> Enum.max()
    num_states = length(data)

    # Calculate bar dimensions
    bar_width = width / num_states * 0.8
    bar_spacing = width / num_states * 0.2

    bars =
      data
      |> Enum.with_index()
      |> Enum.map(fn {%{"state" => state, "probability" => prob}, index} ->
        bar_height = if max_prob > 0, do: prob / max_prob * (height - 50), else: 0
        x = index * (bar_width + bar_spacing) + bar_spacing / 2
        y = height - 30 - bar_height

        """
        <rect x="#{x}" y="#{y}" width="#{bar_width}" height="#{bar_height}"
              fill="#2ca02c" stroke="#000" stroke-width="0.5"/>
        <text x="#{x + bar_width / 2}" y="#{height - 10}" text-anchor="middle"
              font-size="10" font-family="Arial">#{state}</text>
        <text x="#{x + bar_width / 2}" y="#{y - 5}" text-anchor="middle"
              font-size="8" font-family="Arial">#{Float.round(prob, 3)}</text>
        """
      end)
      |> Enum.join("\n")

    """
    <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
      <title>#{title}</title>
      <text x="#{width / 2}" y="20" text-anchor="middle" font-size="14" font-family="Arial" font-weight="bold">#{title}</text>
      #{bars}
      <text x="#{width / 2}" y="#{height - 2}" text-anchor="middle" font-size="12" font-family="Arial">Quantum State</text>
    </svg>
    """
  end

  defp format_state_label(index, num_states) do
    num_qubits = trunc(:math.log2(num_states))
    binary_string = Integer.to_string(index, 2) |> String.pad_leading(num_qubits, "0")
    "|#{binary_string}⟩"
  end
end
