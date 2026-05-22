defmodule Qx.OperationsControlledRotationsTest do
  use ExUnit.Case, async: true

  alias Qx.{Operations, QuantumCircuit}

  describe "cy/3" do
    test "emits {:cy, [c, t], []}" do
      qc = QuantumCircuit.new(2, 0) |> Operations.cy(0, 1)

      assert QuantumCircuit.get_instructions(qc) == [{:cy, [0, 1], []}]
    end

    test "duplicate control/target raises Qx.QubitIndexError" do
      qc = QuantumCircuit.new(2, 0)

      assert_raise Qx.QubitIndexError, ~r/distinct/, fn ->
        Operations.cy(qc, 0, 0)
      end
    end

    test "out-of-range qubit raises Qx.QubitIndexError" do
      qc = QuantumCircuit.new(2, 0)

      assert_raise Qx.QubitIndexError, ~r/Qubit index 5 out of range/, fn ->
        Operations.cy(qc, 0, 5)
      end
    end

    test "CY with control=|1⟩ flips target with Y phase: |10⟩ -> i|11⟩" do
      # qubit 0 control, qubit 1 target. Start in |10⟩ by X on qubit 0.
      probs =
        QuantumCircuit.new(2, 0)
        |> Operations.x(0)
        |> Operations.cy(0, 1)
        |> Qx.run()
        |> Map.fetch!(:probabilities)
        |> Nx.to_flat_list()

      # |11⟩ (MSB qubit 0): index = 0b11 = 3, prob = 1
      assert_in_delta Enum.at(probs, 3), 1.0, 1.0e-5
      assert_in_delta Enum.at(probs, 0), 0.0, 1.0e-5
    end

    test "CY with control=|0⟩ leaves target unchanged" do
      probs =
        QuantumCircuit.new(2, 0)
        |> Operations.cy(0, 1)
        |> Qx.run()
        |> Map.fetch!(:probabilities)
        |> Nx.to_flat_list()

      assert_in_delta Enum.at(probs, 0), 1.0, 1.0e-5
    end
  end

  describe "crx/4" do
    test "emits {:crx, [c, t], [theta]}" do
      qc = QuantumCircuit.new(2, 0) |> Operations.crx(0, 1, :math.pi() / 2)

      assert [{:crx, [0, 1], [theta]}] = QuantumCircuit.get_instructions(qc)
      assert_in_delta theta, :math.pi() / 2, 1.0e-12
    end

    test "non-numeric theta raises ArgumentError" do
      qc = QuantumCircuit.new(2, 0)

      assert_raise ArgumentError, fn ->
        Operations.crx(qc, 0, 1, :not_a_number)
      end
    end

    test "CRx(0) is identity: |00⟩ stays |00⟩" do
      probs =
        QuantumCircuit.new(2, 0)
        |> Operations.crx(0, 1, 0.0)
        |> Qx.run()
        |> Map.fetch!(:probabilities)
        |> Nx.to_flat_list()

      assert_in_delta Enum.at(probs, 0), 1.0, 1.0e-5
    end

    test "CRx(π) on |10⟩ flips target to |11⟩ (up to phase)" do
      probs =
        QuantumCircuit.new(2, 0)
        |> Operations.x(0)
        |> Operations.crx(0, 1, :math.pi())
        |> Qx.run()
        |> Map.fetch!(:probabilities)
        |> Nx.to_flat_list()

      # Rx(π) maps |0⟩ → −i|1⟩, so target qubit becomes |1⟩
      assert_in_delta Enum.at(probs, 3), 1.0, 1.0e-5
    end

    test "CRx(π) on |00⟩ (control off) leaves state unchanged" do
      # Sanity: control=|0⟩ means CRx must be the identity on target.
      probs =
        QuantumCircuit.new(2, 0)
        |> Operations.crx(0, 1, :math.pi())
        |> Qx.run()
        |> Map.fetch!(:probabilities)
        |> Nx.to_flat_list()

      assert_in_delta Enum.at(probs, 0), 1.0, 1.0e-5
    end
  end

  describe "cry/4" do
    test "emits {:cry, [c, t], [theta]}" do
      qc = QuantumCircuit.new(2, 0) |> Operations.cry(0, 1, :math.pi())

      assert [{:cry, [0, 1], _params}] = QuantumCircuit.get_instructions(qc)
    end

    test "CRy(π) on |10⟩ flips target to |11⟩" do
      probs =
        QuantumCircuit.new(2, 0)
        |> Operations.x(0)
        |> Operations.cry(0, 1, :math.pi())
        |> Qx.run()
        |> Map.fetch!(:probabilities)
        |> Nx.to_flat_list()

      assert_in_delta Enum.at(probs, 3), 1.0, 1.0e-5
    end

    test "CRy(π/2) on |10⟩ creates equal superposition on target" do
      probs =
        QuantumCircuit.new(2, 0)
        |> Operations.x(0)
        |> Operations.cry(0, 1, :math.pi() / 2)
        |> Qx.run()
        |> Map.fetch!(:probabilities)
        |> Nx.to_flat_list()

      # |10⟩ → (|10⟩ + |11⟩)/√2 ⇒ probs at index 2 and 3 are each ~0.5
      assert_in_delta Enum.at(probs, 2), 0.5, 1.0e-5
      assert_in_delta Enum.at(probs, 3), 0.5, 1.0e-5
    end

    test "CRy(π) on |00⟩ (control off) leaves state unchanged" do
      probs =
        QuantumCircuit.new(2, 0)
        |> Operations.cry(0, 1, :math.pi())
        |> Qx.run()
        |> Map.fetch!(:probabilities)
        |> Nx.to_flat_list()

      assert_in_delta Enum.at(probs, 0), 1.0, 1.0e-5
    end

    test "non-numeric theta raises ArgumentError" do
      qc = QuantumCircuit.new(2, 0)

      assert_raise ArgumentError, fn ->
        Operations.cry(qc, 0, 1, :not_a_number)
      end
    end
  end

  describe "crz/4" do
    test "emits {:crz, [c, t], [theta]}" do
      qc = QuantumCircuit.new(2, 0) |> Operations.crz(0, 1, :math.pi())

      assert [{:crz, [0, 1], _params}] = QuantumCircuit.get_instructions(qc)
    end

    test "CRz(0) is identity in probability" do
      probs =
        QuantumCircuit.new(2, 0)
        |> Operations.h(0)
        |> Operations.h(1)
        |> Operations.crz(0, 1, 0.0)
        |> Qx.run()
        |> Map.fetch!(:probabilities)
        |> Nx.to_flat_list()

      # Equal superposition over 4 states
      Enum.each(0..3, fn i ->
        assert_in_delta Enum.at(probs, i), 0.25, 1.0e-5
      end)
    end

    test "CRz only changes phase, not probabilities" do
      # Even with a non-trivial angle, probabilities should be unchanged
      # vs the no-CRz version, because Rz is diagonal in the computational basis.
      probs =
        QuantumCircuit.new(2, 0)
        |> Operations.h(0)
        |> Operations.h(1)
        |> Operations.crz(0, 1, :math.pi() / 3)
        |> Qx.run()
        |> Map.fetch!(:probabilities)
        |> Nx.to_flat_list()

      Enum.each(0..3, fn i ->
        assert_in_delta Enum.at(probs, i), 0.25, 1.0e-5
      end)
    end

    test "CRz(π) phase is observable via H ; CRz(π) ; H interference" do
      # Phase-sensitive test: a wrong (or no-op) CRz would not affect the
      # target after H ; H = I, so the final state stays |10⟩ (index 2,
      # prob 1.0). The correct CRz(π) rotates the target's |+⟩ to |−⟩
      # (modulo global phase) on the control=|1⟩ branch, so the second H
      # maps |−⟩ → |1⟩, landing at |11⟩ (index 3, prob 1.0).
      probs =
        QuantumCircuit.new(2, 0)
        |> Operations.x(0)
        |> Operations.h(1)
        |> Operations.crz(0, 1, :math.pi())
        |> Operations.h(1)
        |> Qx.run()
        |> Map.fetch!(:probabilities)
        |> Nx.to_flat_list()

      # A no-op CRz would give |10⟩ (index 2). Correct CRz(π) gives |11⟩.
      assert_in_delta Enum.at(probs, 3), 1.0, 1.0e-5
      assert_in_delta Enum.at(probs, 2), 0.0, 1.0e-5
    end

    test "non-numeric theta raises ArgumentError" do
      qc = QuantumCircuit.new(2, 0)

      assert_raise ArgumentError, fn ->
        Operations.crz(qc, 0, 1, :not_a_number)
      end
    end
  end

  describe "all controlled rotations: validation parity with cx/3" do
    for gate <- [:cy, :crx, :cry, :crz] do
      @gate gate

      test "#{@gate}: control == target raises Qx.QubitIndexError" do
        qc = QuantumCircuit.new(2, 0)

        assert_raise Qx.QubitIndexError, ~r/distinct/, fn ->
          case @gate do
            :cy -> Operations.cy(qc, 0, 0)
            :crx -> Operations.crx(qc, 0, 0, 0.5)
            :cry -> Operations.cry(qc, 0, 0, 0.5)
            :crz -> Operations.crz(qc, 0, 0, 0.5)
          end
        end
      end

      test "#{@gate}: negative qubit raises Qx.QubitIndexError" do
        qc = QuantumCircuit.new(2, 0)

        assert_raise Qx.QubitIndexError, ~r/Qubit index -1/, fn ->
          case @gate do
            :cy -> Operations.cy(qc, -1, 1)
            :crx -> Operations.crx(qc, -1, 1, 0.5)
            :cry -> Operations.cry(qc, -1, 1, 0.5)
            :crz -> Operations.crz(qc, -1, 1, 0.5)
          end
        end
      end
    end
  end
end
