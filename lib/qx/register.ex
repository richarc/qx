defmodule Qx.Register do
  # Internal calc engine (multi-qubit state, immediate gate application).
  # Demoted from the public surface in v0.10 — see
  # spec/unified-circuit-stepper-design.md §"Reposition calc mode".
  # The documented path is circuit mode + Qx.steps/2 / Qx.Step.show/1.
  # Still functional, no stability guarantee; removal deferred to v1.0.
  @moduledoc false

  @behaviour Qx.Behaviours.QuantumState

  defstruct [:num_qubits, :state]

  @type t :: %__MODULE__{
          num_qubits: pos_integer(),
          state: Nx.Tensor.t()
        }

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
    Qx.Validation.validate_num_qubits!(num_qubits)

    %__MODULE__{
      num_qubits: num_qubits,
      state: Qx.StateInit.zero_state(num_qubits)
    }
  end

  def new(qubits) when is_list(qubits) do
    if qubits == [] do
      raise Qx.RegisterError, :empty
    end

    Qx.Validation.validate_num_qubits!(length(qubits))

    # Validate all qubits
    Enum.each(qubits, fn qubit ->
      unless Qx.Validation.valid_qubit?(qubit) do
        raise Qx.RegisterError, {:invalid_qubit, qubit}
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

  @doc """
  Creates a register from a list of computational basis states.

  ## Parameters
    * `basis_states` - List of 0s and 1s representing the basis state for each qubit

  ## Examples

      # Create |010⟩ state
      iex> reg = Qx.Register.from_basis_states([0, 1, 0])
      iex> reg.num_qubits
      3

      # Create |11⟩ state (Bell state preparation starting point)
      iex> reg = Qx.Register.from_basis_states([1, 1])
      iex> probs = Qx.Register.get_probabilities(reg) |> Nx.to_flat_list()
      iex> Enum.at(probs, 3)
      1.0
  """
  @spec from_basis_states(list(0 | 1)) :: t()
  def from_basis_states(states) when is_list(states) do
    if Enum.empty?(states) do
      raise Qx.RegisterError, :empty
    end

    # Validate all elements are 0 or 1
    unless Enum.all?(states, &(&1 in [0, 1])) do
      raise Qx.BasisError, Enum.find(states, &(&1 not in [0, 1]))
    end

    # Create qubits for each basis state
    qubits =
      Enum.map(states, fn
        0 -> Qx.Qubit.new()
        1 -> Qx.Qubit.one()
      end)

    new(qubits)
  end

  @doc """
  Creates a register where all qubits are in superposition (|+⟩ state).

  ## Parameters
    * `num_qubits` - Number of qubits to create

  ## Examples

      # Create 2-qubit register in equal superposition of all 4 basis states
      iex> reg = Qx.Register.from_superposition(2)
      iex> probs = Qx.Register.get_probabilities(reg) |> Nx.to_flat_list()
      iex> Enum.all?(probs, fn p -> abs(p - 0.25) < 0.01 end)
      true

      # 3-qubit superposition (8 equal states)
      iex> reg = Qx.Register.from_superposition(3)
      iex> probs = Qx.Register.get_probabilities(reg) |> Nx.to_flat_list()
      iex> Enum.all?(probs, fn p -> abs(p - 0.125) < 0.01 end)
      true
  """
  @spec from_superposition(pos_integer()) :: t()
  def from_superposition(num_qubits) when is_integer(num_qubits) and num_qubits > 0 do
    Qx.Validation.validate_num_qubits!(num_qubits)

    # Apply H gate to all qubits starting from |0...0⟩
    register = new(num_qubits)

    Enum.reduce(0..(num_qubits - 1), register, fn qubit_index, acc ->
      h(acc, qubit_index)
    end)
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

    new_state =
      Qx.Calc.apply_single_qubit_gate(
        register.state,
        Qx.Gates.hadamard(),
        qubit_index,
        register.num_qubits
      )

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

    new_state =
      Qx.Calc.apply_single_qubit_gate(
        register.state,
        Qx.Gates.pauli_x(),
        qubit_index,
        register.num_qubits
      )

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

    new_state =
      Qx.Calc.apply_single_qubit_gate(
        register.state,
        Qx.Gates.pauli_y(),
        qubit_index,
        register.num_qubits
      )

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

    new_state =
      Qx.Calc.apply_single_qubit_gate(
        register.state,
        Qx.Gates.pauli_z(),
        qubit_index,
        register.num_qubits
      )

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

    new_state =
      Qx.Calc.apply_single_qubit_gate(
        register.state,
        Qx.Gates.s_gate(),
        qubit_index,
        register.num_qubits
      )

    %{register | state: new_state}
  end

  @doc """
  Applies an S† (S-dagger) gate to a specific qubit in the register.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.sdg(0)
      iex> Qx.Register.valid?(reg)
      true
  """
  def sdg(%__MODULE__{} = register, qubit_index) do
    validate_qubit_index!(register, qubit_index)

    new_state =
      Qx.Calc.apply_single_qubit_gate(
        register.state,
        Qx.Gates.s_dagger(),
        qubit_index,
        register.num_qubits
      )

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

    new_state =
      Qx.Calc.apply_single_qubit_gate(
        register.state,
        Qx.Gates.t_gate(),
        qubit_index,
        register.num_qubits
      )

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

    new_state =
      Qx.Calc.apply_single_qubit_gate(
        register.state,
        Qx.Gates.rx(theta),
        qubit_index,
        register.num_qubits
      )

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

    new_state =
      Qx.Calc.apply_single_qubit_gate(
        register.state,
        Qx.Gates.ry(theta),
        qubit_index,
        register.num_qubits
      )

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

    new_state =
      Qx.Calc.apply_single_qubit_gate(
        register.state,
        Qx.Gates.rz(theta),
        qubit_index,
        register.num_qubits
      )

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

    new_state =
      Qx.Calc.apply_single_qubit_gate(
        register.state,
        Qx.Gates.phase(phi),
        qubit_index,
        register.num_qubits
      )

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
      raise Qx.QubitIndexError, {:duplicate, [control_qubit, target_qubit]}
    end

    new_state =
      Qx.Calc.apply_cnot(register.state, control_qubit, target_qubit, register.num_qubits)

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
      raise Qx.QubitIndexError, {:duplicate, [control_qubit, target_qubit]}
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

    Qx.Validation.validate_qubits_different!([control1, control2, target])

    new_state =
      Qx.Calc.apply_toffoli(register.state, control1, control2, target, register.num_qubits)

    %{register | state: new_state}
  end

  @doc """
  Applies a controlled-Y (CY) gate.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.cy(0, 1)
      iex> Qx.Register.valid?(reg)
      true
  """
  def cy(%__MODULE__{} = register, control_qubit, target_qubit) do
    apply_controlled_target(register, control_qubit, target_qubit, Qx.Gates.pauli_y())
  end

  @doc """
  Applies a controlled rotation about the X-axis (CRx) gate.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.crx(0, 1, :math.pi() / 2)
      iex> Qx.Register.valid?(reg)
      true
  """
  def crx(%__MODULE__{} = register, control_qubit, target_qubit, theta) do
    apply_controlled_target(register, control_qubit, target_qubit, Qx.Gates.rx(theta))
  end

  @doc """
  Applies a controlled rotation about the Y-axis (CRy) gate.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.cry(0, 1, :math.pi() / 2)
      iex> Qx.Register.valid?(reg)
      true
  """
  def cry(%__MODULE__{} = register, control_qubit, target_qubit, theta) do
    apply_controlled_target(register, control_qubit, target_qubit, Qx.Gates.ry(theta))
  end

  @doc """
  Applies a controlled rotation about the Z-axis (CRz) gate.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.crz(0, 1, :math.pi() / 2)
      iex> Qx.Register.valid?(reg)
      true
  """
  def crz(%__MODULE__{} = register, control_qubit, target_qubit, theta) do
    apply_controlled_target(register, control_qubit, target_qubit, Qx.Gates.rz(theta))
  end

  @doc """
  Applies a controlled-phase (CP) gate.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.cp(0, 1, :math.pi() / 4)
      iex> Qx.Register.valid?(reg)
      true
  """
  def cp(%__MODULE__{} = register, control_qubit, target_qubit, theta) do
    apply_controlled_target(register, control_qubit, target_qubit, Qx.Gates.phase(theta))
  end

  @doc """
  Applies a SWAP gate, exchanging the states of two qubits.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.swap(0, 1)
      iex> Qx.Register.valid?(reg)
      true
  """
  def swap(%__MODULE__{} = register, qubit_a, qubit_b) do
    validate_qubit_index!(register, qubit_a)
    validate_qubit_index!(register, qubit_b)

    if qubit_a == qubit_b do
      raise Qx.QubitIndexError, {:duplicate, [qubit_a, qubit_b]}
    end

    swap_matrix = Qx.Gates.swap(qubit_a, qubit_b, register.num_qubits)
    new_state = Nx.dot(swap_matrix, register.state)

    %{register | state: new_state}
  end

  @doc """
  Applies an iSWAP gate.

  ## Examples

      iex> reg = Qx.Register.new(2) |> Qx.Register.iswap(0, 1)
      iex> Qx.Register.valid?(reg)
      true
  """
  def iswap(%__MODULE__{} = register, qubit_a, qubit_b) do
    validate_qubit_index!(register, qubit_a)
    validate_qubit_index!(register, qubit_b)

    if qubit_a == qubit_b do
      raise Qx.QubitIndexError, {:duplicate, [qubit_a, qubit_b]}
    end

    iswap_matrix = Qx.Gates.iswap(qubit_a, qubit_b, register.num_qubits)
    new_state = Nx.dot(iswap_matrix, register.state)

    %{register | state: new_state}
  end

  @doc """
  Applies a controlled-SWAP (Fredkin) gate.

  ## Examples

      iex> reg = Qx.Register.new(3) |> Qx.Register.cswap(0, 1, 2)
      iex> Qx.Register.valid?(reg)
      true
  """
  def cswap(%__MODULE__{} = register, control, target_a, target_b) do
    validate_qubit_index!(register, control)
    validate_qubit_index!(register, target_a)
    validate_qubit_index!(register, target_b)

    Qx.Validation.validate_qubits_different!([control, target_a, target_b])

    new_state =
      Qx.Calc.apply_cswap(register.state, control, target_a, target_b, register.num_qubits)

    %{register | state: new_state}
  end

  @doc """
  Applies the general single-qubit U(θ, φ, λ) unitary.

  ## Examples

      iex> reg = Qx.Register.new(1)
      ...>   |> Qx.Register.u(0, :math.pi() / 2, 0.0, :math.pi())
      iex> Qx.Register.valid?(reg)
      true
  """
  def u(%__MODULE__{} = register, qubit_index, theta, phi, lambda) do
    validate_qubit_index!(register, qubit_index)

    new_state =
      Qx.Calc.apply_single_qubit_gate(
        register.state,
        Qx.Gates.u(theta, phi, lambda),
        qubit_index,
        register.num_qubits
      )

    %{register | state: new_state}
  end

  # Lifts a 2×2 single-qubit gate matrix into the controlled-on-`c`
  # two-qubit unitary and applies it to `register.state`. Shared by
  # cy/3, crx/4, cry/4, crz/4, cp/4 to avoid repeating the
  # validate-distinct-controlled-gate boilerplate.
  defp apply_controlled_target(%__MODULE__{} = register, control_qubit, target_qubit, gate_matrix) do
    validate_qubit_index!(register, control_qubit)
    validate_qubit_index!(register, target_qubit)

    if control_qubit == target_qubit do
      raise Qx.QubitIndexError, {:duplicate, [control_qubit, target_qubit]}
    end

    controlled_matrix =
      Qx.Gates.controlled_gate(gate_matrix, control_qubit, target_qubit, register.num_qubits)

    new_state = Nx.dot(controlled_matrix, register.state)

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
        basis_label = Qx.Format.basis_state(index, register.num_qubits)
        {basis_label, amplitude, probability}
      end)

    # Build Dirac notation (only show non-zero terms)
    state_str = Qx.Format.dirac_notation(amplitudes_and_probs)

    %{
      state: state_str,
      amplitudes:
        Enum.map(amplitudes_and_probs, fn {basis, amp, _prob} ->
          {basis, Qx.Format.complex(amp)}
        end),
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
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = register) do
    Qx.Validation.valid_register?(register)
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  # Validate qubit index
  defp validate_qubit_index!(%__MODULE__{} = register, qubit_index) do
    Qx.Validation.validate_qubit_index!(qubit_index, register.num_qubits)
  end
end
