defmodule Qx.Draw.SVG.Charts do
  @moduledoc """
  SVG chart generation for quantum simulation results.

  This module handles all SVG-based chart rendering, including:
  - Probability distribution bar charts
  - Measurement count histograms
  - Raw probability histograms

  SVG visualizations are standalone and can be embedded in web pages,
  saved to files, or used in environments where VegaLite is not available.

  ## Internal Module

  This module is part of the Qx.Draw refactoring and should be accessed
  through the public `Qx.Draw` API rather than directly.
  """

  @doc """
  Creates an SVG bar chart of probability distribution from simulation result.

  ## Parameters
    * `result` - Simulation result map containing probabilities
    * `title` - Chart title
    * `width` - Chart width in pixels
    * `height` - Chart height in pixels

  ## Returns
  SVG string that can be saved to file or embedded in HTML.
  """
  def plot(result, title, width, height) do
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
      |> Enum.map_join("\n", fn {prob, index} ->
        bar_height = if max_prob > 0, do: prob / max_prob * (height - 50), else: 0
        x = index * (bar_width + bar_spacing) + bar_spacing / 2
        y = height - 30 - bar_height

        state_label = Qx.Format.state_label(index, num_states)

        """
        <rect x="#{x}" y="#{y}" width="#{bar_width}" height="#{bar_height}"
              fill="#1f77b4" stroke="#000" stroke-width="0.5"/>
        <text x="#{x + bar_width / 2}" y="#{height - 10}" text-anchor="middle"
              font-size="10" font-family="Arial">#{state_label}</text>
        <text x="#{x + bar_width / 2}" y="#{y - 5}" text-anchor="middle"
              font-size="8" font-family="Arial">#{Float.round(prob, 3)}</text>
        """
      end)

    """
    <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
      <title>#{title}</title>
      <text x="#{width / 2}" y="20" text-anchor="middle" font-size="14" font-family="Arial" font-weight="bold">#{title}</text>
      #{bars}
      <text x="#{width / 2}" y="#{height - 2}" text-anchor="middle" font-size="12" font-family="Arial">Quantum State</text>
    </svg>
    """
  end

  @doc """
  Creates an SVG bar chart of measurement counts from simulation result.

  ## Parameters
    * `result` - Simulation result containing measurement counts
    * `title` - Chart title
    * `width` - Chart width in pixels
    * `height` - Chart height in pixels

  ## Returns
  SVG string showing count distribution of measurement outcomes.
  """
  def plot_counts(result, title, width, height) do
    if result.counts == %{} do
      render_empty_counts(width, height)
    else
      render_counts_histogram(result.counts, title, width, height)
    end
  end

  @doc """
  Creates an SVG histogram from raw probability data.

  ## Parameters
    * `data` - List of maps with "state" and "probability" keys
    * `title` - Chart title
    * `width` - Chart width in pixels
    * `height` - Chart height in pixels

  ## Returns
  SVG string for probability histogram.
  """
  def histogram(data, title, width, height) do
    max_prob = data |> Enum.map(&Map.get(&1, "probability")) |> Enum.max()
    num_states = length(data)

    # Calculate bar dimensions
    bar_width = width / num_states * 0.8
    bar_spacing = width / num_states * 0.2

    bars =
      data
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {%{"state" => state, "probability" => prob}, index} ->
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

    """
    <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
      <title>#{title}</title>
      <text x="#{width / 2}" y="20" text-anchor="middle" font-size="14" font-family="Arial" font-weight="bold">#{title}</text>
      #{bars}
      <text x="#{width / 2}" y="#{height - 2}" text-anchor="middle" font-size="12" font-family="Arial">Quantum State</text>
    </svg>
    """
  end

  # Private helper to render empty counts chart
  defp render_empty_counts(width, height) do
    """
    <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
      <title>No Measurements</title>
      <text x="#{width / 2}" y="#{height / 2}" text-anchor="middle" font-size="14" font-family="Arial">No Measurements</text>
    </svg>
    """
  end

  # Private helper to render counts histogram
  defp render_counts_histogram(counts_map, title, width, height) do
    counts = Enum.to_list(counts_map)
    max_count = counts |> Enum.map(&elem(&1, 1)) |> Enum.max()
    num_outcomes = length(counts)

    # Calculate bar dimensions
    bar_width = width / num_outcomes * 0.8
    bar_spacing = width / num_outcomes * 0.2

    bars =
      counts
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {{bit_string, count}, index} ->
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
