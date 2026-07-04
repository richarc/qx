defmodule Qx.Draw.StateTable do
  @moduledoc """
  A quantum-state table artifact produced by `Qx.draw_state/2`: every
  basis state with its amplitude and probability, pre-rendered in
  three encodings.

  The struct is plain data with one static shape in every environment
  (see `spec/api-design-principles.md` §6): Livebook renders the
  markdown through the `Kino.Render` protocol, IEx prints the text
  table via `Inspect`, and a standalone application picks the field
  it needs (`to_string/1` gives the text form).

  ## Fields

    * `:text` - monospaced plain-text table
    * `:markdown` - markdown table
    * `:html` - HTML `<table>`

  ## Examples

      iex> table = Qx.create_circuit(1) |> Qx.h(0) |> Qx.get_state() |> Qx.draw_state()
      iex> table.text =~ "Basis State"
      true
      iex> table.markdown =~ "Probability"
      true
  """

  @enforce_keys [:text, :markdown, :html]
  defstruct [:text, :markdown, :html]

  @type t :: %__MODULE__{text: String.t(), markdown: String.t(), html: String.t()}

  defimpl String.Chars do
    def to_string(%{text: text}), do: text
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{text: text}, _opts) do
      concat(["#Qx.Draw.StateTable<\n", text || "", "\n>"])
    end
  end

  if Code.ensure_loaded?(Kino.Render) do
    defimpl Kino.Render do
      def to_livebook(%{markdown: markdown}) do
        markdown |> Kino.Markdown.new() |> Kino.Render.to_livebook()
      end
    end
  end
end
