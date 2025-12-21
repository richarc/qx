defmodule Qx.Draw.VegaLite do
  @moduledoc """
  VegaLite visualization functions for quantum simulation results.

  This module handles all VegaLite-based chart generation, including:
  - Probability distribution plots
  - Measurement count histograms
  - Raw probability histograms
  - Bloch sphere 2D projections

  VegaLite visualizations are particularly useful in LiveBook environments
  where they provide interactive, publication-quality charts.

  ## Internal Module

  This module is part of the Qx.Draw refactoring and should be accessed
  through the public `Qx.Draw` API rather than directly.
  """

  @doc """
  Creates a VegaLite plot of probability distribution from simulation result.

  ## Parameters
    * `result` - Simulation result map containing probabilities
    * `title` - Plot title
    * `width` - Plot width in pixels
    * `height` - Plot height in pixels

  ## Returns
  VegaLite specification that can be rendered in LiveBook or converted to other formats.
  """
  def plot(result, title, width, height) do
    probabilities = Nx.to_flat_list(result.probabilities)
    num_states = length(probabilities)

    data =
      probabilities
      |> Enum.with_index()
      |> Enum.map(fn {prob, index} ->
        state_label = Qx.Format.state_label(index, num_states)
        %{"state" => state_label, "probability" => prob}
      end)

    VegaLite.new(width: width, height: height, title: title)
    |> VegaLite.data_from_values(data)
    |> VegaLite.mark(:bar)
    |> VegaLite.encode_field(:x, "state", type: :nominal, title: "Quantum State")
    |> VegaLite.encode_field(:y, "probability", type: :quantitative, title: "Probability")
    |> VegaLite.encode(:color, value: "#1f77b4")
  end

  @doc """
  Creates a VegaLite plot of measurement counts from simulation result.

  ## Parameters
    * `result` - Simulation result containing measurement counts
    * `title` - Plot title
    * `width` - Plot width in pixels
    * `height` - Plot height in pixels

  ## Returns
  VegaLite specification showing count distribution of measurement outcomes.
  """
  def plot_counts(result, title, width, height) do
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

  @doc """
  Creates a VegaLite histogram from raw probability data.

  ## Parameters
    * `data` - List of maps with "state" and "probability" keys
    * `title` - Plot title
    * `width` - Plot width in pixels
    * `height` - Plot height in pixels

  ## Returns
  VegaLite specification for probability histogram.
  """
  def histogram(data, title, width, height) do
    VegaLite.new(width: width, height: height, title: title)
    |> VegaLite.data_from_values(data)
    |> VegaLite.mark(:bar)
    |> VegaLite.encode_field(:x, "state", type: :nominal, title: "Quantum State")
    |> VegaLite.encode_field(:y, "probability", type: :quantitative, title: "Probability")
    |> VegaLite.encode(:color, value: "#2ca02c")
  end

  @doc """
  Creates a VegaLite visualization of a qubit state on the Bloch sphere.

  Since VegaLite doesn't support native 3D rendering, this creates a 2D projection
  of the state vector onto the XZ plane.

  ## Parameters
    * `coords` - Tuple of {x, y, z, theta, phi} Bloch sphere coordinates
    * `title` - Plot title
    * `size` - Size of the plot (width and height) in pixels

  ## Returns
  VegaLite specification showing the 2D projection of the Bloch sphere state.

  ## Bloch Sphere Representation
  - |0⟩ state appears at the top (z = +1)
  - |1⟩ state appears at the bottom (z = -1)
  - |+⟩ state appears at the right (x = +1)
  - |-⟩ state appears at the left (x = -1)
  """
  def bloch_sphere({x, _y, z, _theta, _phi}, title, size) do
    # Create a simple 2D representation showing the state vector projection
    # onto the XZ plane (standard view)
    data = [
      # Axes
      %{"type" => "axis", "x" => 0, "y" => 0, "x2" => 1, "y2" => 0, "label" => "X"},
      %{"type" => "axis", "x" => 0, "y" => 0, "x2" => 0, "y2" => 1, "label" => "Z"},
      %{"type" => "axis", "x" => 0, "y" => 0, "x2" => -1, "y2" => 0, "label" => "-X"},
      %{"type" => "axis", "x" => 0, "y" => 0, "x2" => 0, "y2" => -1, "label" => "-Z"},
      # State vector
      %{"type" => "vector", "x" => 0, "y" => 0, "x2" => x, "y2" => z, "label" => "State"}
    ]

    VegaLite.new(width: size, height: size, title: title)
    |> VegaLite.data_from_values(data)
    |> VegaLite.layers([
      VegaLite.new()
      |> VegaLite.mark(:rule, color: "#cccccc")
      |> VegaLite.encode_field(:x, "x", type: :quantitative, scale: [domain: [-1.2, 1.2]])
      |> VegaLite.encode_field(:y, "y", type: :quantitative, scale: [domain: [-1.2, 1.2]])
      |> VegaLite.encode_field(:x2, "x2")
      |> VegaLite.encode_field(:y2, "y2")
      |> VegaLite.transform(filter: "datum.type == 'axis'"),
      VegaLite.new()
      |> VegaLite.mark(:rule, color: "#ff0000", stroke_width: 3)
      |> VegaLite.encode_field(:x, "x", type: :quantitative)
      |> VegaLite.encode_field(:y, "y", type: :quantitative)
      |> VegaLite.encode_field(:x2, "x2")
      |> VegaLite.encode_field(:y2, "y2")
      |> VegaLite.transform(filter: "datum.type == 'vector'"),
      VegaLite.new()
      |> VegaLite.mark(:point, color: "#ff0000", size: 100)
      |> VegaLite.encode_field(:x, "x2", type: :quantitative)
      |> VegaLite.encode_field(:y, "y2", type: :quantitative)
      |> VegaLite.transform(filter: "datum.type == 'vector'")
    ])
  end
end
