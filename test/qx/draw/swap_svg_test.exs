defmodule Qx.Draw.SwapSvgTest do
  use ExUnit.Case, async: true

  describe "swap gate SVG rendering" do
    test "renders an SVG string" do
      circuit = Qx.create_circuit(2) |> Qx.swap(0, 1)
      svg = Qx.Draw.circuit(circuit)

      assert is_binary(svg)
      assert svg =~ "<svg"
    end

    test "SVG contains line elements for the × symbols and connecting line" do
      circuit = Qx.create_circuit(2) |> Qx.swap(0, 1)
      svg = Qx.Draw.circuit(circuit)

      # render_swap produces 5 lines: 1 connecting + 2 per × symbol (2 qubits)
      line_count = svg |> String.split("<line") |> length() |> Kernel.-(1)
      assert line_count >= 5
    end

    test "non-adjacent qubits render correctly (qubit 0 and 2 in a 3-qubit circuit)" do
      circuit = Qx.create_circuit(3) |> Qx.swap(0, 2)
      svg = Qx.Draw.circuit(circuit)

      assert is_binary(svg)
      assert svg =~ "<svg"
    end
  end
end
