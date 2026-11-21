defmodule Qx.FormatToleranceTest do
  @moduledoc """
  One answer to "is this amplitude zero for display?", in `Qx.Format`, used
  by Dirac notation, `Qx.Step` and the state table (plan:
  display-tolerance).

  Two questions are kept apart. Noise: a probability at or under 1.0e-10 is
  rounding residue and is never shown. Presentation: in a one-line Dirac
  string a term whose amplitude prints as all zeros is left out, unless
  every term would be.
  """
  use ExUnit.Case, async: true

  alias Complex, as: C
  alias Qx.{Format, Step}

  defp term(basis, re, im \\ 0.0) do
    {basis, C.new(re, im), re * re + im * im}
  end

  defp step(amplitudes) do
    state = Nx.tensor(amplitudes, type: :c64)

    %Step{
      kind: :gate,
      operation: {:h, [0], []},
      index: 0,
      state: state,
      probabilities: Qx.Math.probabilities(state)
    }
  end

  describe "the evidence the noise floor rests on" do
    # U then U⁻¹ leaves |0…0⟩ exactly; whatever sits on the other basis
    # states is float32 rounding residue. Measured up to 1,740 gates and 14
    # qubits the largest was 2.3e-13 (see the plan's scratchpad). The
    # circuits here are short: in the test environment a longer one trips
    # the simulator's norm-drift assertion, which is a separate matter.
    for {qubits, depth} <- [{2, 10}, {6, 10}] do
      test "residue after #{depth} layers and their inverse on #{qubits} qubits is far below the floor" do
        n = unquote(qubits)
        depth = unquote(depth)

        forward =
          Enum.reduce(1..depth, Qx.create_circuit(n), fn k, circuit ->
            circuit =
              Enum.reduce(0..(n - 1), circuit, fn q, c ->
                c |> Qx.ry(q, 0.3 + 0.07 * q + 0.01 * k) |> Qx.rz(q, 0.2 + 0.05 * k)
              end)

            Enum.reduce(0..(n - 2)//1, circuit, fn q, c -> Qx.cx(c, q, q + 1) end)
          end)

        both =
          Enum.reduce(depth..1//-1, forward, fn k, circuit ->
            circuit = Enum.reduce((n - 2)..0//-1, circuit, fn q, c -> Qx.cx(c, q, q + 1) end)

            Enum.reduce((n - 1)..0//-1, circuit, fn q, c ->
              c |> Qx.rz(q, -(0.2 + 0.05 * k)) |> Qx.ry(q, -(0.3 + 0.07 * q + 0.01 * k))
            end)
          end)

        [_zero_state | residue] = both |> Qx.get_probabilities() |> Nx.to_flat_list()

        assert Enum.max(residue) < 1.0e-11
        assert Enum.all?(residue, &Format.negligible?/1)
      end
    end

    test "the smallest uniform probability Qx supports is far above the floor" do
      refute Format.negligible?(1 / Integer.pow(2, 20))
    end
  end

  describe "negligible?/1" do
    test "rounding residue is negligible" do
      assert Format.negligible?(0.0)
      assert Format.negligible?(2.3e-13)
      assert Format.negligible?(1.0e-11)
      assert Format.negligible?(1.0e-10)
    end

    test "a probability that is not finite is not residue" do
      refute Format.negligible?(:nan)
      refute Format.negligible?(:infinity)
    end

    test "a real probability is not, however small" do
      refute Format.negligible?(1.1e-10)
      refute Format.negligible?(1.0e-9)
      refute Format.negligible?(9.5e-7)
      refute Format.negligible?(1.0)
    end
  end

  describe "significant_terms/2" do
    test "leaves out noise" do
      terms = [term("|0⟩", 1.0), term("|1⟩", 1.0e-7)]
      assert {[{"|0⟩", _, _}], false} = Format.significant_terms(terms)
    end

    test "leaves out a term that prints as 0.000 when another term prints" do
      terms = [term("|0⟩", 1.0), term("|1⟩", 4.0e-4)]
      assert {[{"|0⟩", _, _}], false} = Format.significant_terms(terms)
    end

    test "the boundary: an amplitude of exactly half a unit prints, and is kept" do
      # 0.0005 prints as 0.001 at three decimals.
      at = [term("|0⟩", 1.0), term("|1⟩", 5.0e-4)]
      assert {[_, {"|1⟩", _, _}], false} = Format.significant_terms(at)
      assert Format.dirac_notation(at) == "1.000|0⟩ + 0.001|1⟩"

      under = [term("|0⟩", 1.0), term("|1⟩", 4.999e-4)]
      assert {[_], false} = Format.significant_terms(under)
    end

    test "keeps a term that prints as 0.001" do
      terms = [term("|0⟩", 1.0), term("|1⟩", 6.0e-4)]
      assert {[{"|0⟩", _, _}, {"|1⟩", _, _}], false} = Format.significant_terms(terms)
    end

    test "judges a complex amplitude by its parts" do
      prints = [term("|0⟩", 1.0), term("|1⟩", 0.0, -6.0e-4)]
      assert {[_, {"|1⟩", _, _}], false} = Format.significant_terms(prints)

      # |amplitude| is 5.7e-4, but both parts print as 0.000.
      zeros = [term("|0⟩", 1.0), term("|1⟩", 4.0e-4, 4.0e-4)]
      assert {[{"|0⟩", _, _}], false} = Format.significant_terms(zeros)
    end

    test "a higher precision keeps what a lower one leaves out" do
      terms = [term("|0⟩", 1.0), term("|1⟩", 4.0e-4)]

      assert {[_], false} = Format.significant_terms(terms, precision: 3)
      assert {[_, {"|1⟩", _, _}], false} = Format.significant_terms(terms, precision: 5)
    end

    test "a wide uniform state keeps every term" do
      # The 20-qubit uniform regime in miniature: probability 8.1e-7 each,
      # printed 0.001.
      terms = for basis <- ["|00⟩", "|01⟩", "|10⟩", "|11⟩"], do: term(basis, 9.0e-4)
      assert {kept, false} = Format.significant_terms(terms)
      assert Enum.map(kept, &elem(&1, 0)) == ["|00⟩", "|01⟩", "|10⟩", "|11⟩"]
    end

    test "when every term would print as zero, the largest are kept, in index order" do
      terms = [
        term("|000⟩", 1.0e-4),
        term("|001⟩", 4.0e-4),
        term("|010⟩", 2.0e-4),
        term("|011⟩", 3.0e-4),
        term("|100⟩", 3.5e-4),
        term("|101⟩", 1.0e-7)
      ]

      assert {kept, true} = Format.significant_terms(terms)
      assert Enum.map(kept, &elem(&1, 0)) == ["|001⟩", "|010⟩", "|011⟩", "|100⟩"]
    end

    test "the largest-terms fallback respects a :max under four" do
      terms = [
        term("|00⟩", 1.0e-4),
        term("|01⟩", 4.0e-4),
        term("|10⟩", 2.0e-4),
        term("|11⟩", 3.0e-4)
      ]

      assert {kept, true} = Format.significant_terms(terms, max: 2)
      assert Enum.map(kept, &elem(&1, 0)) == ["|01⟩", "|11⟩"]
    end

    test "a zero vector keeps its first term" do
      terms = [term("|0⟩", 0.0), term("|1⟩", 0.0)]
      assert {[{"|0⟩", _, _}], false} = Format.significant_terms(terms)
      assert Format.dirac_notation(terms) == "0.000|0⟩"
    end

    test "no terms give no terms" do
      assert Format.significant_terms([]) == {[], false}
      assert Format.dirac_notation([]) == ""
    end

    test ":max limits the terms and reports the cut" do
      terms = for basis <- ["|00⟩", "|01⟩", "|10⟩", "|11⟩"], do: term(basis, 0.5)

      assert {kept, true} = Format.significant_terms(terms, max: 2)
      assert Enum.map(kept, &elem(&1, 0)) == ["|00⟩", "|01⟩"]
      assert {[_, _, _, _], false} = Format.significant_terms(terms, max: 4)
    end
  end

  describe "dirac_notation/2" do
    test "a wide uniform state prints its terms, not 0.000|0…0⟩" do
      terms = for basis <- ["|00⟩", "|01⟩", "|10⟩", "|11⟩"], do: term(basis, 9.0e-4)

      assert Format.dirac_notation(terms) ==
               "0.001|00⟩ + 0.001|01⟩ + 0.001|10⟩ + 0.001|11⟩"
    end

    test "an imaginary part at the level of rounding residue is not printed" do
      assert Format.dirac_notation([term("|0⟩", 1.0, 5.0e-6)]) == "1.000|0⟩"
    end

    test "a real imaginary part is printed" do
      assert Format.dirac_notation([term("|0⟩", 1.0, 5.0e-4)]) == "(1.000+0.001i)|0⟩"
    end

    test "has no :threshold option" do
      terms = [term("|0⟩", 0.999), term("|1⟩", 0.045)]
      assert Format.dirac_notation(terms, threshold: 0.01) == "0.999|0⟩ + 0.045|1⟩"
    end
  end

  describe "Qx.Step.show/1" do
    test "a wide uniform state is not shown as 0.000|00⟩" do
      shown = Step.show(step(List.duplicate(C.new(9.0e-4, 0.0), 4)))

      refute shown.state =~ "0.000|00"
      assert shown.state == "0.001|00⟩ + 0.001|01⟩ + 0.001|10⟩ + 0.001|11⟩"
    end
  end

  describe "the three surfaces agree" do
    test "a basis state holding only rounding residue is left out everywhere" do
      amplitudes = [C.new(1.0, 0.0), C.new(0.0, 1.0e-7), C.new(0.0, 0.0), C.new(0.0, 0.0)]
      step = step(amplitudes)

      assert Step.show(step).state == "1.000|00⟩"
      assert inspect(step) =~ "1.000|00⟩>"
      refute inspect(step) =~ "|01⟩"

      table = Qx.draw_state(step.state, hide_zeros: true)
      assert table.text =~ "|00⟩"
      refute table.text =~ "|01⟩"
    end

    test "a small real amplitude is kept everywhere" do
      # Probability 3.6e-7: under the old 1.0e-6 cut of Dirac notation, above
      # the floor.
      amplitudes = [C.new(1.0, 0.0), C.new(6.0e-4, 0.0)]
      step = step(amplitudes)

      assert Step.show(step).state == "1.000|0⟩ + 0.001|1⟩"
      assert inspect(step) =~ "1.000|0⟩ + 0.001|1⟩"
      assert Qx.draw_state(step.state, hide_zeros: true).text =~ "|1⟩"
    end
  end

  describe "one definition" do
    test "Qx.Step and the state table hold no display threshold of their own" do
      for file <- ["lib/qx/step.ex", "lib/qx/draw/tables.ex"] do
        source = File.read!(Path.expand("../../" <> file, __DIR__))

        # Neither file has any reason to hold a small float literal.
        refute source =~ ~r/\d\.\d+e-\d+|threshold/i,
               "#{file} has a threshold of its own; use Qx.Format.negligible?/1 or significant_terms/2"
      end
    end
  end
end
