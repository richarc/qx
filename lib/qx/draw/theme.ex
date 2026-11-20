defmodule Qx.Draw.Theme do
  @moduledoc false

  # Internal: the one place that holds the colours, gate families and type
  # of the Qx visual design guide. The circuit, Bloch and chart renderers
  # all read from here, so a colour changes in one place.
  #
  # This module must not reference VegaLite: it compiles when the optional
  # :vega_lite dependency is absent. `vega_config/0` returns plain data.

  @ink "#16181D"
  @ink2 "#4A5261"
  @muted "#6B7482"
  @back "#A9B1BD"
  @rule "#D9DEE5"
  @paper "#FFFFFF"
  @accent "#D55E00"
  @data "#0072B2"
  # The shading of the Bloch sphere body, from its highlight to its edge.
  @sphere_mid "#EEF1F5"
  @sphere_edge "#CBD3DD"

  @colors %{
    ink: @ink,
    ink2: @ink2,
    muted: @muted,
    back: @back,
    rule: @rule,
    paper: @paper,
    accent: @accent,
    data: @data,
    sphere_mid: @sphere_mid,
    sphere_edge: @sphere_edge
  }

  # Stroke, and fill (the stroke at 16% on paper), of each gate family.
  @families %{
    pauli: %{stroke: "#0072B2", fill: "#D6E8F3"},
    hadamard: %{stroke: "#D55E00", fill: "#F8E5D6"},
    phase: %{stroke: "#009E73", fill: "#D6EFE9"},
    rotation: %{stroke: "#A8457F", fill: "#F1E1EB"},
    exchange: %{stroke: "#5D3A9B", fill: "#E5DFEF"},
    non_unitary: %{stroke: "#5B6470", fill: "#E5E6E8"}
  }

  @family_order [:pauli, :hadamard, :phase, :rotation, :exchange, :non_unitary]

  # Gate atom to family, for every instruction atom a producer emits
  # (`Qx.Operations`, `Qx.Patterns`, the OpenQASM importer). A controlled
  # gate takes the family of the gate it controls. A test checks this map
  # against the producers, and the circuit drawer takes its supported set
  # from it, so neither can fall behind.
  @gate_families %{
    x: :pauli,
    y: :pauli,
    z: :pauli,
    cx: :pauli,
    ccx: :pauli,
    cy: :pauli,
    cz: :pauli,
    h: :hadamard,
    s: :phase,
    sdg: :phase,
    t: :phase,
    tdg: :phase,
    phase: :phase,
    cp: :phase,
    rx: :rotation,
    ry: :rotation,
    rz: :rotation,
    u: :rotation,
    crx: :rotation,
    cry: :rotation,
    crz: :rotation,
    swap: :exchange,
    iswap: :exchange,
    cswap: :exchange,
    measure: :non_unitary,
    c_if: :non_unitary,
    barrier: :non_unitary
  }

  @fonts %{
    math: "'STIX Two Text','STIX Two Math','Latin Modern Roman',Cambria,'Times New Roman',serif",
    sans: "-apple-system,'Segoe UI',Helvetica,Arial,sans-serif",
    mono: "ui-monospace,SFMono-Regular,Menlo,Consolas,monospace"
  }

  @doc "A neutral or accent colour of the guide, as a hex string."
  def color(name), do: Map.fetch!(@colors, name)

  @doc "The six gate families, in the guide's order."
  def families, do: @family_order

  @doc "Every gate atom that has a family."
  def gates, do: Map.keys(@gate_families)

  @doc """
  The family of a gate atom. Raises `Qx.GateError` for an atom no
  producer emits.
  """
  def family(gate) when is_atom(gate) do
    case @gate_families do
      %{^gate => family} -> family
      _ -> raise Qx.GateError, {:unsupported_gate, gate}
    end
  end

  @doc """
  The stroke and fill of a family. In the `:mono` style every family is
  ink on paper.
  """
  def family_colors(family, style \\ :color)
  def family_colors(family, :color), do: Map.fetch!(@families, family)

  def family_colors(family, :mono) when is_map_key(@families, family),
    do: %{stroke: @ink, fill: @paper}

  @doc "Every colour a drawing may use: neutrals, accents and family colours."
  def palette do
    family_colors = Enum.flat_map(@families, fn {_family, c} -> [c.stroke, c.fill] end)
    Enum.uniq(Map.values(@colors) ++ family_colors)
  end

  @doc "A font stack: `:math`, `:sans` or `:mono`."
  def font(voice), do: Map.fetch!(@fonts, voice)

  @doc """
  The guide's Vega-Lite config, as the keyword list `VegaLite.config/2`
  takes.
  """
  def vega_config do
    [
      background: @paper,
      font: "-apple-system, 'Segoe UI', Helvetica, Arial, sans-serif",
      view: [stroke: nil],
      mark: [tooltip: true],
      bar: [color: @data, corner_radius_end: 3],
      scale: [band_padding_inner: 0.32, band_padding_outer: 0.16],
      title: [anchor: "start", font_size: 14, font_weight: 600, color: @ink, offset: 14],
      axis: [
        label_color: @ink2,
        label_font_size: 11,
        title_color: @ink,
        title_font_size: 12,
        title_font_weight: 500,
        title_padding: 10,
        grid_color: "#E6E9EE",
        domain_color: "#8A93A0",
        ticks: false,
        label_padding: 8
      ],
      axis_x: [
        grid: false,
        label_angle: 0,
        label_font: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
      ],
      axis_y: [domain: false, tick_count: 5],
      legend: [label_color: @ink2, title_color: @ink, symbol_type: "square"],
      range: [category: ["#0072B2", "#D55E00", "#009E73", "#A8457F", "#5D3A9B"]]
    ]
  end
end
