defmodule Qx.Register do
  @moduledoc """
  Multi-qubit quantum register for calculation mode.

  This module provides functionality for creating and manipulating quantum registers
  containing multiple qubits. Gates are applied immediately in real-time, similar to
  `Qx.Qubit` but for multi-qubit systems.

  ## Calculation Mode - Multi-Qubit

  Calculation mode with registers allows you to work with multiple qubits directly,
  applying gates in real-time and seeing results immediately. This is perfect for:
  - Creating entangled states (Bell states, GHZ states)
  - Multi-qubit gate exploration
  - Learning quantum algorithms
  - Interactive debugging

  ## Example Workflows

      # Create a 2-qubit register and make a Bell state
      reg = Qx.Register.new(2)
        |> Qx.Register.h(0)
        |> Qx.Register.cx(0, 1)
        |> Qx.Register.show_state()

      # Create register from existing qubits
      q1 = Qx.Qubit.new(0.6, 0.8)
      q2 = Qx.Qubit.new()
      reg = Qx.Register.new([q1, q2])
        |> Qx.Register.h(0)

      # Inspect state at any point
      reg = Qx.Register.new(3)
        |> Qx.Register.h(0)
        |> Qx.Register.h(1)
        |> Qx.Register.h(2)

      probs = Qx.Register.get_probabilities(reg)
      # All 8 basis states have equal probability

  ## See Also

  - `Qx.Qubit` - Single qubit calculation mode
  - `Qx.QuantumCircuit` - Circuit mode for building quantum circuits
  """

  defstruct [:num_qubits, :state]

  @type t :: %__MODULE__{
          num_qubits: pos_integer(),
          state: Nx.Tensor.t()
        }

  alias Complex, as: C

  @doc """
  Creates a new quantum register.

  ## Parameters

  When called with an integer:
  - `num_qubits` - Number of qubits to create (all initialized to |0⟩)

  When called with a list:
  - `qubits` - List of qubit state tensors to combine via tensor product

  ## Examples

      # Create a 2-qubit register (both in |0⟩)
      iex> reg = Qx.Register.new(2)
      iex> reg.num_qubits
      2

      # Create from existing qubits
      iex> q1 = Qx.Qubit.new(0.6, 0.8)
      iex> q2 = Qx.Qubit.new()
      iex> reg = Qx.Register.new([q1, q2])
      iex> reg.num_qubits
      2
  """
  def new(num_qubits) when is_integer(num_qubits) and num_qubits > 0 do
    if num_qubits > 20 do
      raise ArgumentError, "Maximum 20 qubits supported (requested #{num_qubits})"
    end

    # Create initial state |00...0⟩
    state_size = trunc(:math.pow(2, num_qubits))

    # Initialize state vector with first element = 1, rest = 0
    initial_state =
      for i <- 0..(state_size - 1) do
        if i == 0 do
          C.new(1.0, 0.0)
        else
          C.new(0.0, 0.0)
        end
      end
      |> Nx.tensor(type: :c64)

    %__MODULE__{
      num_qubits: num_qubits,
      state: initial_state
    }
  end

  def new(qubits) when is_list(qubits) do
    if length(qubits) == 0 do
      raise ArgumentError, "Cannot create register from empty list of qubits"
    end

    if length(qubits) > 20 do
      raise ArgumentError, "Maximum 20 qubits supported (provided #{length(qubits)})"
    end

    # Validate all qubits
    Enum.each(qubits, fn qubit ->
      unless Qx.Qubit.valid?(qubit) do
        raise ArgumentError, "Invalid qubit in list - must be normalized 2-element tensor"
      end
    end)

    # Compute tensor product of all qubits
    state = tensor_product(qubits)

    %__MODULE__{
      num_qubits: length(qubits),
      state: state
    }
  end

  # Computes the tensor product (Kronecker product) of a list of qubits
  defp tensor_product([single_qubit]) do
    single_qubit
  end

  defp tensor_product([first | rest]) do
    rest_product = tensor_product(rest)
    kronecker_product(first, rest_product)
  end

  # Computes Kronecker product of two state vectors
  defp kronecker_product(state_a, state_b) do
    # state_a is {2}, state_b is {2^n}
    size_a = Nx.axis_size(state_a, 0)
    size_b = Nx.axis_size(state_b, 0)

    # Build result by iterating through all combinations
    result =
      for i <- 0..(size_a - 1), j <- 0..(size_b - 1) do
        a_elem = Nx.to_number(state_a[i])
        b_elem = Nx.to_number(state_b[j])
        Complex.multiply(a_elem, b_elem)
      end
      |> Nx.tensor(type: :c64)

    result
  end

  # ============================================================================
  # Single-Qubit Gate Operations
  # ============================================================================

  @doc """
  Applies a Hadamard gate to a specific qubit in the register.

  ## Parameters
    * `register` - The quantum register
    * `qubit_index` - Index of the qubit to apply the gate to (0-based)

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.h(0)
      iex> Qx.Register.valid?(reg)
      true
  """
  def h(%__MODULE__{} = register, qubit_index) do
    validate_qubit_index!(register, qubit_index)
    new_state = Qx.Calc.apply_single_qubit_gate(register.state, Qx.Gates.hadamard(), qubit_index, register.num_qubits)
    %{register | state: new_state}
  end

  @doc """
  Applies a Pauli-X gate to a specific qubit in the register.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.x(0)
      iex> Qx.Register.valid?(reg)
      true
  """
  def x(%__MODULE__{} = register, qubit_index) do
    validate_qubit_index!(register, qubit_index)
    new_state = Qx.Calc.apply_single_qubit_gate(register.state, Qx.Gates.pauli_x(), qubit_index, register.num_qubits)
    %{register | state: new_state}
  end

  @doc """
  Applies a Pauli-Y gate to a specific qubit in the register.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.y(0)
      iex> Qx.Register.valid?(reg)
      true
  """
  def y(%__MODULE__{} = register, qubit_index) do
    validate_qubit_index!(register, qubit_index)
    new_state = Qx.Calc.apply_single_qubit_gate(register.state, Qx.Gates.pauli_y(), qubit_index, register.num_qubits)
    %{register | state: new_state}
  end

  @doc """
  Applies a Pauli-Z gate to a specific qubit in the register.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.z(0)
      iex> Qx.Register.valid?(reg)
      true
  """
  def z(%__MODULE__{} = register, qubit_index) do
    validate_qubit_index!(register, qubit_index)
    new_state = Qx.Calc.apply_single_qubit_gate(register.state, Qx.Gates.pauli_z(), qubit_index, register.num_qubits)
    %{register | state: new_state}
  end

  @doc """
  Applies an S gate to a specific qubit in the register.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.s(0)
      iex> Qx.Register.valid?(reg)
      true
  """
  def s(%__MODULE__{} = register, qubit_index) do
    validate_qubit_index!(register, qubit_index)
    new_state = Qx.Calc.apply_single_qubit_gate(register.state, Qx.Gates.s_gate(), qubit_index, register.num_qubits)
    %{register | state: new_state}
  end

  @doc """
  Applies a T gate to a specific qubit in the register.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.t(0)
      iex> Qx.Register.valid?(reg)
      true
  """
  def t(%__MODULE__{} = register, qubit_index) do
    validate_qubit_index!(register, qubit_index)
    new_state = Qx.Calc.apply_single_qubit_gate(register.state, Qx.Gates.t_gate(), qubit_index, register.num_qubits)
    %{register | state: new_state}
  end

  @doc """
  Applies a rotation around the X-axis to a specific qubit.

  ## Parameters
    * `register` - The quantum register
    * `qubit_index` - Index of the qubit
    * `theta` - Rotation angle in radians

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.rx(0, :math.pi() / 2)
      iex> Qx.Register.valid?(reg)
      true
  """
  def rx(%__MODULE__{} = register, qubit_index, theta) do
    validate_qubit_index!(register, qubit_index)
    new_state = Qx.Calc.apply_single_qubit_gate(register.state, Qx.Gates.rx(theta), qubit_index, register.num_qubits)
    %{register | state: new_state}
  end

  @doc """
  Applies a rotation around the Y-axis to a specific qubit.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.ry(0, :math.pi() / 2)
      iex> Qx.Register.valid?(reg)
      true
  """
  def ry(%__MODULE__{} = register, qubit_index, theta) do
    validate_qubit_index!(register, qubit_index)
    new_state = Qx.Calc.apply_single_qubit_gate(register.state, Qx.Gates.ry(theta), qubit_index, register.num_qubits)
    %{register | state: new_state}
  end

  @doc """
  Applies a rotation around the Z-axis to a specific qubit.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.rz(0, :math.pi() / 4)
      iex> Qx.Register.valid?(reg)
      true
  """
  def rz(%__MODULE__{} = register, qubit_index, theta) do
    validate_qubit_index!(register, qubit_index)
    new_state = Qx.Calc.apply_single_qubit_gate(register.state, Qx.Gates.rz(theta), qubit_index, register.num_qubits)
    %{register | state: new_state}
  end

  @doc """
  Applies a phase gate to a specific qubit.

  ## Parameters
    * `register` - The quantum register
    * `qubit_index` - Index of the qubit
    * `phi` - Phase angle in radians

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.phase(0, :math.pi() / 4)
      iex> Qx.Register.valid?(reg)
      true
  """
  def phase(%__MODULE__{} = register, qubit_index, phi) do
    validate_qubit_index!(register, qubit_index)
    new_state = Qx.Calc.apply_single_qubit_gate(register.state, Qx.Gates.phase(phi), qubit_index, register.num_qubits)
    %{register | state: new_state}
  end

  # ============================================================================
  # Multi-Qubit Gate Operations
  # ============================================================================

  @doc """
  Applies a CNOT (controlled-X) gate.

  ## Parameters
    * `register` - The quantum register
    * `control_qubit` - Index of the control qubit
    * `target_qubit` - Index of the target qubit

  ## Examples

      # Create a Bell state
      iex> reg = Qx.Register.new(2)
      ...>   |> Qx.Register.h(0)
      ...>   |> Qx.Register.cx(0, 1)
      iex> Qx.Register.valid?(reg)
      true
  """
  def cx(%__MODULE__{} = register, control_qubit, target_qubit) do
    validate_qubit_index!(register, control_qubit)
    validate_qubit_index!(register, target_qubit)

    if control_qubit == target_qubit do
      raise ArgumentError, "Control and target qubits must be different"
    end

    new_state = Qx.Calc.apply_cnot(register.state, control_qubit, target_qubit, register.num_qubits)
    %{register | state: new_state}
  end

  @doc """
  Applies a controlled-Z gate.

  ## Parameters
    * `register` - The quantum register
    * `control_qubit` - Index of the control qubit
    * `target_qubit` - Index of the target qubit

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.cz(0, 1)
      iex> Qx.Register.valid?(reg)
      true
  """
  def cz(%__MODULE__{} = register, control_qubit, target_qubit) do
    validate_qubit_index!(register, control_qubit)
    validate_qubit_index!(register, target_qubit)

    if control_qubit == target_qubit do
      raise ArgumentError, "Control and target qubits must be different"
    end

    # CZ = H on target, CNOT, H on target
    register
    |> h(target_qubit)
    |> cx(control_qubit, target_qubit)
    |> h(target_qubit)
  end

  @doc """
  Applies a Toffoli (CCX/CCNOT) gate.

  ## Parameters
    * `register` - The quantum register
    * `control1` - Index of first control qubit
    * `control2` - Index of second control qubit
    * `target` - Index of target qubit

  ## Examples

      iex> reg = Qx.Register.new(3) |> Qx.Register.ccx(0, 1, 2)
      iex> Qx.Register.valid?(reg)
      true
  """
  def ccx(%__MODULE__{} = register, control1, control2, target) do
    validate_qubit_index!(register, control1)
    validate_qubit_index!(register, control2)
    validate_qubit_index!(register, target)

    if control1 == control2 or control1 == target or control2 == target do
      raise ArgumentError, "All qubit indices must be different"
    end

    new_state = Qx.Calc.apply_toffoli(register.state, control1, control2, target, register.num_qubits)
    %{register | state: new_state}
  end

  # ============================================================================
  # State Inspection
  # ============================================================================

  @doc """
  Returns the state vector of the register.

  ## Examples

      iex> reg = Qx.Register.new(2)
      iex> state = Qx.Register.state_vector(reg)
      iex> Nx.shape(state)
      {4}
  """
  def state_vector(%__MODULE__{} = register) do
    register.state
  end

  @doc """
  Returns the measurement probabilities for all basis states.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.h(0) |> Qx.Register.h(1)
      iex> probs = Qx.Register.get_probabilities(reg)
      iex> Nx.shape(probs)
      {4}
  """
  def get_probabilities(%__MODULE__{} = register) do
    Qx.Math.probabilities(register.state)
  end

  @doc """
  Returns a human-readable representation of the register state.

  Similar to `Qx.Qubit.show_state/1` but for multi-qubit systems.

  ## Examples

      # Bell state
      iex> reg = Qx.Register.new(2) |> Qx.Register.h(0) |> Qx.Register.cx(0, 1)
      iex> info = Qx.Register.show_state(reg)
      iex> is_map(info)
      true
  """
  def show_state(%__MODULE__{} = register) do
    state_list = Nx.to_flat_list(register.state)
    probs_list = Nx.to_flat_list(get_probabilities(register))

    # Format each basis state
    amplitudes_and_probs =
      Enum.zip(state_list, probs_list)
      |> Enum.with_index()
      |> Enum.map(fn {{amplitude, probability}, index} ->
        basis_label = format_basis_state(index, register.num_qubits)
        amplitude_str = format_complex(amplitude)
        {basis_label, amplitude_str, probability}
      end)

    # Build Dirac notation (only show non-zero terms)
    state_str = build_state_string(amplitudes_and_probs)

    %{
      state: state_str,
      amplitudes: Enum.map(amplitudes_and_probs, fn {basis, amp, _prob} -> {basis, amp} end),
      probabilities: Enum.map(amplitudes_and_probs, fn {basis, _amp, prob} -> {basis, prob} end)
    }
  end

  @doc """
  Checks if a register is valid (properly normalized).

  ## Examples

      iex> reg = Qx.Register.new(2)
      iex> Qx.Register.valid?(reg)
      true
  """
  def valid?(%__MODULE__{} = register) do
    probs = get_probabilities(register)
    total_prob = Nx.sum(probs) |> Nx.to_number()
    abs(total_prob - 1.0) < 1.0e-6
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  # Validate qubit index
  defp validate_qubit_index!(%__MODULE__{} = register, qubit_index) do
    if qubit_index < 0 or qubit_index >= register.num_qubits do
      raise ArgumentError,
            "Qubit index #{qubit_index} out of range (register has #{register.num_qubits} qubits)"
    end
  end

  # Format a basis state as |000⟩, |001⟩, etc.
  defp format_basis_state(index, num_qubits) do
    binary_string =
      Integer.to_string(index, 2)
      |> String.pad_leading(num_qubits, "0")

    "|#{binary_string}⟩"
  end

  # Format complex number as string
  defp format_complex(complex_num) do
    real = Complex.real(complex_num)
    imag = Complex.imag(complex_num)

    real_str = :erlang.float_to_binary(real, decimals: 3)
    imag_str = :erlang.float_to_binary(abs(imag), decimals: 3)

    sign = if imag >= 0, do: "+", else: "-"
    "#{real_str}#{sign}#{imag_str}i"
  end

  # Build state string in Dirac notation
  defp build_state_string(amplitudes_and_probs) do
    # Filter out near-zero amplitudes
    significant_terms =
      amplitudes_and_probs
      |> Enum.filter(fn {_basis, _amp_str, prob} -> prob > 1.0e-6 end)

    if Enum.empty?(significant_terms) do
      # Shouldn't happen with normalized state, but handle it
      {basis, _, _} = List.first(amplitudes_and_probs)
      "0.000#{basis}"
    else
      significant_terms
      |> Enum.map(fn {basis, _amp_str, prob} ->
        magnitude = :math.sqrt(prob)
        mag_str = :erlang.float_to_binary(magnitude, decimals: 3)
        "#{mag_str}#{basis}"
      end)
      |> Enum.join(" + ")
    end
  end
end
