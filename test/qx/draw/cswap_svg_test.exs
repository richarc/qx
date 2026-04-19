defmodule Qx.Draw.CswapSvgTest do
  use ExUnit.Case, async: true

  describe "cswap gate SVG rendering" do
    test "renders an SVG string" do
      circuit = Qx.create_circuit(3) |> Qx.cswap(0, 1, 2)
      svg = Qx.Draw.circuit(circuit)

      assert is_binary(svg)
      assert svg =~ "<svg"
    end

    test "SVG contains control dot (filled circle) and × symbols" do
      circuit = Qx.create_circuit(3) |> Qx.cswap(0, 1, 2)
      svg = Qx.Draw.circuit(circuit)

      assert svg =~ "<circle"
      assert svg =~ "×"
    end

    test "SVG contains vertical connecting line" do
      circuit = Qx.create_circuit(3) |> Qx.cswap(0, 1, 2)
      svg = Qx.Draw.circuit(circuit)

      assert svg =~ "<line"
    end

    test "non-adjacent qubits render correctly" do
      circuit = Qx.create_circuit(4) |> Qx.cswap(0, 1, 3)
      svg = Qx.Draw.circuit(circuit)

      assert is_binary(svg)
      assert svg =~ "<svg"
    end
  end
end
