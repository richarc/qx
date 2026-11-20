defmodule Qx.Test.SVGText do
  @moduledoc false

  # A label in a drawing is one `text` element holding several `tspan`s
  # (a subscript, a dagger), so the label a reader sees is the element's
  # text with the markup taken out.

  @doc "The plain text of every `text` element in an SVG string."
  def labels(svg) do
    ~r/<text\b[^>]*>(.*?)<\/text>/s
    |> Regex.scan(svg, capture: :all_but_first)
    |> Enum.map(fn [body] -> String.replace(body, ~r/<[^>]+>/, "") end)
  end
end
