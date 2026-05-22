defmodule Qx.PatternsTest do
  use ExUnit.Case, async: true

  alias Qx.{Patterns, QuantumCircuit}

  describe "h_all/1" do
    test "emits one H per qubit, in ascending order" do
      qc = QuantumCircuit.new(3, 0) |> Patterns.h_all()

      assert QuantumCircuit.get_instructions(qc) == [
               {:h, [0], []},
               {:h, [1], []},
               {:h, [2], []}
             ]
    end

    test "single-qubit circuit emits exactly one H" do
      qc = QuantumCircuit.new(1, 0) |> Patterns.h_all()

      assert QuantumCircuit.get_instructions(qc) == [{:h, [0], []}]
    end

    test "appends to existing instructions, doesn't replace" do
      qc =
        QuantumCircuit.new(2, 0)
        |> Qx.Operations.x(0)
        |> Patterns.h_all()

      assert QuantumCircuit.get_instructions(qc) == [
               {:x, [0], []},
               {:h, [0], []},
               {:h, [1], []}
             ]
    end
  end

  describe "x_all/1" do
    test "emits one X per qubit on a 3-qubit circuit" do
      qc = QuantumCircuit.new(3, 0) |> Patterns.x_all()

      assert QuantumCircuit.get_instructions(qc) == [
               {:x, [0], []},
               {:x, [1], []},
               {:x, [2], []}
             ]
    end

    test "single-qubit circuit emits one X" do
      qc = QuantumCircuit.new(1, 0) |> Patterns.x_all()

      assert QuantumCircuit.get_instructions(qc) == [{:x, [0], []}]
    end
  end

  describe "y_all/1" do
    test "emits one Y per qubit on a 2-qubit circuit" do
      qc = QuantumCircuit.new(2, 0) |> Patterns.y_all()

      assert QuantumCircuit.get_instructions(qc) == [
               {:y, [0], []},
               {:y, [1], []}
             ]
    end

    test "single-qubit circuit emits one Y" do
      qc = QuantumCircuit.new(1, 0) |> Patterns.y_all()

      assert QuantumCircuit.get_instructions(qc) == [{:y, [0], []}]
    end
  end

  describe "z_all/1" do
    test "emits one Z per qubit on a 3-qubit circuit" do
      qc = QuantumCircuit.new(3, 0) |> Patterns.z_all()

      assert QuantumCircuit.get_instructions(qc) == [
               {:z, [0], []},
               {:z, [1], []},
               {:z, [2], []}
             ]
    end

    test "single-qubit circuit emits one Z" do
      qc = QuantumCircuit.new(1, 0) |> Patterns.z_all()

      assert QuantumCircuit.get_instructions(qc) == [{:z, [0], []}]
    end
  end

  describe "measure_all/1" do
    test "emits one measurement per qubit, qubit i -> classical bit i" do
      qc = QuantumCircuit.new(3, 3) |> Patterns.measure_all()

      assert QuantumCircuit.get_instructions(qc) == [
               {:measure, [0, 0], []},
               {:measure, [1, 1], []},
               {:measure, [2, 2], []}
             ]
    end

    test "appends after gates without disturbing earlier instructions" do
      qc =
        QuantumCircuit.new(2, 2)
        |> Qx.Operations.h(0)
        |> Qx.Operations.cx(0, 1)
        |> Patterns.measure_all()

      assert QuantumCircuit.get_instructions(qc) == [
               {:h, [0], []},
               {:cx, [0, 1], []},
               {:measure, [0, 0], []},
               {:measure, [1, 1], []}
             ]
    end

    test "raises Qx.ClassicalBitError when num_classical_bits < num_qubits" do
      qc = QuantumCircuit.new(3, 2)

      assert_raise Qx.ClassicalBitError, ~r/Classical bit index 2 out of range/, fn ->
        Patterns.measure_all(qc)
      end
    end

    test "single-qubit circuit emits one measurement" do
      qc = QuantumCircuit.new(1, 1) |> Patterns.measure_all()

      assert QuantumCircuit.get_instructions(qc) == [{:measure, [0, 0], []}]
    end
  end

  describe "barrier_all/1" do
    test "emits a single barrier spanning every qubit" do
      qc = QuantumCircuit.new(3, 0) |> Patterns.barrier_all()

      assert QuantumCircuit.get_instructions(qc) == [{:barrier, [0, 1, 2], []}]
    end

    test "single-qubit circuit emits barrier over [0]" do
      qc = QuantumCircuit.new(1, 0) |> Patterns.barrier_all()

      assert QuantumCircuit.get_instructions(qc) == [{:barrier, [0], []}]
    end

    test "appends after gates without disturbing earlier instructions" do
      qc =
        QuantumCircuit.new(2, 0)
        |> Qx.Operations.h(0)
        |> Patterns.barrier_all()

      assert QuantumCircuit.get_instructions(qc) == [
               {:h, [0], []},
               {:barrier, [0, 1], []}
             ]
    end
  end

  describe "cx_chain/2" do
    test "linear cascade on [0, 1, 2, 3] -> three CX in order" do
      qc = QuantumCircuit.new(4, 0) |> Patterns.cx_chain([0, 1, 2, 3])

      assert QuantumCircuit.get_instructions(qc) == [
               {:cx, [0, 1], []},
               {:cx, [1, 2], []},
               {:cx, [2, 3], []}
             ]
    end

    test "empty list is a no-op" do
      qc = QuantumCircuit.new(2, 0)
      assert Patterns.cx_chain(qc, []) == qc
    end

    test "single-element list is a no-op" do
      qc = QuantumCircuit.new(2, 0)
      assert Patterns.cx_chain(qc, [0]) == qc
    end

    test "two-element list emits exactly one CX" do
      qc = QuantumCircuit.new(2, 0) |> Patterns.cx_chain([0, 1])

      assert QuantumCircuit.get_instructions(qc) == [{:cx, [0, 1], []}]
    end

    test "GHZ-style preparation: H(0) + cx_chain entangles all qubits" do
      qc =
        QuantumCircuit.new(3, 0)
        |> Qx.Operations.h(0)
        |> Patterns.cx_chain([0, 1, 2])

      assert QuantumCircuit.get_instructions(qc) == [
               {:h, [0], []},
               {:cx, [0, 1], []},
               {:cx, [1, 2], []}
             ]
    end

    test "non-contiguous qubit order is respected (chain follows list order)" do
      qc = QuantumCircuit.new(4, 0) |> Patterns.cx_chain([3, 0, 2])

      assert QuantumCircuit.get_instructions(qc) == [
               {:cx, [3, 0], []},
               {:cx, [0, 2], []}
             ]
    end

    test "out-of-range qubit propagates Qx.QubitIndexError (Iron Law #7)" do
      qc = QuantumCircuit.new(3, 0)

      assert_raise Qx.QubitIndexError, ~r/Qubit index 5 out of range/, fn ->
        Patterns.cx_chain(qc, [0, 5])
      end
    end
  end

  describe "h_all/2 — list/range overload" do
    test "list form applies H to listed qubits in order" do
      qc = QuantumCircuit.new(5, 0) |> Patterns.h_all([0, 2, 4])

      assert QuantumCircuit.get_instructions(qc) == [
               {:h, [0], []},
               {:h, [2], []},
               {:h, [4], []}
             ]
    end

    test "range form applies H to range qubits in order" do
      qc = QuantumCircuit.new(5, 0) |> Patterns.h_all(1..3)

      assert QuantumCircuit.get_instructions(qc) == [
               {:h, [1], []},
               {:h, [2], []},
               {:h, [3], []}
             ]
    end

    test "empty list is a no-op" do
      qc = QuantumCircuit.new(3, 0)
      assert Patterns.h_all(qc, []) == qc
    end

    test "out-of-range qubit propagates Qx.QubitIndexError" do
      qc = QuantumCircuit.new(3, 0)

      assert_raise Qx.QubitIndexError, ~r/Qubit index 5/, fn ->
        Patterns.h_all(qc, [0, 5])
      end
    end

    test "h_all/1 and h_all/2 over full range produce same instructions" do
      qc = QuantumCircuit.new(3, 0)
      assert Patterns.h_all(qc) == Patterns.h_all(qc, 0..2)
    end
  end

  describe "x_all/2, y_all/2, z_all/2 — list/range overload" do
    test "x_all([0, 3])" do
      qc = QuantumCircuit.new(4, 0) |> Patterns.x_all([0, 3])

      assert QuantumCircuit.get_instructions(qc) == [
               {:x, [0], []},
               {:x, [3], []}
             ]
    end

    test "y_all(0..1)" do
      qc = QuantumCircuit.new(3, 0) |> Patterns.y_all(0..1)

      assert QuantumCircuit.get_instructions(qc) == [
               {:y, [0], []},
               {:y, [1], []}
             ]
    end

    test "z_all([2])" do
      qc = QuantumCircuit.new(3, 0) |> Patterns.z_all([2])

      assert QuantumCircuit.get_instructions(qc) == [{:z, [2], []}]
    end

    test "x_all/y_all/z_all: empty list is a no-op" do
      qc = QuantumCircuit.new(3, 0)
      assert Patterns.x_all(qc, []) == qc
      assert Patterns.y_all(qc, []) == qc
      assert Patterns.z_all(qc, []) == qc
    end

    test "x_all/y_all/z_all: OOR qubit propagates Qx.QubitIndexError" do
      qc = QuantumCircuit.new(3, 0)

      assert_raise Qx.QubitIndexError, fn -> Patterns.x_all(qc, [0, 5]) end
      assert_raise Qx.QubitIndexError, fn -> Patterns.y_all(qc, [0, 5]) end
      assert_raise Qx.QubitIndexError, fn -> Patterns.z_all(qc, [0, 5]) end
    end
  end

  describe "measure_all/2 — list/range overload" do
    test "measures only the listed qubits into their same-index classical bits" do
      qc = QuantumCircuit.new(3, 3) |> Patterns.measure_all([0, 2])

      assert QuantumCircuit.get_instructions(qc) == [
               {:measure, [0, 0], []},
               {:measure, [2, 2], []}
             ]
    end

    test "range form measures the range" do
      qc = QuantumCircuit.new(4, 4) |> Patterns.measure_all(1..2)

      assert QuantumCircuit.get_instructions(qc) == [
               {:measure, [1, 1], []},
               {:measure, [2, 2], []}
             ]
    end

    test "empty list is a no-op" do
      qc = QuantumCircuit.new(3, 3)
      assert Patterns.measure_all(qc, []) == qc
    end

    test "raises Qx.ClassicalBitError if a listed qubit has no classical bit" do
      qc = QuantumCircuit.new(3, 1)

      assert_raise Qx.ClassicalBitError, fn ->
        Patterns.measure_all(qc, [0, 1])
      end
    end
  end

  describe "barrier_all/2 — list/range overload" do
    test "emits a single barrier over the listed qubits" do
      qc = QuantumCircuit.new(4, 0) |> Patterns.barrier_all([0, 2])

      assert QuantumCircuit.get_instructions(qc) == [{:barrier, [0, 2], []}]
    end

    test "range form" do
      qc = QuantumCircuit.new(4, 0) |> Patterns.barrier_all(1..3)

      assert QuantumCircuit.get_instructions(qc) == [{:barrier, [1, 2, 3], []}]
    end

    test "empty list is a no-op (no instruction emitted)" do
      qc = QuantumCircuit.new(3, 0)
      assert Patterns.barrier_all(qc, []) == qc
    end
  end

  describe "list/range equivalence" do
    test "list and range produce identical instructions when contents match" do
      qc = QuantumCircuit.new(5, 5)

      list_form = Patterns.h_all(qc, [0, 1, 2])
      range_form = Patterns.h_all(qc, 0..2)

      assert list_form == range_form
    end
  end
end
