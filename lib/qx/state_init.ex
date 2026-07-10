defmodule Qx.StateInit do
  @moduledoc """
  State initialization utilities for quantum systems.

  The public surface of this module is `basis_state/3` — the raw
  state-vector constructor used by `Qx.QuantumCircuit`.

  The named-state constructors (`zero_state`, `one_state`, `plus_state`,
  `minus_state`, `superposition_state`, `random_state`,
  `bell_state_vector`, `ghz_state_vector`, `w_state`) are deprecated and
  will be removed in Qx 1.0: named states are prepared in **circuit mode**
  (`Qx.bell_state/1`, `Qx.ghz_state/0`, `Qx.Patterns.superposition_circuit/1`, or
  `Qx.create_circuit/1` + gates). Each deprecation notice carries its
  replacement.

  ## Examples

      # Create basis state |101⟩ for 3 qubits
      iex> state = Qx.StateInit.basis_state(5, 8)
      iex> Qx.Math.probabilities(state) |> Nx.to_flat_list() |> Enum.at(5)
      1.0

      # Create |0⟩ for a single qubit (dimension 2, index 0)
      iex> state = Qx.StateInit.basis_state(0, 2)
      iex> Nx.shape(state)
      {2}
  """

  alias Complex, as: C

  @doc """
  Creates a basis state |i⟩ in an n-dimensional Hilbert space.

  The basis state has amplitude 1.0 at the specified index and 0.0 everywhere else.

  ## Parameters
  - `index` - The basis state index (0-based)
  - `dimension` - The dimension of the Hilbert space (2^num_qubits)
  - `type` - Tensor type (default: `:c64`)

  ## Examples

      # Create |0⟩ state
      iex> state = Qx.StateInit.basis_state(0, 2)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> [Enum.at(probs, 0), Enum.at(probs, 1)]
      [1.0, 0.0]

      # Create |11⟩ for 2 qubits (dimension 4, index 3)
      iex> state = Qx.StateInit.basis_state(3, 4)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> Enum.at(probs, 3)
      1.0

      # Create |101⟩ for 3 qubits (dimension 8, index 5)
      iex> state = Qx.StateInit.basis_state(5, 8)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> Enum.at(probs, 5)
      1.0

  ## Raises

    * `Qx.BasisError` - If `dimension` is not a positive integer, `index` is not
      an integer, `index` is negative, or `index >= dimension`
  """
  def basis_state(index, dimension, type \\ :c64)

  def basis_state(index, dimension, type)
      when is_integer(index) and is_integer(dimension) and index >= 0 and index < dimension do
    state_data =
      for i <- 0..(dimension - 1) do
        if i == index, do: C.new(1.0, 0.0), else: C.new(0.0, 0.0)
      end

    Nx.tensor(state_data, type: type)
  end

  # Fallback (sweep #3): route invalid basis_state args onto Qx.BasisError
  # reason variants instead of leaking a raw FunctionClauseError. Checked in
  # priority order — a bad dimension makes the index checks meaningless.
  def basis_state(index, dimension, _type) do
    cond do
      not (is_integer(dimension) and dimension >= 1) ->
        raise Qx.BasisError, {:invalid_dimension, dimension}

      not is_integer(index) ->
        raise Qx.BasisError, {:not_an_integer, index}

      index < 0 ->
        raise Qx.BasisError, {:negative, index}

      true ->
        raise Qx.BasisError, {:out_of_range, index, dimension}
    end
  end

  @doc """
  Creates the zero state |00...0⟩ for n qubits.

  This is equivalent to `basis_state(0, 2^num_qubits)`.

  ## Parameters
  - `num_qubits` - Number of qubits
  - `type` - Tensor type (default: `:c64`)

  ## Examples

      # Create |0⟩ for single qubit
      iex> state = Qx.StateInit.zero_state(1)
      iex> Nx.shape(state)
      {2}

      # Create |00⟩ for 2 qubits
      iex> state = Qx.StateInit.zero_state(2)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> Enum.at(probs, 0)
      1.0

      # Verify all other amplitudes are zero
      iex> state = Qx.StateInit.zero_state(3)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> Enum.sum(Enum.drop(probs, 1))
      0.0
  """
  @deprecated "Use `basis_state(0, Integer.pow(2, num_qubits))` — circuits already start in |0…0⟩. Will be removed in Qx 1.0"
  def zero_state(num_qubits, type \\ :c64) when is_integer(num_qubits) and num_qubits > 0 do
    dimension = trunc(:math.pow(2, num_qubits))
    basis_state(0, dimension, type)
  end

  @doc """
  Creates the |1⟩ state for a single qubit.

  ## Examples

      iex> state = Qx.StateInit.one_state()
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> Enum.at(probs, 1)
      1.0
  """
  @deprecated "Use `basis_state(1, 2)`. Will be removed in Qx 1.0"
  def one_state(type \\ :c64) do
    basis_state(1, 2, type)
  end

  @doc """
  Creates the |+⟩ state: (|0⟩ + |1⟩)/√2

  ## Examples

      iex> state = Qx.StateInit.plus_state()
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> [p0, p1] = probs
      iex> abs(p0 - 0.5) < 0.01 and abs(p1 - 0.5) < 0.01
      true
  """
  @deprecated "Prepare |+⟩ in circuit mode: `Qx.create_circuit(1) |> Qx.h(0)`. Will be removed in Qx 1.0"
  def plus_state(type \\ :c64) do
    inv_sqrt2 = 1.0 / :math.sqrt(2)
    Nx.tensor([C.new(inv_sqrt2, 0.0), C.new(inv_sqrt2, 0.0)], type: type)
  end

  @doc """
  Creates the |-⟩ state: (|0⟩ - |1⟩)/√2

  ## Examples

      iex> state = Qx.StateInit.minus_state()
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> [p0, p1] = probs
      iex> abs(p0 - 0.5) < 0.01 and abs(p1 - 0.5) < 0.01
      true
  """
  @deprecated "Prepare |−⟩ in circuit mode: `Qx.create_circuit(1) |> Qx.x(0) |> Qx.h(0)`. Will be removed in Qx 1.0"
  def minus_state(type \\ :c64) do
    inv_sqrt2 = 1.0 / :math.sqrt(2)
    Nx.tensor([C.new(inv_sqrt2, 0.0), C.new(-inv_sqrt2, 0.0)], type: type)
  end

  @doc """
  Creates an equal superposition state for n qubits.

  The state is (1/√(2^n)) Σ|i⟩ where i ranges over all basis states.
  Each basis state has equal probability 1/(2^n).

  ## Parameters
  - `num_qubits` - Number of qubits
  - `type` - Tensor type (default: `:c64`)

  ## Examples

      # Single qubit: (|0⟩ + |1⟩)/√2
      iex> state = Qx.StateInit.superposition_state(1)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> Enum.all?(probs, &(abs(&1 - 0.5) < 0.01))
      true

      # Two qubits: (|00⟩ + |01⟩ + |10⟩ + |11⟩)/2
      iex> state = Qx.StateInit.superposition_state(2)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> Enum.all?(probs, &(abs(&1 - 0.25) < 0.01))
      true

      # Three qubits: each state has probability 1/8
      iex> state = Qx.StateInit.superposition_state(3)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> Enum.all?(probs, &(abs(&1 - 0.125) < 0.01))
      true
  """
  @deprecated "Use `Qx.Patterns.superposition_circuit/1` (circuit mode). Will be removed in Qx 1.0"
  def superposition_state(num_qubits, type \\ :c64)
      when is_integer(num_qubits) and num_qubits > 0 do
    dimension = trunc(:math.pow(2, num_qubits))
    amplitude = 1.0 / :math.sqrt(dimension)

    state_data = List.duplicate(C.new(amplitude, 0.0), dimension)
    Nx.tensor(state_data, type: type)
  end

  @doc """
  Creates a random normalized quantum state.

  Generates random complex amplitudes and normalizes them to ensure
  the state is valid (|ψ|² = 1).

  ## Parameters
  - `num_qubits` - Number of qubits
  - `type` - Tensor type (default: `:c64`)

  ## Examples

      # Create random single qubit state
      iex> state = Qx.StateInit.random_state(1)
      iex> Qx.Validation.valid_qubit?(state)
      true

      # Create random 3-qubit state
      iex> state = Qx.StateInit.random_state(3)
      iex> probs = Qx.Math.probabilities(state)
      iex> total = Nx.sum(probs) |> Nx.to_number()
      iex> abs(total - 1.0) < 1.0e-6
      true
  """
  @deprecated "No direct replacement — build random amplitudes and normalize: `(for _ <- 1..dimension, do: Complex.new(:rand.uniform() * 2 - 1, :rand.uniform() * 2 - 1)) |> Nx.tensor(type: :c64) |> Qx.Math.normalize()`. Will be removed in Qx 1.0"
  def random_state(num_qubits, type \\ :c64) when is_integer(num_qubits) and num_qubits > 0 do
    dimension = trunc(:math.pow(2, num_qubits))

    # Generate random complex amplitudes
    state_data =
      for _ <- 0..(dimension - 1) do
        real = :rand.uniform() * 2 - 1
        imag = :rand.uniform() * 2 - 1
        C.new(real, imag)
      end

    state = Nx.tensor(state_data, type: type)
    Qx.Math.normalize(state)
  end

  @type bell_state_which :: :phi_plus | :phi_minus | :psi_plus | :psi_minus

  @doc """
  Creates one of the four Bell states as a state vector.

  Accepts an optional atom to select which Bell state to prepare, and an
  optional tensor type (`:c64` or `:c128`):

  | Atom          | State                            |
  | ------------- | -------------------------------- |
  | `:phi_plus`   | `\|Φ+⟩ = (\|00⟩ + \|11⟩)/√2` (default) |
  | `:phi_minus`  | `\|Φ-⟩ = (\|00⟩ - \|11⟩)/√2`   |
  | `:psi_plus`   | `\|Ψ+⟩ = (\|01⟩ + \|10⟩)/√2`   |
  | `:psi_minus`  | `\|Ψ-⟩ = (\|01⟩ - \|10⟩)/√2`   |

  ## Examples

      iex> state = Qx.StateInit.bell_state_vector()
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> abs(Enum.at(probs, 0) - 0.5) < 0.01 and abs(Enum.at(probs, 3) - 0.5) < 0.01
      true

      iex> state = Qx.StateInit.bell_state_vector(:phi_minus)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> abs(Enum.at(probs, 0) - 0.5) < 0.01 and abs(Enum.at(probs, 3) - 0.5) < 0.01
      true

      iex> state = Qx.StateInit.bell_state_vector(:psi_plus)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> abs(Enum.at(probs, 1) - 0.5) < 0.01 and abs(Enum.at(probs, 2) - 0.5) < 0.01
      true

      iex> state = Qx.StateInit.bell_state_vector(:psi_minus)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> abs(Enum.at(probs, 1) - 0.5) < 0.01 and abs(Enum.at(probs, 2) - 0.5) < 0.01
      true

  ## See Also

    * `Qx.bell_state/1` — returns a **circuit recipe** (`%Qx.QuantumCircuit{}`)
      that *prepares* the Bell state when run, rather than the state vector
      directly. Use that when you want a circuit to execute, this when you
      want the mathematical state.
  """
  @deprecated "Use `Qx.bell_state/1` (circuit mode). Will be removed in Qx 1.0"
  @spec bell_state_vector(bell_state_which(), Nx.Type.t()) :: Nx.Tensor.t()
  def bell_state_vector(which \\ :phi_plus, type \\ :c64)

  def bell_state_vector(:phi_plus, type) do
    inv_sqrt2 = 1.0 / :math.sqrt(2)

    Nx.tensor(
      [C.new(inv_sqrt2, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(inv_sqrt2, 0.0)],
      type: type
    )
  end

  def bell_state_vector(:phi_minus, type) do
    inv_sqrt2 = 1.0 / :math.sqrt(2)

    Nx.tensor(
      [C.new(inv_sqrt2, 0.0), C.new(0.0, 0.0), C.new(0.0, 0.0), C.new(-inv_sqrt2, 0.0)],
      type: type
    )
  end

  def bell_state_vector(:psi_plus, type) do
    inv_sqrt2 = 1.0 / :math.sqrt(2)

    Nx.tensor(
      [C.new(0.0, 0.0), C.new(inv_sqrt2, 0.0), C.new(inv_sqrt2, 0.0), C.new(0.0, 0.0)],
      type: type
    )
  end

  def bell_state_vector(:psi_minus, type) do
    inv_sqrt2 = 1.0 / :math.sqrt(2)

    Nx.tensor(
      [C.new(0.0, 0.0), C.new(inv_sqrt2, 0.0), C.new(-inv_sqrt2, 0.0), C.new(0.0, 0.0)],
      type: type
    )
  end

  @doc """
  Creates a GHZ state for n qubits: (|00...0⟩ + |11...1⟩)/√2

  The Greenberger-Horne-Zeilinger (GHZ) state is a maximally entangled
  state for multiple qubits.

  ## Parameters
  - `num_qubits` - Number of qubits; must be `>= 2` (a single-qubit GHZ
    state is undefined). Smaller values raise `FunctionClauseError`.
  - `type` - Tensor type (default: `:c64`)

  ## Examples

      # GHZ state for 2 qubits (same as Bell state)
      iex> state = Qx.StateInit.ghz_state_vector(2)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> abs(Enum.at(probs, 0) - 0.5) < 0.01 and abs(Enum.at(probs, 3) - 0.5) < 0.01
      true

      # GHZ state for 3 qubits: (|000⟩ + |111⟩)/√2
      iex> state = Qx.StateInit.ghz_state_vector(3)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> abs(Enum.at(probs, 0) - 0.5) < 0.01 and abs(Enum.at(probs, 7) - 0.5) < 0.01
      true

      # All other states have zero probability
      iex> state = Qx.StateInit.ghz_state_vector(3)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> Enum.sum(Enum.slice(probs, 1..6))
      0.0

  ## See Also

    * `Qx.ghz_state/0` — returns a **circuit recipe** (hardcoded 3-qubit)
      rather than the state vector. Use that for a runnable circuit; this
      for the mathematical state at any qubit count.
  """
  @deprecated "Use `Qx.ghz_state/0` (circuit mode). Will be removed in Qx 1.0"
  @spec ghz_state_vector(pos_integer(), Nx.Type.t()) :: Nx.Tensor.t()
  def ghz_state_vector(num_qubits, type \\ :c64)
      when is_integer(num_qubits) and num_qubits >= 2 do
    dimension = trunc(:math.pow(2, num_qubits))
    inv_sqrt2 = 1.0 / :math.sqrt(2)

    state_data =
      for i <- 0..(dimension - 1) do
        if i == 0 or i == dimension - 1 do
          C.new(inv_sqrt2, 0.0)
        else
          C.new(0.0, 0.0)
        end
      end

    Nx.tensor(state_data, type: type)
  end

  @doc """
  Creates a W state for n qubits.

  The W state is another type of entangled state where exactly one qubit
  is |1⟩ and the rest are |0⟩, in superposition.

  For 3 qubits: (|001⟩ + |010⟩ + |100⟩)/√3

  ## Examples

      # W state for 3 qubits
      iex> state = Qx.StateInit.w_state(3)
      iex> probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()
      iex> expected_prob = 1.0 / 3.0
      iex> abs(Enum.at(probs, 1) - expected_prob) < 0.01 and
      ...> abs(Enum.at(probs, 2) - expected_prob) < 0.01 and
      ...> abs(Enum.at(probs, 4) - expected_prob) < 0.01
      true
  """
  @deprecated "No replacement — build the state with `basis_state/2` sums or gates in circuit mode. Will be removed in Qx 1.0"
  def w_state(num_qubits, type \\ :c64) when is_integer(num_qubits) and num_qubits >= 2 do
    dimension = trunc(:math.pow(2, num_qubits))
    amplitude = 1.0 / :math.sqrt(num_qubits)

    state_data =
      for i <- 0..(dimension - 1) do
        # Count number of 1 bits in binary representation
        bit_count = count_bits(i)

        if bit_count == 1 do
          C.new(amplitude, 0.0)
        else
          C.new(0.0, 0.0)
        end
      end

    Nx.tensor(state_data, type: type)
  end

  # Private helper: count number of 1 bits in integer
  defp count_bits(n) when n >= 0 do
    count_bits(n, 0)
  end

  defp count_bits(0, count), do: count

  defp count_bits(n, count) do
    count_bits(Bitwise.bsr(n, 1), count + Bitwise.band(n, 1))
  end
end
