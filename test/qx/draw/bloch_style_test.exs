defmodule Qx.Draw.BlochStyleTest do
  @moduledoc """
  The Bloch sphere follows the Bloch sphere sheet of the Qx visual design
  guide, with one departure: the shaded body has no outline, its edge is
  the darker rim of the shading. Three great circles are split into
  a solid near half and a dashed far half, ink axes, and one accent-coloured
  state vector whose head shows whether it points toward or away from the
  reader (plan: visual-design-guide).

  The drawing is grouped into `<g data-part="...">` elements, which the
  tests read part by part.
  """
  use ExUnit.Case, async: true

  alias Qx.Draw.Image
  alias Qx.Draw.SVG.Bloch
  alias Qx.Draw.Theme

  @ink "#16181D"
  @ink2 "#4A5261"
  @back "#A9B1BD"
  @paper "#FFFFFF"
  @accent "#D55E00"

  @pi :math.pi()

  setup_all do
    Mix.ensure_application!(:xmerl)
    :ok
  end

  # -- states ----------------------------------------------------------

  defp zero, do: Qx.create_circuit(1) |> Qx.get_state()
  defp one, do: Qx.create_circuit(1) |> Qx.x(0) |> Qx.get_state()
  defp plus, do: Qx.create_circuit(1) |> Qx.h(0) |> Qx.get_state()
  defp minus, do: Qx.create_circuit(1) |> Qx.x(0) |> Qx.h(0) |> Qx.get_state()
  defp plus_i, do: Qx.create_circuit(1) |> Qx.h(0) |> Qx.s(0) |> Qx.get_state()
  defp minus_i, do: Qx.create_circuit(1) |> Qx.h(0) |> Qx.sdg(0) |> Qx.get_state()

  # cos(θ/2)|0⟩ + e^{iφ} sin(θ/2)|1⟩
  defp state(theta, phi) do
    Nx.tensor(
      [
        Complex.new(:math.cos(theta / 2), 0.0),
        Complex.new(
          :math.sin(theta / 2) * :math.cos(phi),
          :math.sin(theta / 2) * :math.sin(phi)
        )
      ],
      type: :c64
    )
  end

  defp general, do: state(0.65 * @pi, 0.45 * @pi)

  # The camera sits 30° round from x and 18° above the equator, so this
  # state points straight at the reader and its opposite straight away.
  defp toward_viewer, do: state(0.4 * @pi, @pi / 6)
  defp away_from_viewer, do: state(0.6 * @pi, 7 * @pi / 6)

  # -- helpers ---------------------------------------------------------

  # Hides a value's type from the compiler, so a call the type checker
  # knows to be wrong can still be made to test the error it raises.
  defp untyped(term), do: term |> :erlang.term_to_binary() |> :erlang.binary_to_term()

  defp svg(state, options \\ []), do: Qx.Draw.bloch(state, options).svg

  defp attributes(string) do
    ~r/([\w:-]+)="([^"]*)"/
    |> Regex.scan(string, capture: :all_but_first)
    |> Map.new(fn [name, value] -> {name, value} end)
  end

  defp elements(markup, tag) do
    ~r/<#{tag}\b([^>]*)>/
    |> Regex.scan(markup, capture: :all_but_first)
    |> Enum.map(fn [attrs] -> attributes(attrs) end)
  end

  defp texts(markup) do
    ~r/<text\b([^>]*)>(.*?)<\/text>/s
    |> Regex.scan(markup, capture: :all_but_first)
    |> Enum.map(fn [attrs, body] ->
      {attributes(attrs), body |> String.replace(~r/<[^>]+>/, "") |> String.trim()}
    end)
  end

  # The markup inside `<g data-part="name">`, or nil when the part is absent.
  defp part(svg, name) do
    case Regex.run(~r/<g data-part="#{name}">(.*?)<\/g>/s, svg, capture: :all_but_first) do
      [inner] -> inner
      nil -> nil
    end
  end

  defp parts(svg) do
    ~r/<g data-part="([\w-]+)">/ |> Regex.scan(svg, capture: :all_but_first) |> List.flatten()
  end

  defp num(string) do
    {value, ""} = Float.parse(string)
    value
  end

  defp points(%{"points" => points}) do
    points
    |> String.split(" ")
    |> Enum.map(fn point -> point |> String.split(",") |> Enum.map(&num/1) end)
  end

  defp colours(markup) do
    ~r/(?:fill|stroke|stop-color)="([^"]*)"/
    |> Regex.scan(markup, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
  end

  defp font_sizes(markup) do
    ~r/font-size="([^"]*)"/
    |> Regex.scan(markup, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&num/1)
  end

  defp stroke_widths(markup) do
    ~r/stroke-width="([^"]*)"/
    |> Regex.scan(markup, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&num/1)
  end

  defp parse_xml!(svg) do
    {document, _rest} = svg |> :binary.bin_to_list() |> :xmerl_scan.string(quiet: true)
    document
  end

  # :solid, :hollow or nil, for the arrowhead (a path) or the dot (a circle).
  defp head_style(%{"fill" => @accent, "stroke" => @paper}), do: :solid
  defp head_style(%{"fill" => @paper, "stroke" => @accent}), do: :hollow

  defp arrowhead(svg), do: svg |> part("vector") |> elements("path") |> List.first()
  defp vector_dot(svg), do: svg |> part("vector") |> elements("circle") |> List.first()

  # -- body ------------------------------------------------------------

  describe "body and edge" do
    test "a radial-gradient body whose edge is shading alone, with no outline" do
      svg = svg(general())

      assert [gradient] = elements(svg, "radialGradient")
      assert {gradient["cx"], gradient["cy"], gradient["r"]} == {"36%", "30%", "75%"}

      assert Enum.map(elements(svg, "stop"), &{&1["offset"], &1["stop-color"]}) == [
               {"0", "#FFFFFF"},
               {"0.6", "#EEF1F5"},
               {"0.86", "#CBD3DD"},
               {"1", "#A9B1BD"}
             ]

      assert [body] = svg |> part("body") |> elements("circle")
      assert body["fill"] == "url(##{gradient["id"]})"

      refute Map.has_key?(body, "stroke")

      # No line is drawn round the sphere: the darker rim of the gradient
      # is its edge. The only circle of the sphere's radius is the body.
      refute "silhouette" in parts(svg)
      assert [^body] = Enum.filter(elements(svg, "circle"), &(&1["r"] == body["r"]))
    end

    test "the radius is 33.5% of the size" do
      assert [%{"r" => "134"}] = svg(general()) |> part("body") |> elements("circle")

      assert [%{"r" => "80.4"}] =
               svg(general(), size: 240) |> part("body") |> elements("circle")

      assert [%{"r" => "201"}] =
               svg(general(), size: 600) |> part("body") |> elements("circle")
    end

    test "a tinted equatorial plane" do
      assert [plane] = svg(general()) |> part("plane") |> elements("polygon")
      assert plane["fill"] == @ink and plane["fill-opacity"] == "0.045"
      assert length(points(plane)) >= 60
    end

    test "two spheres for different states have different gradient ids" do
      id = fn svg -> svg |> elements("radialGradient") |> hd() |> Map.fetch!("id") end

      assert id.(svg(plus())) != id.(svg(minus()))
      assert id.(svg(plus())) != id.(svg(plus(), size: 240))
      assert id.(svg(plus())) == id.(svg(plus()))
      assert id.(svg(general())) =~ ~r/^[A-Za-z][\w-]*$/
    end
  end

  # -- great circles ---------------------------------------------------

  describe "great circles" do
    test "exactly three, each a solid near half in Ink 2 and a dashed far half in Back" do
      svg = svg(general())

      near = svg |> part("near") |> elements("polyline")
      far = svg |> part("far") |> elements("polyline")

      assert length(near) == 3
      assert length(far) == 3

      for half <- near do
        assert half["stroke"] == @ink2 and half["fill"] == "none"
        assert half["stroke-width"] == "1.1"
        refute Map.has_key?(half, "stroke-dasharray")
      end

      for half <- far do
        assert half["stroke"] == @back and half["fill"] == "none"
        assert half["stroke-dasharray"] == "3 3"
      end

      # No other rings anywhere: the only other polylines are the two
      # angle arcs.
      assert length(elements(svg, "polyline")) == 8
    end

    test "each near half joins its far half at both ends, on the edge of the body" do
      svg = svg(general())
      [%{"cx" => cx, "cy" => cy, "r" => r}] = svg |> part("body") |> elements("circle")

      near = svg |> part("near") |> elements("polyline") |> Enum.map(&points/1)
      far = svg |> part("far") |> elements("polyline") |> Enum.map(&points/1)

      assert length(near) == 3 and length(far) == 3

      for {near_half, far_half} <- Enum.zip(near, far) do
        assert List.first(near_half) == List.last(far_half)
        assert List.last(near_half) == List.first(far_half)

        # The halves meet where the circle turns away from the reader,
        # which is on the edge of the body.
        [x, y] = List.first(near_half)
        distance = :math.sqrt((x - num(cx)) ** 2 + (y - num(cy)) ** 2)
        assert_in_delta distance, num(r), 0.2
      end
    end
  end

  # -- state vector ----------------------------------------------------

  describe "state vector" do
    test "accent is used for the state and nothing else" do
      svg = svg(general())

      for name <- parts(svg) -- ["vector", "shadow"] do
        refute @accent in colours(part(svg, name)), "#{name} uses the accent"
      end

      assert @accent in colours(part(svg, "vector"))
    end

    test "the shaft is a 3-wide accent line on a 6-wide paper halo, from the centre" do
      svg = svg(general())
      [%{"cx" => cx, "cy" => cy}] = svg |> part("body") |> elements("circle")

      assert [halo, shaft] = svg |> part("vector") |> elements("line")
      assert halo["stroke"] == @paper and halo["stroke-width"] == "6"
      assert halo["stroke-linecap"] == "round"
      assert shaft["stroke"] == @accent and shaft["stroke-width"] == "3"
      assert {shaft["x1"], shaft["y1"]} == {cx, cy}
    end

    test "the arrowhead's point touches the surface" do
      svg = svg(plus_i())
      [%{"cx" => cx, "cy" => cy, "r" => r}] = svg |> part("body") |> elements("circle")

      # |i⟩ lies along y, which projects to 0.866 right and 0.155 down.
      assert [_, tip_x, tip_y] = Regex.run(~r/^M([\d.]+) ([\d.]+)L/, arrowhead(svg)["d"])
      assert_in_delta num(tip_x), num(cx) + 0.866 * num(r), 0.2
      assert_in_delta num(tip_y), num(cy) + 0.1545 * num(r), 0.2
    end

    test "the head is solid on the near hemisphere and hollow on the far one" do
      assert head_style(arrowhead(svg(zero()))) == :solid
      assert head_style(arrowhead(svg(plus()))) == :solid
      assert head_style(arrowhead(svg(plus_i()))) == :solid
      assert head_style(arrowhead(svg(general()))) == :solid

      assert head_style(arrowhead(svg(one()))) == :hollow
      assert head_style(arrowhead(svg(minus()))) == :hollow
      assert head_style(arrowhead(svg(minus_i()))) == :hollow
    end

    test "a hollow head is paper-filled with an accent outline drawn over its fill" do
      head = arrowhead(svg(minus()))
      assert head["stroke-width"] == "1.75"
      assert head["paint-order"] == "fill stroke"
      assert head["stroke-linejoin"] == "round"
    end

    test "a vector aimed at the reader ends in a dot of radius 5.5, solid" do
      svg = svg(toward_viewer())

      assert arrowhead(svg) == nil
      assert %{"r" => "5.5"} = dot = vector_dot(svg)
      assert head_style(dot) == :solid
    end

    test "a vector aimed away from the reader ends in a hollow dot" do
      svg = svg(away_from_viewer())

      assert arrowhead(svg) == nil
      assert %{"r" => "5.5"} = dot = vector_dot(svg)
      assert head_style(dot) == :hollow
    end

    test "the centre point is not drawn under a dot" do
      # An ink point inside a ring is the "out of the page" symbol, which
      # would contradict a hollow dot.
      assert part(svg(toward_viewer()), "centre") == nil
      assert part(svg(away_from_viewer()), "centre") == nil
      assert [%{"fill" => @ink}] = svg(general()) |> part("centre") |> elements("circle")
    end

    test "the short-vector threshold scales with the size" do
      # A projected length of about 24 at size 400: an arrowhead. The same
      # state at any size keeps its arrowhead.
      short = state(0.4 * @pi + 0.18, @pi / 6)

      assert arrowhead(svg(short))
      assert arrowhead(svg(short, size: 240))
      assert arrowhead(svg(short, size: 800))
      assert vector_dot(svg(short)) == nil
    end

    test "a drop line to the plane and a shadow back to the centre, for a general state" do
      shadow = part(svg(general()), "shadow")

      assert [shadow_line, drop] = elements(shadow, "line")
      assert shadow_line["stroke"] == @accent and shadow_line["stroke-opacity"] == "0.45"
      assert drop["stroke"] == @accent and drop["stroke-dasharray"] == "3 2.5"
      # The drop is vertical: z does not move a point sideways.
      assert drop["x1"] == drop["x2"]
      assert [%{"fill" => @accent}] = elements(shadow, "circle")
    end

    test "no drop line on the equator, no shadow at a pole" do
      assert [_shadow_line] = svg(plus()) |> part("shadow") |> elements("line")
      assert part(svg(zero()), "shadow") == nil
      assert part(svg(one()), "shadow") == nil
    end
  end

  # -- angle arcs ------------------------------------------------------

  describe "angle arcs" do
    test "θ and φ arcs, each with its letter, for a general state" do
      arcs = part(svg(general()), "arcs")

      assert [_, _] = polylines = elements(arcs, "polyline")
      assert Enum.all?(polylines, &(&1["stroke"] == @ink2 and &1["fill"] == "none"))

      assert [{phi, "φ"}, {theta, "θ"}] = texts(arcs)

      for attrs <- [phi, theta] do
        assert attrs["font-style"] == "italic"
        assert attrs["font-family"] == Theme.font(:math)
        assert attrs["fill"] == @ink2
        assert attrs["paint-order"] == "stroke fill" and attrs["stroke"] == @paper
      end
    end

    test "no arcs at either pole" do
      assert part(svg(zero()), "arcs") == nil
      assert part(svg(one()), "arcs") == nil
    end

    test "only the θ arc when φ is zero" do
      arcs = part(svg(plus()), "arcs")

      assert [_] = elements(arcs, "polyline")
      assert [{_, "θ"}] = texts(arcs)
    end
  end

  # -- axes and labels -------------------------------------------------

  describe "axes and labels" do
    test "axes are Ink 2 outside the sphere and Back inside or behind it, never coloured" do
      svg = svg(general())

      assert colours(part(svg, "axes")) -- [@ink2] == []
      assert colours(part(svg, "axes-hidden")) == [@back]

      for colour <- ["#FF5733", "#33FF57", "#3357FF", "#CC0000"] do
        refute svg =~ colour
      end
    end

    test "each axis has a solid part with an arrowhead and a pale part" do
      svg = svg(general())

      assert length(elements(part(svg, "axes-hidden"), "line")) >= 3
      assert length(elements(part(svg, "axes"), "line")) >= 3
      assert length(elements(part(svg, "axes"), "path")) == 3
    end

    test "axis letters are italic in the mathematics voice, placed by the camera" do
      svg = svg(general())
      [%{"cx" => cx, "cy" => cy}] = svg |> part("body") |> elements("circle")

      assert [{x, "x"}, {y, "y"}, {z, "z"}] = texts(part(svg, "axes"))

      for attrs <- [x, y, z] do
        assert attrs["font-style"] == "italic"
        assert attrs["font-family"] == Theme.font(:math)
        assert attrs["font-size"] == "15"
      end

      # x comes toward the reader and to the left, y runs right, z is up.
      assert num(x["x"]) < num(cx) and num(x["y"]) > num(cy)
      assert num(y["x"]) > num(cx)
      assert num(z["x"]) == num(cx) and num(z["y"]) < num(cy)
    end

    test "six state labels as kets in the mathematics voice, on a paper halo" do
      labels = texts(part(svg(general()), "labels"))

      assert Enum.map(labels, &elem(&1, 1)) == ["|0⟩", "|1⟩", "|+⟩", "|−⟩", "|i⟩", "|−i⟩"]

      for {attrs, _text} <- labels do
        assert attrs["font-family"] == Theme.font(:math)
        assert attrs["font-size"] == "14"
        assert attrs["fill"] == @ink
        assert attrs["stroke"] == @paper and attrs["paint-order"] == "stroke fill"
      end
    end

    test "|0⟩ is labelled above the centre and |1⟩ below" do
      svg = svg(general())
      [%{"cy" => cy}] = svg |> part("body") |> elements("circle")
      [{zero, "|0⟩"}, {one, "|1⟩"} | _] = texts(part(svg, "labels"))

      assert num(zero["y"]) < num(cy)
      assert num(one["y"]) > num(cy)
    end
  end

  # -- readout ---------------------------------------------------------

  describe "readout" do
    defp readout(svg) do
      [{attrs, text}] = texts(part(svg, "readout"))
      {attrs, text}
    end

    test "θ and φ as fractions of π in the mono voice, centred under the sphere" do
      svg = svg(general())
      {attrs, text} = readout(svg)

      assert text == "θ = 0.65πφ = 0.45π"
      assert part(svg, "readout") =~ ~r/θ = 0\.65π<tspan dx="14">φ = 0\.45π<\/tspan>/

      assert attrs["font-family"] == Theme.font(:mono)
      assert attrs["font-size"] == "11" and attrs["fill"] == @ink2
      assert attrs["text-anchor"] == "middle" and attrs["x"] == "200"
      assert attrs["y"] == "386"
    end

    test "φ is shown from 0 up to 2π, never negative (S†H|0⟩ is 1.50π)" do
      assert {_, "θ = 0.50πφ = 1.50π"} = readout(svg(minus_i()))
      assert {_, "θ = 0.50πφ = 1.00π"} = readout(svg(minus()))
      assert {_, "θ = 0.50πφ = 0.50π"} = readout(svg(plus_i()))
      refute svg(minus_i()) =~ "-0.5"
    end

    test "φ is 0 at the poles, whatever the global phase" do
      assert {_, "θ = 0.00πφ = 0.00π"} = readout(svg(zero()))
      assert {_, "θ = 1.00πφ = 0.00π"} = readout(svg(one()))

      phased_one = Nx.tensor([Complex.new(0.0, 0.0), Complex.new(0.0, -1.0)], type: :c64)
      assert {_, "θ = 1.00πφ = 0.00π"} = readout(svg(phased_one))
    end

    test "rounding noise just below zero does not read as 2π" do
      noisy_plus =
        Nx.tensor([Complex.new(0.70710678, 0.0), Complex.new(0.70710678, -1.0e-9)], type: :c64)

      assert {_, "θ = 0.50πφ = 0.00π"} = readout(svg(noisy_plus))
    end
  end

  describe "qubit_to_bloch_coordinates/1" do
    test "φ is in [0, 2π)" do
      for state <- [zero(), one(), plus(), minus(), plus_i(), minus_i(), general()] do
        {_x, _y, _z, theta, phi} = Bloch.qubit_to_bloch_coordinates(state)

        assert theta >= 0.0 and theta <= @pi + 1.0e-6
        assert phi >= 0.0 and phi < 2 * @pi
      end
    end

    test "known states" do
      assert {x, y, z, theta, phi} = Bloch.qubit_to_bloch_coordinates(minus_i())
      assert_in_delta x, 0.0, 1.0e-6
      assert_in_delta y, -1.0, 1.0e-6
      assert_in_delta z, 0.0, 1.0e-6
      assert_in_delta theta, @pi / 2, 1.0e-6
      assert_in_delta phi, 3 * @pi / 2, 1.0e-6

      assert {_, _, z, _, _} = Bloch.qubit_to_bloch_coordinates(one())
      assert_in_delta z, -1.0, 1.0e-6
    end
  end

  # -- scaling ---------------------------------------------------------

  describe "scaling" do
    test "at size 240 every font is 80% of its size at 400" do
      at_400 = font_sizes(svg(general()))
      at_240 = font_sizes(svg(general(), size: 240))

      assert length(at_400) == length(at_240)

      for {large, small} <- Enum.zip(at_400, at_240) do
        assert_in_delta small, 0.8 * large, 0.051
      end
    end

    test "above 400 fonts and strokes scale with the size" do
      at_400 = svg(general())
      at_800 = svg(general(), size: 800)

      assert length(font_sizes(at_400)) == length(font_sizes(at_800))
      assert length(stroke_widths(at_400)) == length(stroke_widths(at_800))
      assert font_sizes(at_400) != [] and stroke_widths(at_400) != []

      for {normal, double} <- Enum.zip(font_sizes(at_400), font_sizes(at_800)) do
        assert_in_delta double, 2 * normal, 0.051
      end

      for {normal, double} <- Enum.zip(stroke_widths(at_400), stroke_widths(at_800)) do
        assert_in_delta double, 2 * normal, 0.011
      end
    end

    test "the image is a square of the size" do
      assert [%{"width" => "600", "height" => "600", "viewBox" => "0 0 600 600"}] =
               elements(svg(general(), size: 600), "svg")
    end
  end

  # -- title, accessibility, colour -------------------------------------

  describe "title and accessibility" do
    test "the title is left-aligned in the sans voice" do
      svg = svg(general(), title: "Plus state")

      assert [{attrs, "Plus state"}] = texts(part(svg, "title"))
      assert attrs["font-family"] == Theme.font(:sans)
      assert {attrs["x"], attrs["y"]} == {"16", "26"}
      assert attrs["font-size"] == "13" and attrs["font-weight"] == "600"
      refute Map.has_key?(attrs, "text-anchor")
    end

    test "the default title is Bloch Sphere, and nil draws none" do
      assert %Image{title: "Bloch Sphere", svg: svg} = Qx.Draw.bloch(general())
      assert [{_, "Bloch Sphere"}] = texts(part(svg, "title"))

      assert %Image{title: nil, svg: untitled} = Qx.Draw.bloch(general(), title: nil)
      assert part(untitled, "title") == nil

      # Without a title the sphere is centred; with one it sits 6 lower.
      assert [%{"cy" => "200"}] = untitled |> part("body") |> elements("circle")
      assert [%{"cy" => "206"}] = svg |> part("body") |> elements("circle")
    end

    test "a title that needs escaping yields well-formed XML" do
      svg = svg(general(), title: "x <y> & \"z\"")

      assert parse_xml!(svg)
      assert svg =~ "x &lt;y&gt; &amp; &quot;z&quot;"
    end

    test "an invalid title or size raises Qx.OptionError" do
      assert_raise Qx.OptionError, ~r/title/, fn -> Qx.Draw.bloch(general(), title: :plus) end
      assert_raise Qx.OptionError, ~r/size/, fn -> Qx.Draw.bloch(general(), size: 0) end
      assert_raise Qx.OptionError, ~r/size/, fn -> Qx.draw_bloch(general(), size: "400") end
    end

    test "every state parses as XML" do
      for state <- [zero(), one(), plus(), minus(), plus_i(), minus_i(), toward_viewer()] do
        assert parse_xml!(svg(state))
      end
    end

    test "the root is an img with an aria-label naming θ and φ" do
      assert [root] = elements(svg(general(), title: nil), "svg")
      assert root["role"] == "img"
      assert root["aria-label"] == "Bloch sphere showing θ = 0.65π, φ = 0.45π"

      assert [titled] = elements(svg(general(), title: "My state"), "svg")
      assert titled["aria-label"] == "My state: Bloch sphere showing θ = 0.65π, φ = 0.45π"
    end

    test "every colour is a theme colour" do
      allowed = ["none" | Theme.palette()]

      for state <- [zero(), minus(), general(), away_from_viewer()],
          colour <- colours(svg(state)) do
        assert colour in allowed or String.starts_with?(colour, "url(#"),
               "uses #{colour}"
      end
    end
  end

  # -- review follow-ups (visual-design-guide triage) --------------------

  describe "invalid input raises a typed error" do
    test "a size too large to draw raises Qx.OptionError" do
      assert_raise Qx.OptionError, ~r/size/, fn -> Qx.Draw.bloch(zero(), size: 1.0e160) end
      assert_raise Qx.OptionError, ~r/size/, fn -> Qx.draw_bloch(zero(), size: 10 ** 400) end
      assert_raise Qx.OptionError, ~r/size/, fn -> Qx.Draw.bloch(zero(), size: 10_001) end

      assert %Image{} = Qx.Draw.bloch(zero(), size: 10_000)
    end

    test "options that are not a keyword list raise Qx.OptionError" do
      assert_raise Qx.OptionError, fn -> Qx.Draw.bloch(zero(), untyped("Zero")) end
      assert_raise Qx.OptionError, fn -> Qx.draw_bloch(zero(), [1, 2]) end
    end

    test "an unknown option raises Qx.OptionError naming it" do
      assert_raise Qx.OptionError, ~r/:radius/, fn -> Qx.Draw.bloch(zero(), radius: 3) end
    end

    test "a state that is not one qubit raises Qx.StateShapeError" do
      two_qubits = Qx.create_circuit(2) |> Qx.get_state()

      assert_raise Qx.StateShapeError, ~r/expected 2, got 4/, fn -> Qx.Draw.bloch(two_qubits) end
      assert_raise Qx.StateShapeError, fn -> Qx.draw_bloch(Nx.tensor([1.0])) end
      assert_raise Qx.StateShapeError, fn -> Qx.Draw.bloch(untyped(:not_a_state)) end
    end

    test "an amplitude that is not finite raises Qx.StateNormalizationError" do
      for bad <- [Nx.Constants.nan(), Nx.Constants.infinity()] do
        state = Nx.stack([bad, Nx.tensor(0.0)]) |> Nx.as_type(:c64)
        assert_raise Qx.StateNormalizationError, fn -> Qx.Draw.bloch(state) end
      end
    end
  end

  describe "title (review follow-ups)" do
    test "an empty title is no title" do
      assert %Image{title: nil, svg: svg} = Qx.Draw.bloch(general(), title: "")
      assert svg == svg(general(), title: nil)
    end

    test "characters XML does not allow are left out of the title" do
      svg = svg(general(), title: "Plus" <> <<0>> <> " state" <> <<0xFF>>)

      assert parse_xml!(svg)
      assert [{_attrs, "Plus state"}] = texts(part(svg, "title"))
    end
  end

  describe "near a pole (review follow-ups)" do
    test "float32 rounding in α and noise in β do not give φ a value" do
      # |α| is one float32 step under 1 and β is noise with a phase of its
      # own: the state is |0⟩ and must read as |0⟩.
      noisy_zero =
        Nx.tensor(
          [
            Complex.new(0.99999994, 0.0),
            Complex.new(1.0e-8 * :math.cos(2.0), 1.0e-8 * :math.sin(2.0))
          ],
          type: :c64
        )

      assert {_, "θ = 0.00πφ = 0.00π"} = readout(svg(noisy_zero))
      assert {_x, _y, _z, _theta, phi} = Bloch.qubit_to_bloch_coordinates(noisy_zero)
      assert phi == 0.0

      noisy_one =
        Nx.tensor(
          [
            Complex.new(1.0e-8 * :math.cos(2.0), 1.0e-8 * :math.sin(2.0)),
            Complex.new(0.99999994, 0.0)
          ],
          type: :c64
        )

      assert {_, "θ = 1.00πφ = 0.00π"} = readout(svg(noisy_one))
    end

    test "a state a rounding step off normalised still reads as the pole" do
      above = Nx.tensor([Complex.new(1.0000001, 0.0), Complex.new(0.0, 0.0)], type: :c64)

      assert {_, "θ = 0.00πφ = 0.00π"} = readout(svg(above))
      assert {x, y, z, theta, _phi} = Bloch.qubit_to_bloch_coordinates(above)
      assert {x, y, z, theta} == {0.0, 0.0, 1.0, 0.0}
    end
  end

  describe "readout and arcs (review follow-ups)" do
    test "φ that rounds to 2.00π reads 0.00π and has no arc" do
      svg = svg(state(0.5 * @pi, 1.998 * @pi))

      assert {_, "θ = 0.50πφ = 0.00π"} = readout(svg)
      assert [{_attrs, "θ"}] = texts(part(svg, "arcs"))
    end

    test "a global phase does not change the picture of a state off the poles" do
      {theta, phi} = {0.65 * @pi, 0.45 * @pi}
      gamma = 1.1

      phased =
        Nx.tensor(
          [
            Complex.new(
              :math.cos(theta / 2) * :math.cos(gamma),
              :math.cos(theta / 2) * :math.sin(gamma)
            ),
            Complex.new(
              :math.sin(theta / 2) * :math.cos(phi + gamma),
              :math.sin(theta / 2) * :math.sin(phi + gamma)
            )
          ],
          type: :c64
        )

      assert readout(svg(phased)) == readout(svg(general()))

      # The same direction to float32 precision; the markup may differ in
      # a last printed digit.
      for {a, b} <-
            Enum.zip(
              Tuple.to_list(Bloch.qubit_to_bloch_coordinates(phased)),
              Tuple.to_list(Bloch.qubit_to_bloch_coordinates(general()))
            ) do
        assert_in_delta a, b, 1.0e-5
      end
    end
  end

  describe "scaling (review follow-ups)" do
    test "at size 240 every stroke is 80% of its width at 400" do
      at_400 = stroke_widths(svg(general()))
      at_240 = stroke_widths(svg(general(), size: 240))

      assert at_400 != [] and length(at_400) == length(at_240)

      for {normal, small} <- Enum.zip(at_400, at_240) do
        assert_in_delta small, 0.8 * normal, 0.0051
      end
    end
  end
end
