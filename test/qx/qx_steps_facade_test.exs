defmodule QxStepsFacadeTest do
  use ExUnit.Case, async: true

  alias Qx.Step

  test "Qx.steps/1 streams one %Qx.Step{} per gate" do
    qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)

    steps = Qx.steps(qc)

    assert is_function(steps) or is_struct(steps, Stream)
    assert [%Step{index: 0}, %Step{index: 1}] = Enum.to_list(steps)
  end

  test "Qx.steps/2 forwards options: seed reproduces a trajectory" do
    qc =
      Qx.create_circuit(2, 2)
      |> Qx.h(0)
      |> Qx.measure(0, 0)
      |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
      |> Qx.measure(1, 1)

    run = fn -> Qx.steps(qc, seed: 99) |> Enum.map(& &1.classical_bits) end

    assert run.() == run.()
  end

  test "Qx.steps matches Qx.Simulation.steps" do
    qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)

    facade = Qx.steps(qc) |> Enum.map(&{&1.kind, &1.operation, &1.index})
    engine = Qx.Simulation.steps(qc) |> Enum.map(&{&1.kind, &1.operation, &1.index})

    assert facade == engine
  end

  test "tap_state on an empty circuit receives the initial state" do
    parent = self()

    Qx.create_circuit(1)
    |> Qx.tap_state(fn state -> send(parent, {:tapped, state}) end)

    assert_receive {:tapped, state}
    assert_in_delta Complex.abs(Nx.to_number(state[0])), 1.0, 1.0e-6
  end
end
