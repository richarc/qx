defmodule Qx.SimulationStepsTest do
  use ExUnit.Case, async: true

  alias Qx.{Math, Simulation, Step}

  # :c64 states are complex float32 (eps ~1.2e-7); 1.0e-6 per Iron Law #8.
  @tolerance 1.0e-6

  # README teleportation circuit: teleports |1⟩ from q0 to q2.
  defp teleportation do
    Qx.create_circuit(3, 3)
    |> Qx.x(0)
    |> Qx.h(1)
    |> Qx.cx(1, 2)
    |> Qx.cx(0, 1)
    |> Qx.h(0)
    |> Qx.measure(0, 0)
    |> Qx.measure(1, 1)
    |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)
    |> Qx.c_if(0, 1, fn c -> Qx.z(c, 2) end)
    |> Qx.measure(2, 2)
  end

  defp assert_states_close(state_a, state_b) do
    list_a = Nx.to_flat_list(state_a)
    list_b = Nx.to_flat_list(state_b)
    assert length(list_a) == length(list_b)

    for {a, b} <- Enum.zip(list_a, list_b) do
      assert_in_delta Complex.abs(Complex.subtract(a, b)), 0.0, @tolerance
    end
  end

  describe "steps/1 on unitary circuits" do
    test "yields one %Qx.Step{} per gate, in order" do
      qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)

      steps = Simulation.steps(qc) |> Enum.to_list()

      assert length(steps) == 2
      assert [%Step{kind: :gate, operation: {:h, [0], []}, index: 0}, _] = steps
      assert [_, %Step{kind: :gate, operation: {:cx, [0, 1], []}, index: 1}] = steps
      assert Enum.all?(steps, &(&1.classical_bits == []))
      assert Enum.all?(steps, &(&1.condition == nil))
    end

    test "step k's state equals get_state/1 of the k-gate prefix" do
      full = Qx.create_circuit(3) |> Qx.h(0) |> Qx.cx(0, 1) |> Qx.ry(2, 0.7)
      steps = Simulation.steps(full) |> Enum.to_list()

      prefixes = [
        Qx.create_circuit(3) |> Qx.h(0),
        Qx.create_circuit(3) |> Qx.h(0) |> Qx.cx(0, 1),
        full
      ]

      for {step, prefix} <- Enum.zip(steps, prefixes) do
        assert_states_close(step.state, Simulation.get_state(prefix))
      end
    end

    test "step probabilities are consistent with Math.probabilities of the step state" do
      qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)

      for step <- Simulation.steps(qc) do
        expected = Math.probabilities(step.state) |> Nx.to_flat_list()
        actual = Nx.to_flat_list(step.probabilities)

        for {a, e} <- Enum.zip(actual, expected) do
          assert_in_delta a, e, @tolerance
        end
      end
    end
  end

  describe "laziness" do
    test "returns a lazy stream, not a list" do
      qc = Qx.create_circuit(1) |> Qx.h(0)
      steps = Simulation.steps(qc)

      assert is_function(steps) or is_struct(steps, Stream)
    end

    test "taking one step does not execute the rest of the circuit" do
      # A bogus trailing instruction raises Qx.GateError if executed;
      # Enum.take(_, 1) must succeed because it never reaches it.
      qc = Qx.create_circuit(1) |> Qx.h(0)
      poisoned = %{qc | instructions: qc.instructions ++ [{:bogus_gate, [0], []}]}

      assert [%Step{operation: {:h, [0], []}}] = Enum.take(Simulation.steps(poisoned), 1)
      assert_raise Qx.GateError, fn -> Enum.to_list(Simulation.steps(poisoned)) end
    end
  end

  describe "steps/2 on the teleportation circuit" do
    test "full trajectory has one step per executed operation" do
      steps = Simulation.steps(teleportation()) |> Enum.to_list()

      # 5 gates + 2 measurements + 2 conditionals (1 step each,
      # taken or not) + 1 final measurement.
      assert length(steps) == 10
      assert Enum.map(steps, & &1.index) == Enum.to_list(0..9)

      assert Enum.map(steps, & &1.kind) ==
               [:gate, :gate, :gate, :gate, :gate] ++
                 [:measurement, :measurement, :conditional, :conditional, :measurement]
    end

    test "measurement steps populate classical_bits" do
      steps = Simulation.steps(teleportation()) |> Enum.to_list()

      [m0, m1] = steps |> Enum.filter(&(&1.kind == :measurement)) |> Enum.take(2)

      assert [b0, b1, 0] = m1.classical_bits
      assert b0 in [0, 1]
      assert b1 in [0, 1]
      assert length(m0.classical_bits) == 3
    end

    test "conditional steps carry the condition and match the measured bits" do
      steps = Simulation.steps(teleportation()) |> Enum.to_list()

      [_m0, m1] = steps |> Enum.filter(&(&1.kind == :measurement)) |> Enum.take(2)
      [b0, b1, 0] = m1.classical_bits

      [x_corr, z_corr] = Enum.filter(steps, &(&1.kind == :conditional))

      if b1 == 1 do
        assert x_corr.condition == {1, 1, :taken}
        assert x_corr.operation == {:x, [2], []}
      else
        assert x_corr.condition == {1, 1, :not_taken}
        assert x_corr.operation == nil
      end

      if b0 == 1 do
        assert z_corr.condition == {0, 1, :taken}
        assert z_corr.operation == {:z, [2], []}
      else
        assert z_corr.condition == {0, 1, :not_taken}
      end
    end

    test "a not-taken c_if leaves the state unchanged" do
      # cbit 0 stays 0, so the block never runs: one flagged step.
      qc =
        Qx.create_circuit(1, 1)
        |> Qx.h(0)
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 0) end)

      steps = Simulation.steps(qc) |> Enum.to_list()

      assert [%Step{kind: :gate} = h_step, %Step{kind: :conditional} = cond_step] = steps
      assert cond_step.condition == {0, 1, :not_taken}
      assert cond_step.operation == nil
      assert_states_close(cond_step.state, h_step.state)
    end

    test "the teleported qubit is consistent with the classical bits" do
      steps = Simulation.steps(teleportation()) |> Enum.to_list()

      final = List.last(steps)
      assert final.kind == :measurement
      assert [_b0, _b1, 1] = final.classical_bits
    end

    test "every yielded state stays normalized" do
      for step <- Simulation.steps(teleportation()) do
        total = step.probabilities |> Nx.sum() |> Nx.to_number()
        assert_in_delta total, 1.0, @tolerance
      end
    end
  end

  describe "seed:" do
    test "the same seed gives an identical trajectory" do
      run = fn -> Simulation.steps(teleportation(), seed: 42) |> Enum.to_list() end

      [a, b] = [run.(), run.()]

      assert Enum.map(a, & &1.classical_bits) == Enum.map(b, & &1.classical_bits)
      assert Enum.map(a, & &1.condition) == Enum.map(b, & &1.condition)

      for {sa, sb} <- Enum.zip(a, b) do
        assert Nx.to_flat_list(sa.state) == Nx.to_flat_list(sb.state)
      end
    end

    test "seeding does not mutate the caller's process :rand state" do
      before_seed = :rand.export_seed()

      Simulation.steps(teleportation(), seed: 1234) |> Enum.to_list()
      Simulation.steps(teleportation()) |> Enum.to_list()

      assert :rand.export_seed() == before_seed
    end
  end

  describe "options" do
    test "renormalize: n counts c_if inner gates in the cadence and keeps states normalized" do
      steps = Simulation.steps(teleportation(), seed: 7, renormalize: 2) |> Enum.to_list()
      plain = Simulation.steps(teleportation(), seed: 7) |> Enum.to_list()

      assert length(steps) == length(plain)
      assert Enum.map(steps, & &1.classical_bits) == Enum.map(plain, & &1.classical_bits)

      for step <- steps do
        total = step.probabilities |> Nx.sum() |> Nx.to_number()
        assert_in_delta total, 1.0, @tolerance
      end
    end

    test "invalid renormalize raises Qx.OptionError, not a raw error" do
      qc = Qx.create_circuit(1) |> Qx.h(0)

      assert_raise Qx.OptionError, fn ->
        Simulation.steps(qc, renormalize: :sometimes) |> Enum.to_list()
      end
    end

    test "backend: Nx.BinaryBackend is accepted" do
      qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)

      steps = Simulation.steps(qc, backend: Nx.BinaryBackend) |> Enum.to_list()

      assert length(steps) == 2
      assert_states_close(List.last(steps).state, Simulation.get_state(qc))
    end
  end

  describe "multi-gate c_if blocks" do
    test "a taken block emits one step per inner gate, in order" do
      qc =
        Qx.create_circuit(1, 1)
        |> Qx.x(0)
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> c |> Qx.x(0) |> Qx.h(0) end)

      steps = Simulation.steps(qc) |> Enum.to_list()

      assert Enum.map(steps, & &1.kind) == [:gate, :measurement, :conditional, :conditional]

      [inner_x, inner_h] = Enum.filter(steps, &(&1.kind == :conditional))
      assert inner_x.operation == {:x, [0], []}
      assert inner_h.operation == {:h, [0], []}
      assert inner_x.condition == {0, 1, :taken}
      assert inner_h.condition == {0, 1, :taken}
      assert Enum.map(steps, & &1.index) == [0, 1, 2, 3]
    end

    test "renormalize: n spans the block and keeps every state normalized" do
      qc =
        Qx.create_circuit(1, 1)
        |> Qx.x(0)
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> c |> Qx.x(0) |> Qx.h(0) |> Qx.z(0) end)

      steps = Simulation.steps(qc, renormalize: 2) |> Enum.to_list()

      assert length(steps) == 5

      for step <- steps do
        total = step.probabilities |> Nx.sum() |> Nx.to_number()
        assert_in_delta total, 1.0, @tolerance
      end
    end
  end

  describe "edge cases" do
    test "an empty circuit yields an empty stream" do
      assert Simulation.steps(Qx.create_circuit(2)) |> Enum.to_list() == []
    end

    test "renormalize: true is accepted" do
      qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)

      steps = Simulation.steps(qc, renormalize: true) |> Enum.to_list()

      assert length(steps) == 2
    end
  end
end
