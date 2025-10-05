defmodule Qx.Draw do
  @moduledoc """
  Visualization functions for quantum simulation results.

  This module provides functions for plotting quantum simulation results,
  including probability distributions and measurement outcomes, with support
  for SVG output and LiveBook integration with VegaLite.
  """

  @doc """
  Plots the probability distribution from a simulation result.

  This is a convenience function for visualizing the probability distribution
  directly from a simulation result map returned by `Qx.run/1` or `Qx.run/2`.
  The probabilities are automatically extracted from the result.

  For more control or to plot raw probability tensors (e.g., from
  `Qx.get_probabilities/1`), use `histogram/2` instead.

  ## Parameters
    * `result` - Simulation result map containing probabilities
    * `options` - Optional plotting parameters (default: [])

  ## Options
    * `:format` - Output format (:svg, :vega_lite) (default: :vega_lite)
    * `:title` - Plot title (default: "Quantum State Probabilities")
    * `:width` - Plot width (default: 400)
    * `:height` - Plot height (default: 300)

  ## Examples

      # Quick visualization from simulation result
      iex> qc = Qx.QuantumCircuit.new(2, 0) |> Qx.Operations.h(0)
      iex> result = Qx.Simulation.run(qc)
      iex> Qx.Draw.plot(result)
      # Returns VegaLite specification

  ## See Also
    * `histogram/2` - For plotting raw probability tensors
    * `plot_counts/2` - For plotting measurement counts
  """
  def plot(result, options \\ []) do
    format = Keyword.get(options, :format, :vega_lite)
    title = Keyword.get(options, :title, "Quantum State Probabilities")
    width = Keyword.get(options, :width, 400)
    height = Keyword.get(options, :height, 300)

    case format do
      :vega_lite ->
        plot_vega_lite(result, title, width, height)

      :svg ->
        plot_svg(result, title, width, height)

      _ ->
        raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  @doc """
  Plots measurement counts as a bar chart.

  ## Parameters
    * `result` - Simulation result containing measurement counts
    * `options` - Optional plotting parameters (default: [])

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 2)
      iex> qc = qc |> Qx.Operations.h(0) |> Qx.Operations.cx(0, 1)
      iex> qc = qc |> Qx.Operations.measure(0, 0) |> Qx.Operations.measure(1, 1)
      iex> result = Qx.Simulation.run(qc)
      iex> Qx.Draw.plot_counts(result)
      # Returns VegaLite specification for measurement counts
  """
  def plot_counts(result, options \\ []) do
    format = Keyword.get(options, :format, :vega_lite)
    title = Keyword.get(options, :title, "Measurement Counts")
    width = Keyword.get(options, :width, 400)
    height = Keyword.get(options, :height, 300)

    case format do
      :vega_lite ->
        plot_counts_vega_lite(result, title, width, height)

      :svg ->
        plot_counts_svg(result, title, width, height)

      _ ->
        raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  @doc """
  Creates a histogram from a raw probability tensor.

  This function provides more control for visualizing probability distributions
  when you already have a probability tensor (e.g., from `Qx.get_probabilities/1`
  or custom calculations). Unlike `plot/2`, this operates directly on probability
  tensors rather than simulation result maps.

  Use this when you need to:
  - Plot probabilities obtained without running a full simulation
  - Compare multiple probability distributions
  - Customize visualization of theoretical probability distributions

  ## Parameters
    * `probabilities` - Nx tensor of probabilities (must sum to 1.0)
    * `options` - Optional plotting parameters (default: [])

  ## Options
    * `:format` - Output format (:svg, :vega_lite) (default: :vega_lite)
    * `:title` - Plot title (default: "Probability Histogram")
    * `:width` - Plot width (default: 400)
    * `:height` - Plot height (default: 300)

  ## Examples

      # Plot probabilities from get_probabilities/1
      iex> qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.h(1)
      iex> probs = Qx.get_probabilities(qc)
      iex> Qx.Draw.histogram(probs)
      # Returns VegaLite specification

      # Plot custom probability distribution
      iex> custom_probs = Nx.tensor([0.5, 0.5, 0.0, 0.0])
      iex> Qx.Draw.histogram(custom_probs, title: "Custom Distribution")
      # Returns VegaLite specification

  ## See Also
    * `plot/2` - For plotting directly from simulation results
    * `get_probabilities/1` - To obtain probability tensors from circuits
  """
  def histogram(probabilities, options \\ []) do
    format = Keyword.get(options, :format, :vega_lite)
    title = Keyword.get(options, :title, "Probability Histogram")
    width = Keyword.get(options, :width, 400)
    height = Keyword.get(options, :height, 300)

    # Convert probabilities to data format
    prob_list = Nx.to_flat_list(probabilities)
    num_states = length(prob_list)

    data =
      prob_list
      |> Enum.with_index()
      |> Enum.map(fn {prob, index} ->
        state_label =
          "|#{Integer.to_string(index, 2) |> String.pad_leading(trunc(:math.log2(num_states)), "0")}⟩"

        %{"state" => state_label, "probability" => prob, "index" => index}
      end)

    case format do
      :vega_lite ->
        histogram_vega_lite(data, title, width, height)

      :svg ->
        histogram_svg(data, title, width, height)

      _ ->
        raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  # Private helper functions

  defp plot_vega_lite(result, title, width, height) do
    probabilities = Nx.to_flat_list(result.probabilities)
    num_states = length(probabilities)

    data =
      probabilities
      |> Enum.with_index()
      |> Enum.map(fn {prob, index} ->
        state_label = format_state_label(index, num_states)
        %{"state" => state_label, "probability" => prob}
      end)

    VegaLite.new(width: width, height: height, title: title)
    |> VegaLite.data_from_values(data)
    |> VegaLite.mark(:bar)
    |> VegaLite.encode_field(:x, "state", type: :nominal, title: "Quantum State")
    |> VegaLite.encode_field(:y, "probability", type: :quantitative, title: "Probability")
    |> VegaLite.encode(:color, value: "#1f77b4")
  end

  defp plot_counts_vega_lite(result, title, width, height) do
    if result.counts == %{} do
      # No measurements, show empty plot
      VegaLite.new(width: width, height: height, title: "No Measurements")
      |> VegaLite.data_from_values([])
      |> VegaLite.mark(:bar)
    else
      data =
        result.counts
        |> Enum.map(fn {bit_string, count} ->
          label = Enum.join(bit_string, "")
          %{"measurement" => label, "count" => count}
        end)

      VegaLite.new(width: width, height: height, title: title)
      |> VegaLite.data_from_values(data)
      |> VegaLite.mark(:bar)
      |> VegaLite.encode_field(:x, "measurement", type: :nominal, title: "Measurement Outcome")
      |> VegaLite.encode_field(:y, "count", type: :quantitative, title: "Count")
      |> VegaLite.encode(:color, value: "#ff7f0e")
    end
  end

  defp histogram_vega_lite(data, title, width, height) do
    VegaLite.new(width: width, height: height, title: title)
    |> VegaLite.data_from_values(data)
    |> VegaLite.mark(:bar)
    |> VegaLite.encode_field(:x, "state", type: :nominal, title: "Quantum State")
    |> VegaLite.encode_field(:y, "probability", type: :quantitative, title: "Probability")
    |> VegaLite.encode(:color, value: "#2ca02c")
  end

  defp plot_svg(result, title, width, height) do
    probabilities = Nx.to_flat_list(result.probabilities)
    num_states = length(probabilities)
    max_prob = Enum.max(probabilities)

    # Calculate bar dimensions
    bar_width = width / num_states * 0.8
    bar_spacing = width / num_states * 0.2

    # Generate SVG bars
    bars =
      probabilities
      |> Enum.with_index()
      |> Enum.map(fn {prob, index} ->
        bar_height = if max_prob > 0, do: prob / max_prob * (height - 50), else: 0
        x = index * (bar_width + bar_spacing) + bar_spacing / 2
        y = height - 30 - bar_height

        state_label = format_state_label(index, num_states)

        """
        <rect x="#{x}" y="#{y}" width="#{bar_width}" height="#{bar_height}"
              fill="#1f77b4" stroke="#000" stroke-width="0.5"/>
        <text x="#{x + bar_width / 2}" y="#{height - 10}" text-anchor="middle"
              font-size="10" font-family="Arial">#{state_label}</text>
        <text x="#{x + bar_width / 2}" y="#{y - 5}" text-anchor="middle"
              font-size="8" font-family="Arial">#{Float.round(prob, 3)}</text>
        """
      end)
      |> Enum.join("\n")

    """
    <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
      <title>#{title}</title>
      <text x="#{width / 2}" y="20" text-anchor="middle" font-size="14" font-family="Arial" font-weight="bold">#{title}</text>
      #{bars}
      <text x="#{width / 2}" y="#{height - 2}" text-anchor="middle" font-size="12" font-family="Arial">Quantum State</text>
    </svg>
    """
  end

  defp plot_counts_svg(result, title, width, height) do
    if result.counts == %{} do
      """
      <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
        <title>No Measurements</title>
        <text x="#{width / 2}" y="#{height / 2}" text-anchor="middle" font-size="14" font-family="Arial">No Measurements</text>
      </svg>
      """
    else
      counts = Enum.to_list(result.counts)
      max_count = counts |> Enum.map(&elem(&1, 1)) |> Enum.max()
      num_outcomes = length(counts)

      # Calculate bar dimensions
      bar_width = width / num_outcomes * 0.8
      bar_spacing = width / num_outcomes * 0.2

      bars =
        counts
        |> Enum.with_index()
        |> Enum.map(fn {{bit_string, count}, index} ->
          bar_height = if max_count > 0, do: count / max_count * (height - 50), else: 0
          x = index * (bar_width + bar_spacing) + bar_spacing / 2
          y = height - 30 - bar_height

          label = Enum.join(bit_string, "")

          """
          <rect x="#{x}" y="#{y}" width="#{bar_width}" height="#{bar_height}"
                fill="#ff7f0e" stroke="#000" stroke-width="0.5"/>
          <text x="#{x + bar_width / 2}" y="#{height - 10}" text-anchor="middle"
                font-size="10" font-family="Arial">#{label}</text>
          <text x="#{x + bar_width / 2}" y="#{y - 5}" text-anchor="middle"
                font-size="8" font-family="Arial">#{count}</text>
          """
        end)
        |> Enum.join("\n")

      """
      <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
        <title>#{title}</title>
        <text x="#{width / 2}" y="20" text-anchor="middle" font-size="14" font-family="Arial" font-weight="bold">#{title}</text>
        #{bars}
        <text x="#{width / 2}" y="#{height - 2}" text-anchor="middle" font-size="12" font-family="Arial">Measurement Outcome</text>
      </svg>
      """
    end
  end

  defp histogram_svg(data, title, width, height) do
    max_prob = data |> Enum.map(&Map.get(&1, "probability")) |> Enum.max()
    num_states = length(data)

    # Calculate bar dimensions
    bar_width = width / num_states * 0.8
    bar_spacing = width / num_states * 0.2

    bars =
      data
      |> Enum.with_index()
      |> Enum.map(fn {%{"state" => state, "probability" => prob}, index} ->
        bar_height = if max_prob > 0, do: prob / max_prob * (height - 50), else: 0
        x = index * (bar_width + bar_spacing) + bar_spacing / 2
        y = height - 30 - bar_height

        """
        <rect x="#{x}" y="#{y}" width="#{bar_width}" height="#{bar_height}"
              fill="#2ca02c" stroke="#000" stroke-width="0.5"/>
        <text x="#{x + bar_width / 2}" y="#{height - 10}" text-anchor="middle"
              font-size="10" font-family="Arial">#{state}</text>
        <text x="#{x + bar_width / 2}" y="#{y - 5}" text-anchor="middle"
              font-size="8" font-family="Arial">#{Float.round(prob, 3)}</text>
        """
      end)
      |> Enum.join("\n")

    """
    <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
      <title>#{title}</title>
      <text x="#{width / 2}" y="20" text-anchor="middle" font-size="14" font-family="Arial" font-weight="bold">#{title}</text>
      #{bars}
      <text x="#{width / 2}" y="#{height - 2}" text-anchor="middle" font-size="12" font-family="Arial">Quantum State</text>
    </svg>
    """
  end

  defp format_state_label(index, num_states) do
    num_qubits = trunc(:math.log2(num_states))
    binary_string = Integer.to_string(index, 2) |> String.pad_leading(num_qubits, "0")
    "|#{binary_string}⟩"
  end

  # ============================================================================
  # Circuit Visualization Functions
  # ============================================================================

  @doc """
  Draws a quantum circuit diagram.

  ## Parameters
    * `circuit` - QuantumCircuit to visualize
    * `title` - Optional circuit title (default: nil)

  ## Examples

      iex> qc = Qx.QuantumCircuit.new(2, 2)
      iex> qc = qc |> Qx.Operations.h(0) |> Qx.Operations.cx(0, 1)
      iex> svg = Qx.Draw.circuit(qc)
      # Returns SVG string
  """
  def circuit(%Qx.QuantumCircuit{} = circuit, title \\ nil) do
    # Validate circuit
    validate_circuit!(circuit)

    # Analyze circuit and create layout
    diagram = analyze_circuit(circuit, title)

    # Generate SVG
    generate_svg(diagram)
  end

  # Private data structure for circuit diagram
  defmodule CircuitDiagram do
    @moduledoc false
    defstruct [
      :num_qubits,
      :num_classical_bits,
      :width,
      :height,
      :title,
      :instructions,
      :measurements,
      :gate_layout,
      :num_columns
    ]
  end

  # Constants for circuit visualization
  @gate_width 30
  @gate_height 30
  @qubit_spacing 45
  @gate_spacing 40
  @padding 20
  @control_radius 4.5
  @target_radius 10.5
  @measure_radius 10.5
  @line_thickness 2
  @gate_border_thickness 1.5
  @barrier_dash "3.7,1.6"
  @font_family "Helvetica"
  @label_font_size 13
  @gate_font_size 10
  @title_font_size 15

  # Colors
  @color_pauli_x "#fa4d56"
  @color_hadamard "#33b1ff"
  @color_control_small "#002d9c"
  @color_control_large "#33b1ff"
  @color_measurement "#a8a8a8"
  @color_barrier "#a8a8a8"
  @color_classical_line "#778899"

  # Validates circuit before drawing
  defp validate_circuit!(%Qx.QuantumCircuit{} = circuit) do
    # Check qubit limit
    if circuit.num_qubits > 20 do
      raise ArgumentError, "Circuit exceeds maximum of 20 qubits (has #{circuit.num_qubits})"
    end

    # Validate all instructions
    Enum.each(circuit.instructions, fn {gate_name, qubits, params} ->
      validate_gate!(gate_name, qubits, params, circuit.num_qubits)
    end)

    # Validate all measurements
    Enum.each(circuit.measurements, fn {qubit, classical_bit} ->
      if qubit < 0 or qubit >= circuit.num_qubits do
        raise ArgumentError, "Invalid qubit index #{qubit}"
      end

      if classical_bit < 0 or classical_bit >= circuit.num_classical_bits do
        raise ArgumentError, "Invalid classical bit index #{classical_bit}"
      end
    end)

    :ok
  end

  # Validates a gate instruction
  defp validate_gate!(gate_name, qubits, _params, num_qubits) do
    # Check if gate is supported
    supported_gates = [:h, :x, :y, :z, :s, :t, :rx, :ry, :rz, :p, :cx, :cz, :ccx, :barrier, :measure, :c_if]

    unless gate_name in supported_gates do
      raise ArgumentError, "Unsupported gate type: #{gate_name}"
    end

    # Validate qubit indices (skip for c_if which has classical bit indices)
    unless gate_name == :c_if do
      Enum.each(qubits, fn qubit ->
        if qubit < 0 or qubit >= num_qubits do
          raise ArgumentError, "Invalid qubit index #{qubit} for gate #{gate_name}"
        end
      end)
    end
  end

  # Analyzes circuit and creates layout
  defp analyze_circuit(%Qx.QuantumCircuit{} = circuit, title) do
    # Measurements are now in circuit.instructions for proper timeline ordering
    # So we just use circuit.instructions directly
    all_operations = circuit.instructions

    # Layout gates with collision avoidance
    {gate_layout, num_columns} = layout_gates(all_operations, circuit.num_qubits)

    # Calculate dimensions
    label_width = 60
    title_height = if title, do: 40, else: 0

    width =
      label_width + num_columns * (@gate_width + @gate_spacing) + @gate_spacing + 2 * @padding

    qubit_area_height = (circuit.num_qubits - 1) * @qubit_spacing + @gate_height
    classical_height = if circuit.num_classical_bits > 0, do: @qubit_spacing + 30, else: 0

    height = title_height + qubit_area_height + classical_height + 2 * @padding

    %CircuitDiagram{
      num_qubits: circuit.num_qubits,
      num_classical_bits: circuit.num_classical_bits,
      width: width,
      height: height,
      title: title,
      instructions: circuit.instructions,
      measurements: circuit.measurements,
      gate_layout: gate_layout,
      num_columns: num_columns
    }
  end

  # Layout gates with collision avoidance
  defp layout_gates(operations, num_qubits) do
    # Track which column each qubit is currently at
    qubit_columns = for i <- 0..(num_qubits - 1), into: %{}, do: {i, 0}
    initial_state = {[], qubit_columns, 0}

    {layout, _final_columns, max_column} =
      Enum.reduce(operations, initial_state, fn operation, {layout, columns, max_col} ->
        {gate_name, qubits, params} = operation

        # Handle c_if by expanding sub-instructions
        if gate_name == :c_if do
          # Extract conditional metadata
          [classical_bit, value] = qubits
          sub_instructions = params

          # Process each sub-instruction as a conditional gate
          Enum.reduce(sub_instructions, {layout, columns, max_col}, fn sub_instr, {sub_layout, sub_columns, sub_max_col} ->
            {sub_gate_name, sub_qubits, sub_params} = sub_instr

            # Find column for this gate
            column = find_available_column(sub_gate_name, sub_qubits, sub_columns, num_qubits)

            # Update columns - conditionals also need vertical lines to classical register
            qubits_to_update =
              if needs_vertical_line?(sub_gate_name) do
                if sub_gate_name == :measure do
                  qubit = hd(sub_qubits)
                  Enum.to_list(qubit..(num_qubits - 1))
                else
                  min_q = Enum.min(sub_qubits)
                  max_q = Enum.max(sub_qubits)
                  Enum.to_list(min_q..max_q)
                end
              else
                # For conditional gates, mark from gate qubit to last qubit (classical register below)
                qubit = hd(sub_qubits)
                Enum.to_list(qubit..(num_qubits - 1))
              end

            new_columns =
              Enum.reduce(qubits_to_update, sub_columns, fn qubit, cols ->
                Map.put(cols, qubit, column + 1)
              end)

            # Add to layout with conditional metadata
            gate_info = %{
              gate: sub_gate_name,
              qubits: sub_qubits,
              params: sub_params,
              column: column,
              conditional: %{classical_bit: classical_bit, value: value}
            }

            {[gate_info | sub_layout], new_columns, max(sub_max_col, column)}
          end)
        else
          # Regular gate processing
          column = find_available_column(gate_name, qubits, columns, num_qubits)

          qubits_to_update =
            if needs_vertical_line?(gate_name) do
              if gate_name == :measure do
                qubit = hd(qubits)
                Enum.to_list(qubit..(num_qubits - 1))
              else
                min_q = Enum.min(qubits)
                max_q = Enum.max(qubits)
                Enum.to_list(min_q..max_q)
              end
            else
              qubits
            end

          new_columns =
            Enum.reduce(qubits_to_update, columns, fn qubit, cols ->
              Map.put(cols, qubit, column + 1)
            end)

          gate_info = %{
            gate: gate_name,
            qubits: qubits,
            params: params,
            column: column
          }

          {[gate_info | layout], new_columns, max(max_col, column)}
        end
      end)

    {Enum.reverse(layout), max_column + 1}
  end

  # Find the first available column for a gate considering collision avoidance
  defp find_available_column(gate_name, qubits, columns, num_qubits) do
    # Get the minimum column where all affected qubits are free
    min_column = qubits |> Enum.map(&Map.get(columns, &1, 0)) |> Enum.max()

    # For gates with vertical lines (multi-qubit gates and measurements),
    # we need to check if any intermediate qubits have gates in this column
    if needs_vertical_line?(gate_name) do
      check_collision_and_advance(gate_name, qubits, columns, min_column, num_qubits)
    else
      min_column
    end
  end

  # Check if gate needs a vertical connecting line
  defp needs_vertical_line?(gate_name) do
    gate_name in [:cx, :cz, :ccx, :measure]
  end

  # Check for collisions along the vertical path and advance if needed
  defp check_collision_and_advance(gate_name, qubits, columns, column, num_qubits) do
    # For measurements, the vertical line goes from the qubit to the classical register
    # which is below all qubits, so we need to check ALL qubits below the measured qubit
    {min_qubit, max_qubit} =
      if gate_name == :measure do
        # Measurement: check from measured qubit to the last qubit (below which is classical register)
        qubit = hd(qubits)
        {qubit, num_qubits - 1}
      else
        # Multi-qubit gates: check between control and target qubits
        {Enum.min(qubits), Enum.max(qubits)}
      end

    # Check all qubits along the vertical path (including the gate's own qubits for measurements)
    # This ensures vertical lines don't overlap with ANY gates in the same column
    qubits_to_check = for q <- min_qubit..max_qubit, do: q

    has_collision? =
      Enum.any?(qubits_to_check, fn q ->
        # Check if this qubit has a gate that extends into or past this column
        Map.get(columns, q, 0) > column
      end)

    if has_collision? do
      # Advance to next column and check again
      check_collision_and_advance(gate_name, qubits, columns, column + 1, num_qubits)
    else
      column
    end
  end

  # Generate SVG from circuit diagram
  defp generate_svg(%CircuitDiagram{} = diagram) do
    label_width = 60
    title_height = if diagram.title, do: 40, else: 0
    start_x = label_width + @padding
    start_y = title_height + @padding

    title_svg = if diagram.title, do: render_title(diagram), else: ""
    lines_svg = render_lines(diagram, start_x, start_y, label_width)
    gates_svg = render_gates(diagram, start_x, start_y)

    """
    <?xml version="1.0" encoding="utf-8" standalone="no"?>
    <svg xmlns="http://www.w3.org/2000/svg" width="#{diagram.width}" height="#{diagram.height}" viewBox="0 0 #{diagram.width} #{diagram.height}">
      <rect width="#{diagram.width}" height="#{diagram.height}" fill="#ffffff"/>
      #{title_svg}
      #{lines_svg}
      #{gates_svg}
    </svg>
    """
  end

  # Render circuit title
  defp render_title(%CircuitDiagram{title: title, width: width}) do
    """
      <text x="#{width / 2}" y="25" text-anchor="middle" font-family="#{@font_family}" font-size="#{@title_font_size}">#{title}</text>
    """
  end

  # Render qubit and classical bit lines with labels
  defp render_lines(%CircuitDiagram{} = diagram, start_x, start_y, _label_width) do
    line_end_x =
      start_x + diagram.num_columns * (@gate_width + @gate_spacing) + @gate_spacing

    # Render qubit lines
    qubit_lines =
      for q <- 0..(diagram.num_qubits - 1) do
        y = start_y + q * @qubit_spacing

        """
          <line x1="#{start_x}" y1="#{y}" x2="#{line_end_x}" y2="#{y}" stroke="#000000" stroke-width="#{@line_thickness}"/>
          <text x="#{start_x - 10}" y="#{y + 5}" text-anchor="end" font-family="#{@font_family}" font-size="#{@label_font_size}">q<tspan baseline-shift="sub" font-size="#{@label_font_size * 0.7}">#{q}</tspan></text>
        """
      end
      |> Enum.join("\n")

    # Render classical bit lines if present
    classical_lines =
      if diagram.num_classical_bits > 0 do
        y = start_y + diagram.num_qubits * @qubit_spacing + 20
        y2 = y + 3

        """
          <line x1="#{start_x}" y1="#{y}" x2="#{line_end_x}" y2="#{y}" stroke="#{@color_classical_line}" stroke-width="#{@line_thickness}"/>
          <line x1="#{start_x}" y1="#{y2}" x2="#{line_end_x}" y2="#{y2}" stroke="#{@color_classical_line}" stroke-width="#{@line_thickness}"/>
          <text x="#{start_x - 10}" y="#{y + 5}" text-anchor="end" font-family="#{@font_family}" font-size="#{@label_font_size}">c/#{diagram.num_classical_bits}</text>
        """
      else
        ""
      end

    qubit_lines <> classical_lines
  end

  # Render all gates
  defp render_gates(%CircuitDiagram{} = diagram, start_x, start_y) do
    diagram.gate_layout
    |> Enum.map(fn gate_info ->
      render_gate(gate_info, diagram, start_x, start_y)
    end)
    |> Enum.join("\n")
  end

  # Render a single gate
  defp render_gate(gate_info, diagram, start_x, start_y) do
    %{gate: gate_name, qubits: qubits, params: params, column: column} = gate_info
    gate_x = start_x + column * (@gate_width + @gate_spacing) + @gate_spacing

    # Render the gate itself
    gate_svg =
      case gate_name do
        :barrier -> render_barrier(qubits, gate_x, start_y, diagram)
        :measure -> render_measurement(qubits, params, gate_x, start_y, diagram)
        :cx -> render_cnot(qubits, gate_x, start_y)
        :cz -> render_controlled_z(qubits, gate_x, start_y)
        :ccx -> render_toffoli(qubits, gate_x, start_y)
        _ -> render_single_qubit_gate(gate_name, qubits, params, gate_x, start_y)
      end

    # Add conditional control lines if this gate is conditional
    conditional_svg =
      if Map.has_key?(gate_info, :conditional) do
        render_classical_control(gate_info, gate_x, start_y, diagram)
      else
        ""
      end

    gate_svg <> conditional_svg
  end

  # Render barrier
  defp render_barrier(_qubits, gate_x, start_y, diagram) do
    y1 = start_y
    y2 = start_y + (diagram.num_qubits - 1) * @qubit_spacing

    """
      <line x1="#{gate_x}" y1="#{y1}" x2="#{gate_x}" y2="#{y2}" stroke="#{@color_barrier}" stroke-width="1" stroke-dasharray="#{@barrier_dash}" opacity="0.6"/>
    """
  end

  # Render measurement
  defp render_measurement([qubit, _classical_bit], _params, gate_x, start_y, diagram) do
    qubit_y = start_y + qubit * @qubit_spacing
    classical_y = start_y + diagram.num_qubits * @qubit_spacing + 20 + 1.5

    # Measurement box
    box_x = gate_x - @gate_width / 2
    box_y = qubit_y - @gate_height / 2

    # Arc and arrow for measurement symbol
    arc_cx = gate_x
    arc_cy = qubit_y + 3
    arc_start_x = gate_x - @measure_radius * 0.7
    arc_start_y = qubit_y + 3
    arc_end_x = gate_x + @measure_radius * 0.7
    arc_end_y = qubit_y + 3
    arrow_x = gate_x + @measure_radius * 0.5
    arrow_y = qubit_y - @measure_radius * 0.5

    # Vertical line to classical register
    # Triangular arrow pointing down
    arrow_tip_y = classical_y + 8
    arrow_left_x = gate_x - 6
    arrow_left_y = classical_y - 1
    arrow_right_x = gate_x + 6
    arrow_right_y = classical_y - 1

    """
      <rect x="#{box_x}" y="#{box_y}" width="#{@gate_width}" height="#{@gate_height}" fill="#{@color_measurement}" stroke="#{@color_measurement}" stroke-width="#{@gate_border_thickness}"/>
      <path d="M #{arc_start_x} #{arc_start_y} A #{@measure_radius * 0.7} #{@measure_radius * 0.7} 0 0 1 #{arc_end_x} #{arc_end_y}" fill="none" stroke="#000000" stroke-width="2"/>
      <line x1="#{arc_cx}" y1="#{arc_cy}" x2="#{arrow_x}" y2="#{arrow_y}" stroke="#000000" stroke-width="2"/>
      <line x1="#{gate_x}" y1="#{qubit_y + @gate_height / 2}" x2="#{gate_x}" y2="#{classical_y}" stroke="#{@color_classical_line}" stroke-width="#{@line_thickness}"/>
      <polygon points="#{gate_x},#{arrow_tip_y} #{arrow_left_x},#{arrow_left_y} #{arrow_right_x},#{arrow_right_y}" fill="#{@color_classical_line}"/>
    """
  end

  # Render CNOT gate
  defp render_cnot([control, target], gate_x, start_y) do
    control_y = start_y + control * @qubit_spacing
    target_y = start_y + target * @qubit_spacing

    # Control dot
    control_svg = """
      <circle cx="#{gate_x}" cy="#{control_y}" r="#{@control_radius}" fill="#{@color_control_small}" stroke="#{@color_control_small}" stroke-width="#{@gate_border_thickness}"/>
    """

    # Target circle with plus
    target_svg = """
      <circle cx="#{gate_x}" cy="#{target_y}" r="#{@target_radius}" fill="none" stroke="#000000" stroke-width="2"/>
      <line x1="#{gate_x - @target_radius}" y1="#{target_y}" x2="#{gate_x + @target_radius}" y2="#{target_y}" stroke="#000000" stroke-width="2"/>
      <line x1="#{gate_x}" y1="#{target_y - @target_radius}" x2="#{gate_x}" y2="#{target_y + @target_radius}" stroke="#000000" stroke-width="2"/>
    """

    # Connecting line
    line_svg = """
      <line x1="#{gate_x}" y1="#{control_y}" x2="#{gate_x}" y2="#{target_y}" stroke="#{@color_control_large}" stroke-width="#{@line_thickness}"/>
    """

    line_svg <> control_svg <> target_svg
  end

  # Render controlled-Z gate
  defp render_controlled_z([control, target], gate_x, start_y) do
    control_y = start_y + control * @qubit_spacing
    target_y = start_y + target * @qubit_spacing

    # Control dot
    control_svg = """
      <circle cx="#{gate_x}" cy="#{control_y}" r="#{@control_radius}" fill="#{@color_control_small}" stroke="#{@color_control_small}" stroke-width="#{@gate_border_thickness}"/>
    """

    # Target dot (CZ uses a dot on target too)
    target_svg = """
      <circle cx="#{gate_x}" cy="#{target_y}" r="#{@control_radius}" fill="#{@color_control_small}" stroke="#{@color_control_small}" stroke-width="#{@gate_border_thickness}"/>
    """

    # Connecting line
    line_svg = """
      <line x1="#{gate_x}" y1="#{control_y}" x2="#{gate_x}" y2="#{target_y}" stroke="#{@color_control_large}" stroke-width="#{@line_thickness}"/>
    """

    line_svg <> control_svg <> target_svg
  end

  # Render Toffoli (CCX) gate
  defp render_toffoli([control1, control2, target], gate_x, start_y) do
    control1_y = start_y + control1 * @qubit_spacing
    control2_y = start_y + control2 * @qubit_spacing
    target_y = start_y + target * @qubit_spacing

    min_y = Enum.min([control1_y, control2_y, target_y])
    max_y = Enum.max([control1_y, control2_y, target_y])

    # Control dots
    controls_svg = """
      <circle cx="#{gate_x}" cy="#{control1_y}" r="#{@control_radius}" fill="#{@color_control_small}" stroke="#{@color_control_small}" stroke-width="#{@gate_border_thickness}"/>
      <circle cx="#{gate_x}" cy="#{control2_y}" r="#{@control_radius}" fill="#{@color_control_small}" stroke="#{@color_control_small}" stroke-width="#{@gate_border_thickness}"/>
    """

    # Target circle with plus
    target_svg = """
      <circle cx="#{gate_x}" cy="#{target_y}" r="#{@target_radius}" fill="none" stroke="#000000" stroke-width="2"/>
      <line x1="#{gate_x - @target_radius}" y1="#{target_y}" x2="#{gate_x + @target_radius}" y2="#{target_y}" stroke="#000000" stroke-width="2"/>
      <line x1="#{gate_x}" y1="#{target_y - @target_radius}" x2="#{gate_x}" y2="#{target_y + @target_radius}" stroke="#000000" stroke-width="2"/>
    """

    # Connecting line
    line_svg = """
      <line x1="#{gate_x}" y1="#{min_y}" x2="#{gate_x}" y2="#{max_y}" stroke="#{@color_control_large}" stroke-width="#{@line_thickness}"/>
    """

    line_svg <> controls_svg <> target_svg
  end

  # Render classical control lines for conditional gates
  defp render_classical_control(gate_info, gate_x, start_y, diagram) do
    %{qubits: qubits, conditional: %{classical_bit: classical_bit, value: value}} = gate_info

    # Get the qubit position (for single-qubit gates)
    qubit = hd(qubits)
    qubit_y = start_y + qubit * @qubit_spacing

    # Classical register position (below all qubits)
    classical_y = start_y + diagram.num_qubits * @qubit_spacing + 20

    # Calculate positions for double parallel lines
    line_spacing = 3
    line1_x = gate_x - line_spacing / 2
    line2_x = gate_x + line_spacing / 2

    # Start from bottom of gate
    line_start_y = qubit_y + @gate_height / 2

    # Double vertical lines from gate to classical register
    lines_svg = """
      <line x1="#{line1_x}" y1="#{line_start_y}" x2="#{line1_x}" y2="#{classical_y}" stroke="#{@color_classical_line}" stroke-width="#{@line_thickness}"/>
      <line x1="#{line2_x}" y1="#{line_start_y}" x2="#{line2_x}" y2="#{classical_y}" stroke="#{@color_classical_line}" stroke-width="#{@line_thickness}"/>
    """

    # Circle on classical register (filled for ==1, hollow for ==0)
    circle_radius = 5
    circle_fill = if value == 1, do: @color_classical_line, else: "none"

    circle_svg = """
      <circle cx="#{gate_x}" cy="#{classical_y}" r="#{circle_radius}" fill="#{circle_fill}" stroke="#{@color_classical_line}" stroke-width="#{@line_thickness}"/>
    """

    # Label showing which classical bit (positioned above the classical line)
    label_svg = """
      <text x="#{gate_x + 12}" y="#{classical_y - 8}" font-family="#{@font_family}" font-size="#{@label_font_size}" fill="#000000">c#{classical_bit}</text>
    """

    lines_svg <> circle_svg <> label_svg
  end

  # Render single-qubit gate
  defp render_single_qubit_gate(gate_name, [qubit], params, gate_x, start_y) do
    qubit_y = start_y + qubit * @qubit_spacing
    box_x = gate_x - @gate_width / 2
    box_y = qubit_y - @gate_height / 2

    {label, color} = gate_label_and_color(gate_name, params)

    """
      <rect x="#{box_x}" y="#{box_y}" width="#{@gate_width}" height="#{@gate_height}" fill="#{color}" stroke="#{color}" stroke-width="#{@gate_border_thickness}"/>
      <text x="#{gate_x}" y="#{qubit_y + 4}" text-anchor="middle" font-family="#{@font_family}" font-size="#{@gate_font_size}" fill="#000000">#{label}</text>
    """
  end

  # Get gate label and color
  defp gate_label_and_color(gate_name, params) do
    case gate_name do
      :h -> {"H", @color_hadamard}
      :x -> {"X", @color_pauli_x}
      :y -> {"Y", @color_pauli_x}
      :z -> {"Z", @color_pauli_x}
      :s -> {"S", @color_hadamard}
      :t -> {"T", @color_hadamard}
      :rx -> {"RX(#{format_param(params)})", @color_hadamard}
      :ry -> {"RY(#{format_param(params)})", @color_hadamard}
      :rz -> {"RZ(#{format_param(params)})", @color_hadamard}
      :p -> {"P(#{format_param(params)})", @color_hadamard}
      _ -> {to_string(gate_name) |> String.upcase(), @color_hadamard}
    end
  end

  # Format gate parameter for display
  defp format_param([param]) when is_number(param) do
    # Format in terms of π if close to common fractions
    pi_val = :math.pi()
    ratio = param / pi_val

    cond do
      abs(ratio - 1) < 0.01 -> "π"
      abs(ratio - 0.5) < 0.01 -> "π/2"
      abs(ratio - 0.25) < 0.01 -> "π/4"
      abs(ratio + 1) < 0.01 -> "-π"
      abs(ratio + 0.5) < 0.01 -> "-π/2"
      abs(ratio + 0.25) < 0.01 -> "-π/4"
      true -> Float.round(param, 2) |> to_string()
    end
  end

  defp format_param(_), do: "θ"
end
