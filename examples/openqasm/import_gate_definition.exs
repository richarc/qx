# OpenQASM Gate Definition → Elixir Function
#
# Demonstrates `Qx.Export.OpenQASM.from_qasm_function/1` converting a
# `gate name(p) a, b { ... }` definition into compilable Elixir source.
# Useful when storing user-supplied gate definitions for later replay
# (see qxportal).
#
# Run with:  elixir examples/openqasm/import_gate_definition.exs

alias Qx.Export.OpenQASM

# A parametric gate definition in QASM 3.0.
qasm = """
OPENQASM 3.0;
include "stdgates.inc";

gate myrxz(theta, phi) a, b {
  rx(theta) a;
  cx a, b;
  rz(phi) b;
}
"""

# Parse and emit Elixir source.
{:ok, %{name: name, arity: arity, source: source}} =
  OpenQASM.from_qasm_function(qasm)

IO.puts("Function name: #{name}")
IO.puts("Arity: #{arity}")
IO.puts("\n--- Generated Elixir source ---")
IO.puts(source)

# Compile it into a real module and call it.
module_source = """
defmodule Demo.UserGates do
  #{source}
end
"""

[{module, _bin} | _] = Code.compile_string(module_source)

circuit =
  Qx.create_circuit(2)
  |> module.myrxz(:math.pi() / 3, :math.pi() / 4, 0, 1)

IO.puts("\nCircuit after applying user-defined gate:")
IO.inspect(circuit.instructions)

# Out-of-scope features raise typed errors. v1 rejects gate modifiers
# (`inv @`, `pow @`, `ctrl @`, `negctrl @`) and nested user-defined gate
# references.
case OpenQASM.from_qasm_function("""
     OPENQASM 3.0;
     gate bad a, b {
       ctrl @ h a;
     }
     """) do
  {:ok, _} ->
    IO.puts("\nUnexpectedly succeeded — should have rejected modifier")

  {:error, %Qx.QasmUnsupportedError{} = e} ->
    IO.puts("\nModifier rejected as expected:")
    IO.puts("  #{Exception.message(e)}")
end
