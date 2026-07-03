defmodule Qx.CalcModeInternalTest do
  use ExUnit.Case, async: true

  # Calc mode is demoted to an internal engine (v0.10): both modules are
  # hidden from docs but MUST keep working — the non-breaking guarantee.

  describe "hidden from documentation" do
    test "Qx.Register moduledoc is hidden" do
      assert {:docs_v1, _, :elixir, _, :hidden, _, _} = Code.fetch_docs(Qx.Register)
    end

    test "Qx.Qubit moduledoc is hidden" do
      assert {:docs_v1, _, :elixir, _, :hidden, _, _} = Code.fetch_docs(Qx.Qubit)
    end
  end

  describe "still fully functional" do
    test "Qx.Register.new/1 |> h/2 evolves the state" do
      reg = Qx.Register.new(2) |> Qx.Register.h(0)

      probs = Qx.Register.get_probabilities(reg) |> Nx.to_flat_list()

      assert_in_delta Enum.at(probs, 0), 0.5, 1.0e-6
      assert_in_delta Enum.at(probs, 2), 0.5, 1.0e-6
    end

    test "Qx.Qubit.new/0 |> h/1 superposes" do
      q = Qx.Qubit.new() |> Qx.Qubit.h()

      [p0, p1] = Qx.Qubit.measure_probabilities(q) |> Nx.to_flat_list()

      assert_in_delta p0, 0.5, 1.0e-6
      assert_in_delta p1, 0.5, 1.0e-6
    end
  end
end
