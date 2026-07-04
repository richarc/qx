# Compiled only when the optional :vega_lite dependency is present.
# Qx.Draw guards every call with a typed Qx.MissingDependencyError, so
# this module's absence is never observable as an UndefinedFunctionError.
if Code.ensure_loaded?(VegaLite) do
  defmodule Qx.Draw.VegaLite do
    @moduledoc false

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
    def counts(result, title, width, height) do
      if result.counts == %{} do
        # No measurements, show empty plot
        VegaLite.new(width: width, height: height, title: "No Measurements")
        |> VegaLite.data_from_values([])
        |> VegaLite.mark(:bar)
      else
        data =
          result.counts
          |> Enum.map(fn {bit_string, count} ->
            %{"measurement" => bit_string, "count" => count}
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
  end
end
