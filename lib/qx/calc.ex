defmodule Qx.Calc do
  @moduledoc """
  Shared calculation engine for quantum gate operations.

  This module provides the core logic for applying quantum gates to state vectors,
  used by both `Qx.Qubit` (single-qubit calculation mode) and `Qx.Register`
  (multi-qubit calculation mode).

  ## Design

  The module handles:
  - Single-qubit gate application (direct matrix multiplication)
  - Multi-qubit gate application (tensor product expansion)
  - State vector transformations

  This centralizes the gate application logic in one place, making it easier to
  optimize and maintain.
  """

  @doc """
  Applies a single-qubit gate to a state vector.

  Uses optimized direct statevector manipulation from Qx.CalcFast for
  improved performance (10-1000x faster than matrix-based approach).

  ## Parameters

    * `state` - State vector (Nx tensor)
    * `gate_matrix` - 2x2 gate matrix (from Qx.Gates)
    * `target_qubit` - Index of qubit to apply gate to (0-based)
    * `num_qubits` - Total number of qubits in the system

  ## Examples

      # Single qubit (num_qubits = 1, target = 0)
      iex> state = Qx.Qubit.new()
      iex> gate = Qx.Gates.hadamard()
      iex> Qx.Calc.apply_single_qubit_gate(state, gate, 0, 1)

      # Multi-qubit register (apply H to qubit 1 in 3-qubit system)
      iex> reg = Qx.Register.new(3)
      iex> gate = Qx.Gates.hadamard()
      iex> Qx.Calc.apply_single_qubit_gate(reg.state, gate, 1, 3)
  """
  @spec apply_single_qubit_gate(Nx.Tensor.t(), Nx.Tensor.t(), non_neg_integer(), pos_integer()) ::
          Nx.Tensor.t()
  def apply_single_qubit_gate(state, gate_matrix, target_qubit, num_qubits) do
    # Use optimized direct statevector manipulation
    Qx.CalcFast.apply_single_qubit_gate(state, gate_matrix, target_qubit, num_qubits)
  end

  @doc """
  Applies a two-qubit gate (like CNOT) to a state vector.

  Uses optimized direct statevector manipulation from Qx.CalcFast for
  improved performance (avoids building 2^n x 2^n matrix).

  ## Parameters

    * `state` - State vector (Nx tensor)
    * `control_qubit` - Index of control qubit
    * `target_qubit` - Index of target qubit
    * `num_qubits` - Total number of qubits in the system

  ## Examples

      iex> reg = Qx.Register.new(2)
      iex> Qx.Calc.apply_cnot(reg.state, 0, 1, 2)
  """
  @spec apply_cnot(Nx.Tensor.t(), non_neg_integer(), non_neg_integer(), pos_integer()) ::
          Nx.Tensor.t()
  def apply_cnot(state, control_qubit, target_qubit, num_qubits) do
    # Use optimized direct statevector manipulation
    Qx.CalcFast.apply_cnot(state, control_qubit, target_qubit, num_qubits)
  end

  @doc """
  Applies a Toffoli (CCX) gate to a state vector.

  Uses optimized direct statevector manipulation from Qx.CalcFast for
  improved performance (avoids building 2^n x 2^n matrix).

  ## Parameters

    * `state` - State vector (Nx tensor)
    * `control1` - Index of first control qubit
    * `control2` - Index of second control qubit
    * `target` - Index of target qubit
    * `num_qubits` - Total number of qubits in the system
  """
  @spec apply_toffoli(
          Nx.Tensor.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          pos_integer()
        ) :: Nx.Tensor.t()
  def apply_toffoli(state, control1, control2, target, num_qubits) do
    # Use optimized direct statevector manipulation
    Qx.CalcFast.apply_toffoli(state, control1, control2, target, num_qubits)
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================
  #
  # Note: The old matrix-based implementations (build_full_gate_matrix,
  # build_cnot_matrix, build_toffoli_matrix) have been removed in favor
  # of direct statevector manipulation in Qx.CalcFast. The old approach
  # was 10-1000x slower and used significantly more memory.
  #
  # For reference or debugging, the old implementations are preserved in
  # git history (commit before EXLA optimization).
end
