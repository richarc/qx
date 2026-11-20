defmodule Qx.Draw.SVG.Circuit do
  @moduledoc false

  # Internal: draws a circuit as an SVG diagram in the quantikz grammar of
  # the Qx visual design guide (Circuit diagrams sheet): thin ink wires,
  # boxed gates labelled as mathematics, dots and ⊕ for controls and
  # targets, and one family colour on every gate.
  #
  # The work is in three steps. `place/2` gives every gate a column,
  # `columns/1` turns the columns into x positions (a column is as wide as
  # its widest gate), and `draw/3` draws one gate. Drawing a gate returns
  # its lines, shapes and texts separately, so the whole diagram is
  # layered: lines under shapes under text.

  alias Qx.Draw.SVG.Markup
  alias Qx.Draw.Theme
  alias Qx.Validation

  import Qx.Draw.SVG.Markup, only: [num: 1]

  # Geometry, in SVG user units. Read from the guide's reference drawings.
  @pitch 48
  @box 32
  @half_box 16
  @column_gap 24
  @wire_start 54
  @run_in 12
  @run_out 16
  @right_margin 10
  @label_x 46
  @top_titled 52
  @top_plain 26
  @bottom 26
  @register_drop 44
  @register_bottom 24
  @register_half_gap 1.5
  @baseline 5.1
  @dot_radius 3.5
  @target_radius 9
  @cross 5
  @barrier_overhang 20
  @label_size 15
  @iswap_label_size 13
  @iswap_baseline 4.4
  @small_size 10.5
  @condition_size 11
  @condition_drop 17.7
  @title_size 13
  @title_x 24
  @title_y 18
  # Average advance of the sans title face, used only to keep a long title
  # inside the image.
  @title_advance 7.2

  @stroke "1.25"
  @classical_stroke "1"
  @cross_stroke "1.75"

  @max_qubits 20

  @letter_gates [:h, :x, :y, :z, :s, :t]
  @boxed [:h, :x, :y, :z, :s, :sdg, :t, :tdg, :rx, :ry, :rz, :phase, :u]
  # A controlled gate drawn as a control joined to the box of the gate it
  # controls.
  @controlled_boxes %{cy: :y, cp: :phase, crx: :rx, cry: :ry, crz: :rz}

  # How many qubits each gate acts on. A measurement, a barrier and a
  # `c_if` have shapes of their own and are validated separately.
  @qubit_counts Map.new(@boxed, &{&1, 1})
                |> Map.merge(
                  Map.new([:cx, :cy, :cz, :cp, :crx, :cry, :crz, :swap, :iswap], &{&1, 2})
                )
                |> Map.merge(%{ccx: 3, cswap: 3})

  # An integer angle beyond this cannot be turned into a float.
  @max_integer_angle 1.0e300

  @doc """
  Renders a quantum circuit as an SVG diagram.

  ## Parameters
    * `circuit` - `Qx.QuantumCircuit` struct to visualize
    * `options` - `:title` (a string or `nil`) and `:style` (`:color` or
      `:mono`), already validated by the caller

  ## Returns
  SVG string representing the complete circuit diagram.

  ## Validation
  Raises a typed `Qx.*Error` on a malformed circuit:
  - `Qx.QubitCountError` if the circuit exceeds 20 qubits
  - `Qx.GateError` if an unsupported gate type is present, an instruction
    does not have the shape its gate takes (a barrier with no qubits
    included), or an angle is too large to draw
  - `Qx.QubitIndexError` / `Qx.ClassicalBitError` if a qubit or classical
    bit index is out of range
  """
  def render(%Qx.QuantumCircuit{} = circuit, options \\ []) do
    title = Keyword.get(options, :title)
    style = Keyword.get(options, :style, :color)

    # One read for the whole render: get_instructions/1 is O(n) per call.
    instructions = Qx.QuantumCircuit.get_instructions(circuit)
    validate_circuit!(circuit, instructions)

    gates = instructions |> Enum.flat_map(&flatten/1) |> place(circuit.num_qubits)
    {centers, wire_end} = columns(gates)

    top = if title, do: @top_titled, else: @top_plain
    last_wire = top + (circuit.num_qubits - 1) * @pitch
    register = if circuit.num_classical_bits > 0, do: last_wire + @register_drop

    context = %{style: style, top: top, register: register}

    drawn =
      Enum.map(gates, fn gate ->
        x = Map.fetch!(centers, gate.column)
        gate |> draw(x, context) |> with_condition(gate.condition, x, context)
      end)

    width = max(wire_end + @right_margin, title_extent(title))
    height = if register, do: register + @register_bottom, else: last_wire + @bottom

    [
      ~s(<?xml version="1.0" encoding="utf-8" standalone="no"?>),
      ~s(<svg xmlns="http://www.w3.org/2000/svg" role="img" ) <>
        ~s(aria-label="#{Markup.escape(aria_label(circuit, title))}" ) <>
        ~s(width="#{num(width)}" height="#{num(height)}" ) <>
        ~s(viewBox="0 0 #{num(width)} #{num(height)}">),
      ~s(<rect width="#{num(width)}" height="#{num(height)}" fill="#{Theme.color(:paper)}"/>),
      title_text(title),
      wires(circuit.num_qubits, wire_end, context),
      register_lines(wire_end, context),
      Enum.map(drawn, & &1.lines),
      Enum.map(drawn, & &1.shapes),
      wire_labels(circuit.num_qubits, context),
      register_texts(circuit.num_classical_bits, context),
      Enum.map(drawn, & &1.texts),
      "</svg>"
    ]
    |> List.flatten()
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  # -- validation ------------------------------------------------------

  defp validate_circuit!(%Qx.QuantumCircuit{} = circuit, instructions) do
    if circuit.num_qubits > @max_qubits do
      raise Qx.QubitCountError, {circuit.num_qubits, 1, @max_qubits}
    end

    Enum.each(instructions, &validate_instruction!(&1, circuit))

    Enum.each(circuit.measurements, fn {qubit, classical_bit} ->
      Validation.validate_qubit_index!(qubit, circuit.num_qubits)
      Validation.validate_classical_bit!(classical_bit, circuit.num_classical_bits)
    end)

    :ok
  end

  defp validate_instruction!({:c_if, [classical_bit, value], block}, circuit)
       when is_integer(value) and is_list(block) do
    Validation.validate_classical_bit!(classical_bit, circuit.num_classical_bits)
    Enum.each(block, &validate_conditional_instruction!(&1, circuit))
  end

  # The second index of a measurement is its classical bit, not a qubit.
  defp validate_instruction!({:measure, [qubit, classical_bit], _params}, circuit) do
    Validation.validate_qubit_index!(qubit, circuit.num_qubits)
    Validation.validate_classical_bit!(classical_bit, circuit.num_classical_bits)
  end

  defp validate_instruction!({:barrier, [], _params}, _circuit) do
    raise Qx.GateError, "A barrier with no qubits cannot be drawn"
  end

  defp validate_instruction!({:barrier, qubits, _params}, circuit) when is_list(qubits) do
    Enum.each(qubits, &Validation.validate_qubit_index!(&1, circuit.num_qubits))
  end

  # The supported set is the theme's: a gate can be drawn when it has a
  # family. `Theme.family/1` raises `Qx.GateError` for any other atom. The
  # shape is checked too, so a circuit built by hand cannot reach a draw
  # clause that does not match it.
  defp validate_instruction!({gate, qubits, params} = instruction, circuit)
       when is_atom(gate) and is_list(qubits) and is_list(params) do
    _family = Theme.family(gate)

    if length(qubits) != Map.get(@qubit_counts, gate), do: malformed!(instruction)

    Enum.each(qubits, &Validation.validate_qubit_index!(&1, circuit.num_qubits))
    Enum.each(params, &validate_angle!(gate, &1))
  end

  defp validate_instruction!(instruction, _circuit), do: malformed!(instruction)

  defp malformed!(instruction) do
    raise Qx.GateError, "Malformed instruction, cannot be drawn: #{inspect(instruction)}"
  end

  # A parameter that is not a number is drawn as θ. A number must fit in
  # a float to be formatted.
  defp validate_angle!(gate, angle) when is_integer(angle) and abs(angle) > @max_integer_angle,
    do: raise(Qx.GateError, {:invalid_parameter, gate, angle})

  defp validate_angle!(_gate, _angle), do: :ok

  # `Qx.c_if/4` rejects both of these, so they are reachable only from a
  # circuit built by hand.
  defp validate_conditional_instruction!({:c_if, _condition, _block}, _circuit),
    do: raise(Qx.ConditionalError, :nested_conditionals)

  defp validate_conditional_instruction!({:measure, _qubits, _params}, _circuit),
    do: raise(Qx.ConditionalError, :measurement_in_conditional)

  defp validate_conditional_instruction!(instruction, circuit),
    do: validate_instruction!(instruction, circuit)

  # -- layout ----------------------------------------------------------

  # A `c_if` block becomes its gates, each carrying the condition.
  defp flatten({:c_if, [classical_bit, value], block}) do
    for {gate, qubits, params} <- block do
      %{gate: gate, qubits: qubits, params: params, condition: {classical_bit, value}}
    end
  end

  defp flatten({gate, qubits, params}),
    do: [%{gate: gate, qubits: qubits, params: params, condition: nil}]

  # Gives each gate the first column in which every wire it occupies is
  # free. `free` maps a qubit to its next free column.
  defp place(gates, num_qubits) do
    free = Map.new(0..(num_qubits - 1), &{&1, 0})

    {placed, _free} =
      Enum.map_reduce(gates, free, fn gate, free ->
        occupied = occupied_wires(gate, num_qubits)
        column = occupied |> Enum.map(&Map.fetch!(free, &1)) |> Enum.max()
        free = Enum.reduce(occupied, free, &Map.put(&2, &1, column + 1))
        {Map.put(gate, :column, column), free}
      end)

    placed
  end

  # A barrier is a slice through the whole circuit: its column holds
  # nothing else, and a gate added after it is drawn after it.
  defp occupied_wires(%{gate: :barrier}, num_qubits), do: Enum.to_list(0..(num_qubits - 1))

  # A measurement drops to the register, crossing every wire below it.
  defp occupied_wires(%{gate: :measure, qubits: [qubit, _classical_bit]}, num_qubits),
    do: Enum.to_list(qubit..(num_qubits - 1))

  # A conditional gate is joined to the register from below.
  defp occupied_wires(%{qubits: qubits, condition: {_bit, _value}}, num_qubits),
    do: Enum.to_list(Enum.min(qubits)..(num_qubits - 1))

  # A multi-qubit gate crosses every wire between its qubits.
  defp occupied_wires(%{qubits: qubits}, _num_qubits),
    do: Enum.to_list(Enum.min(qubits)..Enum.max(qubits))

  # The centre x of every column and the x the wires end at. A column is as
  # wide as the widest gate in it.
  defp columns([]), do: {%{}, @wire_start + @run_in + @box + @run_out}

  defp columns(gates) do
    widths =
      Enum.reduce(gates, %{}, fn gate, widths ->
        width = width(gate)
        Map.update(widths, gate.column, width, &max(&1, width))
      end)

    {centers, next_left} =
      widths
      |> Enum.sort()
      |> Enum.map_reduce(@wire_start + @run_in, fn {column, width}, left ->
        {{column, left + width / 2}, left + width + @column_gap}
      end)

    {Map.new(centers), next_left - @column_gap + @run_out}
  end

  defp width(%{gate: :barrier}), do: 0
  defp width(%{gate: :iswap}), do: Markup.box_width(iswap_label(), @iswap_label_size)

  defp width(%{gate: gate, params: params}) when gate in @boxed,
    do: box_width(gate, params)

  defp width(%{gate: gate, params: params}) when is_map_key(@controlled_boxes, gate),
    do: box_width(Map.fetch!(@controlled_boxes, gate), params)

  # Dots, targets, crosses and meters take one box of room.
  defp width(_gate), do: @box

  defp box_width(gate, params),
    do: Markup.box_width(label(gate, params), @label_size, min_box_width(gate))

  # The guide draws every single-angle rotation in a 64 box, every phase
  # gate with an angle in a 56 box and U in an 84 box; a longer label
  # widens its box from there.
  defp min_box_width(gate) when gate in [:rx, :ry, :rz], do: 64
  defp min_box_width(:phase), do: 56
  defp min_box_width(:u), do: 84
  defp min_box_width(_gate), do: @box

  # -- labels ----------------------------------------------------------

  defp label(gate, _params) when gate in @letter_gates,
    do: [{:italic, gate |> Atom.to_string() |> String.upcase()}]

  defp label(:sdg, _params), do: [{:italic, "S"}, {:sup, "†"}]
  defp label(:tdg, _params), do: [{:italic, "T"}, {:sup, "†"}]
  defp label(:rx, params), do: rotation_label("x", params)
  defp label(:ry, params), do: rotation_label("y", params)
  defp label(:rz, params), do: rotation_label("z", params)
  defp label(:phase, params), do: [{:italic, "P"}, {:upright, angles(params)}]
  defp label(:u, params), do: [{:italic, "U"}, {:upright, angles(params)}]

  defp rotation_label(axis, params),
    do: [{:italic, "R"}, {:sub_italic, axis}, {:upright, angles(params)}]

  defp iswap_label, do: [{:italic, "i"}, {:upright, "SWAP"}]

  defp angles([]), do: "(θ)"
  defp angles(params), do: "(" <> Enum.map_join(params, ", ", &Markup.angle/1) <> ")"

  # -- gates -----------------------------------------------------------

  # Each clause returns the lines, shapes and texts of one gate centred on
  # `x`, and the y of its lowest point (a condition line starts there).

  defp draw(%{gate: gate, qubits: [qubit], params: params}, x, context) when gate in @boxed do
    y = wire_y(qubit, context)

    %{
      lines: [],
      shapes: [labelled_box(gate, params, x, y, context)],
      texts: [box_label(gate, params, x, y)],
      bottom: y + @half_box
    }
  end

  defp draw(%{gate: :cx, qubits: [control, target]}, x, context) do
    control_y = wire_y(control, context)
    target_y = wire_y(target, context)

    %{
      lines: [connector(x, control_y, target_y)],
      shapes: [dot(x, control_y), target(x, target_y, context)],
      texts: [],
      bottom: lowest([{control_y, @dot_radius}, {target_y, @target_radius}])
    }
  end

  defp draw(%{gate: :ccx, qubits: [control_a, control_b, target]}, x, context) do
    ys = [control_a, control_b, target] |> Enum.map(&wire_y(&1, context))
    [a_y, b_y, target_y] = ys

    %{
      lines: [connector(x, Enum.min(ys), Enum.max(ys))],
      shapes: [dot(x, a_y), dot(x, b_y), target(x, target_y, context)],
      texts: [],
      bottom: lowest([{a_y, @dot_radius}, {b_y, @dot_radius}, {target_y, @target_radius}])
    }
  end

  defp draw(%{gate: gate, qubits: [control, target], params: params}, x, context)
       when is_map_key(@controlled_boxes, gate) do
    controlled = Map.fetch!(@controlled_boxes, gate)
    control_y = wire_y(control, context)
    target_y = wire_y(target, context)
    # The connector stops at the near edge of the box.
    edge = if control_y < target_y, do: target_y - @half_box, else: target_y + @half_box

    %{
      lines: [connector(x, control_y, edge)],
      shapes: [dot(x, control_y), labelled_box(controlled, params, x, target_y, context)],
      texts: [box_label(controlled, params, x, target_y)],
      bottom: lowest([{control_y, @dot_radius}, {target_y, @half_box}])
    }
  end

  # CZ is symmetric: two ink dots and no colour.
  defp draw(%{gate: :cz, qubits: [qubit_a, qubit_b]}, x, context) do
    a_y = wire_y(qubit_a, context)
    b_y = wire_y(qubit_b, context)

    %{
      lines: [connector(x, a_y, b_y)],
      shapes: [dot(x, a_y), dot(x, b_y)],
      texts: [],
      bottom: max(a_y, b_y) + @dot_radius
    }
  end

  defp draw(%{gate: :swap, qubits: [qubit_a, qubit_b]}, x, context) do
    a_y = wire_y(qubit_a, context)
    b_y = wire_y(qubit_b, context)

    %{
      lines: [connector(x, a_y, b_y)],
      shapes: [cross(x, a_y, context), cross(x, b_y, context)],
      texts: [],
      bottom: max(a_y, b_y) + @cross
    }
  end

  defp draw(%{gate: :cswap, qubits: [control, target_a, target_b]}, x, context) do
    ys = [control, target_a, target_b] |> Enum.map(&wire_y(&1, context))
    [control_y, a_y, b_y] = ys

    %{
      lines: [connector(x, Enum.min(ys), Enum.max(ys))],
      shapes: [dot(x, control_y), cross(x, a_y, context), cross(x, b_y, context)],
      texts: [],
      bottom: lowest([{control_y, @dot_radius}, {a_y, @cross}, {b_y, @cross}])
    }
  end

  defp draw(%{gate: :iswap, qubits: [qubit_a, qubit_b]} = gate, x, context) do
    upper = wire_y(min(qubit_a, qubit_b), context)
    lower = wire_y(max(qubit_a, qubit_b), context)
    width = width(gate)

    if abs(qubit_a - qubit_b) == 1 do
      # Adjacent wires: one box spanning both.
      middle = (upper + lower) / 2

      %{
        lines: [],
        shapes: [box(x, upper - @half_box, width, lower - upper + @box, :exchange, context)],
        texts: [iswap_text(x, middle)],
        bottom: lower + @half_box
      }
    else
      %{
        lines: [connector(x, upper + @half_box, lower - @half_box)],
        shapes: [
          box(x, upper - @half_box, width, @box, :exchange, context),
          box(x, lower - @half_box, width, @box, :exchange, context)
        ],
        texts: [iswap_text(x, upper), iswap_text(x, lower)],
        bottom: lower + @half_box
      }
    end
  end

  # A meter: a neutral box with an ink arc and needle, a double line down
  # to an arrowhead on the register, and the classical bit index.
  defp draw(%{gate: :measure, qubits: [qubit, classical_bit]}, x, context) do
    y = wire_y(qubit, context)
    upper_line = context.register - @register_half_gap
    ink = Theme.color(:ink)
    ink2 = Theme.color(:ink2)

    arc =
      ~s(<path d="M#{num(x - 9)} #{num(y + 6)}A9 9 0 0 1 #{num(x + 9)} #{num(y + 6)}" ) <>
        ~s(fill="none" stroke="#{ink}" stroke-width="#{@stroke}"/>)

    # Tip first, then the base.
    arrowhead =
      ~s(<polygon points="#{num(x)},#{num(upper_line - 0.5)} ) <>
        ~s(#{num(x - 4.5)},#{num(upper_line - 7.5)} #{num(x + 4.5)},#{num(upper_line - 7.5)}" ) <>
        ~s(fill="#{ink2}"/>)

    %{
      lines: double_line(x, y + @half_box, upper_line - 6.5),
      shapes: [
        box(x, y - @half_box, @box, @box, :non_unitary, context),
        arc,
        line(x, y + 6, x + 7, y - 8, ink, @stroke),
        arrowhead
      ],
      texts: [
        Markup.text(x + 8, upper_line - 5.5, Integer.to_string(classical_bit),
          size: @small_size,
          fill: ink2
        )
      ],
      bottom: y + @half_box
    }
  end

  defp draw(%{gate: :barrier, qubits: qubits}, x, context) do
    top = wire_y(Enum.min(qubits), context) - @barrier_overhang
    bottom = wire_y(Enum.max(qubits), context) + @barrier_overhang

    barrier =
      line(x, top, x, bottom, Theme.color(:muted), @classical_stroke, ~s( stroke-dasharray="4 3"))

    %{lines: [barrier], shapes: [], texts: [], bottom: bottom}
  end

  # A classical condition: a double line up from a dot on the register to
  # the gate, labelled with the bit and the value it must hold.
  defp with_condition(drawn, nil, _x, _context), do: drawn

  defp with_condition(drawn, {classical_bit, value}, x, context) do
    ink2 = Theme.color(:ink2)
    register = context.register

    dot =
      ~s(<circle cx="#{num(x)}" cy="#{num(register)}" r="#{num(@dot_radius)}" fill="#{ink2}"/>)

    label =
      Markup.text(
        x,
        register + @condition_drop,
        [{:italic, "c"}, {:sub, Integer.to_string(classical_bit)}, {:upright, " = #{value}"}],
        size: @condition_size,
        fill: ink2,
        anchor: "middle"
      )

    %{
      drawn
      | lines: drawn.lines ++ double_line(x, drawn.bottom, register),
        shapes: drawn.shapes ++ [dot],
        texts: drawn.texts ++ [label]
    }
  end

  # -- parts -----------------------------------------------------------

  defp wire_y(qubit, context), do: context.top + qubit * @pitch

  defp lowest(points), do: points |> Enum.map(fn {y, extent} -> y + extent end) |> Enum.max()

  defp line(x1, y1, x2, y2, stroke, width, extra \\ "") do
    ~s(<line x1="#{num(x1)}" y1="#{num(y1)}" x2="#{num(x2)}" y2="#{num(y2)}" ) <>
      ~s(stroke="#{stroke}" stroke-width="#{width}"#{extra}/>)
  end

  defp connector(x, from_y, to_y), do: line(x, from_y, x, to_y, Theme.color(:ink), @stroke)

  # Anything classical is a double line in Ink 2.
  defp double_line(x, from_y, to_y) do
    ink2 = Theme.color(:ink2)

    [
      line(x - @register_half_gap, from_y, x - @register_half_gap, to_y, ink2, @classical_stroke),
      line(x + @register_half_gap, from_y, x + @register_half_gap, to_y, ink2, @classical_stroke)
    ]
  end

  defp box(x, top, width, height, family, context) do
    %{stroke: stroke, fill: fill} = Theme.family_colors(family, context.style)

    ~s(<rect x="#{num(x - width / 2)}" y="#{num(top)}" width="#{num(width)}" ) <>
      ~s(height="#{num(height)}" rx="2" fill="#{fill}" stroke="#{stroke}" ) <>
      ~s(stroke-width="#{@stroke}"/>)
  end

  defp labelled_box(gate, params, x, y, context) do
    box(x, y - @half_box, box_width(gate, params), @box, Theme.family(gate), context)
  end

  defp box_label(gate, params, x, y) do
    Markup.text(x, y + @baseline, label(gate, params), size: @label_size, anchor: "middle")
  end

  defp iswap_text(x, y) do
    Markup.text(x, y + @iswap_baseline, iswap_label(), size: @iswap_label_size, anchor: "middle")
  end

  defp dot(x, y) do
    ink = Theme.color(:ink)

    ~s(<circle cx="#{num(x)}" cy="#{num(y)}" r="#{num(@dot_radius)}" fill="#{ink}" ) <>
      ~s(stroke="#{ink}" stroke-width="#{@stroke}"/>)
  end

  # ⊕: an X, so it is drawn in the Pauli family. The cross stops at the rim.
  defp target(x, y, context) do
    %{stroke: stroke, fill: fill} = Theme.family_colors(:pauli, context.style)
    r = @target_radius

    [
      ~s(<circle cx="#{num(x)}" cy="#{num(y)}" r="#{r}" fill="#{fill}" stroke="#{stroke}" ) <>
        ~s(stroke-width="#{@stroke}"/>),
      ~s(<path d="M#{num(x - r)} #{num(y)}H#{num(x + r)}M#{num(x)} #{num(y - r)}V#{num(y + r)}" ) <>
        ~s(stroke="#{stroke}" stroke-width="#{@stroke}" fill="none"/>)
    ]
  end

  defp cross(x, y, context) do
    %{stroke: stroke} = Theme.family_colors(:exchange, context.style)
    cap = ~s( stroke-linecap="round")
    d = @cross

    [
      line(x - d, y - d, x + d, y + d, stroke, @cross_stroke, cap),
      line(x + d, y - d, x - d, y + d, stroke, @cross_stroke, cap)
    ]
  end

  # -- frame -----------------------------------------------------------

  defp wires(num_qubits, wire_end, context) do
    for qubit <- 0..(num_qubits - 1) do
      y = wire_y(qubit, context)
      line(@wire_start, y, wire_end, y, Theme.color(:ink), @stroke)
    end
  end

  defp wire_labels(num_qubits, context) do
    for qubit <- 0..(num_qubits - 1) do
      Markup.text(
        @label_x,
        wire_y(qubit, context) + @baseline,
        [{:italic, "q"}, {:sub, Integer.to_string(qubit)}],
        size: @label_size,
        anchor: "end"
      )
    end
  end

  # The classical register is a bundle: a double line with a slash and the
  # bit count. The slash is a path, not a line, so the register lines are
  # the only horizontal lines in Ink 2.
  defp register_lines(_wire_end, %{register: nil}), do: []

  defp register_lines(wire_end, %{register: y}) do
    ink2 = Theme.color(:ink2)
    upper = y - @register_half_gap
    lower = y + @register_half_gap

    [
      line(@wire_start, upper, wire_end, upper, ink2, @classical_stroke),
      line(@wire_start, lower, wire_end, lower, ink2, @classical_stroke),
      ~s(<path d="M#{@wire_start + 7} #{num(y + 6)}L#{@wire_start + 13} #{num(y - 6)}" ) <>
        ~s(stroke="#{ink2}" stroke-width="#{@classical_stroke}" fill="none"/>)
    ]
  end

  defp register_texts(_num_classical_bits, %{register: nil}), do: []

  defp register_texts(num_classical_bits, %{register: y}) do
    [
      Markup.text(@label_x, y + @baseline, [{:italic, "c"}], size: @label_size, anchor: "end"),
      Markup.text(@wire_start + 15, y - 7, Integer.to_string(num_classical_bits),
        size: @small_size,
        fill: Theme.color(:ink2)
      )
    ]
  end

  defp title_text(nil), do: []

  defp title_text(title) do
    [Markup.text(@title_x, @title_y, title, voice: :sans, size: @title_size, weight: 600)]
  end

  defp title_extent(nil), do: 0

  defp title_extent(title),
    do: ceil(2 * @title_x + String.length(title) * @title_advance)

  defp aria_label(_circuit, title) when is_binary(title), do: title

  defp aria_label(%Qx.QuantumCircuit{num_qubits: 1}, nil), do: "Quantum circuit, 1 qubit"

  defp aria_label(%Qx.QuantumCircuit{num_qubits: n}, nil), do: "Quantum circuit, #{n} qubits"
end
