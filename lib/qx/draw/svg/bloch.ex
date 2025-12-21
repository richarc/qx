defmodule Qx.Draw.SVG.Bloch do
  @moduledoc """
  SVG rendering of qubit states on the Bloch sphere.

  The Bloch sphere is a geometrical representation of pure qubit states where:
  - |0⟩ state is at the north pole (top)
  - |1⟩ state is at the south pole (bottom)
  - |+⟩ state is on the equator (front)
  - |-⟩ state is on the equator (back)
  - |i⟩ and |-i⟩ states are on the equator (sides)

  This module provides a sophisticated 3D SVG rendering with:
  - Wireframe sphere with latitude and longitude lines
  - Colored coordinate axes
  - State labels at key positions
  - State vector visualization
  - Angle information (θ and φ)

  ## Internal Module

  This module is part of the Qx.Draw refactoring and should be accessed
  through the public `Qx.Draw` API rather than directly.
  """

  @doc """
  Converts a qubit state to Bloch sphere coordinates.

  ## Parameters
    * `qubit` - Single qubit state tensor (2-element complex vector)

  ## Returns
  Tuple of `{x, y, z, theta, phi}` where:
  - `x, y, z` are Cartesian coordinates on the unit sphere
  - `theta` is the polar angle (0 to π)
  - `phi` is the azimuthal angle (0 to 2π)

  ## Bloch Sphere Mapping
  For a qubit state α|0⟩ + β|1⟩:
  - θ = 2 * acos(|α|)
  - φ = arg(β) - arg(α)
  """
  def qubit_to_bloch_coordinates(qubit) do
    # Extract amplitudes α and β from qubit state
    [alpha, beta] = Nx.to_flat_list(qubit)

    # Get magnitude and phase
    alpha_mag = Complex.abs(alpha)
    _beta_mag = Complex.abs(beta)

    # Calculate θ (polar angle): θ = 2 * acos(|α|)
    theta = 2 * :math.acos(max(-1.0, min(1.0, alpha_mag)))

    # Calculate φ (azimuthal angle): φ = arg(β) - arg(α)
    alpha_phase = Complex.phase(alpha)
    beta_phase = Complex.phase(beta)
    phi = beta_phase - alpha_phase

    # Convert to Cartesian coordinates
    x = :math.sin(theta) * :math.cos(phi)
    y = :math.sin(theta) * :math.sin(phi)
    z = :math.cos(theta)

    {x, y, z, theta, phi}
  end

  @doc """
  Renders a qubit state on the Bloch sphere as SVG.

  Creates a detailed 3D visualization with wireframe, axes, labels, and
  the state vector.

  ## Parameters
    * `coords` - Tuple of {x, y, z, theta, phi} Bloch coordinates
    * `title` - Chart title
    * `size` - Size of the SVG (width and height) in pixels

  ## Returns
  SVG string with complete Bloch sphere visualization.

  ## Features
  - 3D wireframe with latitude/longitude grid
  - Colored coordinate axes (X=red, Y=green, Z=blue)
  - State labels (|0⟩, |1⟩, |+⟩, |-⟩, |i⟩, |-i⟩)
  - Red state vector arrow
  - Angle information footer
  """
  def render({x, y, z, theta, phi}, title, size) do
    # 3D Projection Parameters
    # View angles (in radians)
    view_theta = :math.pi() / 6  # Elevation (30 degrees)
    view_phi = -:math.pi() / 4   # Azimuth (-45 degrees)

    # Center and scale
    cx = size / 2
    cy = size / 2
    radius = size * 0.35

    # 1. Generate 3D points for all elements
    # Sphere wireframe (Latitude lines)
    latitudes =
      for lat <- [-60, -30, 0, 30, 60] do
        lat_rad = lat * :math.pi() / 180
        r_lat = :math.cos(lat_rad)
        y_lat = :math.sin(lat_rad)

        for lon <- 0..360//10 do
          lon_rad = lon * :math.pi() / 180
          x_3d = r_lat * :math.cos(lon_rad)
          z_3d = r_lat * :math.sin(lon_rad)
          {x_3d, z_3d, y_lat}
        end
      end

    # Sphere wireframe (Longitude lines)
    longitudes =
      for lon <- [0, 45, 90, 135, 180, 225, 270, 315] do
        lon_rad = lon * :math.pi() / 180
        cos_lon = :math.cos(lon_rad)
        sin_lon = :math.sin(lon_rad)

        for lat <- -90..90//10 do
          lat_rad = lat * :math.pi() / 180
          r_lat = :math.cos(lat_rad)
          y_lat = :math.sin(lat_rad)
          x_3d = r_lat * cos_lon
          z_3d = r_lat * sin_lon
          {x_3d, z_3d, y_lat}
        end
      end

    # Axes
    axes = [
      {{-1.2, 0, 0}, {1.2, 0, 0}, "x", "#FF5733"},
      {{0, 0, -1.2}, {0, 0, 1.2}, "y", "#33FF57"},
      {{0, -1.2, 0}, {0, 1.2, 0}, "z", "#3357FF"}
    ]

    # State Vector (map Bloch coordinates to 3D engine coordinates)
    state_vector_tip = {y, z, x}

    # Labels
    labels = [
      {{0, 1.1, 0}, "|0⟩", "middle"},
      {{0, -1.1, 0}, "|1⟩", "middle"},
      {{0, 0, 1.1}, "|+⟩", "start"},
      {{0, 0, -1.1}, "|-⟩", "end"},
      {{1.1, 0, 0}, "|i⟩", "start"},
      {{-1.1, 0, 0}, "|-i⟩", "end"}
    ]

    # 2. Project and Render
    # Helper to project 3D point to 2D SVG coordinates
    project = fn {x3d, y3d, z3d} ->
      # Rotation around Y axis (Azimuth)
      x1 = x3d * :math.cos(view_phi) - z3d * :math.sin(view_phi)
      z1 = x3d * :math.sin(view_phi) + z3d * :math.cos(view_phi)

      # Rotation around X axis (Elevation)
      y2 = y3d * :math.cos(view_theta) - z1 * :math.sin(view_theta)
      z2 = y3d * :math.sin(view_theta) + z1 * :math.cos(view_theta)

      # Orthographic projection (scientific look)
      scale = 1.0

      svg_x = cx + x1 * radius * scale
      svg_y = cy - y2 * radius * scale  # Invert Y for SVG

      # Return depth for sorting
      {svg_x, svg_y, z2}
    end

    # Render Wireframe (Back)
    wireframe_paths_back =
      (latitudes ++ longitudes)
      |> Enum.map(fn points ->
        projected = Enum.map(points, project)
        avg_z = Enum.sum(Enum.map(projected, &elem(&1, 2))) / length(projected)
        {avg_z, projected}
      end)
      |> Enum.filter(fn {z, _} -> z < 0 end)
      |> Enum.map(fn {_, points} -> points_to_svg_path(points, "#e0e0e0", 1, "2,2") end)

    # Render Wireframe (Front)
    wireframe_paths_front =
      (latitudes ++ longitudes)
      |> Enum.map(fn points ->
        projected = Enum.map(points, project)
        avg_z = Enum.sum(Enum.map(projected, &elem(&1, 2))) / length(projected)
        {avg_z, projected}
      end)
      |> Enum.filter(fn {z, _} -> z >= 0 end)
      |> Enum.map(fn {_, points} -> points_to_svg_path(points, "#cccccc", 1) end)

    # Render Axes
    axes_svg =
      axes
      |> Enum.map(fn {p1, p2, label, color} ->
        {x1, y1, _} = project.(p1)
        {x2, y2, _} = project.(p2)

        """
        <line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}" stroke="#{color}" stroke-width="1.5" opacity="0.8"/>
        <text x="#{x2}" y="#{y2}" fill="#{color}" font-family="Arial" font-size="12" font-weight="bold">#{label}</text>
        """
      end)

    # Render Labels
    labels_svg =
      labels
      |> Enum.map(fn {pos, text, anchor} ->
        {lx, ly, _} = project.(pos)
        ly = ly + 4
        lx = lx + 10

        """
        <text x="#{lx}" y="#{ly}" text-anchor="#{anchor}" font-family="Arial" font-size="14" font-weight="bold" fill="#333">#{text}</text>
        """
      end)

    # Render State Vector
    {vx, vy, _} = project.(state_vector_tip)
    {ox, oy, _} = project.({0, 0, 0})

    vector_svg = """
    <line x1="#{ox}" y1="#{oy}" x2="#{vx}" y2="#{vy}" stroke="#FF0000" stroke-width="3"/>
    <circle cx="#{vx}" cy="#{vy}" r="5" fill="#FF0000"/>
    """

    # Assemble SVG
    """
    <svg width="#{size}" height="#{size}" xmlns="http://www.w3.org/2000/svg" style="background: white;">
      <title>#{title}</title>
      <rect width="100%" height="100%" fill="white"/>
      <text x="#{cx}" y="25" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold">#{title}</text>

      <!-- Back Wireframe -->
      #{Enum.join(wireframe_paths_back, "\n")}

      <!-- Axes -->
      #{Enum.join(axes_svg, "\n")}

      <!-- Front Wireframe -->
      #{Enum.join(wireframe_paths_front, "\n")}

      <!-- State Vector -->
      #{vector_svg}

      <!-- Labels -->
      #{Enum.join(labels_svg, "\n")}

      <!-- Info Footer -->
      <text x="#{cx}" y="#{size - 10}" text-anchor="middle" font-family="monospace" font-size="11" fill="#666">
        θ: #{Float.round(theta / :math.pi(), 2)}π, φ: #{Float.round(phi / :math.pi(), 2)}π
      </text>
    </svg>
    """
  end

  # Private helper to convert 3D points to SVG path
  defp points_to_svg_path(points, color, width, dash \\ "") do
    d = Enum.map_join(points, " L ", fn {x, y, _} -> "#{x},#{y}" end)

    dash_attr = if dash != "", do: "stroke-dasharray=\"#{dash}\"", else: ""

    "<path d=\"M #{d}\" fill=\"none\" stroke=\"#{color}\" stroke-width=\"#{width}\" #{dash_attr}/>"
  end
end
