defmodule Qx.Draw.CircuitStyleTest do
  @moduledoc """
  Circuit diagrams follow the Circuit diagrams sheet of the Qx visual
  design guide: quantikz-style ink structure, gate boxes coloured by
  family, labels set as mathematics, boxes that widen with their label,
  and a mono style (plan: visual-design-guide).

  Geometry constants are the ones read from the guide's reference
  drawings; two whole circuits are compared against those drawings.
  """
  use ExUnit.Case, async: true

  alias Qx.Draw.Image
  alias Qx.Draw.SVG.Markup
  alias Qx.Draw.Theme
  alias Qx.Test.GateCatalogue

  @ink "#16181D"
  @ink2 "#4A5261"
  @muted "#6B7482"
  @paper "#FFFFFF"

  @pi :math.pi()

  setup_all do
    Mix.ensure_application!(:xmerl)
    :ok
  end

  # -- helpers ---------------------------------------------------------

  defp svg(circuit, options \\ []), do: Qx.Draw.circuit(circuit, options).svg

  defp attributes(string) do
    ~r/([\w:-]+)="([^"]*)"/
    |> Regex.scan(string, capture: :all_but_first)
    |> Map.new(fn [name, value] -> {name, value} end)
  end

  # Attribute maps of every `tag` element.
  defp elements(svg, tag) do
    ~r/<#{tag}\b([^>]*)>/
    |> Regex.scan(svg, capture: :all_but_first)
    |> Enum.map(fn [attrs] -> attributes(attrs) end)
  end

  # `{attributes, plain text}` of every text element.
  defp texts(svg) do
    ~r/<text\b([^>]*)>(.*?)<\/text>/s
    |> Regex.scan(svg, capture: :all_but_first)
    |> Enum.map(fn [attrs, body] ->
      {attributes(attrs), String.replace(body, ~r/<[^>]+>/, "")}
    end)
  end

  defp num(string) do
    {value, ""} = Float.parse(string)
    value
  end

  defp family(name), do: Theme.family_colors(name)

  # Gate boxes: every rect with a stroke (the background has none).
  defp boxes(svg), do: svg |> elements("rect") |> Enum.filter(&Map.has_key?(&1, "stroke"))

  defp center_x(box), do: num(box["x"]) + num(box["width"]) / 2

  # Gate labels: ink text in the mathematics voice, centred on its gate.
  defp gate_labels(svg) do
    for {attrs, text} <- texts(svg),
        attrs["text-anchor"] == "middle",
        attrs["fill"] == @ink,
        attrs["font-family"] == Theme.font(:math),
        do: {attrs, text}
  end

  defp horizontal?(line), do: line["y1"] == line["y2"]
  defp vertical?(line), do: line["x1"] == line["x2"]

  # Quantum wires: horizontal ink lines.
  defp wires(svg) do
    svg |> elements("line") |> Enum.filter(&(horizontal?(&1) and &1["stroke"] == @ink))
  end

  # Connectors: vertical ink lines.
  defp connectors(svg) do
    svg |> elements("line") |> Enum.filter(&(vertical?(&1) and &1["stroke"] == @ink))
  end

  defp colours(svg) do
    ~r/(?:fill|stroke|stop-color)="([^"]*)"/
    |> Regex.scan(svg, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
  end

  defp parse_xml!(svg) do
    {document, _rest} = svg |> :binary.bin_to_list() |> :xmerl_scan.string(quiet: true)
    document
  end

  defp teleportation do
    Qx.create_circuit(3, 2)
    |> Qx.h(1)
    |> Qx.cx(1, 2)
    |> Qx.barrier([0, 1, 2])
    |> Qx.cx(0, 1)
    |> Qx.h(0)
    |> Qx.measure(0, 0)
    |> Qx.measure(1, 1)
    |> Qx.c_if(1, 1, &Qx.x(&1, 2))
    |> Qx.c_if(0, 1, &Qx.z(&1, 2))
  end

  defp qft3 do
    Qx.create_circuit(3)
    |> Qx.h(0)
    |> Qx.cp(1, 0, @pi / 2)
    |> Qx.cp(2, 0, @pi / 4)
    |> Qx.h(1)
    |> Qx.cp(2, 1, @pi / 2)
    |> Qx.h(2)
    |> Qx.barrier([0, 1, 2])
    |> Qx.swap(0, 2)
  end

  # -- every gate draws ------------------------------------------------

  describe "every public gate function draws" do
    test "one circuit per producer function, in both styles" do
      assert GateCatalogue.uncovered() == []

      for {module, name, circuit} <- GateCatalogue.circuits(), style <- [:color, :mono] do
        assert %Image{svg: svg} = Qx.Draw.circuit(circuit, style: style),
               "#{inspect(module)}.#{name} did not draw"

        assert svg =~ "<svg"
        assert parse_xml!(svg)
      end
    end

    # Regression (finding 1 of the plan): these five raised Qx.GateError
    # "Unsupported gate" in 0.12.0.
    test "cy, crx, cry, crz and phase draw" do
      assert svg(Qx.create_circuit(2) |> Qx.cy(0, 1)) =~ "<svg"
      assert svg(Qx.create_circuit(2) |> Qx.crx(0, 1, 0.5)) =~ "<svg"
      assert svg(Qx.create_circuit(2) |> Qx.cry(0, 1, 0.5)) =~ "<svg"
      assert svg(Qx.create_circuit(2) |> Qx.crz(0, 1, 0.5)) =~ "<svg"
      assert svg(Qx.create_circuit(1) |> Qx.phase(0, 0.5)) =~ "<svg"
    end

    test "a gate inside a c_if block draws, controlled gates included" do
      circuit =
        Qx.create_circuit(3, 1)
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> c |> Qx.cy(1, 2) |> Qx.crz(2, 1, 0.5) end)

      assert svg(circuit) =~ "<svg"
    end

    test "a circuit imported from OpenQASM draws" do
      qasm = """
      OPENQASM 3.0;
      include "stdgates.inc";
      qubit[3] q;
      bit[1] c;
      p(pi/4) q[0];
      cy q[0], q[1];
      crx(pi/2) q[1], q[2];
      cry(0.3) q[0], q[2];
      crz(pi) q[0], q[1];
      c[0] = measure q[0];
      """

      assert svg(Qx.from_qasm!(qasm)) =~ "<svg"
    end

    test "an empty circuit draws its wires" do
      svg = svg(Qx.create_circuit(2))
      assert length(wires(svg)) == 2
      assert parse_xml!(svg)
    end

    test "an atom no producer emits raises Qx.GateError, inside a c_if block too" do
      circuit = Qx.QuantumCircuit.put_instructions(Qx.create_circuit(1, 1), [{:p, [0], [0.5]}])
      assert_raise Qx.GateError, fn -> Qx.Draw.circuit(circuit) end

      conditional =
        Qx.QuantumCircuit.put_instructions(Qx.create_circuit(1, 1), [
          {:c_if, [0, 1], [{:p, [0], [0.5]}]}
        ])

      assert_raise Qx.GateError, fn -> Qx.Draw.circuit(conditional) end
    end
  end

  # -- families --------------------------------------------------------

  describe "gate families" do
    @boxed [
      {:x, :pauli, "X"},
      {:y, :pauli, "Y"},
      {:z, :pauli, "Z"},
      {:h, :hadamard, "H"},
      {:s, :phase, "S"},
      {:sdg, :phase, "S†"},
      {:t, :phase, "T"},
      {:tdg, :phase, "T†"}
    ]

    for {gate, family, label} <- @boxed do
      test "#{gate} is a 32 x 32 box in the #{family} family labelled #{label}" do
        svg = svg(apply(Qx, unquote(gate), [Qx.create_circuit(1), 0]))
        colors = family(unquote(family))

        assert [box] = boxes(svg)
        assert box["fill"] == colors.fill
        assert box["stroke"] == colors.stroke
        assert box["stroke-width"] == "1.25"
        assert box["width"] == "32" and box["height"] == "32"
        assert box["rx"] == "2"

        assert [{attrs, unquote(label)}] = gate_labels(svg)
        assert attrs["font-size"] == "15"
        assert num(attrs["x"]) == center_x(box)
      end
    end

    @rotations [
      {:rx, :rotation, "Rx(π/2)", 64},
      {:ry, :rotation, "Ry(π/2)", 64},
      {:rz, :rotation, "Rz(π/2)", 64},
      {:phase, :phase, "P(π/2)", 56}
    ]

    for {gate, family, label, width} <- @rotations do
      test "#{gate} is a #{width}-wide box in the #{family} family labelled #{label}" do
        svg = svg(apply(Qx, unquote(gate), [Qx.create_circuit(1), 0, @pi / 2]))
        colors = family(unquote(family))

        assert [box] = boxes(svg)
        assert box["fill"] == colors.fill and box["stroke"] == colors.stroke
        assert box["width"] == to_string(unquote(width))
        assert [{_attrs, unquote(label)}] = gate_labels(svg)
      end
    end

    test "a short angle keeps the kind's slot: Rx(π) 64, P(π) 56" do
      assert [%{"width" => "64"}] = boxes(svg(Qx.create_circuit(1) |> Qx.rx(0, @pi)))
      assert [%{"width" => "56"}] = boxes(svg(Qx.create_circuit(1) |> Qx.phase(0, @pi)))
    end

    test "u is a rotation box at least 84 wide, labelled with its three angles" do
      svg = svg(Qx.create_circuit(1) |> Qx.u(0, @pi / 2, 0, @pi))
      colors = family(:rotation)

      assert [box] = boxes(svg)
      assert box["fill"] == colors.fill and box["stroke"] == colors.stroke
      assert num(box["width"]) >= 84
      assert [{_attrs, "U(π/2, 0, π)"}] = gate_labels(svg)
    end

    test "the letter of a label is italic, brackets and angle upright" do
      svg = svg(Qx.create_circuit(1) |> Qx.rx(0, @pi / 2))

      assert svg =~ ~s(<tspan font-style="italic">R</tspan>)
      assert svg =~ ~r/<tspan dy="4.2" font-style="italic" font-size="10.8">x<\/tspan>/
      assert svg =~ ~s(<tspan dy="-4.2">\(π/2\)</tspan>)
    end

    test "cx: an ink control, an ink connector and a Pauli target of radius 9" do
      svg = svg(Qx.create_circuit(2) |> Qx.cx(0, 1))
      pauli = family(:pauli)
      circles = elements(svg, "circle")

      assert [control] = Enum.filter(circles, &(&1["r"] == "3.5"))
      assert control["fill"] == @ink and control["stroke"] == @ink
      assert control["cy"] == "26"

      assert [target] = Enum.filter(circles, &(&1["r"] == "9"))
      assert target["fill"] == pauli.fill and target["stroke"] == pauli.stroke
      assert target["cy"] == "74"
      assert target["cx"] == control["cx"]

      assert [connector] = connectors(svg)
      assert connector["x1"] == control["cx"]
      assert {connector["y1"], connector["y2"]} == {"26", "74"}
      assert connector["stroke-width"] == "1.25"

      assert boxes(svg) == []
    end

    test "ccx: two ink controls and one Pauli target" do
      svg = svg(Qx.create_circuit(3) |> Qx.ccx(0, 1, 2))
      circles = elements(svg, "circle")

      assert length(Enum.filter(circles, &(&1["r"] == "3.5" and &1["fill"] == @ink))) == 2
      assert [target] = Enum.filter(circles, &(&1["r"] == "9"))
      assert target["stroke"] == family(:pauli).stroke
      assert [%{"y1" => "26", "y2" => "122"}] = connectors(svg)
    end

    test "cz: two ink dots, an ink connector and no colour" do
      svg = svg(Qx.create_circuit(2) |> Qx.cz(0, 1))

      assert [%{"r" => "3.5", "fill" => @ink}, %{"r" => "3.5", "fill" => @ink}] =
               elements(svg, "circle")

      assert boxes(svg) == []
      assert [_connector] = connectors(svg)
      assert Enum.sort(colours(svg)) == Enum.sort([@ink, @paper])
    end

    @controlled [
      {:cy, :pauli, "Y", [], 32},
      {:cp, :phase, "P(π/2)", [@pi / 2], 56},
      {:crx, :rotation, "Rx(π/2)", [@pi / 2], 64},
      {:cry, :rotation, "Ry(π/2)", [@pi / 2], 64},
      {:crz, :rotation, "Rz(π/2)", [@pi / 2], 64}
    ]

    for {gate, family, label, params, width} <- @controlled do
      test "#{gate}: an ink control joined to a #{family} box labelled #{label}" do
        svg = svg(apply(Qx, unquote(gate), [Qx.create_circuit(2), 0, 1 | unquote(params)]))
        colors = family(unquote(family))

        assert [control] = elements(svg, "circle")
        assert control["r"] == "3.5" and control["fill"] == @ink and control["cy"] == "26"

        assert [box] = boxes(svg)
        assert box["fill"] == colors.fill and box["stroke"] == colors.stroke
        assert box["width"] == to_string(unquote(width))
        assert box["y"] == "58"
        assert center_x(box) == num(control["cx"])

        # The connector stops at the edge of the box.
        assert [%{"y1" => "26", "y2" => "58"}] = connectors(svg)
        assert [{_attrs, unquote(label)}] = gate_labels(svg)
      end
    end

    test "a control below its target joins the bottom edge of the box" do
      svg = svg(Qx.create_circuit(2) |> Qx.cp(1, 0, @pi / 2))

      assert [%{"cy" => "74"}] = elements(svg, "circle")
      assert [%{"y" => "10"}] = boxes(svg)
      assert [%{"y1" => "74", "y2" => "42"}] = connectors(svg)
    end

    test "swap: two crosses in the Exchange stroke on an ink connector" do
      svg = svg(Qx.create_circuit(2) |> Qx.swap(0, 1))
      exchange = family(:exchange)

      crosses = svg |> elements("line") |> Enum.filter(&(&1["stroke"] == exchange.stroke))

      assert length(crosses) == 4
      assert Enum.all?(crosses, &(&1["stroke-width"] == "1.75"))
      assert Enum.all?(crosses, &(&1["stroke-linecap"] == "round"))
      assert Enum.all?(crosses, &(abs(num(&1["x2"]) - num(&1["x1"])) == 10.0))
      assert [%{"y1" => "26", "y2" => "74"}] = connectors(svg)
      assert boxes(svg) == []
    end

    test "cswap: an ink control and two Exchange crosses" do
      svg = svg(Qx.create_circuit(3) |> Qx.cswap(0, 1, 2))
      exchange = family(:exchange)

      assert [%{"r" => "3.5", "fill" => @ink, "cy" => "26"}] = elements(svg, "circle")

      crosses = svg |> elements("line") |> Enum.filter(&(&1["stroke"] == exchange.stroke))
      assert length(crosses) == 4
      assert [%{"y1" => "26", "y2" => "122"}] = connectors(svg)
    end

    test "iswap on adjacent wires is one Exchange box spanning both" do
      svg = svg(Qx.create_circuit(2) |> Qx.iswap(0, 1))
      exchange = family(:exchange)

      assert [box] = boxes(svg)
      assert box["fill"] == exchange.fill and box["stroke"] == exchange.stroke
      assert {box["y"], box["height"], box["width"]} == {"10", "80", "56"}

      assert [{attrs, "iSWAP"}] = gate_labels(svg)
      assert attrs["font-size"] == "13"
      assert svg =~ ~s(<tspan font-style="italic">i</tspan><tspan>SWAP</tspan>)
      assert connectors(svg) == []
    end

    test "iswap on non-adjacent wires is two Exchange boxes joined by an ink connector" do
      svg = svg(Qx.create_circuit(3) |> Qx.iswap(0, 2))
      exchange = family(:exchange)

      assert [top, bottom] = boxes(svg)
      assert top["stroke"] == exchange.stroke and bottom["stroke"] == exchange.stroke
      assert {top["y"], top["height"]} == {"10", "32"}
      assert {bottom["y"], bottom["height"]} == {"106", "32"}

      assert [{_, "iSWAP"}, {_, "iSWAP"}] = gate_labels(svg)
      assert [%{"y1" => "42", "y2" => "106"}] = connectors(svg)
    end
  end

  # -- ink structure and type ------------------------------------------

  describe "structure" do
    test "wires are ink at 1.25, 48 apart, from x 54" do
      svg = svg(Qx.create_circuit(3) |> Qx.h(0))

      assert [w0, w1, w2] = wires(svg)
      assert Enum.map([w0, w1, w2], & &1["y1"]) == ["26", "74", "122"]
      assert Enum.all?([w0, w1, w2], &(&1["stroke-width"] == "1.25" and &1["x1"] == "54"))
    end

    test "wire labels are q with an upright subscript index, right-aligned at 46" do
      svg = svg(Qx.create_circuit(2) |> Qx.h(0))

      labels = for {%{"text-anchor" => "end"} = attrs, text} <- texts(svg), do: {attrs, text}

      assert [{a0, "q0"}, {a1, "q1"}] = labels
      assert a0["x"] == "46" and a0["y"] == "31.1" and a1["y"] == "79.1"
      assert a0["font-size"] == "15" and a0["font-family"] == Theme.font(:math)

      assert svg =~
               ~s(<tspan font-style="italic">q</tspan><tspan dy="4.2" font-size="10.8">0</tspan>)
    end

    test "no gate label is set under 15, except the iSWAP label at 13" do
      for {_module, _name, circuit} <- GateCatalogue.circuits(),
          {attrs, text} <- gate_labels(svg(circuit)) do
        if text == "iSWAP" do
          assert attrs["font-size"] == "13"
        else
          assert attrs["font-size"] == "15", "#{text} is set at #{attrs["font-size"]}"
        end
      end
    end

    test "every fill and stroke is a theme colour" do
      allowed = ["none" | Theme.palette()]

      for {_module, name, circuit} <- GateCatalogue.circuits(), style <- [:color, :mono] do
        for colour <- colours(svg(circuit, style: style)) do
          assert colour in allowed, "#{name} (#{style}) uses #{colour}"
        end
      end
    end

    test "the root element is an img with an aria-label" do
      assert [root] = elements(svg(Qx.create_circuit(2) |> Qx.h(0)), "svg")
      assert root["role"] == "img"
      assert root["aria-label"] == "Quantum circuit, 2 qubits"

      assert [titled] = elements(svg(Qx.create_circuit(1) |> Qx.h(0), title: "Bell"), "svg")
      assert titled["aria-label"] == "Bell"
    end

    test "the output parses as XML, with a title that needs escaping too" do
      title = ~s(a <b> & "c")
      svg = svg(teleportation(), title: title)

      assert parse_xml!(svg)
      assert svg =~ "a &lt;b&gt; &amp; &quot;c&quot;"
      refute svg =~ "<b>"
    end
  end

  # -- columns ---------------------------------------------------------

  describe "columns" do
    test "the first column starts 12 after the wire, columns are 24 apart" do
      svg = svg(Qx.create_circuit(1) |> Qx.h(0) |> Qx.x(0) |> Qx.z(0))

      assert Enum.map(boxes(svg), & &1["x"]) == ["66", "122", "178"]
    end

    test "a wide label widens its box and every gate in the column shares its centre" do
      circuit =
        Qx.create_circuit(2)
        |> Qx.u(0, -7 * @pi / 16, -1.23, -3 * @pi / 16)
        |> Qx.h(1)
        |> Qx.x(0)
        |> Qx.x(1)

      svg = svg(circuit)
      assert [u, h, x0, x1] = boxes(svg)

      assert num(u["width"]) > 84
      assert h["width"] == "32"
      assert center_x(u) == center_x(h)

      # The next column starts 24 after the widest box of this one.
      assert num(x0["x"]) == num(u["x"]) + num(u["width"]) + 24
      assert x0["x"] == x1["x"]

      # The label fits with 8 either side by the renderer's own estimate.
      assert [{_, "U(−7π/16, −1.23, −3π/16)"} | _] = gate_labels(svg)
    end

    test "the wire runs 16 past the last column and the image 10 past the wire" do
      svg = svg(Qx.create_circuit(1) |> Qx.h(0))

      assert [%{"x2" => "114"}] = wires(svg)
      assert [%{"width" => "124"}] = elements(svg, "svg")
    end

    test "a conditional gate does not share a column with a gate its line would cross" do
      # The condition line of X on q0 runs down past q1, so X must sit to
      # the right of everything already drawn on q1.
      circuit =
        Qx.create_circuit(2, 1)
        |> Qx.measure(1, 0)
        |> Qx.h(1)
        |> Qx.h(1)
        |> Qx.c_if(0, 1, &Qx.x(&1, 0))

      boxes = boxes(svg(circuit))
      x = Enum.find(boxes, &(&1["stroke"] == family(:pauli).stroke))
      others = boxes -- [x]

      assert Enum.all?(others, &(num(&1["x"]) + num(&1["width"]) < num(x["x"])))
    end
  end

  # -- classical parts -------------------------------------------------

  describe "classical register, measurement and condition" do
    setup do
      {:ok, svg: svg(Qx.create_circuit(2, 2) |> Qx.h(0) |> Qx.measure(0, 1))}
    end

    test "the register is a double line in Ink 2, 3 apart, 44 below the last wire", %{svg: svg} do
      lines =
        svg |> elements("line") |> Enum.filter(&(horizontal?(&1) and &1["stroke"] == @ink2))

      assert [upper, lower] = lines
      assert {upper["y1"], lower["y1"]} == {"116.5", "119.5"}
      assert upper["stroke-width"] == "1" and lower["stroke-width"] == "1"
      assert upper["x1"] == "54"
    end

    test "the register is a bundle: a slash with the bit count", %{svg: svg} do
      assert svg =~ ~s(<path d="M61 124L67 112" stroke="#{@ink2}" stroke-width="1" fill="none"/>)

      assert {count, "2"} =
               Enum.find(texts(svg), fn {attrs, _} -> attrs["x"] == "69" end)

      assert count["font-size"] == "10.5" and count["fill"] == @ink2

      assert Enum.any?(texts(svg), fn {attrs, text} ->
               text == "c" and attrs["text-anchor"] == "end" and attrs["y"] == "123.1"
             end)
    end

    test "a meter is a neutral box with an ink arc and needle", %{svg: svg} do
      neutral = family(:non_unitary)

      assert [_h, meter] = boxes(svg)
      assert meter["fill"] == neutral.fill and meter["stroke"] == neutral.stroke

      x = center_x(meter)
      cx = Markup.num(x)
      left = Markup.num(x - 9)
      right = Markup.num(x + 9)

      assert svg =~
               ~s(<path d="M#{left} 32A9 9 0 0 1 #{right} 32" fill="none" stroke="#{@ink}" stroke-width="1.25"/>)

      assert Enum.any?(elements(svg, "line"), fn line ->
               line["x1"] == cx and line["y1"] == "32" and line["y2"] == "18" and
                 line["stroke"] == @ink
             end)
    end

    test "a measurement drops a double line to an arrowhead on the register, with its bit index",
         %{svg: svg} do
      assert [_h, meter] = boxes(svg)
      x = center_x(meter)

      drops = svg |> elements("line") |> Enum.filter(&(vertical?(&1) and &1["stroke"] == @ink2))

      assert [left, right] = drops
      assert num(left["x1"]) == x - 1.5 and num(right["x1"]) == x + 1.5
      assert left["y1"] == "42" and left["y2"] == "110"
      assert left["stroke-width"] == "1"

      assert [arrow] = elements(svg, "polygon")
      assert arrow["fill"] == @ink2

      # Tip first, on the upper register line; 9 wide and 7 tall.
      assert [[tip_x, tip_y], [left_x, base_y], [right_x, base_y]] =
               arrow["points"]
               |> String.split(" ")
               |> Enum.map(fn point -> point |> String.split(",") |> Enum.map(&num/1) end)

      assert tip_x == x and tip_y == 116.0
      assert right_x - left_x == 9.0 and tip_y - base_y == 7.0

      assert {index, "1"} =
               Enum.find(texts(svg), fn {attrs, _} -> num(attrs["x"]) == x + 8 end)

      assert index["y"] == "111" and index["font-size"] == "10.5" and index["fill"] == @ink2
    end

    test "a condition rises as a double line from a dot on the register, labelled c_k = v" do
      svg = svg(Qx.create_circuit(1, 2) |> Qx.measure(0, 1) |> Qx.c_if(1, 1, &Qx.x(&1, 0)))

      x_box = Enum.find(boxes(svg), &(&1["stroke"] == family(:pauli).stroke))
      x = center_x(x_box)

      rises =
        svg
        |> elements("line")
        |> Enum.filter(&(vertical?(&1) and &1["stroke"] == @ink2 and &1["y2"] == "70"))

      assert [left, right] = rises
      assert num(left["x1"]) == x - 1.5 and num(right["x1"]) == x + 1.5
      assert left["y1"] == "42"

      assert [dot] = Enum.filter(elements(svg, "circle"), &(&1["fill"] == @ink2))
      assert dot["r"] == "3.5" and dot["cy"] == "70" and num(dot["cx"]) == x

      assert {label, "c1 = 1"} =
               Enum.find(texts(svg), fn {attrs, _} -> attrs["font-size"] == "11" end)

      assert label["y"] == "87.7" and label["fill"] == @ink2 and num(label["x"]) == x
    end

    test "a condition on 0 is labelled = 0" do
      svg = svg(Qx.create_circuit(1, 1) |> Qx.measure(0, 0) |> Qx.c_if(0, 0, &Qx.x(&1, 0)))
      assert Enum.any?(texts(svg), fn {_, text} -> text == "c0 = 0" end)
    end

    test "no register is drawn for a circuit with no classical bits" do
      svg = svg(Qx.create_circuit(2) |> Qx.h(0))
      assert Enum.filter(elements(svg, "line"), &(&1["stroke"] == @ink2)) == []
      assert [%{"height" => "100"}] = elements(svg, "svg")
    end
  end

  # -- barrier ---------------------------------------------------------

  describe "barrier" do
    test "a dashed Muted line 20 beyond the first and last wire it covers" do
      svg = svg(Qx.create_circuit(4) |> Qx.barrier([1, 2]))

      assert [barrier] =
               svg |> elements("line") |> Enum.filter(&Map.has_key?(&1, "stroke-dasharray"))

      assert barrier["stroke"] == @muted
      assert barrier["stroke-dasharray"] == "4 3"
      assert barrier["stroke-width"] == "1"
      assert {barrier["y1"], barrier["y2"]} == {"54", "142"}
    end

    test "it has a column of its own, 24 from the gates either side" do
      svg = svg(Qx.create_circuit(2) |> Qx.h(0) |> Qx.barrier([0]) |> Qx.x(0) |> Qx.h(1))

      assert [barrier] =
               svg |> elements("line") |> Enum.filter(&Map.has_key?(&1, "stroke-dasharray"))

      assert [h0, x0, h1] = boxes(svg)
      assert num(barrier["x1"]) == num(h0["x"]) + 32 + 24
      assert num(x0["x"]) == num(barrier["x1"]) + 24

      # A gate added after the barrier is drawn after it, on any wire.
      assert h1["x"] == x0["x"]
    end
  end

  # -- title, options, style -------------------------------------------

  describe "title and options" do
    test "the title is left-aligned in the sans voice, and moves the first wire to 52" do
      svg = svg(Qx.create_circuit(1) |> Qx.h(0), title: "Bell")

      assert {attrs, "Bell"} =
               Enum.find(texts(svg), fn {attrs, _} ->
                 attrs["font-family"] == Theme.font(:sans)
               end)

      assert {attrs["x"], attrs["y"]} == {"24", "18"}
      assert attrs["font-size"] == "13" and attrs["font-weight"] == "600"
      refute Map.has_key?(attrs, "text-anchor")

      assert [%{"y1" => "52"}] = wires(svg)
    end

    test "a binary second argument still sets the title" do
      circuit = Qx.create_circuit(1) |> Qx.h(0)

      assert %Image{title: "Bell", svg: svg} = Qx.Draw.circuit(circuit, "Bell")
      assert svg == Qx.Draw.circuit(circuit, title: "Bell").svg
      assert %Image{title: "Bell"} = Qx.draw_circuit(circuit, "Bell")
      assert %Image{title: "Bell"} = Qx.draw_circuit(circuit, title: "Bell", style: :mono)
    end

    test "nil and no second argument draw without a title" do
      circuit = Qx.create_circuit(1) |> Qx.h(0)

      assert %Image{title: nil, svg: svg} = Qx.Draw.circuit(circuit)
      assert svg == Qx.Draw.circuit(circuit, nil).svg
      assert svg == Qx.Draw.circuit(circuit, []).svg
      assert svg == Qx.Draw.circuit(circuit, style: :color).svg
    end

    test "a long title widens the image" do
      title = String.duplicate("A long title ", 6)
      assert [%{"width" => width}] = elements(svg(Qx.create_circuit(1), title: title), "svg")
      assert num(width) > 400
    end

    test "an invalid style raises Qx.OptionError" do
      circuit = Qx.create_circuit(1) |> Qx.h(0)

      assert_raise Qx.OptionError, ~r/style/, fn -> Qx.Draw.circuit(circuit, style: :dark) end
      assert_raise Qx.OptionError, ~r/style/, fn -> Qx.draw_circuit(circuit, style: "mono") end
    end

    test "a title that is not a string, or a second argument of another type, raises Qx.OptionError" do
      circuit = Qx.create_circuit(1) |> Qx.h(0)

      assert_raise Qx.OptionError, ~r/title/, fn -> Qx.Draw.circuit(circuit, title: 42) end
      assert_raise Qx.OptionError, fn -> Qx.Draw.circuit(circuit, :bell) end
      assert_raise Qx.OptionError, fn -> Qx.Draw.circuit(circuit, [1, 2]) end
    end

    test "typed errors on a malformed circuit are unchanged" do
      # Qx.create_circuit(21) raises by itself, so the count is set on the
      # struct to reach the drawer's own guard.
      too_wide = %{Qx.create_circuit(1) | num_qubits: 21}
      assert_raise Qx.QubitCountError, ~r/21/, fn -> Qx.Draw.circuit(too_wide) end

      out_of_range = Qx.QuantumCircuit.put_instructions(Qx.create_circuit(1), [{:h, [5], []}])
      assert_raise Qx.QubitIndexError, fn -> Qx.Draw.circuit(out_of_range) end

      bad_bit = %{Qx.create_circuit(1, 1) | measurements: [{0, 7}]}
      assert_raise Qx.ClassicalBitError, fn -> Qx.Draw.circuit(bad_bit) end
    end
  end

  describe "style: :mono" do
    test "contains only ink, Ink 2, Muted and paper" do
      allowed = [@ink, @ink2, @muted, @paper, "none"]

      for circuit <- [teleportation(), qft3()], colour <- colours(svg(circuit, style: :mono)) do
        assert colour in allowed, "mono output uses #{colour}"
      end
    end

    test "every catalogue circuit contains only ink, Ink 2, Muted and paper" do
      allowed = [@ink, @ink2, @muted, @paper, "none"]

      assert GateCatalogue.circuits() != []

      for {_module, name, circuit} <- GateCatalogue.circuits() do
        mono = svg(circuit, style: :mono)

        for colour <- colours(mono) do
          assert colour in allowed, "mono #{name} uses #{colour}"
        end

        # Ink 2 and Muted belong to the register and the barrier. A gate
        # box is ink on paper.
        for box <- boxes(mono) do
          assert {box["stroke"], box["fill"]} == {@ink, @paper}, "mono #{name} box"
        end
      end
    end

    test "boxes are ink on paper and the geometry is that of the colour style" do
      color = svg(qft3())
      mono = svg(qft3(), style: :mono)

      assert Enum.all?(boxes(mono), &(&1["stroke"] == @ink and &1["fill"] == @paper))

      geometry = fn svg ->
        Enum.map(boxes(svg), &Map.take(&1, ["x", "y", "width", "height"]))
      end

      assert geometry.(mono) == geometry.(color)
      refute mono == color
    end
  end

  # -- whole circuits against the guide's drawings ----------------------

  describe "the guide's whole circuits" do
    test "teleportation matches the reference drawing" do
      svg = svg(teleportation(), title: "Quantum teleportation")

      assert [%{"width" => "540", "height" => "216", "viewBox" => "0 0 540 216"}] =
               elements(svg, "svg")

      assert Enum.map(wires(svg), &{&1["y1"], &1["x1"], &1["x2"]}) == [
               {"52", "54", "530"},
               {"100", "54", "530"},
               {"148", "54", "530"}
             ]

      # H, H, meter, meter, X, Z
      assert Enum.map(boxes(svg), &{&1["x"], &1["y"]}) == [
               {"66", "84"},
               {"258", "36"},
               {"314", "36"},
               {"370", "84"},
               {"426", "132"},
               {"482", "132"}
             ]

      assert [barrier] =
               svg |> elements("line") |> Enum.filter(&Map.has_key?(&1, "stroke-dasharray"))

      assert {barrier["x1"], barrier["y1"], barrier["y2"]} == {"178", "32", "168"}

      targets = Enum.filter(elements(svg, "circle"), &(&1["r"] == "9"))
      assert Enum.map(targets, &{&1["cx"], &1["cy"]}) == [{"138", "148"}, {"218", "100"}]

      assert Enum.map(elements(svg, "polygon"), & &1["points"]) == [
               "330,190 325.5,183 334.5,183",
               "386,190 381.5,183 390.5,183"
             ]

      assert Enum.any?(texts(svg), fn {attrs, text} ->
               text == "c1 = 1" and attrs["x"] == "442" and attrs["y"] == "209.7"
             end)
    end

    test "the three-qubit QFT matches the reference drawing" do
      svg = svg(qft3(), title: "Three-qubit quantum Fourier transform")

      assert [%{"width" => "556", "height" => "174"}] = elements(svg, "svg")

      # H, P(π/2), P(π/4), H, P(π/2), H
      assert Enum.map(boxes(svg), &{&1["x"], &1["y"], &1["width"]}) == [
               {"66", "36", "32"},
               {"122", "36", "56"},
               {"202", "36", "56"},
               {"282", "84", "32"},
               {"338", "84", "56"},
               {"418", "132", "32"}
             ]

      assert Enum.map(gate_labels(svg), fn {attrs, text} -> {attrs["x"], attrs["y"], text} end) ==
               [
                 {"82", "57.1", "H"},
                 {"150", "57.1", "P(π/2)"},
                 {"230", "57.1", "P(π/4)"},
                 {"298", "105.1", "H"},
                 {"366", "105.1", "P(π/2)"},
                 {"434", "153.1", "H"}
               ]

      assert Enum.map(connectors(svg), &{&1["x1"], &1["y1"], &1["y2"]}) == [
               {"150", "100", "68"},
               {"230", "148", "68"},
               {"366", "148", "116"},
               {"514", "52", "148"}
             ]
    end
  end

  # -- review follow-ups (visual-design-guide triage) --------------------

  describe "a circuit built by hand raises a typed error" do
    defp hand_built(instructions, qubits \\ 2, bits \\ 0) do
      Qx.QuantumCircuit.put_instructions(Qx.create_circuit(qubits, bits), instructions)
    end

    test "an empty barrier raises Qx.GateError" do
      circuit = Qx.create_circuit(2) |> Qx.barrier([])
      assert_raise Qx.GateError, ~r/barrier/, fn -> Qx.Draw.circuit(circuit) end
      assert_raise Qx.GateError, ~r/barrier/, fn -> Qx.draw_circuit(circuit) end
    end

    test "an instruction of the wrong shape raises Qx.GateError" do
      malformed = [
        {:cx, [0], []},
        {:h, [0, 1], []},
        {:ccx, [0, 1], []},
        {:h, 0, []},
        {:rx, [0], 1.0},
        {:h, [0]},
        :h,
        {"h", [0], []},
        {:measure, [0], []},
        {:c_if, [0], []},
        {:c_if, [0, 1], :x}
      ]

      for instruction <- malformed do
        assert_raise Qx.GateError, fn -> Qx.Draw.circuit(hand_built([instruction], 2, 1)) end
      end
    end

    test "a malformed instruction inside a c_if block raises Qx.GateError" do
      circuit = hand_built([{:c_if, [0, 1], [{:cx, [0], []}]}], 2, 1)
      assert_raise Qx.GateError, fn -> Qx.Draw.circuit(circuit) end
    end

    test "an angle too large to draw raises Qx.GateError naming the gate" do
      circuit = Qx.create_circuit(1) |> Qx.rx(0, 10 ** 400)
      assert_raise Qx.GateError, ~r/rx/, fn -> Qx.Draw.circuit(circuit) end

      controlled = hand_built([{:cp, [0, 1], [-(10 ** 400)]}])
      assert_raise Qx.GateError, ~r/cp/, fn -> Qx.Draw.circuit(controlled) end
    end

    test "a nested c_if and a measurement in a block raise Qx.ConditionalError" do
      nested = hand_built([{:c_if, [0, 1], [{:c_if, [0, 1], [{:x, [0], []}]}]}], 2, 1)
      assert_raise Qx.ConditionalError, fn -> Qx.Draw.circuit(nested) end

      measured = hand_built([{:c_if, [0, 1], [{:measure, [0, 0], []}]}], 2, 1)
      assert_raise Qx.ConditionalError, fn -> Qx.Draw.circuit(measured) end
    end

    test "a classical bit or qubit out of range raises its index error" do
      bad_condition = hand_built([{:c_if, [5, 1], [{:x, [0], []}]}], 2, 1)
      assert_raise Qx.ClassicalBitError, fn -> Qx.Draw.circuit(bad_condition) end

      bad_bit = hand_built([{:measure, [0, 7], []}], 2, 1)
      assert_raise Qx.ClassicalBitError, fn -> Qx.Draw.circuit(bad_bit) end

      bad_qubit = hand_built([{:measure, [5, 0], []}], 2, 1)
      assert_raise Qx.QubitIndexError, fn -> Qx.Draw.circuit(bad_qubit) end
    end

    test "a classical bit that is not an integer raises Qx.ClassicalBitError" do
      bad_condition = hand_built([{:c_if, [:a, 1], [{:x, [0], []}]}], 2, 1)
      assert_raise Qx.ClassicalBitError, fn -> Qx.Draw.circuit(bad_condition) end

      bad_bit = hand_built([{:measure, [0, "1"], []}], 2, 1)
      assert_raise Qx.ClassicalBitError, fn -> Qx.Draw.circuit(bad_bit) end
    end
  end

  describe "qubits given in reverse order" do
    test "cx(1, 0) puts the control on the lower wire and the target on the upper" do
      svg = svg(Qx.create_circuit(2) |> Qx.cx(1, 0))
      circles = elements(svg, "circle")

      assert [%{"cy" => "74"}] = Enum.filter(circles, &(&1["r"] == "3.5"))
      assert [%{"cy" => "26"}] = Enum.filter(circles, &(&1["r"] == "9"))
      assert [connector] = connectors(svg)
      assert Enum.sort([connector["y1"], connector["y2"]]) == ["26", "74"]
    end

    test "ccx(2, 1, 0) puts the target on the top wire" do
      svg = svg(Qx.create_circuit(3) |> Qx.ccx(2, 1, 0))
      circles = elements(svg, "circle")

      assert circles |> Enum.filter(&(&1["r"] == "3.5")) |> Enum.map(& &1["cy"]) |> Enum.sort() ==
               ["122", "74"]

      assert [%{"cy" => "26"}] = Enum.filter(circles, &(&1["r"] == "9"))
      assert [connector] = connectors(svg)
      assert Enum.sort([connector["y1"], connector["y2"]]) == ["122", "26"]
    end

    test "iswap is symmetric: iswap(1, 0) draws as iswap(0, 1)" do
      assert svg(Qx.create_circuit(2) |> Qx.iswap(1, 0)) ==
               svg(Qx.create_circuit(2) |> Qx.iswap(0, 1))

      assert svg(Qx.create_circuit(3) |> Qx.iswap(2, 0)) ==
               svg(Qx.create_circuit(3) |> Qx.iswap(0, 2))
    end
  end

  describe "options (review follow-ups)" do
    test "an unknown option raises Qx.OptionError naming it" do
      circuit = Qx.create_circuit(1) |> Qx.h(0)

      assert_raise Qx.OptionError, ~r/:colour/, fn -> Qx.Draw.circuit(circuit, colour: :mono) end
      assert_raise Qx.OptionError, ~r/:size/, fn -> Qx.draw_circuit(circuit, size: 300) end
    end

    test "an empty title is no title" do
      circuit = Qx.create_circuit(1) |> Qx.h(0)
      untitled = Qx.Draw.circuit(circuit)

      assert %Image{title: nil} = Qx.Draw.circuit(circuit, title: "")
      assert Qx.Draw.circuit(circuit, title: "").svg == untitled.svg
      assert Qx.Draw.circuit(circuit, "").svg == untitled.svg
    end

    test "the label names the number of qubits when there is no title" do
      assert [%{"aria-label" => "Quantum circuit, 1 qubit"}] =
               elements(svg(Qx.create_circuit(1)), "svg")

      assert [%{"aria-label" => "Quantum circuit, 2 qubits"}] =
               elements(svg(Qx.create_circuit(2)), "svg")
    end

    test "characters XML does not allow are left out of the title" do
      svg = svg(Qx.create_circuit(1), title: "Bell" <> <<0>> <> " state" <> <<0xFF>>)

      assert parse_xml!(svg)
      assert Enum.any?(texts(svg), fn {_attrs, text} -> text == "Bell state" end)
    end
  end
end
