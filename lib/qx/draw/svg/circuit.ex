defmodule Qx.Draw.SVG.Circuit do
  @moduledoc """
  SVG rendering of quantum circuit diagrams.

  This module provides sophisticated SVG-based circuit visualization with:
  - Publication-quality IEEE-style gate notation
  - Support for all common quantum gates
  - Automatic gate layout with collision avoidance
  - Multi-qubit gates (CNOT, CZ, Toffoli)
  - Measurement operations with classical bit connections
  - Conditional gates (classical feedback)
  - Parametric gates with π-notation
  - Barrier markers for circuit organization

  ## Circuit Diagram Features

  - **Single-qubit gates**: H, X, Y, Z, S, T, RX, RY, RZ, Phase
  - **Multi-qubit gates**: CNOT (CX), Controlled-Z (CZ), Toffoli (CCX)
  - **Measurements**: With visual connection to classical registers
  - **Conditionals**: Gates controlled by classical bit values
  - **Barriers**: Visual separators for circuit sections

  ## Internal Module

  This module is part of the Qx.Draw refactoring and should be accessed
  through the public `Qx.Draw` API rather than directly.
  """

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

  @doc """
  Renders a quantum circuit as an SVG diagram.

  ## Parameters
    * `circuit` - `Qx.QuantumCircuit` struct to visualize
    * `title` - Optional circuit title (default: `nil`)

  ## Returns
  SVG string representing the complete circuit diagram.

  ## Validation
  Raises `ArgumentError` if:
  - Circuit exceeds 20 qubits
  - Invalid gate types are present
  - Qubit or classical bit indices are out of range

  ## Examples

      circuit = Qx.QuantumCircuit.new(2, 2)
      |> Qx.Operations.h(0)
      |> Qx.Operations.cx(0, 1)

      svg = Qx.Draw.SVG.Circuit.render(circuit, "Bell State")
      File.write!("bell_circuit.svg", svg)
  """
  def render(%Qx.QuantumCircuit{} = circuit, title \\ nil) do
    # Validate circuit
    validate_circuit!(circuit)

    # Analyze circuit and create layout
    diagram = analyze_circuit(circuit, title)

    # Generate SVG
    generate_svg(diagram)
  end

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
    supported_gates = [
      :h,
      :x,
      :y,
      :z,
      :s,
      :t,
      :rx,
      :ry,
      :rz,
      :p,
      :cx,
      :cz,
      :ccx,
      :barrier,
      :measure,
      :c_if
    ]

    unless gate_name in supported_gates do
      raise ArgumentError, "Unsupported gate type: #{gate_name}"
    end

    # Validate qubit indices (skip for c_if which has classical bit indices)
    unless gate_name == :c_if do
      validate_qubit_indices!(qubits, num_qubits, gate_name)
    end
  end

  defp validate_qubit_indices!(qubits, num_qubits, gate_name) do
    Enum.each(qubits, fn qubit ->
      if qubit < 0 or qubit >= num_qubits do
        raise ArgumentError, "Invalid qubit index #{qubit} for gate #{gate_name}"
      end
    end)
  end

  # Analyzes circuit and creates layout
  defp analyze_circuit(%Qx.QuantumCircuit{} = circuit, title) do
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
    qubit_columns = for i <- 0..(num_qubits - 1), into: %{}, do: {i, 0}
    initial_state = {[], qubit_columns, 0}

    {layout, _final_columns, max_column} =
      Enum.reduce(operations, initial_state, fn operation, {layout, columns, max_col} ->
        {gate_name, qubits, params} = operation

        if gate_name == :c_if do
          process_conditional_gate(qubits, params, layout, columns, max_col, num_qubits)
        else
          process_regular_gate(gate_name, qubits, params, layout, columns, max_col, num_qubits)
        end
      end)

    {Enum.reverse(layout), max_column + 1}
  end

  defp process_conditional_gate(
         [classical_bit, value],
         sub_instructions,
         layout,
         columns,
         max_col,
         num_qubits
       ) do
    Enum.reduce(sub_instructions, {layout, columns, max_col}, fn sub_instr,
                                                                 {sub_layout, sub_columns,
                                                                  sub_max_col} ->
      {sub_gate_name, sub_qubits, sub_params} = sub_instr

      column = find_available_column(sub_gate_name, sub_qubits, sub_columns, num_qubits)

      qubits_to_update = get_qubits_to_update(sub_gate_name, sub_qubits, num_qubits, true)

      new_columns = update_columns(sub_columns, qubits_to_update, column)

      gate_info = %{
        gate: sub_gate_name,
        qubits: sub_qubits,
        params: sub_params,
        column: column,
        conditional: %{classical_bit: classical_bit, value: value}
      }

      {[gate_info | sub_layout], new_columns, max(sub_max_col, column)}
    end)
  end

  defp process_regular_gate(gate_name, qubits, params, layout, columns, max_col, num_qubits) do
    column = find_available_column(gate_name, qubits, columns, num_qubits)

    qubits_to_update = get_qubits_to_update(gate_name, qubits, num_qubits, false)

    new_columns = update_columns(columns, qubits_to_update, column)

    gate_info = %{
      gate: gate_name,
      qubits: qubits,
      params: params,
      column: column
    }

    {[gate_info | layout], new_columns, max(max_col, column)}
  end

  defp get_qubits_to_update(gate_name, qubits, num_qubits, is_conditional) do
    if is_conditional or needs_vertical_line?(gate_name) do
      if gate_name == :measure or is_conditional do
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
  end

  defp update_columns(columns, qubits_to_update, column) do
    Enum.reduce(qubits_to_update, columns, fn qubit, cols ->
      Map.put(cols, qubit, column + 1)
    end)
  end

  defp find_available_column(gate_name, qubits, columns, num_qubits) do
    min_column = qubits |> Enum.map(&Map.get(columns, &1, 0)) |> Enum.max()

    if needs_vertical_line?(gate_name) do
      check_collision_and_advance(gate_name, qubits, columns, min_column, num_qubits)
    else
      min_column
    end
  end

  defp needs_vertical_line?(gate_name) do
    gate_name in [:cx, :cz, :ccx, :measure]
  end

  defp check_collision_and_advance(gate_name, qubits, columns, column, num_qubits) do
    {min_qubit, max_qubit} =
      if gate_name == :measure do
        qubit = hd(qubits)
        {qubit, num_qubits - 1}
      else
        {Enum.min(qubits), Enum.max(qubits)}
      end

    qubits_to_check = for q <- min_qubit..max_qubit, do: q

    has_collision? =
      Enum.any?(qubits_to_check, fn q ->
        Map.get(columns, q, 0) > column
      end)

    if has_collision? do
      check_collision_and_advance(gate_name, qubits, columns, column + 1, num_qubits)
    else
      column
    end
  end

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

  defp render_title(%CircuitDiagram{title: title, width: width}) do
    """
      <text x="#{width / 2}" y="25" text-anchor="middle" font-family="#{@font_family}" font-size="#{@title_font_size}">#{title}</text>
    """
  end

  defp render_lines(%CircuitDiagram{} = diagram, start_x, start_y, _label_width) do
    line_end_x =
      start_x + diagram.num_columns * (@gate_width + @gate_spacing) + @gate_spacing

    qubit_lines =
      Enum.map_join(0..(diagram.num_qubits - 1), "\n", fn q ->
        y = start_y + q * @qubit_spacing

        """
          <line x1="#{start_x}" y1="#{y}" x2="#{line_end_x}" y2="#{y}" stroke="#000000" stroke-width="#{@line_thickness}"/>
          <text x="#{start_x - 10}" y="#{y + 5}" text-anchor="end" font-family="#{@font_family}" font-size="#{@label_font_size}">q<tspan baseline-shift="sub" font-size="#{@label_font_size * 0.7}">#{q}</tspan></text>
        """
      end)

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

  defp render_gates(%CircuitDiagram{} = diagram, start_x, start_y) do
    diagram.gate_layout
    |> Enum.map_join("\n", fn gate_info ->
      render_gate(gate_info, diagram, start_x, start_y)
    end)
  end

  defp render_gate(gate_info, diagram, start_x, start_y) do
    %{gate: gate_name, qubits: qubits, params: params, column: column} = gate_info
    gate_x = start_x + column * (@gate_width + @gate_spacing) + @gate_spacing

    gate_svg =
      case gate_name do
        :barrier -> render_barrier(qubits, gate_x, start_y, diagram)
        :measure -> render_measurement(qubits, params, gate_x, start_y, diagram)
        :cx -> render_cnot(qubits, gate_x, start_y)
        :cz -> render_controlled_z(qubits, gate_x, start_y)
        :ccx -> render_toffoli(qubits, gate_x, start_y)
        _ -> render_single_qubit_gate(gate_name, qubits, params, gate_x, start_y)
      end

    conditional_svg =
      if Map.has_key?(gate_info, :conditional) do
        render_classical_control(gate_info, gate_x, start_y, diagram)
      else
        ""
      end

    gate_svg <> conditional_svg
  end

  defp render_barrier(_qubits, gate_x, start_y, diagram) do
    y1 = start_y
    y2 = start_y + (diagram.num_qubits - 1) * @qubit_spacing

    """
      <line x1="#{gate_x}" y1="#{y1}" x2="#{gate_x}" y2="#{y2}" stroke="#{@color_barrier}" stroke-width="1" stroke-dasharray="#{@barrier_dash}" opacity="0.6"/>
    """
  end

  defp render_measurement([qubit, _classical_bit], _params, gate_x, start_y, diagram) do
    qubit_y = start_y + qubit * @qubit_spacing
    classical_y = start_y + diagram.num_qubits * @qubit_spacing + 20 + 1.5

    box_x = gate_x - @gate_width / 2
    box_y = qubit_y - @gate_height / 2

    arc_cx = gate_x
    arc_cy = qubit_y + 3
    arc_start_x = gate_x - @measure_radius * 0.7
    arc_start_y = qubit_y + 3
    arc_end_x = gate_x + @measure_radius * 0.7
    arc_end_y = qubit_y + 3
    arrow_x = gate_x + @measure_radius * 0.5
    arrow_y = qubit_y - @measure_radius * 0.5

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

  defp render_cnot([control, target], gate_x, start_y) do
    control_y = start_y + control * @qubit_spacing
    target_y = start_y + target * @qubit_spacing

    control_svg = """
      <circle cx="#{gate_x}" cy="#{control_y}" r="#{@control_radius}" fill="#{@color_control_small}" stroke="#{@color_control_small}" stroke-width="#{@gate_border_thickness}"/>
    """

    target_svg = """
      <circle cx="#{gate_x}" cy="#{target_y}" r="#{@target_radius}" fill="none" stroke="#000000" stroke-width="2"/>
      <line x1="#{gate_x - @target_radius}" y1="#{target_y}" x2="#{gate_x + @target_radius}" y2="#{target_y}" stroke="#000000" stroke-width="2"/>
      <line x1="#{gate_x}" y1="#{target_y - @target_radius}" x2="#{gate_x}" y2="#{target_y + @target_radius}" stroke="#000000" stroke-width="2"/>
    """

    line_svg = """
      <line x1="#{gate_x}" y1="#{control_y}" x2="#{gate_x}" y2="#{target_y}" stroke="#{@color_control_large}" stroke-width="#{@line_thickness}"/>
    """

    line_svg <> control_svg <> target_svg
  end

  defp render_controlled_z([control, target], gate_x, start_y) do
    control_y = start_y + control * @qubit_spacing
    target_y = start_y + target * @qubit_spacing

    control_svg = """
      <circle cx="#{gate_x}" cy="#{control_y}" r="#{@control_radius}" fill="#{@color_control_small}" stroke="#{@color_control_small}" stroke-width="#{@gate_border_thickness}"/>
    """

    target_svg = """
      <circle cx="#{gate_x}" cy="#{target_y}" r="#{@control_radius}" fill="#{@color_control_small}" stroke="#{@color_control_small}" stroke-width="#{@gate_border_thickness}"/>
    """

    line_svg = """
      <line x1="#{gate_x}" y1="#{control_y}" x2="#{gate_x}" y2="#{target_y}" stroke="#{@color_control_large}" stroke-width="#{@line_thickness}"/>
    """

    line_svg <> control_svg <> target_svg
  end

  defp render_toffoli([control1, control2, target], gate_x, start_y) do
    control1_y = start_y + control1 * @qubit_spacing
    control2_y = start_y + control2 * @qubit_spacing
    target_y = start_y + target * @qubit_spacing

    min_y = Enum.min([control1_y, control2_y, target_y])
    max_y = Enum.max([control1_y, control2_y, target_y])

    controls_svg = """
      <circle cx="#{gate_x}" cy="#{control1_y}" r="#{@control_radius}" fill="#{@color_control_small}" stroke="#{@color_control_small}" stroke-width="#{@gate_border_thickness}"/>
      <circle cx="#{gate_x}" cy="#{control2_y}" r="#{@control_radius}" fill="#{@color_control_small}" stroke="#{@color_control_small}" stroke-width="#{@gate_border_thickness}"/>
    """

    target_svg = """
      <circle cx="#{gate_x}" cy="#{target_y}" r="#{@target_radius}" fill="none" stroke="#000000" stroke-width="2"/>
      <line x1="#{gate_x - @target_radius}" y1="#{target_y}" x2="#{gate_x + @target_radius}" y2="#{target_y}" stroke="#000000" stroke-width="2"/>
      <line x1="#{gate_x}" y1="#{target_y - @target_radius}" x2="#{gate_x}" y2="#{target_y + @target_radius}" stroke="#000000" stroke-width="2"/>
    """

    line_svg = """
      <line x1="#{gate_x}" y1="#{min_y}" x2="#{gate_x}" y2="#{max_y}" stroke="#{@color_control_large}" stroke-width="#{@line_thickness}"/>
    """

    line_svg <> controls_svg <> target_svg
  end

  defp render_classical_control(gate_info, gate_x, start_y, diagram) do
    %{qubits: qubits, conditional: %{classical_bit: classical_bit, value: value}} = gate_info

    qubit = hd(qubits)
    qubit_y = start_y + qubit * @qubit_spacing

    classical_y = start_y + diagram.num_qubits * @qubit_spacing + 20

    line_spacing = 3
    line1_x = gate_x - line_spacing / 2
    line2_x = gate_x + line_spacing / 2

    line_start_y = qubit_y + @gate_height / 2

    lines_svg = """
      <line x1="#{line1_x}" y1="#{line_start_y}" x2="#{line1_x}" y2="#{classical_y}" stroke="#{@color_classical_line}" stroke-width="#{@line_thickness}"/>
      <line x1="#{line2_x}" y1="#{line_start_y}" x2="#{line2_x}" y2="#{classical_y}" stroke="#{@color_classical_line}" stroke-width="#{@line_thickness}"/>
    """

    circle_radius = 5
    circle_fill = if value == 1, do: @color_classical_line, else: "none"

    circle_svg = """
      <circle cx="#{gate_x}" cy="#{classical_y}" r="#{circle_radius}" fill="#{circle_fill}" stroke="#{@color_classical_line}" stroke-width="#{@line_thickness}"/>
    """

    label_svg = """
      <text x="#{gate_x + 12}" y="#{classical_y - 8}" font-family="#{@font_family}" font-size="#{@label_font_size}" fill="#000000">c#{classical_bit}</text>
    """

    lines_svg <> circle_svg <> label_svg
  end

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

  defp gate_label_and_color(gate_name, params) do
    case gate_name do
      :h -> {"H", @color_hadamard}
      :x -> {"X", @color_pauli_x}
      :y -> {"Y", @color_pauli_x}
      :z -> {"Z", @color_pauli_x}
      :s -> {"S", @color_hadamard}
      :t -> {"T", @color_hadamard}
      _ -> parameterized_gate_label(gate_name, params)
    end
  end

  defp parameterized_gate_label(gate_name, params) do
    case gate_name do
      :rx -> {"RX(#{format_param(params)})", @color_hadamard}
      :ry -> {"RY(#{format_param(params)})", @color_hadamard}
      :rz -> {"RZ(#{format_param(params)})", @color_hadamard}
      :p -> {"P(#{format_param(params)})", @color_hadamard}
      _ -> {to_string(gate_name) |> String.upcase(), @color_hadamard}
    end
  end

  defp format_param([param]) when is_number(param) do
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
