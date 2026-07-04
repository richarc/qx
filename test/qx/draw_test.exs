defmodule Qx.DrawTest do
  use ExUnit.Case, async: true

  alias Qx.Draw.{Image, StateTable}

  defp state(build_fn) do
    Qx.create_circuit(1) |> build_fn.() |> Qx.get_state()
  end

  describe "bloch/2" do
    test "visualizes |0⟩ state" do
      assert %Image{} = Qx.Draw.bloch(Qx.create_circuit(1) |> Qx.get_state())
    end

    test "visualizes |1⟩ state" do
      assert %Image{svg: svg} = Qx.Draw.bloch(state(&Qx.x(&1, 0)))
      assert svg =~ "<svg"
    end

    test "visualizes |+⟩ state" do
      assert %Image{} = Qx.Draw.bloch(state(&Qx.h(&1, 0)))
    end

    test "visualizes |−⟩ state" do
      minus = Qx.create_circuit(1) |> Qx.x(0) |> Qx.h(0) |> Qx.get_state()
      assert %Image{} = Qx.Draw.bloch(minus)
    end

    test "carries a custom title" do
      assert %Image{title: "My Custom Title", svg: svg} =
               Qx.Draw.bloch(state(&Qx.h(&1, 0)), title: "My Custom Title")

      assert svg =~ "My Custom Title"
    end

    test "supports custom size" do
      assert %Image{svg: svg} = Qx.Draw.bloch(state(&Qx.h(&1, 0)), size: 600)
      assert svg =~ ~s(width="600")
    end

    test "to_string/1 returns the raw SVG" do
      image = Qx.Draw.bloch(Qx.create_circuit(1) |> Qx.get_state())
      assert to_string(image) == image.svg
    end
  end

  describe "state_table/2" do
    test "displays single-qubit state" do
      table = Qx.Draw.state_table(Qx.create_circuit(1) |> Qx.get_state())

      assert %StateTable{} = table
      assert table.text =~ "Basis State"
      assert table.text =~ "|0⟩"
    end

    test "displays two-qubit state" do
      table = Qx.Draw.state_table(Qx.create_circuit(2) |> Qx.get_state())

      assert table.text =~ "|00⟩"
      assert table.text =~ "|11⟩"
    end

    test "works with three-qubit state" do
      table = Qx.Draw.state_table(Qx.create_circuit(3) |> Qx.get_state())

      assert table.text =~ "|000⟩"
      assert table.text =~ "|111⟩"
    end

    test "hides zero-probability states with hide_zeros" do
      table =
        Qx.create_circuit(2)
        |> Qx.h(0)
        |> Qx.get_state()
        |> Qx.Draw.state_table(hide_zeros: true)

      refute table.text =~ "|01⟩"
      refute table.text =~ "|11⟩"
    end

    test "html field is an HTML table" do
      table = Qx.Draw.state_table(Qx.create_circuit(2) |> Qx.get_state())

      assert table.html =~ "<table"
      assert table.html =~ "<th>Basis State</th>"
    end

    test "supports custom precision" do
      table =
        Qx.create_circuit(1)
        |> Qx.h(0)
        |> Qx.get_state()
        |> Qx.Draw.state_table(precision: 5)

      assert table.text =~ ~r/\d+\.\d{5}/
    end

    test "markdown field escapes basis-state pipes" do
      table = Qx.Draw.state_table(Qx.create_circuit(2) |> Qx.get_state())

      assert table.markdown =~ "| Basis State | Amplitude | Probability |"
      assert table.markdown =~ "| \\|00⟩"
      assert table.markdown =~ "| \\|11⟩"
    end

    test "accepts the internal calc-engine register escape hatch" do
      table = Qx.Draw.state_table(Qx.Register.new(1))
      assert %StateTable{} = table
      assert table.text =~ "|0⟩"
    end

    test "to_string/1 returns the text table" do
      table = Qx.Draw.state_table(Qx.create_circuit(1) |> Qx.get_state())
      assert to_string(table) == table.text
    end
  end

  describe "chart functions" do
    test "plot/2 returns a VegaLite spec" do
      result = Qx.create_circuit(1) |> Qx.h(0) |> Qx.run(shots: 8)
      assert %VegaLite{} = Qx.Draw.plot(result)
    end

    test "counts/2 returns a VegaLite spec, empty counts included" do
      result = Qx.create_circuit(1) |> Qx.h(0) |> Qx.run(shots: 8)
      assert %VegaLite{} = Qx.Draw.counts(result)
    end

    test "histogram/2 returns a VegaLite spec" do
      probs = Qx.get_probabilities(Qx.create_circuit(2) |> Qx.h(0))
      assert %VegaLite{} = Qx.Draw.histogram(probs, title: "t")
    end
  end

  describe "facade delegates" do
    test "Qx.draw_bloch/2 returns an Image" do
      assert %Image{} = Qx.draw_bloch(Qx.create_circuit(1) |> Qx.get_state())
    end

    test "Qx.draw_state/2 returns a StateTable" do
      table = Qx.draw_state(Qx.create_circuit(2) |> Qx.get_state())
      assert %StateTable{} = table
      assert table.text =~ "Basis State"
    end

    test "Qx.draw_circuit/2 returns an Image" do
      qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
      assert %Image{svg: svg} = Qx.draw_circuit(qc)
      assert svg =~ "<svg"
    end
  end
end
