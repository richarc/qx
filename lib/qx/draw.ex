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

  ## Visual style

  The images and charts share one visual language. Structure (wires,
  controls, outlines, axes) is always drawn in ink, and colour carries
  one meaning per picture.

  A circuit diagram colours each gate by its family, that is, by what the
  gate does to the state:

  | Family | Gates |
  |---|---|
  | Pauli | X, Y, Z, the ⊕ of CNOT and Toffoli, controlled-Y |
  | Hadamard | H |
  | Phase | S, S†, T, T†, P(λ), controlled-P |
  | Rotation | Rx, Ry, Rz, U, the controlled rotations |
  | Exchange | SWAP, iSWAP, CSWAP |

  Measurements, classical conditions and barriers are neutral. A control
  dot is ink, and a controlled gate takes the family of the gate it
  controls; CZ is symmetric, so it is two ink dots. A gate is always
  named by its label, so the diagram reads without colour:
  `circuit(qc, style: :mono)` draws it in ink alone.

  On the Bloch sphere the state vector is the only coloured mark. Its
  head is solid when the vector points toward the reader and hollow when
  it points away.

  The three charts are one colour. The probability axis of `plot/2` and
  `histogram/2` runs from 0 to 1, so two charts can be compared by eye;
  when every bar is under 0.2 it fits the data instead.

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

  @chart_options [:title, :width, :height, :max_qubits]

  @doc """
  Plots the probability distribution from a simulation result.

  The probability axis runs from 0 to 1, so two charts can be compared
  by eye. When every bar is under 0.2 (a distribution spread over many
  states) the axis fits the data instead, so the bars can be read. Each bar is labelled with its basis state as a ket (`|01⟩`).
  With more than 16 bars the labels become bare bit strings set
  vertically, and with more than 64 only every fourth is shown. Up to 8
  bars carry their value above them.

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
    * `Qx.OptionError` - if `:max_qubits` is not a positive integer, or
      `options` is not a keyword list of the options above

  ## Examples

      qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
      result = Qx.run(qc)
      Qx.Draw.plot(result, title: "Bell State")
  """
  @spec plot(Qx.SimulationResult.t(), keyword()) :: VegaLite.t()
  def plot(result, options \\ []) do
    ensure_vega_lite!()
    Validation.validate_draw_options!(options, @chart_options)
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

  Bars are in bit-string order and the count axis starts at zero. Each
  bar is labelled with its outcome as a ket (`|01⟩`). With more than 16
  bars the labels become bare bit strings set vertically, and with more
  than 64 only every fourth is shown. Up to 8 bars carry their count
  above them.

  ## Parameters
    * `result` - Simulation result containing measurement counts
    * `options` - Optional plotting parameters (default: [])

  ## Options
    * `:title` - Plot title (default: "Measurement Counts", or "No
      Measurements" for a result with no counts)
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
    * `Qx.OptionError` - if `:max_qubits` is not a positive integer, or
      `options` is not a keyword list of the options above

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
    Validation.validate_draw_options!(options, @chart_options)
    validate_size!(map_size(result.counts), options)

    default_title =
      if map_size(result.counts) == 0, do: "No Measurements", else: "Measurement Counts"

    title = Keyword.get(options, :title, default_title)
    width = Keyword.get(options, :width, 400)
    height = Keyword.get(options, :height, 300)

    VL.counts(result, title, width, height)
  end

  @doc """
  Creates a histogram from a raw probability tensor.

  The probability axis runs from 0 to 1, so two charts can be compared
  by eye. When every bar is under 0.2 (a distribution spread over many
  states) the axis fits the data instead, so the bars can be read. Each bar is labelled with its basis state as a ket (`|01⟩`).
  With more than 16 bars the labels become bare bit strings set
  vertically, and with more than 64 only every fourth is shown. Up to 8
  bars carry their value above them.

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
    * `Qx.OptionError` - if `:max_qubits` is not a positive integer, or
      `options` is not a keyword list of the options above

  ## Examples

      qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.h(1)
      probs = Qx.get_probabilities(qc)
      Qx.Draw.histogram(probs)
  """
  @spec histogram(Nx.Tensor.t(), keyword()) :: VegaLite.t()
  def histogram(probabilities, options \\ []) do
    ensure_vega_lite!()
    Validation.validate_draw_options!(options, @chart_options)
    validate_size!(Nx.size(probabilities), options)
    title = Keyword.get(options, :title, "Probability Histogram")
    width = Keyword.get(options, :width, 400)
    height = Keyword.get(options, :height, 300)

    VL.histogram(Nx.to_flat_list(probabilities), title, width, height)
  end

  @doc """
  Visualizes a single qubit state on the Bloch sphere.

  The sphere is drawn with x toward the reader and to the left, y to the
  right and z up. The state vector is the one coloured mark: its head is
  solid when the tip is on the near hemisphere and hollow when it is on
  the far one, and a vector aimed straight at or away from the reader
  ends in a dot. A dashed line drops from the tip to the equatorial
  plane, arcs mark θ and φ, and both angles are written under the sphere
  as fractions of π, with φ from 0 up to 2π.

  ## Parameters
    * `qubit` - Single qubit state tensor (2-element c64 tensor)
    * `options` - Optional plotting parameters (default: [])

  ## Options
    * `:title` - Plot title, or `nil` or `""` for none (default: "Bloch
      Sphere")
    * `:size` - Width and height of the image in pixels, up to 10000
      (default: 400). Everything scales with it; text and lines stop shrinking at 80% of
      their default size, so a small sphere stays legible

  ## Returns
  A `Qx.Draw.Image` artifact carrying the SVG. Livebook renders it
  inline; standalone applications read `image.svg`.

  ## Raises
    * `Qx.OptionError` - if `:title` is not a string or `nil`, `:size` is
      not a positive number up to 10000, or `options` is not a keyword
      list of the options above
    * `Qx.StateShapeError` - if `qubit` is not a tensor of two amplitudes
    * `Qx.StateNormalizationError` - if an amplitude is NaN or infinite

  ## Examples

      state = Qx.create_circuit(1) |> Qx.h(0) |> Qx.get_state()
      image = Qx.Draw.bloch(state, title: "Plus state")
      File.write!("bloch.svg", image.svg)
  """
  @spec bloch(Nx.Tensor.t(), keyword()) :: Image.t()
  def bloch(qubit, options \\ []) do
    Validation.validate_draw_options!(options, [:title, :size])
    title = options |> Keyword.get(:title, "Bloch Sphere") |> Validation.validate_draw_title!()
    size = options |> Keyword.get(:size, 400) |> Validation.validate_draw_image_size!()

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

  The diagram is drawn the way quantikz draws one: thin ink wires, boxed
  gates labelled as mathematics, a dot for a control and ⊕ for a target.
  Each gate is coloured by its family (see "Visual style" in the module
  documentation). A box widens to fit its label, and every gate in that
  column shares the wider slot.

  ## Parameters
    * `circuit` - `Qx.QuantumCircuit` struct to visualize
    * `title_or_options` - The title (a string or `nil`), or a keyword
      list of options (default: `nil`)

  ## Options
    * `:title` - Diagram title, drawn above the circuit (default: `nil`;
      `""` is also no title)
    * `:style` - `:color` (default) or `:mono`. The mono style draws every
      gate in ink on white, for print and papers

  ## Returns
  A `Qx.Draw.Image` artifact carrying the SVG diagram. Livebook renders
  it inline; standalone applications read `image.svg`.

  ## Raises
    * `Qx.OptionError` - if `:style` is not `:color` or `:mono`, `:title`
      is not a string or `nil`, an option is not one of the two above, or
      the second argument is neither a title nor a keyword list
    * `Qx.QubitCountError` - if the circuit has more than 20 qubits
    * `Qx.GateError` - if a barrier has no qubits, an angle is too large
      to draw, or an instruction of a circuit built by hand does not have
      the shape its gate takes

  ## Examples

      qc = Qx.create_circuit(2, 2)
      |> Qx.h(0)
      |> Qx.cx(0, 1)
      |> Qx.measure(0, 0)
      |> Qx.measure(1, 1)

      image = Qx.Draw.circuit(qc, "Bell State Circuit")
      File.write!("bell.svg", image.svg)

      # The same diagram without colour
      Qx.Draw.circuit(qc, title: "Bell State Circuit", style: :mono)
  """
  @spec circuit(Qx.QuantumCircuit.t(), String.t() | nil | keyword()) :: Image.t()
  def circuit(%Qx.QuantumCircuit{} = circuit, title_or_options \\ nil) do
    {title, style} = Validation.draw_circuit_options!(title_or_options)
    %Image{svg: Circuit.render(circuit, title: title, style: style), title: title}
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
