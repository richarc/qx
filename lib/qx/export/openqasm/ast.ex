defmodule Qx.Export.OpenQASM.AST do
  @moduledoc """
  Documentation of the AST node shapes produced by `Qx.Export.OpenQASM.Parser`
  and consumed by `Qx.Export.OpenQASM.Lowering` and
  `Qx.Export.OpenQASM.Codegen`.

  AST nodes are tagged tuples. Every node carries a 1-based `:line` (and where
  meaningful, `:column`) in its trailing keyword list so error messages can
  point at the original source.

  ## Program

      {:program, [statement, ...]}

  ## Top-level statements

      {:openqasm_version, version :: String.t(), line: pos_integer()}
      {:include, path :: String.t(), line: pos_integer()}
      {:qreg_decl, name :: String.t(), size :: pos_integer(), line: pos_integer()}
      {:creg_decl, name :: String.t(), size :: pos_integer(), line: pos_integer()}
      {:gate_call, name :: String.t(), params :: [expr], qubits :: [qubit_ref],
       line: pos_integer()}
      {:measure, qubit :: qubit_ref, target :: cbit_ref, line: pos_integer()}
      {:barrier, qubits :: [qubit_ref] | {:all, register :: String.t()},
       line: pos_integer()}
      {:c_if, cbit :: cbit_ref, value :: non_neg_integer(),
       body :: [statement], line: pos_integer()}
      {:gate_def, name :: String.t(), params :: [String.t()],
       qubits :: [String.t()], body :: [statement], line: pos_integer()}

  ## References

      {:qubit_ref, register :: String.t(), index :: non_neg_integer()}
      {:cbit_ref, register :: String.t(), index :: non_neg_integer()}

  ## Parameter expressions

      {:expr, :pi}
      {:expr, number}                          # literal float or integer
      {:expr, :neg, [expr]}                    # unary minus
      {:expr, :add, [expr, expr]}
      {:expr, :sub, [expr, expr]}
      {:expr, :mul, [expr, expr]}
      {:expr, :div, [expr, expr]}
      {:expr, :call, [function_name, [expr, ...]]}  # sin, cos, tan, exp, ln, sqrt
      {:expr, :ident, name :: String.t()}      # gate-def parameter reference
  """
end
