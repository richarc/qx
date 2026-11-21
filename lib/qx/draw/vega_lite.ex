# Compiled only when the optional :vega_lite dependency is present.
# Qx.Draw guards every call with a typed Qx.MissingDependencyError, so
# this module's absence is never observable as an UndefinedFunctionError.
if Code.ensure_loaded?(VegaLite) do
  defmodule Qx.Draw.VegaLite do
    @moduledoc false

    # The three bar charts of Qx.Draw, built by one function so they share
    # the config, colour, axis and label rules of the Qx visual design
    # guide (Charts sheet). The colour comes from the config's `bar.color`:
    # nothing here sets one.

    alias Qx.Draw.Theme

    # Basis-state labels are level kets up to this many bars, and bare bit
    # strings set vertically beyond it.
    @ket_limit 16
    # Beyond this many bars only every fourth label is shown.
    @thin_limit 64
    @thin_step 4
    # Bars carry their value above them up to this many bars.
    @value_label_limit 8

    @x_title "Basis state"

    # The probability axis runs from 0 to 1, so two charts can be compared
    # by eye, as long as some bar reaches this height. When every bar is
    # shorter (a distribution spread over many states) the bars would be a
    # few pixels tall, so the axis fits the data instead. The margin keeps
    # a bar that rounding left a hair under 0.2 on the fixed side.
    @fixed_axis_min 0.2 - 1.0e-6
    @fixed_axis [scale: [domain: [0, 1]], axis: [format: ".2f"]]
    @fitted_axis [scale: [zero: true, nice: true]]

    @probability %{
      x_field: "state",
      # The data holds kets: "|01⟩".
      x_values: :kets,
      y_field: "probability",
      y_title: "Probability",
      y_options: @fixed_axis,
      value_format: ".2f"
    }

    @counts %{
      x_field: "measurement",
      # The data holds bare bit strings: "01".
      x_values: :bit_strings,
      y_field: "count",
      y_title: "Counts",
      y_options: [scale: [zero: true, nice: true]],
      value_format: "d"
    }

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
      histogram(Nx.to_flat_list(result.probabilities), title, width, height)
    end

    @doc """
    Creates a VegaLite plot of measurement counts from simulation result.

    Bars are in bit-string order.

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
        VegaLite.new(width: width, height: height, title: title)
        |> VegaLite.config(Theme.vega_config())
        |> VegaLite.data_from_values([])
        |> VegaLite.mark(:bar)
      else
        # A map is in key order only up to 32 keys, and the x encoding
        # keeps the data order (`sort: nil`), so sort here.
        data =
          result.counts
          |> Enum.sort_by(fn {bit_string, _count} -> bit_string end)
          |> Enum.map(fn {bit_string, count} ->
            %{"measurement" => bit_string, "count" => count}
          end)

        bar_chart(data, @counts, title, width, height)
      end
    end

    @doc """
    Creates a VegaLite histogram from a list of probabilities.

    ## Parameters
      * `probabilities` - One probability per basis state, in index order
      * `title` - Plot title
      * `width` - Plot width in pixels
      * `height` - Plot height in pixels

    ## Returns
    VegaLite specification for probability histogram.
    """
    def histogram(probabilities, title, width, height) do
      num_states = length(probabilities)

      data =
        probabilities
        |> Enum.with_index()
        |> Enum.map(fn {probability, index} ->
          %{"state" => Qx.Format.state_label(index, num_states), "probability" => probability}
        end)

      kind = %{@probability | y_options: probability_axis(probabilities)}
      bar_chart(data, kind, title, width, height)
    end

    defp probability_axis(probabilities) do
      if Enum.max(probabilities, fn -> 0 end) >= @fixed_axis_min,
        do: @fixed_axis,
        else: @fitted_axis
    end

    defp bar_chart(data, kind, title, width, height) do
      bars = length(data)

      VegaLite.new(width: width, height: height, title: title)
      |> VegaLite.config(Theme.vega_config())
      |> VegaLite.data_from_values(data)
      |> VegaLite.encode_field(:x, kind.x_field, x_options(data, bars, kind))
      |> VegaLite.encode_field(
        :y,
        kind.y_field,
        [type: :quantitative, title: kind.y_title] ++ kind.y_options
      )
      |> marks(bars, kind)
    end

    # Few bars: the bars and their values above them, as two layers that
    # share the encodings above. Otherwise the bars alone.
    defp marks(chart, bars, kind) when bars <= @value_label_limit do
      VegaLite.layers(chart, [
        VegaLite.mark(VegaLite.new(), :bar),
        VegaLite.new()
        |> VegaLite.mark(:text,
          color: Theme.color(:ink),
          font_size: 11,
          baseline: :bottom,
          dy: -4
        )
        |> VegaLite.encode_field(:text, kind.y_field,
          type: :quantitative,
          format: kind.value_format
        )
      ])
    end

    defp marks(chart, _bars, _kind), do: VegaLite.mark(chart, :bar)

    defp x_options(data, bars, kind) do
      base = [type: :nominal, title: @x_title, sort: nil]

      case x_axis(data, bars, kind) do
        [] -> base
        axis -> base ++ [axis: axis]
      end
    end

    defp x_axis(data, bars, kind) do
      label_form(kind.x_values, bars) ++ thinned_values(data, bars, kind.x_field)
    end

    # Kets, level, while they fit; then bare bit strings set vertically.
    # The config already sets the label angle to 0.
    defp label_form(:kets, bars) when bars <= @ket_limit, do: []

    defp label_form(:kets, _bars),
      do: [label_expr: label_expr("slice(datum.value, 1, -1)"), label_angle: -90]

    defp label_form(:bit_strings, bars) when bars <= @ket_limit,
      do: [label_expr: label_expr("'|' + datum.value + '⟩'")]

    defp label_form(:bit_strings, _bars), do: [label_angle: -90]

    # A host can add a tick that has no value: Livebook's chart theme sets
    # `axisBand.tickExtra`. An expression that slices or joins a missing
    # value fails in Vega and the whole chart draws empty, so every label
    # expression checks the value first.
    defp label_expr(expression), do: "isString(datum.value) ? #{expression} : ''"

    defp thinned_values(_data, bars, _x_field) when bars <= @thin_limit, do: []

    defp thinned_values(data, _bars, x_field) do
      [values: data |> Enum.take_every(@thin_step) |> Enum.map(&Map.fetch!(&1, x_field))]
    end
  end
end
