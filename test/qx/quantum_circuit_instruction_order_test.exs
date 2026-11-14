defmodule Qx.QuantumCircuitInstructionOrderTest do
  use ExUnit.Case, async: true

  alias Qx.QuantumCircuit

  # Covers three things about a circuit's instruction list:
  #
  #   * ORDER — every consumer (get_instructions, run, steps, draw, QASM
  #     export and import) sees instructions in the order they were added;
  #   * the struct contract — the list is read with `get_instructions/1` and
  #     written in bulk with `put_instructions/2`; there is no public
  #     `instructions` field;
  #   * COST — adding an instruction does not get dearer as the circuit grows.

  @tolerance 1.0e-6

  # X then CX gives |11⟩. In the opposite order CX sees |00⟩ and does
  # nothing, leaving |10⟩: the two orders give different results.
  defp order_sensitive_circuit do
    Qx.create_circuit(2) |> Qx.x(0) |> Qx.cx(0, 1)
  end

  # q0 is flipped, measured into c0, and c0 decides whether q1 is flipped.
  # Every instruction depends on the one before it.
  defp order_sensitive_conditional_circuit do
    Qx.create_circuit(2, 2)
    |> Qx.x(0)
    |> Qx.measure(0, 0)
    |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
    |> Qx.measure(1, 1)
  end

  defp assert_probabilities(tensor, expected) do
    actual = Nx.to_flat_list(tensor)
    assert length(actual) == length(expected)

    actual
    |> Enum.zip(expected)
    |> Enum.each(fn {a, e} -> assert_in_delta a, e, @tolerance end)
  end

  describe "get_instructions/1 returns instructions in call order" do
    test "one of each producer kind, with the exact tuples" do
      circuit =
        Qx.create_circuit(3, 2)
        |> Qx.h(0)
        |> Qx.rx(1, 0.5)
        |> Qx.cx(0, 1)
        |> Qx.ccx(0, 1, 2)
        |> Qx.barrier([0, 1, 2])
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> c |> Qx.x(1) |> Qx.z(2) end)

      assert QuantumCircuit.get_instructions(circuit) == [
               {:h, [0], []},
               {:rx, [1], [0.5]},
               {:cx, [0, 1], []},
               {:ccx, [0, 1, 2], []},
               {:barrier, [0, 1, 2], []},
               {:measure, [0, 0], []},
               {:c_if, [0, 1], [{:x, [1], []}, {:z, [2], []}]}
             ]
    end

    test "an empty circuit has no instructions" do
      assert QuantumCircuit.get_instructions(Qx.create_circuit(2)) == []
    end
  end

  describe "consumers see instructions in call order" do
    test "run/2 applies gates in call order" do
      result = Qx.run(order_sensitive_circuit())

      assert_probabilities(result.probabilities, [0.0, 0.0, 0.0, 1.0])
    end

    test "run/2 on the conditional path applies the timeline in call order" do
      result = Qx.run(order_sensitive_conditional_circuit(), shots: 5)

      assert result.classical_bits == List.duplicate([1, 1], 5)
      assert result.counts == %{"11" => 5}
    end

    test "steps/2 yields one step per instruction, in call order" do
      steps = order_sensitive_circuit() |> Qx.steps() |> Enum.to_list()

      assert Enum.map(steps, & &1.operation) == [{:x, [0], []}, {:cx, [0, 1], []}]
      assert Enum.map(steps, & &1.index) == [0, 1]

      [after_x, after_cx] = steps
      assert_probabilities(after_x.probabilities, [0.0, 0.0, 1.0, 0.0])
      assert_probabilities(after_cx.probabilities, [0.0, 0.0, 0.0, 1.0])
    end

    test "steps/2 on a conditional circuit follows the timeline in call order" do
      steps = order_sensitive_conditional_circuit() |> Qx.steps() |> Enum.to_list()

      assert Enum.map(steps, &{&1.kind, &1.operation}) == [
               {:gate, {:x, [0], []}},
               {:measurement, {:measure, [0, 0], []}},
               {:conditional, {:x, [1], []}},
               {:measurement, {:measure, [1, 1], []}}
             ]

      assert List.last(steps).classical_bits == [1, 1]
    end

    test "to_qasm/2 writes gate lines in call order" do
      gate_lines =
        order_sensitive_circuit()
        |> Qx.to_qasm()
        |> String.split("\n")
        |> Enum.filter(&(&1 in ["x q[0];", "cx q[0], q[1];"]))

      assert gate_lines == ["x q[0];", "cx q[0], q[1];"]
    end

    test "from_qasm/1 keeps source order" do
      source = """
      OPENQASM 3.0;
      include "stdgates.inc";

      qubit[2] q;
      bit[2] c;

      x q[0];
      cx q[0], q[1];
      h q[1];
      c[0] = measure q[0];
      """

      assert {:ok, circuit} = Qx.from_qasm(source)

      assert QuantumCircuit.get_instructions(circuit) == [
               {:x, [0], []},
               {:cx, [0, 1], []},
               {:h, [1], []},
               {:measure, [0, 0], []}
             ]
    end

    test "a QASM export/import round trip keeps the order" do
      circuit = order_sensitive_circuit()

      assert {:ok, imported} = circuit |> Qx.to_qasm() |> Qx.from_qasm()

      assert QuantumCircuit.get_instructions(imported) ==
               QuantumCircuit.get_instructions(circuit)
    end

    test "draw_circuit/1 places gates left to right in call order" do
      image = Qx.create_circuit(1) |> Qx.x(0) |> Qx.h(0) |> Qx.draw_circuit()

      assert gate_label_x(image.svg, "X") < gate_label_x(image.svg, "H")
    end
  end

  # The x coordinate of the single gate label `label` in a circuit SVG.
  defp gate_label_x(svg, label) do
    pattern = Regex.compile!(~s{<text x="([0-9.]+)"[^>]*>#{label}</text>})
    assert [[_, x]] = Regex.scan(pattern, svg)
    {value, ""} = Float.parse(x)
    value
  end

  describe "struct contract" do
    test "the struct has no `instructions` field" do
      refute Map.has_key?(Qx.create_circuit(1), :instructions)
    end

    test "put_instructions/2 stores a list in circuit order, and builders add after it" do
      list = [{:h, [0], []}, {:cx, [0, 1], []}, {:x, [1], []}]

      circuit = QuantumCircuit.put_instructions(Qx.create_circuit(2), list)
      assert QuantumCircuit.get_instructions(circuit) == list

      assert circuit |> Qx.z(0) |> QuantumCircuit.get_instructions() ==
               list ++ [{:z, [0], []}]

      assert circuit |> QuantumCircuit.put_instructions([]) |> QuantumCircuit.get_instructions() ==
               []
    end

    test "depth/1 counts the instructions" do
      assert QuantumCircuit.depth(Qx.create_circuit(2)) == 0
      assert QuantumCircuit.depth(order_sensitive_circuit()) == 2
      assert QuantumCircuit.depth(order_sensitive_conditional_circuit()) == 4
    end

    test "reset/1 empties the instructions" do
      circuit = QuantumCircuit.reset(order_sensitive_conditional_circuit())

      assert QuantumCircuit.get_instructions(circuit) == []
      assert QuantumCircuit.depth(circuit) == 0
      assert QuantumCircuit.get_measurements(circuit) == []
    end
  end

  describe "c_if/4" do
    test "keeps earlier instructions; the body holds only the gates the function added" do
      circuit =
        Qx.create_circuit(3, 1)
        |> Qx.h(0)
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> c |> Qx.x(1) |> Qx.z(2) |> Qx.cx(1, 2) end)
        |> Qx.h(2)

      assert QuantumCircuit.get_instructions(circuit) == [
               {:h, [0], []},
               {:measure, [0, 0], []},
               {:c_if, [0, 1], [{:x, [1], []}, {:z, [2], []}, {:cx, [1, 2], []}]},
               {:h, [2], []}
             ]
    end

    test "two conditional blocks each hold their own body" do
      circuit =
        Qx.create_circuit(2, 1)
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> c |> Qx.x(1) |> Qx.h(1) end)
        |> Qx.c_if(0, 0, fn c -> Qx.z(c, 1) end)

      assert QuantumCircuit.get_instructions(circuit) == [
               {:measure, [0, 0], []},
               {:c_if, [0, 1], [{:x, [1], []}, {:h, [1], []}]},
               {:c_if, [0, 0], [{:z, [1], []}]}
             ]
    end
  end

  describe "cost of adding an instruction" do
    # Reductions are the BEAM's deterministic work counter, so this needs no
    # timing threshold. The test builds 50,000 gates, then counts the
    # reductions spent adding 50,000 more to that already-long circuit.
    #
    # Measured 2026-11-14 (OTP 29, three fresh VMs, spread under 0.1%):
    #
    #   * appending with `list ++ [x]`: 1,654 reductions per gate, because
    #     each append copies the whole list (and the 100,000-gate build takes
    #     19 s);
    #   * a `Qx.h/2` call whose result is thrown away, which is everything
    #     except the growing list: 10.5 reductions.
    #
    # The limit is more than 10× under the first and more than 10× over the
    # second.
    @half 50_000
    @max_reductions_per_gate 140

    @tag timeout: 300_000
    test "adding a gate to a 50,000-gate circuit costs a constant amount of work" do
      # A fresh process, so the count is this build's alone. It returns the
      # numbers; the assertions run here, where a failure reports properly.
      {spent, depth} =
        Task.async(fn ->
          add_gate = fn i, circuit -> Qx.h(circuit, rem(i, 4)) end
          long_circuit = Enum.reduce(1..@half, Qx.create_circuit(4), add_gate)

          before = reductions()
          longer_circuit = Enum.reduce(1..@half, long_circuit, add_gate)
          spent = reductions() - before

          {spent, QuantumCircuit.depth(longer_circuit)}
        end)
        |> Task.await(:infinity)

      assert depth == 2 * @half

      per_gate = spent / @half

      assert per_gate < @max_reductions_per_gate,
             "adding a gate to a #{@half}-gate circuit cost #{Float.round(per_gate, 1)} " <>
               "reductions; expected fewer than #{@max_reductions_per_gate}"
    end
  end

  defp reductions do
    {:reductions, count} = Process.info(self(), :reductions)
    count
  end
end
