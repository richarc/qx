defmodule Qx.DrawContractsTest do
  @moduledoc """
  Contract tests for the draw-rework (plan: draw-rework): one static
  return type per function, no environment sniffing, artifact structs
  with Inspect + Kino.Render, facade delegates aligned.
  """
  use ExUnit.Case, async: true

  alias Qx.Draw.{Image, StateTable}

  defp bell_result do
    Qx.create_circuit(2, 2)
    |> Qx.h(0)
    |> Qx.cx(0, 1)
    |> Qx.measure_all()
    |> Qx.run(shots: 64)
  end

  describe "chart functions return VegaLite.t() always" do
    test "draw/2, draw_counts/2, draw_histogram/2" do
      result = bell_result()
      assert %VegaLite{} = Qx.draw(result)
      assert %VegaLite{} = Qx.draw_counts(result, title: "t")

      assert %VegaLite{} =
               Qx.draw_histogram(Qx.get_probabilities(Qx.create_circuit(1) |> Qx.h(0)))
    end

    test "tier 2 names follow the Qx.draw_X -> Draw.X rule" do
      result = bell_result()
      assert %VegaLite{} = Qx.Draw.plot(result)
      assert %VegaLite{} = Qx.Draw.counts(result)
      refute function_exported?(Qx.Draw, :plot_counts, 2)
      refute function_exported?(Qx.Draw, :bloch_sphere, 2)
    end
  end

  describe "draw_bloch/2 returns %Qx.Draw.Image{}" do
    test "always an Image, svg inside, regardless of options" do
      state = Qx.create_circuit(1) |> Qx.h(0) |> Qx.get_state()
      assert %Image{} = image = Qx.draw_bloch(state, title: "plus")
      assert String.contains?(image.svg, "<svg")
      assert to_string(image) == image.svg
    end
  end

  describe "draw_circuit/2 facade delegate" do
    test "returns an Image" do
      qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
      assert %Image{} = image = Qx.draw_circuit(qc, "Bell")
      assert String.contains?(image.svg, "<svg")
    end
  end

  describe "draw_state/2 returns %Qx.Draw.StateTable{}" do
    test "one static type, renderings as data" do
      state = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1) |> Qx.get_state()
      assert %StateTable{} = table = Qx.draw_state(state)
      assert table.text =~ "Basis State"
      assert table.markdown =~ "|00⟩" or table.markdown =~ "\\|00⟩"
      assert table.html =~ "<table"
      assert to_string(table) == table.text
    end

    test "precision and hide_zeros options still work" do
      state = Qx.create_circuit(2) |> Qx.h(0) |> Qx.get_state()
      assert %StateTable{} = t = Qx.draw_state(state, precision: 5, hide_zeros: true)
      refute t.text =~ "|11⟩"
    end
  end

  describe "environment independence" do
    # Deliberately narrow: matches the two exact idioms the rework
    # deleted. A broad `ensure_loaded` grep would false-positive on the
    # sanctioned compile-time guards around optional-dep protocol impls.
    test "no Kino sniffing left anywhere in lib/" do
      hits =
        "lib/**/*.ex"
        |> Path.wildcard()
        |> Enum.filter(fn f ->
          content = File.read!(f)

          String.contains?(content, "kino_available?") or
            String.contains?(content, "apply(Kino")
        end)

      assert hits == []
    end
  end

  describe "Kino.Render implementations (kino present in dev/test)" do
    test "artifact structs and taught structs render" do
      for mod <- [Image, StateTable, Qx.QuantumCircuit, Qx.SimulationResult, Qx.Step] do
        impl = Kino.Render.impl_for(struct(mod, %{}))
        assert impl != Kino.Render.Any, "no Kino.Render impl for #{inspect(mod)}"
      end
    end
  end

  describe "Inspect impls" do
    test "Image inspects compactly, StateTable shows the table" do
      state = Qx.create_circuit(1) |> Qx.get_state()
      assert inspect(Qx.draw_bloch(state)) =~ "#Qx.Draw.Image<"
      assert inspect(Qx.draw_state(state)) =~ "Basis State"
    end
  end
end
