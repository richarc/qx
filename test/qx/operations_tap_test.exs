defmodule Qx.OperationsTapTest do
  use ExUnit.Case, async: true

  alias Qx.Operations

  # :c64 states are complex float32 (eps ~1.2e-7); 1.0e-6 per Iron Law #8.
  @tolerance 1.0e-6

  describe "tap_state/2" do
    test "receives the state after the instructions so far, not the initial state" do
      parent = self()

      Qx.QuantumCircuit.new(1, 0)
      |> Operations.h(0)
      |> Operations.tap_state(fn state -> send(parent, {:tapped, state}) end)

      assert_receive {:tapped, state}
      amp = 1.0 / :math.sqrt(2)

      assert_in_delta Complex.abs(Nx.to_number(state[0])), amp, @tolerance
      assert_in_delta Complex.abs(Nx.to_number(state[1])), amp, @tolerance
    end

    test "returns the circuit unchanged so the pipeline continues" do
      circuit = Qx.QuantumCircuit.new(2, 0) |> Operations.h(0)

      tapped = Operations.tap_state(circuit, fn _state -> :ignored end)

      assert tapped == circuit
    end

    test "raises Qx.MeasurementError when the circuit so far contains a measurement" do
      circuit =
        Qx.QuantumCircuit.new(1, 1)
        |> Operations.h(0)
        |> Operations.measure(0, 0)

      assert_raise Qx.MeasurementError, fn ->
        Operations.tap_state(circuit, fn _state -> :ignored end)
      end
    end

    test "raises Qx.MeasurementError when the circuit so far contains a conditional" do
      circuit =
        Qx.QuantumCircuit.new(2, 1)
        |> Operations.h(0)
        |> Operations.c_if(0, 1, fn c -> Operations.x(c, 1) end)

      assert_raise Qx.MeasurementError, fn ->
        Operations.tap_state(circuit, fn _state -> :ignored end)
      end
    end
  end

  describe "tap_probabilities/2" do
    test "receives the probabilities after the instructions so far" do
      parent = self()

      Qx.QuantumCircuit.new(2, 0)
      |> Operations.h(0)
      |> Operations.cx(0, 1)
      |> Operations.tap_probabilities(fn probs -> send(parent, {:tapped, probs}) end)

      assert_receive {:tapped, probs}
      [p00, p01, p10, p11] = Nx.to_flat_list(probs)

      assert_in_delta p00, 0.5, @tolerance
      assert_in_delta p01, 0.0, @tolerance
      assert_in_delta p10, 0.0, @tolerance
      assert_in_delta p11, 0.5, @tolerance
    end

    test "returns the circuit unchanged so the pipeline continues" do
      circuit = Qx.QuantumCircuit.new(2, 0) |> Operations.h(0)

      tapped = Operations.tap_probabilities(circuit, fn _probs -> :ignored end)

      assert tapped == circuit
    end

    test "raises Qx.MeasurementError when the circuit so far contains a measurement" do
      circuit =
        Qx.QuantumCircuit.new(1, 1)
        |> Operations.h(0)
        |> Operations.measure(0, 0)

      assert_raise Qx.MeasurementError, fn ->
        Operations.tap_probabilities(circuit, fn _probs -> :ignored end)
      end
    end

    test "raises Qx.MeasurementError when the circuit so far contains a conditional" do
      circuit =
        Qx.QuantumCircuit.new(2, 1)
        |> Operations.h(0)
        |> Operations.c_if(0, 1, fn c -> Operations.x(c, 1) end)

      assert_raise Qx.MeasurementError, fn ->
        Operations.tap_probabilities(circuit, fn _probs -> :ignored end)
      end
    end
  end
end
