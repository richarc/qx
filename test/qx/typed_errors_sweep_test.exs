defmodule Qx.TypedErrorsSweepTest do
  use ExUnit.Case, async: true

  alias Qx.Draw.SVG.Circuit, as: SvgCircuit
  alias Qx.Draw.Tables

  # Covers the Iron Law #7 sweep: the two new exceptions plus the public
  # sites that previously leaked a raw `ArgumentError`/`FunctionClauseError`
  # and had no prior assertion.

  describe "Qx.RegisterError" do
    test "exception(:empty) carries the reason and a message" do
      e = Qx.RegisterError.exception(:empty)
      assert e.reason == :empty
      assert e.message =~ "empty list"
    end

    test "exception({:invalid_qubit, q}) carries the offending qubit" do
      qubit = Nx.tensor([1.0, 1.0])
      e = Qx.RegisterError.exception({:invalid_qubit, qubit})
      assert {:invalid_qubit, ^qubit} = e.reason
      assert e.message =~ "Invalid qubit"
    end

    test "exception({:invalid_input, value}) inspects the value" do
      e = Qx.RegisterError.exception({:invalid_input, :nope})
      assert {:invalid_input, :nope} = e.reason
      assert e.message =~ "Qx.Register or Nx.Tensor"
      assert e.message =~ ":nope"
    end

    test "exception(message) passes a binary straight through" do
      e = Qx.RegisterError.exception("boom")
      assert e.message == "boom"
      assert e.reason == nil
    end
  end

  describe "Qx.BasisError" do
    test "exception(value) captures the value and formats the message" do
      e = Qx.BasisError.exception(2)
      assert e.value == 2
      assert e.message == "Basis must be 0 or 1, got: 2"
    end

    test "captures a binary value rather than treating it as a message" do
      e = Qx.BasisError.exception("x")
      assert e.value == "x"
      assert e.message =~ ~s("x")
    end
  end

  describe "register construction sites" do
    test "from_basis_states/1 rejects an empty list with Qx.RegisterError" do
      e = assert_raise Qx.RegisterError, fn -> Qx.Register.from_basis_states([]) end
      assert e.reason == :empty
    end

    test "from_basis_states/1 rejects non-binary basis values with Qx.BasisError" do
      e = assert_raise Qx.BasisError, fn -> Qx.Register.from_basis_states([0, 2, 1]) end
      assert e.value == 2
    end
  end

  describe "Qx.Qubit.from_basis/1" do
    test "rejects a non-0/1 basis with Qx.BasisError" do
      e = assert_raise Qx.BasisError, fn -> Qx.Qubit.from_basis(2) end
      assert e.value == 2
    end
  end

  describe "Qx.Draw.Tables.render/2" do
    test "rejects unknown input with Qx.RegisterError" do
      e = assert_raise Qx.RegisterError, fn -> Tables.render(:not_a_register) end
      assert {:invalid_input, :not_a_register} = e.reason
    end

    test "rejects an unsupported format with Qx.OptionError" do
      reg = Qx.Register.new(1)
      e = assert_raise Qx.OptionError, fn -> Tables.render(reg, format: :bogus) end
      assert e.option == :format
      assert e.value == :bogus
    end
  end

  describe "Qx.Draw format options" do
    test "plot/2 rejects an unsupported format with Qx.OptionError" do
      e = assert_raise Qx.OptionError, fn -> Qx.Draw.plot(%{}, format: :bogus) end
      assert e.option == :format
    end

    test "plot_counts/2 rejects an unsupported format with Qx.OptionError" do
      e = assert_raise Qx.OptionError, fn -> Qx.Draw.plot_counts(%{}, format: :bogus) end
      assert e.option == :format
    end

    test "bloch_sphere/2 rejects an unsupported format with Qx.OptionError" do
      qubit = Qx.Qubit.new()
      e = assert_raise Qx.OptionError, fn -> Qx.Draw.bloch_sphere(qubit, format: :bogus) end
      assert e.option == :format
    end

    test "histogram/2 rejects an unsupported format with Qx.OptionError" do
      probs = Nx.tensor([0.5, 0.5])
      e = assert_raise Qx.OptionError, fn -> Qx.Draw.histogram(probs, format: :bogus) end
      assert e.option == :format
    end
  end

  describe "Qx.Draw.SVG.Circuit.render/1 defensive validation" do
    test "exceeding 20 qubits raises Qx.QubitCountError" do
      circuit = %Qx.QuantumCircuit{num_qubits: 21, num_classical_bits: 0}
      assert_raise Qx.QubitCountError, fn -> SvgCircuit.render(circuit) end
    end

    test "an unsupported gate raises Qx.GateError" do
      circuit = %Qx.QuantumCircuit{
        num_qubits: 1,
        num_classical_bits: 0,
        instructions: [{:bogus, [0], []}]
      }

      e = assert_raise Qx.GateError, fn -> SvgCircuit.render(circuit) end
      assert e.gate == :bogus
    end

    test "an out-of-range gate qubit raises Qx.QubitIndexError" do
      circuit = %Qx.QuantumCircuit{
        num_qubits: 1,
        num_classical_bits: 0,
        instructions: [{:h, [5], []}]
      }

      assert_raise Qx.QubitIndexError, fn -> SvgCircuit.render(circuit) end
    end

    test "an out-of-range measurement qubit raises Qx.QubitIndexError" do
      circuit = %Qx.QuantumCircuit{num_qubits: 1, num_classical_bits: 1, measurements: [{5, 0}]}
      assert_raise Qx.QubitIndexError, fn -> SvgCircuit.render(circuit) end
    end

    test "an out-of-range classical bit raises Qx.ClassicalBitError" do
      circuit = %Qx.QuantumCircuit{num_qubits: 1, num_classical_bits: 1, measurements: [{0, 5}]}
      assert_raise Qx.ClassicalBitError, fn -> SvgCircuit.render(circuit) end
    end
  end
end
