defmodule Qx.Draw.IswapSvgTest do
  use ExUnit.Case, async: true

  alias Qx.Test.SVGText

  describe "iswap gate SVG rendering" do
    test "renders an SVG string" do
      circuit = Qx.create_circuit(2) |> Qx.iswap(0, 1)
      svg = Qx.Draw.circuit(circuit).svg

      assert is_binary(svg)
      assert svg =~ "<svg"
    end

    test "adjacent qubits draw one Exchange box spanning both wires, labelled iSWAP" do
      circuit = Qx.create_circuit(2) |> Qx.iswap(0, 1)
      svg = Qx.Draw.circuit(circuit).svg

      # One box in the Exchange stroke, 80 tall: from 16 above the upper
      # wire to 16 below the lower one.
      assert [[box]] = Regex.scan(~r/<rect [^>]*stroke="#5D3A9B"[^>]*>/, svg)
      assert box =~ ~s(height="80")

      labels = SVGText.labels(svg)

      assert Enum.count(labels, &(&1 == "iSWAP")) == 1
    end

    test "SVG contains rect elements for the labelled boxes" do
      circuit = Qx.create_circuit(2) |> Qx.iswap(0, 1)
      svg = Qx.Draw.circuit(circuit).svg

      assert svg =~ "<rect"
    end

    test "non-adjacent qubits render correctly (qubit 0 and 2 in a 3-qubit circuit)" do
      circuit = Qx.create_circuit(3) |> Qx.iswap(0, 2)
      svg = Qx.Draw.circuit(circuit).svg

      assert is_binary(svg)
      assert svg =~ "<svg"

      # Not adjacent: one labelled Exchange box on each wire.
      labels = SVGText.labels(svg)

      assert Enum.count(labels, &(&1 == "iSWAP")) == 2
      assert length(Regex.scan(~r/<rect [^>]*stroke="#5D3A9B"[^>]*>/, svg)) == 2
    end
  end
end
