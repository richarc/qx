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

  alias Complex, as: C

  @doc """
  Applies a single-qubit gate to a state vector.

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
    cond do
      num_qubits == 1 ->
        # Simple case: single qubit, direct matrix multiplication
        Nx.dot(gate_matrix, state)

      num_qubits > 1 ->
        # Multi-qubit case: expand gate to full system size
        full_gate_matrix = build_full_gate_matrix(gate_matrix, target_qubit, num_qubits)
        Nx.dot(full_gate_matrix, state)
    end
  end

  @doc """
  Applies a two-qubit gate (like CNOT) to a state vector.

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
    gate_matrix = build_cnot_matrix(control_qubit, target_qubit, num_qubits)
    Nx.dot(gate_matrix, state)
  end

  @doc """
  Applies a Toffoli (CCX) gate to a state vector.

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
    gate_matrix = build_toffoli_matrix(control1, control2, target, num_qubits)
    Nx.dot(gate_matrix, state)
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  # Builds a full n-qubit gate matrix from a 2x2 single-qubit gate
  defp build_full_gate_matrix(gate_2x2, target_qubit, num_qubits) do
    # We need to build a 2^n x 2^n matrix
    # This is the tensor product with qubit ordering convention:
    # Qubit 0 is rightmost (LSB), so we build from highest to lowest
    # Gate for qubit i: I_{n-1} ⊗ ... ⊗ I_{i+1} ⊗ gate_i ⊗ I_{i-1} ⊗ ... ⊗ I_0

    identity = Qx.Gates.identity()

    # Build list of matrices from highest qubit index to lowest
    # This matches the standard quantum computing convention
    matrices =
      for i <- (num_qubits - 1)..0//-1 do
        if i == target_qubit, do: gate_2x2, else: identity
      end

    # Compute tensor product of all matrices
    tensor_product_matrices(matrices)
  end

  # Computes tensor product of a list of 2x2 matrices
  defp tensor_product_matrices([single_matrix]) do
    single_matrix
  end

  defp tensor_product_matrices([first | rest]) do
    rest_product = tensor_product_matrices(rest)
    kronecker_product_matrix(first, rest_product)
  end

  # Kronecker product for matrices
  defp kronecker_product_matrix(mat_a, mat_b) do
    # mat_a is 2x2, mat_b is 2^n x 2^n
    size_a = 2
    size_b = Nx.axis_size(mat_b, 0)
    result_size = size_a * size_b

    # Build result matrix
    result =
      for i <- 0..(result_size - 1), j <- 0..(result_size - 1) do
        # Determine which element of mat_a and mat_b to multiply
        a_row = div(i, size_b)
        a_col = div(j, size_b)
        b_row = rem(i, size_b)
        b_col = rem(j, size_b)

        a_elem = Nx.to_number(mat_a[a_row][a_col])
        b_elem = Nx.to_number(mat_b[b_row][b_col])

        Complex.multiply(a_elem, b_elem)
      end
      |> Nx.tensor(type: :c64)
      |> Nx.reshape({result_size, result_size})

    result
  end

  # Builds a CNOT gate matrix for n qubits
  defp build_cnot_matrix(control_qubit, target_qubit, num_qubits) do
    state_size = trunc(:math.pow(2, num_qubits))

    # Build the CNOT matrix directly
    result =
      for i <- 0..(state_size - 1), j <- 0..(state_size - 1) do
        # Check if control qubit is |1⟩ in state i
        control_bit = Bitwise.band(Bitwise.bsr(i, control_qubit), 1)

        if control_bit == 1 do
          # If control is |1⟩, apply X to target: flip target bit
          j_with_flipped_target = Bitwise.bxor(i, Bitwise.bsl(1, target_qubit))

          # Matrix element is 1 if j matches the flipped state
          if j == j_with_flipped_target do
            C.new(1.0, 0.0)
          else
            C.new(0.0, 0.0)
          end
        else
          # If control is |0⟩, identity: keep state unchanged
          if i == j do
            C.new(1.0, 0.0)
          else
            C.new(0.0, 0.0)
          end
        end
      end
      |> Nx.tensor(type: :c64)
      |> Nx.reshape({state_size, state_size})

    result
  end

  # Builds a Toffoli gate matrix for n qubits
  defp build_toffoli_matrix(control1, control2, target, num_qubits) do
    state_size = trunc(:math.pow(2, num_qubits))

    # Build the Toffoli matrix directly
    result =
      for i <- 0..(state_size - 1), j <- 0..(state_size - 1) do
        # Check if both control qubits are |1⟩ in state i
        control1_bit = Bitwise.band(Bitwise.bsr(i, control1), 1)
        control2_bit = Bitwise.band(Bitwise.bsr(i, control2), 1)

        if control1_bit == 1 and control2_bit == 1 do
          # If both controls are |1⟩, apply X to target: flip target bit
          j_with_flipped_target = Bitwise.bxor(i, Bitwise.bsl(1, target))

          # Matrix element is 1 if j matches the flipped state
          if j == j_with_flipped_target do
            C.new(1.0, 0.0)
          else
            C.new(0.0, 0.0)
          end
        else
          # If any control is |0⟩, identity: keep state unchanged
          if i == j do
            C.new(1.0, 0.0)
          else
            C.new(0.0, 0.0)
          end
        end
      end
      |> Nx.tensor(type: :c64)
      |> Nx.reshape({state_size, state_size})

    result
  end
end
