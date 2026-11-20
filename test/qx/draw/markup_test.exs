defmodule Qx.Draw.SVG.MarkupTest do
  use ExUnit.Case, async: true

  alias Qx.Draw.SVG.Markup
  alias Qx.Draw.Theme

  @pi :math.pi()

  defp plain(markup), do: String.replace(markup, ~r/<[^>]+>/, "")

  describe "escape/1" do
    test "escapes the five XML special characters" do
      assert Markup.escape(~s(a <b> & "c" 'd')) ==
               "a &lt;b&gt; &amp; &quot;c&quot; &#39;d&#39;"
    end

    test "leaves other text, including non-ASCII, as it is" do
      assert Markup.escape("θ = 0.50π |0⟩ S†") == "θ = 0.50π |0⟩ S†"
    end

    test "accepts anything that implements String.Chars" do
      assert Markup.escape(42) == "42"
      assert Markup.escape(:"<a>") == "&lt;a&gt;"
    end
  end

  describe "num/1" do
    test "one decimal at most, whole numbers without a decimal point" do
      assert Markup.num(54) == "54"
      assert Markup.num(54.0) == "54"
      assert Markup.num(190.5) == "190.5"
      assert Markup.num(57.123) == "57.1"
      assert Markup.num(57.16) == "57.2"
      assert Markup.num(-3.25) in ["-3.2", "-3.3"]
    end

    test "more decimals on request, without trailing zeros" do
      assert Markup.num(0.88, 2) == "0.88"
      assert Markup.num(1.2, 2) == "1.2"
      assert Markup.num(1.0, 2) == "1"
      assert Markup.num(1.756, 2) == "1.76"
      assert Markup.num(-0.004, 2) == "0"
      assert Markup.num(100.0) == "100"
      assert Markup.num(7, 2) == "7"
    end

    test "never uses exponent form and never prints negative zero" do
      assert Markup.num(1.0e-9) == "0"
      assert Markup.num(-1.0e-9) == "0"
      assert Markup.num(-0.04) == "0"
      assert Markup.num(1.0e7) == "10000000"
      refute Markup.num(123_456_789.123) =~ "e"
    end
  end

  describe "angle/1" do
    test "zero and whole multiples of π" do
      assert Markup.angle(0) == "0"
      assert Markup.angle(0.0004) == "0"
      assert Markup.angle(@pi) == "π"
      assert Markup.angle(2 * @pi) == "2π"
      assert Markup.angle(-@pi) == "−π"
    end

    test "fractions of π with denominators 2, 3, 4, 6, 8, 12 and 16" do
      assert Markup.angle(@pi / 2) == "π/2"
      assert Markup.angle(@pi / 3) == "π/3"
      assert Markup.angle(3 * @pi / 4) == "3π/4"
      assert Markup.angle(5 * @pi / 6) == "5π/6"
      assert Markup.angle(-@pi / 8) == "−π/8"
      assert Markup.angle(7 * @pi / 12) == "7π/12"
      assert Markup.angle(@pi / 16) == "π/16"
      assert Markup.angle(3 * @pi / 2) == "3π/2"
    end

    test "a fraction is shown in lowest terms" do
      assert Markup.angle(2 * @pi / 4) == "π/2"
      assert Markup.angle(4 * @pi / 16) == "π/4"
    end

    test "the tolerance is 0.001" do
      assert Markup.angle(@pi / 2 + 0.0009) == "π/2"
      assert Markup.angle(@pi / 2 + 0.002) == "1.57"
    end

    test "anything else is two decimals, with a true minus sign" do
      assert Markup.angle(0.3) == "0.30"
      assert Markup.angle(1.0) == "1.00"
      assert Markup.angle(-1.234) == "−1.23"
      assert Markup.angle(@pi / 5) == "0.63"
      assert Markup.angle(@pi / 7) == "0.45"
    end

    test "beyond 2π is two decimals" do
      assert Markup.angle(3 * @pi) == "9.42"
      assert Markup.angle(-5 * @pi / 2) == "−7.85"
    end

    test "a value that is not a number is shown as θ" do
      assert Markup.angle(:theta) == "θ"
      assert Markup.angle(nil) == "θ"
    end
  end

  describe "math_label/2" do
    test "a letter is italic" do
      assert Markup.math_label([{:italic, "H"}]) == ~s(<tspan font-style="italic">H</tspan>)
    end

    test "a dagger is an upright superscript at 72% size" do
      assert Markup.math_label([{:italic, "S"}, {:sup, "†"}]) ==
               ~s(<tspan font-style="italic">S</tspan>) <>
                 ~s(<tspan dy="-5.4" font-size="10.8">†</tspan>)
    end

    test "Rx(π/2): italic letter, italic subscript, upright brackets and angle" do
      label = Markup.math_label([{:italic, "R"}, {:sub_italic, "x"}, {:upright, "(π/2)"}])

      assert label ==
               ~s(<tspan font-style="italic">R</tspan>) <>
                 ~s(<tspan dy="4.2" font-style="italic" font-size="10.8">x</tspan>) <>
                 ~s(<tspan dy="-4.2">(π/2\)</tspan>)

      assert plain(label) == "Rx(π/2)"
    end

    test "U with three real angles" do
      angles = Enum.map_join([@pi / 2, 0.3, -@pi / 4], ", ", &Markup.angle/1)
      label = Markup.math_label([{:italic, "U"}, {:upright, "(" <> angles <> ")"}])

      assert label ==
               ~s(<tspan font-style="italic">U</tspan><tspan>(π/2, 0.30, −π/4\)</tspan>)
    end

    test "q with an upright subscript index" do
      assert Markup.math_label([{:italic, "q"}, {:sub, "12"}]) ==
               ~s(<tspan font-style="italic">q</tspan><tspan dy="4.2" font-size="10.8">12</tspan>)
    end

    test "the baseline returns after a subscript, and offsets scale with the size" do
      label = Markup.math_label([{:italic, "c"}, {:sub, "1"}, {:upright, " = 1"}], 11)

      assert label ==
               ~s(<tspan font-style="italic">c</tspan>) <>
                 ~s(<tspan dy="3.1" font-size="7.9">1</tspan>) <>
                 ~s(<tspan dy="-3.1"> = 1</tspan>)
    end

    test "text is escaped" do
      assert Markup.math_label([{:upright, "a<b"}]) == "<tspan>a&lt;b</tspan>"
    end
  end

  describe "text/4" do
    test "builds a text element in a voice" do
      text = Markup.text(82, 57.1, [{:italic, "H"}], anchor: "middle", fill: "#16181D")

      assert text ==
               ~s(<text x="82" y="57.1" text-anchor="middle" font-family="#{Theme.font(:math)}" ) <>
                 ~s(font-size="15" fill="#16181D"><tspan font-style="italic">H</tspan></text>)
    end

    test "a binary is escaped and set as it is, with optional weight" do
      text =
        Markup.text(24, 18, "a <b>",
          voice: :sans,
          size: 13,
          weight: 600,
          fill: "#16181D"
        )

      assert text =~ ~s(font-family="#{Theme.font(:sans)}")
      assert text =~ ~s(font-size="13" font-weight="600" fill="#16181D">a &lt;b&gt;</text>)
      refute text =~ "text-anchor"
    end
  end

  describe "label_width/2 and box_width/3" do
    # The guide's box widths at 15px: H 32, P(π/4) 56, Rx(π/2) 64,
    # U(θ, φ, λ) 84; and the iSWAP box at 13px, 56.
    test "a single letter fits the minimum 32 box" do
      assert Markup.box_width([{:italic, "H"}], 15) == 32

      for letter <- ~w(X Y Z S T) do
        assert Markup.box_width([{:italic, letter}], 15) == 32
      end

      assert Markup.box_width([{:italic, "S"}, {:sup, "†"}], 15) == 32
    end

    test "measured labels reproduce the guide's box widths" do
      assert Markup.box_width([{:italic, "P"}, {:upright, "(π/4)"}], 15) == 56

      assert Markup.box_width([{:italic, "R"}, {:sub_italic, "x"}, {:upright, "(π/2)"}], 15) ==
               64

      assert Markup.box_width([{:italic, "U"}, {:upright, "(θ, φ, λ)"}], 15) == 84
      assert Markup.box_width([{:italic, "i"}, {:upright, "SWAP"}], 13) == 56
    end

    test "a minimum width holds a short label in its kind's slot" do
      # The guide draws P(λ) in the same 56 box as P(π/2), and Rx(θ) in the
      # same 64 box as Rx(π/2): the slot is per kind, the label only widens it.
      assert Markup.box_width([{:italic, "P"}, {:upright, "(λ)"}], 15, 56) == 56

      assert Markup.box_width([{:italic, "R"}, {:sub_italic, "x"}, {:upright, "(θ)"}], 15, 64) ==
               64
    end

    test "a long label widens the box past its minimum, keeping 8 either side" do
      segments = [{:italic, "U"}, {:upright, "(−7π/16, −1.23, −3π/16)"}]
      width = Markup.box_width(segments, 15, 84)

      assert width > 84
      assert rem(width, 4) == 0
      assert width >= Markup.label_width(segments, 15) + 16
    end

    test "width grows with the text and with the size" do
      short = Markup.label_width([{:upright, "(π)"}], 15)
      long = Markup.label_width([{:upright, "(3π/16)"}], 15)
      assert long > short
      assert Markup.label_width([{:upright, "(π)"}], 30) == 2 * short
    end

    test "subscripts and superscripts count at 72%" do
      base = Markup.label_width([{:upright, "0"}], 15)
      assert_in_delta Markup.label_width([{:sub, "0"}], 15), 0.72 * base, 1.0e-6
      assert_in_delta Markup.label_width([{:sup, "0"}], 15), 0.72 * base, 1.0e-6
    end
  end

  describe "review follow-ups" do
    test "an angle that rounds to zero is shown as 0, without a sign" do
      assert Markup.angle(0.002) == "0"
      assert Markup.angle(-0.002) == "0"
      assert Markup.angle(-0.0049) == "0"
      assert Markup.angle(0.006) == "0.01"
      assert Markup.angle(-0.006) == "−0.01"
    end

    test "escape/1 leaves out characters XML does not allow" do
      assert Markup.escape("a" <> <<0>> <> "b") == "ab"
      assert Markup.escape("a" <> <<0x1B>> <> "b" <> <<0x7>>) == "ab"
      assert Markup.escape("a\tb\nc\rd") == "a\tb\nc\rd"
      assert Markup.escape("π|0⟩ 😀") == "π|0⟩ 😀"
    end

    test "escape/1 leaves out bytes that are not UTF-8" do
      assert Markup.escape("a" <> <<0xFF>> <> "b") == "ab"
    end
  end
end
