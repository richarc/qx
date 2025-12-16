defmodule Qx.Gates do
  @moduledoc """
  Quantum gate matrix definitions with proper complex number support.

  This module provides the fundamental gate matrices used in quantum computing,
  properly implemented with complex numbers where required.
  """

  alias Complex, as: C
  alias Qx.Math

  @doc """
  Returns the Hadamard gate matrix.

  H = 1/√2 * [[1,  1],
              [1, -1]]

  ## Examples

      iex> Qx.Gates.hadamard()
      # Returns complex matrix tensor
  """
  def hadamard do
    inv_sqrt2 = 1.0 / :math.sqrt(2)

    Math.complex_matrix([
      [inv_sqrt2, inv_sqrt2],
      [inv_sqrt2, -inv_sqrt2]
    ])
  end

  @doc """
  Returns the Pauli-X gate matrix (bit flip).

  X = [[0, 1],
       [1, 0]]

  ## Examples

      iex> Qx.Gates.pauli_x()
      # Returns complex matrix tensor
  """
  def pauli_x do
    Math.complex_matrix([
      [0, 1],
      [1, 0]
    ])
  end

  @doc """
  Returns the Pauli-Y gate matrix.

  Y = [[0, -i],
       [i,  0]]

  ## Examples

      iex> Qx.Gates.pauli_y()
      # Returns complex matrix tensor
  """
  def pauli_y do
    Math.complex_matrix([
      [C.new(0, 0), C.new(0, -1)],
      [C.new(0, 1), C.new(0, 0)]
    ])
  end

  @doc """
  Returns the Pauli-Z gate matrix (phase flip).

  Z = [[1,  0],
       [0, -1]]

  ## Examples

      iex> Qx.Gates.pauli_z()
      # Returns complex matrix tensor
  """
  def pauli_z do
    Math.complex_matrix([
      [1, 0],
      [0, -1]
    ])
  end

  @doc """
  Returns the S gate matrix (phase gate π/2).

  S = [[1, 0],
       [0, i]]

  ## Examples

      iex> Qx.Gates.s_gate()
      # Returns complex matrix tensor
  """
  def s_gate do
    Math.complex_matrix([
      [C.new(1, 0), C.new(0, 0)],
      [C.new(0, 0), C.new(0, 1)]
    ])
  end

  @doc """
  Returns the T gate matrix (phase gate π/4).

  T = [[1, 0      ],
       [0, e^(iπ/4)]]

  ## Examples

      iex> Qx.Gates.t_gate()
      # Returns complex matrix tensor
  """
  def t_gate do
    phase = C.exp(C.new(0, :math.pi() / 4))

    Math.complex_matrix([
      [C.new(1, 0), C.new(0, 0)],
      [C.new(0, 0), phase]
    ])
  end

  @doc """
  Returns the S† (S-dagger) gate matrix.

  S† = [[1,  0],
        [0, -i]]

  ## Examples

      iex> Qx.Gates.s_dagger()
      # Returns complex matrix tensor
  """
  def s_dagger do
    Math.complex_matrix([
      [C.new(1, 0), C.new(0, 0)],
      [C.new(0, 0), C.new(0, -1)]
    ])
  end

  @doc """
  Returns the T† (T-dagger) gate matrix.

  T† = [[1, 0       ],
        [0, e^(-iπ/4)]]

  ## Examples

      iex> Qx.Gates.t_dagger()
      # Returns complex matrix tensor
  """
  def t_dagger do
    phase = C.exp(C.new(0, -:math.pi() / 4))

    Math.complex_matrix([
      [C.new(1, 0), C.new(0, 0)],
      [C.new(0, 0), phase]
    ])
  end

  @doc """
  Returns a rotation gate around the X-axis.

  RX(θ) = [[cos(θ/2), -i*sin(θ/2)],
           [-i*sin(θ/2), cos(θ/2)]]

  ## Parameters
    * `theta` - Rotation angle in radians

  ## Examples

      iex> Qx.Gates.rx(math.pi/2)
      # Returns complex matrix tensor
  """
  def rx(theta) do
    cos_half = :math.cos(theta / 2)
    sin_half = :math.sin(theta / 2)

    Math.complex_matrix([
      [C.new(cos_half, 0), C.new(0, -sin_half)],
      [C.new(0, -sin_half), C.new(cos_half, 0)]
    ])
  end

  @doc """
  Returns a rotation gate around the Y-axis.

  RY(θ) = [[cos(θ/2), -sin(θ/2)],
           [sin(θ/2),  cos(θ/2)]]

  ## Parameters
    * `theta` - Rotation angle in radians

  ## Examples

      iex> Qx.Gates.ry(math.pi/2)
      # Returns complex matrix tensor
  """
  def ry(theta) do
    cos_half = :math.cos(theta / 2)
    sin_half = :math.sin(theta / 2)

    Math.complex_matrix([
      [cos_half, -sin_half],
      [sin_half, cos_half]
    ])
  end

  @doc """
  Returns a rotation gate around the Z-axis.

  RZ(θ) = [[e^(-iθ/2), 0       ],
           [0,          e^(iθ/2)]]

  ## Parameters
    * `theta` - Rotation angle in radians

  ## Examples

      iex> Qx.Gates.rz(math.pi/2)
      # Returns complex matrix tensor
  """
  def rz(theta) do
    exp_neg = C.exp(C.new(0, -theta / 2))
    exp_pos = C.exp(C.new(0, theta / 2))

    Math.complex_matrix([
      [exp_neg, C.new(0, 0)],
      [C.new(0, 0), exp_pos]
    ])
  end

  @doc """
  Returns a phase gate with arbitrary phase.

  Phase(φ) = [[1, 0     ],
              [0, e^(iφ)]]

  ## Parameters
    * `phi` - Phase angle in radians

  ## Examples

      iex> Qx.Gates.phase(:math.pi/4)
      # Returns complex matrix tensor
  """
  def phase(phi) do
    phase_factor = C.exp(C.new(0, phi))

    Math.complex_matrix([
      [C.new(1, 0), C.new(0, 0)],
      [C.new(0, 0), phase_factor]
    ])
  end

  @doc """
  Returns the identity gate matrix.

  I = [[1, 0],
       [0, 1]]

  ## Examples

      iex> Qx.Gates.identity()
      # Returns complex matrix tensor
  """
  def identity do
    Math.complex_matrix([
      [1, 0],
      [0, 1]
    ])
  end

  @doc """
  Creates a controlled version of a single-qubit gate for n qubits.

  ## Parameters
    * `gate` - The single-qubit gate matrix
    * `control_qubit` - Index of the control qubit
    * `target_qubit` - Index of the target qubit
    * `num_qubits` - Total number of qubits

  ## Examples

      iex> cx_gate = Qx.Gates.controlled_gate(Qx.Gates.pauli_x(), 0, 1, 2)
  """
  def controlled_gate(gate, control_qubit, target_qubit, num_qubits) do
    state_size = trunc(:math.pow(2, num_qubits))

    # Create zero matrix of appropriate size (c64)
    zero_matrix = Nx.broadcast(Nx.tensor(0, type: :c64), {state_size, state_size})

    # Calculate bit positions (MSB convention: qubit 0 is leftmost)
    control_bit_pos = num_qubits - 1 - control_qubit
    target_bit_pos = num_qubits - 1 - target_qubit

    for i <- 0..(state_size - 1), reduce: zero_matrix do
      acc ->
        control_bit = Bitwise.band(Bitwise.bsr(i, control_bit_pos), 1)

        if control_bit == 1 do
          # Apply gate transformation
          target_bit = Bitwise.band(Bitwise.bsr(i, target_bit_pos), 1)
          j = Bitwise.bxor(i, Bitwise.bsl(1, target_bit_pos))

          # Get gate matrix elements
          # If target_bit is 0, we want gate[0][0] for (i,i) and gate[1][0] for (j,i)
          # If target_bit is 1, we want gate[1][1] for (i,i) and gate[0][1] for (j,i)
          # Note: gate matrix is [row][col], so gate[out][in]

          # Diagonal element (stay in state i)
          diag_element = gate[target_bit][target_bit]

          # Off-diagonal element (transition to state j)
          off_diag_element = gate[1 - target_bit][target_bit]

          acc
          |> Nx.put_slice([i, i], Nx.reshape(diag_element, {1, 1}))
          |> Nx.put_slice([j, i], Nx.reshape(off_diag_element, {1, 1}))
        else
          # Identity on this basis state (control not satisfied)
          Nx.put_slice(acc, [i, i], Nx.tensor([[1]], type: :c64))
        end
    end
  end

  @doc """
  Returns the CNOT (controlled-X) gate matrix for n qubits.

  ## Parameters
    * `control_qubit` - Index of the control qubit
    * `target_qubit` - Index of the target qubit
    * `num_qubits` - Total number of qubits

  ## Examples

      iex> cnot = Qx.Gates.cnot(0, 1, 2)
  """
  def cnot(control_qubit, target_qubit, num_qubits) do
    controlled_gate(pauli_x(), control_qubit, target_qubit, num_qubits)
  end

  @doc """
  Returns the Toffoli (CCX) gate matrix for n qubits.

  ## Parameters
    * `control1` - Index of the first control qubit
    * `control2` - Index of the second control qubit
    * `target` - Index of the target qubit
    * `num_qubits` - Total number of qubits

  ## Examples

      iex> toffoli = Qx.Gates.toffoli(0, 1, 2, 3)
  """
  def toffoli(control1, control2, target, num_qubits) do
    state_size = trunc(:math.pow(2, num_qubits))

    # Create identity matrix
    identity_matrix = Nx.broadcast(0.0, {state_size, state_size, 2})

    for i <- 0..(state_size - 1), reduce: identity_matrix do
      acc ->
        control1_bit = Bitwise.band(Bitwise.bsr(i, control1), 1)
        control2_bit = Bitwise.band(Bitwise.bsr(i, control2), 1)

        if control1_bit == 1 and control2_bit == 1 do
          # Apply X gate to target
          j = Bitwise.bxor(i, Bitwise.bsl(1, target))

          acc
          # Real part
          |> Nx.put_slice([i, j, 0], Nx.tensor([[[1.0]]]))
          # Imaginary part
          |> Nx.put_slice([i, j, 1], Nx.tensor([[[0.0]]]))
        else
          # Identity on this basis state
          acc
          # Real part
          |> Nx.put_slice([i, i, 0], Nx.tensor([[[1.0]]]))
          # Imaginary part
          |> Nx.put_slice([i, i, 1], Nx.tensor([[[0.0]]]))
        end
    end
  end
end
