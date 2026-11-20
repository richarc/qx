defmodule Qx.Draw.ThemeTest do
  use ExUnit.Case, async: true

  alias Qx.Draw.Theme
  alias Qx.Test.GateCatalogue

  # Stroke and fill of each gate family, from the Foundations sheet of the
  # Qx visual design guide.
  @guide_families %{
    pauli: {"#0072B2", "#D6E8F3"},
    hadamard: {"#D55E00", "#F8E5D6"},
    phase: {"#009E73", "#D6EFE9"},
    rotation: {"#A8457F", "#F1E1EB"},
    exchange: {"#5D3A9B", "#E5DFEF"},
    non_unitary: {"#5B6470", "#E5E6E8"}
  }

  # The Vega-Lite config on the Charts sheet, as the JSON it converts to.
  @guide_config %{
    "background" => "#FFFFFF",
    "font" => "-apple-system, 'Segoe UI', Helvetica, Arial, sans-serif",
    "view" => %{"stroke" => nil},
    "mark" => %{"tooltip" => true},
    "bar" => %{"color" => "#0072B2", "cornerRadiusEnd" => 3},
    "scale" => %{"bandPaddingInner" => 0.32, "bandPaddingOuter" => 0.16},
    "title" => %{
      "anchor" => "start",
      "fontSize" => 14,
      "fontWeight" => 600,
      "color" => "#16181D",
      "offset" => 14
    },
    "axis" => %{
      "labelColor" => "#4A5261",
      "labelFontSize" => 11,
      "titleColor" => "#16181D",
      "titleFontSize" => 12,
      "titleFontWeight" => 500,
      "titlePadding" => 10,
      "gridColor" => "#E6E9EE",
      "domainColor" => "#8A93A0",
      "ticks" => false,
      "labelPadding" => 8
    },
    "axisX" => %{
      "grid" => false,
      "labelAngle" => 0,
      "labelFont" => "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
    },
    "axisY" => %{"domain" => false, "tickCount" => 5},
    "legend" => %{
      "labelColor" => "#4A5261",
      "titleColor" => "#16181D",
      "symbolType" => "square"
    },
    "range" => %{"category" => ["#0072B2", "#D55E00", "#009E73", "#A8457F", "#5D3A9B"]}
  }

  defp channels("#" <> hex) do
    for <<pair::binary-size(2) <- hex>>, do: String.to_integer(pair, 16)
  end

  describe "gate families" do
    test "the catalogue has a circuit for every producer function" do
      assert GateCatalogue.uncovered() == []
    end

    test "every catalogue entry names a function that exists" do
      assert GateCatalogue.stale() == []
    end

    test "every gate atom Qx.Operations and Qx.Patterns emit has a family" do
      atoms = GateCatalogue.all_atoms()
      assert :phase in atoms and :cy in atoms and :c_if in atoms

      for atom <- atoms do
        assert Theme.family(atom) in Map.keys(@guide_families),
               "no family for #{inspect(atom)}"
      end
    end

    test "every gate atom the OpenQASM importer emits has a family" do
      atoms = GateCatalogue.qasm_atoms()

      # Exact, so a table entry the reader fails to pick up is noticed.
      # Update both numbers when the importer's gate table changes.
      assert length(GateCatalogue.qasm_table()) == 28
      assert length(atoms) == 24

      for atom <- atoms do
        assert Theme.family(atom) in Map.keys(@guide_families),
               "no family for #{inspect(atom)}"
      end
    end

    test "gates/0 is exactly the set of atoms the producers emit" do
      emitted = Enum.uniq(GateCatalogue.all_atoms() ++ GateCatalogue.qasm_atoms())
      assert Enum.sort(Theme.gates()) == Enum.sort(emitted)
    end

    test "a controlled gate takes the family of the gate it controls" do
      for gate <- [:x, :y, :z, :cx, :ccx, :cy, :cz], do: assert(Theme.family(gate) == :pauli)
      assert Theme.family(:h) == :hadamard
      for gate <- [:s, :sdg, :t, :tdg, :phase, :cp], do: assert(Theme.family(gate) == :phase)

      for gate <- [:rx, :ry, :rz, :u, :crx, :cry, :crz],
          do: assert(Theme.family(gate) == :rotation)

      for gate <- [:swap, :iswap, :cswap], do: assert(Theme.family(gate) == :exchange)
      for gate <- [:measure, :c_if, :barrier], do: assert(Theme.family(gate) == :non_unitary)
    end

    test "an unknown gate raises Qx.GateError" do
      assert_raise Qx.GateError, fn -> Theme.family(:p) end
      assert_raise Qx.GateError, fn -> Theme.family(:not_a_gate) end
    end

    test "each family has the guide's stroke and fill" do
      assert Enum.sort(Theme.families()) == Enum.sort(Map.keys(@guide_families))

      for {family, {stroke, fill}} <- @guide_families do
        assert Theme.family_colors(family) == %{stroke: stroke, fill: fill}
      end
    end

    test "each fill is its stroke at 16% on paper, to within 1 per channel" do
      for family <- Theme.families() do
        %{stroke: stroke, fill: fill} = Theme.family_colors(family)

        for {s, f} <- Enum.zip(channels(stroke), channels(fill)) do
          assert_in_delta f, 255 - 0.16 * (255 - s), 1.0, "#{family}: #{stroke} / #{fill}"
        end
      end
    end

    test "the mono style draws every family in ink on paper" do
      for family <- Theme.families() do
        assert Theme.family_colors(family, :mono) == %{stroke: "#16181D", fill: "#FFFFFF"}
        assert Theme.family_colors(family, :color) == Theme.family_colors(family)
      end
    end
  end

  describe "neutrals, accents and type" do
    test "colours are the guide's hex values" do
      assert Theme.color(:ink) == "#16181D"
      assert Theme.color(:ink2) == "#4A5261"
      assert Theme.color(:muted) == "#6B7482"
      assert Theme.color(:back) == "#A9B1BD"
      assert Theme.color(:rule) == "#D9DEE5"
      assert Theme.color(:paper) == "#FFFFFF"
      assert Theme.color(:accent) == "#D55E00"
      assert Theme.color(:data) == "#0072B2"
    end

    test "palette/0 lists every colour a drawing may use" do
      palette = Theme.palette()

      for name <- [:ink, :ink2, :muted, :back, :rule, :paper, :accent, :data] do
        assert Theme.color(name) in palette
      end

      for {_family, {stroke, fill}} <- @guide_families do
        assert stroke in palette and fill in palette
      end
    end

    test "the three font stacks" do
      assert Theme.font(:math) ==
               "'STIX Two Text','STIX Two Math','Latin Modern Roman',Cambria,'Times New Roman',serif"

      assert Theme.font(:sans) == "-apple-system,'Segoe UI',Helvetica,Arial,sans-serif"
      assert Theme.font(:mono) == "ui-monospace,SFMono-Regular,Menlo,Consolas,monospace"
    end
  end

  describe "vega_config/0" do
    test "converts to the guide's Vega-Lite config" do
      config =
        VegaLite.new()
        |> VegaLite.config(Theme.vega_config())
        |> VegaLite.to_spec()
        |> Map.fetch!("config")

      assert config == @guide_config
    end
  end
end
