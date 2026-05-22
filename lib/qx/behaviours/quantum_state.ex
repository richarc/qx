defmodule Qx.Behaviours.QuantumState do
  @moduledoc """
  Behaviour for **multi-qubit** quantum state manipulation.

  Enforces a consistent gate-application API across modules whose state
  is indexed by qubit number — currently `Qx.Register` (calc-mode
  multi-qubit) and, by convention, `Qx.QuantumCircuit` via `Qx.Operations`.
  Implementing modules must provide the standard gate set + state
  inspection.

  ## Single-qubit modules

  `Qx.Qubit` is **intentionally not** an implementor — its gate functions
  take a single-state argument (`Qx.Qubit.h(qubit)`) rather than the
  `(state, qubit_index)` shape this behaviour requires. Unifying both
  paradigms under one behaviour would force a structural redesign of
  `Qx.Qubit` and is deferred to a future major version.

  ## Optional callbacks

  Three-qubit gates (`ccx`, `cswap`) and a small handful of less-common
  two-qubit gates are marked as `@optional_callbacks` — implementations
  with fewer than 3 qubits (or that omit a gate) can leave them
  undefined without a compile warning.

  ## Example

      defmodule MyMultiQubitState do
        @behaviour Qx.Behaviours.QuantumState

        @impl true
        def h(state, qubit), do: # ... implementation

        @impl true
        def cx(state, control, target), do: # ... implementation

        # ... other required callbacks
      end
  """

  @type state :: any()
  @type qubit_index :: non_neg_integer()
  @type angle :: number()

  # Single-qubit Pauli + Clifford gates
  @callback h(state, qubit_index) :: state
  @callback x(state, qubit_index) :: state
  @callback y(state, qubit_index) :: state
  @callback z(state, qubit_index) :: state
  @callback s(state, qubit_index) :: state
  @callback sdg(state, qubit_index) :: state
  @callback t(state, qubit_index) :: state

  # Parameterized single-qubit rotations + the general U gate
  @callback rx(state, qubit_index, angle) :: state
  @callback ry(state, qubit_index, angle) :: state
  @callback rz(state, qubit_index, angle) :: state
  @callback phase(state, qubit_index, angle) :: state
  @callback u(state, qubit_index, angle, angle, angle) :: state

  # Two-qubit gates
  @callback cx(state, qubit_index, qubit_index) :: state
  @callback cy(state, qubit_index, qubit_index) :: state
  @callback cz(state, qubit_index, qubit_index) :: state
  @callback swap(state, qubit_index, qubit_index) :: state
  @callback iswap(state, qubit_index, qubit_index) :: state
  @callback cp(state, qubit_index, qubit_index, angle) :: state
  @callback crx(state, qubit_index, qubit_index, angle) :: state
  @callback cry(state, qubit_index, qubit_index, angle) :: state
  @callback crz(state, qubit_index, qubit_index, angle) :: state

  # Three-qubit gates
  @callback ccx(state, qubit_index, qubit_index, qubit_index) :: state
  @callback cswap(state, qubit_index, qubit_index, qubit_index) :: state

  # State inspection
  @callback state_vector(state) :: Nx.Tensor.t()
  @callback valid?(state) :: boolean()

  # Three-qubit gates (ccx, cswap) are optional because a two-qubit-only
  # implementor wouldn't have them; the parameterised two-qubit gates and U
  # are optional because they're newer additions and a minimal implementor
  # might omit them. The base gates (h/x/y/z/s/sdg/t/rx/ry/rz/phase/cx/cz)
  # remain required.
  @optional_callbacks [
    u: 5,
    cy: 3,
    swap: 3,
    iswap: 3,
    cp: 4,
    crx: 4,
    cry: 4,
    crz: 4,
    ccx: 4,
    cswap: 4
  ]
end
