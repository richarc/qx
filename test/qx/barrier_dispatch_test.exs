defmodule Qx.BarrierDispatchTest do
  use ExUnit.Case, async: true

  alias Qx.Simulation

  # :c64 states are complex float32 (eps ~1.2e-7); 1.0e-6 per Iron Law #8.
  @tolerance 1.0e-6

  # Bell circuit with a mid-circuit barrier spanning both qubits.
  defp bell_with_barrier do
    Qx.create_circuit(2, 2)
    |> Qx.h(0)
    |> Qx.barrier([0, 1])
    |> Qx.cx(0, 1)
    |> Qx.measure(0, 0)
    |> Qx.measure(1, 1)
  end

  defp assert_probs(probs_tensor, expected) do
    for {p, e} <- Enum.zip(Nx.to_flat_list(probs_tensor), expected) do
      assert_in_delta p, e, @tolerance
    end
  end

  describe "run/2" do
    test "a multi-qubit barrier is a no-op, not Qx.GateError" do
      result = Qx.run(bell_with_barrier())

      assert_probs(result.probabilities, [0.5, 0.0, 0.0, 0.5])
    end

    test "barrier_all/1 circuits run" do
      qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.barrier_all() |> Qx.cx(0, 1)

      result = Qx.run(qc)

      assert_probs(result.probabilities, [0.5, 0.0, 0.0, 0.5])
    end

    test "barriers inside the conditional (timeline) path are no-ops" do
      qc =
        Qx.create_circuit(2, 2)
        |> Qx.x(0)
        |> Qx.barrier([0, 1])
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
        |> Qx.measure(1, 1)

      result = Qx.run(qc, shots: 16)

      assert result.counts == %{"11" => 16}
    end
  end

  describe "get_state/2" do
    test "state with a barrier equals state without it" do
      with_barrier = Qx.create_circuit(2) |> Qx.h(0) |> Qx.barrier([0, 1]) |> Qx.cx(0, 1)
      without = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)

      a = Simulation.get_state(with_barrier) |> Nx.to_flat_list()
      b = Simulation.get_state(without) |> Nx.to_flat_list()

      for {x, y} <- Enum.zip(a, b) do
        assert_in_delta Complex.abs(Complex.subtract(x, y)), 0.0, @tolerance
      end
    end
  end

  describe "steps/2" do
    test "a barrier emits a step with the state unchanged" do
      qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.barrier([0, 1]) |> Qx.cx(0, 1)

      steps = Simulation.steps(qc) |> Enum.to_list()

      assert length(steps) == 3
      [h_step, barrier_step, _cx_step] = steps
      assert barrier_step.kind == :gate
      assert barrier_step.operation == {:barrier, [0, 1], []}
      assert Nx.to_flat_list(barrier_step.state) == Nx.to_flat_list(h_step.state)
    end

    test "renormalize: 2 cadence — barrier between gates changes nothing" do
      # The barrier must not advance the gate counter: with the barrier
      # between h and cx, cx is still gate ordinal 2 (renorm point). A
      # regression that counts the barrier shifts the cadence; at float32
      # the renorm itself is ~identity, so the observable contract is
      # exact step-for-step equivalence with the barrier-free circuit
      # (skipping the barrier's own step) plus normalization throughout.
      with_barrier = Qx.create_circuit(2) |> Qx.h(0) |> Qx.barrier([0, 1]) |> Qx.cx(0, 1)
      without = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)

      barrier_steps =
        Simulation.steps(with_barrier, renormalize: 2)
        |> Enum.reject(&match?({:barrier, _, _}, &1.operation))

      plain_steps = Simulation.steps(without, renormalize: 2) |> Enum.to_list()

      assert length(barrier_steps) == length(plain_steps)

      for {a, b} <- Enum.zip(barrier_steps, plain_steps) do
        assert a.operation == b.operation

        for {x, y} <- Enum.zip(Nx.to_flat_list(a.state), Nx.to_flat_list(b.state)) do
          assert_in_delta Complex.abs(Complex.subtract(x, y)), 0.0, @tolerance
        end

        total = a.probabilities |> Nx.sum() |> Nx.to_number()
        assert_in_delta total, 1.0, @tolerance
      end
    end
  end

  describe "edge cases" do
    test "a barrier inside a c_if body is a no-op on the inner-gate path" do
      qc =
        Qx.create_circuit(2, 2)
        |> Qx.x(0)
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> c |> Qx.barrier([0, 1]) |> Qx.x(1) end)
        |> Qx.measure(1, 1)

      result = Qx.run(qc, shots: 16)

      assert result.counts == %{"11" => 16}

      steps = Simulation.steps(qc) |> Enum.to_list()
      conditionals = Enum.filter(steps, &(&1.kind == :conditional))

      assert Enum.map(conditionals, & &1.operation) ==
               [{:barrier, [0, 1], []}, {:x, [1], []}]
    end

    test "a barrier as the only instruction leaves the initial state" do
      qc = Qx.create_circuit(1) |> Qx.barrier([0])

      state = Simulation.get_state(qc)

      assert_in_delta Complex.abs(Nx.to_number(state[0])), 1.0, @tolerance
      assert [%{operation: {:barrier, [0], []}}] = Simulation.steps(qc) |> Enum.to_list()
    end

    test "an explicitly empty-qubit-list barrier is also a no-op" do
      # Operations.barrier/2 permits []; the historical 0-qubit shape.
      qc = Qx.create_circuit(1) |> Qx.h(0) |> Qx.Operations.barrier([])

      result = Qx.run(qc)

      assert_probs(result.probabilities, [0.5, 0.5])
    end
  end
end
