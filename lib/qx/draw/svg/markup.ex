defmodule Qx.Draw.SVG.Markup do
  @moduledoc false

  # Internal: the text and number helpers shared by the SVG renderers.
  #
  # A label is a list of segments in the guide's mathematics voice:
  #
  #   {:italic, "R"}      a letter
  #   {:upright, "(π/2)"} digits, brackets, π
  #   {:sub, "0"}         an upright subscript at 72% size
  #   {:sub_italic, "x"}  an italic subscript at 72% size
  #   {:sup, "†"}         an upright superscript at 72% size

  alias Qx.Draw.Theme

  @small 0.72
  @sub_dy 0.28
  @sup_dy 0.36

  # Fractions of π an angle is shown as, when it is within @angle_tolerance.
  @denominators [1, 2, 3, 4, 6, 8, 12, 16]
  @angle_tolerance 0.001
  @minus "−"

  # Advance widths in em. SVG output cannot measure text and the reader's
  # font is one of several in a stack, so these are sized for the widest
  # face in the mathematics stack; a box sized from them does not clip in
  # the narrower ones.
  @advances %{
    "H" => 0.76,
    "X" => 0.66,
    "Y" => 0.62,
    "Z" => 0.62,
    "S" => 0.56,
    "T" => 0.60,
    "P" => 0.62,
    "R" => 0.64,
    "U" => 0.80,
    "W" => 0.90,
    "A" => 0.68,
    "M" => 0.90,
    "I" => 0.40,
    "i" => 0.30,
    "x" => 0.48,
    "y" => 0.46,
    "z" => 0.42,
    "c" => 0.44,
    "(" => 0.34,
    ")" => 0.34,
    "/" => 0.30,
    "," => 0.28,
    " " => 0.28,
    "." => 0.26,
    "|" => 0.24,
    "⟩" => 0.40,
    "π" => 0.56,
    "θ" => 0.56,
    "φ" => 0.66,
    "λ" => 0.56,
    "†" => 0.50,
    "−" => 0.62,
    "-" => 0.36,
    "+" => 0.62,
    "=" => 0.62
  }

  @doc """
  Escapes text for use in XML content or a double-quoted attribute. Bytes
  that are not UTF-8 and characters XML 1.0 does not allow (the control
  characters other than tab, line feed and carriage return) are left out:
  no escape exists for them, and one of them makes the whole image
  unreadable.
  """
  def escape(text) do
    text
    |> to_string()
    |> String.replace_invalid("")
    |> String.replace(
      ~r/[^\x{9}\x{A}\x{D}\x{20}-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]/u,
      ""
    )
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  @doc """
  Formats a number for an attribute: at most `decimals` decimals (one by
  default), no exponent form, no trailing zeros, and a whole number
  without a decimal point.
  """
  def num(value, decimals \\ 1)

  def num(value, _decimals) when is_integer(value), do: Integer.to_string(value)

  def num(value, decimals) when is_float(value) do
    formatted = :erlang.float_to_binary(value, decimals: decimals)

    trimmed =
      if String.contains?(formatted, "."),
        do: formatted |> String.trim_trailing("0") |> String.trim_trailing("."),
        else: formatted

    if trimmed == "-0", do: "0", else: trimmed
  end

  @doc """
  Formats an angle in radians: a fraction of π when it is within 0.001 of
  one (denominators 1, 2, 3, 4, 6, 8, 12 and 16, up to 2π either way),
  otherwise two decimals; a value that rounds to zero is shown as 0. A
  value that is not a number is shown as θ.
  """
  def angle(value) when is_number(value) do
    if abs(value) < @angle_tolerance do
      "0"
    else
      case pi_fraction(value) do
        {numerator, denominator} -> format_fraction(numerator, denominator)
        nil -> format_decimal(value)
      end
    end
  end

  def angle(_value), do: "θ"

  # The lowest-terms fraction n/d with value ≈ nπ/d, or nil. Denominators
  # are tried smallest first, so the first match is in lowest terms.
  # Nothing beyond 2π is a fraction, and a very large value would overflow
  # the arithmetic below.
  defp pi_fraction(value) when abs(value) > 7, do: nil

  defp pi_fraction(value) do
    ratio = value / :math.pi()

    Enum.find_value(@denominators, fn denominator ->
      numerator = round(ratio * denominator)

      if numerator != 0 and abs(numerator) <= 2 * denominator and
           abs(value - numerator * :math.pi() / denominator) < @angle_tolerance do
        {numerator, denominator}
      end
    end)
  end

  defp format_fraction(numerator, denominator) do
    sign = if numerator < 0, do: @minus, else: ""
    count = if abs(numerator) == 1, do: "", else: Integer.to_string(abs(numerator))
    over = if denominator == 1, do: "", else: "/#{denominator}"
    sign <> count <> "π" <> over
  end

  defp format_decimal(value) do
    case :erlang.float_to_binary(abs(value) * 1.0, decimals: 2) do
      "0.00" -> "0"
      text when value < 0 -> @minus <> text
      text -> text
    end
  end

  @doc """
  Builds the `tspan` markup of a label at a font size. Subscripts and
  superscripts are set at 72% size and shifted with `dy`; the baseline
  returns on the next full-size segment.
  """
  def math_label(segments, size \\ 15) do
    {markup, _shift} =
      Enum.map_reduce(segments, 0.0, fn {kind, text}, shift ->
        target = baseline_shift(kind, size)
        {tspan(kind, text, target - shift, size), target}
      end)

    IO.iodata_to_binary(markup)
  end

  defp baseline_shift(kind, size) when kind in [:sub, :sub_italic], do: @sub_dy * size
  defp baseline_shift(:sup, size), do: -@sup_dy * size
  defp baseline_shift(_kind, _size), do: 0.0

  defp tspan(kind, text, dy, size) do
    dy_attr = if abs(dy) < 0.05, do: "", else: ~s( dy="#{num(dy)}")
    style_attr = if kind in [:italic, :sub_italic], do: ~s( font-style="italic"), else: ""

    size_attr =
      if kind in [:sub, :sub_italic, :sup],
        do: ~s( font-size="#{num(@small * size)}"),
        else: ""

    ["<tspan", dy_attr, style_attr, size_attr, ">", escape(text), "</tspan>"]
  end

  @doc """
  Builds a `text` element. `content` is a list of label segments, or a
  binary set as it is.

  Options: `:voice` (`:math`, `:sans` or `:mono`; default `:math`), `:size`
  (default 15), `:fill` (default ink), `:anchor`, `:weight`, and `:extra`
  for further attributes, already formatted.
  """
  def text(x, y, content, opts \\ []) do
    size = Keyword.get(opts, :size, 15)
    fill = Keyword.get(opts, :fill, Theme.color(:ink))
    voice = Keyword.get(opts, :voice, :math)

    anchor =
      case Keyword.get(opts, :anchor) do
        nil -> ""
        anchor -> ~s( text-anchor="#{anchor}")
      end

    weight =
      case Keyword.get(opts, :weight) do
        nil -> ""
        weight -> ~s( font-weight="#{weight}")
      end

    extra =
      case Keyword.get(opts, :extra) do
        nil -> ""
        extra -> " " <> extra
      end

    body = if is_binary(content), do: escape(content), else: math_label(content, size)

    ~s(<text x="#{num(x)}" y="#{num(y)}"#{anchor} font-family="#{Theme.font(voice)}" ) <>
      ~s(font-size="#{num(size)}"#{weight} fill="#{fill}"#{extra}>#{body}</text>)
  end

  @doc "Estimated width of a label at a font size, in user units."
  def label_width(segments, size) do
    Enum.reduce(segments, 0.0, fn {kind, text}, width ->
      scale = if kind in [:sub, :sub_italic, :sup], do: @small, else: 1.0
      width + text_advance(text) * scale * size
    end)
  end

  defp text_advance(text) do
    text
    |> String.graphemes()
    |> Enum.reduce(0.0, fn grapheme, sum -> sum + advance(grapheme) end)
  end

  defp advance(grapheme) do
    case @advances do
      %{^grapheme => advance} -> advance
      _ -> default_advance(grapheme)
    end
  end

  defp default_advance(<<c>>) when c in ?0..?9, do: 0.50
  defp default_advance(<<c>>) when c in ?A..?Z, do: 0.70
  defp default_advance(<<c>>) when c in ?a..?z, do: 0.50
  defp default_advance(_grapheme), do: 0.60

  @doc """
  Width of the box that holds a label: the label plus 8 either side,
  rounded up to a multiple of 4, and never under `min`.
  """
  def box_width(segments, size, min \\ 32) do
    needed = label_width(segments, size) + 16
    max(min, ceil(needed / 4) * 4)
  end
end
