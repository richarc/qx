defmodule Qx.Draw.ChartStyleTest do
  @moduledoc """
  The three Vega-Lite charts follow the Charts sheet of the Qx visual
  design guide: one config, one colour, a 0 to 1 probability axis, ket
  labels and value labels while the bars are few (plan:
  visual-design-guide).

  Inputs are built directly rather than simulated, so the bar counts are
  exact.
  """
  use ExUnit.Case, async: true

  alias Qx.Draw
  alias Qx.Draw.Theme

  @data_blue "#0072B2"

  defp probabilities(size), do: Nx.broadcast(Nx.tensor(1.0 / size, type: :f32), {size})

  defp result(fields) do
    struct!(
      %Qx.SimulationResult{
        probabilities: probabilities(2),
        classical_bits: [],
        state: nil,
        shots: 1,
        counts: %{}
      },
      fields
    )
  end

  # A counts map with `outcomes` distinct bit-string keys of `bits` bits.
  defp counts(outcomes, bits) do
    Map.new(0..(outcomes - 1), fn i ->
      {i |> Integer.to_string(2) |> String.pad_leading(bits, "0"), i + 1}
    end)
  end

  defp chart(:plot, bars), do: Draw.plot(result(probabilities: probabilities(bars)))
  defp chart(:histogram, bars), do: Draw.histogram(probabilities(bars))
  defp chart(:counts, bars), do: Draw.counts(result(counts: counts(bars, 8)))

  # Hides a value's type from the compiler, so a call the type checker
  # knows to be wrong can still be made to test the error it raises.
  defp untyped(term), do: term |> :erlang.term_to_binary() |> :erlang.binary_to_term()

  defp spec(function, bars), do: function |> chart(bars) |> VegaLite.to_spec()

  # The views that draw marks: the layers of a layered spec, or the spec
  # itself. Encodings set at the top level are inherited by every layer.
  defp views(%{"layer" => layers} = spec) do
    Enum.map(layers, fn layer ->
      Map.update(layer, "encoding", spec["encoding"], &Map.merge(spec["encoding"], &1))
    end)
  end

  defp views(spec), do: [spec]

  defp mark_type(%{"mark" => %{"type" => type}}), do: type
  defp mark_type(%{"mark" => type}), do: type

  defp view(spec, type), do: Enum.find(views(spec), &(mark_type(&1) == type))

  defp x_encoding(spec), do: view(spec, "bar")["encoding"]["x"]
  defp y_encoding(spec), do: view(spec, "bar")["encoding"]["y"]

  describe "shared config and colour" do
    for function <- [:plot, :histogram, :counts] do
      test "#{function} carries the theme config" do
        expected =
          VegaLite.new()
          |> VegaLite.config(Theme.vega_config())
          |> VegaLite.to_spec()
          |> Map.fetch!("config")

        assert spec(unquote(function), 4)["config"] == expected
        assert spec(unquote(function), 32)["config"] == expected
      end

      test "#{function} bars are data blue" do
        for bars <- [4, 32] do
          spec = spec(unquote(function), bars)
          bar = view(spec, "bar")

          assert bar, "no bar mark"
          assert spec["config"]["bar"]["color"] == @data_blue

          # Nothing overrides the config colour.
          refute Map.has_key?(bar["encoding"], "color")
          refute is_map(bar["mark"]) and Map.has_key?(bar["mark"], "color")
        end
      end
    end

    test "the empty-counts chart keeps its title and carries the config" do
      spec = result(counts: %{}) |> Draw.counts() |> VegaLite.to_spec()

      assert spec["title"] == "No Measurements"
      assert spec["config"]["bar"]["color"] == @data_blue
    end
  end

  describe "axes" do
    test "the probability axis is fixed at 0 to 1 when a bar reaches 0.2" do
      # Uniform over 2 and 4 states: bars of 0.5 and 0.25.
      for function <- [:plot, :histogram], bars <- [2, 4] do
        y = y_encoding(spec(function, bars))

        assert y["field"] == "probability"
        assert y["scale"] == %{"domain" => [0, 1]}
        assert y["axis"]["format"] == ".2f"
        assert y["title"] == "Probability"
      end
    end

    test "the probability axis fits the data when every bar is under 0.2" do
      # Uniform over 8, 32 and 128 states: bars of 0.125, 0.031 and 0.008,
      # which a 0 to 1 axis would draw as slivers.
      for function <- [:plot, :histogram], bars <- [8, 32, 128] do
        y = y_encoding(spec(function, bars))

        assert y["field"] == "probability"
        assert y["scale"] == %{"zero" => true, "nice" => true}
        assert y["title"] == "Probability"
        # The tick format is left to Vega: two decimals cannot tell 0.002
        # from 0.004.
        refute Map.has_key?(y, "axis")
      end
    end

    test "one bar at 0.2 is enough to keep the 0 to 1 axis, wherever it is" do
      fixed = %{"domain" => [0, 1]}
      fitted = %{"zero" => true, "nice" => true}

      # The tallest bar is in the middle of each list, not first.
      cases = [
        {[0.1, 0.1, 0.1, 0.1, 0.2, 0.1, 0.1, 0.1, 0.1], fixed},
        # A hair under 0.2, as float32 arithmetic can leave it.
        {[0.1, 0.1, 0.1, 0.1, 0.1999995, 0.1, 0.1, 0.1, 0.1000005], fixed},
        {[0.1, 0.1, 0.1, 0.101, 0.199, 0.1, 0.1, 0.1, 0.1], fitted},
        {List.duplicate(0.1 / 63, 31) ++ [0.9] ++ List.duplicate(0.1 / 63, 32), fixed}
      ]

      for {probabilities, scale} <- cases do
        tensor = Nx.tensor(probabilities, type: :f32)

        for chart <- [Draw.histogram(tensor), Draw.plot(result(probabilities: tensor))] do
          assert y_encoding(VegaLite.to_spec(chart))["scale"] == scale,
                 "tallest bar #{Enum.max(probabilities)}"
        end
      end
    end

    test "the counts axis starts at zero and ends on a round number" do
      for bars <- [2, 32] do
        y = y_encoding(spec(:counts, bars))

        assert y["field"] == "count"
        assert y["scale"]["zero"] == true
        assert y["scale"]["nice"] == true
        refute Map.has_key?(y["scale"], "domain")
        assert y["title"] == "Counts"
      end
    end

    test "the x title is Basis state and the data order is kept" do
      for function <- [:plot, :histogram, :counts] do
        x = x_encoding(spec(function, 4))

        assert x["title"] == "Basis state"
        assert x["type"] == "nominal"
        assert Map.has_key?(x, "sort") and x["sort"] == nil
      end
    end

    test "data field names are unchanged" do
      assert x_encoding(spec(:plot, 4))["field"] == "state"
      assert x_encoding(spec(:histogram, 4))["field"] == "state"
      assert x_encoding(spec(:counts, 4))["field"] == "measurement"

      assert [%{"state" => "|00⟩", "probability" => _} | _] = spec(:plot, 4)["data"]["values"]

      assert [%{"measurement" => "00000000", "count" => 1} | _] =
               spec(:counts, 4)["data"]["values"]
    end
  end

  describe "basis-state labels" do
    test "kets, level, at 16 bars or fewer" do
      for function <- [:plot, :histogram] do
        axis = x_encoding(spec(function, 16))["axis"] || %{}

        # The data already holds kets and the config sets the angle to 0.
        refute Map.has_key?(axis, "labelExpr")
        refute Map.has_key?(axis, "labelAngle")
        refute Map.has_key?(axis, "values")
      end

      # Counts data holds bare bit strings, so the axis writes them as kets.
      axis = x_encoding(spec(:counts, 16))["axis"]
      assert axis["labelExpr"] == "isString(datum.value) ? '|' + datum.value + '⟩' : ''"
      refute Map.has_key?(axis, "labelAngle")
    end

    test "bare bit strings, vertical, above 16 bars" do
      for function <- [:plot, :histogram] do
        axis = x_encoding(spec(function, 32))["axis"]

        assert axis["labelAngle"] == -90
        assert axis["labelExpr"] == "isString(datum.value) ? slice(datum.value, 1, -1) : ''"
        refute Map.has_key?(axis, "values")
      end

      axis = x_encoding(spec(:counts, 17))["axis"]
      assert axis["labelAngle"] == -90
      refute Map.has_key?(axis, "labelExpr")
    end

    test "every fourth label above 64 bars" do
      for function <- [:plot, :histogram] do
        refute Map.has_key?(x_encoding(spec(function, 64))["axis"], "values")

        axis = x_encoding(spec(function, 128))["axis"]
        assert length(axis["values"]) == 32
        assert Enum.take(axis["values"], 3) == ["|0000000⟩", "|0000100⟩", "|0001000⟩"]
        assert axis["labelAngle"] == -90
      end

      axis = x_encoding(spec(:counts, 65))["axis"]
      assert length(axis["values"]) == 17
      assert Enum.take(axis["values"], 2) == ["00000000", "00000100"]
    end
  end

  describe "label expressions under a host theme" do
    # Livebook renders every chart with its own theme merged under the
    # spec's config, and that theme sets axisBand.tickExtra, which adds a
    # tick that has no value. An expression that slices or joins the
    # value without checking it fails there, and the chart draws empty.
    test "every label expression checks that the tick has a value" do
      expressions =
        for function <- [:plot, :histogram, :counts],
            bars <- [2, 16, 17, 64, 128],
            expression = x_encoding(spec(function, bars))["axis"]["labelExpr"],
            do: {function, bars, expression}

      # Kets are shortened above 16 bars (plot and histogram at 17, 64 and
      # 128); bit strings are made kets at 16 or fewer (counts at 2 and 16).
      assert length(expressions) == 8

      for {function, bars, expression} <- expressions do
        assert String.starts_with?(expression, "isString(datum.value) ? "),
               "#{function} at #{bars} bars: #{expression}"

        assert String.ends_with?(expression, " : ''"),
               "#{function} at #{bars} bars: #{expression}"
      end
    end
  end

  describe "value labels" do
    test "a text layer with the values at 8 bars or fewer" do
      for function <- [:plot, :histogram, :counts], bars <- [1, 8] do
        spec = spec(function, bars)
        text = view(spec, "text")

        assert text, "#{function} at #{bars} bars has no text layer"
        assert text["mark"]["color"] == Theme.color(:ink)
        assert text["mark"]["fontSize"] == 11

        field = if function == :counts, do: "count", else: "probability"
        format = if function == :counts, do: "d", else: ".2f"

        assert text["encoding"]["text"]["field"] == field
        assert text["encoding"]["text"]["format"] == format
        assert text["encoding"]["x"] == x_encoding(spec)
      end
    end

    test "no text layer at 9 bars" do
      for function <- [:plot, :histogram, :counts] do
        spec = spec(function, 9)

        assert view(spec, "bar")
        refute view(spec, "text")
      end
    end
  end

  describe "counts order" do
    test "bars are in bit-string order past the 32-key map ordering limit" do
      # Maps keep sorted key order only up to 32 keys, so 40 outcomes come
      # out of the map unsorted.
      counts = counts(40, 6)
      refute Map.keys(counts) == Enum.sort(Map.keys(counts))
      spec = result(counts: counts) |> Draw.counts() |> VegaLite.to_spec()

      outcomes = Enum.map(spec["data"]["values"], & &1["measurement"])

      assert length(outcomes) == 40
      assert outcomes == Enum.sort(outcomes)
      assert hd(outcomes) == "000000"
    end
  end

  describe "unchanged behaviour" do
    test "title, width and height options still apply" do
      spec =
        result(probabilities: probabilities(4))
        |> Draw.plot(title: "Bell", width: 500, height: 250)
        |> VegaLite.to_spec()

      assert spec["title"] == "Bell"
      assert spec["width"] == 500
      assert spec["height"] == 250
    end

    test "the size limit is still checked" do
      assert_raise Qx.DrawSizeError, fn ->
        Draw.plot(result(probabilities: probabilities(8)), max_qubits: 2)
      end

      assert_raise Qx.DrawSizeError, fn ->
        Draw.counts(result(counts: counts(8, 8)), max_qubits: 2)
      end
    end
  end

  describe "options (review follow-ups)" do
    test "an unknown option raises Qx.OptionError naming it" do
      assert_raise Qx.OptionError, ~r/:colour/, fn ->
        Draw.plot(result(probabilities: probabilities(4)), colour: "red")
      end

      assert_raise Qx.OptionError, ~r/:colour/, fn ->
        Draw.counts(result(counts: counts(4, 2)), colour: "red")
      end

      assert_raise Qx.OptionError, ~r/:colour/, fn ->
        Draw.histogram(probabilities(4), colour: "red")
      end
    end

    test "options that are not a keyword list raise Qx.OptionError" do
      assert_raise Qx.OptionError, fn ->
        Draw.plot(result(probabilities: probabilities(4)), untyped("Bell"))
      end

      assert_raise Qx.OptionError, fn ->
        Draw.counts(result(counts: counts(4, 2)), untyped("Bell"))
      end

      assert_raise Qx.OptionError, fn -> Draw.histogram(probabilities(4), [1, 2]) end
    end

    test "the empty-counts chart takes the title it is given" do
      spec = result(counts: %{}) |> Draw.counts(title: "Run 7") |> VegaLite.to_spec()
      assert spec["title"] == "Run 7"
    end
  end
end
