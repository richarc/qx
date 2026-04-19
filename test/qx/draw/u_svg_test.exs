defmodule Qx.Draw.USvgTest do
  use ExUnit.Case, async: true

  describe "u gate SVG rendering" do
    test "renders an SVG string" do
      circuit = Qx.create_circuit(1) |> Qx.u(0, :math.pi(), 0, :math.pi())
      svg = Qx.Draw.circuit(circuit)

      assert is_binary(svg)
      assert svg =~ "<svg"
    end

    test "SVG contains U label text" do
      circuit = Qx.create_circuit(1) |> Qx.u(0, :math.pi(), 0, :math.pi())
      svg = Qx.Draw.circuit(circuit)

      assert svg =~ ">U("
    end

    test "SVG contains rect element for the labelled box" do
      circuit = Qx.create_circuit(1) |> Qx.u(0, :math.pi(), 0, :math.pi())
      svg = Qx.Draw.circuit(circuit)

      assert svg =~ "<rect"
    end

    test "renders on a multi-qubit circuit" do
      circuit = Qx.create_circuit(3) |> Qx.u(2, :math.pi() / 2, 0, :math.pi())
      svg = Qx.Draw.circuit(circuit)

      assert is_binary(svg)
      assert svg =~ "<svg"
      assert svg =~ ">U("
    end
  end
end
