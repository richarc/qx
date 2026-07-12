defmodule Qx.Draw.Tables do
  @moduledoc false

  alias Qx.Draw.StateTable

  @doc """
  Builds a `Qx.Draw.StateTable` artifact for a quantum state: every
  basis state with its complex amplitude and probability, pre-rendered
  as text, markdown, and HTML.

  ## Parameters
    * `register_or_state` - An `Nx.Tensor` state vector (an internal
      calc-engine register struct also works)
    * `options` - Keyword list of options

  ## Options
    * `:precision` - Number of decimal places for floats (default: 3)
    * `:hide_zeros` - Hide states with near-zero probability (default: `false`)

  ## Returns
  A `%Qx.Draw.StateTable{}` struct. One static type in every
  environment; Livebook renders it via `Kino.Render`.

  ## Examples

      state = Qx.create_circuit(2) |> Qx.h(0) |> Qx.get_state()
      Qx.Draw.Tables.render(state, precision: 4, hide_zeros: true)
  """
  def render(register_or_state, options \\ []) do
    precision = Keyword.get(options, :precision, 3)
    hide_zeros = Keyword.get(options, :hide_zeros, false)

    state =
      case register_or_state do
        %Qx.Register{state: s} ->
          IO.warn(
            "Passing a Qx.Register to Qx.draw_state/2 (Qx.Draw.state_table/2) is " <>
              "deprecated and will be removed in Qx 1.0. Use circuit mode: run the " <>
              "circuit and pass the state vector (`Qx.get_state/1` or a `Qx.Step`).",
            []
          )

          s

        tensor when is_struct(tensor, Nx.Tensor) ->
          tensor

        _ ->
          raise Qx.RegisterError, {:invalid_input, register_or_state}
      end

    table_data = build_table_data(state, precision, hide_zeros)

    %StateTable{
      text: format_text(table_data),
      markdown: format_markdown(table_data),
      html: format_html(table_data)
    }
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
end
