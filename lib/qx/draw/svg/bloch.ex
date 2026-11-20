defmodule Qx.Draw.SVG.Bloch do
  @moduledoc false

  # Internal: draws a single-qubit state on the Bloch sphere, following the
  # Bloch sphere sheet of the Qx visual design guide. The picture has two
  # jobs, in order: read as a sphere, then show exactly where the state
  # points.
  #
  # Everything is computed in Bloch coordinates (x, y, z on the unit
  # sphere) and put on the page by one orthographic projection,
  # `project/2`, which also returns the depth: positive is the hemisphere
  # nearer the reader. Depth decides what is drawn solid and what is
  # drawn pale or dashed.
  #
  # The drawing is grouped into `<g data-part="...">` elements, back to
  # front: body, plane, far, axes-hidden, shadow, arcs, near, silhouette,
  # labels, vector, centre, axes, title, readout.

  alias Qx.Draw.SVG.Markup
  alias Qx.Draw.Theme

  import Qx.Draw.SVG.Markup, only: [num: 1, num: 2]

  # The camera: 30° round from the x axis and 18° above the equator. x
  # comes toward the reader and to the left, y runs right, z is up.
  @azimuth :math.pi() / 6
  @elevation :math.pi() / 10

  # Unit vectors of the page in Bloch coordinates.
  @right {-:math.sin(@azimuth), :math.cos(@azimuth), 0.0}
  @up {-:math.cos(@azimuth) * :math.sin(@elevation), -:math.sin(@azimuth) * :math.sin(@elevation),
       :math.cos(@elevation)}
  @toward {:math.cos(@azimuth) * :math.cos(@elevation),
           :math.sin(@azimuth) * :math.cos(@elevation), :math.sin(@elevation)}

  # Sizes at the default 400 x 400. Lengths scale with size / 400; fonts
  # and strokes scale the same way but never go under 80%, so a small
  # sphere stays legible.
  @base_size 400
  @min_scale 0.8
  @radius_ratio 0.335
  @title_shift 6

  @silhouette_stroke 1.5
  @near_stroke 1.1
  @far_stroke 1.0
  @axis_stroke 1.25
  @shaft_stroke 3
  @halo_stroke 6
  @head_length 13
  @head_width 11
  @hollow_stroke 1.75
  @short_vector 20
  @dot_radius 5.5

  @axis_font 15
  @label_font 14
  @arc_font 13
  @readout_font 11
  @title_font 13

  # An axis runs from a short stub behind the origin to an arrowhead past
  # the surface.
  @axis_start -1.14
  @axis_end 1.30

  @theta_arc_radius 0.36
  @phi_arc_radius 0.27
  @arc_label_gap 0.135

  # Half a great circle is drawn with this many segments.
  @half_circle_segments 60

  # Below this a coordinate counts as zero: on the equator, or with φ = 0.
  @epsilon 1.0e-6
  # Below this sin θ the state is at a pole and φ has no meaning. States
  # are float32, whose rounding leaves about 1e-7 in an amplitude that
  # should be zero; the phase of such an amplitude is noise.
  @pole_epsilon 1.0e-5
  @hidden_epsilon 0.02

  # Where each state label sits relative to its point on the sphere, and
  # how it is anchored. Offsets are at the default size.
  @state_labels [
    {{0.0, 0.0, 1.0}, "|0⟩", {12, -6}, "start"},
    {{0.0, 0.0, -1.0}, "|1⟩", {12, 16}, "start"},
    {{1.0, 0.0, 0.0}, "|+⟩", {10, 20}, "start"},
    {{-1.0, 0.0, 0.0}, "|−⟩", {8, -10}, "start"},
    {{0.0, 1.0, 0.0}, "|i⟩", {8, -9}, "start"},
    {{0.0, -1.0, 0.0}, "|−i⟩", {-2, -12}, "middle"}
  ]

  @axes [{{1.0, 0.0, 0.0}, "x"}, {{0.0, 1.0, 0.0}, "y"}, {{0.0, 0.0, 1.0}, "z"}]

  # The equator and the two meridians through the axes, each as the two
  # unit vectors that span it.
  @great_circles [
    {{1.0, 0.0, 0.0}, {0.0, 1.0, 0.0}},
    {{1.0, 0.0, 0.0}, {0.0, 0.0, 1.0}},
    {{0.0, 1.0, 0.0}, {0.0, 0.0, 1.0}}
  ]

  @doc """
  Converts a qubit state to Bloch sphere coordinates.

  ## Parameters
    * `qubit` - Single qubit state tensor (2-element complex vector)

  ## Returns
  Tuple of `{x, y, z, theta, phi}` where:
  - `x, y, z` are Cartesian coordinates on the unit sphere
  - `theta` is the polar angle (0 to π)
  - `phi` is the azimuthal angle, from 0 up to but not including 2π. At
    a pole, where it has no meaning, it is 0

  ## Bloch Sphere Mapping
  For a qubit state α|0⟩ + β|1⟩:
  - θ = 2 * atan2(|β|, |α|)
  - φ = arg(β) - arg(α), brought into [0, 2π)

  Only the direction of the state is used: a state that is not normalised
  is drawn where its normalised form would be.

  Raises `Qx.StateShapeError` if `qubit` is not a two-element tensor, and
  `Qx.StateNormalizationError` if an amplitude is NaN or infinite.
  """
  def qubit_to_bloch_coordinates(qubit) do
    # Extract amplitudes α and β from qubit state
    [alpha, beta] = amplitudes!(qubit)

    # Calculate θ (polar angle). atan2 of the two magnitudes is used
    # rather than 2·acos(|α|): near a pole acos turns a rounding error of
    # 6e-8 in |α| into 7e-4 in θ, and it needs |α| clamped to 1.
    theta = 2 * :math.atan2(Complex.abs(beta), Complex.abs(alpha))

    # Calculate φ (azimuthal angle): φ = arg(β) - arg(α)
    phi =
      if :math.sin(theta) < @pole_epsilon do
        0.0
      else
        normalize_phi(Complex.phase(beta) - Complex.phase(alpha))
      end

    # Convert to Cartesian coordinates
    x = :math.sin(theta) * :math.cos(phi)
    y = :math.sin(theta) * :math.sin(phi)
    z = :math.cos(theta)

    {x, y, z, theta, phi}
  end

  defp amplitudes!(%Nx.Tensor{} = qubit) do
    case Nx.size(qubit) do
      2 -> qubit |> Nx.to_flat_list() |> Enum.map(&finite!/1)
      size -> raise Qx.StateShapeError, {size, 2}
    end
  end

  defp amplitudes!(other) do
    raise Qx.StateShapeError,
          "Expected a single-qubit state tensor of 2 amplitudes, got: #{inspect(other)}"
  end

  # NaN and the infinities come out of a tensor as atoms.
  defp finite!(%Complex{re: re, im: im} = amplitude) when is_number(re) and is_number(im),
    do: amplitude

  defp finite!(amplitude) when is_number(amplitude), do: amplitude

  defp finite!(amplitude) do
    raise Qx.StateNormalizationError,
          "State has an amplitude that is not a finite number: #{inspect(amplitude)}"
  end

  # Brings an angle into [0, 2π). Rounding noise just under zero would
  # land just under 2π, so it is taken as 0.
  defp normalize_phi(phi) do
    two_pi = 2 * :math.pi()
    wrapped = phi - two_pi * Float.floor(phi / two_pi)
    if two_pi - wrapped < @epsilon, do: 0.0, else: wrapped
  end

  @doc """
  Renders a qubit state on the Bloch sphere as SVG.

  ## Parameters
    * `coords` - Tuple of {x, y, z, theta, phi} Bloch coordinates
    * `title` - Chart title, or `nil` for none
    * `size` - Size of the SVG (width and height) in pixels

  ## Returns
  SVG string with complete Bloch sphere visualization.

  ## Features
  - A shaded body with an ink outline
  - Three great circles, the near half solid and the far half dashed
  - Ink axes: solid outside the sphere, pale inside or behind it
  - State labels (|0⟩, |1⟩, |+⟩, |−⟩, |i⟩, |−i⟩)
  - The state vector in the accent colour, with a solid head on the near
    hemisphere and a hollow one on the far hemisphere
  - A drop line to the equatorial plane, and the θ and φ arcs
  - θ and φ as fractions of π under the sphere
  """
  def render({x, y, z, theta, phi}, title, size) do
    scale = size / @base_size
    radius = size * @radius_ratio
    cy = if title, do: size / 2 + @title_shift * scale, else: size / 2

    view = %{
      cx: size / 2,
      cy: cy,
      radius: radius,
      size: size,
      # Lengths, and fonts and strokes.
      k: scale,
      f: max(scale, @min_scale)
    }

    state = %{point: {x, y, z}, theta: theta, phi: phi}
    readout = readout(theta, phi)

    [
      ~s(<svg xmlns="http://www.w3.org/2000/svg" role="img" ) <>
        ~s(aria-label="#{Markup.escape(aria_label(title, readout))}" ) <>
        ~s(width="#{num(size)}" height="#{num(size)}" viewBox="0 0 #{num(size)} #{num(size)}">),
      gradient(gradient_id(size, theta, phi)),
      ~s(<rect width="#{num(size)}" height="#{num(size)}" fill="#{Theme.color(:paper)}"/>),
      group("body", [body(gradient_id(size, theta, phi), view)]),
      group("plane", [plane(view)]),
      group("far", great_circle_halves(:far, view)),
      group("axes-hidden", hidden_axes(view)),
      group("shadow", shadow(state, view)),
      group("arcs", arcs(state, view)),
      group("near", great_circle_halves(:near, view)),
      group("silhouette", [silhouette(view)]),
      group("labels", state_labels(view)),
      group("vector", vector(state, view)),
      group("centre", centre(state, view)),
      group("axes", visible_axes(view)),
      group("title", title_text(title, view)),
      group("readout", [readout_text(readout, view)]),
      "</svg>"
    ]
    |> List.flatten()
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  # -- projection ------------------------------------------------------

  # Orthographic projection of a point in Bloch coordinates: screen x,
  # screen y, and depth (positive is nearer the reader).
  defp project(point, view) do
    {view.cx + view.radius * dot(point, @right), view.cy - view.radius * dot(point, @up),
     dot(point, @toward)}
  end

  defp dot({ax, ay, az}, {bx, by, bz}), do: ax * bx + ay * by + az * bz

  defp scale({x, y, z}, factor), do: {x * factor, y * factor, z * factor}

  # u·cos(angle) + v·sin(angle): a point on the circle spanned by u and v.
  defp on_circle({ux, uy, uz}, {vx, vy, vz}, angle, radius \\ 1.0) do
    c = radius * :math.cos(angle)
    s = radius * :math.sin(angle)
    {ux * c + vx * s, uy * c + vy * s, uz * c + vz * s}
  end

  # -- sphere ----------------------------------------------------------

  # The id is derived from the size and state, so two different spheres
  # inlined in one page do not share a gradient.
  defp gradient_id(size, theta, phi),
    do: "bloch-#{round(size * 10)}-#{round(theta * 1000)}-#{round(phi * 1000)}"

  defp gradient(id) do
    [
      "<defs>",
      ~s(<radialGradient id="#{id}" cx="36%" cy="30%" r="75%">),
      ~s(<stop offset="0" stop-color="#{Theme.color(:paper)}"/>),
      ~s(<stop offset="0.6" stop-color="#{Theme.color(:sphere_mid)}"/>),
      ~s(<stop offset="1" stop-color="#{Theme.color(:sphere_edge)}"/>),
      "</radialGradient>",
      "</defs>"
    ]
  end

  defp body(gradient_id, view) do
    ~s(<circle cx="#{num(view.cx)}" cy="#{num(view.cy)}" r="#{num(view.radius)}" ) <>
      ~s|fill="url(##{gradient_id})"/>|
  end

  defp silhouette(view) do
    ~s(<circle cx="#{num(view.cx)}" cy="#{num(view.cy)}" r="#{num(view.radius)}" ) <>
      ~s(fill="none" stroke="#{Theme.color(:ink)}" ) <>
      ~s(stroke-width="#{stroke(@silhouette_stroke, view)}"/>)
  end

  # The equatorial plane, tinted, so the equator reads as a disc seen at
  # an angle.
  defp plane(view) do
    count = 2 * @half_circle_segments
    {u, v} = hd(@great_circles)

    points =
      for i <- 0..(count - 1) do
        project(on_circle(u, v, 2 * :math.pi() * i / count), view)
      end

    ~s(<polygon points="#{points_attr(points)}" fill="#{Theme.color(:ink)}" fill-opacity="0.045"/>)
  end

  # Each great circle is sampled starting where it turns toward the
  # reader, so the first half of the samples is the near half and the
  # second the far half, and the two share their end points.
  defp great_circle_halves(which, view) do
    for {u, v} <- @great_circles do
      start = :math.atan2(-dot(u, @toward), dot(v, @toward))
      step = :math.pi() / @half_circle_segments

      [first | _] =
        points =
        for i <- 0..(2 * @half_circle_segments - 1) do
          project(on_circle(u, v, start + i * step), view)
        end

      {near, far} = Enum.split(points ++ [first], @half_circle_segments)

      case which do
        :near -> near_half(near ++ [hd(far)], view)
        :far -> far_half(far, view)
      end
    end
  end

  defp near_half(points, view) do
    ~s(<polyline points="#{points_attr(points)}" fill="none" stroke="#{Theme.color(:ink2)}" ) <>
      ~s(stroke-width="#{stroke(@near_stroke, view)}"/>)
  end

  defp far_half(points, view) do
    dash = num(3 * view.k)

    ~s(<polyline points="#{points_attr(points)}" fill="none" stroke="#{Theme.color(:back)}" ) <>
      ~s(stroke-width="#{stroke(@far_stroke, view)}" stroke-dasharray="#{dash} #{dash}"/>)
  end

  defp points_attr(points),
    do: Enum.map_join(points, " ", fn {x, y, _depth} -> "#{num(x)},#{num(y)}" end)

  # -- axes ------------------------------------------------------------

  # An axis is solid where it is outside the sphere and in view, and pale
  # where it passes through the sphere or behind it.
  defp hidden_axes(view) do
    for {axis, _letter} <- @axes, {from, to, :hidden} <- axis_pieces(axis) do
      axis_line(axis, from, to, Theme.color(:back), @far_stroke, view)
    end
  end

  defp visible_axes(view) do
    ink2 = Theme.color(:ink2)

    for {axis, letter} <- @axes do
      lines =
        for {from, to, :visible} <- axis_pieces(axis) do
          axis_line(axis, from, to, ink2, @axis_stroke, view)
        end

      {tip_x, tip_y, _} = project(scale(axis, @axis_end), view)
      {dx, dy} = screen_direction(axis)

      letter_text =
        Markup.text(
          tip_x + dx * 11 * view.k,
          tip_y + dy * 11 * view.k + 0.23 * @axis_font * view.f,
          letter,
          size: @axis_font * view.f,
          fill: ink2,
          anchor: "middle",
          extra: ~s(font-style="italic")
        )

      [lines, arrowhead({tip_x, tip_y}, {dx, dy}, 7 * view.k, 6 * view.k, ink2), letter_text]
    end
  end

  # The origin, where the axes and the state vector meet. It is left out
  # under a short vector's dot: an ink point inside a ring would read as
  # the "out of the page" symbol, whichever way the vector points.
  defp centre(%{point: point}, view) do
    if short_vector?(point, view) do
      []
    else
      [
        ~s(<circle cx="#{num(view.cx)}" cy="#{num(view.cy)}" r="#{num(2 * view.k)}" ) <>
          ~s(fill="#{Theme.color(:ink)}"/>)
      ]
    end
  end

  # A vector aimed at or away from the reader is too short on the page
  # for an arrowhead.
  defp short_vector?(point, view) do
    {tip_x, tip_y, _depth} = project(point, view)
    :math.sqrt((tip_x - view.cx) ** 2 + (tip_y - view.cy) ** 2) < @short_vector * view.k
  end

  # The stretches of an axis between the points where its visibility can
  # change: where it leaves the sphere (|t| = 1) and where it comes out
  # from behind the outline.
  defp axis_pieces(axis) do
    outline = 1 / max(screen_length(axis), @epsilon)

    [@axis_start, -outline, -1.0, 1.0, outline, @axis_end]
    |> Enum.filter(&(&1 >= @axis_start and &1 <= @axis_end))
    |> Enum.sort()
    |> Enum.dedup()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [from, to] -> {from, to, axis_visibility(axis, (from + to) / 2)} end)
  end

  defp axis_visibility(axis, t) do
    behind_sphere? = t * dot(axis, @toward) < 0 and abs(t) * screen_length(axis) < 1

    if abs(t) > 1 and not behind_sphere?, do: :visible, else: :hidden
  end

  # Length on the page of a unit vector, in sphere radii.
  defp screen_length(vector), do: :math.sqrt(dot(vector, @right) ** 2 + dot(vector, @up) ** 2)

  # Unit direction on the page of a vector in Bloch coordinates.
  defp screen_direction(vector) do
    length = max(screen_length(vector), @epsilon)
    {dot(vector, @right) / length, -dot(vector, @up) / length}
  end

  defp axis_line(axis, from, to, colour, width, view) do
    {x1, y1, _} = project(scale(axis, from), view)
    {x2, y2, _} = project(scale(axis, to), view)

    ~s(<line x1="#{num(x1)}" y1="#{num(y1)}" x2="#{num(x2)}" y2="#{num(y2)}" ) <>
      ~s(stroke="#{colour}" stroke-width="#{stroke(width, view)}"/>)
  end

  # A filled triangle with its point at `tip`, pointing along `direction`.
  defp arrowhead({tip_x, tip_y}, {dx, dy}, length, width, colour) do
    ~s(<path d="#{triangle({tip_x, tip_y}, {dx, dy}, length, width)}" fill="#{colour}"/>)
  end

  defp triangle({tip_x, tip_y}, {dx, dy}, length, width) do
    base_x = tip_x - dx * length
    base_y = tip_y - dy * length
    half = width / 2

    "M#{num(tip_x)} #{num(tip_y)}" <>
      "L#{num(base_x - dy * half)} #{num(base_y + dx * half)}" <>
      "L#{num(base_x + dy * half)} #{num(base_y - dx * half)}Z"
  end

  # -- labels ----------------------------------------------------------

  defp state_labels(view) do
    for {point, ket, {dx, dy}, anchor} <- @state_labels do
      {x, y, _depth} = project(point, view)

      Markup.text(x + dx * view.k, y + dy * view.k, ket,
        size: @label_font * view.f,
        anchor: anchor,
        extra: halo(3, view)
      )
    end
  end

  # A paper outline under the glyphs, so text stays readable over lines.
  defp halo(width, view) do
    ~s(stroke="#{Theme.color(:paper)}" stroke-width="#{stroke(width, view)}" ) <>
      ~s(paint-order="stroke fill")
  end

  # -- state -----------------------------------------------------------

  # The foot of the state on the equatorial plane: a faint line from the
  # centre to it, and a dashed line from the tip down (or up) to it. They
  # pin down where the tip sits in depth.
  defp shadow(%{point: {x, y, z}}, view) do
    if :math.sqrt(x * x + y * y) < @hidden_epsilon do
      []
    else
      accent = Theme.color(:accent)
      {foot_x, foot_y, _} = project({x, y, 0.0}, view)
      {tip_x, tip_y, _} = project({x, y, z}, view)

      shadow_line =
        ~s(<line x1="#{num(view.cx)}" y1="#{num(view.cy)}" x2="#{num(foot_x)}" ) <>
          ~s(y2="#{num(foot_y)}" stroke="#{accent}" stroke-opacity="0.45" ) <>
          ~s(stroke-width="#{stroke(1.5, view)}"/>)

      drop =
        if abs(z) < @hidden_epsilon do
          []
        else
          [
            ~s(<line x1="#{num(tip_x)}" y1="#{num(tip_y)}" x2="#{num(foot_x)}" ) <>
              ~s(y2="#{num(foot_y)}" stroke="#{accent}" stroke-width="#{stroke(1.0, view)}" ) <>
              ~s(stroke-dasharray="#{num(3 * view.k)} #{num(2.5 * view.k)}"/>)
          ]
        end

      foot =
        ~s(<circle cx="#{num(foot_x)}" cy="#{num(foot_y)}" r="#{num(2.2 * view.k)}" ) <>
          ~s(fill="#{accent}"/>)

      [shadow_line, drop, foot]
    end
  end

  # θ from the z axis to the vector, φ in the equatorial plane from the x
  # axis to the shadow. Neither is drawn at a pole, where φ has no meaning.
  defp arcs(%{theta: theta, phi: phi}, view) do
    if :math.sin(theta) < @hidden_epsilon do
      []
    else
      x_axis = {1.0, 0.0, 0.0}
      y_axis = {0.0, 1.0, 0.0}
      z_axis = {0.0, 0.0, 1.0}
      # The horizontal direction the state points in.
      heading = on_circle(x_axis, y_axis, phi)

      # No φ arc when φ reads 0.00π, from either side of zero.
      phi_arc =
        if phi < @hidden_epsilon or 2 * :math.pi() - phi < @hidden_epsilon,
          do: [],
          else: arc(x_axis, y_axis, phi, @phi_arc_radius, "φ", view)

      [phi_arc, arc(z_axis, heading, theta, @theta_arc_radius, "θ", view)]
    end
  end

  # An arc of `angle` from `u` toward `v`, with its letter just outside
  # its middle.
  defp arc(u, v, angle, radius, letter, view) do
    steps = max(2, ceil(angle / (:math.pi() / 40)))

    points =
      for i <- 0..steps, do: project(on_circle(u, v, angle * i / steps, radius), view)

    {label_x, label_y, _} =
      project(on_circle(u, v, angle / 2, radius + @arc_label_gap), view)

    font = @arc_font * view.f

    [
      ~s(<polyline points="#{points_attr(points)}" fill="none" stroke="#{Theme.color(:ink2)}" ) <>
        ~s(stroke-width="#{stroke(1.0, view)}"/>),
      Markup.text(label_x, label_y + 0.35 * font, letter,
        size: font,
        fill: Theme.color(:ink2),
        anchor: "middle",
        extra: ~s(font-style="italic" ) <> halo(3, view)
      )
    ]
  end

  # The state vector: the only saturated mark. Its head is solid when the
  # tip is on the near hemisphere and hollow when it is on the far one. A
  # vector aimed at or away from the reader is too short on the page for
  # an arrowhead and ends in a dot instead.
  defp vector(%{point: point}, view) do
    accent = Theme.color(:accent)
    {tip_x, tip_y, depth} = project(point, view)
    dx = tip_x - view.cx
    dy = tip_y - view.cy
    length = :math.sqrt(dx * dx + dy * dy)
    near? = depth >= -@epsilon

    if short_vector?(point, view) do
      [
        shaft_lines({tip_x, tip_y}, {tip_x, tip_y}, view),
        ~s(<circle cx="#{num(tip_x)}" cy="#{num(tip_y)}" r="#{num(@dot_radius * view.k)}" ) <>
          head_paint(near?, accent, view) <> "/>"
      ]
    else
      direction = {dx / length, dy / length}
      head_length = @head_length * view.k
      {ux, uy} = direction

      # The halo stops at the base of the head; the shaft runs a little
      # under it so no gap shows.
      halo_end = {tip_x - ux * head_length, tip_y - uy * head_length}
      overlap = head_length - 1.4 * view.k
      shaft_end = {tip_x - ux * overlap, tip_y - uy * overlap}

      [
        shaft_lines(halo_end, shaft_end, view),
        ~s(<path d="#{triangle({tip_x, tip_y}, direction, head_length, @head_width * view.k)}" ) <>
          head_paint(near?, accent, view) <> ~s( stroke-linejoin="round"/>)
      ]
    end
  end

  defp shaft_lines({halo_x, halo_y}, {shaft_x, shaft_y}, view) do
    [
      ~s(<line x1="#{num(view.cx)}" y1="#{num(view.cy)}" x2="#{num(halo_x)}" ) <>
        ~s(y2="#{num(halo_y)}" stroke="#{Theme.color(:paper)}" ) <>
        ~s(stroke-width="#{stroke(@halo_stroke, view)}" stroke-linecap="round"/>),
      ~s(<line x1="#{num(view.cx)}" y1="#{num(view.cy)}" x2="#{num(shaft_x)}" ) <>
        ~s(y2="#{num(shaft_y)}" stroke="#{Theme.color(:accent)}" ) <>
        ~s(stroke-width="#{stroke(@shaft_stroke, view)}"/>)
    ]
  end

  # Solid: accent with a thin paper edge. Hollow: paper with an accent
  # outline drawn over the fill.
  defp head_paint(true, accent, view) do
    ~s(fill="#{accent}" stroke="#{Theme.color(:paper)}" stroke-width="#{stroke(1.0, view)}")
  end

  defp head_paint(false, accent, view) do
    ~s(fill="#{Theme.color(:paper)}" stroke="#{accent}" ) <>
      ~s(stroke-width="#{stroke(@hollow_stroke, view)}" paint-order="fill stroke")
  end

  # -- text ------------------------------------------------------------

  defp title_text(nil, _view), do: []

  defp title_text(title, view) do
    [
      Markup.text(16 * view.k, 26 * view.k, title,
        voice: :sans,
        size: @title_font * view.f,
        weight: 600
      )
    ]
  end

  # θ and φ as multiples of π, two decimals. φ is shown from 0.00 up to
  # 1.99: a value that rounds to 2.00 is the same direction as 0.00.
  defp readout(theta, phi) do
    theta_text = :erlang.float_to_binary(theta / :math.pi(), decimals: 2)

    phi_text =
      case :erlang.float_to_binary(phi / :math.pi(), decimals: 2) do
        "2.00" -> "0.00"
        text -> text
      end

    {"θ = #{theta_text}π", "φ = #{phi_text}π"}
  end

  defp readout_text({theta_text, phi_text}, view) do
    ~s(<text x="#{num(view.cx)}" y="#{num(view.size - 14 * view.k)}" text-anchor="middle" ) <>
      ~s(font-family="#{Theme.font(:mono)}" font-size="#{num(@readout_font * view.f)}" ) <>
      ~s(fill="#{Theme.color(:ink2)}">#{theta_text}) <>
      ~s(<tspan dx="#{num(14 * view.k)}">#{phi_text}</tspan></text>)
  end

  defp aria_label(nil, {theta_text, phi_text}),
    do: "Bloch sphere showing #{theta_text}, #{phi_text}"

  defp aria_label(title, readout), do: "#{title}: " <> aria_label(nil, readout)

  # -- helpers ---------------------------------------------------------

  # A part of the drawing; nothing is emitted for an empty part.
  defp group(name, content) do
    case List.flatten(content) do
      [] -> []
      elements -> [~s(<g data-part="#{name}">), elements, "</g>"]
    end
  end

  # A stroke width at the default size, scaled, to two decimals.
  defp stroke(width, view), do: num(width * view.f, 2)
end
