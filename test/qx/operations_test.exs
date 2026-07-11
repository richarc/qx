defmodule Qx.OperationsTest do
  use ExUnit.Case, async: true

  # Wire up the module's doctests — Qx.Operations had no `doctest` directive,
  # so its @doc examples (sdg, t, tdg, …) were never executed. Opt-in per
  # module: without this line they render in `mix docs` but never run.
  #
  # `:except` skips PRE-EXISTING broken doctests (they rely on IO.inspect
  # side-output / `%Qx.QuantumCircuit{...}` ellipsis and have never actually
  # run). Fixing them is out of scope for the tdg/qasm-facade branch and is
  # recorded as discovered work (ROADMAP / scratchpad). Do NOT let this except
  # list grow — new doctests must pass.
  doctest Qx.Operations,
    except: [tap_circuit: 2, tap_state: 2, tap_probabilities: 2, c_if: 4]

  alias Qx.{Math, Operations, QuantumCircuit}

  describe "tdg/2" do
    test "emits a single {:tdg, [q], []} instruction" do
      qc = QuantumCircuit.new(1, 0) |> Operations.tdg(0)
      assert QuantumCircuit.get_instructions(qc) == [{:tdg, [0], []}]
    end

    test "appends onto an offset circuit at the chosen qubit" do
      qc = QuantumCircuit.new(3, 0) |> Operations.h(1) |> Operations.tdg(2)

      assert QuantumCircuit.get_instructions(qc) == [
               {:h, [1], []},
               {:tdg, [2], []}
             ]
    end

    test "out-of-range qubit raises Qx.QubitIndexError (Iron Law #7)" do
      qc = QuantumCircuit.new(1, 0)

      assert_raise Qx.QubitIndexError, ~r/out of range/, fn ->
        Operations.tdg(qc, 3)
      end
    end

    test "Qx.tdg/2 facade delegates to Operations.tdg/2" do
      base = QuantumCircuit.new(2, 0)
      assert Qx.tdg(base, 1) == Operations.tdg(base, 1)
    end
  end

  describe "tdg execution (Iron Law #9 — dispatched by run/2 and steps/2)" do
    test "t then tdg is the identity (returns |+⟩ unchanged) via run/2" do
      base = QuantumCircuit.new(1, 0) |> Operations.h(0)

      ref = base |> Qx.run() |> Map.fetch!(:probabilities) |> Nx.to_flat_list()

      out =
        base
        |> Operations.t(0)
        |> Operations.tdg(0)
        |> Qx.run()
        |> Map.fetch!(:probabilities)
        |> Nx.to_flat_list()

      Enum.zip(ref, out) |> Enum.each(fn {r, o} -> assert_in_delta r, o, 1.0e-6 end)
    end

    test "tdg applies the exact same state as phase(-π/4) via run/2" do
      base = QuantumCircuit.new(1, 0) |> Operations.h(0)

      via_tdg = base |> Operations.tdg(0) |> Qx.run() |> Map.fetch!(:state)
      via_phase = base |> Operations.phase(0, -:math.pi() / 4) |> Qx.run() |> Map.fetch!(:state)

      max_diff =
        via_tdg
        |> Nx.subtract(via_phase)
        |> Nx.abs()
        |> Nx.reduce_max()
        |> Nx.to_number()

      assert max_diff < 1.0e-6
    end

    test ":tdg is dispatched by steps/2 without raising unsupported_gate" do
      qc = QuantumCircuit.new(1, 0) |> Operations.h(0) |> Operations.tdg(0)

      # Materialising the stream would raise Qx.GateError {:unsupported_gate, :tdg}
      # if the simulation dispatch lacked a :tdg arm.
      steps = Qx.steps(qc) |> Enum.to_list()
      refute steps == []

      final_probs = List.last(steps).state |> Math.probabilities() |> Nx.to_flat_list()
      run_probs = Qx.run(qc) |> Map.fetch!(:probabilities) |> Nx.to_flat_list()

      Enum.zip(final_probs, run_probs)
      |> Enum.each(fn {s, r} -> assert_in_delta s, r, 1.0e-6 end)
    end
  end
end
