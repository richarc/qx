defmodule Qx.Export.OpenQASM.RoundTripTest do
  use ExUnit.Case, async: true

  alias Qx.Export.OpenQASM
  alias Qx.QuantumCircuit
  alias Qx.Simulation

  @tolerance 1.0e-10
  @fixture_dir Path.expand("../../../fixtures/qasm", __DIR__)

  defp drop_measurements(%QuantumCircuit{} = circuit) do
    instructions =
      Enum.reject(circuit.instructions, fn
        {:measure, _, _} -> true
        _ -> false
      end)

    %{circuit | instructions: instructions, measurements: [], measured_qubits: MapSet.new()}
  end

  defp simulate_state!(circuit) do
    circuit
    |> drop_measurements()
    |> Simulation.get_state()
  end

  defp states_equal?(a, b) do
    diff = a |> Nx.subtract(b) |> Nx.abs() |> Nx.reduce_max() |> Nx.to_number()
    diff < @tolerance
  end

  def build_bell do
    Qx.create_circuit(2, 2)
    |> Qx.h(0)
    |> Qx.cx(0, 1)
  end

  def build_ghz3 do
    Qx.create_circuit(3, 3)
    |> Qx.h(0)
    |> Qx.cx(0, 1)
    |> Qx.cx(1, 2)
  end

  def build_qft3 do
    Qx.create_circuit(3)
    |> Qx.h(0)
    |> Qx.cp(1, 0, :math.pi() / 2)
    |> Qx.cp(2, 0, :math.pi() / 4)
    |> Qx.h(1)
    |> Qx.cp(2, 1, :math.pi() / 2)
    |> Qx.h(2)
    |> Qx.swap(0, 2)
  end

  def build_mixed_parametric do
    Qx.create_circuit(2)
    |> Qx.h(0)
    |> Qx.rx(1, :math.pi() / 3)
    |> Qx.ry(0, :math.pi() / 5)
    |> Qx.cx(0, 1)
    |> Qx.rz(1, :math.pi() / 7)
    |> Qx.phase(0, :math.pi() / 4)
  end

  # Grover (2 qubits) searching for |11>: H ⊗ H, oracle (CZ), then diffuser.
  def build_grover2 do
    Qx.create_circuit(2)
    |> Qx.h(0)
    |> Qx.h(1)
    |> Qx.cz(0, 1)
    |> Qx.h(0)
    |> Qx.h(1)
    |> Qx.x(0)
    |> Qx.x(1)
    |> Qx.cz(0, 1)
    |> Qx.x(0)
    |> Qx.x(1)
    |> Qx.h(0)
    |> Qx.h(1)
  end

  # Deutsch-Jozsa, balanced f(x) = x[0], 3 qubits, classical bits dropped
  # before statevector comparison.
  def build_ibm_example do
    Qx.create_circuit(3, 2)
    |> Qx.x(2)
    |> Qx.h(0)
    |> Qx.h(1)
    |> Qx.h(2)
    |> Qx.cx(0, 2)
    |> Qx.h(0)
    |> Qx.h(1)
    |> Qx.measure(0, 0)
    |> Qx.measure(1, 1)
  end

  describe "to_qasm |> from_qasm" do
    for {name, builder} <- [
          bell: :build_bell,
          ghz3: :build_ghz3,
          qft3: :build_qft3,
          mixed: :build_mixed_parametric,
          grover2: :build_grover2,
          ibm_example: :build_ibm_example
        ] do
      test "#{name}: state vectors match within #{@tolerance}" do
        # credo:disable-for-next-line Credo.Check.Refactor.Apply
        original = apply(__MODULE__, unquote(builder), [])
        qasm = OpenQASM.to_qasm(original)

        {:ok, reimported} = OpenQASM.from_qasm(qasm)

        original_state = simulate_state!(original)
        reimported_state = simulate_state!(reimported)

        assert states_equal?(original_state, reimported_state),
               "round-trip statevector mismatch for #{unquote(name)}"
      end
    end
  end

  describe "fixtures parse and round-trip to runnable circuits" do
    @fixtures_with_builder [
      {"bell", :build_bell},
      {"ghz3", :build_ghz3},
      {"qft3", :build_qft3},
      {"grover2", :build_grover2},
      {"ibm_example", :build_ibm_example}
    ]

    for {fixture, builder} <- @fixtures_with_builder do
      test "#{fixture}.qasm parses and matches the Qx-built equivalent" do
        path = Path.join(@fixture_dir, "#{unquote(fixture)}.qasm")
        {:ok, parsed} = OpenQASM.from_qasm(File.read!(path))
        # credo:disable-for-next-line Credo.Check.Refactor.Apply
        built = apply(__MODULE__, unquote(builder), [])

        assert states_equal?(simulate_state!(built), simulate_state!(parsed)),
               "fixture/built statevector mismatch for #{unquote(fixture)}"
      end
    end
  end
end
