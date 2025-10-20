defmodule Qx.DrawTest do
  use ExUnit.Case, async: true

  describe "bloch_sphere/2" do
    test "visualizes |0⟩ state" do
      q = Qx.Qubit.new()
      result = Qx.Draw.bloch_sphere(q)

      assert is_struct(result, VegaLite) or is_binary(result)
    end

    test "visualizes |1⟩ state" do
      q = Qx.Qubit.one()
      result = Qx.Draw.bloch_sphere(q)

      assert is_struct(result, VegaLite) or is_binary(result)
    end

    test "visualizes |+⟩ state" do
      q = Qx.Qubit.plus()
      result = Qx.Draw.bloch_sphere(q)

      assert is_struct(result, VegaLite) or is_binary(result)
    end

    test "visualizes |-⟩ state" do
      q = Qx.Qubit.minus()
      result = Qx.Draw.bloch_sphere(q)

      assert is_struct(result, VegaLite) or is_binary(result)
    end

    test "supports SVG format" do
      q = Qx.Qubit.new()
      result = Qx.Draw.bloch_sphere(q, format: :svg)

      assert is_binary(result)
      assert result =~ "<svg"
      assert result =~ "</svg>"
    end

    test "supports custom title" do
      q = Qx.Qubit.new()
      result = Qx.Draw.bloch_sphere(q, format: :svg, title: "My Custom Title")

      assert is_binary(result)
      assert result =~ "My Custom Title"
    end

    test "supports custom size" do
      q = Qx.Qubit.new()
      result = Qx.Draw.bloch_sphere(q, format: :svg, size: 600)

      assert is_binary(result)
      assert result =~ "width=\"600\""
    end

    test "visualizes superposition state after Hadamard" do
      q = Qx.Qubit.new() |> Qx.Qubit.h()
      result = Qx.Draw.bloch_sphere(q)

      assert is_struct(result, VegaLite) or is_binary(result)
    end
  end

  describe "state_table/2" do
    test "displays single qubit state" do
      q = Qx.Qubit.new()
      table = Qx.Draw.state_table(q)

      assert is_binary(table)
      assert table =~ "Basis State"
      assert table =~ "Amplitude"
      assert table =~ "Probability"
      assert table =~ "|0⟩"
      assert table =~ "|1⟩"
    end

    test "displays two-qubit register" do
      reg = Qx.Register.new(2)
      table = Qx.Draw.state_table(reg)

      assert is_binary(table)
      assert table =~ "|00⟩"
      assert table =~ "|01⟩"
      assert table =~ "|10⟩"
      assert table =~ "|11⟩"
    end

    test "displays Bell state" do
      reg = Qx.Register.new(2) |> Qx.Register.h(0) |> Qx.Register.cx(0, 1)
      table = Qx.Draw.state_table(reg)

      assert is_binary(table)
      assert table =~ "|00⟩"
      assert table =~ "|11⟩"
      # Both |00⟩ and |11⟩ should have ~0.5 probability
      assert table =~ "0.5"
    end

    test "hides zero amplitude states when requested" do
      reg = Qx.Register.new(2) |> Qx.Register.h(0) |> Qx.Register.cx(0, 1)
      table = Qx.Draw.state_table(reg, hide_zeros: true)

      assert is_binary(table)
      assert table =~ "|00⟩"
      assert table =~ "|11⟩"
      # |01⟩ and |10⟩ should not appear
      refute table =~ "|01⟩"
      refute table =~ "|10⟩"
    end

    test "supports HTML format" do
      reg = Qx.Register.new(2)
      table = Qx.Draw.state_table(reg, format: :html)

      assert is_binary(table)
      assert table =~ "<table"
      assert table =~ "<thead>"
      assert table =~ "<tbody>"
      assert table =~ "</table>"
    end

    test "supports custom precision" do
      reg = Qx.Register.new(2) |> Qx.Register.h(0)
      table = Qx.Draw.state_table(reg, precision: 5)

      assert is_binary(table)
      # Should have more decimal places
      assert table =~ ~r/\d+\.\d{5}/
    end

    test "works with three-qubit register" do
      reg = Qx.Register.new(3)
      table = Qx.Draw.state_table(reg)

      assert is_binary(table)
      assert table =~ "|000⟩"
      assert table =~ "|111⟩"
    end

    test "supports markdown format" do
      reg = Qx.Register.new(2)
      result = Qx.Draw.state_table(reg, format: :markdown)

      # Should return markdown string (Kino not available in tests)
      assert is_binary(result)
      assert result =~ "| Basis State | Amplitude | Probability |"
      assert result =~ "|-------------|-----------|-------------|"
      # Pipes in basis states should be escaped
      assert result =~ "| \\|00⟩"
      assert result =~ "| \\|11⟩"
    end

    test "auto format defaults to text when Kino not available" do
      reg = Qx.Register.new(2)
      result = Qx.Draw.state_table(reg, format: :auto)

      # Should return text format in test environment
      assert is_binary(result)
      assert result =~ "Basis State | Amplitude"
    end
  end

  describe "Qx.draw_bloch/2" do
    test "is accessible from main Qx module" do
      q = Qx.Qubit.new()
      result = Qx.draw_bloch(q)

      assert is_struct(result, VegaLite) or is_binary(result)
    end
  end

  describe "Qx.draw_state/2" do
    test "is accessible from main Qx module" do
      reg = Qx.Register.new(2)
      table = Qx.draw_state(reg)

      assert is_binary(table)
      assert table =~ "Basis State"
    end
  end
end
