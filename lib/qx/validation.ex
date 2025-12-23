defmodule Qx.Validation do
  @moduledoc """
  Centralized validation functions for quantum operations.

  Provides consistent error handling and validation across all Qx modules.

  ## Examples

      # Validate single qubit state
      iex> q = Qx.Qubit.new()
      iex> Qx.Validation.valid_qubit?(q)
      true

      # Validate qubit index
      iex> Qx.Validation.validate_qubit_index!(0, 3)
      :ok

      iex> Qx.Validation.validate_qubit_index!(5, 3)
      ** (Qx.QubitIndexError) Qubit index 5 out of range (0..2)
  """

  @doc """
  Validates a single qubit state.

  A valid qubit must:
  - Have shape `{2}`
  - Be normalized (|α|² + |β|² = 1)

  ## Parameters
  - `state` - Nx tensor representing qubit state
  - `tolerance` - Normalization tolerance (default: 1.0e-6)

  ## Examples

      iex> q = Qx.Qubit.new()
      iex> Qx.Validation.valid_qubit?(q)
      true

      iex> invalid = Nx.tensor([Complex.new(1.0, 0.0), Complex.new(1.0, 0.0)], type: :c64)
      iex> Qx.Validation.valid_qubit?(invalid)
      false

      iex> wrong_shape = Nx.tensor([Complex.new(1.0, 0.0)], type: :c64)
      iex> Qx.Validation.valid_qubit?(wrong_shape)
      false
  """
  @spec valid_qubit?(Nx.Tensor.t(), float()) :: boolean()
  def valid_qubit?(state, tolerance \\ 1.0e-6) do
    case Nx.shape(state) do
      {2} ->
        probs = Qx.Math.probabilities(state)
        norm = Nx.sum(probs) |> Nx.to_number()
        abs(norm - 1.0) < tolerance

      _ ->
        false
    end
  end

  @doc """
  Validates a quantum register state.

  Requirements:
  - Shape must be `{2^num_qubits}`
  - Must be normalized

  ## Examples

      iex> reg = Qx.Register.new(2)
      iex> Qx.Validation.valid_register?(reg)
      true
  """
  @spec valid_register?(%{state: Nx.Tensor.t(), num_qubits: integer()}, float()) :: boolean()
  def valid_register?(%{state: state, num_qubits: num_qubits}, tolerance \\ 1.0e-6) do
    expected_size = trunc(:math.pow(2, num_qubits))
    actual_size = Nx.axis_size(state, 0)

    if actual_size != expected_size do
      false
    else
      probs = Qx.Math.probabilities(state)
      norm = Nx.sum(probs) |> Nx.to_number()
      abs(norm - 1.0) < tolerance
    end
  end

  @doc """
  Validates normalization of a state vector.

  Raises `Qx.StateNormalizationError` if not normalized within tolerance.

  ## Examples

      iex> state = Qx.Qubit.new()
      iex> Qx.Validation.validate_normalized!(state)
      :ok

      iex> invalid = Nx.tensor([Complex.new(1.0, 0.0), Complex.new(1.0, 0.0)], type: :c64)
      iex> Qx.Validation.validate_normalized!(invalid)
      ** (Qx.StateNormalizationError) State not normalized: total probability = 2.0 (expected 1.0 ± 1.0e-6)
  """
  def validate_normalized!(state, tolerance \\ 1.0e-6) do
    probs = Qx.Math.probabilities(state)
    total = Nx.sum(probs) |> Nx.to_number()

    if abs(total - 1.0) > tolerance do
      raise Qx.StateNormalizationError, {total, tolerance}
    end

    :ok
  end

  @doc """
  Validates a qubit index is within valid range for the system.

  ## Parameters
  - `index` - Qubit index to validate (0-based)
  - `num_qubits` - Total number of qubits in the system

  ## Examples

      iex> Qx.Validation.validate_qubit_index!(0, 3)
      :ok

      iex> Qx.Validation.validate_qubit_index!(2, 3)
      :ok

      iex> Qx.Validation.validate_qubit_index!(5, 3)
      ** (Qx.QubitIndexError) Qubit index 5 out of range (0..2)

      iex> Qx.Validation.validate_qubit_index!(-1, 3)
      ** (Qx.QubitIndexError) Qubit index -1 out of range (0..2)
  """
  def validate_qubit_index!(index, num_qubits)
      when is_integer(index) and is_integer(num_qubits) do
    if index < 0 or index >= num_qubits do
      raise Qx.QubitIndexError, {index, num_qubits}
    end

    :ok
  end

  @doc """
  Validates multiple qubit indices are all within valid range.

  ## Examples

      iex> Qx.Validation.validate_qubit_indices!([0, 1], 3)
      :ok

      iex> Qx.Validation.validate_qubit_indices!([0, 5], 3)
      ** (Qx.QubitIndexError) Qubit index 5 out of range (0..2)
  """
  def validate_qubit_indices!(indices, num_qubits) when is_list(indices) do
    Enum.each(indices, &validate_qubit_index!(&1, num_qubits))
    :ok
  end

  @doc """
  Validates all qubit indices in a list are different.

  ## Examples

      iex> Qx.Validation.validate_qubits_different!([0, 1, 2])
      :ok

      iex> Qx.Validation.validate_qubits_different!([0, 1, 0])
      ** (ArgumentError) All qubit indices must be different: [0, 1, 0]
  """
  def validate_qubits_different!(qubits) when is_list(qubits) do
    if length(Enum.uniq(qubits)) != length(qubits) do
      raise ArgumentError,
            "All qubit indices must be different: #{inspect(qubits)}"
    end

    :ok
  end

  @doc """
  Validates a classical bit index.

  ## Examples

      iex> Qx.Validation.validate_classical_bit!(0, 5)
      :ok

      iex> Qx.Validation.validate_classical_bit!(10, 5)
      ** (Qx.ClassicalBitError) Classical bit index 10 out of range (0..4)
  """
  def validate_classical_bit!(index, num_bits) when is_integer(index) and is_integer(num_bits) do
    if index < 0 or index >= num_bits do
      raise Qx.ClassicalBitError, {index, num_bits}
    end

    :ok
  end

  @doc """
  Validates state vector shape matches expected size.

  ## Examples

      iex> state = Qx.Qubit.new()
      iex> Qx.Validation.validate_state_shape!(state, 2)
      :ok

      iex> state = Qx.Qubit.new()
      iex> Qx.Validation.validate_state_shape!(state, 4)
      ** (ArgumentError) Invalid state shape: expected {4}, got {2}
  """
  def validate_state_shape!(state, expected_size) do
    actual_size = Nx.axis_size(state, 0)

    if actual_size != expected_size do
      raise ArgumentError,
            "Invalid state shape: expected {#{expected_size}}, got {#{actual_size}}"
    end

    :ok
  end

  @doc """
  Validates that an angle/parameter is a number.

  ## Examples

      iex> Qx.Validation.validate_parameter!(:math.pi())
      :ok

      iex> Qx.Validation.validate_parameter!("not a number")
      ** (ArgumentError) Parameter must be a number, got: "not a number"
  """
  def validate_parameter!(param) when is_number(param), do: :ok

  def validate_parameter!(param) do
    raise ArgumentError, "Parameter must be a number, got: #{inspect(param)}"
  end

  @doc """
  Validates gate name is a known gate.

  ## Examples

      iex> Qx.Validation.validate_gate_name!(:h)
      :ok

      iex> Qx.Validation.validate_gate_name!(:not_a_gate)
      ** (Qx.GateError) Unsupported gate: :not_a_gate
  """
  def validate_gate_name!(gate_name) do
    known_gates = [
      :h,
      :x,
      :y,
      :z,
      :s,
      :t,
      :rx,
      :ry,
      :rz,
      :phase,
      :cx,
      :cnot,
      :cz,
      :ccx,
      :toffoli
    ]

    if gate_name not in known_gates do
      raise Qx.GateError, {:unsupported_gate, gate_name}
    end

    :ok
  end

  @doc """
  Validates number of qubits is within supported range (1-20).

  ## Examples

      iex> Qx.Validation.validate_num_qubits!(5)
      :ok

      iex> Qx.Validation.validate_num_qubits!(0)
      ** (Qx.QubitCountError) Invalid qubit count: 0 (must be between 1 and 20)

      iex> Qx.Validation.validate_num_qubits!(25)
      ** (Qx.QubitCountError) Invalid qubit count: 25 (must be between 1 and 20)
  """
  def validate_num_qubits!(num_qubits) when is_integer(num_qubits) do
    if num_qubits < 1 or num_qubits > 20 do
      raise Qx.QubitCountError, {num_qubits, 1, 20}
    end

    :ok
  end
end
