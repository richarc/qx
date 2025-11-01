defmodule Qx.Behaviours.QuantumState do
  @moduledoc """
  Behaviour for quantum state manipulation.

  This behaviour ensures consistent API across Circuit and Calculation modes.
  Any module implementing this behaviour must provide a complete set of
  quantum gate operations and state inspection functions.

  ## Example

      defmodule MyQuantumState do
        @behaviour Qx.Behaviours.QuantumState

        @impl true
        def h(state, qubit), do: # ... implementation

        @impl true
        def state_vector(state), do: # ... implementation

        # ... other required callbacks
      end
  """

  @type state :: any()
  @type qubit_index :: non_neg_integer()
  @type angle :: number()

  # Single-qubit gates
  @callback h(state, qubit_index) :: state
  @callback x(state, qubit_index) :: state
  @callback y(state, qubit_index) :: state
  @callback z(state, qubit_index) :: state
  @callback s(state, qubit_index) :: state
  @callback t(state, qubit_index) :: state

  # Parameterized single-qubit gates
  @callback rx(state, qubit_index, angle) :: state
  @callback ry(state, qubit_index, angle) :: state
  @callback rz(state, qubit_index, angle) :: state
  @callback phase(state, qubit_index, angle) :: state

  # Multi-qubit gates
  @callback cx(state, qubit_index, qubit_index) :: state
  @callback cz(state, qubit_index, qubit_index) :: state
  @callback ccx(state, qubit_index, qubit_index, qubit_index) :: state

  # State inspection
  @callback state_vector(state) :: Nx.Tensor.t()
  @callback valid?(state) :: boolean()
end
