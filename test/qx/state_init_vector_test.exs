defmodule Qx.StateInitVectorTest do
  use ExUnit.Case, async: true

  alias Qx.StateInit

  defp approx_equal?(a, b, tolerance \\ 0.01) do
    abs(a - b) < tolerance
  end

  defp probs(state), do: state |> Qx.Math.probabilities() |> Nx.to_flat_list()
  defp real_at(state, i), do: state |> Nx.real() |> Nx.to_flat_list() |> Enum.at(i)

  describe "bell_state_vector/0,1,2" do
    test "defaults to |Φ+⟩, amplitude in |00⟩ and |11⟩ both positive" do
      state = StateInit.bell_state_vector()
      p = probs(state)
      assert approx_equal?(Enum.at(p, 0), 0.5)
      assert approx_equal?(Enum.at(p, 1), 0.0)
      assert approx_equal?(Enum.at(p, 2), 0.0)
      assert approx_equal?(Enum.at(p, 3), 0.5)
      # sign distinguishes :phi_plus from :phi_minus (probability cannot)
      assert real_at(state, 3) > 0
    end

    test ":phi_minus has amplitude in |00⟩ and |11⟩, |11⟩ sign negative" do
      state = StateInit.bell_state_vector(:phi_minus)
      p = probs(state)
      assert approx_equal?(Enum.at(p, 0), 0.5)
      assert approx_equal?(Enum.at(p, 3), 0.5)
      assert approx_equal?(Enum.at(p, 1), 0.0)
      assert approx_equal?(Enum.at(p, 2), 0.0)
      assert real_at(state, 3) < 0
    end

    test ":psi_plus has amplitude in |01⟩ and |10⟩, |10⟩ sign positive" do
      state = StateInit.bell_state_vector(:psi_plus)
      p = probs(state)
      assert approx_equal?(Enum.at(p, 1), 0.5)
      assert approx_equal?(Enum.at(p, 2), 0.5)
      assert approx_equal?(Enum.at(p, 0), 0.0)
      assert approx_equal?(Enum.at(p, 3), 0.0)
      assert real_at(state, 2) > 0
    end

    test ":psi_minus has amplitude in |01⟩ and |10⟩, |10⟩ sign negative" do
      state = StateInit.bell_state_vector(:psi_minus)
      p = probs(state)
      assert approx_equal?(Enum.at(p, 1), 0.5)
      assert approx_equal?(Enum.at(p, 2), 0.5)
      assert approx_equal?(Enum.at(p, 0), 0.0)
      assert approx_equal?(Enum.at(p, 3), 0.0)
      assert real_at(state, 2) < 0
    end
  end

  describe "ghz_state_vector/1,2" do
    test "2 qubits (same as Bell)" do
      p = probs(StateInit.ghz_state_vector(2))
      assert approx_equal?(Enum.at(p, 0), 0.5)
      assert approx_equal?(Enum.at(p, 3), 0.5)
      assert approx_equal?(Enum.at(p, 1), 0.0)
      assert approx_equal?(Enum.at(p, 2), 0.0)
    end

    test "3 qubits: (|000⟩ + |111⟩)/√2" do
      p = probs(StateInit.ghz_state_vector(3))
      assert approx_equal?(Enum.at(p, 0), 0.5)
      assert approx_equal?(Enum.at(p, 7), 0.5)
      assert approx_equal?(Enum.sum(Enum.slice(p, 1..6)), 0.0)
    end

    test "4 qubits: (|0000⟩ + |1111⟩)/√2" do
      p = probs(StateInit.ghz_state_vector(4))
      assert approx_equal?(Enum.at(p, 0), 0.5)
      assert approx_equal?(Enum.at(p, 15), 0.5)
      assert approx_equal?(Enum.sum(Enum.slice(p, 1..14)), 0.0)
    end

    test "5 qubits is normalized" do
      total =
        StateInit.ghz_state_vector(5) |> Qx.Math.probabilities() |> Nx.sum() |> Nx.to_number()

      assert approx_equal?(total, 1.0, 1.0e-6)
    end
  end

  describe "tensor type parameter" do
    test "bell_state_vector honours :c128" do
      assert Nx.type(StateInit.bell_state_vector(:phi_plus, :c128)) == {:c, 128}
    end

    test "ghz_state_vector honours :c128" do
      assert Nx.type(StateInit.ghz_state_vector(3, :c128)) == {:c, 128}
    end
  end
end
