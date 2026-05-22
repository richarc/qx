defmodule Qx.OperationsBasisMeasurementTest do
  use ExUnit.Case, async: true

  alias Qx.{Operations, QuantumCircuit}

  describe "measure_z/3" do
    test "emits the same instruction as measure/3" do
      mz =
        QuantumCircuit.new(1, 1)
        |> Operations.measure_z(0, 0)
        |> QuantumCircuit.get_instructions()

      m =
        QuantumCircuit.new(1, 1)
        |> Operations.measure(0, 0)
        |> QuantumCircuit.get_instructions()

      assert mz == m
    end

    test "raises Qx.ClassicalBitError when bit OOR" do
      qc = QuantumCircuit.new(2, 1)

      assert_raise Qx.ClassicalBitError, fn ->
        Operations.measure_z(qc, 0, 5)
      end
    end
  end

  describe "measure_x/3" do
    test "expands to H ; measure (2 instructions)" do
      qc = QuantumCircuit.new(1, 1) |> Operations.measure_x(0, 0)

      assert [
               {:h, [0], []},
               {:measure, [0, 0], []}
             ] = QuantumCircuit.get_instructions(qc)
    end

    test "on |+⟩ deterministically yields classical 0" do
      # Prepare |+⟩ with H, then X-basis measure -> outcome 0 with probability 1
      result =
        QuantumCircuit.new(1, 1)
        |> Operations.h(0)
        |> Operations.measure_x(0, 0)
        |> Qx.run(shots: 100)

      counts = Map.fetch!(result, :counts)
      assert Map.get(counts, [0], 0) == 100
    end

    test "on |−⟩ deterministically yields classical 1" do
      # |−⟩ = H|1⟩ = H ; X ; |0⟩ ... actually H|0⟩ = |+⟩, X|+⟩ = |+⟩.
      # Correct prep: X then H -> H|1⟩ = |−⟩
      result =
        QuantumCircuit.new(1, 1)
        |> Operations.x(0)
        |> Operations.h(0)
        |> Operations.measure_x(0, 0)
        |> Qx.run(shots: 100)

      counts = Map.fetch!(result, :counts)
      assert Map.get(counts, [1], 0) == 100
    end

    test "on |0⟩ yields ~50/50 split" do
      result =
        QuantumCircuit.new(1, 1)
        |> Operations.measure_x(0, 0)
        |> Qx.run(shots: 1000)

      counts = Map.fetch!(result, :counts)
      zeros = Map.get(counts, [0], 0)
      ones = Map.get(counts, [1], 0)

      # within sampling tolerance
      assert zeros + ones == 1000
      assert zeros > 400 and zeros < 600
    end

    test "raises Qx.QubitIndexError on OOR qubit" do
      qc = QuantumCircuit.new(2, 2)

      assert_raise Qx.QubitIndexError, fn ->
        Operations.measure_x(qc, 5, 0)
      end
    end

    test "raises Qx.ClassicalBitError on OOR classical bit" do
      qc = QuantumCircuit.new(2, 1)

      assert_raise Qx.ClassicalBitError, fn ->
        Operations.measure_x(qc, 0, 5)
      end
    end
  end

  describe "measure_y/3" do
    test "expands to Sdg ; H ; measure (3 instructions)" do
      qc = QuantumCircuit.new(1, 1) |> Operations.measure_y(0, 0)

      assert [
               {:sdg, [0], []},
               {:h, [0], []},
               {:measure, [0, 0], []}
             ] = QuantumCircuit.get_instructions(qc)
    end

    test "on |+i⟩ deterministically yields classical 0" do
      # |+i⟩ = S|+⟩ = S ; H |0⟩
      result =
        QuantumCircuit.new(1, 1)
        |> Operations.h(0)
        |> Operations.s(0)
        |> Operations.measure_y(0, 0)
        |> Qx.run(shots: 100)

      counts = Map.fetch!(result, :counts)
      assert Map.get(counts, [0], 0) == 100
    end

    test "on |−i⟩ deterministically yields classical 1" do
      # |−i⟩ = Sdg|+⟩ ... actually |−i⟩ = S|−⟩ = S ; H ; X |0⟩
      result =
        QuantumCircuit.new(1, 1)
        |> Operations.x(0)
        |> Operations.h(0)
        |> Operations.s(0)
        |> Operations.measure_y(0, 0)
        |> Qx.run(shots: 100)

      counts = Map.fetch!(result, :counts)
      assert Map.get(counts, [1], 0) == 100
    end

    test "on |0⟩ yields ~50/50 split" do
      result =
        QuantumCircuit.new(1, 1)
        |> Operations.measure_y(0, 0)
        |> Qx.run(shots: 1000)

      counts = Map.fetch!(result, :counts)
      zeros = Map.get(counts, [0], 0)
      ones = Map.get(counts, [1], 0)

      assert zeros + ones == 1000
      assert zeros > 400 and zeros < 600
    end
  end

  describe "interop: measure_x ↔ measure_z" do
    test "z-basis measure of |0⟩ is deterministic 0" do
      result =
        QuantumCircuit.new(1, 1)
        |> Operations.measure_z(0, 0)
        |> Qx.run(shots: 100)

      counts = Map.fetch!(result, :counts)
      assert Map.get(counts, [0], 0) == 100
    end
  end
end
