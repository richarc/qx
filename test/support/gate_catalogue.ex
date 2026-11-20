defmodule Qx.Test.GateCatalogue do
  @moduledoc false

  # One circuit per public circuit-building function in `Qx.Operations` and
  # `Qx.Patterns`. The draw tests run every entry instead of listing gate
  # atoms by hand, so a gate added to a producer without a matching entry
  # here fails `uncovered/0`, and one added here without drawer support
  # fails the draw tests.

  alias Qx.{Operations, Patterns, QuantumCircuit}

  # Public functions of the two producer modules that do not append
  # instructions: the taps run a callback and return the circuit as it is.
  @not_producers [:tap_circuit, :tap_state, :tap_probabilities]

  @doc "`{module, function, circuit}` for every producer function."
  def circuits do
    half = :math.pi() / 2

    [
      {Operations, :h, QuantumCircuit.new(1) |> Operations.h(0)},
      {Operations, :x, QuantumCircuit.new(1) |> Operations.x(0)},
      {Operations, :y, QuantumCircuit.new(1) |> Operations.y(0)},
      {Operations, :z, QuantumCircuit.new(1) |> Operations.z(0)},
      {Operations, :s, QuantumCircuit.new(1) |> Operations.s(0)},
      {Operations, :sdg, QuantumCircuit.new(1) |> Operations.sdg(0)},
      {Operations, :t, QuantumCircuit.new(1) |> Operations.t(0)},
      {Operations, :tdg, QuantumCircuit.new(1) |> Operations.tdg(0)},
      {Operations, :rx, QuantumCircuit.new(1) |> Operations.rx(0, half)},
      {Operations, :ry, QuantumCircuit.new(1) |> Operations.ry(0, half)},
      {Operations, :rz, QuantumCircuit.new(1) |> Operations.rz(0, half)},
      {Operations, :phase, QuantumCircuit.new(1) |> Operations.phase(0, half)},
      {Operations, :u, QuantumCircuit.new(1) |> Operations.u(0, half, 0.3, 1.1)},
      {Operations, :cx, QuantumCircuit.new(2) |> Operations.cx(0, 1)},
      {Operations, :cy, QuantumCircuit.new(2) |> Operations.cy(0, 1)},
      {Operations, :cz, QuantumCircuit.new(2) |> Operations.cz(0, 1)},
      {Operations, :cp, QuantumCircuit.new(2) |> Operations.cp(0, 1, half)},
      {Operations, :crx, QuantumCircuit.new(2) |> Operations.crx(0, 1, half)},
      {Operations, :cry, QuantumCircuit.new(2) |> Operations.cry(0, 1, half)},
      {Operations, :crz, QuantumCircuit.new(2) |> Operations.crz(0, 1, half)},
      {Operations, :swap, QuantumCircuit.new(2) |> Operations.swap(0, 1)},
      {Operations, :iswap, QuantumCircuit.new(2) |> Operations.iswap(0, 1)},
      {Operations, :ccx, QuantumCircuit.new(3) |> Operations.ccx(0, 1, 2)},
      {Operations, :cswap, QuantumCircuit.new(3) |> Operations.cswap(0, 1, 2)},
      {Operations, :barrier, QuantumCircuit.new(3) |> Operations.barrier([0, 1, 2])},
      {Operations, :measure, QuantumCircuit.new(1, 1) |> Operations.measure(0, 0)},
      {Operations, :measure_z, QuantumCircuit.new(1, 1) |> Operations.measure_z(0, 0)},
      {Operations, :measure_x, QuantumCircuit.new(1, 1) |> Operations.measure_x(0, 0)},
      {Operations, :measure_y, QuantumCircuit.new(1, 1) |> Operations.measure_y(0, 0)},
      {Operations, :c_if,
       QuantumCircuit.new(2, 1)
       |> Operations.measure(0, 0)
       |> Operations.c_if(0, 1, &Operations.x(&1, 1))},
      {Patterns, :h_all, QuantumCircuit.new(2) |> Patterns.h_all()},
      {Patterns, :x_all, QuantumCircuit.new(2) |> Patterns.x_all()},
      {Patterns, :y_all, QuantumCircuit.new(2) |> Patterns.y_all()},
      {Patterns, :z_all, QuantumCircuit.new(2) |> Patterns.z_all()},
      {Patterns, :measure_all, QuantumCircuit.new(2, 2) |> Patterns.measure_all()},
      {Patterns, :barrier_all, QuantumCircuit.new(2) |> Patterns.barrier_all()},
      {Patterns, :cx_chain, QuantumCircuit.new(3) |> Patterns.cx_chain([0, 1, 2])},
      {Patterns, :ghz, QuantumCircuit.new(3) |> Patterns.ghz([0, 1, 2])},
      {Patterns, :bell_pair, QuantumCircuit.new(2) |> Patterns.bell_pair(0, 1, :psi_minus)},
      {Patterns, :bell_state_circuit, Patterns.bell_state_circuit()},
      {Patterns, :ghz_state_circuit, Patterns.ghz_state_circuit()},
      {Patterns, :superposition_circuit, Patterns.superposition_circuit(2)}
    ]
  end

  @doc """
  Producer functions with no entry in `circuits/0`. Empty when the
  catalogue is complete.
  """
  def uncovered do
    covered = MapSet.new(circuits(), fn {module, name, _circuit} -> {module, name} end)

    for module <- [Operations, Patterns],
        {name, _arity} <- module.__info__(:functions),
        name not in @not_producers,
        not MapSet.member?(covered, {module, name}),
        uniq: true,
        do: {module, name}
  end

  @doc "Every gate atom in a circuit, including those inside `c_if` blocks."
  def atoms(%QuantumCircuit{} = circuit) do
    circuit
    |> QuantumCircuit.get_instructions()
    |> Enum.flat_map(fn
      {:c_if, _condition, sub_instructions} ->
        [:c_if | Enum.map(sub_instructions, &elem(&1, 0))]

      {name, _qubits, _params} ->
        [name]
    end)
  end

  @doc "Every gate atom any catalogue circuit contains."
  def all_atoms do
    circuits()
    |> Enum.flat_map(fn {_module, _name, circuit} -> atoms(circuit) end)
    |> Enum.uniq()
  end

  @doc """
  Catalogue entries that name a function the producer module does not
  export. Empty unless a producer was renamed or removed.
  """
  def stale do
    for {module, name, _circuit} <- circuits(),
        name not in Keyword.keys(module.__info__(:functions)),
        do: {module, name}
  end

  # The path is taken from this file, so it does not depend on the
  # directory the tests are run from.
  @lowering Path.expand("../../lib/qx/export/openqasm/lowering.ex", __DIR__)
  @external_resource @lowering

  @doc """
  The rows of the OpenQASM importer's gate table, as `{qasm name, atom
  name}` strings, read from the lowering source. The table is a private
  module attribute, so the source is the only place it can be read.
  """
  def qasm_table do
    source = File.read!(@lowering)

    ~r/"(\w+)"\s*=>\s*\{:(\w+),\s*\d+,\s*\d+\}/
    |> Regex.scan(source, capture: :all_but_first)
    |> Enum.map(fn [qasm_name, atom_name] -> {qasm_name, atom_name} end)
  end

  @doc "The instruction atoms the OpenQASM importer can emit."
  def qasm_atoms do
    qasm_table()
    |> Enum.map(fn {_qasm_name, atom_name} -> atom_name end)
    |> Enum.uniq()
    |> Enum.map(&String.to_existing_atom/1)
  end
end
