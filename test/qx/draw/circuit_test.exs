defmodule Qx.Draw.CircuitTest do
  use ExUnit.Case, async: true

  defp parse_float(str) do
    case Float.parse(str) do
      {f, _} -> f
      :error -> raise ArgumentError, "cannot parse float: #{inspect(str)}"
    end
  end

  describe "Draw.circuit/2 — measurement arrowhead geometry" do
    # Build a simple 1-qubit circuit with one measurement so we can
    # inspect the rendered SVG polygon coordinates.
    setup do
      qc = Qx.create_circuit(1, 1) |> Qx.measure(0, 0)
      svg = Qx.Draw.circuit(qc)
      {:ok, svg: svg}
    end

    test "renders an SVG string", %{svg: svg} do
      assert is_binary(svg)
      assert svg =~ "<svg"
      assert svg =~ "</svg>"
    end

    test "arrowhead tip does not extend past the bottom classical register line",
         %{svg: svg} do
      # The classical double-line register has two horizontal lines.
      # Find the bottom register line y-coordinate (the larger y value).
      classical_ys =
        Regex.scan(
          ~r/<line x1="(\d+)" y1="([\d.]+)" x2="(\d+)" y2="([\d.]+)" stroke="#778899"/,
          svg
        )
        |> Enum.filter(fn [_, x1, _y1, x2, _y2] -> x1 != x2 end)
        |> Enum.map(fn [_, _x1, _y1, _x2, y2] -> parse_float(y2) end)

      assert classical_ys != [], "expected to find classical register lines in SVG"

      bottom_register_line_y = Enum.max(classical_ys)

      # Extract the polygon tip y (first point in the polygon)
      [_, points_str] = Regex.run(~r/<polygon points="([^"]+)"/, svg)
      [tip_point | _] = String.split(points_str, " ")
      [_, tip_y_str] = String.split(tip_point, ",")
      tip_y = parse_float(tip_y_str)

      assert tip_y <= bottom_register_line_y,
             "Arrowhead tip (#{tip_y}) extends past the bottom classical register line (#{bottom_register_line_y})"
    end

    test "arrowhead base is above the classical register top line", %{svg: svg} do
      classical_ys =
        Regex.scan(
          ~r/<line x1="(\d+)" y1="([\d.]+)" x2="(\d+)" y2="([\d.]+)" stroke="#778899"/,
          svg
        )
        |> Enum.filter(fn [_, x1, _y1, x2, _y2] -> x1 != x2 end)
        |> Enum.map(fn [_, _x1, _y1, _x2, y2] -> parse_float(y2) end)

      top_register_line_y = Enum.min(classical_ys)

      [_, points_str] = Regex.run(~r/<polygon points="([^"]+)"/, svg)
      [_ | base_points] = String.split(points_str, " ")

      base_ys =
        Enum.map(base_points, fn pt ->
          [_, y_str] = String.split(pt, ",")
          parse_float(y_str)
        end)

      Enum.each(base_ys, fn base_y ->
        assert base_y <= top_register_line_y,
               "Arrowhead base (#{base_y}) should be at or above the top classical line (#{top_register_line_y})"
      end)
    end

    test "arrowhead has visible height of at least 6px", %{svg: svg} do
      [_, points_str] = Regex.run(~r/<polygon points="([^"]+)"/, svg)
      [tip_point | base_points] = String.split(points_str, " ")

      [_, tip_y_str] = String.split(tip_point, ",")
      tip_y = parse_float(tip_y_str)

      base_y =
        base_points
        |> List.first()
        |> String.split(",")
        |> List.last()
        |> parse_float()

      height = abs(tip_y - base_y)

      assert height >= 6,
             "Arrowhead height (#{height}) is too small to be visible"
    end
  end
end
