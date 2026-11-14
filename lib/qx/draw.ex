defmodule Qx.Draw do
  @moduledoc """
  Visualization for quantum simulation results.

  Utility module: reached from `Qx.*` in normal use — every function
  here has a `Qx.draw_*` facade delegate (`Qx.draw/2` fronts `plot/2`).

  Every function returns one static artifact type in every
  environment (`spec/api-design-principles.md` §6):

  | Function | Returns | Livebook renders via |
  |---|---|---|
  | `plot/2` | `VegaLite.t()` | kino_vega_lite |
  | `counts/2` | `VegaLite.t()` | kino_vega_lite |
  | `histogram/2` | `VegaLite.t()` | kino_vega_lite |
  | `bloch/2` | `Qx.Draw.Image` | `Kino.Render` |
  | `circuit/2` | `Qx.Draw.Image` | `Kino.Render` |
  | `state_table/2` | `Qx.Draw.StateTable` | `Kino.Render` |

  Nothing here requires Livebook. In a standalone application the
  VegaLite specs feed any Vega renderer, and the `Image`/`StateTable`
  artifacts expose their raw SVG/text/markdown as fields — write them
  to files, serve them, or print them.

  The three VegaLite-returning functions need the optional
  `:vega_lite` dependency and raise `Qx.MissingDependencyError`
  naming the fix when it's absent. The SVG and table artifacts have
  no dependency at all.

  ## Size limit

  `plot/2`, `histogram/2` and `state_table/2` build one bar or row per
  basis state (2^n of them for n qubits), and `counts/2` builds one bar
  per distinct outcome. Each refuses to build more than `2^max_qubits`
  and raises `Qx.DrawSizeError` instead. `:max_qubits` defaults to 12
  (4096 bars or rows); pass a larger value to the call to draw a bigger
  input:

      Qx.Draw.plot(result, max_qubits: 14)

  `bloch/2` and `circuit/2` have no such limit.
  """

  alias Qx.Draw.{Image, Tables}
  alias Qx.Draw.SVG.{Bloch, Circuit}
  alias Qx.Draw.VegaLite, as: VL
  alias Qx.Validation

  # Qx.Draw.VegaLite only compiles when the optional :vega_lite dep is
  # present; every call is behind ensure_vega_lite!/0, so downstream
  # no-vega_lite compiles must not warn on the references.
  @compile {:no_warn_undefined, Qx.Draw.VegaLite}

  @vega_lite_requirement "~> 0.1"

  @doc """
  Plots the probability distribution from a simulation result.

  ## Parameters
    * `result` - Simulation result map containing probabilities
    * `options` - Optional plotting parameters (default: [])

  ## Options
    * `:title` - Plot title (default: "Quantum State Probabilities")
    * `:width` - Plot width (default: 400)
    * `:height` - Plot height (default: 300)
    * `:max_qubits` - Size limit: at most `2^max_qubits` bars are drawn
      (default: 12, so 4096). A positive integer

  ## Returns
  A `VegaLite.t()` chart specification.

  ## Raises
    * `Qx.MissingDependencyError` - if the optional `:vega_lite`
      dependency is not available
    * `Qx.DrawSizeError` - if the result has more than `2^max_qubits`
      basis states
    * `Qx.OptionError` - if `:max_qubits` is not a positive integer

  ## Examples

      qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
      result = Qx.run(qc)
      Qx.Draw.plot(result, title: "Bell State")
  """
  @spec plot(Qx.SimulationResult.t(), keyword()) :: VegaLite.t()
  def plot(result, options \\ []) do
    ensure_vega_lite!()
    validate_size!(Nx.size(result.probabilities), options)
    title = Keyword.get(options, :title, "Quantum State Probabilities")
    width = Keyword.get(options, :width, 400)
    height = Keyword.get(options, :height, 300)

    VL.plot(result, title, width, height)
  end

  @doc """
  Plots measurement counts as a bar chart.

  Works with results from both local simulation (`Qx.run/2`) and remote
  hardware execution (`Qx.Hardware.run/3`).

  ## Parameters
    * `result` - Simulation result containing measurement counts
    * `options` - Optional plotting parameters (default: [])

  ## Options
    * `:title` - Plot title (default: "Measurement Counts")
    * `:width` - Plot width (default: 400)
    * `:height` - Plot height (default: 300)
    * `:max_qubits` - Size limit: at most `2^max_qubits` bars are drawn
      (default: 12, so 4096). A positive integer. The limit is on the
      number of distinct outcomes in the result, not on the number of
      qubits measured

  ## Returns
  A `VegaLite.t()` chart specification.

  ## Raises
    * `Qx.MissingDependencyError` - if the optional `:vega_lite`
      dependency is not available
    * `Qx.DrawSizeError` - if the result has more than `2^max_qubits`
      distinct outcomes
    * `Qx.OptionError` - if `:max_qubits` is not a positive integer

  ## Examples

      qc = Qx.create_circuit(2, 2)
      |> Qx.h(0) |> Qx.cx(0, 1)
      |> Qx.measure(0, 0) |> Qx.measure(1, 1)
      result = Qx.run(qc)
      Qx.Draw.counts(result)
  """
  @spec counts(Qx.SimulationResult.t(), keyword()) :: VegaLite.t()
  def counts(result, options \\ []) do
    ensure_vega_lite!()
    validate_size!(map_size(result.counts), options)
    title = Keyword.get(options, :title, "Measurement Counts")
    width = Keyword.get(options, :width, 400)
    height = Keyword.get(options, :height, 300)

    VL.counts(result, title, width, height)
  end

  @doc """
  Creates a histogram from a raw probability tensor.

  ## Parameters
    * `probabilities` - Nx tensor of probabilities (must sum to 1.0)
    * `options` - Optional plotting parameters (default: [])

  ## Options
    * `:title` - Plot title (default: "Probability Histogram")
    * `:width` - Plot width (default: 400)
    * `:height` - Plot height (default: 300)
    * `:max_qubits` - Size limit: at most `2^max_qubits` bars are drawn
      (default: 12, so 4096). A positive integer

  ## Returns
  A `VegaLite.t()` chart specification.

  ## Raises
    * `Qx.MissingDependencyError` - if the optional `:vega_lite`
      dependency is not available
    * `Qx.DrawSizeError` - if the tensor has more than `2^max_qubits`
      elements
    * `Qx.OptionError` - if `:max_qubits` is not a positive integer

  ## Examples

      qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.h(1)
      probs = Qx.get_probabilities(qc)
      Qx.Draw.histogram(probs)
  """
  @spec histogram(Nx.Tensor.t(), keyword()) :: VegaLite.t()
  def histogram(probabilities, options \\ []) do
    ensure_vega_lite!()
    validate_size!(Nx.size(probabilities), options)
    title = Keyword.get(options, :title, "Probability Histogram")
    width = Keyword.get(options, :width, 400)
    height = Keyword.get(options, :height, 300)

    probabilities_list = Nx.to_flat_list(probabilities)
    num_states = length(probabilities_list)

    data =
      probabilities_list
      |> Enum.with_index()
      |> Enum.map(fn {prob, index} ->
        state_label = Qx.Format.state_label(index, num_states)
        %{"state" => state_label, "probability" => prob}
      end)

    VL.histogram(data, title, width, height)
  end

  @doc """
  Visualizes a single qubit state on the Bloch sphere.

  ## Parameters
    * `qubit` - Single qubit state tensor (2-element c64 tensor)
    * `options` - Optional plotting parameters (default: [])

  ## Options
    * `:title` - Plot title (default: "Bloch Sphere")
    * `:size` - Sphere size (default: 400)

  ## Returns
  A `Qx.Draw.Image` artifact carrying the SVG. Livebook renders it
  inline; standalone applications read `image.svg`.

  ## Examples

      state = Qx.create_circuit(1) |> Qx.h(0) |> Qx.get_state()
      image = Qx.Draw.bloch(state, title: "Plus state")
      File.write!("bloch.svg", image.svg)
  """
  @spec bloch(Nx.Tensor.t(), keyword()) :: Image.t()
  def bloch(qubit, options \\ []) do
    title = Keyword.get(options, :title, "Bloch Sphere")
    size = Keyword.get(options, :size, 400)

    coords = Bloch.qubit_to_bloch_coordinates(qubit)
    %Image{svg: Bloch.render(coords, title, size), title: title}
  end

  @doc """
  Displays a quantum state as a formatted table.

  Shows basis states with their complex amplitudes and probabilities.

  ## Parameters
    * `state` - An `Nx.Tensor` state vector (e.g. from `Qx.get_state/1` or a
      `Qx.Step`). Passing an internal calc-engine Qx.Register struct is
      **deprecated** (emits a runtime warning; removed in Qx 1.0) — use circuit
      mode instead.
    * `options` - Optional formatting parameters (default: [])

  ## Options
    * `:precision` - Number of decimal places (default: 3)
    * `:hide_zeros` - Hide states with near-zero probability (default: `false`)
    * `:max_qubits` - Size limit: a state with more than `2^max_qubits`
      amplitudes is refused (default: 12, so 4096). A positive integer.
      `:hide_zeros` does not lift the limit, because the zero rows are
      dropped only after the whole state has been read. To draw a large
      state with few non-zero amplitudes, pass both:
      `hide_zeros: true, max_qubits: 16`

  ## Returns
  A `Qx.Draw.StateTable` artifact with `:text`, `:markdown`, and
  `:html` renderings as fields. Livebook renders the markdown;
  `to_string/1` gives the text table.

  ## Raises
    * `Qx.DrawSizeError` - if the state has more than `2^max_qubits`
      amplitudes
    * `Qx.OptionError` - if `:max_qubits` is not a positive integer

  ## Examples

      state = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1) |> Qx.get_state()
      table = Qx.Draw.state_table(state)
      table.text
      # => "Basis State | Amplitude ..."
  """
  @spec state_table(Nx.Tensor.t(), keyword()) :: Qx.Draw.StateTable.t()
  def state_table(register_or_state, options \\ []) do
    Tables.render(register_or_state, options)
  end

  @doc """
  Draws a quantum circuit diagram.

  ## Parameters
    * `circuit` - `Qx.QuantumCircuit` struct to visualize
    * `title` - Optional circuit title (default: `nil`)

  ## Returns
  A `Qx.Draw.Image` artifact carrying the SVG diagram (IEEE notation).
  Livebook renders it inline; standalone applications read
  `image.svg`.

  ## Examples

      qc = Qx.create_circuit(2, 2)
      |> Qx.h(0)
      |> Qx.cx(0, 1)
      |> Qx.measure(0, 0)
      |> Qx.measure(1, 1)

      image = Qx.Draw.circuit(qc, "Bell State Circuit")
      File.write!("bell.svg", image.svg)
  """
  @spec circuit(Qx.QuantumCircuit.t(), String.t() | nil) :: Image.t()
  def circuit(%Qx.QuantumCircuit{} = circuit, title \\ nil) do
    %Image{svg: Circuit.render(circuit, title), title: title}
  end

  # The three chart functions need the optional :vega_lite dep; fail
  # fast with the fix in the message instead of an UndefinedFunctionError.
  defp ensure_vega_lite! do
    if !Code.ensure_loaded?(VegaLite) do
      raise Qx.MissingDependencyError, {:vega_lite, @vega_lite_requirement}
    end

    :ok
  end

  # Size cap of the chart functions: at most 2^max_qubits bars. Call it
  # before anything that builds a host-side term per bar (Nx.to_flat_list,
  # Enum.map over the input), so an oversized input costs nothing.
  defp validate_size!(size, options) do
    Validation.validate_draw_size!(size, Validation.draw_max_qubits!(options))
  end
end
