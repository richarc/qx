defmodule Qx.Draw.CswapSvgTest do
  use ExUnit.Case, async: true

  describe "cswap gate SVG rendering" do
    test "renders an SVG string" do
      circuit = Qx.create_circuit(3) |> Qx.cswap(0, 1, 2)
      svg = Qx.Draw.circuit(circuit).svg

      assert is_binary(svg)
      assert svg =~ "<svg"
    end

    test "SVG contains control dot (filled circle) and × symbols" do
      circuit = Qx.create_circuit(3) |> Qx.cswap(0, 1, 2)
      svg = Qx.Draw.circuit(circuit).svg

      assert svg =~ "<circle"

      # Each × is two round-capped lines in the Exchange stroke.
      cross_lines =
        Regex.scan(~r/<line [^>]*stroke="#5D3A9B"[^>]*stroke-linecap="round"/, svg)

      assert length(cross_lines) == 4
    end

    test "SVG contains vertical connecting line" do
      circuit = Qx.create_circuit(3) |> Qx.cswap(0, 1, 2)
      svg = Qx.Draw.circuit(circuit).svg

      assert svg =~ "<line"
    end

    test "non-adjacent qubits render correctly" do
      circuit = Qx.create_circuit(4) |> Qx.cswap(0, 1, 3)
      svg = Qx.Draw.circuit(circuit).svg

      assert is_binary(svg)
      assert svg =~ "<svg"
    end
  end
end
