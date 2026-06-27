defmodule Qx.Validation do
  @moduledoc false

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

  # Validates normalization of a state vector. Raises Qx.StateNormalizationError
  # if total probability is not 1.0 within `tolerance` (default 1.0e-6).
  # Internal contract used by `Qx.Simulation` norm-drift guard.
  @doc false
  def validate_normalized!(state, tolerance \\ 1.0e-6) do
    probs = Qx.Math.probabilities(state)
    total = Nx.sum(probs) |> Nx.to_number()

    if abs(total - 1.0) > tolerance do
      raise Qx.StateNormalizationError, {total, tolerance}
    end

    :ok
  end

  # Validates a qubit index is in 0..(num_qubits-1). Raises Qx.QubitIndexError
  # on out-of-range or negative index. Internal Iron Law #7 contract.
  @doc false
  def validate_qubit_index!(index, num_qubits)
      when is_integer(index) and is_integer(num_qubits) do
    if index < 0 or index >= num_qubits do
      raise Qx.QubitIndexError, {index, num_qubits}
    end

    :ok
  end

  # Validates every qubit index in `indices` is in range. Raises Qx.QubitIndexError
  # on the first offender.
  @doc false
  def validate_qubit_indices!(indices, num_qubits) when is_list(indices) do
    Enum.each(indices, &validate_qubit_index!(&1, num_qubits))
    :ok
  end

  # Validates all qubit indices in a list are distinct. Raises
  # Qx.QubitIndexError with the duplicate-containing list on violation.
  @doc false
  def validate_qubits_different!(qubits) when is_list(qubits) do
    if length(Enum.uniq(qubits)) != length(qubits) do
      raise Qx.QubitIndexError, {:duplicate, qubits}
    end

    :ok
  end

  # Validates a classical bit index is in 0..(num_bits-1). Raises
  # Qx.ClassicalBitError on out-of-range.
  @doc false
  def validate_classical_bit!(index, num_bits) when is_integer(index) and is_integer(num_bits) do
    if index < 0 or index >= num_bits do
      raise Qx.ClassicalBitError, {index, num_bits}
    end

    :ok
  end

  # Validates state vector shape matches `expected_size`. Raises
  # Qx.StateShapeError on mismatch.
  @doc false
  def validate_state_shape!(state, expected_size) do
    actual_size = Nx.axis_size(state, 0)

    if actual_size != expected_size do
      raise Qx.StateShapeError, {actual_size, expected_size}
    end

    :ok
  end

  # Validates angle/parameter is a number. Raises Qx.ParameterError on
  # non-number.
  @doc false
  def validate_parameter!(param) when is_number(param), do: :ok

  def validate_parameter!(param) do
    raise Qx.ParameterError, param
  end

  # Validates qubit count is in 1..20 (the documented Qx limit). Raises
  # Qx.QubitCountError on violation. Called from `Qx.Register.new/1` and
  # `Qx.QuantumCircuit.new/1,2` (the latter wired in Phase A — see plan
  # `api-cleanup-phase-a`).
  @doc false
  def validate_num_qubits!(num_qubits) when is_integer(num_qubits) do
    if num_qubits < 1 or num_qubits > 20 do
      raise Qx.QubitCountError, {num_qubits, 1, 20}
    end

    :ok
  end

  # Validates the `:renormalize` option for `Qx.Simulation.run/2`. Accepts
  # `false`, `true`, or a positive integer; returns the value unchanged.
  # Raises Qx.OptionError on anything else.
  @doc false
  @spec validate_renormalize!(term()) :: false | true | pos_integer()
  def validate_renormalize!(false), do: false
  def validate_renormalize!(true), do: true
  def validate_renormalize!(n) when is_integer(n) and n > 0, do: n

  def validate_renormalize!(value) do
    raise Qx.OptionError,
          {:renormalize, value, "Expected false, true, or a positive integer."}
  end
end
