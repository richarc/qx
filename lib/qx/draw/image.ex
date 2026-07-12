defmodule Qx.Draw.Image do
  @moduledoc """
  Tier 1: a core Qx type — the SVG image artifact produced by
  `Qx.draw_bloch/2` and `Qx.draw_circuit/2`.

  The struct is plain data with one static shape in every environment
  (see `spec/api-design-principles.md` §6): Livebook renders it
  through the `Kino.Render` protocol, IEx shows a compact `Inspect`
  line, and a standalone application reads the raw SVG from the
  `:svg` field (or `to_string/1`) to write a file or serve it.

  ## Fields

    * `:svg` - the complete SVG document as a binary
    * `:title` - the title the drawing was given, or `nil`

  ## Examples

      iex> image = Qx.create_circuit(1) |> Qx.h(0) |> Qx.draw_circuit()
      iex> String.starts_with?(image.svg, "<?xml") or String.contains?(image.svg, "<svg")
      true

      # Standalone: write it to a file
      # File.write!("circuit.svg", image.svg)
  """

  @enforce_keys [:svg]
  defstruct [:svg, :title]

  @type t :: %__MODULE__{svg: String.t(), title: String.t() | nil}

  defimpl String.Chars do
    def to_string(%{svg: svg}), do: svg
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{svg: svg, title: title}, _opts) do
      label = if title, do: " #{inspect(title)}", else: ""
      concat(["#Qx.Draw.Image<svg#{label}, ", "#{byte_size(svg)} bytes>"])
    end
  end

  if Code.ensure_loaded?(Kino.Render) do
    defimpl Kino.Render do
      def to_livebook(%{svg: svg}) do
        svg |> Kino.Image.new(:svg) |> Kino.Render.to_livebook()
      end
    end
  end
end
