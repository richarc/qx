defmodule Qx.Behaviours.QuantumState do
  # Behaviour for multi-qubit quantum state manipulation.
  # Demoted from the public surface in v0.11 (finding R-13): its sole
  # implementor is the internal calc-engine Qx.Register (zero @impls),
  # and Qx.QuantumCircuit follows the shape only by convention via
  # Qx.Operations. Callbacks kept intact — Register still @behaviour's
  # it; both die together at 1.0. No stability guarantee.
  @moduledoc false

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
