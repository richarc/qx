defmodule Qx.QuantumCircuitStateTest do
  use ExUnit.Case, async: true

  # Wire up the module's doctests — Qx.QuantumCircuit had no `doctest` directive,
  # so its @doc examples were never executed (opt-in per module).
  doctest Qx.QuantumCircuit

  alias Qx.QuantumCircuit

  describe "initial_state/1" do
    test "returns the |0…0⟩ initial state vector of shape {2^n}" do
      state = QuantumCircuit.initial_state(QuantumCircuit.new(2))

      assert Nx.shape(state) == {4}
      # Independent reference: a fresh circuit starts in |00⟩ = [1, 0, 0, 0].
      assert Nx.to_flat_list(Nx.abs(state)) == [1.0, 0.0, 0.0, 0.0]
    end

    test "the deprecated get_state/1 still returns the |0…0⟩ initial state" do
      amps =
        QuantumCircuit.new(2)
        |> QuantumCircuit.get_state()
        |> Nx.abs()
        |> Nx.to_flat_list()

      assert amps == [1.0, 0.0, 0.0, 0.0]
    end
  end
end
