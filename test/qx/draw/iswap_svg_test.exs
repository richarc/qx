defmodule Qx.Draw.IswapSvgTest do
  use ExUnit.Case, async: true

  describe "iswap gate SVG rendering" do
    test "renders an SVG string" do
      circuit = Qx.create_circuit(2) |> Qx.iswap(0, 1)
      svg = Qx.Draw.circuit(circuit)

      assert is_binary(svg)
      assert svg =~ "<svg"
    end

    test "SVG contains iSW label text for both qubit boxes" do
      circuit = Qx.create_circuit(2) |> Qx.iswap(0, 1)
      svg = Qx.Draw.circuit(circuit)

      # Two iSW labels — one per qubit
      isw_count = svg |> String.split("iSW") |> length() |> Kernel.-(1)
      assert isw_count >= 2
    end

    test "SVG contains rect elements for the labelled boxes" do
      circuit = Qx.create_circuit(2) |> Qx.iswap(0, 1)
      svg = Qx.Draw.circuit(circuit)

      assert svg =~ "<rect"
    end

    test "non-adjacent qubits render correctly (qubit 0 and 2 in a 3-qubit circuit)" do
      circuit = Qx.create_circuit(3) |> Qx.iswap(0, 2)
      svg = Qx.Draw.circuit(circuit)

      assert is_binary(svg)
      assert svg =~ "<svg"
      assert svg =~ "iSW"
    end
  end
end
