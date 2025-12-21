defmodule Qx.Draw do
  @moduledoc """
  Visualization functions for quantum simulation results.

  This module provides a clean API facade for all visualization capabilities,
  delegating to specialized sub-modules:

  - `Qx.Draw.VegaLite` - VegaLite chart generation (LiveBook integration)
  - `Qx.Draw.SVG.Charts` - SVG histogram and bar charts
  - `Qx.Draw.SVG.Bloch` - Bloch sphere visualization
  - `Qx.Draw.SVG.Circuit` - Quantum circuit diagrams
  - `Qx.Draw.Tables` - State table formatting

  ## Visualization Types

  ### Probability Plots
  - `plot/2` - Plot probability distribution from simulation results
  - `histogram/2` - Plot raw probability tensors

  ### Measurement Counts
  - `plot_counts/2` - Visualize measurement outcome frequencies

  ### Bloch Sphere
  - `bloch_sphere/2` - Visualize single-qubit states geometrically

  ### Circuit Diagrams
  - `circuit/2` - Generate SVG circuit diagrams with IEEE notation

  ### State Tables
  - `state_table/2` - Display quantum states in tabular format

  ## Output Formats

  Most functions support multiple output formats via the `:format` option:
  - `:vega_lite` - Interactive charts for LiveBook (default for plots)
  - `:svg` - Standalone SVG (works everywhere)
  - `:auto` - Auto-detect best format (for tables)
  - `:text` - Plain text tables
  - `:html` - HTML tables
  - `:markdown` - Markdown tables with Kino support

  ## Examples

      # VegaLite plot in LiveBook
      result = Qx.run(circuit)
      Qx.Draw.plot(result)

      # SVG output for saving to file
      Qx.Draw.plot(result, format: :svg)

      # Circuit diagram
      svg = Qx.Draw.circuit(circuit, "My Circuit")
      File.write!("circuit.svg", svg)

      # State table
      Qx.Draw.state_table(register, precision: 4, hide_zeros: true)
  """

  alias Qx.Draw.SVG.{Bloch, Charts, Circuit}
  alias Qx.Draw.{Tables, VegaLite}

  @doc """
  Plots the probability distribution from a simulation result.

  ## Parameters
    * `result` - Simulation result map containing probabilities
    * `options` - Optional plotting parameters (default: [])

  ## Options
    * `:format` - Output format (`:svg`, `:vega_lite`) (default: `:vega_lite`)
    * `:title` - Plot title (default: "Quantum State Probabilities")
    * `:width` - Plot width (default: 400)
    * `:height` - Plot height (default: 300)

  ## Examples

      qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
      result = Qx.run(qc)
      Qx.Draw.plot(result)

      # SVG output
      Qx.Draw.plot(result, format: :svg, title: "Bell State")
  """
  def plot(result, options \\ []) do
    format = Keyword.get(options, :format, :vega_lite)
    title = Keyword.get(options, :title, "Quantum State Probabilities")
    width = Keyword.get(options, :width, 400)
    height = Keyword.get(options, :height, 300)

    case format do
      :vega_lite ->
        VegaLite.plot(result, title, width, height)

      :svg ->
        Charts.plot(result, title, width, height)

      _ ->
        raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  @doc """
  Plots measurement counts as a bar chart.

  ## Parameters
    * `result` - Simulation result containing measurement counts
    * `options` - Optional plotting parameters (default: [])

  ## Options
    * `:format` - Output format (`:svg`, `:vega_lite`) (default: `:vega_lite`)
    * `:title` - Plot title (default: "Measurement Counts")
    * `:width` - Plot width (default: 400)
    * `:height` - Plot height (default: 300)

  ## Examples

      qc = Qx.create_circuit(2, 2)
      |> Qx.h(0) |> Qx.cx(0, 1)
      |> Qx.measure(0, 0) |> Qx.measure(1, 1)
      result = Qx.run(qc)
      Qx.Draw.plot_counts(result)
  """
  def plot_counts(result, options \\ []) do
    format = Keyword.get(options, :format, :vega_lite)
    title = Keyword.get(options, :title, "Measurement Counts")
    width = Keyword.get(options, :width, 400)
    height = Keyword.get(options, :height, 300)

    case format do
      :vega_lite ->
        VegaLite.plot_counts(result, title, width, height)

      :svg ->
        Charts.plot_counts(result, title, width, height)

      _ ->
        raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  @doc """
  Visualizes a single qubit state on the Bloch sphere.

  The Bloch sphere is a geometrical representation of pure qubit states.

  ## Parameters
    * `qubit` - Single qubit state tensor (2-element c64 tensor)
    * `options` - Optional plotting parameters (default: [])

  ## Options
    * `:format` - Output format (`:svg`, `:vega_lite`) (default: `:vega_lite`)
    * `:title` - Plot title (default: "Bloch Sphere")
    * `:size` - Sphere size (default: 400)

  ## Examples

      q = Qx.Qubit.new() |> Qx.Qubit.h()
      Qx.Draw.bloch_sphere(q)

      # SVG output
      Qx.Draw.bloch_sphere(q, format: :svg)
  """
  def bloch_sphere(qubit, options \\ []) do
    format = Keyword.get(options, :format, :vega_lite)
    title = Keyword.get(options, :title, "Bloch Sphere")
    size = Keyword.get(options, :size, 400)

    # Convert qubit state to Bloch coordinates
    coords = Bloch.qubit_to_bloch_coordinates(qubit)

    case format do
      :vega_lite ->
        VegaLite.bloch_sphere(coords, title, size)

      :svg ->
        Bloch.render(coords, title, size)

      _ ->
        raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  @doc """
  Creates a histogram from a raw probability tensor.

  ## Parameters
    * `probabilities` - Nx tensor of probabilities (must sum to 1.0)
    * `options` - Optional plotting parameters (default: [])

  ## Options
    * `:format` - Output format (`:svg`, `:vega_lite`) (default: `:vega_lite`)
    * `:title` - Plot title (default: "Probability Histogram")
    * `:width` - Plot width (default: 400)
    * `:height` - Plot height (default: 300)

  ## Examples

      qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.h(1)
      probs = Qx.get_probabilities(qc)
      Qx.Draw.histogram(probs)
  """
  def histogram(probabilities, options \\ []) do
    format = Keyword.get(options, :format, :vega_lite)
    title = Keyword.get(options, :title, "Probability Histogram")
    width = Keyword.get(options, :width, 400)
    height = Keyword.get(options, :height, 300)

    # Convert probabilities to data format
    probabilities_list = Nx.to_flat_list(probabilities)
    num_states = length(probabilities_list)

    data =
      probabilities_list
      |> Enum.with_index()
      |> Enum.map(fn {prob, index} ->
        state_label = Qx.Format.state_label(index, num_states)
        %{"state" => state_label, "probability" => prob}
      end)

    case format do
      :vega_lite ->
        VegaLite.histogram(data, title, width, height)

      :svg ->
        Charts.histogram(data, title, width, height)

      _ ->
        raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  @doc """
  Displays a quantum state as a formatted table.

  Shows basis states with their complex amplitudes and probabilities.

  ## Parameters
    * `register_or_state` - Either a `Qx.Register` struct or an `Nx.Tensor` state vector
    * `options` - Optional formatting parameters (default: [])

  ## Options
    * `:format` - Output format (`:auto`, `:text`, `:html`, `:markdown`) (default: `:auto`)
    * `:precision` - Number of decimal places (default: 3)
    * `:hide_zeros` - Hide states with near-zero probability (default: `false`)

  ## Examples

      register = Qx.Register.new(2)
      Qx.Draw.state_table(register)

      # Custom format
      Qx.Draw.state_table(register, format: :html, precision: 4)
  """
  def state_table(register_or_state, options \\ []) do
    Tables.render(register_or_state, options)
  end

  @doc """
  Draws a quantum circuit diagram as SVG.

  ## Parameters
    * `circuit` - `Qx.QuantumCircuit` struct to visualize
    * `title` - Optional circuit title (default: `nil`)

  ## Returns
  SVG string representing the complete circuit diagram.

  ## Examples

      qc = Qx.create_circuit(2, 2)
      |> Qx.h(0)
      |> Qx.cx(0, 1)
      |> Qx.measure(0, 0)
      |> Qx.measure(1, 1)

      svg = Qx.Draw.circuit(qc, "Bell State Circuit")
      File.write!("bell.svg", svg)
  """
  def circuit(%Qx.QuantumCircuit{} = circuit, title \\ nil) do
    Circuit.render(circuit, title)
  end
end
