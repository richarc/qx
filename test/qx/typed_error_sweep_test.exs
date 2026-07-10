defmodule Qx.TypedErrorSweep3Test do
  use ExUnit.Case, async: true

  alias Qx.{Operations, Patterns, SimulationResult, StateInit}

  # Typed-error sweep #3 (v0.11). Fallback clauses route previously-raw
  # FunctionClauseError escapes onto the typed Qx.*Error family. Non-breaking:
  # every input asserted here crashes on `main` today (see plan probe table).
  # No existing tests are modified.

  describe "create_circuit non-integer / negative classical bits" do
    test "non-integer num_qubits raises Qx.QubitCountError" do
      e = assert_raise Qx.QubitCountError, fn -> Qx.create_circuit("2") end
      assert e.count == "2"
    end

    test "non-integer num_classical_bits raises Qx.ClassicalBitError" do
      assert_raise Qx.ClassicalBitError, fn -> Qx.create_circuit(2, "0") end
    end

    test "negative num_classical_bits raises Qx.ClassicalBitError" do
      assert_raise Qx.ClassicalBitError, fn -> Qx.create_circuit(2, -1) end
    end
  end

  describe "single/two-qubit builders reject non-integer qubit indices" do
    setup do: %{qc: Qx.create_circuit(2, 2)}

    test "h(qc, \"0\") raises Qx.QubitIndexError", %{qc: qc} do
      e = assert_raise Qx.QubitIndexError, fn -> Qx.h(qc, "0") end
      assert e.qubit == "0"
    end

    test "cx(qc, \"0\", 1) raises Qx.QubitIndexError", %{qc: qc} do
      e = assert_raise Qx.QubitIndexError, fn -> Qx.cx(qc, "0", 1) end
      assert e.qubit == "0"
    end
  end

  describe "Patterns bell/ghz reject invalid selector / count" do
    test "bell_state_circuit(:bogus) raises Qx.OptionError" do
      e = assert_raise Qx.OptionError, fn -> Patterns.bell_state_circuit(:bogus) end
      assert e.option == :which
    end

    test "ghz_state_circuit(1) raises Qx.QubitCountError" do
      assert_raise Qx.QubitCountError, fn -> Patterns.ghz_state_circuit(1) end
    end

    test "ghz_state_circuit(:x) raises Qx.QubitCountError" do
      assert_raise Qx.QubitCountError, fn -> Patterns.ghz_state_circuit(:x) end
    end
  end

  describe "Operations.c_if rejects non-integer classical_bit" do
    test "c_if(qc, \"0\", 0, fun) raises Qx.ClassicalBitError" do
      qc = Qx.create_circuit(2, 2)

      assert_raise Qx.ClassicalBitError, fn ->
        Operations.c_if(qc, "0", 0, fn c -> Qx.x(c, 1) end)
      end
    end
  end

  describe "StateInit.basis_state survivor validation" do
    test "non-integer index raises Qx.BasisError" do
      e = assert_raise Qx.BasisError, fn -> StateInit.basis_state("0", 2) end
      assert e.reason == :not_an_integer
    end

    test "negative index raises Qx.BasisError" do
      assert_raise Qx.BasisError, fn -> StateInit.basis_state(-1, 2) end
    end

    test "index >= dimension raises Qx.BasisError" do
      assert_raise Qx.BasisError, fn -> StateInit.basis_state(5, 2) end
    end

    test "dimension < 1 raises Qx.BasisError" do
      assert_raise Qx.BasisError, fn -> StateInit.basis_state(0, 0) end
    end

    test "valid index still builds the basis state (survivor path)" do
      probs = StateInit.basis_state(3, 4) |> Qx.Math.probabilities() |> Nx.to_flat_list()
      assert Enum.at(probs, 3) == 1.0
    end
  end

  describe "SimulationResult.filter_by_probability threshold widening" do
    setup do
      %{
        result: %SimulationResult{
          probabilities: Nx.tensor([0.5, 0.5, 0.0, 0.0]),
          classical_bits: [[0, 0]],
          state: Nx.tensor([0.707, 0.0, 0.0, 0.707]),
          shots: 100,
          counts: %{"00" => 52, "11" => 48}
        }
      }
    end

    test "integer 1 is accepted and applies the widened arithmetic", %{result: result} do
      # threshold 1 -> min_count = shots = 100; nothing in `result` reaches 100
      assert SimulationResult.filter_by_probability(result, 1) == %{}

      # a certain outcome (count == shots) IS kept — pins min_count = 1 * shots,
      # not just "did not raise"
      certain = %SimulationResult{result | counts: %{"00" => 100}, shots: 100}
      assert SimulationResult.filter_by_probability(certain, 1) == %{"00" => 100}
    end

    test "integer 0 is a valid probability and returns all", %{result: result} do
      assert SimulationResult.filter_by_probability(result, 0) == %{"00" => 52, "11" => 48}
    end

    test "out-of-range 2 raises Qx.OptionError", %{result: result} do
      e = assert_raise Qx.OptionError, fn -> SimulationResult.filter_by_probability(result, 2) end
      assert e.option == :threshold
    end

    test "non-number threshold raises Qx.OptionError", %{result: result} do
      assert_raise Qx.OptionError, fn -> SimulationResult.filter_by_probability(result, "x") end
    end
  end

  describe "Math.normalize zero-vector guard" do
    test "zero vector raises Qx.StateNormalizationError" do
      assert_raise Qx.StateNormalizationError, fn ->
        Qx.Math.normalize(Nx.tensor([0.0, 0.0]))
      end
    end

    test "valid f32 vector still normalizes (survivor path)" do
      out = Qx.Math.normalize(Nx.tensor([1.0, 1.0])) |> Nx.to_flat_list()
      assert_in_delta Enum.at(out, 0), 0.70710677, 1.0e-6
      assert_in_delta Enum.at(out, 1), 0.70710677, 1.0e-6
    end

    test "valid c64 vector still normalizes to 1/√2 amplitudes (renorm survivor path)" do
      v = Nx.tensor([Complex.new(1.0, 0.0), Complex.new(1.0, 0.0)], type: :c64)
      out = Qx.Math.normalize(v)
      assert Nx.type(out) == {:c, 64}

      reals = out |> Nx.real() |> Nx.to_flat_list()
      imags = out |> Nx.imag() |> Nx.to_flat_list()
      assert_in_delta Enum.at(reals, 0), 0.70710677, 1.0e-6
      assert_in_delta Enum.at(reals, 1), 0.70710677, 1.0e-6
      assert Enum.all?(imags, &(abs(&1) < 1.0e-6))
    end
  end

  describe "rx/ry/rz/phase validate parameters at build time" do
    setup do: %{qc: Qx.create_circuit(1, 0)}

    for op <- [:rx, :ry, :rz, :phase] do
      test "#{op}(qc, 0, \"pi\") raises Qx.ParameterError at build time", %{qc: qc} do
        assert_raise Qx.ParameterError, fn -> apply(Qx, unquote(op), [qc, 0, "pi"]) end
      end
    end
  end
end
