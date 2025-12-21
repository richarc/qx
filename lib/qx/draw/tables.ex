defmodule Qx.Draw.Tables do
  @moduledoc """
  State table formatting for quantum registers and state vectors.

  This module provides functions for displaying quantum states in tabular format,
  showing basis states with their amplitudes and probabilities. Supports multiple
  output formats:
  - `:auto` - Auto-detects LiveBook/Kino and chooses best format
  - `:text` - Plain text table with ASCII formatting
  - `:html` - HTML table with styling
  - `:markdown` - Markdown table (with Kino support in LiveBook)

  ## Internal Module

  This module is part of the Qx.Draw refactoring and should be accessed
  through the public `Qx.Draw` API rather than directly.
  """

  @doc """
  Displays a quantum state as a formatted table.

  Shows basis states with their complex amplitudes and probabilities.

  ## Parameters
    * `register_or_state` - Either a `Qx.Register` struct or an `Nx.Tensor` state vector
    * `options` - Keyword list of options

  ## Options
    * `:format` - Output format (`:auto`, `:text`, `:html`, `:markdown`) (default: `:auto`)
    * `:precision` - Number of decimal places for floats (default: 3)
    * `:hide_zeros` - Hide states with near-zero probability (default: `false`)

  ## Returns
  Formatted table as string or Kino.Markdown struct (if in LiveBook).

  ## Examples

      # Display register state
      register = Qx.Register.new(2)
      Qx.Draw.Tables.render(register)

      # Custom format
      Qx.Draw.Tables.render(register, format: :html, precision: 4)

      # Hide negligible amplitudes
      Qx.Draw.Tables.render(register, hide_zeros: true)
  """
  def render(register_or_state, options \\ []) do
    format = Keyword.get(options, :format, :auto)
    precision = Keyword.get(options, :precision, 3)
    hide_zeros = Keyword.get(options, :hide_zeros, false)

    # Extract state vector
    state =
      case register_or_state do
        %Qx.Register{state: s} ->
          s

        tensor when is_struct(tensor, Nx.Tensor) ->
          tensor

        _ ->
          raise ArgumentError,
                "Expected Qx.Register or Nx.Tensor, got: #{inspect(register_or_state)}"
      end

    # Build table data
    table_data = build_table_data(state, precision, hide_zeros)

    case format do
      :auto ->
        format_auto(table_data)

      :text ->
        format_text(table_data)

      :html ->
        format_html(table_data)

      :markdown ->
        format_markdown(table_data)

      _ ->
        raise ArgumentError,
              "Unsupported format: #{format}. Use :auto, :text, :html, or :markdown"
    end
  end

  # Build table data from state vector
  defp build_table_data(state, precision, hide_zeros) do
    state_list = Nx.to_flat_list(state)
    probabilities = state_list |> Enum.map(fn amp -> :math.pow(Complex.abs(amp), 2) end)

    num_states = length(state_list)
    num_qubits = trunc(:math.log2(num_states))

    state_list
    |> Enum.zip(probabilities)
    |> Enum.with_index()
    |> Enum.filter(fn {{_amp, prob}, _index} ->
      not hide_zeros or prob > 1.0e-10
    end)
    |> Enum.map(fn {{amplitude, probability}, index} ->
      basis_state = Qx.Format.basis_state(index, num_qubits)
      amplitude_str = Qx.Format.complex(amplitude, precision: precision)
      probability_str = Float.round(probability, precision)

      {basis_state, amplitude_str, probability_str}
    end)
  end

  # Auto-detect best format based on environment
  defp format_auto(table_data) do
    if kino_available?() do
      format_markdown_kino(table_data)
    else
      format_text(table_data)
    end
  end

  # Format as plain text
  defp format_text(table_data) do
    header = "Basis State | Amplitude              | Probability\n"
    separator = "------------|------------------------|------------\n"

    rows =
      Enum.map_join(table_data, fn {basis, amplitude, probability} ->
        String.pad_trailing(basis, 11) <>
          " | " <>
          String.pad_trailing(amplitude, 22) <>
          " | " <> to_string(probability) <> "\n"
      end)

    header <> separator <> rows
  end

  # Format as HTML table
  defp format_html(table_data) do
    rows =
      Enum.map_join(table_data, "\n", fn {basis, amplitude, probability} ->
        "<tr><td>#{basis}</td><td>#{amplitude}</td><td>#{probability}</td></tr>"
      end)

    """
    <table border="1" cellpadding="5" cellspacing="0" style="border-collapse: collapse;">
      <thead>
        <tr>
          <th>Basis State</th>
          <th>Amplitude</th>
          <th>Probability</th>
        </tr>
      </thead>
      <tbody>
        #{rows}
      </tbody>
    </table>
    """
  end

  # Format as markdown
  defp format_markdown(table_data) do
    markdown = format_markdown_table(table_data)

    if kino_available?() do
      # Use Kino.Markdown for LiveBook
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(Kino.Markdown, :new, [markdown])
    else
      markdown
    end
  end

  # Format as markdown with Kino
  defp format_markdown_kino(table_data) do
    markdown = format_markdown_table(table_data)
    # credo:disable-for-next-line Credo.Check.Refactor.Apply
    apply(Kino.Markdown, :new, [markdown])
  end

  # Generate markdown table string
  defp format_markdown_table(table_data) do
    header = "| Basis State | Amplitude | Probability |\n"
    separator = "|-------------|-----------|-------------|\n"

    rows =
      Enum.map_join(table_data, "\n", fn {basis, amplitude, probability} ->
        # Escape pipes in basis state to prevent markdown column confusion
        escaped_basis = String.replace(basis, "|", "\\|")
        "| #{escaped_basis} | #{amplitude} | #{probability} |"
      end)

    header <> separator <> rows
  end

  # Check if Kino is available (indicates LiveBook environment)
  defp kino_available? do
    Code.ensure_loaded?(Kino)
  end
end
