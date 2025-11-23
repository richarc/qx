defmodule Qx.FormatTest do
  use ExUnit.Case
  doctest Qx.Format

  alias Complex, as: C
  alias Qx.Format

  describe "complex/2" do
    test "formats positive imaginary part" do
      result = Format.complex(C.new(0.707, 0.5))
      assert result == "0.707+0.500i"
    end

    test "formats negative imaginary part" do
      result = Format.complex(C.new(1.0, -0.5))
      assert result == "1.000-0.500i"
    end

    test "formats zero complex number" do
      result = Format.complex(C.new(0.0, 0.0))
      assert result == "0.000+0.000i"
    end

    test "formats pure real number" do
      result = Format.complex(C.new(1.0, 0.0))
      assert result == "1.000+0.000i"
    end

    test "formats pure imaginary number" do
      result = Format.complex(C.new(0.0, 1.0))
      assert result == "0.000+1.000i"
    end

    test "respects custom precision" do
      result = Format.complex(C.new(0.707107, 0.5), precision: 2)
      assert result == "0.71+0.50i"
    end

    test "handles very small numbers" do
      result = Format.complex(C.new(1.0e-10, -1.0e-10))
      assert result == "0.000-0.000i"
    end

    test "handles large numbers" do
      result = Format.complex(C.new(1234.567, -9876.543))
      assert result == "1234.567-9876.543i"
    end

    test "float format option works" do
      result = Format.complex(C.new(0.707, 0.5), format: :float)
      assert result == "0.707+0.5i"
    end
  end

  describe "basis_state/2" do
    test "formats |0⟩ for single qubit" do
      assert Format.basis_state(0, 1) == "|0⟩"
    end

    test "formats |1⟩ for single qubit" do
      assert Format.basis_state(1, 1) == "|1⟩"
    end

    test "formats |00⟩ for two qubits" do
      assert Format.basis_state(0, 2) == "|00⟩"
    end

    test "formats |01⟩ for two qubits" do
      assert Format.basis_state(1, 2) == "|01⟩"
    end

    test "formats |10⟩ for two qubits" do
      assert Format.basis_state(2, 2) == "|10⟩"
    end

    test "formats |11⟩ for two qubits" do
      assert Format.basis_state(3, 2) == "|11⟩"
    end

    test "formats |101⟩ for three qubits" do
      assert Format.basis_state(5, 3) == "|101⟩"
    end

    test "formats |111⟩ for three qubits" do
      assert Format.basis_state(7, 3) == "|111⟩"
    end

    test "handles larger qubit systems" do
      # |1010⟩ in 4-qubit system
      assert Format.basis_state(10, 4) == "|1010⟩"
    end

    test "pads with leading zeros correctly" do
      # |001⟩ in 3-qubit system (index 1)
      assert Format.basis_state(1, 3) == "|001⟩"
    end
  end

  describe "dirac_notation/2" do
    test "formats Bell state |Φ+⟩" do
      # (|00⟩ + |11⟩)/√2
      amplitudes = [
        {"|00⟩", C.new(0.707, 0.0), 0.5},
        {"|01⟩", C.new(0.0, 0.0), 0.0},
        {"|10⟩", C.new(0.0, 0.0), 0.0},
        {"|11⟩", C.new(0.707, 0.0), 0.5}
      ]

      result = Format.dirac_notation(amplitudes)
      assert result == "0.707|00⟩ + 0.707|11⟩"
    end

    test "formats superposition state (|0⟩ + |1⟩)/√2" do
      amplitudes = [
        {"|0⟩", C.new(0.707, 0.0), 0.5},
        {"|1⟩", C.new(0.707, 0.0), 0.5}
      ]

      result = Format.dirac_notation(amplitudes)
      assert result == "0.707|0⟩ + 0.707|1⟩"
    end

    test "formats |0⟩ state" do
      amplitudes = [
        {"|0⟩", C.new(1.0, 0.0), 1.0},
        {"|1⟩", C.new(0.0, 0.0), 0.0}
      ]

      result = Format.dirac_notation(amplitudes)
      assert result == "1.000|0⟩"
    end

    test "filters out near-zero amplitudes" do
      amplitudes = [
        {"|00⟩", C.new(0.707, 0.0), 0.5},
        {"|01⟩", C.new(0.0, 0.0), 1.0e-10},
        {"|10⟩", C.new(0.707, 0.0), 0.5},
        {"|11⟩", C.new(0.0, 0.0), 1.0e-10}
      ]

      result = Format.dirac_notation(amplitudes)
      assert result == "0.707|00⟩ + 0.707|10⟩"
    end

    test "respects custom threshold" do
      amplitudes = [
        {"|0⟩", C.new(0.999, 0.0), 0.998},
        {"|1⟩", C.new(0.045, 0.0), 0.002}
      ]

      # With default threshold, both show
      result1 = Format.dirac_notation(amplitudes)
      assert result1 =~ "|0⟩"
      assert result1 =~ "|1⟩"

      # With higher threshold, only first shows
      result2 = Format.dirac_notation(amplitudes, threshold: 0.01)
      assert result2 == "0.999|0⟩"
    end

    test "respects custom precision" do
      amplitudes = [
        {"|0⟩", C.new(0.707107, 0.0), 0.5},
        {"|1⟩", C.new(0.707107, 0.0), 0.5}
      ]

      result = Format.dirac_notation(amplitudes, precision: 2)
      assert result == "0.71|0⟩ + 0.71|1⟩"
    end

    test "handles GHZ state (|000⟩ + |111⟩)/√2" do
      amplitudes = [
        {"|000⟩", C.new(0.707, 0.0), 0.5},
        {"|001⟩", C.new(0.0, 0.0), 0.0},
        {"|010⟩", C.new(0.0, 0.0), 0.0},
        {"|011⟩", C.new(0.0, 0.0), 0.0},
        {"|100⟩", C.new(0.0, 0.0), 0.0},
        {"|101⟩", C.new(0.0, 0.0), 0.0},
        {"|110⟩", C.new(0.0, 0.0), 0.0},
        {"|111⟩", C.new(0.707, 0.0), 0.5}
      ]

      result = Format.dirac_notation(amplitudes)
      assert result == "0.707|000⟩ + 0.707|111⟩"
    end

    test "handles equal superposition" do
      # All four states with equal amplitude
      amplitudes = [
        {"|00⟩", C.new(0.5, 0.0), 0.25},
        {"|01⟩", C.new(0.5, 0.0), 0.25},
        {"|10⟩", C.new(0.5, 0.0), 0.25},
        {"|11⟩", C.new(0.5, 0.0), 0.25}
      ]

      result = Format.dirac_notation(amplitudes)
      assert result == "0.500|00⟩ + 0.500|01⟩ + 0.500|10⟩ + 0.500|11⟩"
    end

    test "handles empty significant terms gracefully" do
      amplitudes = [
        {"|0⟩", C.new(0.0, 0.0), 0.0},
        {"|1⟩", C.new(0.0, 0.0), 0.0}
      ]

      result = Format.dirac_notation(amplitudes)
      assert result == "0.000|0⟩"
    end
  end

  describe "state_label/2" do
    test "handles num_qubits directly" do
      assert Format.state_label(3, 2) == "|11⟩"
    end

    test "handles state size (power of 2)" do
      # 8 is 2^3, so 3 qubits
      assert Format.state_label(5, 8) == "|101⟩"
    end

    test "treats small numbers as num_qubits" do
      assert Format.state_label(1, 2) == "|01⟩"
    end

    test "handles 4-dimensional space (2 qubits)" do
      assert Format.state_label(3, 4) == "|11⟩"
    end

    test "handles 16-dimensional space (4 qubits)" do
      assert Format.state_label(10, 16) == "|1010⟩"
    end
  end

  describe "integration with quantum states" do
    test "formats Hadamard superposition correctly" do
      # After H gate on |0⟩
      amplitudes = [
        {"|0⟩", C.new(0.707, 0.0), 0.5},
        {"|1⟩", C.new(0.707, 0.0), 0.5}
      ]

      result = Format.dirac_notation(amplitudes)
      assert result == "0.707|0⟩ + 0.707|1⟩"
    end

    test "formats phase states with complex amplitudes" do
      # State with phase
      amplitudes = [
        {"|0⟩", C.new(0.707, 0.0), 0.5},
        {"|1⟩", C.new(0.0, 0.707), 0.5}
      ]

      # Now dirac_notation shows the phase
      result = Format.dirac_notation(amplitudes)
      assert result == "0.707|0⟩ + (0.000+0.707i)|1⟩"
    end

    test "formats minus state correctly" do
      # State |-⟩
      amplitudes = [
        {"|0⟩", C.new(0.707, 0.0), 0.5},
        {"|1⟩", C.new(-0.707, 0.0), 0.5}
      ]

      result = Format.dirac_notation(amplitudes)
      assert result == "0.707|0⟩ - 0.707|1⟩"
    end
  end
end
