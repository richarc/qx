defmodule Qx.Step do
  @moduledoc """
  One executed operation from `Qx.steps/2`: what ran, where in the
  circuit, and the state right after it.

  The struct is raw data. `inspect/1` gives you the readable one-liner,
  and `show/1` the same display map `Qx.Register.show_state/1` returns,
  so printing each step of `Qx.steps(qc)` is already a usable circuit
  walkthrough.

  Steps come in 3 kinds:

    * `:gate` - a unitary gate was applied
    * `:measurement` - a qubit was measured and the state collapsed;
      `classical_bits` holds the outcome
    * `:conditional` - a gate inside a `c_if` block; `condition` says
      which classical bit was tested and whether the block ran

  A word on measured circuits: each step carries the state of *one*
  sampled trajectory. After a measurement step the state is collapsed,
  so what you see differs from the ensemble probabilities `Qx.run/2`
  reports. That's the point of stepping, but don't confuse the two.

  Displaying a step reads all `2^n` amplitudes host-side, the same cost
  as `Qx.Register.show_state/1`. Cheap at teaching scale; noticeable
  when you print steps of a 20-qubit circuit in a tight loop.

  ## Fields

    * `kind` - `:gate`, `:measurement`, or `:conditional`
    * `operation` - the instruction just applied, as
      `{gate, qubits, params}`; `nil` for a not-taken conditional block
    * `index` - 0-based position in the executed timeline
    * `state` - the statevector after this step (`:c64` tensor, same
      shape `Qx.get_state/1` returns)
    * `probabilities` - `Qx.Math.probabilities/1` of that state
    * `classical_bits` - classical register contents so far (defaults
      to `[]` for circuits without measurements)
    * `condition` - `nil`, or `{cbit, value, :taken | :not_taken}` on
      conditional steps
  """

  alias Qx.{Format, Math}

  @enforce_keys []
  defstruct [:kind, :operation, :index, :state, :probabilities, :condition, classical_bits: []]

  @type kind :: :gate | :measurement | :conditional
  @type operation :: {atom(), [non_neg_integer()], [number()]}
  @type condition :: {non_neg_integer(), 0 | 1, :taken | :not_taken}

  @type t :: %__MODULE__{
          kind: kind() | nil,
          operation: operation() | nil,
          index: non_neg_integer() | nil,
          state: Nx.Tensor.t() | nil,
          probabilities: Nx.Tensor.t() | nil,
          classical_bits: [0 | 1],
          condition: condition() | nil
        }

  @doc """
  Returns the display map for a step's state: a Dirac string plus
  per-basis amplitudes and probabilities.

  Same shape `Qx.Register.show_state/1` returns:
  `%{state: dirac, amplitudes: [{basis, "a+bi"}], probabilities: [{basis, p}]}`.

  For steps after a measurement the Dirac string shows the collapsed
  state of that sampled trajectory.

  ## Examples

      iex> qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
      iex> state = Qx.Simulation.get_state(qc)
      iex> step = %Qx.Step{kind: :gate, operation: {:cx, [0, 1], []}, index: 1,
      ...>   state: state, probabilities: Qx.Math.probabilities(state)}
      iex> Qx.Step.show(step).state
      "0.707|00⟩ + 0.707|11⟩"
  """
  @spec show(t()) :: %{state: String.t(), amplitudes: list(), probabilities: list()}
  def show(%__MODULE__{} = step) do
    terms = basis_terms(step)

    %{
      state: Format.dirac_notation(terms),
      amplitudes: Enum.map(terms, fn {basis, amp, _prob} -> {basis, Format.complex(amp)} end),
      probabilities: Enum.map(terms, fn {basis, _amp, prob} -> {basis, prob} end)
    }
  end

  @doc false
  # Shared by show/1 and the Inspect impl: one {basis_label, amplitude,
  # probability} tuple per basis state, in index order.
  @spec basis_terms(t()) :: [{String.t(), Complex.t(), float()}]
  def basis_terms(%__MODULE__{state: state} = step) do
    amplitudes = Nx.to_flat_list(state)
    probabilities = Nx.to_flat_list(step.probabilities || Math.probabilities(state))
    num_qubits = state |> Nx.size() |> then(&trunc(:math.log2(&1)))

    Enum.zip(amplitudes, probabilities)
    |> Enum.with_index()
    |> Enum.map(fn {{amplitude, probability}, index} ->
      {Format.basis_state(index, num_qubits), amplitude, probability}
    end)
  end
end

defimpl Inspect, for: Qx.Step do
  # Single-line rendering, e.g.
  #   #Qx.Step<1: cx(0, 1)  0.707|00⟩ + 0.707|11⟩>
  #   #Qx.Step<4: measure q0 → c0 ⇒ |11⟩  cbits: [1, 1]>
  #   #Qx.Step<6: c_if(c1==1) x(2) taken  |111⟩  cbits: [1, 1, 0]>
  # Dirac strings truncate to the first 4 non-zero terms (+ …).

  alias Qx.{Format, Step}

  @max_dirac_terms 4
  @prob_threshold 1.0e-6

  def inspect(%Step{} = step, _opts) do
    "#Qx.Step<#{step.index}: #{describe(step)}#{cbits(step)}>"
  end

  defp describe(%Step{kind: :measurement, operation: {:measure, [qubit, cbit], _}} = step) do
    "measure q#{qubit} → c#{cbit} ⇒ #{dirac(step)}"
  end

  defp describe(%Step{kind: :conditional, condition: {cbit, value, flag}} = step) do
    "c_if(c#{cbit}==#{value})#{conditional_body(step.operation)} #{flag}  #{dirac(step)}"
  end

  defp describe(%Step{} = step) do
    "#{operation(step.operation)}  #{dirac(step)}"
  end

  defp conditional_body(nil), do: ""
  defp conditional_body(op), do: " #{operation(op)}"

  defp operation(nil), do: ""

  defp operation({gate, qubits, params}) do
    args = Enum.map_join(qubits ++ params, ", ", &to_string/1)
    "#{gate}(#{args})"
  end

  defp cbits(%Step{classical_bits: []}), do: ""
  defp cbits(%Step{classical_bits: bits}), do: "  cbits: #{Kernel.inspect(bits)}"

  defp dirac(%Step{} = step) do
    terms = Step.basis_terms(step)
    significant = Enum.filter(terms, fn {_basis, _amp, prob} -> prob > @prob_threshold end)

    case Enum.split(significant, @max_dirac_terms) do
      # Wide uniform superpositions (n >= 20) put every term below the
      # threshold; show the largest ones instead of a misleading 0.000.
      {[], _} -> terms |> top_terms() |> truncated_dirac(terms)
      {shown, []} -> Format.dirac_notation(shown)
      {shown, _rest} -> Format.dirac_notation(shown) <> " + …"
    end
  end

  defp top_terms(terms) do
    terms
    |> Enum.sort_by(fn {_basis, _amp, prob} -> -prob end)
    |> Enum.take(@max_dirac_terms)
  end

  defp truncated_dirac(shown, all_terms) do
    rendered = Format.dirac_notation(shown, threshold: 0.0)
    if length(all_terms) > length(shown), do: rendered <> " + …", else: rendered
  end
end
